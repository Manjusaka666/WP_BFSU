#!/usr/bin/env Rscript
# 43_heterogeneity_meat.R
# Heterogeneity in meat-shock overreaction by education, income, urban status.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := paste0(region, "_", wave)]

cat(sprintf("[43] Full sample: %d obs\n", nrow(cfps)))

# --- Interaction regressions ---
# Education split
cfps[, edu_high_int := fifelse(!is.na(edu_high), edu_high, NA_integer_)]
cfps[, meat_x_edu := meat_shock * edu_high_int]

het_edu <- feols(price_exp ~ meat_shock + meat_x_edu + edu_high_int | region_wave,
                 data = cfps[!is.na(edu_high_int)], vcov = ~province)

# Income split (below median)
cfps[, meat_x_lowinc := meat_shock * income_below_median]

het_inc <- feols(price_exp ~ meat_shock + meat_x_lowinc + income_below_median | region_wave,
                 data = cfps[!is.na(income_below_median)], vcov = ~province)

# Urban split
cfps[, meat_x_urban := meat_shock * urban]

het_urban <- feols(price_exp ~ meat_shock + meat_x_urban + urban | region_wave,
                   data = cfps[!is.na(urban)], vcov = ~province)

# --- Print results ---
cat("\n=== Heterogeneity: Education ===\n")
print(summary(het_edu))

cat("\n=== Heterogeneity: Income ===\n")
print(summary(het_inc))

cat("\n=== Heterogeneity: Urban ===\n")
print(summary(het_urban))

# --- Build LaTeX table ---
extract_het <- function(model, interact_name, base_name = "meat_shock") {
  ct <- coeftable(model)
  list(
    beta_base = ct[base_name, "Estimate"],
    se_base = ct[base_name, "Std. Error"],
    p_base = ct[base_name, "Pr(>|t|)"],
    beta_int = ct[interact_name, "Estimate"],
    se_int = ct[interact_name, "Std. Error"],
    p_int = ct[interact_name, "Pr(>|t|)"],
    n = model$nobs,
    r2 = fitstat(model, "r2")[[1]]
  )
}

h_edu <- extract_het(het_edu, "meat_x_edu")
h_inc <- extract_het(het_inc, "meat_x_lowinc")
h_urban <- extract_het(het_urban, "meat_x_urban")

cols <- list(h_edu, h_inc, h_urban)
col_labels <- c("Education", "Income", "Urban")
interact_labels <- c("$\\times$ High education", "$\\times$ Low income", "$\\times$ Urban")

lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Heterogeneity in Meat Shock Effects on Inflation Expectations}",
  "\\label{tab:heterogeneity}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  sprintf("& %s \\\\", paste(paste0("(", seq_along(cols), ")"), collapse = " & ")),
  "& Education & Income & Urban status \\\\",
  "\\midrule"
)

# Base meat shock row
betas <- sapply(cols, function(c) fmt_coef(c$beta_base, c$p_base))
lines <- c(lines, sprintf("Meat shock & %s \\\\", paste(betas, collapse = " & ")))
ses <- sapply(cols, function(c) fmt_se(c$se_base))
lines <- c(lines, sprintf("& %s \\\\[4pt]", paste(ses, collapse = " & ")))

# Interaction row
for (i in seq_along(cols)) {
  int_betas <- rep("", length(cols))
  int_ses <- rep("", length(cols))
  int_betas[i] <- fmt_coef(cols[[i]]$beta_int, cols[[i]]$p_int)
  int_ses[i] <- fmt_se(cols[[i]]$se_int)
  lines <- c(lines,
             sprintf("%s & %s \\\\", interact_labels[i], paste(int_betas, collapse = " & ")),
             sprintf("& %s \\\\[4pt]", paste(int_ses, collapse = " & ")))
}

lines <- c(lines, "\\midrule",
           "Region $\\times$ wave FE & Yes & Yes & Yes \\\\")

ns <- sapply(cols, function(c) formatC(c$n, format = "d", big.mark = ","))
lines <- c(lines, sprintf("Observations & %s \\\\", paste(ns, collapse = " & ")))

r2s <- sapply(cols, function(c) fmt_num(c$r2, 3))
lines <- c(lines, sprintf("$R^2$ & %s \\\\", paste(r2s, collapse = " & ")))

lines <- c(lines, "\\bottomrule", "\\end{tabular}",
           "\\begin{tablenotes}[flushleft]", "\\footnotesize",
           "\\item \\textit{Note.} Standard errors clustered at the province level in parentheses. Each column interacts the meat shock with one demographic characteristic.",
           "\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
           "\\end{tablenotes}",
           "\\end{threeparttable}", "\\end{table}")

out_file <- file.path(project_paths$tables, "heterogeneity.tex")
writeLines(lines, con = out_file, useBytes = TRUE)
cat(sprintf("\n[43] Wrote %s\n", out_file))
