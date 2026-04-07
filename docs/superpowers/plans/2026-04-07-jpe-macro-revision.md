# JPE-Macro Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the JMP paper around province-level meat-price shock identification, replacing the contaminated revision-error design, producing all new data pipelines, estimation scripts, tables, figures, and LaTeX sections to JPE-Macro standards.

**Architecture:** Phase 1 builds four data pipelines (province CPI, meat shock, pig intensity, CFPS v2) that feed into Phase 2 estimation scripts (salience models, heterogeneity, spillovers, Bartik IV). Phase 3 generates publication-quality tables and figures. Phase 4 rewrites all LaTeX sections. Each phase can parallelize internally but depends on the prior phase.

**Tech Stack:** R (tidyverse, fixest, haven, readxl, sandwich, ggplot2, sf), LaTeX (XeLaTeX, booktabs, biblatex), Git

---

## Phase 1: Data Pipeline

### Task 1: Parse Province-Level CPI Data

**Files:**
- Create: `src/15_build_province_cpi.R`
- Output: `data/processed/province_cpi_monthly.csv`

- [ ] **Step 1: Create the parsing script**

```r
#!/usr/bin/env Rscript
# 15_build_province_cpi.R
# Parse province-level CPI from NBS Excel/CSV files
# Output: province_cpi_monthly.csv with columns:
#   province, year, month, cpi_mom (preceding month=100 raw value)

library(readxl)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)

raw_dir <- file.path("data", "raw")
out_dir <- file.path("data", "processed")

# --- Province name standardization ---
standardize_province <- function(x) {
  x <- str_trim(x)
  # Map English names to codes used in CFPS
  lookup <- c(
    "Beijing" = "11", "Tianjin" = "12", "Hebei" = "13",
    "Shanxi" = "14", "Inner Mongolia" = "15",
    "Liaoning" = "21", "Jilin" = "22", "Heilongjiang" = "23",
    "Shanghai" = "31", "Jiangsu" = "32", "Zhejiang" = "33",
    "Anhui" = "34", "Fujian" = "35", "Jiangxi" = "36",
    "Shandong" = "37", "Henan" = "41", "Hubei" = "42",
    "Hunan" = "43", "Guangdong" = "44", "Guangxi" = "45",
    "Hainan" = "46", "Chongqing" = "50", "Sichuan" = "51",
    "Guizhou" = "52", "Yunnan" = "53", "Tibet" = "54",
    "Shaanxi" = "61", "Gansu" = "62", "Qinghai" = "63",
    "Ningxia" = "64", "Xinjiang" = "65"
  )
  code <- lookup[x]
  ifelse(is.na(code), NA_character_, code)
}

# --- Parse wide NBS CSV (meat/grain/egg format) ---
parse_nbs_wide_csv <- function(filepath, value_name = "cpi_mom") {
  lines <- readLines(filepath, encoding = "UTF-8")
  # Row 3 has column headers: Region, then month labels
  header_line <- lines[3]
  # Split by tab+comma pattern
  headers <- str_split(header_line, "\t,?")[[1]]
  headers <- str_trim(headers)
  # Remove trailing empty
  headers <- headers[headers != ""]

  # Parse month labels: "Dec 2025", "Nov 2025", ...
  month_labels <- headers[-1]  # drop "Region"

  # Read data rows (4 onward, skip footer)
  data_lines <- lines[4:length(lines)]
  data_lines <- data_lines[!grepl("^Data Sources", data_lines)]
  data_lines <- data_lines[nchar(str_trim(data_lines)) > 0]

  result <- list()
  for (line in data_lines) {
    parts <- str_split(line, "\t,?")[[1]]
    parts <- str_trim(parts)
    province <- parts[1]
    values <- parts[-1]
    # Remove trailing empty strings
    values <- values[1:min(length(values), length(month_labels))]
    values <- suppressWarnings(as.numeric(values))

    for (j in seq_along(values)) {
      if (!is.na(values[j]) && j <= length(month_labels)) {
        # Parse "Dec 2025" -> year=2025, month=12
        ml <- month_labels[j]
        mon_str <- substr(ml, 1, 3)
        yr_str <- substr(ml, 5, 8)
        mon <- match(mon_str, month.abb)
        yr <- as.integer(yr_str)
        if (!is.na(mon) && !is.na(yr)) {
          result[[length(result) + 1]] <- data.frame(
            province_name = province,
            year = yr,
            month = mon,
            value = values[j],
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  df <- bind_rows(result)
  names(df)[names(df) == "value"] <- value_name
  df$provcd <- standardize_province(df$province_name)
  df <- df %>% filter(!is.na(provcd))
  df
}

# --- Parse headline CPI from Excel files ---
parse_headline_cpi_excel <- function(filepath) {
  # Read the Excel file
  df <- read_excel(filepath, skip = 2)
  # First column is Region, rest are months
  region_col <- names(df)[1]
  month_cols <- names(df)[-1]

  df_long <- df %>%
    pivot_longer(cols = -1, names_to = "month_label",
                 values_to = "cpi_headline_mom") %>%
    rename(province_name = 1)

  # Parse month labels
  df_long <- df_long %>%
    mutate(
      mon_str = str_extract(month_label, "^[A-Za-z]+"),
      yr_str = str_extract(month_label, "\\d{4}"),
      month = match(substr(mon_str, 1, 3), month.abb),
      year = as.integer(yr_str),
      province_name = str_trim(province_name),
      provcd = standardize_province(province_name),
      cpi_headline_mom = as.numeric(cpi_headline_mom)
    ) %>%
    filter(!is.na(provcd), !is.na(cpi_headline_mom),
           !is.na(month), !is.na(year)) %>%
    select(province_name, provcd, year, month,
           cpi_headline_mom)

  df_long
}

# --- Main ---
message("=== Building province CPI panel ===")

# 1. Parse headline CPI Excel files
headline_files <- list.files(raw_dir,
  pattern = "CPI_Monthly By Province.*\\.xlsx$",
  full.names = TRUE)

headline_list <- lapply(headline_files, parse_headline_cpi_excel)
headline <- bind_rows(headline_list) %>%
  distinct(provcd, year, month, .keep_all = TRUE) %>%
  arrange(provcd, year, month)

message(sprintf("Headline CPI: %d obs, %d provinces, %d-%d",
                nrow(headline), n_distinct(headline$provcd),
                min(headline$year), max(headline$year)))

# 2. Parse food sub-component CPI CSVs
meat <- parse_nbs_wide_csv(
  file.path(raw_dir, "nbc_food_CPI_province",
            "nbc_meat_CPI by Province.csv"),
  "cpi_meat_mom")

grain <- parse_nbs_wide_csv(
  file.path(raw_dir, "nbc_food_CPI_province",
            "nbc_grain_CPI by Province.csv"),
  "cpi_grain_mom")

eggs <- parse_nbs_wide_csv(
  file.path(raw_dir, "nbc_food_CPI_province",
            "nbc_eggs_CPI by Province.csv"),
  "cpi_eggs_mom")

message(sprintf("Meat CPI: %d obs, years %d-%d",
                nrow(meat), min(meat$year), max(meat$year)))
message(sprintf("Grain CPI: %d obs, years %d-%d",
                nrow(grain), min(grain$year), max(grain$year)))
message(sprintf("Eggs CPI: %d obs, years %d-%d",
                nrow(eggs), min(eggs$year), max(eggs$year)))

# 3. Merge all into single panel
panel <- headline %>%
  select(provcd, province_name, year, month, cpi_headline_mom) %>%
  left_join(
    meat %>% select(provcd, year, month, cpi_meat_mom),
    by = c("provcd", "year", "month")
  ) %>%
  left_join(
    grain %>% select(provcd, year, month, cpi_grain_mom),
    by = c("provcd", "year", "month")
  ) %>%
  left_join(
    eggs %>% select(provcd, year, month, cpi_eggs_mom),
    by = c("provcd", "year", "month")
  )

# 4. Compute YoY from MoM (preceding month=100)
# YoY = product of 12 consecutive MoM factors - 1
# For each series, compute rolling 12-month product
compute_yoy <- function(mom_series) {
  n <- length(mom_series)
  yoy <- rep(NA_real_, n)
  for (i in 12:n) {
    window <- mom_series[(i-11):i]
    if (all(!is.na(window))) {
      yoy[i] <- (prod(window / 100) - 1) * 100
    }
  }
  yoy
}

panel <- panel %>%
  arrange(provcd, year, month) %>%
  group_by(provcd) %>%
  mutate(
    cpi_headline_yoy = compute_yoy(cpi_headline_mom),
    cpi_meat_yoy = compute_yoy(cpi_meat_mom),
    cpi_grain_yoy = compute_yoy(cpi_grain_mom),
    cpi_eggs_yoy = compute_yoy(cpi_eggs_mom)
  ) %>%
  ungroup()

# 5. Save
write_csv(panel, file.path(out_dir, "province_cpi_monthly.csv"))

message(sprintf("Output: %s (%d rows, %d provinces)",
                file.path(out_dir, "province_cpi_monthly.csv"),
                nrow(panel), n_distinct(panel$provcd)))
message("=== Province CPI panel complete ===")
```

