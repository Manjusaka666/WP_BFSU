#!/usr/bin/env Rscript
# ============================================================
# 14_build_chfs_analysis.R
# CHFS 2011 cross-section analysis + panel forward-tracking
# for diagnostic inflation expectations mechanism discrimination
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(haven)
  library(fixest)
  library(ggplot2)
  library(sandwich)
  library(lmtest)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

# ============================================================
# Helper: find .dta files under Chinese-named subdirectories
# ============================================================
find_dta <- function(base_dir, filename) {
  pattern <- file.path(base_dir, "**", filename)
  hits <- Sys.glob(pattern)
  if (length(hits) == 0L) {
    # Try one more level of nesting
    pattern2 <- file.path(base_dir, "*", "**", filename)
    hits <- Sys.glob(pattern2)
  }
  if (length(hits) == 0L) stop(sprintf("Cannot locate %s under %s", filename, base_dir))
  message(sprintf("  Found: %s", hits[1]))
  hits[1]
}

# ============================================================
# PART A: CHFS 2011 Cross-Section
# ============================================================
message("\n========================================")
message("[14] CHFS 2011 Cross-Section Analysis")
message("========================================\n")

chfs_base <- file.path("data", "raw", "CHFS", "CHFS2011")

# --- A1: Locate and read files ---
message("--- Locating CHFS 2011 data files ---")
hh_path     <- find_dta(chfs_base, "chfs2011_hh_20191120_version14.dta")
master_path <- find_dta(chfs_base, "chfs2011_master_202203.dta")

message("--- Reading HH file (selected columns) ---")
hh_cols <- names(read_dta(hh_path, n_max = 0))

# Target variables from HH file
hh_target <- c("hhid",
                "a4008",                               # expected price change
                paste0("a4001_", 1:7, "_mc"),           # info source dummies
                "a4003",                               # risk attitude
                "a4005",                               # expected economic outlook
                "a4007",                               # expected interest rate change
                "a4008a",                              # expected house price change
                "hh_income")                           # household income

hh_select <- intersect(hh_target, hh_cols)
missing_hh <- setdiff(hh_target, hh_cols)
if (length(missing_hh) > 0) message(sprintf("  HH vars not found: %s", paste(missing_hh, collapse = ", ")))

hh <- as.data.table(read_dta(hh_path, col_select = all_of(hh_select)))
message(sprintf("  HH file: %d households, %d selected columns", nrow(hh), ncol(hh)))

message("--- Reading master file ---")
master_cols <- names(read_dta(master_path, n_max = 0))
message(sprintf("  Master columns available: %s", paste(head(master_cols, 30), collapse = ", ")))

# Identify key master variables
# Master file has: hhid, province, rural, region, prov_CHN, swgt, county_lab, city_lab
# Income/consumption are in HH file, not master
prov_candidates  <- c("province", "provcd", "prov", "prov_CHN")
rural_candidates <- c("rural", "urban_rural")

pick <- function(candidates, cols) {
  hit <- intersect(candidates, cols)
  if (length(hit) == 0) return(NULL)
  hit[1]
}

master_select <- c("hhid")
var_map <- list()
for (info in list(
  list(name = "province",  cands = prov_candidates),
  list(name = "rural",     cands = rural_candidates)
)) {
  v <- pick(info$cands, master_cols)
  if (!is.null(v)) {
    master_select <- c(master_select, v)
    var_map[[info$name]] <- v
  } else {
    message(sprintf("  Warning: no match for %s among master columns", info$name))
  }
}
master_select <- unique(master_select)

master <- as.data.table(read_dta(master_path, col_select = all_of(master_select)))

# Rename master columns to canonical names
for (nm in names(var_map)) {
  old <- var_map[[nm]]
  if (old != nm && old %in% names(master)) setnames(master, old, nm)
}
message(sprintf("  Master file: %d households", nrow(master)))

# --- A2: Merge ---
message("--- Merging HH + Master on hhid ---")
dt <- merge(hh, master, by = "hhid", all.x = TRUE)
message(sprintf("  Merged dataset: %d observations", nrow(dt)))

# --- A3: Construct variables ---
message("--- Constructing analysis variables ---")

