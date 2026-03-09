#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(lmtest)
  library(sandwich)
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

main_cols <- c("FE_next_cp", "FR_cp", controls)
use <- panel[complete.cases(panel[, ..main_cols])]
if (nrow(use) < 25) stop("Insufficient observations for baseline models.")

run_ols <- function(formula, data) {
  m <- lm(formula, data = data)
  vc <- NeweyWest(m, lag = 4, prewhite = FALSE, adjust = TRUE)
  ct <- coeftest(m, vcov. = vc)
  list(model = m, vcov = vc, ct = ct)
}

f1 <- as.formula("FE_next_cp ~ FR_cp")
f2 <- as.formula(paste("FE_next_cp ~ FR_cp +", paste(controls, collapse = " + ")))
f3 <- as.formula(paste("FE_next_cp ~ FR_cp +", paste(c(controls, "epu_qavg", "gpr_qavg"), collapse = " + ")))
f4 <- as.formula("FE_next_cp ~ FR_index")

m1 <- run_ols(f1, use)
m2 <- run_ols(f2, use)

use3 <- use[complete.cases(use[, .(FE_next_cp, FR_cp, epu_qavg, gpr_qavg, ..controls)])]
m3 <- run_ols(f3, use3)

use4 <- panel[complete.cases(panel[, .(FE_next_cp, FR_index)])]
m4 <- if (nrow(use4) > 20) run_ols(f4, use4) else NULL

extract_row <- function(obj, coef_name, spec_name) {
  ct <- obj$ct
  if (!coef_name %in% rownames(ct)) {
    return(data.table(spec = spec_name, beta = NA_real_, se = NA_real_, p_value = NA_real_, n = nobs(obj$model), r2 = summary(obj$model)$r.squared))
  }
  data.table(
    spec = spec_name,
    beta = ct[coef_name, "Estimate"],
    se = ct[coef_name, "Std. Error"],
    p_value = ct[coef_name, "Pr(>|t|)"],
    n = nobs(obj$model),
    r2 = summary(obj$model)$r.squared
  )
}

rows <- rbindlist(list(
  extract_row(m1, "FR_cp", "Bivariate"),
  extract_row(m2, "FR_cp", "+ Macro controls"),
  extract_row(m3, "FR_cp", "+ Uncertainty controls")
))
if (!is.null(m4)) rows <- rbind(rows, extract_row(m4, "FR_index", "Alternative expectation revision"))

write_booktabs_table(
  rows,
  file.path(project_paths$tables, "ols_baseline.tex"),
  caption = "Baseline Forecast-Error Regressions",
  label = "tab:ols_baseline",
  notes = c(
    "Dependent variable is next-quarter forecast error using Carlson-Parkin expectations.",
    "All standard errors are Newey-West with 4 lags."
  ),
  digits = 3,
  escape = FALSE
)

# Diagnostics
main_resid <- residuals(m2$model)
jb <- tseries::jarque.bera.test(main_resid)
dw <- lmtest::dwtest(m2$model)
bp <- lmtest::bptest(m2$model)

diag <- data.table(
  test = c("Jarque-Bera", "Durbin-Watson", "Breusch-Pagan"),
  statistic = c(unname(jb$statistic), unname(dw$statistic), unname(bp$statistic)),
  p_value = c(jb$p.value, dw$p.value, bp$p.value)
)
write_booktabs_table(
  diag,
  file.path(project_paths$tables, "ols_diagnostics.tex"),
  caption = "Baseline OLS Diagnostics",
  label = "tab:ols_diagnostics",
  notes = c("Diagnostic tests are reported for the baseline model with macro controls."),
  digits = 3,
  escape = FALSE
)

# Robustness table
rob <- data.table(
  model = c("No Food CPI", "No Money Growth", "No PPI"),
  beta = NA_real_,
  se = NA_real_,
  p_value = NA_real_,
  n = NA_real_
)

rob_forms <- list(
  as.formula(paste("FE_next_cp ~ FR_cp +", paste(setdiff(controls, "Food_CPI_YoY_qavg"), collapse = " + "))),
  as.formula(paste("FE_next_cp ~ FR_cp +", paste(setdiff(controls, "M2_YoY"), collapse = " + "))),
  as.formula(paste("FE_next_cp ~ FR_cp +", paste(setdiff(controls, "PPI_YoY_rate"), collapse = " + ")))
)

for (i in seq_along(rob_forms)) {
  rhs <- attr(terms(rob_forms[[i]]), "term.labels")
  req <- c("FE_next_cp", rhs)
  d_i <- use[complete.cases(use[, ..req])]
  if (nrow(d_i) > 20) {
    m_i <- run_ols(rob_forms[[i]], d_i)
    rob[i, `:=`(
      beta = m_i$ct["FR_cp", "Estimate"],
      se = m_i$ct["FR_cp", "Std. Error"],
      p_value = m_i$ct["FR_cp", "Pr(>|t|)"],
      n = nobs(m_i$model)
    )]
  }
}

write_booktabs_table(
  rob,
  file.path(project_paths$tables, "ols_robustness.tex"),
  caption = "Baseline Robustness to Control Sets",
  label = "tab:ols_robustness",
  notes = c("The diagnostic coefficient remains the coefficient on forecast revision."),
  digits = 3,
  escape = FALSE
)

cat("[40] Baseline models complete.\n")

