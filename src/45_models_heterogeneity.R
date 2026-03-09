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

need <- c("FE_next_cp", "FR_cp", "epu_qavg", "gpr_qavg", "effective_sample_share", controls)
use <- panel[complete.cases(panel[, ..need])]
if (nrow(use) < 25) stop("Insufficient observations for heterogeneity analysis.")

use[, high_epu := as.integer(epu_qavg > median(epu_qavg, na.rm = TRUE))]
use[, high_gpr := as.integer(gpr_qavg > median(gpr_qavg, na.rm = TRUE))]
use[, low_effective_sample := as.integer(effective_sample_share < median(effective_sample_share, na.rm = TRUE))]

run_interaction <- function(flag) {
  f <- as.formula(paste(
    "FE_next_cp ~ FR_cp +",
    flag,
    "+ FR_cp:", flag,
    ifelse(length(controls) > 0, paste("+", paste(controls, collapse = " + ")), "")
  ))
  m <- lm(f, data = use)
  ct <- coeftest(m, vcov. = NeweyWest(m, lag = 4, prewhite = FALSE, adjust = TRUE))
  data.table(
    channel = flag,
    beta_base = ct["FR_cp", "Estimate"],
    beta_interaction = ct[paste0("FR_cp:", flag), "Estimate"],
    p_interaction = ct[paste0("FR_cp:", flag), "Pr(>|t|)"],
    implied_beta_high = ct["FR_cp", "Estimate"] + ct[paste0("FR_cp:", flag), "Estimate"],
    n = nobs(m)
  )
}

het_tab <- rbindlist(list(
  run_interaction("high_epu"),
  run_interaction("high_gpr"),
  run_interaction("low_effective_sample")
))

write_booktabs_table(
  het_tab,
  file.path(project_paths$tables, "heterogeneity_interactions.tex"),
  caption = "Heterogeneity in Diagnostic Coefficients",
  label = "tab:heterogeneity_interactions",
  notes = c(
    "`implied_beta_high` is the diagnostic coefficient under the high-state indicator.",
    "Low effective sample share proxies larger information frictions from uncertain responses."
  ),
  digits = 3,
  escape = FALSE
)

# Monotonicity check across salience terciles.
use[, salience_tercile := cut(msi_raw,
                             breaks = quantile(msi_raw, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE),
                             include.lowest = TRUE,
                             labels = c("Low salience", "Mid salience", "High salience"))]

mono <- use[, {
  rhs <- c("FR_cp", controls)
  f <- as.formula(paste("FE_next_cp ~", paste(rhs, collapse = " + ")))
  m <- lm(f, data = .SD)
  ct <- coeftest(m, vcov. = NeweyWest(m, lag = 2, prewhite = FALSE, adjust = TRUE))
  .(beta = ct["FR_cp", "Estimate"], se = ct["FR_cp", "Std. Error"], n = .N)
}, by = salience_tercile]

mono[, ci_low := beta - 1.96 * se]
mono[, ci_high := beta + 1.96 * se]

write_booktabs_table(
  mono,
  file.path(project_paths$tables, "heterogeneity_monotonicity.tex"),
  caption = "Monotonicity Across Salience Regimes",
  label = "tab:heterogeneity_monotonicity",
  notes = c("A more negative coefficient in high-salience terciles supports stronger diagnostic behavior."),
  digits = 3,
  escape = FALSE
)

p <- ggplot(mono, aes(x = salience_tercile, y = beta, color = salience_tercile)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.1) +
  geom_line(aes(group = 1), color = okabe_ito[["black"]]) +
  scale_color_manual(values = c(okabe_ito[["sky_blue"]], okabe_ito[["blue"]], okabe_ito[["vermillion"]])) +
  labs(
    title = "Diagnostic Coefficient by Salience Regime",
    x = "Salience tercile",
    y = "Coefficient on revision"
  ) +
  theme_pub()

save_plot_pair(p, file.path(project_paths$figures, "heterogeneity_salience"), width = 7.2, height = 4.8)

cat("[45] Heterogeneity module complete.\n")

