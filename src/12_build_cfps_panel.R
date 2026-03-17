#!/usr/bin/env Rscript
# ============================================================
# 12_build_cfps_panel.R
# Build household-level panel from CFPS waves for
# diagnostic-expectations heterogeneity analysis
# ============================================================

library(haven)      # read Stata .dta files
library(dplyr)
library(tidyr)
library(purrr)
library(readr)

# --- Paths ---
raw_dir  <- file.path("data", "raw", "CFPS")
out_dir  <- file.path("data", "processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- CFPS wave configuration ---
# Map wave years to file patterns and key variable names
# Variable names may differ across waves; adapt as needed
waves <- list(
  list(year = 2010, file = "CFPS2010/ecfps2010adult_201906.dta",
       id_var = "pid", price_exp = NULL,  # 2010 lacks price expectations
       age = "qa1age", edu_years = "cfps2010eduy_best",
       gender = "cfps2010_gender", hukou = "qa1"),
  list(year = 2012, file = "CFPS2012/ecfps2012adult_202505.dta",
       id_var = "pid", price_exp = "qp201",
       age = "cfps2012_age", edu_years = "cfps2011_latest_edu",
       gender = "cfps_gender", hukou = "qa301"),
  list(year = 2014, file = "CFPS2014/ecfps2014adult_201906.dta",
       id_var = "pid", price_exp = "qp201",
       age = "cfps2014_age", edu_years = "cfps2014eduy",
       gender = "cfps_gender", hukou = "qa301"),
  list(year = 2016, file = "CFPS2016/ecfps2016adult_201906.dta",
       id_var = "pid", price_exp = "qp201",
       age = "cfps_age", edu_years = "cfps2016eduy",
       gender = "cfps_gender", hukou = "qa301"),
  list(year = 2018, file = "CFPS2018/ecfps2018person_202012.dta",
       id_var = "pid", price_exp = "qp201",
       age = "iage", edu_years = "cfps2018eduy",
       gender = "cfps_gender", hukou = "qa301"),
  list(year = 2020, file = "CFPS2020/ecfps2020person_202306.dta",
       id_var = "pid", price_exp = "qp201",
       age = "iage", edu_years = "cfps2020eduy",
       gender = "cfps_gender", hukou = "qa301"),
  list(year = 2022, file = "CFPS2022/ecfps2022person_202410.dta",
       id_var = "pid", price_exp = "qp201",
       age = "iage", edu_years = "cfps2022eduy",
       gender = "cfps_gender", hukou = "qa301")
)

# --- Helper: extract variables from a single wave ---
extract_wave <- function(wave_info) {
  fpath <- file.path(raw_dir, wave_info$file)
  if (!file.exists(fpath)) {
    message(sprintf("File not found: %s -- skipping wave %d",
                    fpath, wave_info$year))
    return(NULL)
  }

  message(sprintf("Reading CFPS %d from: %s", wave_info$year, fpath))

  # Read only needed columns to manage memory
  # First, read column names to check availability
  col_names <- names(haven::read_dta(fpath, n_max = 0))

  # Build selection vector based on available columns
  vars_to_select <- c()
  var_mapping <- list()

  # Person ID
  if (wave_info$id_var %in% col_names) {
    vars_to_select <- c(vars_to_select, wave_info$id_var)
    var_mapping[["pid"]] <- wave_info$id_var
  }

  # Price expectations
  if (!is.null(wave_info$price_exp) &&
      wave_info$price_exp %in% col_names) {
    vars_to_select <- c(vars_to_select, wave_info$price_exp)
    var_mapping[["price_exp_raw"]] <- wave_info$price_exp
  }

  # Province
  prov_candidates <- c("provcd", "provcd16", "provcd14",
                       "provcd12", "provcd10", "urban",
                       "cfps2010_province_survey")
  prov_var <- intersect(prov_candidates, col_names)[1]
  if (!is.na(prov_var)) {
    vars_to_select <- c(vars_to_select, prov_var)
    var_mapping[["province"]] <- prov_var
  }

  # Demographics
  for (nm in c("age", "edu_years", "gender", "hukou")) {
    vname <- wave_info[[nm]]
    if (!is.null(vname) && vname %in% col_names) {
      vars_to_select <- c(vars_to_select, vname)
      var_mapping[[nm]] <- vname
    }
  }

  # Income candidates
  inc_candidates <- c("p_income", "emp_income", "fincome1",
                      "fincome", "income", "total_income")
  inc_var <- intersect(inc_candidates, col_names)[1]
  if (!is.na(inc_var)) {
    vars_to_select <- c(vars_to_select, inc_var)
    var_mapping[["income"]] <- inc_var
  }

  vars_to_select <- unique(vars_to_select)

  # Read data
  df <- haven::read_dta(fpath, col_select = all_of(vars_to_select))

  # Rename columns
  for (new_name in names(var_mapping)) {
    old_name <- var_mapping[[new_name]]
    if (old_name %in% names(df)) {
      names(df)[names(df) == old_name] <- new_name
    }
  }

  df$wave <- wave_info$year

  # Code price expectations: 1 = rise, 0 = same, -1 = fall, NA = dk
  if ("price_exp_raw" %in% names(df)) {
    df <- df %>%
      mutate(
        price_exp = case_when(
          price_exp_raw == 1 ~ 1L,   # rise
          price_exp_raw == 2 ~ 0L,   # same
          price_exp_raw == 3 ~ -1L,  # fall
          TRUE ~ NA_integer_          # don't know / missing
        )
      ) %>%
      select(-price_exp_raw)
  }

  # Clean demographics
  if ("age" %in% names(df)) {
    df <- df %>%
      mutate(age = as.numeric(age)) %>%
      filter(age >= 18 & age <= 70 | is.na(age))
  }

  if ("edu_years" %in% names(df)) {
    df$edu_years <- as.numeric(df$edu_years)
  }

  if ("income" %in% names(df)) {
    df$income <- as.numeric(df$income)
  }

  df
}

# --- Extract all waves ---
message("=== Building CFPS panel ===")
wave_list <- map(waves, extract_wave)
wave_list <- compact(wave_list)  # drop NULLs

# --- Bind and create panel ---
panel <- bind_rows(wave_list)
message(sprintf("Raw panel: %d observations across %d waves",
                nrow(panel), n_distinct(panel$wave)))

# --- Construct revisions ---
# Sort by person and wave, compute change in expectations
panel <- panel %>%
  arrange(pid, wave) %>%
  group_by(pid) %>%
  mutate(
    price_exp_lag = lag(price_exp, order_by = wave),
    revision = price_exp - price_exp_lag,
    wave_lag = lag(wave, order_by = wave)
  ) %>%
  ungroup()

# --- Construct household-level forecast error proxy ---
# Load provincial CPI data (annual YoY) for matching
# This requires NBS provincial CPI which may need separate download
# For now, use national CPI as proxy
quarterly_panel <- read_csv(
  file.path(out_dir, "panel_quarterly.csv"),
  show_col_types = FALSE
)

# Map CFPS wave years to approximate CPI
cpi_annual <- quarterly_panel %>%
  mutate(year = as.integer(substr(quarter, 1, 4))) %>%
  group_by(year) %>%
  summarise(cpi_yoy = mean(CPI_YoY_rate, na.rm = TRUE),
            .groups = "drop")

panel <- panel %>%
  left_join(cpi_annual, by = c("wave" = "year"))

# Forecast error proxy: did inflation go in the expected direction?
# For rise expectations (price_exp == 1): error is negative if CPI was low
# This is a simplified proxy; full analysis uses provincial CPI
panel <- panel %>%
  mutate(
    fe_proxy = case_when(
      price_exp == 1 & cpi_yoy < 2 ~ -1,  # expected rise, got low infl
      price_exp == 1 & cpi_yoy >= 2 ~ 0,   # expected rise, got rise
      price_exp == 0 & abs(cpi_yoy) < 1 ~ 0,  # expected same, approx same
      price_exp == 0 & cpi_yoy >= 1 ~ 1,   # expected same, got rise
      price_exp == -1 & cpi_yoy > 0 ~ 1,   # expected fall, got rise
      price_exp == -1 & cpi_yoy <= 0 ~ 0,  # expected fall, got fall
      TRUE ~ NA_real_
    )
  )

# --- Demographic variables for heterogeneity ---
# Guard: create columns if missing
if (!"edu_years" %in% names(panel)) {
  message("Warning: edu_years not found in panel, setting to NA")
  panel$edu_years <- NA_real_
}
if (!"hukou" %in% names(panel)) {
  message("Warning: hukou not found in panel, setting to NA")
  panel$hukou <- NA_real_
}
if (!"income" %in% names(panel)) {
  message("Warning: income not found in panel, setting to NA")
  panel$income <- NA_real_
}

panel <- panel %>%
  mutate(
    edu_high = ifelse(!is.na(edu_years) & edu_years >= 12, 1L, 0L),
    urban = case_when(
      hukou == 1 ~ 1L,  # urban hukou
      hukou == 3 ~ 0L,  # rural hukou
      TRUE ~ NA_integer_
    )
  )

# Income terciles within wave
panel <- panel %>%
  group_by(wave) %>%
  mutate(
    income_tercile = if (all(is.na(income))) NA_integer_
                     else ntile(income, 3),
    income_below_median = if (all(is.na(income))) NA_integer_
                          else ifelse(income < median(income, na.rm = TRUE),
                                      1L, 0L)
  ) %>%
  ungroup()

# --- Attention index (composite) ---
# Combine education, income rank, and urban status
# Only compute if at least edu_years is available
if (any(!is.na(panel$edu_years))) {
  panel <- panel %>%
    mutate(
      attention_index = scale(edu_years)[,1] * 0.4 +
        scale(as.numeric(income_tercile))[,1] * 0.4 +
        ifelse(is.na(urban), 0, urban * 0.2),
      attention_tercile = ntile(attention_index, 3)
    )
} else {
  message("Warning: edu_years all NA, skipping attention index")
  panel$attention_index <- NA_real_
  panel$attention_tercile <- NA_integer_
}

# --- Sample restrictions ---
# Keep adults with price expectations in at least one wave
panel_clean <- panel %>%
  filter(!is.na(price_exp)) %>%
  filter(!is.na(pid))

message(sprintf("Clean panel: %d observations, %d unique households",
                nrow(panel_clean), n_distinct(panel_clean$pid)))

# Panel for revision analysis: need consecutive waves
revision_panel <- panel_clean %>%
  filter(!is.na(revision))

message(sprintf("Revision panel: %d obs with consecutive-wave revisions",
                nrow(revision_panel)))

# --- Save ---
write_csv(panel_clean,
          file.path(out_dir, "cfps_panel.csv"))
write_csv(revision_panel,
          file.path(out_dir, "cfps_revision_panel.csv"))

message("=== CFPS panel construction complete ===")
message(sprintf("Output: %s/cfps_panel.csv", out_dir))
message(sprintf("Output: %s/cfps_revision_panel.csv", out_dir))

# --- Summary statistics ---
cat("\n=== CFPS Panel Summary ===\n")
cat(sprintf("Waves: %s\n", paste(sort(unique(panel_clean$wave)),
                                  collapse = ", ")))
cat(sprintf("Total observations: %d\n", nrow(panel_clean)))
cat(sprintf("Unique households: %d\n", n_distinct(panel_clean$pid)))
cat(sprintf("Price exp distribution:\n"))
print(table(panel_clean$price_exp, panel_clean$wave, useNA = "ifany"))
cat(sprintf("\nRevision panel size: %d\n", nrow(revision_panel)))
cat(sprintf("Mean education years: %.1f\n",
            mean(panel_clean$edu_years, na.rm = TRUE)))
cat(sprintf("Fraction urban hukou: %.2f\n",
            mean(panel_clean$urban, na.rm = TRUE)))