# Reverse-code a4008: higher = more inflation expected
# Original: 1=rise a lot, 2=rise a little, 3=no change, 4=reduce little, 5=reduce lot
# Reversed: 5=rise a lot, 4=rise a little, 3=no change, 2=reduce little, 1=reduce lot
dt[, a4008_num := as.numeric(a4008)]
dt[, infl_exp := 6L - a4008_num]  # reverse so higher = more inflationary
dt[a4008_num < 1 | a4008_num > 5, infl_exp := NA_integer_]

# Binary: high inflation expectation (original a4008 in {1, 2} = rise a lot/little)
dt[, high_infl_exp := fifelse(a4008_num %in% 1:2, 1L, 0L)]
dt[is.na(a4008_num) | a4008_num < 1 | a4008_num > 5, high_infl_exp := NA_integer_]

# Information source channels
info_cols <- paste0("a4001_", 1:7, "_mc")
info_present <- intersect(info_cols, names(dt))
for (v in info_present) dt[, (v) := fifelse(get(v) == 1, 1L, 0L, na = 0L)]

# Media salience: newspapers (1) + TV (2) + internet (4)
high_sal_cols <- intersect(c("a4001_1_mc", "a4001_2_mc", "a4001_4_mc"), info_present)
low_sal_cols  <- intersect(c("a4001_3_mc", "a4001_6_mc"), info_present)  # radio + family/friends

if (length(high_sal_cols) > 0) {
  dt[, media_salience := rowSums(.SD, na.rm = TRUE), .SDcols = high_sal_cols]
} else {
  dt[, media_salience := NA_real_]
}

if (length(low_sal_cols) > 0) {
  dt[, low_salience := rowSums(.SD, na.rm = TRUE), .SDcols = low_sal_cols]
} else {
  dt[, low_salience := NA_real_]
}

dt[, high_media := fifelse(media_salience > median(media_salience, na.rm = TRUE), 1L, 0L)]

# Risk attitude
if ("a4003" %in% names(dt)) {
  dt[, risk_attitude := as.numeric(a4003)]
  dt[risk_attitude < 1 | risk_attitude > 5, risk_attitude := NA_real_]
} else {
  dt[, risk_attitude := NA_real_]
}

# Expected economic outlook
if ("a4005" %in% names(dt)) {
  dt[, econ_outlook := as.numeric(a4005)]
} else {
  dt[, econ_outlook := NA_real_]
}

# Expected interest rate change
if ("a4007" %in% names(dt)) {
  dt[, interest_exp := as.numeric(a4007)]
} else {
  dt[, interest_exp := NA_real_]
}

# Expected house price change (reverse-code like a4008 if same scale)
if ("a4008a" %in% names(dt)) {
  dt[, a4008a_num := as.numeric(a4008a)]
  dt[, house_price_exp := 6L - a4008a_num]
  dt[a4008a_num < 1 | a4008a_num > 5, house_price_exp := NA_integer_]
} else {
  dt[, house_price_exp := NA_real_]
}

# Forecast error proxy
# Realized 2012 national CPI ~ 2.6% YoY = moderate/low inflation
# Original a4008: 1=rise a lot, 2=rise a little, 3=no change, 4=reduce little, 5=reduce lot
# Realized outcome most consistent with "rise a little" (category 2)
# Error = expected - realized (in ordinal terms)
# Using reversed scale: realized ~ 4 ("rise a little")
realized_ordinal <- 4L  # "rise a little" on reversed scale
dt[, forecast_error_proxy := infl_exp - realized_ordinal]

# Directional overreaction dummy: expected "rise a lot" (infl_exp == 5)
dt[, overreaction := fifelse(infl_exp == 5L, 1L, 0L)]
dt[is.na(infl_exp), overreaction := NA_integer_]

# Controls: income from HH file, rural from master
if ("hh_income" %in% names(dt)) {
  dt[, log_income := log(as.numeric(hh_income) + 1)]
  dt[is.infinite(log_income) | is.nan(log_income), log_income := NA_real_]
  dt[, income_tercile := frank(hh_income, ties.method = "dense", na.last = "keep")]
  dt[, income_tercile := ceiling(income_tercile / max(income_tercile, na.rm = TRUE) * 3)]
} else {
  dt[, log_income := NA_real_]
  dt[, income_tercile := NA_integer_]
}

