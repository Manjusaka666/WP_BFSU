#!/usr/bin/env Rscript
# 47_revision_regressions.R
# Consolidated revision regressions for the meat-shock design:
# expectations and forecast errors under alternative FE/control structures.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
ensure_paths()

extract_coef <- function(model, coef_name) {
  ct <- coeftable(model)
  if (!(coef_name %in% rownames(ct))) {
    return(list(beta = NA_real_, se = NA_real_, p = NA_real_))
  }
  list(
    beta = as.numeric(ct[coef_name, "Estimate"]),
    se = as.numeric(ct[coef_name, "Std. Error"]),
    p = as.numeric(ct[coef_name, "Pr(>|t|)"])
  )
}

fmt_coef_cell <- function(x) {
  if (is.na(x$beta)) return("")
  fmt_coef(x$beta, x$p)
}

fmt_se_cell <- function(x) {
  if (is.na(x$se)) return("")
  fmt_se(x$se)
}

summarize_model <- function(model, spec_name, dep_var) {
  ct <- coeftable(model)
  keep <- intersect(c("meat_shock", "grain_shock"), rownames(ct))
  if (length(keep) == 0L) {
    return(data.table(
      spec = spec_name,
      dep_var = dep_var,
      coefficient = NA_character_,
      beta = NA_real_,
      se = NA_real_,
      p = NA_real_,
      n = as.integer(model$nobs),
      r2 = fitstat(model, "r2")[[1]]
    ))
  }

  data.table(
    spec = spec_name,
    dep_var = dep_var,
    coefficient = keep,
    beta = as.numeric(ct[keep, "Estimate"]),
    se = as.numeric(ct[keep, "Std. Error"]),
    p = as.numeric(ct[keep, "Pr(>|t|)"]),
    n = as.integer(model$nobs),
    r2 = fitstat(model, "r2")[[1]]
  )
}

build_revision_table <- function(models, meta, out_file) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  ncols <- length(models)
  col_ids <- paste0("(", seq_len(ncols), ")")

  meat_vals <- lapply(models, extract_coef, coef_name = "meat_shock")
  grain_vals <- lapply(models, extract_coef, coef_name = "grain_shock")
  n_vals <- sapply(models, function(m) formatC(as.integer(m$nobs), format = "d", big.mark = ","))
  r2_vals <- sapply(models, function(m) fmt_num(fitstat(m, "r2")[[1]], 3))

  lines <- c(
    "\\begin{table}[!htbp]",
    "\\centering",
    "\\caption{Revision Regressions: Meat Shock Effects Across Specifications}",
    "\\label{tab:revision_regressions}",
    "\\begin{threeparttable}",
    sprintf("\\begin{tabular}{l%s}", paste(rep("c", ncols), collapse = "")),
    "\\toprule",
    sprintf("& %s \\\\", paste(col_ids, collapse = " & ")),
    sprintf("& %s \\\\", paste(meta$col_label, collapse = " & ")),
    # Dep var row removed (AEA format; info in table note)
    "\\midrule",
    sprintf("Meat shock & %s \\\\",
            paste(sapply(meat_vals, fmt_coef_cell), collapse = " & ")),
    sprintf("& %s \\\\[4pt]",
            paste(sapply(meat_vals, fmt_se_cell), collapse = " & ")),
    sprintf("Grain shock & %s \\\\",
            paste(sapply(grain_vals, fmt_coef_cell), collapse = " & ")),
    sprintf("& %s \\\\[4pt]",
            paste(sapply(grain_vals, fmt_se_cell), collapse = " & ")),
    "\\midrule",
    sprintf("Demographics & %s \\\\", paste(meta$demographics, collapse = " & ")),
    sprintf("Province FE & %s \\\\", paste(meta$province_fe, collapse = " & ")),
    sprintf("Wave FE & %s \\\\", paste(meta$wave_fe, collapse = " & ")),
    sprintf("Region $\\times$ wave FE & %s \\\\", paste(meta$region_wave_fe, collapse = " & ")),
    sprintf("Observations & %s \\\\", paste(n_vals, collapse = " & ")),
    sprintf("$R^2$ & %s \\\\", paste(r2_vals, collapse = " & ")),
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]",
    "\\footnotesize",
    "\\item \\textit{Note.} Standard errors clustered at the province level in parentheses.",
    "\\item Demographics include age, high-education indicator, and urban indicator (with negative urban codes recoded to missing).",
    "\\item Column (4) is the horse-race specification that enters meat and grain shocks jointly.",
    "\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{table}"
  )

  writeLines(lines, con = out_file, useBytes = TRUE)
}

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
fe_sample <- cfps[!is.na(fe_clean)]
horse_sample <- exp_sample[!is.na(grain_shock)]

cat(sprintf("[47] Expectation sample: %d obs\n", nrow(exp_sample)))
cat(sprintf("[47] Forecast-error sample: %d obs\n", nrow(fe_sample)))
cat(sprintf("[47] Horse-race sample: %d obs\n", nrow(horse_sample)))

