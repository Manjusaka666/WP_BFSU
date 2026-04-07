#!/usr/bin/env Rscript
# 48_calibration_table.R
# Build calibration benchmark table comparing estimated beta3
# against the rational upper bound under different rho assumptions.

suppressPackageStartupMessages({
  library(data.table)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# --- Load inputs ---
persist <- fread(file.path(project_paths$tables, "persistence_ar1.csv"))
rho_hat <- persist[parameter == "rho", value]

eq_summary <- fread(file.path(project_paths$tables, "eq_summary.csv"))
# Preferred spec: Eq3 with region x wave FE (col 4)
beta3 <- eq_summary[spec == "Eq3_4", beta]
beta3_se <- eq_summary[spec == "Eq3_4", se]

# Meat CPI weight
omega <- 0.05

cat(sprintf("[48] Estimated rho = %.4f\n", rho_hat))
cat(sprintf("[48] Estimated beta3 = %.4f (SE = %.4f)\n", beta3, beta3_se))

# --- Calibration scenarios ---
scenarios <- data.table(
  scenario = c(
    "Transitory ($\\rho = 0$)",
    "Estimated $\\hat{\\rho}$",
    "Moderate ($\\rho = 0.5$)",
    "Permanent ($\\rho = 1$)"
  ),
  rho = c(0, rho_hat, 0.5, 1)
)

# Rational bound: |beta3_R| = omega * |rho - rho_hat_belief|
# Worst case for rational: belief = 1 when rho = 0 -> beta3_R = -omega
# Under correct beliefs (rho_hat_belief = rho): beta3_R = 0
# We show bound assuming household knows rho (best case for rationality)
# and bound assuming household believes permanent (worst case for rationality)

scenarios[, beta3_rational_correct := 0]  # If belief = true rho
scenarios[, beta3_rational_worst := -omega * (1 - rho)]  # If belief = permanent
scenarios[, ratio_to_estimate := beta3 / ifelse(beta3_rational_worst == 0,
                                                 -omega, beta3_rational_worst)]

# --- Build LaTeX table ---
lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Calibration: Estimated vs.\\ Rational Forecast-Error Coefficient}",
  "\\label{tab:calibration_benchmark}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "& & \\multicolumn{2}{c}{Rational bound ($\\beta_3^R$)} & & \\\\",
  "\\cmidrule(lr){3-4}",
  "Persistence scenario & $\\rho$ & Correct belief & Worst case & $\\hat{\\beta}_3$ & Ratio \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(scenarios))) {
  s <- scenarios[i]
  worst_str <- ifelse(s$beta3_rational_worst == 0,
                      "$0$",
                      sprintf("$%.3f$", s$beta3_rational_worst))
  ratio_str <- ifelse(abs(s$beta3_rational_worst) < 1e-6,
                      "$\\infty$",
                      sprintf("$%.0f\\times$", abs(s$ratio_to_estimate)))
  lines <- c(lines, sprintf("%s & $%.2f$ & $0$ & %s & $%.3f$ & %s \\\\",
                            s$scenario, s$rho, worst_str,
                            beta3, ratio_str))
}

lines <- c(lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  sprintf("\\item \\textit{Note.} $\\omega = %.2f$ (meat weight in headline CPI). $\\hat{\\rho} = %.3f$ estimated from AR(1) on monthly province-level meat CPI with province fixed effects.", omega, rho_hat),
  "\\item Rational bound under correct belief: $\\beta_3^R = 0$ (household knows true $\\rho$).",
  "\\item Worst case: household believes shock is permanent ($\\hat{\\rho} = 1$), giving $\\beta_3^R = -\\omega(1 - \\rho)$.",
  sprintf("\\item $\\hat{\\beta}_3 = %.3f$ from the preferred specification (region $\\times$ wave FE, Table~\\ref{tab:eq3_forecast_error}, column 4).", beta3),
  "\\item The ordinal expectation scale inflates the exact ratio; the point estimate should be read as an order-of-magnitude statement.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

out_file <- file.path(project_paths$tables, "calibration_benchmark.tex")
writeLines(lines, con = out_file, useBytes = TRUE)
cat(sprintf("[48] Wrote %s\n", out_file))
