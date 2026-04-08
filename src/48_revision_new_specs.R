#!/usr/bin/env Rscript
# 48_revision_new_specs.R
# New regression specifications for the JPE-Macro revision:
#   Block 1: Province + Region×Wave FE (eq1, eq2, eq3)
#   Block 2: Collapsed cell-level estimation
#   Block 3: Randomization inference (2000 permutations)
#   Block 4: Drop-2022-wave robustness
#   Block 5: Leave-one-region-out for Eq2 & Eq3
# Outputs: outputs/tables/revision_new_results.csv

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# ── Load and prepare data ──────────────────────────────────────
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(province)]
if (is.numeric(cfps$province) || is.integer(cfps$province)) {
  cfps <- cfps[province > 0]
}
cfps <- cfps[!is.na(meat_shock)]
cfps[urban < 0, urban := NA_integer_]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

exp_sample <- cfps[!is.na(price_exp)]
fe_sample  <- cfps[!is.na(fe_clean)]

cat(sprintf("[48] Expectation sample: %d obs\n", nrow(exp_sample)))
cat(sprintf("[48] Forecast-error sample: %d obs\n", nrow(fe_sample)))

results <- list()

extract <- function(model, spec, dep, coef_name = "meat_shock") {
  ct <- coeftable(model)
  if (!(coef_name %in% rownames(ct))) {
    return(data.table(spec = spec, dep_var = dep, coefficient = coef_name,
                      beta = NA_real_, se = NA_real_, p = NA_real_,
                      n = as.integer(model$nobs),
                      r2 = fitstat(model, "r2")[[1]]))
  }
  data.table(
    spec = spec, dep_var = dep, coefficient = coef_name,
    beta = as.numeric(ct[coef_name, "Estimate"]),
    se   = as.numeric(ct[coef_name, "Std. Error"]),
    p    = as.numeric(ct[coef_name, "Pr(>|t|)"]),
    n    = as.integer(model$nobs),
    r2   = fitstat(model, "r2")[[1]]
  )
}

# ── Block 1: Province + Region×Wave FE ─────────────────────────
cat("[48] Block 1: Province + Region×Wave FE\n")

m_eq1_prw <- feols(price_exp ~ meat_shock | province_factor + region_wave,
                   data = exp_sample, vcov = ~province)
results <- c(results, list(extract(m_eq1_prw, "eq1_prov_rw", "price_exp")))
cat(sprintf("  Eq1 prov+RW: beta=%.4f se=%.4f p=%.4f\n",
            coeftable(m_eq1_prw)["meat_shock","Estimate"],
            coeftable(m_eq1_prw)["meat_shock","Std. Error"],
            coeftable(m_eq1_prw)["meat_shock","Pr(>|t|)"]))

m_eq3_prw <- feols(fe_clean ~ meat_shock | province_factor + region_wave,
                   data = fe_sample, vcov = ~province)
results <- c(results, list(extract(m_eq3_prw, "eq3_prov_rw", "fe_clean")))
cat(sprintf("  Eq3 prov+RW: beta=%.4f se=%.4f p=%.4f\n",
            coeftable(m_eq3_prw)["meat_shock","Estimate"],
            coeftable(m_eq3_prw)["meat_shock","Std. Error"],
            coeftable(m_eq3_prw)["meat_shock","Pr(>|t|)"]))

# Eq2 at province-wave level
pw_cpi <- unique(cfps[, .(province_factor, wave_factor, region_wave,
                          meat_shock, realized_cpi_ann, region)],
                 by = c("province_factor", "wave_factor"))
pw_cpi <- pw_cpi[!is.na(realized_cpi_ann) & !is.na(meat_shock)]
cat(sprintf("[48] Eq2 province-wave cells: %d\n", nrow(pw_cpi)))

m_eq2_prw <- tryCatch(
  feols(realized_cpi_ann ~ meat_shock | province_factor + region_wave,
        data = pw_cpi),
  error = function(e) {
    cat(sprintf("  Eq2 prov+RW failed (likely collinear): %s\n", e$message))
    NULL
  }
)
if (!is.null(m_eq2_prw)) {
  results <- c(results, list(extract(m_eq2_prw, "eq2_prov_rw", "realized_cpi_ann")))
}

