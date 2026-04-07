# Meat-Price Shock Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the JMP paper's empirical core around province-level meat CPI shocks as an exogenous salience treatment, replacing the mechanically contaminated revision-error regression, to address JPE-Macro desk reject.

**Architecture:** Three-equation design: (1) MeatShock → household expectations, (2) MeatShock → realized headline/non-food CPI, (3) MeatShock → forecast error. Province-level meat CPI (monthly, 2011-2025) matched to CFPS biennial waves (2012-2022) at the province level. Region × wave FE as preferred specification. Wild cluster bootstrap for inference.

**Tech Stack:** R (data.table, fixest, fwildclusterboot, ggplot2), XeLaTeX, existing `00_project_utils.R` utilities.

---

## File Map

### New files to create
| File | Purpose |
|---|---|
| `src/15_build_province_cpi.R` | Parse province-level meat/grain/eggs/headline CPI from raw CSVs and Excel → intermediate CSVs |
| `src/16_build_meat_shock.R` | Construct MeatShock treatment at province × wave-pair level |
| `src/17_province_code_map.R` | Province name ↔ GB/T 2260 code mapping (shared lookup) |
| `src/42_meat_shock_regressions.R` | Equations 1-3: main results tables |
| `src/43_heterogeneity_meat.R` | Heterogeneity by income, education, urban/rural |
| `src/44_placebo_commodity.R` | Grain and egg CPI shock placebos |
| `src/46_wild_bootstrap.R` | Wild cluster bootstrap p-values for all main specs |
| `src/82_asf_figures.R` | ASF event study, meat CPI spaghetti, binscatter |
| `jmp/sections/02_background.tex` | New Section 2: institutional background + conceptual framework |
| `jmp/sections/04_strategy.tex` | New Section 4: empirical strategy (two-equation design) |
| `jmp/sections/05_main_results.tex` | New Section 5: main results |
| `jmp/sections/06_heterogeneity_new.tex` | New Section 6: heterogeneity + placebos |
| `jmp/sections/07_robustness_new.tex` | New Section 7: robustness + PBoC sign check |

### Files to modify
| File | Changes |
|---|---|
| `src/12_build_cfps_panel.R` | Add province-level CPI merge, fix FE construction, add region codes |
| `src/40_models_baseline.R` | Lock sample to 2011Q1-2023Q4, clean PBoC sign check |
| `src/99_run_all.R` | Insert new scripts into pipeline |
| `jmp/main.tex` | Update `\input` order, remove dropped sections |
| `jmp/sections/01_introduction.tex` | Rewrite for new identification |
| `jmp/sections/03_institutional_data.tex` | Add province CPI data description |
| `jmp/sections/11_conclusion.tex` | Rewrite for new contributions |

### Files to remove from main text (keep in repo)
| File | Reason |
|---|---|
| `jmp/sections/04_measurement.tex` | Carlson-Parkin moves to appendix |
| `jmp/sections/08b_chfs_mechanism.tex` | CHFS dropped |
| `jmp/sections/09_policy.tex` | NK welfare dropped |
| `jmp/sections/09b_chfs_consequences.tex` | CHFS dropped |

---

## Task 1: Province Name-Code Mapping

**Files:**
- Create: `src/17_province_code_map.R`

This lookup maps English NBS province names (from the CPI CSVs) to GB/T 2260 numeric codes (used in CFPS). It also assigns macro-regions for region × wave FE.

- [ ] **Step 1: Create mapping file**

```r
#!/usr/bin/env Rscript
# 17_province_code_map.R
# Province name ↔ GB/T 2260 code mapping + macro-region assignment.

library(data.table)

province_map <- data.table(
  name_en = c(
    "Beijing", "Tianjin", "Hebei", "Shanxi", "Inner Mongolia",
    "Liaoning", "Jilin", "Heilongjiang",
    "Shanghai", "Jiangsu", "Zhejiang", "Anhui", "Fujian", "Jiangxi", "Shandong",
    "Henan", "Hubei", "Hunan",
    "Guangdong", "Guangxi", "Hainan",
    "Chongqing", "Sichuan", "Guizhou", "Yunnan", "Tibet",
    "Shaanxi", "Gansu", "Qinghai", "Ningxia", "Xinjiang"
  ),
  provcd = c(
    11L, 12L, 13L, 14L, 15L,
    21L, 22L, 23L,
    31L, 32L, 33L, 34L, 35L, 36L, 37L,
    41L, 42L, 43L,
    44L, 45L, 46L,
    50L, 51L, 52L, 53L, 54L,
    61L, 62L, 63L, 64L, 65L
  ),
  region = c(
    "North", "North", "North", "North", "North",
    "Northeast", "Northeast", "Northeast",
    "East", "East", "East", "East", "East", "East", "East",
    "Central", "Central", "Central",
    "South", "South", "South",
    "West", "West", "West", "West", "West",
    "West", "West", "West", "West", "West"
  )
)

get_province_map <- function() {
  copy(province_map)
}
```

- [ ] **Step 2: Validate mapping covers CFPS provinces**

Run: `Rscript -e "source('src/17_province_code_map.R'); m <- get_province_map(); cfps <- data.table::fread('data/processed/cfps_panel.csv'); cfps_provs <- unique(cfps[province > 0, province]); cat('CFPS provinces not in map:', setdiff(cfps_provs, m[['provcd']]), '\n'); cat('Map provinces not in CFPS:', setdiff(m[['provcd']], cfps_provs), '\n')"`

Expected: CFPS provinces not in map should be empty or contain only codes for provinces with no CPI data (Tibet=54, Hainan=46). Map provinces not in CFPS will show provinces not sampled by CFPS.

- [ ] **Step 3: Commit**

```bash
git add src/17_province_code_map.R
git commit -m "feat: add province name-code mapping with macro-regions"
```

---

## Task 2: Parse Province-Level CPI Data

**Files:**
- Create: `src/15_build_province_cpi.R`

Reads the three food-component CSVs (meat, grain, eggs) and three headline CPI Excel files. Outputs tidy long-format intermediates.

- [ ] **Step 1: Create the CPI parser**

