#!/usr/bin/env Rscript
# 42_meat_shock_regressions.R
# Main results:
# Eq1: MeatShock -> ordinal inflation expectations
# Eq2: MeatShock -> realized headline CPI (province-wave)
# Eq3: MeatShock -> CP-based forecast error (main specification)

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

clip_prob <- function(x, eps = 0.001) {
  pmin(pmax(x, eps), 1 - eps)
}

build_cp_cells <- function(cfps, delta = 0.5) {
  cell <- cfps[, .(
    p_down = mean(price_exp == -1, na.rm = TRUE),
    p_same = mean(price_exp == 0, na.rm = TRUE),
    p_up = mean(price_exp == 1, na.rm = TRUE),
    realized_cpi_ann = realized_cpi_ann[1],
    region = region[1],
    n_hh = .N
  ), by = .(province, wave)]

  cell <- cell[!is.na(realized_cpi_ann)]
  cell[, p_down_c := clip_prob(p_down)]
  cell[, p_up_c := clip_prob(p_up)]
  cell[, z_d := qnorm(p_down_c)]
  cell[, z_u := qnorm(1 - p_up_c)]
  cell[, sigma_cp := 2 * delta / (z_u - z_d)]
  cell[, mu_cp := delta - sigma_cp * z_u]
  cell[!is.finite(sigma_cp), c("sigma_cp", "mu_cp") := .(NA_real_, NA_real_)]
  cell[, fe_cp := realized_cpi_ann - mu_cp]
  cell
}

format_col <- function(model, coef_name = "meat_shock") {
  ct <- coeftable(model)
  b <- ct[coef_name, "Estimate"]
  se <- ct[coef_name, "Std. Error"]
  p <- if ("Pr(>|t|)" %in% colnames(ct)) ct[coef_name, "Pr(>|t|)"] else NA_real_
  n <- model$nobs
  r2 <- fitstat(model, "r2")[[1]]
  list(beta = b, se = se, p = p, n = n, r2 = r2)
}

build_multicolumn_table <- function(cols, caption, label, notes, fe_rows, out_file, col_subtitles = NULL) {
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
    sprintf("& %s \\\\", paste(col_headers, collapse = " & "))
  )

  if (!is.null(col_subtitles)) {
    lines <- c(lines, sprintf("& %s \\\\", paste(col_subtitles, collapse = " & ")))
  }

  lines <- c(lines, "\\midrule")

  betas <- sapply(cols, function(c) fmt_coef(c$beta, c$p))
  lines <- c(lines, sprintf("Meat shock & %s \\\\", paste(betas, collapse = " & ")))

  ses <- sapply(cols, function(c) fmt_se(c$se))
  lines <- c(lines, sprintf("& %s \\\\[6pt]", paste(ses, collapse = " & ")))

  for (fe in fe_rows) {
    lines <- c(lines, sprintf("%s & %s \\\\", fe$label, paste(fe$values, collapse = " & ")))
  }

  lines <- c(lines, "\\midrule")

  ns <- sapply(cols, function(c) formatC(c$n, format = "d", big.mark = ","))
  lines <- c(lines, sprintf("Observations & %s \\\\", paste(ns, collapse = " & ")))

  r2s <- sapply(cols, function(c) fmt_num(c$r2, 3))
  lines <- c(lines, sprintf("$R^2$ & %s \\\\", paste(r2s, collapse = " & ")))

  lines <- c(lines, "\\bottomrule", "\\end{tabular}")
  lines <- c(lines, "\\begin{tablenotes}[flushleft]", "\\footnotesize")
  lines <- c(lines, sprintf("\\item \\textit{Note.} %s", notes[1]))
  if (length(notes) > 1) {
    for (n in notes[-1]) lines <- c(lines, sprintf("\\item %s", n))
  }
  lines <- c(lines, "\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.")
  lines <- c(lines, "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")

  writeLines(lines, con = out_file, useBytes = TRUE)
  cat(sprintf("[42] Wrote %s\n", out_file))
}

# --- Load and prepare data ---
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

cp_cells <- build_cp_cells(cfps, delta = 0.5)
cfps_cp <- merge(
  cfps,
  cp_cells[, .(province, wave, mu_cp, sigma_cp, fe_cp, n_hh)],
  by = c("province", "wave"),
  all.x = TRUE
)

cat(sprintf("[42] Full sample: %d obs, %d provinces, %d waves\n",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))
cat(sprintf("[42] CP valid cells: %d / %d\n",
            sum(!is.na(cp_cells$mu_cp)), nrow(cp_cells)))
