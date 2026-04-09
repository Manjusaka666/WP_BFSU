#!/usr/bin/env Rscript
# 52_cp_revision_diagnostics.R
# Diagnostics for CP-main specification: overlap, placebo grid, and leverage checks.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

clip_prob <- function(x, eps = 0.001) pmin(pmax(x, eps), 1 - eps)

build_cp_cells <- function(cfps, delta = 0.5) {
  cell <- cfps[, .(
    p_down = mean(price_exp == -1, na.rm = TRUE),
    p_up = mean(price_exp == 1, na.rm = TRUE),
    realized_cpi_ann = realized_cpi_ann[1],
    region = region[1]
  ), by = .(province, wave)]

  cell <- cell[!is.na(realized_cpi_ann)]
  cell[, p_down_c := clip_prob(p_down)]
  cell[, p_up_c := clip_prob(p_up)]
  cell[, z_d := qnorm(p_down_c)]
  cell[, z_u := qnorm(1 - p_up_c)]
  cell[, sigma_cp := 2 * delta / (z_u - z_d)]
  cell[, mu_cp := delta - sigma_cp * z_u]
  cell[!is.finite(sigma_cp) | sigma_cp <= 0, c("sigma_cp", "mu_cp") := .(NA_real_, NA_real_)]
  cell[, fe_cp := realized_cpi_ann - mu_cp]
  cell
}

extract_coef <- function(model, coef_name = "meat_shock") {
  ct <- coeftable(model)
  data.table(
    beta = as.numeric(ct[coef_name, "Estimate"]),
    se = as.numeric(ct[coef_name, "Std. Error"]),
    p = as.numeric(ct[coef_name, "Pr(>|t|)"]),
    n = model$nobs
  )
}

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(price_exp) & !is.na(meat_shock) & province > 0]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