- [ ] **Step 2: Run the script and verify output**

Run: `cd "E:/研究生/WP_BFSU" && Rscript src/15_build_province_cpi.R`
Expected: Creates `data/processed/province_cpi_monthly.csv` with ~5,580 rows (31 provinces × 180 months). Check that province count is 31, year range 2011-2025, meat CPI has values from ~2016 onward.

- [ ] **Step 3: Verify data integrity**

```r
# Quick checks to run interactively
df <- read_csv("data/processed/province_cpi_monthly.csv")
stopifnot(n_distinct(df$provcd) >= 25)  # at least 25 provinces
stopifnot(min(df$year) == 2011)
stopifnot(max(df$year) == 2025)
stopifnot(all(df$cpi_headline_mom > 90 & df$cpi_headline_mom < 115,
              na.rm = TRUE))
message("All checks passed")
```

- [ ] **Step 4: Commit**

```bash
git add src/15_build_province_cpi.R
git commit -m "feat: add province CPI parsing pipeline (headline + meat/grain/egg)"
```

---

### Task 2: Build Meat Shock Variable

**Files:**
- Create: `src/16_build_meat_shock.R`
- Input: `data/processed/province_cpi_monthly.csv`
- Output: `data/processed/province_meat_shock.csv`

- [ ] **Step 1: Create the meat shock construction script**

