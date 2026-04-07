#!/usr/bin/env Rscript
# 50_reviewer_fixes.R
# Address JPE-Macro desk review concerns:
# 1. Province FE + region×wave FE specification
# 2. Formal Wald test of meat vs. grain coefficient equality
# 3. Clean urban variable (remove -9 coding)
# 4. Report one-SD effects

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := paste0(region, "_", wave)]

# ============================================================
# 0. Urban variable diagnostic
# ============================================================
cat("=== Urban variable ===\n")
cat("Value counts:\n")
print(table(cfps$urban, useNA = "always"))
cat(sprintf("Min = %d, Max = %d\n", min(cfps$urban, na.rm = TRUE), max(cfps$urban, na.rm = TRUE)))

# Flag: -9 values are clearly missing codes
n_bad <- sum(cfps$urban < 0, na.rm = TRUE)
cat(sprintf("Observations with urban < 0: %d\n", n_bad))
# Recode to NA
cfps[urban < 0, urban := NA_integer_]
cat(sprintf("After cleaning: urban range [%d, %d], NA count = %d\n",
            min(cfps$urban, na.rm = TRUE), max(cfps$urban, na.rm = TRUE),
            sum(is.na(cfps$urban))))

# ============================================================
# 1. Province FE + Region×Wave FE specification
# ============================================================
cat("\n=== Province FE + Region×Wave FE ===\n")

# Eq1: expectations
# Note: province_factor + region_wave may be collinear for provinces that
# are the only province in their region. Check if feols handles this.
tryCatch({
  eq1_prw <- feols(price_exp ~ meat_shock | province_factor + region_wave,
                   data = cfps, vcov = ~province)
  cat("Eq1 (prov + region×wave):\n")
  print(coeftable(eq1_prw))
  cat(sprintf("  N = %d, R2 = %.4f\n", eq1_prw$nobs, fitstat(eq1_prw, "r2")[[1]]))
}, error = function(e) {
  cat("Eq1 province + region×wave failed:", e$message, "\n")
  cat("Trying province×wave FE instead...\n")
})

# Eq3: forecast error
cfps_fe <- cfps[!is.na(fe_clean)]
tryCatch({
  eq3_prw <- feols(fe_clean ~ meat_shock | province_factor + region_wave,
                   data = cfps_fe, vcov = ~province)
  cat("\nEq3 (prov + region×wave):\n")
  print(coeftable(eq3_prw))
  cat(sprintf("  N = %d, R2 = %.4f\n", eq3_prw$nobs, fitstat(eq3_prw, "r2")[[1]]))
}, error = function(e) {
  cat("Eq3 province + region×wave failed:", e$message, "\n")
})

# Also try province + wave FE (the reviewer's alternative)
eq1_pw <- feols(price_exp ~ meat_shock | province_factor + wave_factor,
                data = cfps, vcov = ~province)
eq3_pw <- feols(fe_clean ~ meat_shock | province_factor + wave_factor,
                data = cfps_fe, vcov = ~province)
cat("\nEq1 (prov + wave): beta =", coeftable(eq1_pw)["meat_shock", "Estimate"],
    "SE =", coeftable(eq1_pw)["meat_shock", "Std. Error"], "\n")
cat("Eq3 (prov + wave): beta =", coeftable(eq3_pw)["meat_shock", "Estimate"],
    "SE =", coeftable(eq3_pw)["meat_shock", "Std. Error"], "\n")

# Region×wave only (current preferred)
eq1_rw <- feols(price_exp ~ meat_shock | region_wave,
                data = cfps, vcov = ~province)
eq3_rw <- feols(fe_clean ~ meat_shock | region_wave,
                data = cfps_fe, vcov = ~province)
cat("\nEq1 (region×wave): beta =", coeftable(eq1_rw)["meat_shock", "Estimate"],
    "SE =", coeftable(eq1_rw)["meat_shock", "Std. Error"], "\n")
cat("Eq3 (region×wave): beta =", coeftable(eq3_rw)["meat_shock", "Estimate"],
    "SE =", coeftable(eq3_rw)["meat_shock", "Std. Error"], "\n")

# ============================================================
# 2. Formal Wald test: H0: beta_meat = beta_grain
# ============================================================
cat("\n=== Wald test: meat = grain ===\n")
m_horse <- feols(price_exp ~ meat_shock + grain_shock | region_wave,
                 data = cfps[!is.na(grain_shock)], vcov = ~province)

# Wald test
wald_result <- wald(m_horse, "meat_shock = grain_shock")
cat("Horse-race coefficients:\n")
print(coeftable(m_horse))
cat("\nWald test H0: beta_meat = beta_grain:\n")
print(wald_result)

# Also with province FE
m_horse_pw <- feols(price_exp ~ meat_shock + grain_shock | province_factor + wave_factor,
                    data = cfps[!is.na(grain_shock)], vcov = ~province)
wald_pw <- wald(m_horse_pw, "meat_shock = grain_shock")
cat("\nWald test (prov + wave FE):\n")
print(wald_pw)

# ============================================================
# 3. One-SD effects
# ============================================================
cat("\n=== One-SD effects ===\n")
sd_meat <- sd(cfps$meat_shock)
beta3 <- coeftable(eq3_rw)["meat_shock", "Estimate"]
cat(sprintf("Meat shock SD = %.4f\n", sd_meat))
cat(sprintf("One-unit beta3 = %.4f\n", beta3))
cat(sprintf("One-SD effect = %.4f pp\n", beta3 * sd_meat))

cat("\nDone.\n")
