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

# Main identification table.
id_tab <- data.table(
  specification = c(
    "First stage: salience on congestion IV",
    "2SLS: revision on instrumented salience",
    "2SLS: forecast error on instrumented revision",
    "Reduced form: forecast error on congestion IV"
  ),
  coefficient = c(
    fs_beta,
    iv_rev_ct[iv_rev_row, "Estimate"],
    iv_fe_ct[iv_fe_row, "Estimate"],
    rf_ct["media_congestion_iv", "Estimate"]
  ),
  se_NW = c(
    fs_se,
    iv_rev_ct[iv_rev_row, "Std. Error"],
    iv_fe_ct[iv_fe_row, "Std. Error"],
    rf_ct["media_congestion_iv", "Std. Error"]
  ),
  p_value = c(
    fs_p,
    iv_rev_ct[iv_rev_row, "Pr(>|t|)"],
    iv_fe_ct[iv_fe_row, "Pr(>|t|)"],
    rf_ct["media_congestion_iv", "Pr(>|t|)"]
  ),
  n_obs = c(nrow(use), nrow(use), nrow(use), nrow(use))
)

write_booktabs_table(
  id_tab,
  file.path(project_paths$tables, "identification_main.tex"),
  caption = "Salience-IV Identification Results",
  label = "tab:identification_main",
  notes = c(
    "Newey-West standard errors use 4 quarterly lags.",
    "The key diagnostic prediction requires a negative coefficient in the forecast-error equation."
  ),
  digits = 3,
  escape = FALSE
)

weak_tab <- data.table(
  metric = c("First-stage t-stat (NW)", "First-stage Wald F (t^2)", "Approx. KP rk Wald F", "AR-type 95% CI lower", "AR-type 95% CI upper"),
  value = c(fs_t, fs_F, fs_F, ar_ci[1], ar_ci[2])
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

placebo_tab <- data.table(
  test = c(
    "Permutation placebo IV: mean coefficient",
    "Permutation placebo IV: 2.5 percentile",
    "Permutation placebo IV: 97.5 percentile",
    paste0("Placebo outcome (", placebo_outcome, ")"),
    "Anticipation test using lead revision"
  ),
  estimate = c(
    mean(placebo_beta, na.rm = TRUE),
    quantile(placebo_beta, 0.025, na.rm = TRUE),
    quantile(placebo_beta, 0.975, na.rm = TRUE),
    pbo_beta,
    ant_beta
  ),
  p_value = c(NA_real_, NA_real_, NA_real_, pbo_p, ant_p)
)

write_booktabs_table(
  placebo_tab,
  file.path(project_paths$tables, "placebo_tests.tex"),
  caption = "Falsification and Placebo Tests",
  label = "tab:placebo_tests",
  notes = c(
    "Permutation placebo reassigns the instrument across quarters 300 times.",
    "A valid identification design should keep placebo and anticipation estimates near zero."
  ),
  digits = 3,
  escape = FALSE
)

# Plot first-stage relation.
p <- ggplot(use, aes(x = media_congestion_iv, y = msi_raw)) +
  geom_point(color = okabe_ito[["blue"]], size = 2.2, alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = okabe_ito[["vermillion"]], fill = okabe_ito[["orange"]], alpha = 0.2) +
  labs(
    title = "First Stage: Media Congestion as Instrument for Salience",
    x = "News Congestion Instrument (higher = lower inflation salience)",
    y = "Inflation Salience Index"
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "identification_first_stage"), width = 7.5, height = 5)

cat("[35] Identification module complete.\n")

