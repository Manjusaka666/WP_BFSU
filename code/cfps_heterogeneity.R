## CFPS Household-Level Heterogeneity Analysis
## Produces: cfps_interactions.tex, cfps_monotonicity.tex

library(data.table)

# Try fixest first; fall back to lm + sandwich
use_fixest <- requireNamespace("fixest", quietly = TRUE)
if (use_fixest) {
  library(fixest)
  message("Using fixest for estimation.")
} else {
  library(sandwich)
  library(lmtest)
  message("fixest not available; using lm + sandwich.")
}

# ---------- 1. Load data ----------
dt <- fread("E:/研究生/WP_BFSU/data/processed/cfps_revision_panel.csv")
message(sprintf("Raw rows: %d", nrow(dt)))

# Ensure key variables are present and non-missing for the interaction models
vars_needed <- c("fe_proxy", "revision", "province", "wave",
                 "edu_high", "income_below_median", "urban")
dt_int <- dt[complete.cases(dt[, ..vars_needed])]
message(sprintf("Interaction sample (complete cases): %d", nrow(dt_int)))

# Factor province and wave
dt_int[, province := as.factor(province)]
dt_int[, wave     := as.factor(wave)]

# ---------- 2. Interaction regressions ----------
interactions <- list(
  edu_high           = "edu_high",
  income_below_median = "income_below_median",
  urban              = "urban"
)

int_results <- list()

for (nm in names(interactions)) {
  xi <- interactions[[nm]]

  if (use_fixest) {
    fml <- as.formula(paste0(
      "fe_proxy ~ revision * ", xi, " | province + wave"
    ))
    fit <- feols(fml, data = dt_int, cluster = ~province)

    cf <- coef(fit)
    se <- se(fit)
    pv <- pvalue(fit)

    # fixest absorbs FE, so coefficients are: revision, xi, revision:xi
    rev_name  <- "revision"
    xi_name   <- xi
    int_name  <- paste0("revision:", xi)

    int_results[[nm]] <- data.table(
      variable       = nm,
      beta_revision  = cf[rev_name],
      se_revision    = se[rev_name],
      p_revision     = pv[rev_name],
      beta_xi        = cf[xi_name],
      se_xi          = se[xi_name],
      p_xi           = pv[xi_name],
      beta_interact  = cf[int_name],
      se_interact    = se[int_name],
      p_interact     = pv[int_name],
      n              = nobs(fit),
      r2             = fitstat(fit, "r2")[[1]]
    )

  } else {
    fml <- as.formula(paste0(
      "fe_proxy ~ revision * ", xi, " + province + wave"
    ))
    fit <- lm(fml, data = dt_int)
    vcov_cl <- vcovCL(fit, cluster = dt_int$province)
    ct <- coeftest(fit, vcov. = vcov_cl)

    rev_name <- "revision"
    xi_name  <- xi
    int_name <- paste0("revision:", xi)

    int_results[[nm]] <- data.table(
      variable       = nm,
      beta_revision  = ct[rev_name, 1],
      se_revision    = ct[rev_name, 2],
      p_revision     = ct[rev_name, 4],
      beta_xi        = ct[xi_name, 1],
      se_xi          = ct[xi_name, 2],
      p_xi           = ct[xi_name, 4],
      beta_interact  = ct[int_name, 1],
      se_interact    = ct[int_name, 2],
      p_interact     = ct[int_name, 4],
      n              = nobs(fit),
      r2             = summary(fit)$r.squared
    )
  }
}

int_tab <- rbindlist(int_results)
cat("\n=== INTERACTION REGRESSION RESULTS ===\n")
print(int_tab, digits = 4)

# ---------- 3. Attention tercile regressions ----------
vars_att <- c("fe_proxy", "revision", "province", "wave", "attention_tercile")
dt_att <- dt[complete.cases(dt[, ..vars_att])]
dt_att[, province := as.factor(province)]
dt_att[, wave     := as.factor(wave)]
message(sprintf("Attention tercile sample (complete cases): %d", nrow(dt_att)))

terciles <- sort(unique(dt_att$attention_tercile))
att_results <- list()

for (q in terciles) {
  sub <- dt_att[attention_tercile == q]

  if (use_fixest) {
    fit <- feols(fe_proxy ~ revision | province + wave,
                 data = sub, cluster = ~province)
    cf <- coef(fit)
    se_v <- se(fit)
    pv <- pvalue(fit)

    att_results[[as.character(q)]] <- data.table(
      attention_tercile = q,
      beta              = cf["revision"],
      se                = se_v["revision"],
      t_stat            = cf["revision"] / se_v["revision"],
      p_value           = pv["revision"],
      n                 = nobs(fit),
      r2                = fitstat(fit, "r2")[[1]]
    )
  } else {
    fit <- lm(fe_proxy ~ revision + province + wave, data = sub)
    vcov_cl <- vcovCL(fit, cluster = sub$province)
    ct <- coeftest(fit, vcov. = vcov_cl)

    att_results[[as.character(q)]] <- data.table(
      attention_tercile = q,
      beta              = ct["revision", 1],
      se                = ct["revision", 2],
      t_stat            = ct["revision", 3],
      p_value           = ct["revision", 4],
      n                 = nobs(fit),
      r2                = summary(fit)$r.squared
    )
  }
}

