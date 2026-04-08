#!/usr/bin/env Rscript
# 42_meat_shock_regressions.R
# Main results: Equations 1-3 of the meat-shock salience design.
# Eq 1: MeatShock -> household expectations
# Eq 2: MeatShock -> realized headline CPI (province-level)
# Eq 3: MeatShock -> household forecast error

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# --- Load data ---
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := paste0(region, "_", wave)]

cat(sprintf("[42] Estimation sample: %d obs, %d provinces, %d waves\n",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))

# ============================================================
# Helper: extract coefficient info
# ============================================================
format_col <- function(model, coef_name = "meat_shock") {
  ct <- coeftable(model)
  b <- ct[coef_name, "Estimate"]
  se <- ct[coef_name, "Std. Error"]
  p <- ct[coef_name, "Pr(>|t|)"]
  n <- model$nobs
  r2 <- fitstat(model, "r2")[[1]]
  list(beta = b, se = se, p = p, n = n, r2 = r2)
}

# ============================================================
# Helper: build LaTeX multicolumn table
# ============================================================
build_multicolumn_table <- function(cols, dep_var, caption, label, notes,
                                    fe_rows = NULL, out_file) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  ncols <- length(cols)
  col_headers <- paste0("(", seq_len(ncols), ")")

  lines <- c(
    "\\begin{table}[!htbp]",
    "\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    "\\begin{threeparttable}",
    sprintf("\\begin{tabular}{l%s}", paste(rep("c", ncols), collapse = "")),
    "\\toprule",
    sprintf("& %s \\\\", paste(col_headers, collapse = " & ")),
    # Column sub-headers instead of "Dep. var" row (AEA format)
    "\\midrule"
  )

  # Coefficient row
  betas <- sapply(cols, function(c) fmt_coef(c$beta, c$p))
  lines <- c(lines, sprintf("Meat shock & %s \\\\",
                             paste(betas, collapse = " & ")))

  # SE row
  ses <- sapply(cols, function(c) fmt_se(c$se))
  lines <- c(lines, sprintf("& %s \\\\[6pt]",
                             paste(ses, collapse = " & ")))

  # FE rows
  if (!is.null(fe_rows)) {
    for (fe in fe_rows) {
      lines <- c(lines, sprintf("%s & %s \\\\", fe$label,
                                paste(fe$values, collapse = " & ")))
    }
  }

  lines <- c(lines, "\\midrule")

  # N row
  ns <- sapply(cols, function(c) formatC(c$n, format = "d", big.mark = ","))
  lines <- c(lines, sprintf("Observations & %s \\\\",
                             paste(ns, collapse = " & ")))

  # R2 row
  r2s <- sapply(cols, function(c) fmt_num(c$r2, 3))
  lines <- c(lines, sprintf("$R^2$ & %s \\\\",
                             paste(r2s, collapse = " & ")))

  lines <- c(lines, "\\bottomrule", "\\end{tabular}")

  # Notes per UChicago Press: general note -> specific notes -> stars (last)
  if (!is.null(notes)) {
    # Separate star legend from other notes; stars always go last
    other_notes <- notes[!grepl("p<0\\.10", notes)]
    star_line <- "\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$."
    lines <- c(lines, "\\begin{tablenotes}[flushleft]", "\\footnotesize")
    # First note gets "\\textit{Note.}" prefix per UChicago convention
    if (length(other_notes) > 0) {
      lines <- c(lines, sprintf("\\item \\textit{Note.} %s", other_notes[1]))
      if (length(other_notes) > 1) {
        for (n in other_notes[-1]) lines <- c(lines, sprintf("\\item %s", n))
      }
    }
    lines <- c(lines, star_line)
    lines <- c(lines, "\\end{tablenotes}")
  }

  lines <- c(lines, "\\end{threeparttable}", "\\end{table}")
  writeLines(lines, con = out_file, useBytes = TRUE)
  cat(sprintf("[42] Wrote %s\n", out_file))
}

# ============================================================
# EQUATION 1: MeatShock -> Household Expectations
# ============================================================
eq1_1 <- feols(price_exp ~ meat_shock, data = cfps, vcov = ~province)
eq1_2 <- feols(price_exp ~ meat_shock + age + edu_high + urban,
               data = cfps, vcov = ~province)
eq1_3 <- feols(price_exp ~ meat_shock | province_factor + wave_factor,
               data = cfps, vcov = ~province)
eq1_4 <- feols(price_exp ~ meat_shock | region_wave,
               data = cfps, vcov = ~province)
eq1_5 <- feols(price_exp ~ meat_shock + age + edu_high + urban | region_wave,
               data = cfps, vcov = ~province)

eq1_cols <- lapply(list(eq1_1, eq1_2, eq1_3, eq1_4, eq1_5), format_col)

