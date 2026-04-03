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

controls <- c("Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate")
controls <- controls[controls %in% names(panel)]

need <- c("quarter", "mu_cp", "FR_cp", "CPI_QoQ_Ann_lead1", controls)
use <- panel[complete.cases(panel[, ..need])]
if (nrow(use) < 30) stop("Insufficient observations for policy backtest.")

window <- max(20L, floor(nrow(use) * 0.5))
res <- vector("list", length = nrow(use) - window)

for (i in seq.int(window + 1, nrow(use))) {
  train <- use[(i - window):(i - 1)]
  test <- use[i]

  f <- as.formula(paste("CPI_QoQ_Ann_lead1 - mu_cp ~ FR_cp", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
  m <- lm(f, data = train)
  pred_fe <- predict(m, newdata = test)

  yhat_policy <- test$mu_cp + pred_fe
  yhat_naive <- test$mu_cp
  y_true <- test$CPI_QoQ_Ann_lead1

  sigma_policy <- sd(residuals(m), na.rm = TRUE)
  sigma_naive <- sd(train$CPI_QoQ_Ann_lead1 - train$mu_cp, na.rm = TRUE)

  res[[i - window]] <- data.table(
    quarter = test$quarter,
    actual = y_true,
    forecast_naive = yhat_naive,
    forecast_policy = yhat_policy,
    err_naive = y_true - yhat_naive,
    err_policy = y_true - yhat_policy,
    covered68_naive = as.integer(y_true >= yhat_naive - sigma_naive & y_true <= yhat_naive + sigma_naive),
    covered68_policy = as.integer(y_true >= yhat_policy - sigma_policy & y_true <= yhat_policy + sigma_policy),
    covered90_naive = as.integer(y_true >= yhat_naive - 1.645 * sigma_naive & y_true <= yhat_naive + 1.645 * sigma_naive),
    covered90_policy = as.integer(y_true >= yhat_policy - 1.645 * sigma_policy & y_true <= yhat_policy + 1.645 * sigma_policy)
  )
}

bt <- rbindlist(res)
fwrite(bt, file.path(project_paths$robustness, "policy_backtest.csv"))

rmse_naive <- sqrt(mean(bt$err_naive^2))
rmse_policy <- sqrt(mean(bt$err_policy^2))
mae_naive <- mean(abs(bt$err_naive))
mae_policy <- mean(abs(bt$err_policy))
cov68_naive <- mean(bt$covered68_naive)
cov68_policy <- mean(bt$covered68_policy)
cov90_naive <- mean(bt$covered90_naive)
cov90_policy <- mean(bt$covered90_policy)

metrics_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Policy Backtest: Forecast Accuracy and Coverage}",
  "\\label{tab:policy_backtest}",
  "{\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  "Metric & Naive forecast & Diagnostic-adjusted forecast \\\\",
  "\\midrule",
  paste0("$\\mathrm{RMSE}$ & ", formatC(rmse_naive, digits = 3, format = "f"), " & ", formatC(rmse_policy, digits = 3, format = "f"), " \\\\"),
  paste0("$\\mathrm{MAE}$ & ", formatC(mae_naive, digits = 3, format = "f"), " & ", formatC(mae_policy, digits = 3, format = "f"), " \\\\"),
  paste0("$\\mathrm{Coverage}_{68\\%}$ & ", formatC(cov68_naive, digits = 3, format = "f"), " & ", formatC(cov68_policy, digits = 3, format = "f"), " \\\\"),
  paste0("$\\mathrm{Coverage}_{90\\%}$ & ", formatC(cov90_naive, digits = 3, format = "f"), " & ", formatC(cov90_policy, digits = 3, format = "f"), " \\\\"),
  "\\addlinespace",
  paste0("$\\Delta\\mathrm{RMSE}$ (naive $-$ adjusted) &  & ", formatC(rmse_naive - rmse_policy, digits = 3, format = "f"), " \\\\"),
  paste0("$\\Delta\\mathrm{MAE}$ (naive $-$ adjusted) &  & ", formatC(mae_naive - mae_policy, digits = 3, format = "f"), " \\\\"),
  paste0("Observations & ", nrow(bt), " & ", nrow(bt), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item \\textit{Notes:} The policy rule adjusts survey expectations by predicted diagnostic forecast errors. This is a deterministic backtest table, so no hypothesis-test rows are reported.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(metrics_lines, file.path(project_paths$tables, "policy_backtest_metrics.tex"), useBytes = TRUE)

# Full-sample policy rule coefficients.
f_full <- as.formula(paste("CPI_QoQ_Ann_lead1 - mu_cp ~ FR_cp", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
m_full <- lm(f_full, data = use)
ct_full <- coeftest(m_full, vcov. = NeweyWest(m_full, lag = 4, prewhite = FALSE, adjust = TRUE))

coef_terms <- rownames(ct_full)
coef_labels <- c(
  "(Intercept)" = "$\\alpha$",
  "FR_cp" = "$\\beta_{FR}$",
  "Food_CPI_YoY_qavg" = "$\\gamma_{\\text{Food CPI}}$",
  "M2_YoY" = "$\\gamma_{M2}$",
  "PPI_YoY_rate" = "$\\gamma_{\\text{PPI}}$"
)

coef_cell <- function(b, p) fmt_coef(b, p, digits = 3)
se_cell <- function(s) fmt_se(s, digits = 3)

coef_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Estimated Policy Rule Parameters}",
  "\\label{tab:policy_rule_formula}",
  "{\\small",
  "\\begin{tabular}{lc}",
  "\\toprule",
  "Parameter & Estimate \\\\",
  "\\midrule"
)

for (term in coef_terms) {
  lab <- if (term %in% names(coef_labels)) coef_labels[[term]] else paste0("$", term, "$")
  coef_lines <- c(
    coef_lines,
    paste0(lab, " & ", coef_cell(ct_full[term, 1], ct_full[term, 4]), " \\\\"),
    paste0(" & ", se_cell(ct_full[term, 2]), " \\\\")
  )
}

coef_lines <- c(
  coef_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item \\textit{Notes:} Operational rule: adjusted forecast equals survey expectation plus predicted forecast error. Newey--West HAC standard errors (4 lags) are in parentheses.",
  "\\item $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(coef_lines, file.path(project_paths$tables, "policy_rule_formula.tex"), useBytes = TRUE)

p <- ggplot(bt, aes(x = parse_quarter(quarter))) +
  geom_line(aes(y = actual, color = "Actual inflation"), linewidth = 1) +
  geom_line(aes(y = forecast_naive, color = "Naive forecast"), linewidth = 0.9, linetype = "dashed") +
  geom_line(aes(y = forecast_policy, color = "Policy-adjusted forecast"), linewidth = 0.9) +
  scale_color_manual(values = c(
    "Actual inflation" = okabe_ito[["black"]],
    "Naive forecast" = okabe_ito[["sky_blue"]],
    "Policy-adjusted forecast" = okabe_ito[["vermillion"]]
  )) +
  labs(
    x = "Quarter",
    y = "Annualized quarterly inflation (pp)",
    color = NULL
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "policy_backtest_path"), width = 8.2, height = 5)

cat("[70] Policy backtest module complete.\n")

