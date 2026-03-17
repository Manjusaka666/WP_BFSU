#!/usr/bin/env Rscript
# 81_regenerate_figures.R
# Regenerate ALL main-text figures with AER/QJE publication theme.
# Fixes: LP IV-dominated scale, beta_t clipped title, axis labels,
#        line weights, font sizes, legend placement.

suppressPackageStartupMessages({
  library(data.table)
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
panel[, qdate := as.Date(parse_quarter(quarter), frac = 1)]

# ── Colour palette (Okabe-Ito, colour-blind safe) ──────────────
col_blue   <- "#0072B2"
col_red    <- "#D55E00"
col_sky    <- "#56B4E9"
col_orange <- "#E69F00"
col_grey   <- "grey50"

# ================================================================
# Figure 1: Expectations vs realized inflation
# ================================================================
df1 <- panel[!is.na(mu_cp) & !is.na(CPI_QoQ_Ann)]
p1 <- ggplot(df1, aes(x = qdate)) +
  geom_line(aes(y = mu_cp, colour = "Quantified expectation"),
            linewidth = 0.75) +
  geom_line(aes(y = CPI_QoQ_Ann, colour = "Realized inflation (QoQ ann.)"),
            linewidth = 0.55, linetype = "dashed") +
  scale_colour_manual(values = c("Quantified expectation" = col_blue,
                                 "Realized inflation (QoQ ann.)" = col_red)) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(x = NULL, y = "Percentage points", colour = NULL) +
  theme_pub()
save_plot_pair(p1, file.path(project_paths$figures, "expectations_vs_realized"))
cat("  [1] expectations_vs_realized\n")

# ================================================================
# Figure 2: Revision-error dynamics
# ================================================================
df2 <- panel[!is.na(FR_cp) & !is.na(FE_next_cp)]
p2 <- ggplot(df2, aes(x = qdate)) +
  geom_col(aes(y = FR_cp, fill = "Forecast revision"),
           alpha = 0.35, width = 60) +
  geom_line(aes(y = FE_next_cp, colour = "Next-quarter forecast error"),
            linewidth = 0.75) +
  scale_fill_manual(values = c("Forecast revision" = col_sky)) +
  scale_colour_manual(values = c("Next-quarter forecast error" = col_red)) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(x = NULL, y = "Percentage points", fill = NULL, colour = NULL) +
  theme_pub()
save_plot_pair(p2, file.path(project_paths$figures, "revision_error_dynamics"))
cat("  [2] revision_error_dynamics\n")

# ================================================================
# Figure 3: Uncertainty and salience states
# ================================================================
df3 <- panel[!is.na(epu_qavg) & !is.na(gpr_qavg) & !is.na(msi_raw)]
df3[, epu_z := as.numeric(scale(epu_qavg))]
df3[, gpr_z := as.numeric(scale(gpr_qavg))]
df3[, msi_z := as.numeric(scale(msi_raw))]

p3 <- ggplot(df3, aes(x = qdate)) +
  geom_line(aes(y = epu_z, colour = "EPU"), linewidth = 0.65) +
  geom_line(aes(y = gpr_z, colour = "GPR"), linewidth = 0.65) +
  geom_line(aes(y = msi_z, colour = "Salience index"),
            linewidth = 0.75, linetype = "dashed") +
  scale_colour_manual(values = c("EPU" = col_blue, "GPR" = col_orange,
                                 "Salience index" = "grey20")) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(x = NULL, y = "Standardised z-score", colour = NULL) +
  theme_pub()
save_plot_pair(p3, file.path(project_paths$figures, "uncertainty_salience_states"))
cat("  [3] uncertainty_salience_states\n")

# ================================================================
# Figure 4: LP — Forecast-error response (OLS only)
# ================================================================
lp_file <- file.path(project_paths$robustness, "lp_dynamic_coefficients.csv")
if (file.exists(lp_file)) {
  lp <- fread(lp_file)

  # OLS forecast-error response only (IV bands dominate scale)
  lp_fe_ols <- lp[outcome == "Forecast error" & model == "OLS LP"]
  p4 <- ggplot(lp_fe_ols, aes(x = h, y = beta)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = col_grey, linewidth = 0.3) +
    geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = col_sky, alpha = 0.25) +
    geom_line(colour = col_blue, linewidth = 0.75) +
    geom_point(colour = col_blue, size = 1.8) +
    scale_x_continuous(breaks = 0:8) +
    labs(x = "Horizon (quarters)", y = expression(hat(beta)[h])) +
    theme_pub()
  save_plot_pair(p4, file.path(project_paths$figures, "lp_forecast_error"))
  cat("  [4] lp_forecast_error\n")

  # OLS inflation response only
  lp_pi_ols <- lp[outcome == "Realized inflation" & model == "OLS LP"]
  p5 <- ggplot(lp_pi_ols, aes(x = h, y = beta)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = col_grey, linewidth = 0.3) +
    geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = col_orange, alpha = 0.20) +
    geom_line(colour = col_red, linewidth = 0.75) +
    geom_point(colour = col_red, size = 1.8) +
    scale_x_continuous(breaks = 0:8) +
    labs(x = "Horizon (quarters)", y = expression(hat(beta)[h])) +
    theme_pub()
  save_plot_pair(p5, file.path(project_paths$figures, "lp_inflation"))
  cat("  [5] lp_inflation\n")
} else {
  cat("  SKIP LP figures (no coefficient file)\n")
}