```r
#!/usr/bin/env Rscript
# 16_build_meat_shock.R
# Construct province-level meat CPI shock for each CFPS wave pair
# MeatShock = cumulative log meat CPI change during inter-wave window

library(dplyr)
library(readr)

out_dir <- file.path("data", "processed")

# --- Load province CPI panel ---
cpi <- read_csv(file.path(out_dir, "province_cpi_monthly.csv"),
                show_col_types = FALSE)

# --- CFPS wave timing ---
# CFPS fieldwork is typically in summer (June-August)
# We define inter-wave windows as July of previous wave to
# June of current wave (24 months for biennial waves)
cfps_waves <- data.frame(
  wave = c(2012, 2014, 2016, 2018, 2020, 2022),
  window_start_year  = c(2010, 2012, 2014, 2016, 2018, 2020),
  window_start_month = c(7, 7, 7, 7, 7, 7),
  window_end_year    = c(2012, 2014, 2016, 2018, 2020, 2022),
  window_end_month   = c(6, 6, 6, 6, 6, 6)
)

# --- Compute cumulative log meat CPI for each province-wave ---
compute_shock <- function(cpi_data, prov, start_y, start_m,
                          end_y, end_m, var = "cpi_meat_mom") {
  d <- cpi_data %>%
    filter(provcd == prov) %>%
    filter((year > start_y | (year == start_y & month >= start_m)) &
           (year < end_y | (year == end_y & month <= end_m))) %>%
    arrange(year, month)

  vals <- d[[var]]
  if (length(vals) == 0 || all(is.na(vals))) return(NA_real_)
  vals <- vals[!is.na(vals)]
  if (length(vals) < 6) return(NA_real_)  # require at least 6 months
  sum(log(vals / 100))
}

# --- Build shock panel ---
provinces <- unique(cpi$provcd)
provinces <- provinces[!is.na(provinces)]

results <- list()
for (i in seq_len(nrow(cfps_waves))) {
  w <- cfps_waves[i, ]
  for (prov in provinces) {
    meat_shock <- compute_shock(cpi, prov,
      w$window_start_year, w$window_start_month,
      w$window_end_year, w$window_end_month,
      "cpi_meat_mom")

    grain_shock <- compute_shock(cpi, prov,
      w$window_start_year, w$window_start_month,
      w$window_end_year, w$window_end_month,
      "cpi_grain_mom")

    egg_shock <- compute_shock(cpi, prov,
      w$window_start_year, w$window_start_month,
      w$window_end_year, w$window_end_month,
      "cpi_eggs_mom")

    # Also compute realized headline CPI in NEXT wave window
    # (for forecast error construction)
    next_idx <- i + 1
    if (next_idx <= nrow(cfps_waves)) {
      wn <- cfps_waves[next_idx, ]
      headline_next <- compute_shock(cpi, prov,
        wn$window_start_year, wn$window_start_month,
        wn$window_end_year, wn$window_end_month,
        "cpi_headline_mom")
    } else {
      # For last wave, use 2022-2024 window
      headline_next <- compute_shock(cpi, prov,
        2022, 7, 2024, 6, "cpi_headline_mom")
    }

    results[[length(results) + 1]] <- data.frame(
      provcd = prov,
      wave = w$wave,
      meat_shock = meat_shock,
      grain_shock = grain_shock,
      egg_shock = egg_shock,
      headline_cpi_next = headline_next,
      stringsAsFactors = FALSE
    )
  }
}

shocks <- bind_rows(results)

# --- Add province names ---
prov_names <- cpi %>%
  distinct(provcd, province_name)
shocks <- shocks %>%
  left_join(prov_names, by = "provcd")

# --- Summary ---
message(sprintf("Meat shock panel: %d province-wave obs", nrow(shocks)))
message(sprintf("Waves: %s", paste(sort(unique(shocks$wave)),
                                    collapse = ", ")))
message(sprintf("Non-missing meat shock: %d",
                sum(!is.na(shocks$meat_shock))))

# --- Summary stats for meat shock ---
cat("\n=== Meat Shock Summary by Wave ===\n")
shocks %>%
  group_by(wave) %>%
  summarise(
    n = sum(!is.na(meat_shock)),
    mean = mean(meat_shock, na.rm = TRUE),
    sd = sd(meat_shock, na.rm = TRUE),
    min = min(meat_shock, na.rm = TRUE),
    max = max(meat_shock, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

# --- Save ---
write_csv(shocks, file.path(out_dir, "province_meat_shock.csv"))
message(sprintf("\nOutput: %s", file.path(out_dir,
                "province_meat_shock.csv")))
```

- [ ] **Step 2: Run and verify**

Run: `Rscript src/16_build_meat_shock.R`
Expected: ~186 rows (31 provinces × 6 waves). The 2018-2020 wave should show the largest meat shocks (ASF period). Check that cross-province standard deviation is meaningfully large for 2018/2020 waves.

- [ ] **Step 3: Commit**

```bash
git add src/16_build_meat_shock.R
git commit -m "feat: construct province-level meat shock variable by CFPS wave"
```

---

### Task 3: Rebuild CFPS Panel with Province CPI Match

