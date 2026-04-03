#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(lmtest)
  library(sandwich)
  library(ggplot2)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

panel_file <- file.path(project_paths$processed, "panel_quarterly.csv")
if (!file.exists(panel_file)) panel_file <- file.path(project_paths$processed, "panel_quarterly.parquet")

panel <- if (grepl("parquet$", panel_file)) as.data.table(arrow::read_parquet(panel_file)) else fread(panel_file)
panel[, q_order := as.numeric(parse_quarter(quarter))]
setorder(panel, q_order)
panel[, q_order := NULL]
panel[, t_id := .I]

controls <- c("Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate", "CPI_YoY_rate")
controls <- controls[controls %in% names(panel)]

need <- c("FE_next_cp", "FR_cp", "msi_raw", "media_congestion_iv", controls)
use <- panel[complete.cases(panel[, ..need])]
if (nrow(use) < 25) stop("Insufficient observations for identification analysis.")

# First-stage relevance.
fs_formula <- as.formula(paste("msi_raw ~ media_congestion_iv", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
fs_lm <- lm(fs_formula, data = use)
fs_ct <- coeftest(fs_lm, vcov. = NeweyWest(fs_lm, lag = 4, prewhite = FALSE, adjust = TRUE))

fs_beta <- unname(fs_ct["media_congestion_iv", "Estimate"])
fs_se <- unname(fs_ct["media_congestion_iv", "Std. Error"])
fs_t <- unname(fs_ct["media_congestion_iv", "t value"])
fs_p <- unname(fs_ct["media_congestion_iv", "Pr(>|t|)"])
fs_F <- fs_t^2

# Reduced form and 2SLS models.
rf_formula <- as.formula(paste("FE_next_cp ~ media_congestion_iv", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
rf <- feols(rf_formula, data = use)
rf_ct <- coeftable(rf, vcov = NW ~ t_id)

iv_rev_formula <- as.formula(paste("FR_cp ~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| msi_raw ~ media_congestion_iv"))
iv_rev <- feols(iv_rev_formula, data = use)
iv_rev_ct <- coeftable(iv_rev, vcov = NW ~ t_id)
iv_rev_row <- grep("^fit_", rownames(iv_rev_ct), value = TRUE)[1]

iv_fe_formula <- as.formula(paste("FE_next_cp ~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| FR_cp ~ media_congestion_iv"))
iv_fe <- feols(iv_fe_formula, data = use)
iv_fe_ct <- coeftable(iv_fe, vcov = NW ~ t_id)
iv_fe_row <- grep("^fit_", rownames(iv_fe_ct), value = TRUE)[1]

# Weak-IV robust interval (Anderson-Rubin style inversion).
ar_confint <- function(dat, y, x, z, controls, lag = 4, grid = seq(-3, 3, by = 0.01)) {
  rhs <- c(z, controls)
  form <- as.formula(paste("u_beta ~", paste(rhs, collapse = " + ")))
  accepted <- logical(length(grid))

  for (i in seq_along(grid)) {
    b0 <- grid[i]
    dat[, u_beta := get(y) - b0 * get(x)]
    m <- lm(form, data = dat)
    ct <- coeftest(m, vcov. = NeweyWest(m, lag = lag, prewhite = FALSE, adjust = TRUE))
    t_val <- ct[z, "t value"]
    accepted[i] <- abs(t_val) <= 1.96
  }

  if (!any(accepted)) return(c(NA_real_, NA_real_))
  c(min(grid[accepted]), max(grid[accepted]))
}

ar_ci <- ar_confint(copy(use), y = "FE_next_cp", x = "FR_cp", z = "media_congestion_iv", controls = controls)

# Placebo 1: pseudo instruments by permutation.
set.seed(123)
placebo_n <- 300L
placebo_beta <- numeric(placebo_n)
for (i in seq_len(placebo_n)) {
  use[, fake_iv := sample(media_congestion_iv)]
  m_fake <- feols(as.formula(paste("FE_next_cp ~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| FR_cp ~ fake_iv")), data = use)
  ct_fake <- coeftable(m_fake, vcov = NW ~ t_id)
  row_fake <- grep("^fit_", rownames(ct_fake), value = TRUE)[1]
  placebo_beta[i] <- ct_fake[row_fake, "Estimate"]
}

# Placebo 2: non-target outcome.
placebo_outcome <- if ("employment_expectation_index" %in% names(use)) "employment_expectation_index" else if ("Ind_Value_Added_YoY" %in% names(use)) "Ind_Value_Added_YoY" else NA_character_
if (!is.na(placebo_outcome)) {
  y_placebo_formula <- as.formula(paste(placebo_outcome, "~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| FR_cp ~ media_congestion_iv"))
  m_placebo_y <- feols(y_placebo_formula, data = use)
  ct_placebo_y <- coeftable(m_placebo_y, vcov = NW ~ t_id)
  row_placebo_y <- grep("^fit_", rownames(ct_placebo_y), value = TRUE)[1]
  pbo_beta <- ct_placebo_y[row_placebo_y, "Estimate"]
  pbo_se <- ct_placebo_y[row_placebo_y, "Std. Error"]
  pbo_p <- ct_placebo_y[row_placebo_y, "Pr(>|t|)"]
} else {
  pbo_beta <- NA_real_
  pbo_se <- NA_real_
  pbo_p <- NA_real_
}

# Anticipation test: future revision should not predict current error.
use[, FR_lead := shift(FR_cp, n = 1, type = "lead")]
ant <- use[!is.na(FR_lead)]
if (nrow(ant) > 20) {
  ant_formula <- as.formula(paste("FE_next_cp ~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| FR_lead ~ media_congestion_iv"))
  m_ant <- feols(ant_formula, data = ant)
  ct_ant <- coeftable(m_ant, vcov = NW ~ t_id)
  row_ant <- grep("^fit_", rownames(ct_ant), value = TRUE)[1]
  ant_beta <- ct_ant[row_ant, "Estimate"]
  ant_p <- ct_ant[row_ant, "Pr(>|t|)"]
} else {
  ant_beta <- NA_real_
  ant_p <- NA_real_
}

# Main identification table in top-field regression style:
# coefficient with stars + standard error row; no p-value rows.
coef_cell <- function(b, p) if (is.na(b)) "" else fmt_coef(b, p, digits = 3)
se_cell <- function(s) if (is.na(s)) "" else fmt_se(s, digits = 3)

iv_rev_beta <- iv_rev_ct[iv_rev_row, "Estimate"]
iv_rev_se <- iv_rev_ct[iv_rev_row, "Std. Error"]
iv_rev_p <- iv_rev_ct[iv_rev_row, "Pr(>|t|)"]

iv_fe_beta <- iv_fe_ct[iv_fe_row, "Estimate"]
iv_fe_se <- iv_fe_ct[iv_fe_row, "Std. Error"]
iv_fe_p <- iv_fe_ct[iv_fe_row, "Pr(>|t|)"]

rf_beta <- rf_ct["media_congestion_iv", "Estimate"]
rf_se <- rf_ct["media_congestion_iv", "Std. Error"]
rf_p <- rf_ct["media_congestion_iv", "Pr(>|t|)"]

id_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Salience-IV Identification: Main Coefficients}",
  "\\label{tab:identification_main}",
  "{\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{1}{c}{(1)} & \\multicolumn{1}{c}{(2)} & \\multicolumn{1}{c}{(3)} & \\multicolumn{1}{c}{(4)} \\\\",
  " & $S_t$ on $Z_t^{cong}$ & $\\Delta\\mu_t$ on $\\widehat{S}_t$ & $FE_{t+1}$ on $\\widehat{\\Delta\\mu}_t$ & $FE_{t+1}$ on $Z_t^{cong}$ \\\\",
  "\\midrule",
  paste0("$Z_t^{cong}$ & ", coef_cell(fs_beta, fs_p), " &  &  & ", coef_cell(rf_beta, rf_p), " \\\\"),
  paste0(" & ", se_cell(fs_se), " &  &  & ", se_cell(rf_se), " \\\\"),
  "\\addlinespace",
  paste0("$\\widehat{S}_t$ &  & ", coef_cell(iv_rev_beta, iv_rev_p), " &  &  \\\\"),
  paste0(" &  & ", se_cell(iv_rev_se), " &  &  \\\\"),
  "\\addlinespace",
  paste0("$\\widehat{\\Delta\\mu}_t$ &  &  & ", coef_cell(iv_fe_beta, iv_fe_p), " &  \\\\"),
  paste0(" &  &  & ", se_cell(iv_fe_se), " &  \\\\"),
  "\\addlinespace",
  paste0("Observations & ", nrow(use), " & ", nrow(use), " & ", nrow(use), " & ", nrow(use), " \\\\"),
  "Macro controls & $\\checkmark$ & $\\checkmark$ & $\\checkmark$ & $\\checkmark$ \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item \\textit{Notes:} Newey--West HAC standard errors (4 lags) are in parentheses. Coefficients carry significance stars only; no standalone $p$-value rows are reported.",
  "\\item $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(id_lines, file.path(project_paths$tables, "identification_main.tex"), useBytes = TRUE)

# Weak-IV diagnostics table (no t-statistic reporting).
weak_tab <- data.table(
  statistic = c("First-stage Wald $F$", "Kleibergen--Paap rk Wald $F$", "AR-type 95\\% CI (lower)", "AR-type 95\\% CI (upper)"),
  value = c(fs_F, fs_F, ar_ci[1], ar_ci[2])
)
write_booktabs_table(
  weak_tab,
  file.path(project_paths$tables, "iv_first_stage.tex"),
  caption = "Instrument Strength and Weak-IV Robust Inference",
  label = "tab:iv_first_stage",
  notes = c(
    "For one endogenous regressor and one instrument, the robust Wald F and KP rk Wald F coincide asymptotically.",
    "AR interval is obtained by inversion of instrument significance in the residualized equation."
  ),
  digits = 3,
  escape = FALSE
)

# Placebo table without p-value columns.
placebo_mean <- mean(placebo_beta, na.rm = TRUE)
placebo_q025 <- quantile(placebo_beta, 0.025, na.rm = TRUE)
placebo_q975 <- quantile(placebo_beta, 0.975, na.rm = TRUE)

placebo_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Falsification and Placebo Checks}",
  "\\label{tab:placebo_tests}",
  "{\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Coefficient & Std. error \\\\",
  "\\midrule",
  paste0("$\\text{Permuted IV mean}$ & $", formatC(placebo_mean, format = "f", digits = 3), "$ &  \\\\"),
  paste0("$\\text{Permuted IV }2.5\\%$ & $", formatC(placebo_q025, format = "f", digits = 3), "$ &  \\\\"),
  paste0("$\\text{Permuted IV }97.5\\%$ & $", formatC(placebo_q975, format = "f", digits = 3), "$ &  \\\\"),
  "\\addlinespace",
  paste0("$\\text{Placebo outcome}$ & ", coef_cell(pbo_beta, pbo_p), " & ", se_cell(pbo_se), " \\\\"),
  paste0("$\\text{Lead revision (anticipation)}$ & ", coef_cell(ant_beta, ant_p), " &  \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item \\textit{Notes:} Permutation placebo reassigns the instrument across quarters (300 draws). Coefficients carry significance stars only.",
  "\\item $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(placebo_lines, file.path(project_paths$tables, "placebo_tests.tex"), useBytes = TRUE)

# Plot first-stage relation.
p <- ggplot(use, aes(x = media_congestion_iv, y = msi_raw)) +
  geom_point(color = okabe_ito[["blue"]], size = 2.2, alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = okabe_ito[["vermillion"]], fill = okabe_ito[["orange"]], alpha = 0.2) +
  labs(
    x = "News Congestion Instrument (higher = lower inflation salience)",
    y = "Inflation Salience Index"
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "identification_first_stage"), width = 6.5, height = 5)

cat("[35] Identification module complete.\n")