# Province + Region×Wave FE with demographics
m_eq1_prw_d <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                       province_factor + region_wave,
                     data = exp_sample, vcov = ~province)
results <- c(results, list(extract(m_eq1_prw_d, "eq1_prov_rw_demog", "price_exp")))

m_eq3_prw_d <- feols(fe_clean ~ meat_shock + age + edu_high + urban |
                       province_factor + region_wave,
                     data = fe_sample, vcov = ~province)
results <- c(results, list(extract(m_eq3_prw_d, "eq3_prov_rw_demog", "fe_clean")))

# ── Block 2: Collapsed cell-level estimation ───────────────────
cat("[48] Block 2: Collapsed cell-level estimation\n")

cell_exp <- exp_sample[, .(
  price_exp = mean(price_exp, na.rm = TRUE),
  meat_shock = meat_shock[1],
  region = region[1],
  n_hh = .N
), by = .(province_factor, wave_factor)]
cell_exp[, region_wave := as.factor(paste0(region, "_", wave_factor))]

cell_fe <- fe_sample[, .(
  fe_clean = mean(fe_clean, na.rm = TRUE),
  meat_shock = meat_shock[1],
  region = region[1],
  n_hh = .N
), by = .(province_factor, wave_factor)]
cell_fe[, region_wave := as.factor(paste0(region, "_", wave_factor))]

m_cell_eq1 <- feols(price_exp ~ meat_shock | region_wave,
                    data = cell_exp, weights = ~n_hh, vcov = ~province_factor)
results <- c(results, list(extract(m_cell_eq1, "eq1_collapsed", "price_exp")))
cat(sprintf("  Collapsed Eq1: beta=%.4f se=%.4f p=%.4f N=%d\n",
            coeftable(m_cell_eq1)["meat_shock","Estimate"],
            coeftable(m_cell_eq1)["meat_shock","Std. Error"],
            coeftable(m_cell_eq1)["meat_shock","Pr(>|t|)"],
            m_cell_eq1$nobs))

m_cell_eq3 <- feols(fe_clean ~ meat_shock | region_wave,
                    data = cell_fe, weights = ~n_hh, vcov = ~province_factor)
results <- c(results, list(extract(m_cell_eq3, "eq3_collapsed", "fe_clean")))
cat(sprintf("  Collapsed Eq3: beta=%.4f se=%.4f p=%.4f N=%d\n",
            coeftable(m_cell_eq3)["meat_shock","Estimate"],
            coeftable(m_cell_eq3)["meat_shock","Std. Error"],
            coeftable(m_cell_eq3)["meat_shock","Pr(>|t|)"],
            m_cell_eq3$nobs))

# ── Block 3: Randomization inference ──────────────────────────
cat("[48] Block 3: Randomization inference (2000 permutations)\n")
set.seed(20260408)
n_perm <- 2000L

# For Eq3 with region×wave FE: permute meat_shock within region×wave cells
obs_beta3 <- coeftable(feols(fe_clean ~ meat_shock | region_wave,
                              data = fe_sample, vcov = ~province))["meat_shock", "Estimate"]

perm_betas <- numeric(n_perm)
for (i in seq_len(n_perm)) {
  tmp <- copy(fe_sample)
  tmp[, meat_shock := sample(meat_shock), by = region_wave]
  m_perm <- feols(fe_clean ~ meat_shock | region_wave, data = tmp, vcov = ~province)
  perm_betas[i] <- coeftable(m_perm)["meat_shock", "Estimate"]
}
ri_p_eq3 <- mean(abs(perm_betas) >= abs(obs_beta3))
cat(sprintf("  RI p-value for Eq3 (RW FE): %.4f (obs beta = %.4f)\n",
            ri_p_eq3, obs_beta3))

results <- c(results, list(data.table(
  spec = "eq3_ri", dep_var = "fe_clean", coefficient = "meat_shock",
  beta = obs_beta3, se = NA_real_, p = ri_p_eq3,
  n = as.integer(fe_sample[, .N]), r2 = NA_real_
)))

