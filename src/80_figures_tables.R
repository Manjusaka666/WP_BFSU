#!/usr/bin/env Rscript

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

# Figure 1: expectations vs realized inflation.
df1 <- panel[!is.na(mu_cp) & !is.na(CPI_QoQ_Ann)]
p1 <- ggplot(df1, aes(x = qdate)) +
  geom_line(aes(y = mu_cp, color = "Quantified expectation"), linewidth = 1) +
  geom_line(aes(y = CPI_QoQ_Ann, color = "Realized inflation"), linewidth = 1, linetype = "dashed") +
  scale_color_manual(values = c("Quantified expectation" = okabe_ito[["blue"]], "Realized inflation" = okabe_ito[["vermillion"]])) +
  labs(
    title = "Inflation Expectations and Realized Inflation",
    x = "Quarter",
    y = "Percentage points",
    color = NULL
  ) +
  theme_pub()
save_plot_pair(p1, file.path(project_paths$figures, "expectations_vs_realized"), width = 8.2, height = 5)

# Figure 2: revision and subsequent forecast error.
df2 <- panel[!is.na(FR_cp) & !is.na(FE_next_cp)]
p2 <- ggplot(df2, aes(x = qdate)) +
  geom_col(aes(y = FR_cp, fill = "Revision"), alpha = 0.35) +
  geom_line(aes(y = FE_next_cp, color = "Next-quarter error"), linewidth = 1.05) +
  scale_fill_manual(values = c("Revision" = okabe_ito[["sky_blue"]])) +
  scale_color_manual(values = c("Next-quarter error" = okabe_ito[["vermillion"]])) +
  labs(
    title = "Revision-Error Dynamics",
    x = "Quarter",
    y = "Percentage points",
    fill = NULL,
    color = NULL
  ) +
  theme_pub()
save_plot_pair(p2, file.path(project_paths$figures, "revision_error_dynamics"), width = 8.2, height = 5)

# Figure 3: uncertainty and salience states.
df3 <- panel[!is.na(epu_qavg) & !is.na(gpr_qavg) & !is.na(msi_raw)]
df3[, epu_z := as.numeric(scale(epu_qavg))]
df3[, gpr_z := as.numeric(scale(gpr_qavg))]
df3[, msi_z := as.numeric(scale(msi_raw))]

p3 <- ggplot(df3, aes(x = qdate)) +
  geom_line(aes(y = epu_z, color = "EPU (z-score)"), linewidth = 1) +
  geom_line(aes(y = gpr_z, color = "GPR (z-score)"), linewidth = 1) +
  geom_line(aes(y = msi_z, color = "Salience index (z-score)"), linewidth = 1.05, linetype = "dashed") +
  scale_color_manual(values = c(
    "EPU (z-score)" = okabe_ito[["blue"]],
    "GPR (z-score)" = okabe_ito[["orange"]],
    "Salience index (z-score)" = okabe_ito[["black"]]
  )) +
  labs(
    title = "Uncertainty and Salience States",
    x = "Quarter",
    y = "Standardized units",
    color = NULL
  ) +
  theme_pub()
save_plot_pair(p3, file.path(project_paths$figures, "uncertainty_salience_states"), width = 8.2, height = 5)

# Correlation matrix table.
vars <- c("mu_cp", "FR_cp", "FE_next_cp", "epu_qavg", "gpr_qavg", "Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate")
vars <- vars[vars %in% names(panel)]
cm <- round(cor(panel[, ..vars], use = "pairwise.complete.obs"), 3)
cm_dt <- data.table(variable = rownames(cm), cm)

write_booktabs_table(
  cm_dt,
  file.path(project_paths$tables, "correlation_matrix.tex"),
  caption = "Correlation Matrix of Core Variables",
  label = "tab:correlation_matrix",
  notes = c("Pairwise-complete correlations."),
  digits = 3,
  escape = FALSE
)

# Key numbers table for manuscript references.
key <- data.table(
  metric = c(
    "Corr(FE, FR)",
    "Mean beta_t (Bayes SSM output placeholder)",
    "Main sample observations",
    "Sample start",
    "Sample end"
  ),
  value = c(
    cor(panel$FE_next_cp, panel$FR_cp, use = "pairwise.complete.obs"),
    NA_real_,
    sum(!is.na(panel$FE_next_cp) & !is.na(panel$FR_cp)),
    panel$quarter[which.min(parse_quarter(panel$quarter))],
    panel$quarter[which.max(parse_quarter(panel$quarter))]
  )
)
write_booktabs_table(
  key,
  file.path(project_paths$tables, "key_numbers.tex"),
  caption = "Key Quantitative Anchors",
  label = "tab:key_numbers",
  notes = c("The Bayes SSM statistic is populated after running the Julia module."),
  digits = 3,
  escape = FALSE
)

cat("[80] Figures and publication tables complete.\n")

