#!/usr/bin/env Rscript
# 44_placebo_commodity.R
# Placebo test: grain shocks should NOT predict expectations
# if the meat channel is the operative salience mechanism.
# Egg shocks excluded: pork-egg substitution during ASF
# mechanically correlates egg and meat prices.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, region_wave := paste0(region, "_", wave)]

cat(sprintf("[44] Sample: %d obs\n", nrow(cfps)))

# --- Meat (reference) ---
m_meat <- feols(price_exp ~ meat_shock | region_wave,
                data = cfps, vcov = ~province)

# --- Grain placebo ---
m_grain <- feols(price_exp ~ grain_shock | region_wave,
                 data = cfps[!is.na(grain_shock)], vcov = ~province)

# --- Horse race: meat + grain ---
m_horse <- feols(price_exp ~ meat_shock + grain_shock | region_wave,
                 data = cfps[!is.na(grain_shock)],
                 vcov = ~province)

# --- Print ---
cat("\n=== Meat (reference) ===\n")
print(summary(m_meat))
cat("\n=== Grain (placebo) ===\n")
print(summary(m_grain))
cat("\n=== Horse race ===\n")
print(summary(m_horse))

# --- LaTeX table ---
extract_coef <- function(model, coef_name) {
  ct <- coeftable(model)
  if (!(coef_name %in% rownames(ct))) return(list(beta = NA, se = NA, p = NA))
  list(
    beta = ct[coef_name, "Estimate"],
    se = ct[coef_name, "Std. Error"],
    p = ct[coef_name, "Pr(>|t|)"]
  )
}

models <- list(m_meat, m_grain, m_horse)
ns <- sapply(models, function(m) m$nobs)
r2s <- sapply(models, function(m) fitstat(m, "r2")[[1]])

# Row: meat_shock
meat_vals <- lapply(models, function(m) extract_coef(m, "meat_shock"))
# Row: grain_shock
grain_vals <- lapply(models, function(m) extract_coef(m, "grain_shock"))

fmt_cell <- function(vals) {
  if (is.na(vals$beta)) return("")
  fmt_coef(vals$beta, vals$p)
}
fmt_se_cell <- function(vals) {
  if (is.na(vals$se)) return("")
  fmt_se(vals$se)
}

lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Commodity Placebo: Meat vs.\\ Grain Shocks}",
  "\\label{tab:placebo_commodity}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "& (1) & (2) & (3) \\\\",
  "& Meat & Grain & Horse race \\\\",
  # Dep var moved to table note (AEA format)
  "\\midrule"
)

# Meat row
lines <- c(lines,
  sprintf("Meat shock & %s \\\\", paste(sapply(meat_vals, fmt_cell), collapse = " & ")),
  sprintf("& %s \\\\[4pt]", paste(sapply(meat_vals, fmt_se_cell), collapse = " & "))
)

# Grain row
lines <- c(lines,
  sprintf("Grain shock & %s \\\\", paste(sapply(grain_vals, fmt_cell), collapse = " & ")),
  sprintf("& %s \\\\[4pt]", paste(sapply(grain_vals, fmt_se_cell), collapse = " & "))
)

lines <- c(lines, "\\midrule",
  "Region $\\times$ wave FE & Yes & Yes & Yes \\\\",
  sprintf("Observations & %s \\\\",
          paste(formatC(ns, format = "d", big.mark = ","), collapse = " & ")),
  sprintf("$R^2$ & %s \\\\",
          paste(fmt_num(r2s, 3), collapse = " & ")),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]", "\\footnotesize",
  "\\item \\textit{Note.} Standard errors clustered at the province level in parentheses.",
  "\\item Columns (1)--(2) enter each commodity shock separately. Column (3) enters both jointly.",
  "\\item Egg shocks excluded because pork-egg substitution during the 2018--2019 African Swine Fever episode mechanically correlates egg and meat price movements.",
  "\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{table}")

out_file <- file.path(project_paths$tables, "placebo_commodity.tex")
writeLines(lines, con = out_file, useBytes = TRUE)
cat(sprintf("\n[44] Wrote %s\n", out_file))
