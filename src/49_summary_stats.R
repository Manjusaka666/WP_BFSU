#!/usr/bin/env Rscript
# 49_summary_stats.R
# Descriptive statistics table for the main estimation sample.

suppressPackageStartupMessages({
  library(data.table)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]

cat(sprintf("[49] Sample: %d obs, %d provinces, %d waves\n",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))

# --- Compute summary stats ---
desc_row <- function(x, label) {
  x <- x[!is.na(x)]
  data.table(
    Variable = label,
    N = length(x),
    Mean = mean(x),
    SD = sd(x),
    Min = min(x),
    Median = median(x),
    Max = max(x)
  )
}

stats <- rbindlist(list(
  desc_row(cfps$price_exp, "Inflation expectation ($\\mu_{it}$)"),
  desc_row(cfps$fe_clean, "Forecast error ($FE_{it}$)"),
  desc_row(cfps$meat_shock, "Meat shock ($s_{pt}$)"),
  desc_row(cfps$grain_shock, "Grain shock"),
  desc_row(cfps$realized_cpi_ann, "Realized headline CPI (\\%, ann.)"),
  desc_row(cfps$age, "Age"),
  desc_row(cfps$edu_high, "High education (indicator)"),
  desc_row(cfps$urban, "Urban (indicator)")
))

# --- Build LaTeX table ---
fmt <- function(x, d = 2) formatC(x, digits = d, format = "f")

lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Descriptive Statistics}",
  "\\label{tab:summary_stats}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  "Variable & $N$ & Mean & SD & Min & Median & Max \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(stats))) {
  s <- stats[i]
  lines <- c(lines, sprintf(
    "%s & %s & %s & %s & %s & %s & %s \\\\",
    s$Variable,
    formatC(s$N, format = "d", big.mark = ","),
    fmt(s$Mean), fmt(s$SD), fmt(s$Min), fmt(s$Median), fmt(s$Max)
  ))
}

lines <- c(lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item \\textit{Note.} Sample restricted to observations with non-missing province code, inflation expectation, and meat shock.",
  "\\item Inflation expectation coded as $\\{-1, 0, 1\\}$ (prices fall, stable, rise).",
  "\\item Forecast error = realized headline CPI (\\%) $-$ expectation scaled to CPI units ($\\{-2, 0, 2\\}$).",
  "\\item Demographics available for a subsample; $N$ varies across rows.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

out_file <- file.path(project_paths$tables, "summary_stats_new.tex")
writeLines(lines, con = out_file, useBytes = TRUE)
cat(sprintf("[49] Wrote %s\n", out_file))