att_tab <- rbindlist(att_results)
att_tab[, ci_low  := beta - 1.96 * se]
att_tab[, ci_high := beta + 1.96 * se]

cat("\n=== ATTENTION TERCILE RESULTS ===\n")
print(att_tab, digits = 4)

# ---------- 4. Save LaTeX tables ----------
outdir <- "E:/研究生/WP_BFSU/outputs/tables"

# --- cfps_interactions.tex ---
stars <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))

tex_int <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{CFPS Household-Level Interaction Regressions}",
  "\\label{tab:cfps_interactions}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & Education & Income & Urban \\\\",
  " & (High) & (Below Median) & \\\\",
  "\\midrule"
)

# Row: Revision
tex_int <- c(tex_int, sprintf(
  "Revision & %s & %s & %s \\\\",
  sprintf("%.3f%s", int_tab$beta_revision[1], stars(int_tab$p_revision[1])),
  sprintf("%.3f%s", int_tab$beta_revision[2], stars(int_tab$p_revision[2])),
  sprintf("%.3f%s", int_tab$beta_revision[3], stars(int_tab$p_revision[3]))
))
tex_int <- c(tex_int, sprintf(
  " & (%.3f) & (%.3f) & (%.3f) \\\\",
  int_tab$se_revision[1], int_tab$se_revision[2], int_tab$se_revision[3]
))

# Row: X_i
tex_int <- c(tex_int, sprintf(
  "$X_i$ & %s & %s & %s \\\\",
  sprintf("%.3f%s", int_tab$beta_xi[1], stars(int_tab$p_xi[1])),
  sprintf("%.3f%s", int_tab$beta_xi[2], stars(int_tab$p_xi[2])),
  sprintf("%.3f%s", int_tab$beta_xi[3], stars(int_tab$p_xi[3]))
))
tex_int <- c(tex_int, sprintf(
  " & (%.3f) & (%.3f) & (%.3f) \\\\",
  int_tab$se_xi[1], int_tab$se_xi[2], int_tab$se_xi[3]
))

# Row: Revision x X_i
tex_int <- c(tex_int, sprintf(
  "Revision $\\times$ $X_i$ & %s & %s & %s \\\\",
  sprintf("%.3f%s", int_tab$beta_interact[1], stars(int_tab$p_interact[1])),
  sprintf("%.3f%s", int_tab$beta_interact[2], stars(int_tab$p_interact[2])),
  sprintf("%.3f%s", int_tab$beta_interact[3], stars(int_tab$p_interact[3]))
))
tex_int <- c(tex_int, sprintf(
  " & (%.3f) & (%.3f) & (%.3f) \\\\",
  int_tab$se_interact[1], int_tab$se_interact[2], int_tab$se_interact[3]
))

tex_int <- c(tex_int,
  "\\midrule",
  sprintf("Observations & %s & %s & %s \\\\",
    formatC(int_tab$n[1], format = "d", big.mark = ","),
    formatC(int_tab$n[2], format = "d", big.mark = ","),
    formatC(int_tab$n[3], format = "d", big.mark = ",")),
  sprintf("$R^2$ & %.3f & %.3f & %.3f \\\\",
    int_tab$r2[1], int_tab$r2[2], int_tab$r2[3]),
  "Province FE & Yes & Yes & Yes \\\\",
  "Wave FE & Yes & Yes & Yes \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item Standard errors clustered at the province level in parentheses.",
  "\\item $^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.1$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(tex_int, file.path(outdir, "cfps_interactions.tex"))
message("Saved cfps_interactions.tex")

# --- cfps_monotonicity.tex ---
tercile_labels <- c("Bottom (most constrained)", "Middle", "Top (least constrained)")

tex_mon <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{CFPS Diagnostic Coefficient by Attention Tercile}",
  "\\label{tab:cfps_monotonicity}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Attention tercile & $\\hat{\\beta}$ & SE & $t$-stat & $N$ & 95\\% CI \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(att_tab))) {
  tex_mon <- c(tex_mon, sprintf(
    "%s & %.3f%s & %.3f & %.2f & %s & [%.3f, %.3f] \\\\",
    tercile_labels[i],
    att_tab$beta[i], stars(att_tab$p_value[i]),
    att_tab$se[i],
    att_tab$t_stat[i],
    formatC(att_tab$n[i], format = "d", big.mark = ","),
    att_tab$ci_low[i], att_tab$ci_high[i]
  ))
}

tex_mon <- c(tex_mon,
  "\\midrule",
  "Province FE & \\multicolumn{5}{c}{Yes} \\\\",
  "Wave FE & \\multicolumn{5}{c}{Yes} \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]",
  "\\footnotesize",
  "\\item Each column reports results from a separate regression of the forecast-error proxy on revision,",
  "estimated within the given attention tercile. Standard errors clustered at the province level.",
  "\\item $^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.1$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(tex_mon, file.path(outdir, "cfps_monotonicity.tex"))
message("Saved cfps_monotonicity.tex")

cat("\n=== DONE ===\n")