**Files:**
- Create: `src/17_build_cfps_panel_v2.R`
- Input: `data/raw/CFPS/`, `data/processed/province_meat_shock.csv`, `data/processed/province_cpi_monthly.csv`
- Output: `data/processed/cfps_salience_panel.csv`

- [ ] **Step 1: Create the rebuilt CFPS panel script**

This script reuses the wave extraction logic from `src/12_build_cfps_panel.R` but:
- Matches households to province-level realized CPI (not national)
- Constructs forecast error using province-level headline CPI
- Merges province-level meat shock as the treatment variable
- Does NOT construct the contaminated revision-error proxy

```r
#!/usr/bin/env Rscript
# 17_build_cfps_panel_v2.R
# Build CFPS panel matched to province-level CPI and meat shocks
# for the salience-based identification design

library(haven)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)

source("src/00_project_utils.R")

raw_dir  <- file.path("data", "raw", "CFPS")
out_dir  <- file.path("data", "processed")

# --- Reuse wave extraction from 12_build_cfps_panel.R ---
# (Copy the waves list and extract_wave function from that script)
# Key change: we keep province codes for matching

# [The wave config and extract_wave() function from
#  src/12_build_cfps_panel.R lines 22-158 are reused here.
#  The only change is ensuring provcd is properly mapped.]

# --- After extraction, merge province-level data ---

# Load province meat shocks
shocks <- read_csv(file.path(out_dir, "province_meat_shock.csv"),
                   show_col_types = FALSE)

# Load province CPI for forecast error construction
prov_cpi <- read_csv(file.path(out_dir, "province_cpi_monthly.csv"),
                     show_col_types = FALSE)

# Compute province-year average headline CPI (YoY)
prov_cpi_annual <- prov_cpi %>%
  filter(!is.na(cpi_headline_yoy)) %>%
  group_by(provcd, year) %>%
  summarise(cpi_yoy_prov = mean(cpi_headline_yoy, na.rm = TRUE),
            .groups = "drop")

# --- Merge into CFPS panel ---
# 1. Merge meat shock by province-wave
panel <- panel_clean %>%
  left_join(shocks %>% select(provcd, wave, meat_shock,
                               grain_shock, egg_shock,
                               headline_cpi_next),
            by = c("provcd", "wave"))

# 2. Merge province-level realized CPI for forecast error
#    Match wave year to province CPI
panel <- panel %>%
  left_join(prov_cpi_annual, by = c("provcd", "wave" = "year"))

# 3. Construct clean forecast error
#    FE = realized province CPI(t→t+1) - expectation direction
#    Use headline_cpi_next (cumulative log CPI in next wave window)
#    scaled to percentage points
panel <- panel %>%
  mutate(
    # Convert cumulative log to percentage
    realized_infl_next = headline_cpi_next * 100,
    # g(μ): map ordinal expectation to quantitative proxy
    # Using province-level mean CPI as the neutral anchor
    exp_quantified = case_when(
      price_exp == 1 ~ cpi_yoy_prov + 2,   # expects rise above trend
      price_exp == 0 ~ cpi_yoy_prov,        # expects trend continuation
      price_exp == -1 ~ cpi_yoy_prov - 2,   # expects below trend
      TRUE ~ NA_real_
    ),
    # Forecast error: realized minus expected
    fe_clean = realized_infl_next - exp_quantified
  )

# --- Save ---
write_csv(panel, file.path(out_dir, "cfps_salience_panel.csv"))
```

Note: This script will need refinement during implementation to handle the exact province code mapping between CFPS waves and the CPI data. The key design decision is that `fe_clean` uses province-level realized CPI, not the household's own expectation variable.

- [ ] **Step 2: Run and verify**

Run: `Rscript src/17_build_cfps_panel_v2.R`
Expected: Panel with ~13,000+ obs, non-missing meat_shock for waves 2016-2022, province-level CPI matched.

- [ ] **Step 3: Commit**

```bash
git add src/17_build_cfps_panel_v2.R
git commit -m "feat: rebuild CFPS panel with province CPI match and clean FE"
```

---

### Task 4: Construct Pre-ASF Pig Intensity

**Files:**
- Create: `src/18_pig_intensity.R`
- Output: `data/processed/province_pig_intensity.csv`

- [ ] **Step 1: Create pig intensity script**

Since NBS province-level pig inventory data may not be readily available as a file, we use the meat CPI volatility in the pre-ASF window (2016-2018H1) as a proxy for province-level exposure to pork supply shocks. Provinces with more volatile meat CPI before ASF are more exposed.

```r
#!/usr/bin/env Rscript
# 18_pig_intensity.R
# Construct pre-ASF pig intensity proxy by province
# Uses pre-2018 meat CPI volatility as exposure measure

library(dplyr)
library(readr)

out_dir <- file.path("data", "processed")

cpi <- read_csv(file.path(out_dir, "province_cpi_monthly.csv"),
                show_col_types = FALSE)

# Pre-ASF window: Jan 2016 to Jul 2018
pre_asf <- cpi %>%
  filter(year >= 2016, (year < 2018 | (year == 2018 & month <= 7))) %>%
  filter(!is.na(cpi_meat_mom))

pig_intensity <- pre_asf %>%
  group_by(provcd, province_name) %>%
  summarise(
    meat_cpi_sd_pre = sd(cpi_meat_mom, na.rm = TRUE),
    meat_cpi_mean_pre = mean(cpi_meat_mom, na.rm = TRUE),
    meat_cpi_range_pre = max(cpi_meat_mom, na.rm = TRUE) -
                         min(cpi_meat_mom, na.rm = TRUE),
    n_months = n(),
    .groups = "drop"
  ) %>%
  # Standardize
  mutate(
    pig_intensity_z = scale(meat_cpi_sd_pre)[, 1]
  )

write_csv(pig_intensity,
          file.path(out_dir, "province_pig_intensity.csv"))

message(sprintf("Pig intensity: %d provinces", nrow(pig_intensity)))
cat("\n=== Pig Intensity Summary ===\n")
summary(pig_intensity$meat_cpi_sd_pre)
```