build_multicolumn_table(
  eq1_cols,
  dep_var = "Inflation expectation ($\\mu_{it}$)",
  caption = "Meat Price Shock and Household Inflation Expectations",
  label = "tab:eq1_expectations",
  notes = c(
    "Standard errors clustered at the province level in parentheses.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Meat shock is the cumulative log meat CPI change in the household's province between consecutive CFPS waves."
  ),
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes")),
    list(label = "Province FE", values = c("", "", "Yes", "", "")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "")),
    list(label = "Region $\\times$ wave FE",
         values = c("", "", "", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq1_expectations.tex")
)

# ============================================================
# EQUATION 2: MeatShock -> Realized Headline CPI (province-level)
# ============================================================
prov_wave <- cfps[, .(
  mean_exp = mean(price_exp, na.rm = TRUE),
  meat_shock = meat_shock[1],
  grain_shock = grain_shock[1],
  egg_shock = egg_shock[1],
  headline_cpi_next = headline_cpi_next[1],
  realized_cpi_ann = realized_cpi_ann[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]

prov_wave[, province_factor := as.factor(province)]
prov_wave[, wave_factor := as.factor(wave)]
prov_wave[, region_wave := paste0(region, "_", wave)]
prov_wave <- prov_wave[!is.na(realized_cpi_ann)]

eq2_1 <- feols(realized_cpi_ann ~ meat_shock, data = prov_wave, vcov = ~province)
eq2_2 <- feols(realized_cpi_ann ~ meat_shock | province_factor + wave_factor,
               data = prov_wave, vcov = ~province)
eq2_3 <- feols(realized_cpi_ann ~ meat_shock | region_wave,
               data = prov_wave, vcov = ~province)

eq2_cols <- lapply(list(eq2_1, eq2_2, eq2_3), format_col)

build_multicolumn_table(
  eq2_cols,
  dep_var = "Realized headline CPI (\\%, annualized)",
  caption = "Meat Price Shock and Realized Headline CPI",
  label = "tab:eq2_cpi_passthrough",
  notes = c(
    "Unit of observation is province $\\times$ wave.",
    "Standard errors clustered at the province level.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Dependent variable is annualized realized headline CPI inflation in the province over the subsequent inter-wave period."
  ),
  fe_rows = list(
    list(label = "Province FE", values = c("", "Yes", "")),
    list(label = "Wave FE", values = c("", "Yes", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq2_cpi_passthrough.tex")
)

# ============================================================
# EQUATION 3: MeatShock -> Forecast Error
# ============================================================
cfps_fe <- cfps[!is.na(fe_clean)]

eq3_1 <- feols(fe_clean ~ meat_shock, data = cfps_fe, vcov = ~province)
eq3_2 <- feols(fe_clean ~ meat_shock + age + edu_high + urban,
               data = cfps_fe, vcov = ~province)
eq3_3 <- feols(fe_clean ~ meat_shock | province_factor + wave_factor,
               data = cfps_fe, vcov = ~province)
eq3_4 <- feols(fe_clean ~ meat_shock | region_wave,
               data = cfps_fe, vcov = ~province)
eq3_5 <- feols(fe_clean ~ meat_shock + age + edu_high + urban | region_wave,
               data = cfps_fe, vcov = ~province)

eq3_cols <- lapply(list(eq3_1, eq3_2, eq3_3, eq3_4, eq3_5), format_col)

build_multicolumn_table(
  eq3_cols,
  dep_var = "Forecast error ($FE_{it}$)",
  caption = "Meat Price Shock and Household Forecast Errors",
  label = "tab:eq3_forecast_error",
  notes = c(
    "Standard errors clustered at the province level in parentheses.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Forecast error is realized province-level CPI inflation minus the household's directional expectation scaled to CPI units."
  ),
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes")),
    list(label = "Province FE", values = c("", "", "Yes", "", "")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "")),
    list(label = "Region $\\times$ wave FE",
         values = c("", "", "", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq3_forecast_error.tex")
)

cat("[42] All three equation tables written.\n")

# --- Save coefficient summary for reference ---
summary_dt <- data.table(
  equation = rep(c("Eq1", "Eq2", "Eq3"), c(5, 3, 5)),
  spec = c(paste0("Eq1_", 1:5), paste0("Eq2_", 1:3), paste0("Eq3_", 1:5)),
  beta = c(sapply(eq1_cols, `[[`, "beta"),
           sapply(eq2_cols, `[[`, "beta"),
           sapply(eq3_cols, `[[`, "beta")),
  se = c(sapply(eq1_cols, `[[`, "se"),
         sapply(eq2_cols, `[[`, "se"),
         sapply(eq3_cols, `[[`, "se")),
  p = c(sapply(eq1_cols, `[[`, "p"),
        sapply(eq2_cols, `[[`, "p"),
        sapply(eq3_cols, `[[`, "p")),
  n = c(sapply(eq1_cols, `[[`, "n"),
        sapply(eq2_cols, `[[`, "n"),
        sapply(eq3_cols, `[[`, "n"))
)
fwrite(summary_dt, file.path(project_paths$tables, "eq_summary.csv"))
cat("[42] Coefficient summary saved to outputs/tables/eq_summary.csv\n")

# Print key results
cat("\n=== KEY RESULTS ===\n")
cat(sprintf("Eq1 (preferred, region×wave FE): beta = %.4f, se = %.4f, p = %.4f\n",
            eq1_cols[[4]]$beta, eq1_cols[[4]]$se, eq1_cols[[4]]$p))
cat(sprintf("Eq2 (preferred, region×wave FE): beta = %.4f, se = %.4f, p = %.4f\n",
            eq2_cols[[3]]$beta, eq2_cols[[3]]$se, eq2_cols[[3]]$p))
cat(sprintf("Eq3 (preferred, region×wave FE): beta = %.4f, se = %.4f, p = %.4f\n",
            eq3_cols[[4]]$beta, eq3_cols[[4]]$se, eq3_cols[[4]]$p))
cat(sprintf("Overreaction gap: beta1 = %.4f >> beta2 = %.4f\n",
            eq1_cols[[4]]$beta, eq2_cols[[3]]$beta))
