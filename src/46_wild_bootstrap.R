#!/usr/bin/env Rscript
# 46_wild_bootstrap.R
# Manual wild cluster bootstrap (Webb six-point) for Eq1 and Eq3 (CP-based).

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

webb_weights <- c(-sqrt(3 / 2), -1, -sqrt(1 / 2), sqrt(1 / 2), 1, sqrt(3 / 2))

clip_prob <- function(x, eps = 0.001) pmin(pmax(x, eps), 1 - eps)

build_cp_cells <- function(cfps, delta = 0.5) {
  cell <- cfps[, .(
    p_down = mean(price_exp == -1, na.rm = TRUE),
    p_up = mean(price_exp == 1, na.rm = TRUE),
    realized_cpi_ann = realized_cpi_ann[1]
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
  cell[, .(province, wave, mu_cp, fe_cp)]
}

extract_fe_vars <- function(fe_spec) {
  trimws(strsplit(fe_spec, "\\+", fixed = FALSE)[[1]])
}

run_manual_webb_wcb <- function(data, dep_var, fe_spec, cluster_var, B = 9999L,
                                coef_name = "meat_shock", verbose = TRUE) {
  fe_vars <- extract_fe_vars(fe_spec)
  required_vars <- unique(c(dep_var, coef_name, fe_vars, cluster_var))

  if (!all(required_vars %in% names(data))) {
    stop(sprintf("Missing required variables: %s",
                 paste(setdiff(required_vars, names(data)), collapse = ", ")))
  }

  model_data <- copy(data)[, ..required_vars]
  model_data <- model_data[complete.cases(model_data)]
  model_data <- as.data.frame(model_data)

  if (nrow(model_data) == 0L) stop(sprintf("No complete observations for %s | %s", dep_var, fe_spec))

  model_data[[cluster_var]] <- as.factor(model_data[[cluster_var]])
  cluster_fml <- as.formula(paste0("~", cluster_var))
  fml <- as.formula(sprintf("%s ~ %s | %s", dep_var, coef_name, fe_spec))
  fit <- feols(fml, data = model_data, vcov = cluster_fml)

  fml_restricted <- as.formula(sprintf("%s ~ 1 | %s", dep_var, fe_spec))
  fit_restricted <- feols(fml_restricted, data = model_data)
  ct <- coeftable(fit)

  if (!(coef_name %in% rownames(ct))) {
    stop(sprintf("Coefficient '%s' not estimated in %s | %s", coef_name, dep_var, fe_spec))
  }

  t_observed <- as.numeric(ct[coef_name, "t value"])
  p_asymptotic <- as.numeric(ct[coef_name, "Pr(>|t|)"])
  beta <- as.numeric(ct[coef_name, "Estimate"])

  restricted_fitted <- as.numeric(fitted(fit_restricted))
  unrestricted_resid <- as.numeric(resid(fit))

  cluster_vec <- as.character(model_data[[cluster_var]])
  cluster_levels <- unique(cluster_vec)
  cluster_index <- match(cluster_vec, cluster_levels)
  n_clusters <- length(cluster_levels)
  if (n_clusters < 2L) stop("Need at least 2 clusters.")

  fml_star <- as.formula(sprintf("y_star ~ %s | %s", coef_name, fe_spec))
  t_boot <- rep(NA_real_, B)
  model_data$y_star <- NA_real_

  if (verbose) {
    cat(sprintf("\n[46] %s | %s -> %d obs, %d clusters, B=%d\n",
                dep_var, fe_spec, nrow(model_data), n_clusters, B))
  }

  for (b in seq_len(B)) {
    draws <- sample(webb_weights, size = n_clusters, replace = TRUE)
    model_data$y_star <- restricted_fitted + unrestricted_resid * draws[cluster_index]

    fit_star <- tryCatch(feols(fml_star, data = model_data, vcov = cluster_fml), error = function(e) NULL)
    if (!is.null(fit_star)) {
      ct_star <- coeftable(fit_star)
      if (coef_name %in% rownames(ct_star)) t_boot[b] <- as.numeric(ct_star[coef_name, "t value"])
    }
  }

  valid <- is.finite(t_boot)
  if (!any(valid)) stop(sprintf("No valid bootstrap draws for %s | %s", dep_var, fe_spec))

  list(
    beta = beta,
    t_observed = t_observed,
    p_asymptotic = p_asymptotic,
    p_bootstrap = mean(abs(t_boot[valid]) >= abs(t_observed)),
    n_obs = nrow(model_data),
    n_clusters = n_clusters,
    valid_boot_draws = sum(valid)
  )
}

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(price_exp) & !is.na(meat_shock) & !is.na(province) & province > 0]
cfps[, province_factor := as.factor(province)]
cfps[, wave_factor := as.factor(wave)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

cp_cells <- build_cp_cells(cfps, delta = 0.5)
cfps <- merge(cfps, cp_cells, by = c("province", "wave"), all.x = TRUE)

set.seed(42)
B <- as.integer(Sys.getenv("WILD_BOOTSTRAP_B", "9999"))
if (is.na(B) || B <= 0L) stop("WILD_BOOTSTRAP_B must be a positive integer.")

model_specs <- data.table(
  equation = c("Eq1", "Eq1", "Eq1", "Eq3_CP", "Eq3_CP", "Eq3_CP"),
  dep_var = c("price_exp", "price_exp", "price_exp", "fe_cp", "fe_cp", "fe_cp"),
  fe_spec = c(
    "province_factor + wave_factor",
    "region_wave",
    "province_factor + region_wave",
    "province_factor + wave_factor",
    "region_wave",
    "province_factor + region_wave"
  )
)

cat(sprintf("[46] Loaded %d rows from %s\n", nrow(cfps), file.path(project_paths$processed, "cfps_panel.csv")))
cat(sprintf("[46] Running manual Webb wild cluster bootstrap with B=%d\n", B))

results_list <- vector("list", nrow(model_specs))
for (i in seq_len(nrow(model_specs))) {
  spec <- model_specs[i]
  out <- run_manual_webb_wcb(
    data = cfps,
    dep_var = spec$dep_var,
    fe_spec = spec$fe_spec,
    cluster_var = "province_factor",
    B = B,
    coef_name = "meat_shock",
    verbose = TRUE
  )

  results_list[[i]] <- data.table(
    equation = spec$equation,
    dep_var = spec$dep_var,
    fe_spec = spec$fe_spec,
    beta = out$beta,
    t_observed = out$t_observed,
    p_asymptotic = out$p_asymptotic,
    p_bootstrap = out$p_bootstrap,
    n_obs = out$n_obs,
    n_clusters = out$n_clusters,
    valid_boot_draws = out$valid_boot_draws,
    B = B
  )
}

results <- rbindlist(results_list, use.names = TRUE, fill = TRUE)
out_file <- file.path(project_paths$tables, "wild_bootstrap.csv")
fwrite(results, out_file)

boot_tab <- copy(results)[, .(
  Equation = equation,
  `Dependent variable` = dep_var,
  `FE structure` = fe_spec,
  Beta = round(beta, 3),
  `Asymptotic p` = round(p_asymptotic, 4),
  `Bootstrap p` = round(p_bootstrap, 4),
  `N` = n_obs,
  Clusters = n_clusters
)]
write_booktabs_table(
  boot_tab,
  file.path(project_paths$tables, "wild_bootstrap.tex"),
  caption = "Wild Cluster Bootstrap Results for Main Specifications",
  label = "tab:wild_bootstrap",
  notes = c("Webb six-point weights with B bootstrap draws; clustered by province."),
  digits = 4,
  escape = TRUE
)

cat("\n[46] Asymptotic vs bootstrap p-values\n")
print(results[, .(equation, dep_var, fe_spec, p_asymptotic, p_bootstrap, B)])
cat(sprintf("\n[46] Saved results: %s\n", out_file))
