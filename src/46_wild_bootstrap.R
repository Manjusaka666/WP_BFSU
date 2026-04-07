#!/usr/bin/env Rscript
# 46_wild_bootstrap.R
# Manual wild cluster bootstrap (Webb six-point weights) for main equations.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

webb_weights <- c(-sqrt(3 / 2), -1, -sqrt(1 / 2), sqrt(1 / 2), 1, sqrt(3 / 2))

extract_fe_vars <- function(fe_spec) {
  trimws(strsplit(fe_spec, "\\+", fixed = FALSE)[[1]])
}

run_manual_webb_wcb <- function(data, dep_var, fe_spec, cluster_var, B = 9999L,
                                coef_name = "meat_shock", verbose = TRUE) {
  fe_vars <- extract_fe_vars(fe_spec)
  required_vars <- unique(c(dep_var, coef_name, fe_vars, cluster_var))

  if (!all(required_vars %in% names(data))) {
    missing_vars <- setdiff(required_vars, names(data))
    stop(sprintf("Missing required variables: %s", paste(missing_vars, collapse = ", ")))
  }

  model_data <- copy(data)[, ..required_vars]
  model_data <- model_data[complete.cases(model_data)]
  model_data <- as.data.frame(model_data)

  if (nrow(model_data) == 0L) {
    stop(sprintf("No complete observations for %s | %s", dep_var, fe_spec))
  }

  model_data[[cluster_var]] <- as.factor(model_data[[cluster_var]])
  cluster_fml <- as.formula(paste0("~", cluster_var))

  fml <- as.formula(sprintf("%s ~ %s | %s", dep_var, coef_name, fe_spec))
  fit <- feols(fml, data = model_data, vcov = cluster_fml)
  fml_restricted <- as.formula(sprintf("%s ~ 1 | %s", dep_var, fe_spec))
  fit_restricted <- feols(fml_restricted, data = model_data)
  ct <- coeftable(fit)

  if (!(coef_name %in% rownames(ct))) {
    stop(sprintf("Coefficient '%s' not estimated in model %s | %s", coef_name, dep_var, fe_spec))
  }

  t_observed <- as.numeric(ct[coef_name, "t value"])
  p_asymptotic <- as.numeric(ct[coef_name, "Pr(>|t|)"])
  beta <- as.numeric(ct[coef_name, "Estimate"])

  restricted_fitted_vals <- as.numeric(fitted(fit_restricted))
  unrestricted_residual_vals <- as.numeric(resid(fit))

  cluster_vec <- as.character(model_data[[cluster_var]])
  cluster_levels <- unique(cluster_vec)
  cluster_index <- match(cluster_vec, cluster_levels)

  n_clusters <- length(cluster_levels)
  if (n_clusters < 2L) {
    stop(sprintf("Need at least 2 clusters; found %d", n_clusters))
  }

  fml_star <- as.formula(sprintf("y_star ~ %s | %s", coef_name, fe_spec))
  t_boot <- rep(NA_real_, B)
  model_data$y_star <- NA_real_

  if (verbose) {
    cat(sprintf("\n[46] %s | %s -> %d obs, %d clusters, B=%d\n",
                dep_var, fe_spec, nrow(model_data), n_clusters, B))
  }

  for (b in seq_len(B)) {
    cluster_draws <- sample(webb_weights, size = n_clusters, replace = TRUE)
    model_data$y_star <- restricted_fitted_vals +
      unrestricted_residual_vals * cluster_draws[cluster_index]

    fit_star <- tryCatch(
      feols(fml_star, data = model_data, vcov = cluster_fml),
      error = function(e) NULL
    )

    if (!is.null(fit_star)) {
      ct_star <- coeftable(fit_star)
      if (coef_name %in% rownames(ct_star)) {
        t_boot[b] <- as.numeric(ct_star[coef_name, "t value"])
      }
    }

    if (verbose && (b %% 1000L == 0L || b == B)) {
      cat(sprintf("  [46] bootstrap draw %d / %d\n", b, B))
    }
  }

  valid_boot <- is.finite(t_boot)
  if (!any(valid_boot)) {
    stop(sprintf("No valid bootstrap draws for model %s | %s", dep_var, fe_spec))
  }

  p_bootstrap <- mean(abs(t_boot[valid_boot]) >= abs(t_observed))

  list(
    beta = beta,
    t_observed = t_observed,
    p_asymptotic = p_asymptotic,
    p_bootstrap = p_bootstrap,
    n_obs = nrow(model_data),
    n_clusters = n_clusters,
    valid_boot_draws = sum(valid_boot)
  )
}

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))

if (!"province" %in% names(cfps)) {
  stop("Input data must contain 'province' for clustering.")
}

cfps <- cfps[!is.na(province)]
if (is.numeric(cfps$province) || is.integer(cfps$province)) {
  cfps <- cfps[province > 0]
}

cfps[, province_factor := as.factor(province)]
cfps[, wave_factor := as.factor(wave)]
cfps[, region_wave := as.factor(paste0(region, "_", wave))]

set.seed(42)
B <- as.integer(Sys.getenv("WILD_BOOTSTRAP_B", "9999"))
if (is.na(B) || B <= 0L) {
  stop("WILD_BOOTSTRAP_B must be a positive integer.")
}

model_specs <- data.table(
  equation = c("Eq1", "Eq1", "Eq3", "Eq3"),
  dep_var = c("price_exp", "price_exp", "fe_clean", "fe_clean"),
  fe_spec = c("province_factor + wave_factor", "region_wave",
              "province_factor + wave_factor", "region_wave")
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

  cat(sprintf("  [46] Asymptotic p = %.4f | Bootstrap p = %.4f\n",
              out$p_asymptotic, out$p_bootstrap))

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

cat("\n[46] Asymptotic vs bootstrap p-values\n")
print(results[, .(equation, dep_var, fe_spec, p_asymptotic, p_bootstrap, B)])
cat(sprintf("\n[46] Saved results: %s\n", out_file))
