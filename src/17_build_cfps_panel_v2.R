#!/usr/bin/env Rscript
# ============================================================
# 17_build_cfps_panel_v2.R
# Rebuild CFPS household panel matched to province-level CPI.
#
# Fixes the mechanical correlation problem in the original
# 12_build_cfps_panel.R: the old fe_proxy shared the household's
# current expectation on both sides. This version merges
# province-level realized CPI for a clean forecast error.
# ============================================================

library(haven)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)

if (file.exists("src/00_project_utils.R")) {
  source("src/00_project_utils.R")
}

# --- Paths ---
raw_dir  <- file.path("data", "raw", "CFPS")
out_dir  <- file.path("data", "processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- Check required upstream files ---
required_files <- c(
  file.path(out_dir, "province_cpi_monthly.csv"),
  file.path(out_dir, "province_meat_shock.csv"),
  file.path(out_dir, "province_pig_intensity.csv")
)
missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop("Required upstream files not found:\n  ",
       paste(missing, collapse = "\n  "),
       "\nRun upstream tasks first.")
}

# --- Province name lookup ---
# Standard 2-digit province codes used by NBS / CFPS
province_lookup <- tibble::tribble(
  ~provcd_num, ~province_name,
  11L, "Beijing",
  12L, "Tianjin",
  13L, "Hebei",
  14L, "Shanxi",
  15L, "Inner Mongolia",
  21L, "Liaoning",
  22L, "Jilin",
  23L, "Heilongjiang",
  31L, "Shanghai",
  32L, "Jiangsu",
  33L, "Zhejiang",
  34L, "Anhui",
  35L, "Fujian",
  36L, "Jiangxi",
  37L, "Shandong",
  41L, "Henan",
  42L, "Hubei",
  43L, "Hunan",
  44L, "Guangdong",
  45L, "Guangxi",
  46L, "Hainan",
  50L, "Chongqing",
  51L, "Sichuan",
  52L, "Guizhou",
  53L, "Yunnan",
  54L, "Tibet",
  61L, "Shaanxi",
  62L, "Gansu",
  63L, "Qinghai",
  64L, "Ningxia",
  65L, "Xinjiang"
)