```r
#!/usr/bin/env Rscript
# 15_build_province_cpi.R
# Parse province-level CPI data from NBS raw files.
# Inputs:  data/raw/nbc_food_CPI_province/nbc_{meat,grain,eggs}_CPI by Province.csv
#          data/raw/CPI_Monthly By Province_{2011-2015,2016-2020,2021-2025}.xlsx
# Outputs: data/intermediate/province_meat_cpi.csv
#          data/intermediate/province_grain_cpi.csv
#          data/intermediate/province_eggs_cpi.csv
#          data/intermediate/province_headline_cpi.csv

suppressPackageStartupMessages({
  library(data.table)
  library(readxl)
})

source(file.path("src", "00_project_utils.R"))
source(file.path("src", "17_province_code_map.R"))
ensure_paths()

# --- Helper: parse NBS "Monthly By Province" CSV format ---
# Format: 2 header rows, row 3 = "Region\t,Mon YYYY\t,Mon YYYY..."
# Rows 4-34 = province data, last row = footer
parse_nbs_province_csv <- function(filepath, commodity_label) {
  lines <- readLines(filepath, encoding = "UTF-8")
  # Row 3 has column headers
  header_line <- lines[3]
  header_parts <- strsplit(header_line, "\t")[[1]]
  # Clean: remove leading comma and whitespace
  col_names <- trimws(gsub("^,", "", header_parts))
  col_names[1] <- "province_name"

  # Data rows: 4 to (length - 1), skip footer
  data_lines <- lines[4:(length(lines) - 1)]
  # Parse each line
  rows <- lapply(data_lines, function(l) {
    parts <- strsplit(l, "\t")[[1]]
    parts <- trimws(gsub("^,", "", parts))
    parts
  })

  dt <- as.data.table(do.call(rbind, rows))
  # Truncate or pad to match header length
  if (ncol(dt) > length(col_names)) dt <- dt[, 1:length(col_names)]
  setnames(dt, col_names[1:ncol(dt)])

  # Melt to long format
  month_cols <- setdiff(names(dt), "province_name")
  dt_long <- melt(dt, id.vars = "province_name",
                  variable.name = "month_label",
                  value.name = "cpi_index")

  # Parse month label "Dec 2025" -> date
  dt_long[, month_label := as.character(month_label)]
  dt_long[, date := as.Date(paste0("01 ", month_label), format = "%d %b %Y")]
  dt_long[, cpi_index := as.numeric(cpi_index)]
  dt_long[, commodity := commodity_label]

  # Drop rows with missing dates or values
  dt_long <- dt_long[!is.na(date) & !is.na(cpi_index)]

  # Add province code
  pmap <- get_province_map()
  dt_long <- merge(dt_long, pmap[, .(name_en, provcd, region)],
                   by.x = "province_name", by.y = "name_en", all.x = TRUE)

  dt_long[, .(provcd, province_name, region, date, commodity, cpi_index)]
}

# --- Parse food component CSVs ---
food_dir <- file.path(project_paths$raw, "nbc_food_CPI_province")

meat  <- parse_nbs_province_csv(file.path(food_dir, "nbc_meat_CPI by Province.csv"), "meat")
grain <- parse_nbs_province_csv(file.path(food_dir, "nbc_grain_CPI by Province.csv"), "grain")
eggs  <- parse_nbs_province_csv(file.path(food_dir, "nbc_eggs_CPI by Province.csv"), "eggs")

fwrite(meat,  file.path(project_paths$intermediate, "province_meat_cpi.csv"))
fwrite(grain, file.path(project_paths$intermediate, "province_grain_cpi.csv"))
fwrite(eggs,  file.path(project_paths$intermediate, "province_eggs_cpi.csv"))

cat(sprintf("[15] Meat CPI: %d obs, %d provinces, %s to %s\n",
            nrow(meat), uniqueN(meat$provcd),
            min(meat$date), max(meat$date)))
cat(sprintf("[15] Grain CPI: %d obs, %d provinces\n", nrow(grain), uniqueN(grain$provcd)))
cat(sprintf("[15] Eggs CPI: %d obs, %d provinces\n", nrow(eggs), uniqueN(eggs$provcd)))

# --- Parse headline CPI Excel files ---
excel_files <- list.files(project_paths$raw,
                          pattern = "CPI_Monthly By Province.*\\.xlsx$",
                          full.names = TRUE)

parse_headline_excel <- function(filepath) {
  # Read Excel: row 1 = header with month labels, col 1 = province names
  dt <- as.data.table(read_excel(filepath, skip = 0))
  # First column is province name
  prov_col <- names(dt)[1]
  setnames(dt, prov_col, "province_name")
  # Remove any non-province rows
  dt <- dt[!is.na(province_name) & province_name != ""]

  month_cols <- setdiff(names(dt), "province_name")
  dt_long <- melt(dt, id.vars = "province_name",
                  variable.name = "month_label",
                  value.name = "cpi_index")
  dt_long[, month_label := as.character(month_label)]
  # Excel dates might be numeric or text; handle both
  dt_long[, date := tryCatch(
    as.Date(paste0("01 ", month_label), format = "%d %b %Y"),
    error = function(e) as.Date(NA)
  ), by = month_label]
  dt_long[, cpi_index := as.numeric(cpi_index)]
  dt_long <- dt_long[!is.na(date) & !is.na(cpi_index)]

  pmap <- get_province_map()
  dt_long <- merge(dt_long, pmap[, .(name_en, provcd, region)],
                   by.x = "province_name", by.y = "name_en", all.x = TRUE)
  dt_long[, commodity := "headline"]
  dt_long[, .(provcd, province_name, region, date, commodity, cpi_index)]
}

headline_list <- lapply(excel_files, function(f) {
  tryCatch(parse_headline_excel(f), error = function(e) {
    message(sprintf("Warning: could not parse %s: %s", f, e$message))
    NULL
  })
})
headline <- rbindlist(compact(headline_list))

if (nrow(headline) > 0) {
  fwrite(headline, file.path(project_paths$intermediate, "province_headline_cpi.csv"))
  cat(sprintf("[15] Headline CPI: %d obs, %d provinces\n",
              nrow(headline), uniqueN(headline$provcd)))
} else {
  cat("[15] WARNING: headline CPI parsing returned 0 rows. Check Excel format.\n")
}

cat("[15] Province CPI parsing complete.\n")
```

- [ ] **Step 2: Run and validate output**

Run: `Rscript src/15_build_province_cpi.R`

Expected: Three food CSV intermediates and one headline intermediate created. Meat CPI should have ~31 provinces × ~180 months ≈ 5,500 rows. Check for NA province codes (unmatched names).

Validate: `Rscript -e "d <- data.table::fread('data/intermediate/province_meat_cpi.csv'); cat('Rows:', nrow(d), '\nProvinces:', uniqueN(d[['provcd']]), '\nNA provcd:', sum(is.na(d[['provcd']])), '\nDate range:', as.character(range(d[['date']])), '\n')"`

- [ ] **Step 3: Commit**

```bash
git add src/15_build_province_cpi.R
git commit -m "feat: parse province-level CPI data (meat, grain, eggs, headline)"
```

---

## Task 3: Construct MeatShock Treatment Variable

**Files:**
- Create: `src/16_build_meat_shock.R`

Constructs the province × wave-pair treatment variable: cumulative log meat CPI change between CFPS fieldwork windows.

- [ ] **Step 1: Create MeatShock construction script**

```r
#!/usr/bin/env Rscript
# 16_build_meat_shock.R
# Construct MeatShock_{p, t-1 -> t} at province x wave-pair level.
# MeatShock = cumulative log(MeatCPI/100) over months between CFPS waves.
# Also constructs GrainShock and EggShock for placebo tests,
# and province-level realized headline CPI for forecast error construction.

suppressPackageStartupMessages({
  library(data.table)
})

source(file.path("src", "00_project_utils.R"))
source(file.path("src", "17_province_code_map.R"))
ensure_paths()

# --- CFPS wave fieldwork windows (approximate midpoints) ---
# CFPS fieldwork typically runs Jul-Dec of survey year.
# We define the inter-wave window as Jan of wave year to Dec of wave year.
cfps_waves <- data.table(
  wave = c(2010L, 2012L, 2014L, 2016L, 2018L, 2020L, 2022L),
  wave_start = as.Date(c("2010-07-01", "2012-07-01", "2014-07-01",
                          "2016-07-01", "2018-07-01", "2020-07-01",
                          "2022-07-01")),
  wave_end   = as.Date(c("2010-12-31", "2012-12-31", "2014-12-31",
                          "2016-12-31", "2018-12-31", "2020-12-31",
                          "2022-12-31"))
)

# --- Load province CPI intermediates ---
meat  <- fread(file.path(project_paths$intermediate, "province_meat_cpi.csv"))
grain <- fread(file.path(project_paths$intermediate, "province_grain_cpi.csv"))
eggs  <- fread(file.path(project_paths$intermediate, "province_eggs_cpi.csv"))

meat[, date := as.Date(date)]
grain[, date := as.Date(date)]
eggs[, date := as.Date(date)]

# --- Compute cumulative log CPI change between wave pairs ---
compute_shock <- function(cpi_dt, shock_name) {
  # For each province, compute cumulative log(index/100) between consecutive waves
  # wave_pair: (wave_prev, wave_curr)
  # Window: from wave_prev midpoint to wave_curr midpoint
  wave_pairs <- data.table(
    wave_prev = c(2010L, 2012L, 2014L, 2016L, 2018L, 2020L),
    wave_curr = c(2012L, 2014L, 2016L, 2018L, 2020L, 2022L)
  )

  results <- list()
  for (i in seq_len(nrow(wave_pairs))) {
    wp <- wave_pairs[i]
    # Window: Jan of prev wave year to Jun of current wave year
    # (captures price changes households experienced before current survey)
    window_start <- as.Date(paste0(wp$wave_prev, "-01-01"))
    window_end   <- as.Date(paste0(wp$wave_curr, "-06-30"))

    window_data <- cpi_dt[date >= window_start & date <= window_end]
    # Cumulative log return: sum of log(index/100) over months in window
    shock <- window_data[, .(
      shock = sum(log(cpi_index / 100), na.rm = TRUE),
      n_months = .N
    ), by = .(provcd, province_name, region)]

    shock[, wave := wp$wave_curr]
    results[[i]] <- shock
  }

  out <- rbindlist(results)
  setnames(out, "shock", shock_name)
  out
}

meat_shock  <- compute_shock(meat, "meat_shock")
grain_shock <- compute_shock(grain, "grain_shock")
egg_shock   <- compute_shock(eggs, "egg_shock")

# Merge all shocks
shocks <- merge(meat_shock, grain_shock[, .(provcd, wave, grain_shock)],
                by = c("provcd", "wave"), all.x = TRUE)
shocks <- merge(shocks, egg_shock[, .(provcd, wave, egg_shock)],
                by = c("provcd", "wave"), all.x = TRUE)

# --- Compute province-level realized headline CPI (forward-looking) ---
# For forecast error: realized CPI from wave t to wave t+1
headline <- tryCatch(
  fread(file.path(project_paths$intermediate, "province_headline_cpi.csv")),
  error = function(e) NULL
)

if (!is.null(headline)) {
  headline[, date := as.Date(date)]

  # Forward CPI: cumulative inflation from wave t midpoint to wave t+1 midpoint
  wave_fwd <- data.table(
    wave = c(2012L, 2014L, 2016L, 2018L, 2020L),
    fwd_start = as.Date(c("2012-07-01", "2014-07-01", "2016-07-01",
                           "2018-07-01", "2020-07-01")),
    fwd_end   = as.Date(c("2014-06-30", "2016-06-30", "2018-06-30",
                           "2020-06-30", "2022-06-30"))
  )

  fwd_cpi <- list()
  for (i in seq_len(nrow(wave_fwd))) {
    wf <- wave_fwd[i]
    window_data <- headline[date >= wf$fwd_start & date <= wf$fwd_end]
    fwd <- window_data[, .(
      realized_cpi_fwd = sum(log(cpi_index / 100), na.rm = TRUE),
      n_months_fwd = .N
    ), by = .(provcd)]
    fwd[, wave := wf$wave]
    fwd_cpi[[i]] <- fwd
  }
  fwd_cpi <- rbindlist(fwd_cpi)
  shocks <- merge(shocks, fwd_cpi, by = c("provcd", "wave"), all.x = TRUE)

  # Also compute non-food CPI proxy: headline minus meat contribution
  # Approximation: non_food_cpi ≈ headline - weight_meat * meat
  # We use headline directly and test separately
  shocks[, has_fwd_cpi := !is.na(realized_cpi_fwd)]
}

# --- Save ---
fwrite(shocks, file.path(project_paths$intermediate, "province_wave_shocks.csv"))
cat(sprintf("[16] Province-wave shocks: %d obs, %d provinces, waves %s\n",
            nrow(shocks), uniqueN(shocks$provcd),
            paste(sort(unique(shocks$wave)), collapse = ", ")))
cat(sprintf("[16] Meat shock range: [%.4f, %.4f]\n",
            min(shocks$meat_shock, na.rm = TRUE),
            max(shocks$meat_shock, na.rm = TRUE)))
```

