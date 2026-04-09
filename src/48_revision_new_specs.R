#!/usr/bin/env Rscript
# 48_revision_new_specs.R
# Revision specification grid built on the same data construction pattern as
# 42_meat_shock_regressions.R.
# Output: outputs/tables/revision_new_results.csv

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

extract_rows <- function(model, equation, spec, dep_var, sample_tag,
                         coefs = c("meat_shock", "grain_shock", "egg_shock")) {
  ct <- coeftable(model)
  keep <- intersect(coefs, rownames(ct))
  if (length(keep) == 0L) {
    return(data.table(
      equation = equation,
      spec = spec,
      dep_var = dep_var,
      sample = sample_tag,
      coefficient = NA_character_,
      beta = NA_real_,
      se = NA_real_,
      p = NA_real_,
      n = as.integer(model$nobs),
      r2 = fitstat(model, "r2")[[1]]
    ))
  }

  data.table(
    equation = equation,
    spec = spec,
    dep_var = dep_var,
    sample = sample_tag,
    coefficient = keep,
    beta = as.numeric(ct[keep, "Estimate"]),
    se = as.numeric(ct[keep, "Std. Error"]),
    p = as.numeric(ct[keep, "Pr(>|t|)"]),
    n = as.integer(model$nobs),
    r2 = fitstat(model, "r2")[[1]]
  )
}

append_model <- function(store, model, equation, spec, dep_var, sample_tag) {
  store[[length(store) + 1L]] <- extract_rows(
    model = model,
    equation = equation,
    spec = spec,
    dep_var = dep_var,
    sample_tag = sample_tag
  )
  store
}

# -----------------------------------------------------------------------------
# Data setup: mirror the pattern in 42_meat_shock_regressions.R
# -----------------------------------------------------------------------------
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

cat(sprintf("[48] Base sample (Eq1 pattern): %d obs, %d provinces, %d waves\n",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))

cfps_fe <- cfps[!is.na(fe_clean)]
cat(sprintf("[48] Forecast-error sample: %d obs\n", nrow(cfps_fe)))

horse_sample <- cfps[!is.na(grain_shock) & !is.na(egg_shock)]
horse_fe_sample <- cfps_fe[!is.na(grain_shock) & !is.na(egg_shock)]