# RI for Eq1
obs_beta1 <- coeftable(feols(price_exp ~ meat_shock | region_wave,
                              data = exp_sample, vcov = ~province))["meat_shock", "Estimate"]
perm_betas1 <- numeric(n_perm)
for (i in seq_len(n_perm)) {
  tmp <- copy(exp_sample)
  tmp[, meat_shock := sample(meat_shock), by = region_wave]
  m_perm <- feols(price_exp ~ meat_shock | region_wave, data = tmp, vcov = ~province)
  perm_betas1[i] <- coeftable(m_perm)["meat_shock", "Estimate"]
}
ri_p_eq1 <- mean(abs(perm_betas1) >= abs(obs_beta1))
cat(sprintf("  RI p-value for Eq1 (RW FE): %.4f (obs beta = %.4f)\n",
            ri_p_eq1, obs_beta1))

results <- c(results, list(data.table(
  spec = "eq1_ri", dep_var = "price_exp", coefficient = "meat_shock",
  beta = obs_beta1, se = NA_real_, p = ri_p_eq1,
  n = as.integer(exp_sample[, .N]), r2 = NA_real_
)))

# ── Block 4: Drop 2022 wave ──────────────────────────────────
cat("[48] Block 4: Drop-2022 robustness\n")

exp_no22 <- exp_sample[wave != 2022]
fe_no22  <- fe_sample[wave != 2022]

m_eq1_no22 <- feols(price_exp ~ meat_shock | region_wave,
                    data = exp_no22, vcov = ~province)
results <- c(results, list(extract(m_eq1_no22, "eq1_drop2022", "price_exp")))

m_eq3_no22 <- feols(fe_clean ~ meat_shock | region_wave,
                    data = fe_no22, vcov = ~province)
results <- c(results, list(extract(m_eq3_no22, "eq3_drop2022", "fe_clean")))

cat(sprintf("  Drop-2022 Eq1: beta=%.4f p=%.4f N=%d\n",
            coeftable(m_eq1_no22)["meat_shock","Estimate"],
            coeftable(m_eq1_no22)["meat_shock","Pr(>|t|)"],
            m_eq1_no22$nobs))
cat(sprintf("  Drop-2022 Eq3: beta=%.4f p=%.4f N=%d\n",
            coeftable(m_eq3_no22)["meat_shock","Estimate"],
            coeftable(m_eq3_no22)["meat_shock","Pr(>|t|)"],
            m_eq3_no22$nobs))

# ── Block 5: Leave-one-region-out ────────────────────────────
cat("[48] Block 5: Leave-one-region-out\n")

regions <- unique(fe_sample$region)
regions <- regions[!is.na(regions)]

for (r in regions) {
  sub <- fe_sample[region != r]
  if (nrow(sub) < 50) next
  m <- tryCatch(
    feols(fe_clean ~ meat_shock | region_wave, data = sub, vcov = ~province),
    error = function(e) NULL
  )
  if (!is.null(m)) {
    results <- c(results, list(extract(m, paste0("eq3_drop_", r), "fe_clean")))
    cat(sprintf("  Drop region %s: beta=%.4f p=%.4f N=%d\n",
                r,
                coeftable(m)["meat_shock","Estimate"],
                coeftable(m)["meat_shock","Pr(>|t|)"],
                m$nobs))
  }
}

# Same for Eq1
for (r in regions) {
  sub <- exp_sample[region != r]
  if (nrow(sub) < 50) next
  m <- tryCatch(
    feols(price_exp ~ meat_shock | region_wave, data = sub, vcov = ~province),
    error = function(e) NULL
  )
  if (!is.null(m)) {
    results <- c(results, list(extract(m, paste0("eq1_drop_", r), "price_exp")))
  }
}

# ── Save results ─────────────────────────────────────────────
out <- rbindlist(results, use.names = TRUE, fill = TRUE)
csv_out <- file.path(project_paths$tables, "revision_new_results.csv")
fwrite(out, csv_out)
cat(sprintf("[48] Saved %d rows to %s\n", nrow(out), csv_out))
cat("[48] Done.\n")