# ================================================================
# Figure 5: First-stage scatter (identification)
# ================================================================
if (all(c("msi_raw", "media_congestion_iv") %in% names(panel))) {
  df5 <- panel[!is.na(msi_raw) & !is.na(media_congestion_iv)]
  p6 <- ggplot(df5, aes(x = media_congestion_iv, y = msi_raw)) +
    geom_smooth(method = "lm", se = TRUE, colour = col_red,
                fill = col_orange, alpha = 0.18, linewidth = 0.65) +
    geom_point(colour = col_blue, size = 2, alpha = 0.7) +
    labs(x = "Media congestion instrument (standardised)",
         y = "Inflation salience index (standardised)") +
    theme_pub()
  save_plot_pair(p6, file.path(project_paths$figures, "identification_first_stage"))
  cat("  [6] identification_first_stage\n")
}

# ================================================================
# Figure 6: Heterogeneity by salience tercile
# ================================================================
if ("salience_tercile" %in% names(panel)) {
  het_data <- panel[!is.na(salience_tercile) & !is.na(FR_cp) & !is.na(FE_next_cp)]
  het_results <- het_data[, {
    if (.N >= 8) {
      m <- lm(FE_next_cp ~ FR_cp)
      ct <- coeftest(m, vcov. = sandwich::NeweyWest(m, lag = 4, prewhite = FALSE, adjust = TRUE))
      list(beta = ct["FR_cp", 1], se = ct["FR_cp", 2])
    } else {
      list(beta = NA_real_, se = NA_real_)
    }
  }, by = salience_tercile]
  het_results[, ci_lo := beta - 1.96 * se]
  het_results[, ci_hi := beta + 1.96 * se]
  het_results[, label := factor(salience_tercile, levels = 1:3,
    labels = c("Low salience", "Mid salience", "High salience"))]

  p7 <- ggplot(het_results, aes(x = label, y = beta)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = col_grey, linewidth = 0.3) +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15,
                  colour = col_blue, linewidth = 0.5) +
    geom_point(size = 3, colour = col_blue) +
    labs(x = "Salience tercile", y = expression(hat(beta)~"(revision coefficient)")) +
    theme_pub()
  save_plot_pair(p7, file.path(project_paths$figures, "heterogeneity_salience"))
  cat("  [7] heterogeneity_salience\n")
}

# ================================================================
# Figure 7: Mechanism revision-error scatter
# ================================================================
if (all(c("FR_cp", "FE_next_cp", "epu_qavg") %in% names(panel))) {
  df7 <- panel[!is.na(FR_cp) & !is.na(FE_next_cp) & !is.na(epu_qavg)]
  df7[, epu_state := ifelse(epu_qavg > median(epu_qavg, na.rm = TRUE),
                            "High EPU", "Low EPU")]
  p8 <- ggplot(df7, aes(x = FR_cp, y = FE_next_cp, colour = epu_state)) +
    geom_point(size = 2, alpha = 0.7) +
    geom_smooth(method = "lm", se = FALSE, linewidth = 0.65) +
    scale_colour_manual(values = c("Low EPU" = col_sky, "High EPU" = col_red)) +
    labs(x = "Forecast revision", y = "Next-quarter forecast error",
         colour = NULL) +
    theme_pub()
  save_plot_pair(p8, file.path(project_paths$figures, "mechanism_revision_error"))
  cat("  [8] mechanism_revision_error\n")
}