# ============================================================
# CFPS wave configuration (reused from 12_build_cfps_panel.R)
# Wave 2010 excluded: no price expectations variable
# ============================================================
waves <- list(
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

# ============================================================
# Helper: extract variables from a single wave
# (adapted from 12_build_cfps_panel.R lines 54-158)
# ============================================================
extract_wave <- function(wave_info) {
  fpath <- file.path(raw_dir, wave_info$file)
  if (!file.exists(fpath)) {
    message(sprintf("File not found: %s -- skipping wave %d",
                    fpath, wave_info$year))
    return(NULL)
  }

  message(sprintf("Reading CFPS %d from: %s", wave_info$year, fpath))

  col_names <- names(haven::read_dta(fpath, n_max = 0))

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

  # Province code
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

  df <- haven::read_dta(fpath, col_select = all_of(vars_to_select))

  # Rename columns to standard names
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
          TRUE ~ NA_integer_
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

# ============================================================
# Extract all waves and build raw panel
# ============================================================
message("=== Building CFPS panel v2 (province-level CPI) ===")
wave_list <- map(waves, extract_wave)
wave_list <- compact(wave_list)

panel <- bind_rows(wave_list)
message(sprintf("Raw panel: %d observations across %d waves",
                nrow(panel), n_distinct(panel$wave)))

# ============================================================
# Standardise province code to 2-digit character
# ============================================================
# CFPS provcd is typically an integer (11, 12, ... 65)
# Some waves may store 6-digit codes; extract first 2 digits
panel <- panel %>%
  mutate(
    provcd_num = as.integer(province),
    provcd_num = if_else(provcd_num > 99,
                         as.integer(provcd_num %/% 10000),
                         provcd_num),
    provcd = sprintf("%02d", provcd_num)
  ) %>%
  select(-province)

# Attach province names
panel <- panel %>%
  left_join(province_lookup, by = "provcd_num")

# ============================================================
# Demographic variables
# ============================================================
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
    edu_high = if_else(!is.na(edu_years) & edu_years >= 12, 1L, 0L),
    urban = case_when(
      hukou == 1 ~ 1L,
      hukou == 3 ~ 0L,
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
                          else if_else(
                            income < median(income, na.rm = TRUE), 1L, 0L
                          )
  ) %>%
  ungroup()

# ============================================================
# Keep only observations with non-missing price expectations
# ============================================================
panel <- panel %>%
  filter(!is.na(price_exp), !is.na(pid))

message(sprintf("After filtering to non-missing expectations: %d obs, %d unique persons",
                nrow(panel), n_distinct(panel$pid)))

# ============================================================
# Revision (for appendix use only)
# ============================================================
panel <- panel %>%
  arrange(pid, wave) %>%
  group_by(pid) %>%
  mutate(
    price_exp_lag = lag(price_exp, order_by = wave),
    revision = price_exp - price_exp_lag
  ) %>%
  ungroup() %>%
  select(-price_exp_lag)

# ============================================================
# Load province-level CPI monthly data
# Compute province-year average headline CPI YoY
# ============================================================
message("Loading province-level CPI data...")
cpi_monthly <- read_csv(
  file.path(out_dir, "province_cpi_monthly.csv"),
  show_col_types = FALSE
)

# Ensure provcd is character with leading zero
if ("provcd" %in% names(cpi_monthly)) {
  cpi_monthly <- cpi_monthly %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
} else if ("province_code" %in% names(cpi_monthly)) {
  cpi_monthly <- cpi_monthly %>%
    rename(provcd = province_code) %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
}

# Extract year from date/month column
if ("date" %in% names(cpi_monthly)) {
  cpi_monthly <- cpi_monthly %>%
    mutate(year = as.integer(substr(as.character(date), 1, 4)))
} else if ("year" %in% names(cpi_monthly)) {
  cpi_monthly$year <- as.integer(cpi_monthly$year)
} else if ("month" %in% names(cpi_monthly)) {
  cpi_monthly <- cpi_monthly %>%
    mutate(year = as.integer(substr(as.character(month), 1, 4)))
}

# Identify the CPI YoY column
cpi_yoy_col <- intersect(
  c("cpi_yoy", "CPI_YoY", "headline_cpi_yoy", "cpi_yoy_headline"),
  names(cpi_monthly)
)[1]
if (is.na(cpi_yoy_col)) {
  cpi_yoy_col <- grep("cpi.*yoy|yoy.*cpi", names(cpi_monthly),
                       ignore.case = TRUE, value = TRUE)[1]
}
if (is.na(cpi_yoy_col)) {
  stop("Cannot find CPI YoY column in province_cpi_monthly.csv. ",
       "Columns available: ", paste(names(cpi_monthly), collapse = ", "))
}

message(sprintf("Using CPI YoY column: %s", cpi_yoy_col))

# Province-year average CPI YoY
cpi_prov_year <- cpi_monthly %>%
  group_by(provcd, year) %>%
  summarise(
    cpi_yoy_prov = mean(.data[[cpi_yoy_col]], na.rm = TRUE),
    .groups = "drop"
  )

# Merge province-year CPI YoY onto panel
panel <- panel %>%
  left_join(cpi_prov_year, by = c("provcd" = "provcd", "wave" = "year"))

message(sprintf("CPI YoY merge: %d of %d obs matched",
                sum(!is.na(panel$cpi_yoy_prov)), nrow(panel)))

# ============================================================
# Load meat/grain/egg shocks and headline CPI next
# ============================================================
message("Loading province meat shock data...")
meat_shock <- read_csv(
  file.path(out_dir, "province_meat_shock.csv"),
  show_col_types = FALSE
)

# Standardise provcd
if ("provcd" %in% names(meat_shock)) {
  meat_shock <- meat_shock %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
} else if ("province_code" %in% names(meat_shock)) {
  meat_shock <- meat_shock %>%
    rename(provcd = province_code) %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
}

# Identify year/wave column
if (!"wave" %in% names(meat_shock) && "year" %in% names(meat_shock)) {
  meat_shock <- meat_shock %>% rename(wave = year)
}

# Select relevant columns for merge
shock_cols <- intersect(
  c("provcd", "wave", "meat_shock", "grain_shock", "egg_shock",
    "headline_cpi_next"),
  names(meat_shock)
)
meat_shock_slim <- meat_shock %>% select(all_of(shock_cols))

panel <- panel %>%
  left_join(meat_shock_slim, by = c("provcd", "wave"))

message(sprintf("Meat shock merge: %d of %d obs have meat_shock",
                sum(!is.na(panel$meat_shock)), nrow(panel)))

# ============================================================
# Load pig intensity
# ============================================================
message("Loading pig intensity data...")
pig_intensity <- read_csv(
  file.path(out_dir, "province_pig_intensity.csv"),
  show_col_types = FALSE
)

# Standardise provcd
if ("provcd" %in% names(pig_intensity)) {
  pig_intensity <- pig_intensity %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
} else if ("province_code" %in% names(pig_intensity)) {
  pig_intensity <- pig_intensity %>%
    rename(provcd = province_code) %>%
    mutate(provcd = sprintf("%02d", as.integer(provcd)))
}

# Identify year/wave column
if (!"wave" %in% names(pig_intensity) && "year" %in% names(pig_intensity)) {
  pig_intensity <- pig_intensity %>% rename(wave = year)
}

# Identify pig_intensity column
pig_col <- intersect(
  c("pig_intensity_z", "pig_intensity", "pig_z"),
  names(pig_intensity)
)[1]
if (is.na(pig_col)) {
  pig_col <- grep("pig", names(pig_intensity),
                   ignore.case = TRUE, value = TRUE)[1]
}
if (is.na(pig_col)) {
  stop("Cannot find pig intensity column in province_pig_intensity.csv. ",
       "Columns: ", paste(names(pig_intensity), collapse = ", "))
}

pig_slim <- pig_intensity %>%
  select(provcd, wave, pig_intensity_z = all_of(pig_col))

panel <- panel %>%
  left_join(pig_slim, by = c("provcd", "wave"))

message(sprintf("Pig intensity merge: %d of %d obs matched",
                sum(!is.na(panel$pig_intensity_z)), nrow(panel)))

# ============================================================
# Construct clean forecast error
# ============================================================
# Quantify ordinal expectation using province-year CPI YoY anchor:
#   price_exp =  1 (rise): expect cpi_yoy_prov + 2 pp
#   price_exp =  0 (same): expect cpi_yoy_prov (continuation)
#   price_exp = -1 (fall): expect cpi_yoy_prov - 2 pp

panel <- panel %>%
  mutate(
    exp_quantified = case_when(
      price_exp ==  1 ~ cpi_yoy_prov + 2,
      price_exp ==  0 ~ cpi_yoy_prov,
      price_exp == -1 ~ cpi_yoy_prov - 2,
      TRUE ~ NA_real_
    )
  )

# Clean forecast error: realized headline CPI (next wave window)
# minus quantified expectation
# headline_cpi_next comes from province_meat_shock.csv
if ("headline_cpi_next" %in% names(panel)) {
  panel <- panel %>%
    mutate(fe_clean = headline_cpi_next - exp_quantified)
} else {
  message("WARNING: headline_cpi_next not found in merged data. ",
          "fe_clean will be NA. Check province_meat_shock.csv columns.")
  panel$fe_clean <- NA_real_
}

# ============================================================
# Select and order final columns
# ============================================================
final_cols <- c(
  "pid", "wave", "provcd", "province_name",
  "price_exp",
  "age", "edu_years", "edu_high", "gender", "hukou", "urban",
  "income", "income_tercile", "income_below_median",
  "meat_shock", "grain_shock", "egg_shock", "headline_cpi_next",
  "pig_intensity_z",
  "cpi_yoy_prov",
  "exp_quantified",
  "fe_clean",
  "revision"
)

# Keep only columns that exist; fill missing ones with NA
available_cols <- intersect(final_cols, names(panel))
missing_cols <- setdiff(final_cols, names(panel))
if (length(missing_cols) > 0) {
  message("Note: the following output columns are absent and will be NA: ",
          paste(missing_cols, collapse = ", "))
  for (mc in missing_cols) {
    panel[[mc]] <- NA_real_
  }
}

out <- panel %>% select(all_of(final_cols))

# ============================================================
# Save
# ============================================================
out_path <- file.path(out_dir, "cfps_salience_panel.csv")
write_csv(out, out_path)
message(sprintf("\nOutput written to: %s", out_path))

# ============================================================
# Summary statistics
# ============================================================
cat("\n=== CFPS Salience Panel Summary ===\n")
cat(sprintf("Total observations: %d\n", nrow(out)))
cat(sprintf("Unique persons: %d\n", n_distinct(out$pid)))
cat(sprintf("Provinces: %d\n", n_distinct(out$provcd)))

cat("\nN by wave:\n")
wave_tab <- out %>% count(wave)
print(as.data.frame(wave_tab))

cat(sprintf("\nMeat shock -- mean: %.4f, sd: %.4f, non-missing: %d\n",
            mean(out$meat_shock, na.rm = TRUE),
            sd(out$meat_shock, na.rm = TRUE),
            sum(!is.na(out$meat_shock))))

cat(sprintf("Clean FE   -- mean: %.4f, sd: %.4f, non-missing: %d\n",
            mean(out$fe_clean, na.rm = TRUE),
            sd(out$fe_clean, na.rm = TRUE),
            sum(!is.na(out$fe_clean))))

cat(sprintf("\nPrice expectation distribution:\n"))
print(table(out$price_exp, out$wave, useNA = "ifany"))

cat(sprintf("\nRevision available: %d obs\n",
            sum(!is.na(out$revision))))

cat("\n=== CFPS panel v2 construction complete ===\n")