# Derive urban from rural indicator
if ("rural" %in% names(dt)) {
  dt[, rural := as.integer(rural)]
  dt[, urban := fifelse(rural == 1L, 0L, 1L, na = NA_integer_)]
} else {
  dt[, urban := NA_integer_]
}

if ("province" %in% names(dt)) {
  dt[, province := as.factor(province)]
} else {
  dt[, province := NA_character_]
}

# --- A4: Sample summary ---
n_total   <- nrow(dt)
n_infl    <- sum(!is.na(dt$infl_exp))
n_info    <- sum(!is.na(dt$media_salience) & !is.na(dt$infl_exp))
n_risk    <- sum(!is.na(dt$risk_attitude) & !is.na(dt$infl_exp))
message(sprintf("  Total merged obs:        %d", n_total))
message(sprintf("  With inflation exp:      %d", n_infl))
message(sprintf("  With info + infl exp:    %d", n_info))
message(sprintf("  With risk + infl exp:    %d", n_risk))

# --- A5: Descriptive statistics table ---
message("\n--- Generating descriptive statistics ---")

desc_vars <- c("infl_exp", "high_infl_exp", "forecast_error_proxy",
               "media_salience", "low_salience", "high_media",
               "risk_attitude", "log_income")
desc_vars <- desc_vars[desc_vars %in% names(dt)]

desc_list <- lapply(desc_vars, function(v) {
  x <- dt[[v]]
  x <- x[!is.na(x)]
  data.table(
    Variable = v,
    N        = length(x),
    Mean     = mean(x),
    SD       = sd(x),
    Min      = min(x),
    Median   = median(x),
    Max      = max(x)
  )
})
desc_tab <- rbindlist(desc_list)

# Pretty labels
label_map <- c(
  infl_exp            = "Inflation expectation (1-5)",
  high_infl_exp       = "High inflation exp. (binary)",
  forecast_error_proxy = "Forecast error proxy",
  media_salience      = "High-salience channels (0-3)",
  low_salience        = "Low-salience channels (0-2)",
  high_media          = "Above-median media (binary)",
  risk_attitude       = "Risk attitude (1-5)",
  log_income          = "Log(income + 1)"
)
desc_tab[, Variable := fifelse(Variable %in% names(label_map),
                                label_map[Variable], Variable)]

write_booktabs_table(
  desc_tab,
  file.path(project_paths$tables, "chfs_2011_summary.tex"),
  caption = "CHFS 2011 Cross-Section: Descriptive Statistics",
  label   = "tab:chfs_2011_summary",
  notes   = c(
    "Data from the 2011 China Household Finance Survey.",
    "Inflation expectation reverse-coded so higher values = more inflationary.",
    "Forecast error proxy = expected (reversed ordinal) minus realized ordinal (2012 CPI ~ 2.6\\%)."
  ),
  digits = 3
)
message(sprintf("  Saved: %s", file.path(project_paths$tables, "chfs_2011_summary.tex")))

# --- A6: Regressions ---
message("\n--- Running cross-section regressions ---")

# Prepare regression sample
# NOTE: Cross-sectional test. Cannot construct a forecast error independent of
# the expectation level (single wave = single realized CPI for all HH).
# Instead, test whether media exposure predicts MORE EXTREME expectations,
# controlling for province and demographics. If media-exposed HH hold more
# inflationary beliefs when actual 2012 inflation was moderate (~2.6%),
# that IS overreaction. Rigidity predicts the opposite: media exposure
# should moderate expectations.
reg_dt <- dt[!is.na(infl_exp) & !is.na(log_income) & !is.na(province)]
message(sprintf("  Regression sample (baseline): %d obs", nrow(reg_dt)))

# Construct province-demeaned expectation and extremity measure
reg_dt[, prov_mean_exp := mean(infl_exp, na.rm = TRUE), by = province]
reg_dt[, exp_deviation := infl_exp - prov_mean_exp]
reg_dt[, exp_extremity := abs(exp_deviation)]
# Binary: over-predicting inflation (top category = "rise a lot", infl_exp==5)
reg_dt[, over_predict := fifelse(infl_exp == 5L, 1L, 0L)]

