#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(zoo)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

read_if_exists <- function(path) {
  if (!file.exists(path)) return(NULL)
  dt <- fread(path)
  setnames(dt, make.unique(names(dt), sep = "_dup"))
  dt
}

merge_safe <- function(lhs, rhs, by = "quarter") {
  dup <- setdiff(intersect(names(lhs), names(rhs)), by)
  if (length(dup) > 0) {
    setnames(rhs, dup, paste0(dup, "_src"))
  }
  merge(lhs, rhs, by = by, all.x = TRUE)
}

pboc_candidates <- c(
  file.path(project_paths$intermediate, "pboc_depositor_survey_quarterly_extended.csv"),
  file.path(project_paths$intermediate, "pboc_depositor_survey_quarterly.csv")
)
pboc_file <- pboc_candidates[file.exists(pboc_candidates)][1]
if (is.na(pboc_file)) stop("Missing PBOC quarterly survey file.")

pboc <- fread(pboc_file)
setnames(pboc, make.unique(names(pboc), sep = "_dup"))
if (!"quarter" %in% names(pboc) && "report_quarter" %in% names(pboc)) {
  setnames(pboc, "report_quarter", "quarter")
}
if (!"infl_exp_index" %in% names(pboc) && "price_expectation_index" %in% names(pboc)) {
  setnames(pboc, "price_expectation_index", "infl_exp_index")
}

idx <- read_if_exists(file.path(project_paths$intermediate, "pboc_infl_exp_index_extended.csv"))
if (is.null(idx)) idx <- read_if_exists(file.path(project_paths$intermediate, "pboc_infl_exp_index.csv"))
if (!is.null(idx)) {
  if (!"quarter" %in% names(idx) && "report_quarter" %in% names(idx)) setnames(idx, "report_quarter", "quarter")
  if ("future_price_expectation_index" %in% names(idx)) {
    setnames(idx, "future_price_expectation_index", "infl_exp_index_alt")
  }
  idx <- idx[, .(quarter, infl_exp_index_alt)]
}

cp <- read_if_exists(file.path(project_paths$intermediate, "pboc_expected_inflation_cp.csv"))
if (is.null(cp)) stop("Run 05_carlson_parkin_quantify.R first.")

epu <- read_if_exists(file.path(project_paths$intermediate, "epu_quarterly.csv"))
gpr <- read_if_exists(file.path(project_paths$intermediate, "gpr_quarterly.csv"))
nbs <- read_if_exists(file.path(project_paths$intermediate, "nbs_macro_quarterly.csv"))
food <- read_if_exists(file.path(project_paths$intermediate, "food_cpi_quarterly.csv"))

for (obj in list(epu, gpr, nbs, food)) {
  if (is.null(obj)) stop("Missing one or more required intermediate macro files.")
}

panel <- copy(pboc)
if (!is.null(idx)) panel <- merge_safe(panel, idx, by = "quarter")
panel <- merge_safe(panel, cp, by = "quarter")
panel <- merge_safe(panel, epu, by = "quarter")
panel <- merge_safe(panel, gpr, by = "quarter")
panel <- merge_safe(panel, nbs, by = "quarter")
panel <- merge_safe(panel, food, by = "quarter")

for (base_name in c("CPI_YoY", "PPI_YoY", "CPI_QoQ_Ann", "M2_YoY", "Food_CPI_YoY_qavg", "epu_qavg", "gpr_qavg")) {
  alt_name <- paste0(base_name, "_src")
  if (!base_name %in% names(panel) && alt_name %in% names(panel)) {
    setnames(panel, alt_name, base_name)
  }
}

# Keep CPI/PPI inflation rates in percentage-point form.
if ("CPI_YoY" %in% names(panel)) {
  panel[, CPI_YoY_rate := fifelse(CPI_YoY > 20, CPI_YoY - 100, CPI_YoY)]
}
if ("PPI_YoY" %in% names(panel)) {
  panel[, PPI_YoY_rate := fifelse(PPI_YoY > 20, PPI_YoY - 100, PPI_YoY)]
}

# Alternative expectations measure using raw index scale.
panel[, mu_alt_index := as.numeric(infl_exp_index)]