- [ ] **Step 2: Run and verify**

Run: `Rscript src/18_pig_intensity.R`
Expected: 31 rows (one per province), reasonable variation in `meat_cpi_sd_pre`.

- [ ] **Step 3: Commit**

```bash
git add src/18_pig_intensity.R
git commit -m "feat: construct pre-ASF pig intensity proxy by province"
```

---

## Phase 2: Estimation

### Task 5: Main Salience Models (Eq 1, 2, 3 + Wald Test)

**Files:**
- Create: `src/41_models_salience.R`
- Input: `data/processed/cfps_salience_panel.csv`
- Output: `outputs/tables/salience_eq1_expectations.tex`, `outputs/tables/salience_eq2_cpi.tex`, `outputs/tables/salience_eq3_fe.tex`, `outputs/tables/salience_wald_test.tex`

- [ ] **Step 1: Create estimation script**

```r
#!/usr/bin/env Rscript
# 41_models_salience.R
# Estimate the three-equation salience identification design
# Eq 1: MeatShock -> expectations
# Eq 2: MeatShock -> headline CPI
# Eq 3: MeatShock -> forecast error
# Plus formal Wald test of β₁ = β₂

library(dplyr)
library(readr)
library(fixest)      # fast FE estimation
library(modelsummary) # publication tables

out_dir <- file.path("outputs", "tables")
data_dir <- file.path("data", "processed")

panel <- read_csv(file.path(data_dir, "cfps_salience_panel.csv"),
                  show_col_types = FALSE)

# --- Restrict to waves with meat shock data ---
est_sample <- panel %>%
  filter(!is.na(meat_shock), !is.na(price_exp))

message(sprintf("Estimation sample: %d obs, %d provinces, waves %s",
                nrow(est_sample),
                n_distinct(est_sample$provcd),
                paste(sort(unique(est_sample$wave)), collapse=",")))

# ========== Equation 1: MeatShock -> Expectations ==========
eq1_biv   <- feols(price_exp ~ meat_shock,
                   data = est_sample, cluster = ~provcd)
eq1_ctrl  <- feols(price_exp ~ meat_shock + age + edu_high + urban,
                   data = est_sample, cluster = ~provcd)
eq1_pfe   <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                   provcd,
                   data = est_sample, cluster = ~provcd)
eq1_wfe   <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                   wave,
                   data = est_sample, cluster = ~provcd)
eq1_full  <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                   provcd + wave,
                   data = est_sample, cluster = ~provcd)

eq1_models <- list(
  "(1)" = eq1_biv, "(2)" = eq1_ctrl, "(3)" = eq1_pfe,
  "(4)" = eq1_wfe, "(5)" = eq1_full
)

# ========== Equation 2: MeatShock -> Headline CPI ==========
# Province-level regression
prov_panel <- est_sample %>%
  distinct(provcd, wave, .keep_all = TRUE) %>%
  select(provcd, wave, meat_shock, headline_cpi_next)

eq2_biv  <- feols(headline_cpi_next ~ meat_shock,
                  data = prov_panel, cluster = ~provcd)
eq2_pfe  <- feols(headline_cpi_next ~ meat_shock | provcd,
                  data = prov_panel, cluster = ~provcd)
eq2_full <- feols(headline_cpi_next ~ meat_shock | provcd + wave,
                  data = prov_panel, cluster = ~provcd)

eq2_models <- list(
  "(1)" = eq2_biv, "(2)" = eq2_pfe, "(3)" = eq2_full
)

# ========== Equation 3: MeatShock -> Forecast Error ==========
eq3_biv  <- feols(fe_clean ~ meat_shock,
                  data = est_sample, cluster = ~provcd)
eq3_ctrl <- feols(fe_clean ~ meat_shock + age + edu_high + urban,
                  data = est_sample, cluster = ~provcd)
eq3_pfe  <- feols(fe_clean ~ meat_shock + age + edu_high + urban |
                  provcd,
                  data = est_sample, cluster = ~provcd)
eq3_wfe  <- feols(fe_clean ~ meat_shock + age + edu_high + urban |
                  wave,
                  data = est_sample, cluster = ~provcd)
eq3_full <- feols(fe_clean ~ meat_shock + age + edu_high + urban |
                  provcd + wave,
                  data = est_sample, cluster = ~provcd)

eq3_models <- list(
  "(1)" = eq3_biv, "(2)" = eq3_ctrl, "(3)" = eq3_pfe,
  "(4)" = eq3_wfe, "(5)" = eq3_full
)

# ========== Wald Test: β₁ = β₂ ==========
# Stacked regression approach
# Create stacked dataset with equation indicator
stacked <- bind_rows(
  est_sample %>%
    distinct(provcd, wave, .keep_all = TRUE) %>%
    mutate(y = price_exp, eq = "exp"),
  est_sample %>%
    distinct(provcd, wave, .keep_all = TRUE) %>%
    mutate(y = headline_cpi_next, eq = "cpi")
) %>%
  mutate(is_exp = as.integer(eq == "exp"))

wald_model <- feols(y ~ meat_shock * is_exp | provcd + wave,
                    data = stacked, cluster = ~provcd)

# The interaction term meat_shock:is_exp tests β₁ - β₂
# H₀: β₁ = β₂ ↔ interaction = 0
wald_pval <- summary(wald_model)$coeftable["meat_shock:is_exp",
                                            "Pr(>|t|)"]

message(sprintf("Wald test p-value (β₁ = β₂): %.4f", wald_pval))

# ========== Export Tables ==========
# [Use modelsummary or custom LaTeX export matching JPE-Macro format]
# Each table: booktabs, multicolumn, no p-values, stars only,
# controls indicators, N/R²/clusters footer

# Save model objects for table generation
saveRDS(eq1_models, file.path(data_dir, "eq1_models.rds"))
saveRDS(eq2_models, file.path(data_dir, "eq2_models.rds"))
saveRDS(eq3_models, file.path(data_dir, "eq3_models.rds"))
saveRDS(wald_model, file.path(data_dir, "wald_model.rds"))

message("=== Salience models estimated ===")
```