cp_cells <- build_cp_cells(cfps, delta = 0.5)
cfps <- merge(cfps, cp_cells[, .(province, wave, fe_cp)], by = c("province", "wave"), all.x = TRUE)
cfps <- cfps[!is.na(fe_cp)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

# Preferred baseline model
m_base <- feols(fe_cp ~ meat_shock | province_factor + region_wave, data = cfps, vcov = ~province)
base_coef <- extract_coef(m_base)
fwrite(base_coef, file.path(project_paths$tables, "cp_preferred_coef.csv"))

# 1) Support / overlap by region-wave
overlap <- cfps[, .(
  n_obs = .N,
  n_provinces = uniqueN(province),
  shock_min = min(meat_shock, na.rm = TRUE),
  shock_p10 = quantile(meat_shock, 0.10, na.rm = TRUE),
  shock_p90 = quantile(meat_shock, 0.90, na.rm = TRUE),
  shock_max = max(meat_shock, na.rm = TRUE)
), by = .(region, wave)]
setorder(overlap, wave, region)
fwrite(overlap, file.path(project_paths$tables, "robustness_support_overlap.csv"))

# 2) Leave-one-province-out leverage
provs <- sort(unique(cfps$province))
loo <- rbindlist(lapply(provs, function(p) {
  d <- cfps[province != p]
  m <- feols(fe_cp ~ meat_shock | province_factor + region_wave, data = d, vcov = ~province)
  cbind(data.table(drop_province = p), extract_coef(m))
}), use.names = TRUE, fill = TRUE)
loo[, beta_gap_vs_base := beta - base_coef$beta]
fwrite(loo, file.path(project_paths$tables, "robustness_leave_one_province_out.csv"))

loo_summary <- data.table(
  stat = c("Baseline beta", "LOO min beta", "LOO max beta", "LOO SD beta", "Share same sign as baseline"),
  value = c(
    base_coef$beta,
    min(loo$beta),
    max(loo$beta),
    sd(loo$beta),
    mean(sign(loo$beta) == sign(base_coef$beta))
  )
)
fwrite(loo_summary, file.path(project_paths$tables, "robustness_leave_one_province_out_summary.csv"))

# 3) Wave-drop leverage (ASF episode leverage check)
waves <- sort(unique(cfps$wave))
wave_drop <- rbindlist(lapply(waves, function(w) {
  d <- cfps[wave != w]
  m <- feols(fe_cp ~ meat_shock | province_factor + region_wave, data = d, vcov = ~province)
  cbind(data.table(drop_wave = w), extract_coef(m))
}), use.names = TRUE, fill = TRUE)
wave_drop[, beta_gap_vs_base := beta - base_coef$beta]
fwrite(wave_drop, file.path(project_paths$tables, "robustness_leave_one_wave_out.csv"))

# 4) Placebo commodity grid
placebo_specs <- list(
  list(name = "meat_only", fml = fe_cp ~ meat_shock | province_factor + region_wave, coef = "meat_shock"),
  list(name = "grain_only", fml = fe_cp ~ grain_shock | province_factor + region_wave, coef = "grain_shock"),
  list(name = "egg_only", fml = fe_cp ~ egg_shock | province_factor + region_wave, coef = "egg_shock"),
  list(name = "horse_race_meat", fml = fe_cp ~ meat_shock + grain_shock + egg_shock | province_factor + region_wave, coef = "meat_shock"),
  list(name = "horse_race_grain", fml = fe_cp ~ meat_shock + grain_shock + egg_shock | province_factor + region_wave, coef = "grain_shock"),
  list(name = "horse_race_egg", fml = fe_cp ~ meat_shock + grain_shock + egg_shock | province_factor + region_wave, coef = "egg_shock")
)

placebo <- rbindlist(lapply(placebo_specs, function(s) {
  needed <- all.vars(s$fml)
  d <- cfps[complete.cases(cfps[, ..needed])]
  m <- feols(s$fml, data = d, vcov = ~province)
  out <- extract_coef(m, s$coef)
  cbind(data.table(spec = s$name, coefficient = s$coef), out)
}), use.names = TRUE, fill = TRUE)

horse <- feols(
  fe_cp ~ meat_shock + grain_shock + egg_shock | province_factor + region_wave,
  data = cfps[complete.cases(cfps[, .(fe_cp, meat_shock, grain_shock, egg_shock, province_factor, region_wave)])],
  vcov = ~province
)

linear_diff_test <- function(model, left, right, df = 30) {
  b <- coef(model)
  v <- vcov(model)
  d <- as.numeric(b[left] - b[right])
  var_d <- as.numeric(v[left, left] + v[right, right] - 2 * v[left, right])
  if (!is.finite(var_d) || var_d <= 0) {
    return(data.table(diff = d, t_stat = NA_real_, p_value = NA_real_))
  }
  t_stat <- d / sqrt(var_d)
  p_val <- 2 * pt(abs(t_stat), df = df, lower.tail = FALSE)
  data.table(diff = d, t_stat = t_stat, p_value = p_val)
}

wald_meat_grain <- linear_diff_test(horse, "meat_shock", "grain_shock")
wald_meat_egg <- linear_diff_test(horse, "meat_shock", "egg_shock")

wald_dt <- rbindlist(list(
  cbind(data.table(test = "meat = grain"), wald_meat_grain),
  cbind(data.table(test = "meat = egg"), wald_meat_egg)
), use.names = TRUE, fill = TRUE)

fwrite(placebo, file.path(project_paths$tables, "robustness_placebo_grid.csv"))
fwrite(wald_dt, file.path(project_paths$tables, "robustness_placebo_wald.csv"))

# LaTeX convenience tables
write_booktabs_table(
  loo_summary,
  file.path(project_paths$tables, "robustness_leave_one_province_out_summary.tex"),
  caption = "Leave-One-Province-Out Stability: CP Main Coefficient",
  label = "tab:loo_cp_summary",
  notes = c("Baseline model: fe_cp on meat shock with province FE and region-by-wave FE."),
  digits = 3,
  escape = FALSE
)

write_booktabs_table(
  placebo[, .(spec, coefficient, beta, se, p, n)],
  file.path(project_paths$tables, "robustness_placebo_grid.tex"),
  caption = "Commodity Placebo Grid (CP Main Outcome)",
  label = "tab:placebo_grid_cp",
  notes = c("All models use province FE and region-by-wave FE with province-clustered SE."),
  digits = 3,
  escape = TRUE
)

write_booktabs_table(
  overlap,
  file.path(project_paths$tables, "robustness_support_overlap.tex"),
  caption = "Within-Region Shock Support by Wave",
  label = "tab:support_overlap",
  notes = c("Reported distribution of meat-shock support by region-wave cell."),
  digits = 3,
  escape = TRUE
)

cat("[52] CP revision diagnostics completed.\n")