cat(sprintf("[42] Eq3 CP sample: %d observations\n", sum(!is.na(cfps_cp$fe_cp))))

# --- Eq1: expectations ---
eq1_1 <- feols(price_exp ~ meat_shock, data = cfps, vcov = ~province)
eq1_2 <- feols(price_exp ~ meat_shock + age + edu_high + urban, data = cfps, vcov = ~province)
eq1_3 <- feols(price_exp ~ meat_shock | province_factor + wave_factor, data = cfps, vcov = ~province)
eq1_4 <- feols(price_exp ~ meat_shock | region_wave, data = cfps, vcov = ~province)
eq1_5 <- feols(price_exp ~ meat_shock + age + edu_high + urban | region_wave, data = cfps, vcov = ~province)
eq1_6 <- feols(price_exp ~ meat_shock | province_factor + region_wave, data = cfps, vcov = ~province)
eq1_cols <- lapply(list(eq1_1, eq1_2, eq1_3, eq1_4, eq1_5, eq1_6), format_col)

build_multicolumn_table(
  cols = eq1_cols,
  caption = "Meat Price Shock and Household Inflation Expectations",
  label = "tab:eq1_expectations",
  notes = c(
    "Dependent variable is the ordinal CFPS expectation response (fall/same/rise coded as -1/0/1).",
    "Standard errors are clustered at the province level.",
    "Column (6) is the preferred specification."
  ),
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes", "")),
    list(label = "Province FE", values = c("", "", "Yes", "", "", "Yes")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "", "Yes", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq1_expectations.tex"),
  col_subtitles = c(
    "Bivariate",
    "Demographics",
    "Province + wave FE",
    "Region $\\times$ wave FE",
    "Region $\\times$ wave + demog",
    "Province + region $\\times$ wave FE"
  )
)

# --- Eq2: pass-through ---
prov_wave <- cfps[, .(
  meat_shock = meat_shock[1],
  grain_shock = grain_shock[1],
  egg_shock = egg_shock[1],
  realized_cpi_ann = realized_cpi_ann[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]
prov_wave <- prov_wave[!is.na(realized_cpi_ann)]
prov_wave[, province_factor := as.factor(province)]
prov_wave[, wave_factor := as.factor(wave)]
prov_wave[, region_wave := as.factor(paste0(region, "_", wave))]

eq2_1 <- feols(realized_cpi_ann ~ meat_shock, data = prov_wave, vcov = ~province)
eq2_2 <- feols(realized_cpi_ann ~ meat_shock | province_factor + wave_factor, data = prov_wave, vcov = ~province)
eq2_3 <- feols(realized_cpi_ann ~ meat_shock | region_wave, data = prov_wave, vcov = ~province)
eq2_4 <- feols(realized_cpi_ann ~ meat_shock | province_factor + region_wave, data = prov_wave, vcov = ~province)
eq2_cols <- lapply(list(eq2_1, eq2_2, eq2_3, eq2_4), format_col)

build_multicolumn_table(
  cols = eq2_cols,
  caption = "Meat Price Shock and Realized Headline CPI",
  label = "tab:eq2_cpi_passthrough",
  notes = c(
    "Unit of observation is province $\\times$ wave.",
    "Dependent variable is annualized realized headline CPI over the subsequent inter-wave period.",
    "Standard errors are clustered at the province level. Column (4) is the preferred specification."
  ),
  fe_rows = list(
    list(label = "Province FE", values = c("", "Yes", "", "Yes")),
    list(label = "Wave FE", values = c("", "Yes", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq2_cpi_passthrough.tex"),
  col_subtitles = c("Bivariate", "Province + wave FE", "Region $\\times$ wave FE", "Province + region $\\times$ wave FE")
)

# --- Eq3: CP-based forecast error ---
cfps_fe <- cfps_cp[!is.na(fe_cp)]

eq3_1 <- feols(fe_cp ~ meat_shock, data = cfps_fe, vcov = ~province)
eq3_2 <- feols(fe_cp ~ meat_shock + age + edu_high + urban, data = cfps_fe, vcov = ~province)
eq3_3 <- feols(fe_cp ~ meat_shock | province_factor + wave_factor, data = cfps_fe, vcov = ~province)
eq3_4 <- feols(fe_cp ~ meat_shock | region_wave, data = cfps_fe, vcov = ~province)
eq3_5 <- feols(fe_cp ~ meat_shock + age + edu_high + urban | region_wave, data = cfps_fe, vcov = ~province)
eq3_6 <- feols(fe_cp ~ meat_shock | province_factor + region_wave, data = cfps_fe, vcov = ~province)
eq3_cols <- lapply(list(eq3_1, eq3_2, eq3_3, eq3_4, eq3_5, eq3_6), format_col)

eq3_notes <- c(
  "Dependent variable is the Carlson-Parkin forecast error: realized province-level CPI inflation minus CP-quantified expected inflation (delta = 0.5 percentage points).",
  "Standard errors are clustered at the province level.",
  "Column (6) is the preferred specification."
)

build_multicolumn_table(
  cols = eq3_cols,
  caption = "Meat Price Shock and CP-Based Forecast Errors",
  label = "tab:eq3_forecast_error",
  notes = eq3_notes,
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes", "")),
    list(label = "Province FE", values = c("", "", "Yes", "", "", "Yes")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "", "Yes", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq3_forecast_error.tex"),
  col_subtitles = c(
    "Bivariate",
    "Demographics",
    "Province + wave FE",
    "Region $\\times$ wave FE",
    "Region $\\times$ wave + demog",
    "Province + region $\\times$ wave FE"
  )
)

# Keep appendix compatibility name.
build_multicolumn_table(
  cols = eq3_cols,
  caption = "Meat Price Shock and CP-Based Forecast Errors",
  label = "tab:eq3_carlson_parkin",
  notes = eq3_notes,
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes", "")),
    list(label = "Province FE", values = c("", "", "Yes", "", "", "Yes")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "", "Yes", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq3_carlson_parkin.tex"),
  col_subtitles = c(
    "Bivariate",
    "Demographics",
    "Province + wave FE",
    "Region $\\times$ wave FE",
    "Region $\\times$ wave + demog",
    "Province + region $\\times$ wave FE"
  )
)

# --- Sample ledger and diagnostics artifacts ---
sample_ledger <- data.table(
  sample = c(
    "Household sample after base filters",
    "Province-wave cells with realized CPI",
    "CP-valid province-wave cells",
    "Eq1 estimation sample",
    "Eq2 estimation cells",
    "Eq3 (CP) estimation sample",
    "Eq3 dropped due to missing CP expectation"
  ),
  value = c(
    nrow(cfps),
    nrow(cp_cells),
    sum(!is.na(cp_cells$mu_cp)),
    nrow(cfps),
    nrow(prov_wave),
    nrow(cfps_fe),
    nrow(cfps_cp) - nrow(cfps_fe)
  )
)
fwrite(sample_ledger, file.path(project_paths$tables, "sample_ledger.csv"))
write_booktabs_table(
  sample_ledger,
  file.path(project_paths$tables, "sample_ledger.tex"),
  caption = "Estimation Sample Ledger",
  label = "tab:sample_ledger",
  notes = c("CP means Carlson-Parkin quantification at province-wave level."),
  digits = 0,
  escape = FALSE
)
fwrite(cp_cells, file.path(project_paths$tables, "cp_cell_diagnostics.csv"))

# --- Coefficient summary ---
summary_dt <- rbindlist(list(
  data.table(equation = "Eq1", spec = paste0("Eq1_", 1:6), rbindlist(eq1_cols)),
  data.table(equation = "Eq2", spec = paste0("Eq2_", 1:4), rbindlist(eq2_cols)),
  data.table(equation = "Eq3_CP", spec = paste0("Eq3_", 1:6), rbindlist(eq3_cols))
), use.names = TRUE, fill = TRUE)
fwrite(summary_dt, file.path(project_paths$tables, "eq_summary.csv"))

cat("\n=== KEY RESULTS (Preferred specs) ===\n")
cat(sprintf("Eq1 (col 6): beta = %.4f, se = %.4f, p = %.4f\n",
            eq1_cols[[6]]$beta, eq1_cols[[6]]$se, eq1_cols[[6]]$p))
cat(sprintf("Eq2 (col 4): beta = %.4f, se = %.4f, p = %.4f\n",
            eq2_cols[[4]]$beta, eq2_cols[[4]]$se, eq2_cols[[4]]$p))
cat(sprintf("Eq3 CP (col 6): beta = %.4f, se = %.4f, p = %.4f\n",
            eq3_cols[[6]]$beta, eq3_cols[[6]]$se, eq3_cols[[6]]$p))
cat("[42] Main tables and diagnostics written.\n")