- [ ] **Step 2: Run and verify**

Run: `Rscript src/41_models_salience.R`
Expected: All models estimate without error. Check β₁ sign (should be positive), β₂ sign (should be near zero or small), β₃ sign (should be negative).

- [ ] **Step 3: Commit**

```bash
git add src/41_models_salience.R
git commit -m "feat: estimate three-equation salience models with Wald test"
```

---

### Task 6: Heterogeneity Models

**Files:**
- Create: `src/42_models_heterogeneity_v2.R`
- Output: `outputs/tables/salience_heterogeneity.tex`

- [ ] **Step 1: Create heterogeneity script**

Interact meat shock with income tercile, education, urban status, and food expenditure proxy. Each interaction tests whether salience-driven overreaction varies with household characteristics as theory predicts.

```r
#!/usr/bin/env Rscript
# 42_models_heterogeneity_v2.R
# Heterogeneity: interact meat shock with household characteristics

library(dplyr)
library(readr)
library(fixest)

data_dir <- file.path("data", "processed")
panel <- read_csv(file.path(data_dir, "cfps_salience_panel.csv"),
                  show_col_types = FALSE) %>%
  filter(!is.na(meat_shock), !is.na(price_exp))

# --- Interactions ---
het_income <- feols(
  price_exp ~ meat_shock * income_below_median +
    age + edu_high + urban | provcd + wave,
  data = panel, cluster = ~provcd)

het_edu <- feols(
  price_exp ~ meat_shock * edu_high +
    age + urban | provcd + wave,
  data = panel, cluster = ~provcd)

het_urban <- feols(
  price_exp ~ meat_shock * urban +
    age + edu_high | provcd + wave,
  data = panel, cluster = ~provcd)

# FE version for Eq 3
het_fe_income <- feols(
  fe_clean ~ meat_shock * income_below_median +
    age + edu_high + urban | provcd + wave,
  data = panel, cluster = ~provcd)

het_fe_edu <- feols(
  fe_clean ~ meat_shock * edu_high +
    age + urban | provcd + wave,
  data = panel, cluster = ~provcd)

het_fe_urban <- feols(
  fe_clean ~ meat_shock * urban +
    age + edu_high | provcd + wave,
  data = panel, cluster = ~provcd)

het_models <- list(
  exp_income = het_income, exp_edu = het_edu,
  exp_urban = het_urban,
  fe_income = het_fe_income, fe_edu = het_fe_edu,
  fe_urban = het_fe_urban
)

saveRDS(het_models, file.path(data_dir, "het_models.rds"))
message("=== Heterogeneity models estimated ===")
```

- [ ] **Step 2: Run and verify, then commit**

```bash
Rscript src/42_models_heterogeneity_v2.R
git add src/42_models_heterogeneity_v2.R
git commit -m "feat: estimate heterogeneity interactions with meat shock"
```

---

### Task 7: Spillover Diagnostics

**Files:**
- Create: `src/43_models_spillover.R`
- Output: `outputs/tables/salience_spillover.tex`

- [ ] **Step 1: Create spillover script**

Add neighbor-province average meat shock as control. Compute spatial lags using province adjacency. Re-estimate with Conley SEs if `conleyreg` or similar package is available.

