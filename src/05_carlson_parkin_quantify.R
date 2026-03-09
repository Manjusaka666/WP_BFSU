#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(stats)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

args <- commandArgs(trailingOnly = TRUE)
delta <- ifelse(length(args) >= 1, as.numeric(args[[1]]), 0.5)

pboc_candidates <- c(
  file.path(project_paths$intermediate, "pboc_depositor_survey_quarterly_extended.csv"),
  file.path(project_paths$intermediate, "pboc_depositor_survey_quarterly.csv")
)
pboc_file <- pboc_candidates[file.exists(pboc_candidates)][1]
if (is.na(pboc_file)) stop("Missing PBOC quarterly survey file.")

nbs_file <- file.path(project_paths$intermediate, "nbs_macro_quarterly.csv")
if (!file.exists(nbs_file)) stop("Missing nbs_macro_quarterly.csv")

pboc <- fread(pboc_file)
if (!"quarter" %in% names(pboc) && "report_quarter" %in% names(pboc)) {
  setnames(pboc, "report_quarter", "quarter")
}

need_cols <- c("quarter", "price_up_share", "price_down_share", "price_uncertain_share")
for (col in need_cols) {
  if (!col %in% names(pboc)) pboc[, (col) := NA_real_]
}

nbs <- fread(nbs_file)
if (!"CPI_YoY" %in% names(nbs)) stop("CPI_YoY not found in nbs macro file")
nbs_small <- nbs[, .(quarter, pi_baseline = as.numeric(CPI_YoY))]
if (median(nbs_small$pi_baseline, na.rm = TRUE) > 20) {
  nbs_small[, pi_baseline := pi_baseline - 100]
}

x <- merge(pboc[, .(quarter, price_up_share, price_down_share, price_uncertain_share)],
           nbs_small,
           by = "quarter",
           all.x = TRUE)

for (col in c("price_up_share", "price_down_share", "price_uncertain_share")) {
  x[, (col) := fifelse(get(col) > 1, get(col) / 100, get(col))]
}

x[, uncertain := fifelse(is.na(price_uncertain_share), 0, pmax(pmin(price_uncertain_share, 0.99), 0))]
x[, effective_sample_share := 1 - uncertain]

clip <- function(v) pmin(pmax(v, 1e-6), 1 - 1e-6)

compute_cp <- function(p_up, p_down, baseline, d) {
  z_u <- qnorm(1 - clip(p_up))
  z_d <- qnorm(clip(p_down))
  sigma <- 2 * d / (z_u - z_d)
  mu <- baseline + d - sigma * z_u
  list(mu = mu, sigma = sigma)
}

# Baseline: renormalize excluding uncertain responses.
x[, p_up_renorm := price_up_share / effective_sample_share]
x[, p_down_renorm := price_down_share / effective_sample_share]
cp_main <- compute_cp(x$p_up_renorm, x$p_down_renorm, x$pi_baseline, delta)
x[, mu_cp := cp_main$mu]
x[, sigma_cp := cp_main$sigma]

# Bounds: treat uncertain responses as all down or all up.
x[, p_up_lower := price_up_share]
x[, p_down_lower := price_down_share + uncertain]
cp_lower <- compute_cp(x$p_up_lower, x$p_down_lower, x$pi_baseline, delta)
x[, mu_cp_lower := cp_lower$mu]

x[, p_up_upper := price_up_share + uncertain]
x[, p_down_upper := price_down_share]
cp_upper <- compute_cp(x$p_up_upper, x$p_down_upper, x$pi_baseline, delta)
x[, mu_cp_upper := cp_upper$mu]

x[effective_sample_share <= 0.5 | is.na(pi_baseline), c("mu_cp", "sigma_cp", "mu_cp_lower", "mu_cp_upper") := .(NA_real_, NA_real_, NA_real_, NA_real_)]

x[, q_order := as.numeric(parse_quarter(quarter))]
setorder(x, q_order)
x[, q_order := NULL]

out_file <- file.path(project_paths$intermediate, "pboc_expected_inflation_cp.csv")
fwrite(
  x[, .(quarter, pi_baseline, mu_cp, sigma_cp, mu_cp_lower, mu_cp_upper,
        delta_used = delta, effective_sample_share)],
  out_file
)

coverage <- data.table(
  metric = c("total_quarters", "cp_available", "cp_share", "sample_start", "sample_end", "delta_pp"),
  value = c(
    nrow(x),
    sum(!is.na(x$mu_cp)),
    sprintf("%.3f", mean(!is.na(x$mu_cp))),
    x$quarter[which.min(parse_quarter(x$quarter))],
    x$quarter[which.max(parse_quarter(x$quarter))],
    sprintf("%.2f", delta)
  )
)
write_booktabs_table(
  coverage,
  file.path(project_paths$tables, "cp_coverage.tex"),
  caption = "Carlson-Parkin Quantification Coverage",
  label = "tab:cp_coverage",
  notes = c(
    "`mu_cp` uses renormalized up/down shares after removing uncertain responses.",
    "Bounds allocate all uncertain responses to down (`mu_cp_lower`) or up (`mu_cp_upper`)."
  ),
  digits = 3,
  escape = FALSE
)

head_tab <- x[, .(quarter, pi_baseline, mu_cp, sigma_cp, mu_cp_lower, mu_cp_upper, effective_sample_share)][1:12]
write_booktabs_table(
  head_tab,
  file.path(project_paths$tables, "cp_head.tex"),
  caption = "Carlson-Parkin Quantification: First 12 Quarters",
  label = "tab:cp_head",
  notes = c("Inflation units are percentage points, quarterly sample frequency."),
  digits = 3,
  escape = FALSE
)

bounds_tab <- x[!is.na(mu_cp), .(
  mean_mu_cp = mean(mu_cp),
  mean_lower = mean(mu_cp_lower),
  mean_upper = mean(mu_cp_upper),
  median_band_width = median(mu_cp_upper - mu_cp_lower)
)]
write_booktabs_table(
  bounds_tab,
  file.path(project_paths$tables, "cp_bounds.tex"),
  caption = "Sensitivity to Uncertain Responses in Carlson-Parkin Mapping",
  label = "tab:cp_bounds",
  notes = c("Wide lower-upper bands indicate stronger identification uncertainty from non-answers."),
  digits = 3,
  escape = FALSE
)

cat("[05] wrote", out_file, "\n")