prov_wave <- cfps[, .(
  mean_exp = mean(price_exp, na.rm = TRUE),
  meat_shock = meat_shock[1],
  grain_shock = grain_shock[1],
  egg_shock = egg_shock[1],
  headline_cpi_next = headline_cpi_next[1],
  realized_cpi_ann = realized_cpi_ann[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]
prov_wave[, province_factor := as.factor(province)]
prov_wave[, wave_factor := as.factor(wave)]
prov_wave[, region_wave := as.factor(paste0(region, "_", wave))]
prov_wave <- prov_wave[!is.na(realized_cpi_ann) & !is.na(meat_shock)]

cat(sprintf("[48] Province-wave Eq2 sample: %d cells\n", nrow(prov_wave)))

results <- list()

# -----------------------------------------------------------------------------
# Equation 1: price_exp
# -----------------------------------------------------------------------------
cat("[48] Running Eq1 revision specs...\n")

m_eq1_rw <- feols(price_exp ~ meat_shock | region_wave, data = cfps, vcov = ~province)
results <- append_model(results, m_eq1_rw, "Eq1", "rw_fe", "price_exp", "base")

m_eq1_rw_x <- feols(price_exp ~ meat_shock + age + edu_high + urban | region_wave,
                    data = cfps, vcov = ~province)
results <- append_model(results, m_eq1_rw_x, "Eq1", "rw_fe_demog", "price_exp", "base")

m_eq1_pw <- feols(price_exp ~ meat_shock | province_factor + wave_factor,
                  data = cfps, vcov = ~province)
results <- append_model(results, m_eq1_pw, "Eq1", "prov_wave_fe", "price_exp", "base")

m_eq1_prw <- feols(price_exp ~ meat_shock | province_factor + region_wave,
                   data = cfps, vcov = ~province)
results <- append_model(results, m_eq1_prw, "Eq1", "prov_rw_fe", "price_exp", "base")

if (nrow(horse_sample) > 0) {
  m_eq1_horse <- feols(price_exp ~ meat_shock + grain_shock + egg_shock | region_wave,
                       data = horse_sample, vcov = ~province)
  results <- append_model(results, m_eq1_horse, "Eq1", "rw_fe_horse", "price_exp", "horse")
}

cfps_no22 <- cfps[wave != 2022]
m_eq1_no22 <- feols(price_exp ~ meat_shock | region_wave, data = cfps_no22, vcov = ~province)
results <- append_model(results, m_eq1_no22, "Eq1", "rw_fe_drop2022", "price_exp", "drop2022")

cell_exp <- cfps[, .(
  price_exp = mean(price_exp, na.rm = TRUE),
  meat_shock = meat_shock[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]
cell_exp[, region_wave := as.factor(paste0(region, "_", wave))]
m_eq1_cell <- feols(price_exp ~ meat_shock | region_wave,
                    data = cell_exp, weights = ~n_hh, vcov = ~province)
results <- append_model(results, m_eq1_cell, "Eq1", "rw_fe_collapsed", "price_exp", "collapsed")

# -----------------------------------------------------------------------------
# Equation 2: realized_cpi_ann (province-wave)
# -----------------------------------------------------------------------------
cat("[48] Running Eq2 revision specs...\n")

m_eq2_rw <- feols(realized_cpi_ann ~ meat_shock | region_wave,
                  data = prov_wave, vcov = ~province)
results <- append_model(results, m_eq2_rw, "Eq2", "rw_fe", "realized_cpi_ann", "base")

m_eq2_pw <- feols(realized_cpi_ann ~ meat_shock | province_factor + wave_factor,
                  data = prov_wave, vcov = ~province)
results <- append_model(results, m_eq2_pw, "Eq2", "prov_wave_fe", "realized_cpi_ann", "base")

prov_wave_horse <- prov_wave[!is.na(grain_shock) & !is.na(egg_shock)]
if (nrow(prov_wave_horse) > 0) {
  m_eq2_horse <- feols(realized_cpi_ann ~ meat_shock + grain_shock + egg_shock | region_wave,
                       data = prov_wave_horse, vcov = ~province)
  results <- append_model(results, m_eq2_horse, "Eq2", "rw_fe_horse", "realized_cpi_ann", "horse")
}

prov_wave_no22 <- prov_wave[wave != 2022]
if (nrow(prov_wave_no22) > 0) {
  m_eq2_no22 <- feols(realized_cpi_ann ~ meat_shock | region_wave,
                      data = prov_wave_no22, vcov = ~province)
  results <- append_model(results, m_eq2_no22, "Eq2", "rw_fe_drop2022", "realized_cpi_ann", "drop2022")
}

# -----------------------------------------------------------------------------
# Equation 3: fe_clean
# -----------------------------------------------------------------------------
cat("[48] Running Eq3 revision specs...\n")

m_eq3_rw <- feols(fe_clean ~ meat_shock | region_wave, data = cfps_fe, vcov = ~province)
results <- append_model(results, m_eq3_rw, "Eq3", "rw_fe", "fe_clean", "base")

m_eq3_rw_x <- feols(fe_clean ~ meat_shock + age + edu_high + urban | region_wave,
                    data = cfps_fe, vcov = ~province)
results <- append_model(results, m_eq3_rw_x, "Eq3", "rw_fe_demog", "fe_clean", "base")

m_eq3_pw <- feols(fe_clean ~ meat_shock | province_factor + wave_factor,
                  data = cfps_fe, vcov = ~province)
results <- append_model(results, m_eq3_pw, "Eq3", "prov_wave_fe", "fe_clean", "base")

m_eq3_prw <- feols(fe_clean ~ meat_shock | province_factor + region_wave,
                   data = cfps_fe, vcov = ~province)
results <- append_model(results, m_eq3_prw, "Eq3", "prov_rw_fe", "fe_clean", "base")

if (nrow(horse_fe_sample) > 0) {
  m_eq3_horse <- feols(fe_clean ~ meat_shock + grain_shock + egg_shock | region_wave,
                       data = horse_fe_sample, vcov = ~province)
  results <- append_model(results, m_eq3_horse, "Eq3", "rw_fe_horse", "fe_clean", "horse")
}

cfps_fe_no22 <- cfps_fe[wave != 2022]
m_eq3_no22 <- feols(fe_clean ~ meat_shock | region_wave, data = cfps_fe_no22, vcov = ~province)
results <- append_model(results, m_eq3_no22, "Eq3", "rw_fe_drop2022", "fe_clean", "drop2022")

cell_fe <- cfps_fe[, .(
  fe_clean = mean(fe_clean, na.rm = TRUE),
  meat_shock = meat_shock[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]
cell_fe[, region_wave := as.factor(paste0(region, "_", wave))]
m_eq3_cell <- feols(fe_clean ~ meat_shock | region_wave,
                    data = cell_fe, weights = ~n_hh, vcov = ~province)
results <- append_model(results, m_eq3_cell, "Eq3", "rw_fe_collapsed", "fe_clean", "collapsed")

# -----------------------------------------------------------------------------
# Save and print compact diagnostics
# -----------------------------------------------------------------------------
out <- rbindlist(results, use.names = TRUE, fill = TRUE)
csv_out <- file.path(project_paths$tables, "revision_new_results.csv")
fwrite(out, csv_out)

cat(sprintf("[48] Saved %d coefficient rows to %s\n", nrow(out), csv_out))

key_rows <- out[equation %in% c("Eq1", "Eq2", "Eq3") &
                  spec == "rw_fe" &
                  coefficient == "meat_shock"]
if (nrow(key_rows) > 0) {
  cat("[48] Key RW FE coefficients (meat_shock):\n")
  for (i in seq_len(nrow(key_rows))) {
    cat(sprintf("  %s: beta=%.4f se=%.4f p=%.4f n=%d\n",
                key_rows$equation[i],
                key_rows$beta[i],
                key_rows$se[i],
                key_rows$p[i],
                key_rows$n[i]))
  }
}

cat("[48] Done.\n")