```r
#!/usr/bin/env Rscript
# 43_models_spillover.R
# Spillover diagnostics for meat shock identification

library(dplyr)
library(readr)
library(fixest)

data_dir <- file.path("data", "processed")
panel <- read_csv(file.path(data_dir, "cfps_salience_panel.csv"),
                  show_col_types = FALSE) %>%
  filter(!is.na(meat_shock), !is.na(price_exp))

shocks <- read_csv(file.path(data_dir, "province_meat_shock.csv"),
                   show_col_types = FALSE)

# --- Construct national average meat shock (leave-one-out) ---
national_avg <- shocks %>%
  group_by(wave) %>%
  mutate(
    national_meat_shock = (sum(meat_shock, na.rm = TRUE) -
      ifelse(is.na(meat_shock), 0, meat_shock)) /
      (sum(!is.na(meat_shock)) - ifelse(is.na(meat_shock), 0, 1))
  ) %>%
  ungroup() %>%
  select(provcd, wave, national_meat_shock)

panel <- panel %>%
  left_join(national_avg, by = c("provcd", "wave")) %>%
  mutate(
    # Province deviation from national
    meat_shock_deviation = meat_shock - national_meat_shock
  )

# --- Models ---
# Baseline (replicate)
spill_base <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                    provcd + wave,
                    data = panel, cluster = ~provcd)

# Control for national shock
spill_national <- feols(
  price_exp ~ meat_shock + national_meat_shock +
    age + edu_high + urban | provcd + wave,
  data = panel, cluster = ~provcd)

# Use deviation only
spill_deviation <- feols(
  price_exp ~ meat_shock_deviation + age + edu_high + urban |
    provcd + wave,
  data = panel, cluster = ~provcd)

# Same for FE outcome
spill_fe_base <- feols(fe_clean ~ meat_shock +
                       age + edu_high + urban | provcd + wave,
                       data = panel, cluster = ~provcd)

spill_fe_national <- feols(
  fe_clean ~ meat_shock + national_meat_shock +
    age + edu_high + urban | provcd + wave,
  data = panel, cluster = ~provcd)

spill_models <- list(
  exp_base = spill_base, exp_national = spill_national,
  exp_deviation = spill_deviation,
  fe_base = spill_fe_base, fe_national = spill_fe_national
)

saveRDS(spill_models, file.path(data_dir, "spillover_models.rds"))
message("=== Spillover diagnostics estimated ===")
```

- [ ] **Step 2: Run, verify, commit**

```bash
Rscript src/43_models_spillover.R
git add src/43_models_spillover.R
git commit -m "feat: spillover diagnostics with national shock control"
```

---

### Task 8: Shift-Share (Bartik) IV

**Files:**
- Create: `src/44_models_bartik_iv.R`
- Output: `outputs/tables/salience_bartik_iv.tex`

- [ ] **Step 1: Create Bartik IV script**

Instrument: pre-ASF pig intensity × national meat CPI change.

```r
#!/usr/bin/env Rscript
# 44_models_bartik_iv.R
# Shift-share IV: pre-ASF pig intensity x national meat CPI

library(dplyr)
library(readr)
library(fixest)

data_dir <- file.path("data", "processed")

panel <- read_csv(file.path(data_dir, "cfps_salience_panel.csv"),
                  show_col_types = FALSE) %>%
  filter(!is.na(meat_shock), !is.na(price_exp))

pig <- read_csv(file.path(data_dir, "province_pig_intensity.csv"),
                show_col_types = FALSE) %>%
  select(provcd, pig_intensity_z)

shocks <- read_csv(file.path(data_dir, "province_meat_shock.csv"),
                   show_col_types = FALSE)

# National meat shock by wave
national_shock <- shocks %>%
  group_by(wave) %>%
  summarise(national_meat_shock = mean(meat_shock, na.rm = TRUE),
            .groups = "drop")

# Merge pig intensity and national shock
panel <- panel %>%
  left_join(pig, by = "provcd") %>%
  left_join(national_shock, by = "wave") %>%
  mutate(
    bartik_iv = pig_intensity_z * national_meat_shock
  )

# --- First stage ---
fs <- feols(meat_shock ~ bartik_iv + age + edu_high + urban |
            provcd + wave,
            data = panel, cluster = ~provcd)
message(sprintf("First-stage F: %.2f",
                fitstat(fs, "ivf")$ivf1$stat))

# --- IV estimation ---
iv_exp <- feols(price_exp ~ age + edu_high + urban |
                provcd + wave |
                meat_shock ~ bartik_iv,
                data = panel, cluster = ~provcd)

iv_fe <- feols(fe_clean ~ age + edu_high + urban |
               provcd + wave |
               meat_shock ~ bartik_iv,
               data = panel, cluster = ~provcd)

# --- Reduced form ---
rf_exp <- feols(price_exp ~ bartik_iv + age + edu_high + urban |
                provcd + wave,
                data = panel, cluster = ~provcd)

rf_fe <- feols(fe_clean ~ bartik_iv + age + edu_high + urban |
               provcd + wave,
               data = panel, cluster = ~provcd)

iv_models <- list(
  first_stage = fs,
  iv_exp = iv_exp, iv_fe = iv_fe,
  rf_exp = rf_exp, rf_fe = rf_fe
)

saveRDS(iv_models, file.path(data_dir, "bartik_iv_models.rds"))
message("=== Bartik IV models estimated ===")
```

- [ ] **Step 2: Run, verify first-stage F > 10, commit**

```bash
Rscript src/44_models_bartik_iv.R
git add src/44_models_bartik_iv.R
git commit -m "feat: shift-share IV with pre-ASF pig intensity"
```

---

### Task 9: Placebo Tests (Grain + Egg Shocks)

**Files:**
- Create: `src/45_models_placebo.R`
- Output: `outputs/tables/salience_placebo.tex`