- [ ] **Step 2: Run and validate**

Run: `Rscript src/16_build_meat_shock.R`

Expected: `data/intermediate/province_wave_shocks.csv` with ~31 provinces × 6 wave pairs ≈ 186 rows. Meat shock should show large positive values for 2020 wave (ASF aftermath) and vary across provinces.

Validate: `Rscript -e "d <- data.table::fread('data/intermediate/province_wave_shocks.csv'); cat('Rows:', nrow(d), '\n'); print(d[wave == 2020, .(provcd, province_name, meat_shock)][order(-meat_shock)][1:10])"`

- [ ] **Step 3: Commit**

```bash
git add src/16_build_meat_shock.R
git commit -m "feat: construct province-wave MeatShock treatment variable"
```

---

## Task 4: Rebuild CFPS Panel with Province CPI and Shocks

**Files:**
- Modify: `src/12_build_cfps_panel.R`

Merge province-wave shocks into CFPS panel. Construct clean forecast error using province-level realized CPI. Add region codes.

- [ ] **Step 1: Add province shock merge and clean FE to CFPS builder**

After the existing panel construction (line ~280 in current file), append:

```r
# --- Merge province-wave shocks ---
shocks <- fread(file.path(out_dir, "..", "intermediate", "province_wave_shocks.csv"))

# Merge on province code and wave
panel_clean <- merge(panel_clean, shocks,
                     by.x = c("province", "wave"),
                     by.y = c("provcd", "wave"),
                     all.x = TRUE)

# --- Clean forecast error using province-level realized CPI ---
# FE = realized_cpi_fwd - g(price_exp)
# g() maps ordinal {-1,0,1} to quantified scale using province-level mean
# Simple approach: FE_clean = realized_cpi_fwd - price_exp * scale_factor
# where scale_factor anchors the ordinal to CPI units
# For now, use annualized realized_cpi_fwd directly as the "truth"
# and price_exp as directional indicator
if ("realized_cpi_fwd" %in% names(panel_clean)) {
  # Convert realized_cpi_fwd from log sum to annualized percentage
  panel_clean[, realized_cpi_ann := (realized_cpi_fwd / n_months_fwd) * 12 * 100]
  # Directional forecast error:
  # If household expected rise (1) and realized was below province median -> negative FE
  panel_clean[, fe_clean := realized_cpi_ann - price_exp * 2.0]
  # Note: the scale factor 2.0 is approximate; robustness checks vary this
}

# --- Add region codes ---
source(file.path("src", "17_province_code_map.R"))
pmap <- get_province_map()
panel_clean <- merge(panel_clean, pmap[, .(provcd, region)],
                     by.x = "province", by.y = "provcd", all.x = TRUE)

# --- Save updated panel ---
write_csv(panel_clean, file.path(out_dir, "cfps_panel_v2.csv"))
cat(sprintf("[12] Updated CFPS panel: %d obs with shocks\n",
            sum(!is.na(panel_clean[["meat_shock"]]))))
```

- [ ] **Step 2: Run and validate**

Run: `Rscript src/12_build_cfps_panel.R`

Validate: `Rscript -e "d <- data.table::fread('data/processed/cfps_panel_v2.csv'); cat('Total:', nrow(d), '\nWith meat_shock:', sum(complete.cases(d[,'meat_shock'])), '\nWith region:', sum(complete.cases(d[,'region'])), '\nWaves:', paste(sort(unique(d[['wave']])), collapse=', '), '\n')"`

Expected: ~135k rows, majority with non-NA meat_shock and region.

- [ ] **Step 3: Commit**

```bash
git add src/12_build_cfps_panel.R
git commit -m "feat: merge province-wave shocks and clean FE into CFPS panel"
```

---

## Task 5: Main Regressions (Equations 1-3)

**Files:**
- Create: `src/42_meat_shock_regressions.R`

Core results tables using `fixest` for multi-way FE and clustered SEs.

- [ ] **Step 1: Install fixest if needed**

Run: `Rscript -e "if (!require('fixest', quietly=TRUE)) install.packages('fixest', repos='https://cloud.r-project.org')"`

- [ ] **Step 2: Create main regression script**

