#!/usr/bin/env Rscript
# 50_scaling_sensitivity.R
# Scaling sensitivity analysis for forecast error construction.
# Baseline: fe_clean = realized_cpi_ann - price_exp       (ordinal {-1,0,1})
# Symmetric wide: fe = realized_cpi_ann - price_exp * 2.0 ({-2,0,2})
# Very wide:      fe = realized_cpi_ann - price_exp * 4.0 ({-4,0,4})

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# --- Load panel ---
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps[, `:=`(
  province_factor = factor(province),
  wave_factor     = factor(wave),
  region_wave     = interaction(region, wave, drop = TRUE)
)]

# --- Construct alternative FE measures ---
# Baseline is already fe_clean = realized_cpi_ann - price_exp
cfps[, fe_sym_wide  := realized_cpi_ann - price_exp * 2.0]
cfps[, fe_very_wide := realized_cpi_ann - price_exp * 4.0]

# --- Run preferred Eq3 specification (region x wave FE) for each scaling ---
fe_sample <- cfps[!is.na(fe_clean) & !is.na(meat_shock)]

cat(sprintf("[50] Scaling sensitivity sample: %d obs\n", nrow(fe_sample)))

m_baseline  <- feols(fe_clean     ~ meat_shock | region_wave, data = fe_sample, vcov = ~province)
m_sym_wide  <- feols(fe_sym_wide  ~ meat_shock | region_wave, data = fe_sample, vcov = ~province)
m_very_wide <- feols(fe_very_wide ~ meat_shock | region_wave, data = fe_sample, vcov = ~province)

extract_row <- function(m, label) {
  ct <- coeftable(m)
  data.table(
    scaling   = label,
    beta      = ct["meat_shock", "Estimate"],
    se        = ct["meat_shock", "Std. Error"],
    p         = ct["meat_shock", "Pr(>|t|)"],
    n         = m$nobs,
    r2        = fitstat(m, "r2")$r2
  )
}

results <- rbindlist(list(
  extract_row(m_baseline,  "Baseline (x1)"),
  extract_row(m_sym_wide,  "Symmetric wide (x2)"),
  extract_row(m_very_wide, "Very wide (x4)")
))

cat("\n=== Scaling Sensitivity: Eq3 Preferred Spec (Region x Wave FE) ===\n")
print(results)

# --- Save CSV ---
fwrite(results, file.path(project_paths$tables, "scaling_sensitivity.csv"))
cat(sprintf("\n[50] Saved outputs/tables/scaling_sensitivity.csv\n"))

# --- Build LaTeX table ---
stars <- function(p) {
  if (p < 0.01) return("^{***}")
  if (p < 0.05) return("^{**}")
  if (p < 0.10) return("^{*}")
  return("")
}

lines <- c(
  "\begin{table}[!htbp]",
  "\centering",
  "\caption{Scaling Sensitivity: Forecast Error Construction}",
  "\label{tab:scaling_sensitivity}",
  "\begin{threeparttable}",
  "\begin{tabular}{lccc}",
  "\toprule",
  "& (1) & (2) & (3) \\\\",
  "& Baseline & Symmetric wide & Very wide \\\\",
  "& $\{-1,0,1\}$ & $\{-2,0,2\}$ & $\{-4,0,4\}$ \\\\",
  "\midrule"
)

lines <- c(lines, sprintf("Meat shock & $%.3f%s$ & $%.3f%s$ & $%.3f%s$ \\\\",
  results[1, beta], stars(results[1, p]),
  results[2, beta], stars(results[2, p]),
  results[3, beta], stars(results[3, p])))
lines <- c(lines, sprintf("& $(%.3f)$ & $(%.3f)$ & $(%.3f)$ \\[6pt]",
  results[1, se], results[2, se], results[3, se]))

lines <- c(lines,
  "Region $\times$ wave FE & Yes & Yes & Yes \\\\",
  "\midrule",
  sprintf("Observations & %s & %s & %s \\\\",
    formatC(results[1, n], format = "d", big.mark = ","),
    formatC(results[2, n], format = "d", big.mark = ","),
    formatC(results[3, n], format = "d", big.mark = ",")),
  sprintf("$R^2$ & %.3f & %.3f & %.3f \\\\",
    results[1, r2], results[2, r2], results[3, r2]),
  "\bottomrule",
  "\end{tabular}",
  "\begin{tablenotes}[flushleft]",
  "\footnotesize",
  "\item \textit{Note.} The dependent variable is the forecast error under different scalings of the ordinal expectation variable. Column~(1) uses the raw ordinal code. Column~(2) doubles the scale. Column~(3) quadruples it. All specifications include region $\times$ wave fixed effects. Standard errors clustered at the province level in parentheses.",
  "\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
  "\end{tablenotes}",
  "\end{threeparttable}",
  "\end{table}"
)

out_file <- file.path(project_paths$tables, "scaling_sensitivity.tex")
writeLines(lines, con = out_file, useBytes = TRUE)
cat(sprintf("[50] Wrote %s\n", out_file))