- [ ] **Step 1: Create placebo script**

If overreaction is meat-price-specific (pork salience), then grain and egg shocks should have weaker effects on expectations.

```r
#!/usr/bin/env Rscript
# 45_models_placebo.R
# Placebo: grain and egg shocks should be weaker than meat

library(dplyr)
library(readr)
library(fixest)

data_dir <- file.path("data", "processed")
panel <- read_csv(file.path(data_dir, "cfps_salience_panel.csv"),
                  show_col_types = FALSE) %>%
  filter(!is.na(price_exp))

# Grain shock -> expectations
grain_exp <- feols(price_exp ~ grain_shock + age + edu_high + urban |
                   provcd + wave,
                   data = panel %>% filter(!is.na(grain_shock)),
                   cluster = ~provcd)

# Egg shock -> expectations
egg_exp <- feols(price_exp ~ egg_shock + age + edu_high + urban |
                 provcd + wave,
                 data = panel %>% filter(!is.na(egg_shock)),
                 cluster = ~provcd)

# Meat shock (replicate baseline for comparison)
meat_exp <- feols(price_exp ~ meat_shock + age + edu_high + urban |
                  provcd + wave,
                  data = panel %>% filter(!is.na(meat_shock)),
                  cluster = ~provcd)

# All three in same regression (horse race)
horse <- feols(price_exp ~ meat_shock + grain_shock + egg_shock +
               age + edu_high + urban | provcd + wave,
               data = panel %>%
                 filter(!is.na(meat_shock), !is.na(grain_shock),
                        !is.na(egg_shock)),
               cluster = ~provcd)

placebo_models <- list(
  meat = meat_exp, grain = grain_exp, egg = egg_exp,
  horse_race = horse
)

saveRDS(placebo_models, file.path(data_dir, "placebo_models.rds"))
message("=== Placebo models estimated ===")
```

- [ ] **Step 2: Run, verify, commit**

```bash
Rscript src/45_models_placebo.R
git add src/45_models_placebo.R
git commit -m "feat: placebo tests with grain and egg CPI shocks"
```

---

## Phase 3: Tables and Figures

### Task 10: Generate Publication Tables

**Files:**
- Create: `src/83_generate_tables_v2.R`
- Output: All `outputs/tables/salience_*.tex` files

- [ ] **Step 1: Create table generation script**

Uses `modelsummary` with custom formatting to produce JPE-Macro-quality LaTeX tables: booktabs, multicolumn headers, no p-values, stars only (* p<0.10, ** p<0.05, *** p<0.01), controls indicator rows, N/R²/clusters footer.

This script loads all .rds model objects from Phase 2 and produces formatted .tex tables.

- [ ] **Step 2: Run and verify LaTeX compiles**
- [ ] **Step 3: Commit**

---

### Task 11: Generate Publication Figures

**Files:**
- Create: `src/82_figures_v2.R`
- Output: `outputs/figures/meat_cpi_spaghetti.pdf`, `outputs/figures/asf_event_study.pdf`, `outputs/figures/binscatter_shock_fe.pdf`, `outputs/figures/heterogeneity_forest.pdf`

- [ ] **Step 1: Create figure script**

Produces four main-text figures:
1. Province meat CPI trajectories with ASF window shaded
2. Event study: dynamic coefficients around ASF
3. Binscatter: meat shock vs forecast error
4. Heterogeneity forest plot

All: Okabe-Ito palette, PDF vector, no gridlines, shaded confidence bands.

- [ ] **Step 2: Run and verify PDFs are produced**
- [ ] **Step 3: Commit**

---

## Phase 4: LaTeX Writing

### Task 12: Rewrite All Sections

**Files to create (replacing old sections):**
- `jmp/sections/01_introduction.tex`
- `jmp/sections/02_background.tex` (new, replaces 02_literature.tex)
- `jmp/sections/03_data.tex` (new, replaces 03_institutional_data.tex)
- `jmp/sections/04_strategy.tex` (new, replaces 05_identification.tex)
- `jmp/sections/05_results.tex` (new, replaces 06_baseline_results.tex)
- `jmp/sections/06_heterogeneity.tex` (new, replaces 07_heterogeneity.tex)
- `jmp/sections/07_robustness.tex` (new, replaces 10_robustness.tex + 08_mechanism.tex)
- `jmp/sections/08_conclusion.tex` (new, replaces 11_conclusion.tex)
- `jmp/main.tex` (update section includes and title)

Each section follows the spec in `docs/superpowers/specs/2026-04-07-jpe-macro-revision-design.md`.

Prose standards: US English, active voice, one idea per paragraph, economic magnitudes before significance, no AI-writing patterns.

- [ ] **Step 1-8: Write each section sequentially**
- [ ] **Step 9: Update main.tex**
- [ ] **Step 10: Compile and fix errors**
- [ ] **Step 11: Commit**

---

## Phase 5: Verification

### Task 13: Cross-Check and Consistency Audit

- [ ] **Step 1: Verify all numbers in text match output files**
- [ ] **Step 2: Verify sample windows are consistent across all tables**
- [ ] **Step 3: Verify inflation concept (YoY) is used everywhere**
- [ ] **Step 4: Run format audit (labels, references, figure placement)**
- [ ] **Step 5: Compile final PDF**
- [ ] **Step 6: Final commit**