# Main forecast errors and revisions.
panel[, q_order := as.numeric(parse_quarter(quarter))]
setorder(panel, q_order)
panel[, q_order := NULL]
panel[, CPI_QoQ_Ann_lead1 := shift(CPI_QoQ_Ann, n = 1, type = "lead")]
panel[, CPI_YoY_rate_lead1 := shift(CPI_YoY_rate, n = 1, type = "lead")]
panel[, FE_next_cp := CPI_QoQ_Ann_lead1 - mu_cp]
panel[, FR_cp := mu_cp - shift(mu_cp, n = 1, type = "lag")]
panel[, FE_next_index := CPI_QoQ_Ann_lead1 - mu_alt_index]
panel[, FR_index := mu_alt_index - shift(mu_alt_index, n = 1, type = "lag")]

panel[, msi_raw := 0.6 * scale(epu_qavg)[, 1] + 0.4 * scale(infl_exp_index)[, 1]]
panel[, msi_raw := as.numeric(msi_raw)]
panel[, media_congestion_iv := -scale(gpr_qavg)[, 1]]

panel[, sample_main := as.integer(!is.na(FE_next_cp) & !is.na(FR_cp) & !is.na(epu_qavg) & !is.na(gpr_qavg))]

csv_out <- file.path(project_paths$processed, "panel_quarterly.csv")
parquet_out <- file.path(project_paths$processed, "panel_quarterly.parquet")
fwrite(panel, csv_out)
parquet_ok <- TRUE
tryCatch({
  arrow::write_parquet(panel, parquet_out)
}, error = function(e) {
  parquet_ok <<- FALSE
})

if (!parquet_ok) {
  py_cmd <- sprintf(
    "import pandas as pd; df=pd.read_csv(r'%s'); df.to_parquet(r'%s', index=False)",
    normalizePath(csv_out, winslash = "/", mustWork = FALSE),
    normalizePath(parquet_out, winslash = "/", mustWork = FALSE)
  )
  py_status <- system2("python", args = c("-c", shQuote(py_cmd)))
  if (py_status != 0) {
    warning("Parquet export failed in both R arrow and Python fallback.")
  }
}

# Sample overview.
s_main <- panel[sample_main == 1]
overview <- data.table(
  item = c("main_sample_start", "main_sample_end", "n_main_obs", "n_total_quarters", "has_alt_expectation"),
  value = c(
    ifelse(nrow(s_main) > 0, s_main$quarter[1], ""),
    ifelse(nrow(s_main) > 0, s_main$quarter[nrow(s_main)], ""),
    nrow(s_main),
    nrow(panel),
    any(!is.na(panel$mu_alt_index))
  )
)
write_booktabs_table(
  overview,
  file.path(project_paths$tables, "sample_overview.tex"),
  caption = "Quarterly Sample Construction",
  label = "tab:sample_overview",
  notes = c("Main sample requires non-missing FE, revision, uncertainty measures, and controls."),
  digits = 3,
  escape = FALSE
)

vars <- c("mu_cp", "mu_alt_index", "FR_cp", "FE_next_cp", "epu_qavg", "gpr_qavg",
          "CPI_QoQ_Ann", "CPI_YoY_rate", "Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate")
vars <- vars[vars %in% names(panel)]

stat_list <- lapply(vars, function(v) {
  xv <- panel[[v]]
  data.table(
    variable = v,
    n = sum(!is.na(xv)),
    mean = mean(xv, na.rm = TRUE),
    sd = sd(xv, na.rm = TRUE),
    p25 = quantile(xv, 0.25, na.rm = TRUE),
    median = median(xv, na.rm = TRUE),
    p75 = quantile(xv, 0.75, na.rm = TRUE)
  )
})

desc <- rbindlist(stat_list)
write_booktabs_table(
  desc,
  file.path(project_paths$tables, "desc_stats.tex"),
  caption = "Descriptive Statistics of Core Variables",
  label = "tab:desc_stats",
  notes = c("All inflation-related variables are in percentage points."),
  digits = 3,
  escape = FALSE
)

cat("[10] wrote", csv_out, "and", parquet_out, "\n")