# (a) Media exposure -> expectation level (diagnostic: beta > 0)
message("  [a] Media exposure -> expectation level...")
m1 <- tryCatch(
  feols(infl_exp ~ high_media + log_income + urban | province,
        data = reg_dt[!is.na(high_media)], vcov = "hetero"),
  error = function(e) {
    message("    fixest failed, falling back to lm: ", e$message)
    lm(infl_exp ~ high_media + log_income + urban + province,
       data = reg_dt[!is.na(high_media)])
  }
)

# (b) Media exposure -> expectation extremity (diagnostic: beta > 0)
message("  [b] Media exposure -> expectation extremity...")
m2 <- tryCatch(
  feols(exp_extremity ~ high_media + log_income + urban | province,
        data = reg_dt[!is.na(high_media)], vcov = "hetero"),
  error = function(e) {
    message("    fixest failed, falling back to lm: ", e$message)
    lm(exp_extremity ~ high_media + log_income + urban + province,
       data = reg_dt[!is.na(high_media)])
  }
)

# (c) Media exposure -> over-prediction binary (diagnostic: beta > 0)
message("  [c] Media exposure -> over-prediction (LPM)...")
m3 <- tryCatch(
  feols(over_predict ~ high_media + log_income + urban | province,
        data = reg_dt[!is.na(high_media)], vcov = "hetero"),
  error = function(e) {
    message("    fixest failed, falling back to lm: ", e$message)
    lm(over_predict ~ high_media + log_income + urban + province,
       data = reg_dt[!is.na(high_media)])
  }
)

# (d) Risk attitude placebo -> expectation level (should be null or weak)
message("  [d] Risk attitude placebo...")
m4 <- tryCatch(
  feols(infl_exp ~ risk_attitude + log_income + urban | province,
        data = reg_dt[!is.na(risk_attitude)], vcov = "hetero"),
  error = function(e) {
    message("    fixest failed, falling back to lm: ", e$message)
    lm(infl_exp ~ risk_attitude + log_income + urban + province,
       data = reg_dt[!is.na(risk_attitude)])
  }
)

# (e) Horse race: media + risk attitude jointly
message("  [e] Horse race: media + risk...")
m5 <- tryCatch(
  feols(infl_exp ~ high_media + risk_attitude + log_income + urban | province,
        data = reg_dt[!is.na(high_media) & !is.na(risk_attitude)], vcov = "hetero"),
  error = function(e) {
    message("    fixest failed, falling back to lm: ", e$message)
    lm(infl_exp ~ high_media + risk_attitude + log_income + urban + province,
       data = reg_dt[!is.na(high_media) & !is.na(risk_attitude)])
  }
)

# --- A7: Build regression output table ---
message("--- Formatting mechanism discrimination table ---")

extract_feols <- function(mod, varnames) {
  ct <- coeftable(mod)
  out <- lapply(varnames, function(v) {
    if (v %in% rownames(ct)) {
      list(b = ct[v, "Estimate"], se = ct[v, "Std. Error"], p = ct[v, "Pr(>|t|)"])
    } else {
      list(b = NA_real_, se = NA_real_, p = NA_real_)
    }
  })
  names(out) <- varnames
  out
}

extract_lm_robust <- function(mod, varnames) {
  se_hc <- sqrt(diag(vcovHC(mod, type = "HC1")))
  ct <- coeftest(mod, vcov. = vcovHC(mod, type = "HC1"))
  out <- lapply(varnames, function(v) {
    if (v %in% rownames(ct)) {
      list(b = ct[v, "Estimate"], se = ct[v, "Std. Error"], p = ct[v, "Pr(>|t|)"])
    } else {
      list(b = NA_real_, se = NA_real_, p = NA_real_)
    }
  })
  names(out) <- varnames
  out
}

safe_extract <- function(mod, varnames) {
  if (inherits(mod, "fixest")) {
    extract_feols(mod, varnames)
  } else {
    extract_lm_robust(mod, varnames)
  }
}

safe_nobs <- function(mod) {
  if (inherits(mod, "fixest")) mod$nobs else nobs(mod)
}

# Key coefficients for the mechanism table
c1 <- safe_extract(m1, "high_media")
c2 <- safe_extract(m2, "high_media")
c3 <- safe_extract(m3, "high_media")
c4 <- safe_extract(m4, "risk_attitude")
c5 <- safe_extract(m5, c("high_media", "risk_attitude"))

