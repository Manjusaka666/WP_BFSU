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

controls <- c("Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY_rate")
controls <- controls[controls %in% names(panel)]

run_lp <- function(data, outcome, horizons = 0:8, iv = FALSE, label = "") {
  out <- rbindlist(lapply(horizons, function(h) {
    y_name <- paste0(outcome, "_lead", h)
    dt <- copy(data)
    dt[, (y_name) := shift(get(outcome), n = h, type = "lead")]
    req <- c(y_name, "FR_cp", if (iv) "media_congestion_iv", controls)
    dt <- dt[complete.cases(dt[, ..req])]
    if (nrow(dt) < 20) {
      return(data.table(h = h, beta = NA_real_, se = NA_real_, ci_low = NA_real_, ci_high = NA_real_, n = nrow(dt), model = label))
    }

    if (!iv) {
      f <- as.formula(paste(y_name, "~ FR_cp", ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")))
      m <- lm(f, data = dt)
      ct <- coeftest(m, vcov. = NeweyWest(m, lag = 4, prewhite = FALSE, adjust = TRUE))
      beta <- ct["FR_cp", "Estimate"]
      se <- ct["FR_cp", "Std. Error"]
    } else {
      f <- as.formula(paste(y_name, "~", ifelse(length(controls) > 0, paste(controls, collapse = " + "), "1"), "| FR_cp ~ media_congestion_iv"))
      m <- feols(f, data = dt)
      ct <- coeftable(m, vcov = NW ~ t_id)
      row <- grep("^fit_", rownames(ct), value = TRUE)[1]
      beta <- ct[row, "Estimate"]
      se <- ct[row, "Std. Error"]
    }

    data.table(h = h, beta = beta, se = se, ci_low = beta - 1.96 * se, ci_high = beta + 1.96 * se, n = nrow(dt), model = label)
  }))

  out
}

lp_fe_ols <- run_lp(panel, "FE_next_cp", horizons = 0:8, iv = FALSE, label = "OLS LP")
lp_fe_iv <- run_lp(panel, "FE_next_cp", horizons = 0:8, iv = TRUE, label = "IV LP")
lp_pi_ols <- run_lp(panel, "CPI_QoQ_Ann", horizons = 0:8, iv = FALSE, label = "OLS LP")
lp_pi_iv <- run_lp(panel, "CPI_QoQ_Ann", horizons = 0:8, iv = TRUE, label = "IV LP")

lp_all <- rbindlist(list(
  cbind(outcome = "Forecast error", lp_fe_ols),
  cbind(outcome = "Forecast error", lp_fe_iv),
  cbind(outcome = "Realized inflation", lp_pi_ols),
  cbind(outcome = "Realized inflation", lp_pi_iv)
))

fwrite(lp_all, file.path(project_paths$robustness, "lp_dynamic_coefficients.csv"))

write_booktabs_table(
  lp_all,
  file.path(project_paths$tables, "lp_dynamic.tex"),
  caption = "Local Projections: Dynamic Effects of Revision Shocks",
  label = "tab:lp_dynamic",
  notes = c(
    "`h` is horizon in quarters.",
    "IV LP instruments forecast revision with media-congestion salience shock."
  ),
  digits = 3,
  escape = FALSE
)

plot_lp <- function(df, title, file_stub) {
  p <- ggplot(df, aes(x = h, y = beta, color = model, fill = model)) +
    geom_hline(yintercept = 0, color = okabe_ito[["black"]], linetype = "dashed") +
    geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.16, color = NA) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    scale_color_manual(values = c("OLS LP" = okabe_ito[["blue"]], "IV LP" = okabe_ito[["vermillion"]])) +
    scale_fill_manual(values = c("OLS LP" = okabe_ito[["sky_blue"]], "IV LP" = okabe_ito[["orange"]])) +
    labs(title = title, x = "Horizon (quarters)", y = "Response coefficient") +
    theme_pub()

  save_plot_pair(p, file.path(project_paths$figures, file_stub), width = 7.8, height = 5)
}

plot_lp(lp_all[outcome == "Forecast error"], "Local Projections: Forecast Error Response", "lp_forecast_error")
plot_lp(lp_all[outcome == "Realized inflation"], "Local Projections: Realized Inflation Response", "lp_inflation")

cat("[60] Local projection module complete.\n")