# Expectations revisions
m_exp_rw <- feols(price_exp ~ meat_shock | region_wave,
                  data = exp_sample, vcov = ~province)
m_exp_rw_demog <- feols(price_exp ~ meat_shock + age + edu_high + urban | region_wave,
                        data = exp_sample, vcov = ~province)
m_exp_pw <- feols(price_exp ~ meat_shock | province_factor + wave_factor,
                  data = exp_sample, vcov = ~province)
m_exp_horse <- feols(price_exp ~ meat_shock + grain_shock | region_wave,
                     data = horse_sample, vcov = ~province)

# Forecast-error revisions
m_fe_rw <- feols(fe_clean ~ meat_shock | region_wave,
                 data = fe_sample, vcov = ~province)
m_fe_rw_demog <- feols(fe_clean ~ meat_shock + age + edu_high + urban | region_wave,
                       data = fe_sample, vcov = ~province)

models <- list(
  m_exp_rw,
  m_exp_rw_demog,
  m_exp_pw,
  m_exp_horse,
  m_fe_rw,
  m_fe_rw_demog
)

model_meta <- data.table(
  spec = c("exp_rw", "exp_rw_demog", "exp_pw", "exp_horse", "fe_rw", "fe_rw_demog"),
  col_label = c("Exp: RW FE", "Exp: RW FE + X", "Exp: Prov+Wave FE",
                "Exp: Horse race", "FE: RW FE", "FE: RW FE + X"),
  dep_label = c("$\\mu_{it}$", "$\\mu_{it}$", "$\\mu_{it}$",
                "$\\mu_{it}$", "$FE_{it}$", "$FE_{it}$"),
  demographics = c("", "Yes", "", "", "", "Yes"),
  province_fe = c("", "", "Yes", "", "", ""),
  wave_fe = c("", "", "Yes", "", "", ""),
  region_wave_fe = c("Yes", "Yes", "", "Yes", "Yes", "Yes")
)

summary_dt <- rbindlist(list(
  summarize_model(m_exp_rw, "exp_rw", "price_exp"),
  summarize_model(m_exp_rw_demog, "exp_rw_demog", "price_exp"),
  summarize_model(m_exp_pw, "exp_pw", "price_exp"),
  summarize_model(m_exp_horse, "exp_horse", "price_exp"),
  summarize_model(m_fe_rw, "fe_rw", "fe_clean"),
  summarize_model(m_fe_rw_demog, "fe_rw_demog", "fe_clean")
), use.names = TRUE, fill = TRUE)

horse_meat <- extract_coef(m_exp_horse, "meat_shock")
horse_grain <- extract_coef(m_exp_horse, "grain_shock")
if (!is.na(horse_meat$beta) && !is.na(horse_grain$beta)) {
  vc <- vcov(m_exp_horse)
  diff_beta <- horse_meat$beta - horse_grain$beta
  diff_var <- vc["meat_shock", "meat_shock"] +
    vc["grain_shock", "grain_shock"] -
    2 * vc["meat_shock", "grain_shock"]
  if (is.finite(diff_var) && diff_var > 0) {
    diff_se <- sqrt(diff_var)
    diff_t <- diff_beta / diff_se
    diff_p <- 2 * pnorm(abs(diff_t), lower.tail = FALSE)
    summary_dt <- rbind(
      summary_dt,
      data.table(
        spec = "exp_horse",
        dep_var = "price_exp",
        coefficient = "meat_minus_grain",
        beta = diff_beta,
        se = diff_se,
        p = diff_p,
        n = as.integer(m_exp_horse$nobs),
        r2 = fitstat(m_exp_horse, "r2")[[1]]
      ),
      use.names = TRUE,
      fill = TRUE
    )
    cat(sprintf("[47] Horse-race difference (meat - grain): %.4f (SE %.4f, p %.4f)\n",
                diff_beta, diff_se, diff_p))
  }
}

csv_out <- file.path(project_paths$tables, "revision_regressions.csv")
fwrite(summary_dt, csv_out)

tex_out <- file.path(project_paths$tables, "revision_regressions.tex")
build_revision_table(models, model_meta, tex_out)

cat(sprintf("[47] Saved %s\n", csv_out))
cat(sprintf("[47] Saved %s\n", tex_out))
cat(sprintf("[47] Preferred expectations (RW FE): beta = %.4f, se = %.4f, p = %.4f\n",
            extract_coef(m_exp_rw, "meat_shock")$beta,
            extract_coef(m_exp_rw, "meat_shock")$se,
            extract_coef(m_exp_rw, "meat_shock")$p))
cat(sprintf("[47] Preferred forecast error (RW FE): beta = %.4f, se = %.4f, p = %.4f\n",
            extract_coef(m_fe_rw, "meat_shock")$beta,
            extract_coef(m_fe_rw, "meat_shock")$se,
            extract_coef(m_fe_rw, "meat_shock")$p))