# Build table rows
build_row <- function(var_label, cols_list) {
  coef_row <- c(Variable = var_label)
  se_row   <- c(Variable = "")
  for (i in seq_along(cols_list)) {
    cl <- cols_list[[i]]
    if (is.null(cl) || is.na(cl$b)) {
      coef_row <- c(coef_row, "")
      se_row   <- c(se_row, "")
    } else {
      coef_row <- c(coef_row, fmt_coef(cl$b, cl$p))
      se_row   <- c(se_row, fmt_se(cl$se))
    }
  }
  rbind(coef_row, se_row)
}

na_entry <- list(b = NA_real_, se = NA_real_, p = NA_real_)

tab_rows <- rbind(
  build_row("High media (TV/internet/newspaper)",
            list(c1[["high_media"]], c2[["high_media"]], c3[["high_media"]],
                 na_entry, c5[["high_media"]])),
  build_row("Risk attitude",
            list(na_entry, na_entry, na_entry,
                 c4[["risk_attitude"]], c5[["risk_attitude"]]))
)
tab_dt <- as.data.table(tab_rows)
setnames(tab_dt, c("Variable",
                    "(1) Exp. level", "(2) Extremity", "(3) Over-predict",
                    "(4) Risk placebo", "(5) Horse race"))

# Add DV and N rows
dv_row <- data.table(
  Variable = "Dep. variable",
  `(1) Exp. level`    = "Infl. exp.",
  `(2) Extremity`     = "|Dev. from prov.|",
  `(3) Over-predict`  = "Over-predict",
  `(4) Risk placebo`  = "Infl. exp.",
  `(5) Horse race`    = "Infl. exp."
)
n_row <- data.table(
  Variable = "Observations",
  `(1) Exp. level`    = as.character(safe_nobs(m1)),
  `(2) Extremity`     = as.character(safe_nobs(m2)),
  `(3) Over-predict`  = as.character(safe_nobs(m3)),
  `(4) Risk placebo`  = as.character(safe_nobs(m4)),
  `(5) Horse race`    = as.character(safe_nobs(m5))
)
tab_dt <- rbind(dv_row, tab_dt, n_row)

write_booktabs_table(
  tab_dt,
  file.path(project_paths$tables, "chfs_mechanism_info_channel.tex"),
  caption = "CHFS 2011: Information Channels and Inflation Expectations",
  label   = "tab:chfs_mechanism_info_channel",
  notes   = c(
    "Columns (1), (4), (5): DV is inflation expectation (1-5 scale, higher = more inflationary).",
    "Column (2): DV is absolute deviation from province mean expectation.",
    "Column (3): DV is binary indicator for top category (expect prices to rise a lot).",
    "All specifications include province FE and controls (log income, urban/rural).",
    "Diagnostic prediction: high-media coefficient is positive (media amplifies overreaction).",
    "Heteroskedasticity-robust standard errors in parentheses.",
    "* p < 0.10, ** p < 0.05, *** p < 0.01."
  ),
  digits = 3
)
message(sprintf("  Saved: %s", file.path(project_paths$tables, "chfs_mechanism_info_channel.tex")))

# Risk placebo standalone table
risk_tab <- tab_dt[, c("Variable", "(4) Risk placebo"), with = FALSE]
write_booktabs_table(
  risk_tab,
  file.path(project_paths$tables, "chfs_risk_placebo.tex"),
  caption = "CHFS 2011: Risk Attitude Placebo Test",
  label   = "tab:chfs_risk_placebo",
  notes   = c(
    "Dependent variable: inflation expectation (1-5, higher = more inflationary).",
    "Risk attitude should not predict expectations if diagnostic channel operates through salience.",
    "Province FE and income/urban controls included.",
    "* p < 0.10, ** p < 0.05, *** p < 0.01."
  ),
  digits = 3
)
message(sprintf("  Saved: %s", file.path(project_paths$tables, "chfs_risk_placebo.tex")))

# --- A8: Information channel gradient figure ---
message("--- Generating information channel gradient figure ---")

fig_dt <- dt[!is.na(infl_exp) & !is.na(media_salience)]
fig_dt[, channel_type := fifelse(media_salience >= 2, "High-salience media",
                          fifelse(media_salience == 1, "Mixed",
                                  "Low-salience only"))]
fig_dt[, channel_type := factor(channel_type,
                                 levels = c("Low-salience only", "Mixed", "High-salience media"))]

