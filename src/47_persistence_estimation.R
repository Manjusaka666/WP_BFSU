#!/usr/bin/env Rscript
# 47_persistence_estimation.R
# Estimate AR(1) persistence of meat-price shocks from monthly
# province-level CPI data. Used to calibrate the rational benchmark.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# --- Load province-level meat CPI ---
meat <- fread(file.path(project_paths$intermediate, "province_meat_cpi.csv"))
meat[, date := as.Date(date)]
setorder(meat, provcd, date)

# Convert CPI index (base 100) to log change
meat[, log_change := log(cpi_index / 100)]

# Lag within province
meat[, log_change_lag := shift(log_change, 1), by = provcd]

# Drop missing
meat_est <- meat[!is.na(log_change) & !is.na(log_change_lag)]

cat(sprintf("[47] Persistence sample: %d obs, %d provinces, %s to %s\n",
            nrow(meat_est), uniqueN(meat_est$provcd),
            min(meat_est$date), max(meat_est$date)))

# --- AR(1) with province FE ---
ar1 <- feols(log_change ~ log_change_lag | provcd,
             data = meat_est, vcov = ~provcd)

rho <- coeftable(ar1)["log_change_lag", "Estimate"]
rho_se <- coeftable(ar1)["log_change_lag", "Std. Error"]
rho_p <- coeftable(ar1)["log_change_lag", "Pr(>|t|)"]

cat(sprintf("\n=== AR(1) Persistence ===\n"))
cat(sprintf("rho = %.4f (SE = %.4f, p = %.6f)\n", rho, rho_se, rho_p))
cat(sprintf("N = %d, provinces = %d\n", ar1$nobs, uniqueN(meat_est$provcd)))

# --- Save for calibration script ---
persistence <- data.table(
  parameter = c("rho", "rho_se", "rho_p", "n_obs", "n_provinces"),
  value = c(rho, rho_se, rho_p, ar1$nobs, uniqueN(meat_est$provcd))
)
fwrite(persistence, file.path(project_paths$tables, "persistence_ar1.csv"))
cat(sprintf("[47] Saved persistence_ar1.csv\n"))