# ================================================================
# Figure 8: Policy backtest paths
# ================================================================
bt_file <- file.path(project_paths$robustness, "policy_backtest_paths.csv")
if (!file.exists(bt_file)) bt_file <- file.path(project_paths$processed, "policy_backtest_paths.csv")
if (file.exists(bt_file)) {
  bt <- fread(bt_file)
  bt[, qdate := as.Date(parse_quarter(quarter), frac = 1)]

  p9 <- ggplot(bt, aes(x = qdate)) +
    geom_line(aes(y = realized, colour = "Realized inflation"),
              linewidth = 0.75) +
    geom_line(aes(y = naive_forecast, colour = "Naive survey forecast"),
              linewidth = 0.55, linetype = "dashed") +
    geom_line(aes(y = adjusted_forecast, colour = "Diagnostic-adjusted"),
              linewidth = 0.65, linetype = "dotdash") +
    scale_colour_manual(values = c("Realized inflation" = "grey20",
                                   "Naive survey forecast" = col_sky,
                                   "Diagnostic-adjusted" = col_red)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(x = NULL, y = "Annualised quarterly inflation (pp)", colour = NULL) +
    theme_pub()
  save_plot_pair(p9, file.path(project_paths$figures, "policy_backtest_path"))
  cat("  [9] policy_backtest_path\n")
}

# ================================================================
# Figure 9: beta_t path (Bayesian state-space)
# ================================================================
beta_file <- file.path(project_paths$tables, "beta_t_path.csv")
if (file.exists(beta_file)) {
  beta_dt <- fread(beta_file)
  if ("quarter" %in% names(beta_dt)) {
    beta_dt[, qdate := as.Date(parse_quarter(quarter), frac = 1)]
    x_col <- "qdate"
    x_lab <- NULL
    x_scale <- scale_x_date(date_breaks = "2 years", date_labels = "%Y")
  } else {
    beta_dt[, idx := .I]
    x_col <- "idx"
    x_lab <- "Quarter"
    x_scale <- NULL
  }

  # Guess column names
  mean_col <- intersect(names(beta_dt), c("beta_mean", "mean", "posterior_mean"))[1]
  lo68_col <- intersect(names(beta_dt), c("ci68_lo", "q16", "lo68", "p16"))[1]
  hi68_col <- intersect(names(beta_dt), c("ci68_hi", "q84", "hi68", "p84"))[1]
  lo90_col <- intersect(names(beta_dt), c("ci90_lo", "q05", "lo90", "p05", "ci95_lo"))[1]
  hi90_col <- intersect(names(beta_dt), c("ci90_hi", "q95", "hi90", "p95", "ci95_hi"))[1]

  if (!is.na(mean_col)) {
    p10 <- ggplot(beta_dt, aes_string(x = x_col))
    if (!is.na(lo90_col) && !is.na(hi90_col)) {
      p10 <- p10 + geom_ribbon(aes_string(ymin = lo90_col, ymax = hi90_col),
                                fill = col_sky, alpha = 0.18)
    }
    if (!is.na(lo68_col) && !is.na(hi68_col)) {
      p10 <- p10 + geom_ribbon(aes_string(ymin = lo68_col, ymax = hi68_col),
                                fill = col_sky, alpha = 0.35)
    }
    p10 <- p10 +
      geom_hline(yintercept = 0, linetype = "dotted", colour = col_grey, linewidth = 0.3) +
      geom_line(aes_string(y = mean_col), colour = col_blue, linewidth = 0.7) +
      labs(x = x_lab, y = expression(beta[t]~"(posterior mean)")) +
      theme_pub()
    if (!is.null(x_scale)) p10 <- p10 + x_scale
    save_plot_pair(p10, file.path(project_paths$figures, "beta_t"))
    cat("  [10] beta_t\n")
  }
}

cat("[81] All figures regenerated.\n")