grad <- fig_dt[, .(mean_exp = mean(infl_exp, na.rm = TRUE),
                    se_exp   = sd(infl_exp, na.rm = TRUE) / sqrt(.N),
                    pct_overpredict = mean(infl_exp == 5, na.rm = TRUE),
                    n = .N),
               by = channel_type]

p_channel <- ggplot(grad, aes(x = channel_type, y = mean_exp, fill = channel_type)) +
  geom_col(width = 0.6, color = "grey30", linewidth = 0.3) +
  geom_errorbar(aes(ymin = mean_exp - 1.96 * se_exp,
                     ymax = mean_exp + 1.96 * se_exp),
                width = 0.15, linewidth = 0.4) +
  geom_hline(yintercept = 4, linetype = "dashed", color = "grey50", linewidth = 0.3) +
  annotate("text", x = 0.6, y = 4.05, label = 'Realized ~ "rise a little"',
           hjust = 0, size = 2.5, color = "grey40", family = "serif") +
  scale_fill_manual(values = c(okabe_ito[["sky_blue"]],
                                okabe_ito[["yellow"]],
                                okabe_ito[["vermillion"]])) +
  labs(
    title = "Mean Inflation Expectation by Information Channel Type",
    subtitle = "CHFS 2011 cross-section (higher = more inflationary)",
    x = "Dominant information channel",
    y = "Mean inflation expectation (1-5 scale)"
  ) +
  theme_pub() +
  theme(legend.position = "none")

save_plot_pair(p_channel, file.path(project_paths$figures, "chfs_info_channel_gradient"),
               width = 6.5, height = 4.5)
message(sprintf("  Saved: %s", file.path(project_paths$figures, "chfs_info_channel_gradient.pdf")))

# --- A9: Save cleaned cross-section ---
out_vars <- c("hhid", "infl_exp", "high_infl_exp", "forecast_error_proxy",
              "overreaction", "media_salience", "low_salience", "high_media",
              "risk_attitude", "econ_outlook", "interest_exp", "house_price_exp",
              "log_income", "income_tercile", "urban", "province")
out_vars <- intersect(out_vars, names(dt))
fwrite(dt[, ..out_vars], file.path(project_paths$processed, "chfs_2011_analysis.csv"))
message(sprintf("  Saved: %s", file.path(project_paths$processed, "chfs_2011_analysis.csv")))


# ============================================================
# PART B: CHFS Panel Forward-Tracking (Behavioral Consequences)
# ============================================================
message("\n========================================")
message("[14] CHFS Panel Forward-Tracking")
message("========================================\n")

# --- B1: Classify 2011 belief types ---
message("--- Classifying 2011 belief types ---")

# Residualize infl_exp on province FE and demographics
class_dt <- dt[!is.na(infl_exp) & !is.na(province) & !is.na(log_income)]
if (nrow(class_dt) > 50) {
  m_resid <- tryCatch(
    feols(infl_exp ~ log_income + urban | province, data = class_dt),
    error = function(e) lm(infl_exp ~ log_income + urban + province, data = class_dt)
  )
  class_dt[, infl_residual := residuals(m_resid)]
  class_dt[, overreactor := fifelse(infl_residual >= quantile(infl_residual, 0.75, na.rm = TRUE),
                                     1L, 0L)]
  message(sprintf("  Overreactors (top quartile of residual): %d / %d (%.1f%%)",
                  sum(class_dt$overreactor == 1),
                  nrow(class_dt),
                  100 * mean(class_dt$overreactor)))
} else {
  message("  Warning: insufficient obs for belief classification")
  class_dt[, overreactor := NA_integer_]
}

# Keep baseline variables for panel merge
baseline <- class_dt[, .(hhid, infl_exp, overreactor, log_income, urban, province,
                          media_salience, high_media)]

# --- B2: Link forward through master files ---
message("--- Linking forward through CHFS waves ---")

# Use HH files (not master) because master lacks income/consumption
# 2013+: total_income available; 2015+: total_consump also available
master_files <- list(
  list(year = 2013, dir = "CHFS2013", file = "chfs2013_hh_20191120_version14.dta"),
  list(year = 2015, dir = "CHFS2015", file = "chfs2015_hh_20191120_version14.dta"),
  list(year = 2017, dir = "CHFS2017", file = "chfs2017_hh_202206.dta"),
  list(year = 2019, dir = "CHFS2019", file = "chfs2019_hh_pub_v1_20260131.dta"),
  list(year = 2021, dir = "CHFS2021", file = "chfs2021_hh_pub_v0_20260131.dta")
)

