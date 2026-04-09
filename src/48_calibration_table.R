#!/usr/bin/env Rscript
# 48_calibration_table.R
# Compare preferred CP-based Eq3 coefficient against model-based rational bounds.

suppressPackageStartupMessages({
  library(data.table)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

persist <- fread(file.path(project_paths$tables, "persistence_ar1.csv"))
rho_hat <- persist[parameter == "rho", value]

eq_summary <- fread(file.path(project_paths$tables, "eq_summary.csv"))
beta3 <- eq_summary[spec == "Eq3_6", beta]

omega <- 0.05
bound_time_agg <- -24 * omega

scenarios <- data.table(
  scenario = c(
    "Transitory ($\\rho=0$), permanent-belief worst case",
    "Estimated persistence ($\\rho=\\hat{\\rho}$), permanent-belief worst case",
    "Moderate persistence ($\\rho=0.5$), permanent-belief worst case",
    "Time-aggregated worst case ($24\\omega$)"
  ),
  bound = c(-omega, -omega * (1 - rho_hat), -omega * (1 - 0.5), bound_time_agg)
)
scenarios[, ratio := abs(beta3 / bound)]

lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Calibration: Preferred CP Estimate vs. Rational Benchmark Bounds}",
  "\\label{tab:calibration_benchmark}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Scenario & Rational bound & Preferred $\\hat{\\beta}_3$ & Ratio \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(scenarios))) {
  s <- scenarios[i]
  lines <- c(lines, sprintf("%s & $%.3f$ & $%.3f$ & $%.1f\\times$ \\\\",
                            s$scenario, s$bound, beta3, s$ratio))
}

lines <- c(
  lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  sprintf("\\item \\textit{Note.} Preferred coefficient is CP-based Eq~3 column (6): $\\hat{\\beta}_3 = %.3f$.", beta3),
  sprintf("\\item Headline CPI meat weight is set to $\\omega=%.2f$. Estimated persistence is $\\hat{\\rho}=%.3f$.", omega, rho_hat),
  "\\item These are model-based benchmark bounds from the paper's signal-extraction calibration.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

out_file <- file.path(project_paths$tables, "calibration_benchmark.tex")
writeLines(lines, out_file, useBytes = TRUE)
cat(sprintf("[48] Wrote %s\n", out_file))
