#!/usr/bin/env Rscript
# 49_carlson_parkin_oprobit.R
# Robustness: (1) Carlson-Parkin quantified expectations -> Eq3 forecast error
#             (2) Ordered probit of ordinal expectations on meat_shock

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(MASS)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

# ============================================================
# Load data (same as 42_meat_shock_regressions.R)
# ============================================================
cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_wave := paste0(region, "_", wave)]

cat(sprintf("[49] Full sample: %d obs, %d provinces, %d waves
",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))

# ============================================================
# TASK 1: Carlson-Parkin quantification at province x wave level
# ============================================================
# price_exp is coded as {-1, 0, 1} for {fall, same, rise}

# Compute shares per province x wave cell
cell <- cfps[, .(
  p_down = mean(price_exp == -1, na.rm = TRUE),
  p_same = mean(price_exp ==  0, na.rm = TRUE),
  p_up   = mean(price_exp ==  1, na.rm = TRUE),
  realized_cpi_ann = realized_cpi_ann[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]

# Drop cells with missing realized CPI
cell <- cell[!is.na(realized_cpi_ann)]

cat(sprintf("[49] Province x wave cells: %d
", nrow(cell)))

# Clip shares to avoid infinite quantiles
clip <- function(v) pmin(pmax(v, 0.001), 0.999)
cell[, p_down_c := clip(p_down)]
cell[, p_up_c   := clip(p_up)]

# Carlson-Parkin inversion
# z_d = qnorm(p_down)  => (-delta - mu_e) / sigma_e
# z_u = qnorm(1 - p_up) => (delta - mu_e) / sigma_e
# sigma_e = 2*delta / (z_u - z_d)
# mu_e = delta - sigma_e * z_u
# delta = 0.5 pp (half percentage point indifference zone)

delta <- 0.5

cell[, z_d := qnorm(p_down_c)]
cell[, z_u := qnorm(1 - p_up_c)]

cell[, sigma_cp := 2 * delta / (z_u - z_d)]
cell[, mu_cp := delta - sigma_cp * z_u]

# Drop cells where sigma is non-positive (degenerate cells)
cell[sigma_cp <= 0, c("mu_cp", "sigma_cp") := .(NA_real_, NA_real_)]

cat(sprintf("[49] CP quantification valid for %d / %d cells
",
            sum(!is.na(cell$mu_cp)), nrow(cell)))

# Forecast error: realized - quantified expectation
cell[, fe_cp := realized_cpi_ann - mu_cp]

# ============================================================
# Merge CP forecast error back to household level
# ============================================================
cfps_cp <- merge(cfps, cell[, .(province, wave, mu_cp, fe_cp)],
                 by = c("province", "wave"), all.x = TRUE)
cfps_cp <- cfps_cp[!is.na(fe_cp)]

cat(sprintf("[49] CP estimation sample: %d obs
", nrow(cfps_cp)))

# ============================================================
# Eq3 regressions with CP forecast error
# ============================================================
eq3cp_1 <- feols(fe_cp ~ meat_shock, data = cfps_cp, vcov = ~province)
eq3cp_2 <- feols(fe_cp ~ meat_shock + age + edu_high + urban,
                 data = cfps_cp, vcov = ~province)
eq3cp_3 <- feols(fe_cp ~ meat_shock | province_factor + wave_factor,
                 data = cfps_cp, vcov = ~province)
eq3cp_4 <- feols(fe_cp ~ meat_shock | region_wave,
                 data = cfps_cp, vcov = ~province)
eq3cp_5 <- feols(fe_cp ~ meat_shock + age + edu_high + urban | region_wave,
                 data = cfps_cp, vcov = ~province)
eq3cp_6 <- feols(fe_cp ~ meat_shock | province_factor + region_wave,
                 data = cfps_cp, vcov = ~province)

# ============================================================
# Helper: extract coefficient info (same as 42)
# ============================================================
format_col <- function(model, coef_name = "meat_shock") {
  ct <- coeftable(model)
  b  <- ct[coef_name, "Estimate"]
  se <- ct[coef_name, "Std. Error"]
  p  <- ct[coef_name, "Pr(>|t|)"]
  n  <- model$nobs
  r2 <- fitstat(model, "r2")[[1]]
  list(beta = b, se = se, p = p, n = n, r2 = r2)
}

eq3cp_cols <- lapply(list(eq3cp_1, eq3cp_2, eq3cp_3, eq3cp_4, eq3cp_5, eq3cp_6),
                     format_col)

# ============================================================
# Build LaTeX table matching eq3_forecast_error.tex style
# ============================================================
build_eq3cp_table <- function(cols, out_file) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)

  L <- character(0)
  add <- function(x) L <<- c(L, x)

  add("\\begin{table}[!htbp]")
  add("\\centering")
  add("\\caption{Meat Price Shock and Carlson-Parkin Forecast Errors}")
  add("\\label{tab:eq3_carlson_parkin}")
  add("\\begin{threeparttable}")
  add("\\footnotesize")
  add("\\setlength{\\tabcolsep}{3pt}")
  add("\\begin{tabular}{lcccccc}")
  add("\\toprule")
  add("& (1) & (2) & (3) & (4) & (5) & (6) \\\\")
  add("& Bivariate & Demographics & \\shortstack{Province\\\\+ wave} & \\shortstack{Region\\\\$\\times$ wave} & \\shortstack{Region $\\times$ wave\\\\+ demographics} & \\shortstack{Province +\\\\region $\\times$ wave} \\\\")
  add("\\midrule")

  betas <- sapply(cols, function(c) fmt_coef(c$beta, c$p))
  add(sprintf("Meat shock & %s \\\\", paste(betas, collapse = " & ")))

  ses <- sapply(cols, function(c) fmt_se(c$se))
  add(sprintf("& %s \\\\[6pt]", paste(ses, collapse = " & ")))

  add("Demographics &  & Yes &  &  & Yes &  \\\\")
  add("Province FE &  &  & Yes &  &  & Yes \\\\")
  add("Wave FE &  &  & Yes &  &  &  \\\\")
  add("Region $\\times$ wave FE &  &  &  & Yes & Yes & Yes \\\\")
  add("\\midrule")

  ns <- sapply(cols, function(c) formatC(c$n, format = "d", big.mark = ","))
  add(sprintf("Observations & %s \\\\", paste(ns, collapse = " & ")))

  r2s <- sapply(cols, function(c) fmt_num(c$r2, 3))
  add(sprintf("$R^2$ & %s \\\\", paste(r2s, collapse = " & ")))

  add("\\bottomrule")
  add("\\end{tabular}")

  add("\\begin{tablenotes}[flushleft]")
  add("\\footnotesize")
  add("\\item \\textit{Note.} The dependent variable is the Carlson-Parkin forecast error: realized province-level CPI inflation minus the Carlson-Parkin quantified expected inflation ($\\delta = 0.5$ pp). Standard errors clustered at the province level in parentheses. Column~(6) is the preferred specification.")
  add("\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.")
  add("\\end{tablenotes}")
  add("\\end{threeparttable}")
  add("\\end{table}")

  writeLines(L, con = out_file, useBytes = TRUE)
  cat(sprintf("[49] Wrote %s\n", out_file))
}

build_eq3cp_table(eq3cp_cols,
                  file.path(project_paths$tables, "eq3_carlson_parkin.tex"))

# ============================================================
# TASK 2: Ordered Probit
# ============================================================
# Create ordered factor from price_exp {-1, 0, 1}
cfps[, price_exp_ord := factor(price_exp, levels = c(-1, 0, 1),
                               labels = c("fall", "same", "rise"),
                               ordered = TRUE)]

cat("[49] Running ordered probit...\n")

# Spec 1: bivariate
oprobit_1 <- polr(price_exp_ord ~ meat_shock, data = cfps, method = "probit")
ct1 <- coef(summary(oprobit_1))
p1  <- 2 * pnorm(-abs(ct1["meat_shock", "t value"]))

# Spec 2: with region x wave dummies
oprobit_2 <- polr(price_exp_ord ~ meat_shock + region_wave, data = cfps,
                  method = "probit")
ct2 <- coef(summary(oprobit_2))
p2  <- 2 * pnorm(-abs(ct2["meat_shock", "t value"]))

cat(sprintf("[49] Ordered probit (bivariate):      beta = %.4f, se = %.4f, p = %.4f\n",
            ct1["meat_shock", "Value"], ct1["meat_shock", "Std. Error"], p1))
cat(sprintf("[49] Ordered probit (region x wave):  beta = %.4f, se = %.4f, p = %.4f\n",
            ct2["meat_shock", "Value"], ct2["meat_shock", "Std. Error"], p2))

# ============================================================
# Combine results into CSV
# ============================================================
results <- rbindlist(list(
  data.table(spec = "CP_Eq3_bivariate",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[1]]$beta, se = eq3cp_cols[[1]]$se,
             p = eq3cp_cols[[1]]$p, n = eq3cp_cols[[1]]$n,
             r2 = eq3cp_cols[[1]]$r2),
  data.table(spec = "CP_Eq3_demographics",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[2]]$beta, se = eq3cp_cols[[2]]$se,
             p = eq3cp_cols[[2]]$p, n = eq3cp_cols[[2]]$n,
             r2 = eq3cp_cols[[2]]$r2),
  data.table(spec = "CP_Eq3_prov_wave_FE",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[3]]$beta, se = eq3cp_cols[[3]]$se,
             p = eq3cp_cols[[3]]$p, n = eq3cp_cols[[3]]$n,
             r2 = eq3cp_cols[[3]]$r2),
  data.table(spec = "CP_Eq3_region_wave_FE",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[4]]$beta, se = eq3cp_cols[[4]]$se,
             p = eq3cp_cols[[4]]$p, n = eq3cp_cols[[4]]$n,
             r2 = eq3cp_cols[[4]]$r2),
  data.table(spec = "CP_Eq3_region_wave_FE_demog",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[5]]$beta, se = eq3cp_cols[[5]]$se,
             p = eq3cp_cols[[5]]$p, n = eq3cp_cols[[5]]$n,
             r2 = eq3cp_cols[[5]]$r2),
  data.table(spec = "CP_Eq3_prov_region_wave_FE",
             dep_var = "fe_cp", coefficient = "meat_shock",
             beta = eq3cp_cols[[6]]$beta, se = eq3cp_cols[[6]]$se,
             p = eq3cp_cols[[6]]$p, n = eq3cp_cols[[6]]$n,
             r2 = eq3cp_cols[[6]]$r2),
  data.table(spec = "OProbit_bivariate",
             dep_var = "price_exp_ord", coefficient = "meat_shock",
             beta = ct1["meat_shock", "Value"],
             se = ct1["meat_shock", "Std. Error"],
             p = p1, n = nrow(cfps), r2 = NA_real_),
  data.table(spec = "OProbit_region_wave_FE",
             dep_var = "price_exp_ord", coefficient = "meat_shock",
             beta = ct2["meat_shock", "Value"],
             se = ct2["meat_shock", "Std. Error"],
             p = p2, n = nrow(cfps), r2 = NA_real_)
))

fwrite(results, file.path(project_paths$tables, "carlson_parkin_results.csv"))
cat(sprintf("[49] Results saved to %s\n",
            file.path(project_paths$tables, "carlson_parkin_results.csv")))

# ============================================================
# Print key results
# ============================================================
cat("\n=== CARLSON-PARKIN EQ3 KEY RESULTS ===\n")
cat(sprintf("CP Eq3 (preferred, region x wave FE): beta = %.4f, se = %.4f, p = %.4f\n",
            eq3cp_cols[[4]]$beta, eq3cp_cols[[4]]$se, eq3cp_cols[[4]]$p))
cat(sprintf("CP Eq3 (prov + region x wave FE):     beta = %.4f, se = %.4f, p = %.4f\n",
            eq3cp_cols[[6]]$beta, eq3cp_cols[[6]]$se, eq3cp_cols[[6]]$p))
cat(sprintf("Ordered probit (region x wave):       beta = %.4f, se = %.4f, p = %.4f\n",
            ct2["meat_shock", "Value"], ct2["meat_shock", "Std. Error"], p2))

cat("\n[49] Carlson-Parkin and ordered probit robustness complete.\n")
