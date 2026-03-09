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

metrics <- data.table(
  model = c("Naive expectation", "Diagnostic-adjusted policy rule"),
  RMSE = c(sqrt(mean(bt$err_naive^2)), sqrt(mean(bt$err_policy^2))),
  MAE = c(mean(abs(bt$err_naive)), mean(abs(bt$err_policy))),
  Coverage68 = c(mean(bt$covered68_naive), mean(bt$covered68_policy)),
  Coverage90 = c(mean(bt$covered90_naive), mean(bt$covered90_policy)),
  N = nrow(bt)
)

metrics[, RMSE_gain := metrics$RMSE[1] - RMSE]
metrics[, MAE_gain := metrics$MAE[1] - MAE]

write_booktabs_table(
  metrics,
  file.path(project_paths$tables, "policy_backtest_metrics.tex"),
  caption = "Policy Backtest: Forecast Accuracy and Coverage",
  label = "tab:policy_backtest",
  notes = c(
    "The policy rule adjusts survey expectations by predicted diagnostic forecast errors.",
    "Positive RMSE/MAE gains indicate improvement relative to naive forecasts."
  ),
  digits = 3,
  escape = FALSE
)

# Full-sample policy rule coefficients.
f_full <- as.formula(paste("CPI_QoQ_Ann_lead1 - mu_cp ~ FR_cp", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
m_full <- lm(f_full, data = use)
ct_full <- coeftest(m_full, vcov. = NeweyWest(m_full, lag = 4, prewhite = FALSE, adjust = TRUE))

coef_tab <- data.table(term = rownames(ct_full), estimate = ct_full[, 1], se = ct_full[, 2], p_value = ct_full[, 4])
write_booktabs_table(
  coef_tab,
  file.path(project_paths$tables, "policy_rule_formula.tex"),
  caption = "Estimated Policy Rule Parameters",
  label = "tab:policy_rule_formula",
  notes = c("Operational rule: adjusted forecast equals survey expectation plus predicted forecast error."),
  digits = 3,
  escape = FALSE
)

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
    title = "Out-of-Sample Backtest: Policy Rule vs Naive Expectations",
    x = "Quarter",
    y = "Annualized quarterly inflation (pp)",
    color = NULL
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "policy_backtest_path"), width = 8.2, height = 5)

cat("[70] Policy backtest module complete.\n")