read_master_wave <- function(info) {
  base <- file.path("data", "raw", "CHFS", info$dir)
  fpath <- tryCatch(find_dta(base, info$file), error = function(e) NULL)
  if (is.null(fpath)) {
    message(sprintf("  Wave %d HH not found, skipping", info$year))
    return(NULL)
  }

  cols <- names(read_dta(fpath, n_max = 0))
  message(sprintf("  Wave %d cols (first 20): %s", info$year, paste(head(cols, 20), collapse = ", ")))

  # Panel linkage: waves 2013+ use hhid_2011 for linking to 2011 baseline
  id_cands <- c("hhid_2011", "hhid")
  id_var <- pick(id_cands, cols)
  if (is.null(id_var)) {
    message(sprintf("  Wave %d: no linkage variable found", info$year))
    return(NULL)
  }

  # Find income and consumption variables
  cons_cands <- c("total_consump", "consump", "tconsump", "total_expenditure")
  inc_cands  <- c("total_income", "hh_income", "income", "tincome")

  sel <- id_var
  cvar <- pick(cons_cands, cols)
  ivar <- pick(inc_cands, cols)
  if (!is.null(cvar)) sel <- c(sel, cvar)
  if (!is.null(ivar)) sel <- c(sel, ivar)
  sel <- unique(sel)

  if (length(sel) <= 1) {
    message(sprintf("  Wave %d: no income/consumption vars found", info$year))
    return(NULL)
  }

  wave_dt <- as.data.table(read_dta(fpath, col_select = all_of(sel)))
  # Rename linkage variable to hhid for consistent merging
  if (id_var != "hhid") {
    if ("hhid" %in% names(wave_dt)) wave_dt[, hhid := NULL]  # drop if exists
    setnames(wave_dt, id_var, "hhid")
  }
  if (!is.null(cvar) && cvar != "total_consump") setnames(wave_dt, cvar, "total_consump")
  if (!is.null(ivar) && ivar != "total_income")  setnames(wave_dt, ivar, "total_income")

  wave_dt[, wave := info$year]
  message(sprintf("  Wave %d: %d obs, linked via %s", info$year, nrow(wave_dt), id_var))
  wave_dt
}

wave_masters <- lapply(master_files, read_master_wave)
wave_masters <- Filter(Negate(is.null), wave_masters)

