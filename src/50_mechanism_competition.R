#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
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

panel[, FE_lag := shift(FE_next_cp, 1, type = "lag")]
panel[, high_epu := as.integer(epu_qavg > median(epu_qavg, na.rm = TRUE))]

controls <- c("Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate")
controls <- controls[controls %in% names(panel)]

need <- c("FE_next_cp", "FR_cp", "FE_lag", "high_epu", controls)
use <- panel[complete.cases(panel[, ..need])]
if (nrow(use) < 25) stop("Insufficient observations for mechanism competition.")

run_nw <- function(formula, data) {
  m <- lm(formula, data = data)
  ct <- coeftest(m, vcov. = NeweyWest(m, lag = 4, prewhite = FALSE, adjust = TRUE))
  list(model = m, ct = ct)
}

f_diag <- as.formula(paste("FE_next_cp ~ FR_cp", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
f_cg <- as.formula(paste("FE_next_cp ~ FE_lag", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
f_horse <- as.formula(paste("FE_next_cp ~ FR_cp + FE_lag", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
f_state <- as.formula(paste("FE_next_cp ~ FR_cp + FR_cp:high_epu + FE_lag + high_epu", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))

m_diag <- run_nw(f_diag, use)
m_cg <- run_nw(f_cg, use)
m_horse <- run_nw(f_horse, use)
m_state <- run_nw(f_state, use)

get_coef <- function(obj, name) {
  ct <- obj$ct
  if (!name %in% rownames(ct)) return(c(NA_real_, NA_real_, NA_real_))
  c(ct[name, "Estimate"], ct[name, "Std. Error"], ct[name, "Pr(>|t|)"])
}

hr <- data.table(
  specification = c("Diagnostic-only", "Information-rigidity-only", "Horse race", "Horse race + state dependence"),
  beta_revision = c(get_coef(m_diag, "FR_cp")[1], NA_real_, get_coef(m_horse, "FR_cp")[1], get_coef(m_state, "FR_cp")[1]),
  se_revision = c(get_coef(m_diag, "FR_cp")[2], NA_real_, get_coef(m_horse, "FR_cp")[2], get_coef(m_state, "FR_cp")[2]),
  p_revision = c(get_coef(m_diag, "FR_cp")[3], NA_real_, get_coef(m_horse, "FR_cp")[3], get_coef(m_state, "FR_cp")[3]),
  beta_lag_error = c(NA_real_, get_coef(m_cg, "FE_lag")[1], get_coef(m_horse, "FE_lag")[1], get_coef(m_state, "FE_lag")[1]),
  se_lag_error = c(NA_real_, get_coef(m_cg, "FE_lag")[2], get_coef(m_horse, "FE_lag")[2], get_coef(m_state, "FE_lag")[2]),
  p_lag_error = c(NA_real_, get_coef(m_cg, "FE_lag")[3], get_coef(m_horse, "FE_lag")[3], get_coef(m_state, "FE_lag")[3]),
  beta_revision_high_epu = c(NA_real_, NA_real_, NA_real_, get_coef(m_state, "FR_cp:high_epu")[1]),
  se_revision_high_epu = c(NA_real_, NA_real_, NA_real_, get_coef(m_state, "FR_cp:high_epu")[2]),
  p_revision_high_epu = c(NA_real_, NA_real_, NA_real_, get_coef(m_state, "FR_cp:high_epu")[3]),
  n = c(nobs(m_diag$model), nobs(m_cg$model), nobs(m_horse$model), nobs(m_state$model))
)

coef_cell <- function(b, p) if (is.na(b)) "" else fmt_coef(b, p, digits = 3)
se_cell <- function(s) if (is.na(s)) "" else fmt_se(s, digits = 3)
col_labels <- c("Diagnostic", "Rigidity", "Joint", "Joint + state")

hr_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Mechanism Competition: Diagnostic Expectations vs Information Rigidity}",
  "\\label{tab:mechanism_horse_race}",
  "{\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{4}{c}{Dependent variable: $FE_{t+1}$} \\\\",
  "\\cmidrule(lr){2-5}",
  paste0(" & ", paste(sprintf("(%d) %s", seq_along(col_labels), col_labels), collapse = " & "), " \\\\"),
  "\\midrule",
  paste0("$\\beta_1$ on $FR_t$ & ",
         paste(mapply(coef_cell, hr$beta_revision, hr$p_revision), collapse = " & "),
         " \\\\"),
  paste0(" & ",
         paste(mapply(se_cell, hr$se_revision), collapse = " & "),
         " \\\\"),
  "\\addlinespace",
  paste0("$\\lambda$ on $FE_t$ & ",
         paste(mapply(coef_cell, hr$beta_lag_error, hr$p_lag_error), collapse = " & "),
         " \\\\"),
  paste0(" & ",
         paste(mapply(se_cell, hr$se_lag_error), collapse = " & "),
         " \\\\"),
  "\\addlinespace",
  paste0("$\\beta_2$ on $FR_t \\times D_t^{high}$ & ",
         paste(mapply(coef_cell, hr$beta_revision_high_epu, hr$p_revision_high_epu), collapse = " & "),
         " \\\\"),
  paste0(" & ",
         paste(mapply(se_cell, hr$se_revision_high_epu), collapse = " & "),
         " \\\\"),
  "\\addlinespace",
  paste0("Observations & ", paste(hr$n, collapse = " & "), " \\\\"),
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
writeLines(hr_lines, file.path(project_paths$tables, "mechanism_horse_race.tex"), useBytes = TRUE)

# Core diagnostic chain: revision predicts subsequent forecast error.
chain <- use[, .(
  quarter,
  FR_cp,
  FE_next_cp,
  high_epu
)]
chain[, FR_bin := cut(FR_cp, breaks = quantile(FR_cp, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE), include.lowest = TRUE)]
chain_tab <- chain[, .(mean_FE = mean(FE_next_cp), n = .N), by = FR_bin]
write_booktabs_table(
  chain_tab,
  file.path(project_paths$tables, "revision_predicts_error.tex"),
  caption = "Diagnostic Chain: Revision Predicts Subsequent Forecast Error",
  label = "tab:revision_predicts_error",
  notes = c("More positive revisions should map into more negative subsequent errors under diagnostic expectations."),
  digits = 3,
  escape = FALSE
)

p <- ggplot(chain, aes(x = FR_cp, y = FE_next_cp, color = factor(high_epu))) +
  geom_point(size = 2, alpha = 0.75) +
  geom_smooth(method = "lm", se = FALSE) +
  scale_color_manual(values = c(okabe_ito[["sky_blue"]], okabe_ito[["vermillion"]]), labels = c("Low EPU", "High EPU")) +
  labs(
    x = "Forecast revision",
    y = "Next-quarter forecast error",
    color = NULL
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "mechanism_revision_error"), width = 6.5, height = 5)

cat("[50] Mechanism competition module complete.\n")