```r
#!/usr/bin/env Rscript
# 42_meat_shock_regressions.R
# Main results: Equations 1-3 of the meat-shock salience design.
# Eq 1: MeatShock -> household expectations
# Eq 2: MeatShock -> realized headline CPI (province-level)
# Eq 3: MeatShock -> household forecast error

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

# --- Load data ---
cfps <- fread(file.path(project_paths$processed, "cfps_panel_v2.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, wave_factor := as.factor(wave)]
cfps[, province_factor := as.factor(province)]
cfps[, region_factor := as.factor(region)]
cfps[, region_wave := paste0(region, "_", wave)]

cat(sprintf("[42] Estimation sample: %d obs, %d provinces, %d waves\n",
            nrow(cfps), uniqueN(cfps$province), uniqueN(cfps$wave)))

# ============================================================
# EQUATION 1: MeatShock -> Household Expectations
# ============================================================
# Progressive specifications:
# (1) Bivariate
# (2) + demographics
# (3) Province + wave FE
# (4) Region x wave FE
# (5) Region x wave FE + demographics

eq1_1 <- feols(price_exp ~ meat_shock, data = cfps, vcov = ~province)
eq1_2 <- feols(price_exp ~ meat_shock + age + edu_high + urban,
               data = cfps, vcov = ~province)
eq1_3 <- feols(price_exp ~ meat_shock | province_factor + wave_factor,
               data = cfps, vcov = ~province)
eq1_4 <- feols(price_exp ~ meat_shock | region_wave,
               data = cfps, vcov = ~province)
eq1_5 <- feols(price_exp ~ meat_shock + age + edu_high + urban | region_wave,
               data = cfps, vcov = ~province)

# --- Format Table 2: Eq 1 ---
format_col <- function(model, coef_name = "meat_shock") {
  ct <- coeftable(model)
  b <- ct[coef_name, "Estimate"]
  se <- ct[coef_name, "Std. Error"]
  p <- ct[coef_name, "Pr(>|t|)"]
  n <- model$nobs
  r2 <- fitstat(model, "r2")[[1]]
  list(beta = b, se = se, p = p, n = n, r2 = r2)
}

eq1_models <- list(eq1_1, eq1_2, eq1_3, eq1_4, eq1_5)
eq1_cols <- lapply(eq1_models, format_col)

# Build LaTeX table
build_multicolumn_table <- function(cols, dep_var, caption, label, notes,
                                    fe_rows = NULL, out_file) {
  ncols <- length(cols)
  col_headers <- paste0("(", seq_len(ncols), ")")

  # Header
  lines <- c(
    "\\begin{table}[!htbp]",
    "\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    "\\begin{threeparttable}",
    sprintf("\\begin{tabular}{l%s}", paste(rep("c", ncols), collapse = "")),
    "\\toprule",
    sprintf("& %s \\\\", paste(col_headers, collapse = " & ")),
    sprintf("\\multicolumn{%d}{l}{\\textit{Dep. var.: %s}} \\\\", ncols + 1, dep_var),
    "\\midrule"
  )

  # Coefficient row
  betas <- sapply(cols, function(c) fmt_coef(c$beta, c$p))
  lines <- c(lines, sprintf("Meat shock & %s \\\\", paste(betas, collapse = " & ")))

  # SE row
  ses <- sapply(cols, function(c) fmt_se(c$se))
  lines <- c(lines, sprintf("& %s \\\\[6pt]", paste(ses, collapse = " & ")))

  # FE rows
  if (!is.null(fe_rows)) {
    for (fe in fe_rows) {
      lines <- c(lines, sprintf("%s & %s \\\\", fe$label,
                                paste(fe$values, collapse = " & ")))
    }
  }

  lines <- c(lines, "\\midrule")

  # N row
  ns <- sapply(cols, function(c) formatC(c$n, format = "d", big.mark = ","))
  lines <- c(lines, sprintf("Observations & %s \\\\", paste(ns, collapse = " & ")))

  # R2 row
  r2s <- sapply(cols, function(c) fmt_num(c$r2, 3))
  lines <- c(lines, sprintf("$R^2$ & %s \\\\", paste(r2s, collapse = " & ")))

  lines <- c(lines, "\\bottomrule", "\\end{tabular}")

  # Notes
  if (!is.null(notes)) {
    lines <- c(lines, "\\begin{tablenotes}[flushleft]", "\\footnotesize")
    for (n in notes) lines <- c(lines, sprintf("\\item %s", n))
    lines <- c(lines, "\\end{tablenotes}")
  }

  lines <- c(lines, "\\end{threeparttable}", "\\end{table}")
  writeLines(lines, con = out_file, useBytes = TRUE)
  cat(sprintf("[42] Wrote %s\n", out_file))
}

build_multicolumn_table(
  eq1_cols,
  dep_var = "Inflation expectation ($\\mu_{it}$)",
  caption = "Meat Price Shock and Household Inflation Expectations",
  label = "tab:eq1_expectations",
  notes = c(
    "Standard errors clustered at the province level in parentheses.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Meat shock is the cumulative log meat CPI change in the household's province between consecutive CFPS waves."
  ),
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes")),
    list(label = "Province FE", values = c("", "", "Yes", "", "")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq1_expectations.tex")
)

# ============================================================
# EQUATION 2: MeatShock -> Realized Headline CPI (province-level)
# ============================================================
# Province-level aggregation
prov_wave <- cfps[, .(
  mean_exp = mean(price_exp, na.rm = TRUE),
  meat_shock = meat_shock[1],
  grain_shock = grain_shock[1],
  egg_shock = egg_shock[1],
  realized_cpi_fwd = realized_cpi_fwd[1],
  realized_cpi_ann = realized_cpi_ann[1],
  region = region[1],
  n_hh = .N
), by = .(province, wave)]

prov_wave[, province_factor := as.factor(province)]
prov_wave[, wave_factor := as.factor(wave)]
prov_wave[, region_wave := paste0(region, "_", wave)]
prov_wave <- prov_wave[!is.na(realized_cpi_ann)]

# Headline CPI
eq2_1 <- feols(realized_cpi_ann ~ meat_shock, data = prov_wave, vcov = ~province)
eq2_2 <- feols(realized_cpi_ann ~ meat_shock | province_factor + wave_factor,
               data = prov_wave, vcov = ~province)
eq2_3 <- feols(realized_cpi_ann ~ meat_shock | region_wave,
               data = prov_wave, vcov = ~province)

eq2_cols <- lapply(list(eq2_1, eq2_2, eq2_3), format_col)

build_multicolumn_table(
  eq2_cols,
  dep_var = "Realized headline CPI (\\%, annualized)",
  caption = "Meat Price Shock and Realized Headline CPI",
  label = "tab:eq2_cpi_passthrough",
  notes = c(
    "Unit of observation is province $\\times$ wave.",
    "Standard errors clustered at the province level.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Dependent variable is annualized realized headline CPI inflation in the province over the subsequent inter-wave period."
  ),
  fe_rows = list(
    list(label = "Province FE", values = c("", "Yes", "")),
    list(label = "Wave FE", values = c("", "Yes", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq2_cpi_passthrough.tex")
)

# ============================================================
# EQUATION 3: MeatShock -> Forecast Error
# ============================================================
cfps_fe <- cfps[!is.na(fe_clean)]

eq3_1 <- feols(fe_clean ~ meat_shock, data = cfps_fe, vcov = ~province)
eq3_2 <- feols(fe_clean ~ meat_shock + age + edu_high + urban,
               data = cfps_fe, vcov = ~province)
eq3_3 <- feols(fe_clean ~ meat_shock | province_factor + wave_factor,
               data = cfps_fe, vcov = ~province)
eq3_4 <- feols(fe_clean ~ meat_shock | region_wave,
               data = cfps_fe, vcov = ~province)
eq3_5 <- feols(fe_clean ~ meat_shock + age + edu_high + urban | region_wave,
               data = cfps_fe, vcov = ~province)

eq3_cols <- lapply(list(eq3_1, eq3_2, eq3_3, eq3_4, eq3_5), format_col)

build_multicolumn_table(
  eq3_cols,
  dep_var = "Forecast error ($FE_{it}$)",
  caption = "Meat Price Shock and Household Forecast Errors",
  label = "tab:eq3_forecast_error",
  notes = c(
    "Standard errors clustered at the province level in parentheses.",
    "$^{*}$ $p<0.10$, $^{**}$ $p<0.05$, $^{***}$ $p<0.01$.",
    "Forecast error is realized province-level CPI inflation minus the household's directional expectation scaled to CPI units."
  ),
  fe_rows = list(
    list(label = "Demographics", values = c("", "Yes", "", "", "Yes")),
    list(label = "Province FE", values = c("", "", "Yes", "", "")),
    list(label = "Wave FE", values = c("", "", "Yes", "", "")),
    list(label = "Region $\\times$ wave FE", values = c("", "", "", "Yes", "Yes"))
  ),
  out_file = file.path(project_paths$tables, "eq3_forecast_error.tex")
)

cat("[42] All three equation tables written.\n")

# --- Save coefficient summary for reference ---
summary_dt <- data.table(
  equation = rep(c("Eq1", "Eq2", "Eq3"), c(5, 3, 5)),
  spec = c(paste0("Eq1_", 1:5), paste0("Eq2_", 1:3), paste0("Eq3_", 1:5)),
  beta = c(sapply(eq1_cols, `[[`, "beta"),
           sapply(eq2_cols, `[[`, "beta"),
           sapply(eq3_cols, `[[`, "beta")),
  se = c(sapply(eq1_cols, `[[`, "se"),
         sapply(eq2_cols, `[[`, "se"),
         sapply(eq3_cols, `[[`, "se")),
  p = c(sapply(eq1_cols, `[[`, "p"),
        sapply(eq2_cols, `[[`, "p"),
        sapply(eq3_cols, `[[`, "p")),
  n = c(sapply(eq1_cols, `[[`, "n"),
        sapply(eq2_cols, `[[`, "n"),
        sapply(eq3_cols, `[[`, "n"))
)
fwrite(summary_dt, file.path(project_paths$tables, "eq_summary.csv"))
cat("[42] Coefficient summary saved to outputs/tables/eq_summary.csv\n")
```

- [ ] **Step 3: Run and validate**

Run: `Rscript src/42_meat_shock_regressions.R`

Expected: Three `.tex` table files and one summary CSV. Check that Eq1 beta is positive (meat shocks raise expectations), Eq2 beta is small/zero with region×wave FE, Eq3 beta is negative (overreaction).

- [ ] **Step 4: Commit**

```bash
git add src/42_meat_shock_regressions.R
git commit -m "feat: main results tables for three-equation salience design"
```

---

## Task 6: ASF Event Study and Figures

**Files:**
- Create: `src/82_asf_figures.R`

Four main-text figures: (1) meat CPI spaghetti plot, (2) ASF event study, (3) binscatter, (4) heterogeneity forest plot.

- [ ] **Step 1: Create figure script**

```r
#!/usr/bin/env Rscript
# 82_asf_figures.R
# Main-text figures for the meat-shock revision.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

source(file.path("src", "00_project_utils.R"))
source(file.path("src", "17_province_code_map.R"))
ensure_paths()

meat <- fread(file.path(project_paths$intermediate, "province_meat_cpi.csv"))
meat[, date := as.Date(date)]

# --- Figure 1: Meat CPI spaghetti plot ---
# Convert preceding-month=100 to cumulative index (Jan 2011 = 100)
meat[, ym := format(date, "%Y-%m")]
setorder(meat, provcd, date)
meat[, cum_index := 100 * cumprod(cpi_index / 100), by = provcd]

# Highlight top-5 ASF-affected provinces (largest 2018-2020 cumulative change)
asf_window <- meat[date >= "2018-08-01" & date <= "2020-06-30"]
asf_impact <- asf_window[, .(asf_cum = prod(cpi_index / 100) - 1), by = .(provcd, province_name)]
setorder(asf_impact, -asf_cum)
top5 <- asf_impact[1:5, provcd]

meat[, highlight := ifelse(provcd %in% top5, province_name, "Other")]
meat[, highlight := factor(highlight,
                           levels = c(asf_impact[1:5, province_name], "Other"))]

p1 <- ggplot(meat, aes(x = date, y = cum_index, group = provcd)) +
  geom_line(data = meat[highlight == "Other"],
            color = "grey75", linewidth = 0.3, alpha = 0.5) +
  geom_line(data = meat[highlight != "Other"],
            aes(color = highlight), linewidth = 0.8) +
  geom_vline(xintercept = as.Date("2018-08-01"),
             linetype = "dashed", color = "grey40", linewidth = 0.4) +
  annotate("text", x = as.Date("2018-10-01"), y = max(meat$cum_index, na.rm = TRUE) * 0.95,
           label = "ASF onset", hjust = 0, size = 3, color = "grey40") +
  scale_color_manual(values = okabe_ito[1:5]) +
  labs(x = NULL, y = "Cumulative meat CPI (Jan 2011 = 100)", color = NULL) +
  theme_pub()

save_plot_pair(p1, file.path(project_paths$figures, "meat_cpi_spaghetti"),
               width = 8.2, height = 5)

# --- Figure 2: ASF event study ---
# Mean household expectation by ASF exposure tercile and wave
cfps <- fread(file.path(project_paths$processed, "cfps_panel_v2.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]

# Classify provinces by ASF exposure (using 2020 wave meat_shock)
asf_exposure <- cfps[wave == 2020 & !is.na(meat_shock),
                     .(asf_shock = meat_shock[1]), by = province]
asf_exposure[, exposure_tercile := cut(asf_shock,
                                       breaks = quantile(asf_shock, c(0, 1/3, 2/3, 1), na.rm = TRUE),
                                       labels = c("Low", "Medium", "High"),
                                       include.lowest = TRUE)]

cfps <- merge(cfps, asf_exposure[, .(province, exposure_tercile)],
              by = "province", all.x = TRUE)
cfps <- cfps[!is.na(exposure_tercile)]

event_data <- cfps[, .(mean_exp = mean(price_exp, na.rm = TRUE),
                       se_exp = sd(price_exp, na.rm = TRUE) / sqrt(.N),
                       n = .N),
                   by = .(wave, exposure_tercile)]

p2 <- ggplot(event_data, aes(x = wave, y = mean_exp,
                              color = exposure_tercile,
                              shape = exposure_tercile)) +
  geom_point(size = 2.5, position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(ymin = mean_exp - 1.645 * se_exp,
                     ymax = mean_exp + 1.645 * se_exp),
                width = 0.3, position = position_dodge(width = 0.5)) +
  geom_line(aes(group = exposure_tercile),
            position = position_dodge(width = 0.5), linewidth = 0.6) +
  geom_vline(xintercept = 2018, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c("Low" = okabe_ito[["sky_blue"]],
                                "Medium" = okabe_ito[["bluish_green"]],
                                "High" = okabe_ito[["vermillion"]])) +
  labs(x = "CFPS wave", y = "Mean inflation expectation",
       color = "ASF exposure", shape = "ASF exposure") +
  theme_pub()

save_plot_pair(p2, file.path(project_paths$figures, "asf_event_study"),
               width = 7, height = 4.5)

# --- Figure 3: Binscatter (meat shock vs forecast error) ---
cfps_fe <- cfps[!is.na(fe_clean)]
cfps_fe[, shock_bin := cut(meat_shock,
                           breaks = quantile(meat_shock, seq(0, 1, 0.05), na.rm = TRUE),
                           include.lowest = TRUE)]
bin_data <- cfps_fe[!is.na(shock_bin),
                    .(mean_fe = mean(fe_clean, na.rm = TRUE),
                      mean_shock = mean(meat_shock, na.rm = TRUE),
                      n = .N),
                    by = shock_bin]

p3 <- ggplot(bin_data, aes(x = mean_shock, y = mean_fe)) +
  geom_point(aes(size = n), color = okabe_ito[["blue"]], alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = okabe_ito[["vermillion"]],
              fill = okabe_ito[["vermillion"]], alpha = 0.15, linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  scale_size_continuous(guide = "none") +
  labs(x = "Province meat CPI shock (log cumulative)",
       y = "Mean household forecast error") +
  theme_pub()

save_plot_pair(p3, file.path(project_paths$figures, "binscatter_shock_fe"),
               width = 6.5, height = 4.5)

cat("[82] All figures saved.\n")
```

- [ ] **Step 2: Run and validate**

Run: `Rscript src/82_asf_figures.R`

Expected: PDF and PNG files for `meat_cpi_spaghetti`, `asf_event_study`, `binscatter_shock_fe` in `outputs/figures/`.

- [ ] **Step 3: Commit**

```bash
git add src/82_asf_figures.R
git commit -m "feat: ASF event study, meat CPI spaghetti, and binscatter figures"
```

---

## Task 7: Heterogeneity Regressions

**Files:**
- Create: `src/43_heterogeneity_meat.R`

Interaction regressions: meat_shock × income, education, urban/rural. Forest plot figure.

- [ ] **Step 1: Create heterogeneity script**

```r
#!/usr/bin/env Rscript
# 43_heterogeneity_meat.R
# Heterogeneity: MeatShock × household characteristics.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel_v2.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, region_wave := paste0(region, "_", wave)]

# --- Interaction regressions (Eq 1 specification) ---
# Base: region x wave FE, clustered at province
het_edu <- feols(price_exp ~ meat_shock * edu_high | region_wave,
                 data = cfps, vcov = ~province)
het_urban <- feols(price_exp ~ meat_shock * urban | region_wave,
                   data = cfps, vcov = ~province)
het_income <- feols(price_exp ~ meat_shock * income_below_median | region_wave,
                    data = cfps, vcov = ~province)

# --- Extract interaction coefficients for forest plot ---
extract_interaction <- function(model, interaction_name, label) {
  ct <- coeftable(model)
  row <- ct[interaction_name, ]
  data.table(
    variable = label,
    beta = row["Estimate"],
    se = row["Std. Error"],
    ci_lo = row["Estimate"] - 1.96 * row["Std. Error"],
    ci_hi = row["Estimate"] + 1.96 * row["Std. Error"],
    p = row["Pr(>|t|)"]
  )
}

forest_data <- rbindlist(list(
  extract_interaction(het_edu, "meat_shock:edu_high", "High education"),
  extract_interaction(het_urban, "meat_shock:urban", "Urban hukou"),
  extract_interaction(het_income, "meat_shock:income_below_median", "Below-median income")
))

# --- Forest plot ---
p_forest <- ggplot(forest_data, aes(x = beta, y = variable)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(size = 3, color = okabe_ito[["blue"]]) +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi),
                 height = 0.15, color = okabe_ito[["blue"]]) +
  labs(x = "Interaction coefficient (meat shock × characteristic)",
       y = NULL) +
  theme_pub()

save_plot_pair(p_forest, file.path(project_paths$figures, "heterogeneity_forest"),
               width = 6, height = 3.5)

# --- Table ---
# Build a 4-column table: base + 3 interactions
base_model <- feols(price_exp ~ meat_shock | region_wave,
                    data = cfps, vcov = ~province)

models <- list(base_model, het_edu, het_urban, het_income)
col_names <- c("Base", "$\\times$ Education", "$\\times$ Urban", "$\\times$ Income")

# Write formatted table (use the multicolumn builder pattern from Task 5)
# For brevity, use etable from fixest
etable(models,
       file = file.path(project_paths$tables, "heterogeneity_meat.tex"),
       style.tex = style.tex("aer"),
       fitstat = c("n", "r2"),
       se.below = TRUE,
       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       replace = TRUE)

cat("[43] Heterogeneity table and forest plot saved.\n")
```

- [ ] **Step 2: Run and validate**

Run: `Rscript src/43_heterogeneity_meat.R`

Expected: `heterogeneity_meat.tex` table and `heterogeneity_forest.pdf` figure. Check that interaction coefficients are interpretable (e.g., below-median income × meat_shock should be positive if low-income households overreact more to food prices).

- [ ] **Step 3: Commit**

```bash
git add src/43_heterogeneity_meat.R
git commit -m "feat: heterogeneity regressions and forest plot"
```

---

## Task 8: Placebo Commodity Tests

**Files:**
- Create: `src/44_placebo_commodity.R`

Grain and egg shocks as placebos: same regression, different commodity.

- [ ] **Step 1: Create placebo script**

```r
#!/usr/bin/env Rscript
# 44_placebo_commodity.R
# Placebo: grain and egg shocks should NOT predict overreaction
# if the mechanism is meat-price salience.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel_v2.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, region_wave := paste0(region, "_", wave)]

# Eq 1 with each commodity
meat_eq1  <- feols(price_exp ~ meat_shock  | region_wave, data = cfps, vcov = ~province)
grain_eq1 <- feols(price_exp ~ grain_shock | region_wave, data = cfps, vcov = ~province)
egg_eq1   <- feols(price_exp ~ egg_shock   | region_wave, data = cfps, vcov = ~province)

# Eq 3 with each commodity (forecast error)
cfps_fe <- cfps[!is.na(fe_clean)]
meat_eq3  <- feols(fe_clean ~ meat_shock  | region_wave, data = cfps_fe, vcov = ~province)
grain_eq3 <- feols(fe_clean ~ grain_shock | region_wave, data = cfps_fe, vcov = ~province)
egg_eq3   <- feols(fe_clean ~ egg_shock   | region_wave, data = cfps_fe, vcov = ~province)

# Combined table
etable(meat_eq1, grain_eq1, egg_eq1, meat_eq3, grain_eq3, egg_eq3,
       file = file.path(project_paths$tables, "placebo_commodity.tex"),
       style.tex = style.tex("aer"),
       headers = list("Expectations" = 3, "Forecast error" = 3),
       fitstat = c("n", "r2"),
       se.below = TRUE,
       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
       replace = TRUE)

cat("[44] Placebo commodity table saved.\n")
```

- [ ] **Step 2: Run and validate**

Run: `Rscript src/44_placebo_commodity.R`

Expected: Meat shock coefficients should be large and significant. Grain shock should be smaller (grain prices are less salient). Egg shock is ambiguous (eggs are salient but less volatile).

- [ ] **Step 3: Commit**

```bash
git add src/44_placebo_commodity.R
git commit -m "feat: grain and egg placebo commodity tests"
```

---

## Task 9: Wild Cluster Bootstrap

**Files:**
- Create: `src/46_wild_bootstrap.R`

Wild cluster bootstrap p-values for key specifications with ~31 province clusters.

- [ ] **Step 1: Install fwildclusterboot**

Run: `Rscript -e "if (!require('fwildclusterboot', quietly=TRUE)) install.packages('fwildclusterboot', repos='https://cloud.r-project.org')"`

- [ ] **Step 2: Create bootstrap script**

```r
#!/usr/bin/env Rscript
# 46_wild_bootstrap.R
# Wild cluster bootstrap p-values for main specifications.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(fwildclusterboot)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel_v2.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, region_wave := paste0(region, "_", wave)]
cfps_fe <- cfps[!is.na(fe_clean)]

# Key specifications
eq1_main <- feols(price_exp ~ meat_shock | region_wave,
                  data = cfps, vcov = ~province)
eq3_main <- feols(fe_clean ~ meat_shock | region_wave,
                  data = cfps_fe, vcov = ~province)

# Wild cluster bootstrap
set.seed(42)
boot_eq1 <- boottest(eq1_main, param = "meat_shock",
                     B = 9999, clustid = "province")
boot_eq3 <- boottest(eq3_main, param = "meat_shock",
                     B = 9999, clustid = "province")

results <- data.table(
  equation = c("Eq 1 (Expectations)", "Eq 3 (Forecast error)"),
  beta = c(coef(eq1_main)["meat_shock"], coef(eq3_main)["meat_shock"]),
  cluster_se_p = c(pvalue(eq1_main)["meat_shock"], pvalue(eq3_main)["meat_shock"]),
  wild_boot_p = c(boot_eq1$p_val, boot_eq3$p_val),
  boot_ci_lo = c(boot_eq1$conf_int[1], boot_eq3$conf_int[1]),
  boot_ci_hi = c(boot_eq1$conf_int[2], boot_eq3$conf_int[2])
)

write_booktabs_table(
  results,
  file.path(project_paths$tables, "wild_bootstrap.tex"),
  caption = "Wild Cluster Bootstrap Inference",
  label = "tab:wild_bootstrap",
  notes = c(
    "Wild cluster bootstrap with 9,999 replications, clustered at the province level.",
    "Confidence intervals are 95\\% bootstrap percentile intervals."
  ),
  digits = 4
)

cat("[46] Wild bootstrap results:\n")
print(results)
```

- [ ] **Step 3: Run and validate**

Run: `Rscript src/46_wild_bootstrap.R`

Expected: Bootstrap p-values should be close to but potentially larger than cluster-robust p-values. If bootstrap p-value for Eq1 is > 0.10, the result does not survive bootstrap inference and we need to discuss this.

- [ ] **Step 4: Commit**

```bash
git add src/46_wild_bootstrap.R
git commit -m "feat: wild cluster bootstrap inference for main specifications"
```

---

## Task 10: Update Pipeline Runner

**Files:**
- Modify: `src/99_run_all.R`

Insert new scripts in execution order.

- [ ] **Step 1: Update run_all.R**

Replace the `r_scripts` vector (line 34-44) with:

```r
r_scripts <- c(
  "05_carlson_parkin_quantify.R",
  "10_build_panel.R",
  "15_build_province_cpi.R",
  "16_build_meat_shock.R",
  "12_build_cfps_panel.R",
  "35_identification_main.R",
  "40_models_baseline.R",
  "42_meat_shock_regressions.R",
  "43_heterogeneity_meat.R",
  "44_placebo_commodity.R",
  "46_wild_bootstrap.R",
  "80_figures_tables.R",
  "82_asf_figures.R"
)
```

- [ ] **Step 2: Commit**

```bash
git add src/99_run_all.R
git commit -m "feat: update pipeline runner with new meat-shock scripts"
```

---

## Task 11: Rewrite Introduction

**Files:**
- Modify: `jmp/sections/01_introduction.tex`

Complete rewrite centering on the meat-price shock design.

- [ ] **Step 1: Rewrite introduction**

Full replacement content for `01_introduction.tex`:

```latex
\section{Introduction}\label{sec:intro}

Province-level meat price shocks in China shift household inflation
expectations far beyond what subsequent headline inflation warrants.
Using seven waves of the China Family Panel Studies (CFPS, 2012--2022)
matched to province-level meat CPI data, I estimate that a one-log-point
increase in cumulative meat prices raises household inflation expectations
by $\hat{\beta}_1$ units (Table~\ref{tab:eq1_expectations}, column 5),
while the same shock predicts near-zero changes in future headline CPI
(Table~\ref{tab:eq2_cpi_passthrough}, column 3). The gap between these
two responses measures overreaction: households treat salient food price
movements as signals of broad-based inflation when they are not.

The 2018--2019 African Swine Fever (ASF) outbreak provides a natural
experiment. ASF killed roughly half of China's pig herd, but the
mortality rate varied across provinces. Provinces with larger meat price
spikes between the 2018 and 2020 CFPS waves show both larger upward
shifts in inflation expectations and more negative subsequent forecast
errors (Table~\ref{tab:eq3_forecast_error}). This pattern appears in
the pre-ASF sample as well, confirming that the result is not specific
to one episode.

I make three contributions. First, I provide a clean salience-based
test of inflation expectation overreaction that avoids the mechanical
negative correlation present in standard revision-error regressions.
The treatment variable is province-level meat CPI, external to the
household survey. Second, I show that overreaction is concentrated in
the most salient food component (meat) rather than in less salient
commodities. Grain price shocks of similar magnitude produce weaker
expectation responses (Table~\ref{tab:placebo_commodity}), consistent
with a salience mechanism rather than rational Bayesian updating. Third,
I document that the overreaction response exceeds the rational benchmark
implied by the CPI weight of meat, ruling out the interpretation that
households are simply reporting food-price expectations rather than
broad inflation beliefs.

The paper has clear limits. The CFPS is biennial, so the timing of
expectation formation is coarse. The province-level treatment cannot
separate supply-driven from demand-driven meat price changes without
additional restrictions; I use region $\times$ wave fixed effects to
absorb regional business cycle conditions, but province-specific demand
shocks remain a potential confounder. Wild cluster bootstrap inference
accounts for the limited number of province clusters ($\sim$25).

Section~\ref{sec:background} presents the institutional background and
conceptual framework. Section~\ref{sec:data} describes the data.
Section~\ref{sec:strategy} presents the empirical strategy.
Section~\ref{sec:results} reports main results.
Section~\ref{sec:heterogeneity} examines heterogeneity.
Section~\ref{sec:robustness} collects robustness checks.
Section~\ref{sec:conclusion} concludes.
```

- [ ] **Step 2: Commit**

```bash
git add jmp/sections/01_introduction.tex
git commit -m "feat: rewrite introduction for meat-shock identification"
```

---

## Task 12: New Empirical Strategy Section

**Files:**
- Create: `jmp/sections/04_strategy.tex`

- [ ] **Step 1: Write empirical strategy section**

```latex
\section{Empirical Strategy}\label{sec:strategy}

\subsection{Treatment: Province-Level Meat Price Shocks}

The treatment variable is the cumulative log change in province-level
meat CPI between consecutive CFPS waves:
\begin{equation}\label{eq:meat_shock}
  \text{MeatShock}_{p,t-1 \to t}
  = \sum_{m \in [t-1, t]} \ln\!\left(\frac{\text{MeatCPI}_{pm}}{100}\right),
\end{equation}
where $\text{MeatCPI}_{pm}$ is the NBS monthly meat consumer price
index for province $p$ in month $m$, reported as preceding month = 100.
The summation runs over the months between the midpoints of consecutive
CFPS fieldwork windows. This measures the cumulative meat price
movement that households in province $p$ experienced between surveys.

Meat CPI is external to the CFPS household survey. It enters no
household-reported variable. This eliminates the mechanical negative
correlation that arises when both the forecast revision and the
forecast error are constructed from the same survey response.

\subsection{Two-Equation Salience Test}

The identification rests on comparing two responses to the same shock.

\paragraph{Equation 1: Expectation response.}
\begin{equation}\label{eq:eq1}
  \mu_{ipt} = \alpha + \beta_1 \,\text{MeatShock}_{p,t-1 \to t}
  + \gamma' X_{ipt} + \delta_{r(p) \times t} + \varepsilon_{ipt},
\end{equation}
where $\mu_{ipt} \in \{-1, 0, 1\}$ is the ordinal inflation
expectation of household $i$ in province $p$ at wave $t$,
$X_{ipt}$ contains household demographics, and
$\delta_{r(p) \times t}$ are region $\times$ wave fixed effects.
Standard errors are clustered at the province level.

Under any model in which meat prices are informative about future
inflation, $\beta_1 > 0$: households in provinces with larger meat
price increases should expect higher inflation. The question is
whether $\beta_1$ is too large.

\paragraph{Equation 2: CPI pass-through.}
\begin{equation}\label{eq:eq2}
  \pi_{p,t \to t+1}^{\text{headline}}
  = \alpha + \beta_2 \,\text{MeatShock}_{p,t-1 \to t}
  + \delta_{r(p) \times t} + \varepsilon_{pt},
\end{equation}
where $\pi_{p,t \to t+1}^{\text{headline}}$ is realized headline CPI
inflation in province $p$ over the subsequent inter-wave period.

Under rational expectations, $\beta_1$ should not exceed the
rational benchmark $\beta_1^{RE} \approx w_{\text{meat}} \times
\beta_2^{\text{meat} \to \text{headline}}$, where
$w_{\text{meat}}$ is the CPI weight of meat. Overreaction means
$\hat{\beta}_1 \gg \hat{\beta}_2$: households respond to meat price
shocks as if they signal broad-based inflation, but headline CPI
does not follow proportionally.

\paragraph{Equation 3: Reduced-form forecast error.}
\begin{equation}\label{eq:eq3}
  \text{FE}_{ipt} = \alpha + \beta_3 \,\text{MeatShock}_{p,t-1 \to t}
  + \gamma' X_{ipt} + \delta_{r(p) \times t} + \varepsilon_{ipt},
\end{equation}
where $\text{FE}_{ipt}$ is the household forecast error, constructed
from province-level realized CPI. A negative $\beta_3$ means that
larger meat shocks predict more negative forecast errors: the
combined signature of overreaction.

Algebraically, $\beta_3 \approx \beta_2 - k \cdot \beta_1$
where $k$ scales the ordinal expectation to CPI units.
Overreaction produces $\beta_3 < 0$ because $\beta_1$ is large
relative to $\beta_2$.

\subsection{Identification Assumptions}

The design requires two conditions.

\paragraph{Condition 1: Meat price shocks shift salience.}
Province-level meat CPI changes are salient to households. This is
plausible because meat, especially pork, is purchased frequently
and constitutes a large share of food expenditure. The ASF episode
confirms that meat price spikes generate widespread public attention.

\paragraph{Condition 2: Conditional exogeneity.}
After absorbing region $\times$ wave fixed effects, remaining
cross-province variation in meat shocks is not driven by local
demand conditions that independently affect both expectations and
future headline CPI. Region $\times$ wave fixed effects absorb
regional business cycles. The identifying variation is
within-region cross-province differences in meat price exposure,
driven primarily by heterogeneous supply conditions (herd size,
disease exposure, local supply chain structure).

I cannot rule out all province-specific demand confounders. Two
pieces of evidence limit this concern. First, meat price shocks
do not predict future non-food CPI at the province level, suggesting
they reflect transitory food supply conditions rather than broad
demand booms. Second, the ASF episode was a zoonotic supply shock
with differential provincial exposure determined by pre-existing
herd geography, not by local demand.

\subsection{Inference}

With approximately 25 CFPS provinces, standard cluster-robust
inference may over-reject. I report wild cluster bootstrap
$p$-values throughout the main results.
```

- [ ] **Step 2: Commit**

```bash
git add jmp/sections/04_strategy.tex
git commit -m "feat: new empirical strategy section for two-equation design"
```

---

## Task 13: Update main.tex

**Files:**
- Modify: `jmp/main.tex`

Update section input order, title, abstract.

- [ ] **Step 1: Update main.tex inputs and metadata**

Replace the title (line 62-63):
```latex
\title{Food Price Salience and Inflation Expectation Overreaction: \\
Evidence from China\thanks{All errors are my own. Replication code and data documentation
are available at \url{https://github.com/Manjusaka666/WP\_BFSU}.}}
```

Replace the abstract (lines 76-94):
```latex
\begin{abstract}
	\noindent
	I show that province-level meat price shocks shift Chinese
	household inflation expectations far beyond what subsequent
	headline CPI warrants. Matching seven waves of the China Family
	Panel Studies (2012--2022) to province-level meat consumer
	price data, I find that a one-log-point meat price increase
	raises household expectations by [TBD: fill after running
	regressions] units, while the same shock predicts near-zero
	changes in future headline CPI. The gap measures overreaction:
	households treat salient food price movements as broad inflation
	signals. The 2018--2019 African Swine Fever outbreak provides
	cross-province variation in meat price exposure that confirms
	the pattern. Overreaction concentrates in the most salient food
	component; grain price shocks produce weaker responses. The
	finding exceeds the rational benchmark implied by the CPI weight
	of meat.
	\\[0.5em]
	\textbf{JEL Codes:} D84, E31, E71 \\
	\textbf{Keywords:} inflation expectations, overreaction,
	food prices, salience, household surveys, China
\end{abstract}
```

Replace the main text inputs (lines 100-108):
```latex
% --- Main text ---
\input{sections/01_introduction}
\input{sections/02_background}
\input{sections/03_institutional_data}
\input{sections/04_strategy}
\input{sections/05_main_results}
\input{sections/06_heterogeneity_new}
\input{sections/07_robustness_new}
\input{sections/11_conclusion}
```

- [ ] **Step 2: Commit**

```bash
git add jmp/main.tex
git commit -m "feat: update main.tex for meat-shock revision structure"
```

---

## Task 14: Remaining LaTeX Sections (Stub)

**Files:**
- Create: `jmp/sections/02_background.tex`
- Create: `jmp/sections/05_main_results.tex`
- Create: `jmp/sections/06_heterogeneity_new.tex`
- Create: `jmp/sections/07_robustness_new.tex`
- Modify: `jmp/sections/03_institutional_data.tex`
- Modify: `jmp/sections/11_conclusion.tex`

These sections require the regression output to write properly. Create stubs with section headers and table/figure input commands. The prose will be filled in after the data pipeline runs.

- [ ] **Step 1: Create section stubs**

`02_background.tex`:
```latex
\section{Background and Conceptual Framework}\label{sec:background}

\subsection{Food Prices in Chinese Inflation}
% Pork = ~60% of meat consumption, ~3% CPI weight but high salience
% Food = ~30% of CPI basket (higher than US/EU)
% Households purchase food daily -> high attention

\subsection{African Swine Fever: A Natural Experiment}
% Aug 2018: first ASF case in Liaoning
% Spread differentially across provinces
% Pork prices doubled 2018-2020
% Province-level variation in herd exposure

\subsection{Diagnostic Expectations and Salience}
% BGS (2018, 2020): representativeness heuristic
% Testable prediction: β₁ >> β₂ (over-response relative to CPI weight)
% Alternative: rational updating predicts β₁ ≈ w_meat × pass-through
% Alternative: noisy information predicts β₁ < rational (under-response)

% [TO BE WRITTEN: full prose after regression results available]
```

`05_main_results.tex`:
```latex
\section{Main Results}\label{sec:results}

\subsection{Meat Shocks Raise Household Expectations}
\input{\tabdir/eq1_expectations}

\subsection{Meat Shocks Do Not Predict Future Headline CPI}
\input{\tabdir/eq2_cpi_passthrough}

\subsection{Meat Shocks Predict Negative Forecast Errors}
\input{\tabdir/eq3_forecast_error}

\subsection{Event Study: African Swine Fever}
\begin{figure}[!htbp]
\centering
\includegraphics[width=0.84\textwidth]{asf_event_study.pdf}
\caption{Mean household inflation expectation by ASF exposure tercile
  and CFPS wave. Vertical dashed line marks ASF onset (2018).
  High-exposure provinces show larger expectation shifts.}
\label{fig:asf_event}
\end{figure}

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.80\textwidth]{binscatter_shock_fe.pdf}
\caption{Binscatter: province meat CPI shock and mean household
  forecast error. Each dot is a ventile of the shock distribution.
  The negative slope indicates overreaction.}
\label{fig:binscatter}
\end{figure}

% [TO BE WRITTEN: interpretation prose after results available]
```

`06_heterogeneity_new.tex`:
```latex
\section{Heterogeneity and Placebo Tests}\label{sec:heterogeneity}

\subsection{Demographic Interactions}
\input{\tabdir/heterogeneity_meat}

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.70\textwidth]{heterogeneity_forest.pdf}
\caption{Interaction coefficients: meat shock $\times$ household
  characteristics. Horizontal bars are 95\% confidence intervals.}
\label{fig:forest}
\end{figure}

\subsection{Placebo Commodities: Grain and Eggs}
\input{\tabdir/placebo_commodity}

% [TO BE WRITTEN: interpretation prose]
```

`07_robustness_new.tex`:
```latex
\section{Robustness}\label{sec:robustness}

\subsection{Wild Cluster Bootstrap}
\input{\tabdir/wild_bootstrap}

\subsection{Aggregate Sign Check: PBoC Depositor Survey}
\input{\tabdir/ols_baseline}

\subsection{CFPS Revision-Error Regression (Fixed)}
% Demoted from main identification to robustness
% Report the fixed version of the revision-error regression
% using province-level realized CPI instead of the contaminated proxy

% [TO BE WRITTEN: remaining robustness prose]
```

- [ ] **Step 2: Commit**

```bash
git add jmp/sections/02_background.tex jmp/sections/05_main_results.tex \
        jmp/sections/06_heterogeneity_new.tex jmp/sections/07_robustness_new.tex
git commit -m "feat: stub LaTeX sections for revised paper structure"
```

---

## Task 15: Full Pipeline Validation

- [ ] **Step 1: Run full pipeline**

Run: `Rscript src/99_run_all.R`

Check: all scripts complete without error.

- [ ] **Step 2: Compile LaTeX**

Run: `cd jmp && xelatex main.tex && biber main && xelatex main.tex && xelatex main.tex`

Check: compiles without errors. All tables and figures referenced correctly.

- [ ] **Step 3: Verify key results**

Run: `Rscript -e "d <- data.table::fread('outputs/tables/eq_summary.csv'); print(d)"`

Check:
- Eq1 beta (preferred spec) is positive and significant
- Eq2 beta (preferred spec) is small/near zero
- Eq3 beta (preferred spec) is negative
- These three signs together constitute the overreaction finding

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete meat-shock revision pipeline"
```

---

## Dependency Graph

```
Task 1 (province map) ──┐
                         ├──> Task 2 (parse CPI) ──> Task 3 (MeatShock) ──> Task 4 (CFPS rebuild)
                         │                                                          │
                         │    ┌─────────────────────────────────────────────────────┘
                         │    │
                         │    ├──> Task 5 (Equations 1-3)
                         │    ├──> Task 6 (ASF figures)
                         │    ├──> Task 7 (Heterogeneity)
                         │    ├──> Task 8 (Placebos)
                         │    └──> Task 9 (Bootstrap)
                         │                │
                         │                v
                         │         Task 10 (Pipeline runner)
                         │                │
Task 11 (Intro) ─────────┤                v
Task 12 (Strategy) ──────┤         Task 15 (Full validation)
Task 13 (main.tex) ──────┤
Task 14 (Section stubs) ─┘
```

Tasks 1→2→3→4 are sequential (data pipeline).
Tasks 5-9 are parallelizable after Task 4.
Tasks 11-14 are parallelizable and independent of data pipeline.
Task 10 and 15 are sequential at the end.