if (length(wave_masters) > 0) {
  # Add 2011 baseline income from HH data (hh_income)
  base_hh <- dt[, .(hhid, total_income = as.numeric(hh_income))]
  base_hh[, wave := 2011L]
  all_waves <- rbindlist(c(list(base_hh), wave_masters), fill = TRUE, use.names = TRUE)

  # Merge with baseline belief types
  panel_dt <- merge(all_waves, baseline[, .(hhid, overreactor, log_income, urban, province)],
                    by = "hhid", all.x = FALSE)
  message(sprintf("  Panel observations matched: %d across %d waves",
                  nrow(panel_dt), uniqueN(panel_dt$wave)))

  # Construct log income (available across all waves)
  if ("total_income" %in% names(panel_dt)) {
    panel_dt[, log_income_panel := log(as.numeric(total_income) + 1)]
    panel_dt[is.infinite(log_income_panel) | is.nan(log_income_panel), log_income_panel := NA_real_]
  }
  # Also construct log consumption where available (2015+)
  if ("total_consump" %in% names(panel_dt)) {
    panel_dt[, log_consump := log(as.numeric(total_consump) + 1)]
    panel_dt[is.infinite(log_consump) | is.nan(log_consump), log_consump := NA_real_]
  }

  # --- B3: Consequence regressions (using income as primary tracking variable) ---
  message("--- Running consequence regressions ---")

  setorder(panel_dt, hhid, wave)

  # Compute delta log income relative to 2011
  if ("log_income_panel" %in% names(panel_dt)) {
    panel_dt[, log_income_2011 := log_income_panel[wave == 2011][1], by = hhid]
    panel_dt[, delta_log_income := log_income_panel - log_income_2011]

    # Regression for each forward wave
    forward_waves <- sort(setdiff(unique(panel_dt$wave), 2011))
    cons_results <- list()

    for (yr in forward_waves) {
      sub <- panel_dt[wave == yr & !is.na(delta_log_income) & !is.na(overreactor)]
      if (nrow(sub) < 30) {
        message(sprintf("    Wave %d: only %d obs, skipping", yr, nrow(sub)))
        next
      }

      mc <- tryCatch(
        feols(delta_log_income ~ overreactor + log_income + urban | province,
              data = sub, vcov = "hetero"),
        error = function(e) {
          lm(delta_log_income ~ overreactor + log_income + urban + province, data = sub)
        }
      )

      cc <- safe_extract(mc, "overreactor")
      cons_results[[as.character(yr)]] <- data.table(
        wave     = yr,
        horizon  = yr - 2011L,
        beta     = cc[["overreactor"]]$b,
        se       = cc[["overreactor"]]$se,
        p        = cc[["overreactor"]]$p,
        n        = safe_nobs(mc)
      )
      message(sprintf("    Wave %d (h=%d): beta=%.4f, se=%.4f, n=%d",
                      yr, yr - 2011, cc[["overreactor"]]$b, cc[["overreactor"]]$se, safe_nobs(mc)))
    }

    if (length(cons_results) > 0) {
      cons_tab <- rbindlist(cons_results)

      # Format table
      cons_out <- cons_tab[, .(
        Horizon  = paste0("2011-", wave),
        Coefficient = fmt_coef(beta, p),
        SE       = fmt_se(se),
        N        = as.character(n)
      )]

      write_booktabs_table(
        cons_out,
        file.path(project_paths$tables, "chfs_consumption_consequences.tex"),
        caption = "Behavioral Consequences of Diagnostic Overreaction: Forward Income",
        label   = "tab:chfs_consumption_consequences",
        notes   = c(
          "Dependent variable: change in log household income relative to 2011.",
          "Overreactor = top quartile of province-residualized inflation expectation in 2011.",
          "Controls: log income, urban indicator, province FE.",
          "Heteroskedasticity-robust standard errors.",
          "* p < 0.10, ** p < 0.05, *** p < 0.01."
        ),
        digits = 3
      )
      message(sprintf("  Saved: %s", file.path(project_paths$tables, "chfs_consumption_consequences.tex")))

      # --- B5: Belief persistence / cumulative consumption gap figure ---
      message("--- Generating belief persistence figure ---")

      p_persist <- ggplot(cons_tab, aes(x = horizon, y = beta)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "grey50", linewidth = 0.3) +
        geom_ribbon(aes(ymin = beta - 1.96 * se, ymax = beta + 1.96 * se),
                    fill = okabe_ito[["sky_blue"]], alpha = 0.25) +
        geom_line(color = okabe_ito[["blue"]], linewidth = 0.8) +
        geom_point(color = okabe_ito[["blue"]], size = 2.5) +
        scale_x_continuous(breaks = cons_tab$horizon,
                           labels = paste0("2011-", cons_tab$wave)) +
        labs(
          title = "Cumulative Income Gap: Diagnostic Overreactors vs. Others",
          subtitle = "CHFS panel, 2011 baseline belief type tracked forward",
          x = "Horizon (years since 2011)",
          y = expression(Delta ~ "log income (overreactor coefficient)")
        ) +
        theme_pub()

      save_plot_pair(p_persist, file.path(project_paths$figures, "chfs_belief_persistence"),
                     width = 7, height = 4.5)
      message(sprintf("  Saved: %s", file.path(project_paths$figures, "chfs_belief_persistence.pdf")))
    } else {
      message("  No forward waves with sufficient data for consumption regressions.")
    }
  } else {
    message("  Income variable not available in panel, skipping consequence analysis.")
  }

  # Save panel dataset
  fwrite(panel_dt, file.path(project_paths$processed, "chfs_panel_consequences.csv"))
  message(sprintf("  Saved: %s", file.path(project_paths$processed, "chfs_panel_consequences.csv")))

} else {
  message("  No forward master files found. Panel analysis skipped.")
}

# ============================================================
# Done
# ============================================================
message("\n========================================")
message("[14] CHFS analysis module complete.")
message("========================================")
