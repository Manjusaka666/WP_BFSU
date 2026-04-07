#!/usr/bin/env Rscript
# ============================================================
# 16_build_meat_shock.R
# Build province x wave-pair CPI treatment shocks for CFPS:
# meat_shock, grain_shock, egg_shock and forward headline CPI.
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
})

# Force English month handling on non-English locales.
invisible(Sys.setlocale("LC_TIME", "C"))

source(file.path("src", "00_project_utils.R"))
source(file.path("src", "17_province_code_map.R"))
ensure_paths()

in_dir <- project_paths$intermediate
out_file <- file.path(project_paths$intermediate, "province_wave_shocks.csv")

required_files <- c(
  file.path(in_dir, "province_meat_cpi.csv"),
  file.path(in_dir, "province_grain_cpi.csv"),
  file.path(in_dir, "province_eggs_cpi.csv"),
  file.path(in_dir, "province_headline_cpi.csv")
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Missing required input files:\n  ", paste(missing_files, collapse = "\n  "))
}

read_province_cpi <- function(path) {
  dt <- fread(path)
  needed <- c("provcd", "province_name", "region", "date", "cpi_index")
  miss <- setdiff(needed, names(dt))
  if (length(miss) > 0) {
    stop("Missing columns in ", basename(path), ": ", paste(miss, collapse = ", "))
  }
  dt[, provcd := as.integer(provcd)]
  dt[, date := as.IDate(date)]
  dt[, cpi_index := as.numeric(cpi_index)]
  dt <- dt[!is.na(provcd) & !is.na(date)]
  setkey(dt, provcd, date)
  dt
}

meat_dt <- read_province_cpi(file.path(in_dir, "province_meat_cpi.csv"))
grain_dt <- read_province_cpi(file.path(in_dir, "province_grain_cpi.csv"))
egg_dt <- read_province_cpi(file.path(in_dir, "province_eggs_cpi.csv"))
headline_dt <- read_province_cpi(file.path(in_dir, "province_headline_cpi.csv"))

waves <- c(2010L, 2012L, 2014L, 2016L, 2018L, 2020L, 2022L)
wave_pairs <- data.table(
  prev_wave = waves[-length(waves)],
  wave = waves[-1L]
)
wave_pairs[, pair_id := .I]
wave_pairs[, wave_pair := sprintf("%d_%d", prev_wave, wave)]

provinces <- get_province_map()[, .(
  provcd = as.integer(provcd),
  province_name = name_en,
  region
)]
setorder(provinces, provcd)

base <- CJ(provcd = provinces$provcd, pair_id = wave_pairs$pair_id, unique = TRUE)
base <- merge(base, provinces, by = "provcd", all.x = TRUE, sort = FALSE)
base <- merge(base, wave_pairs, by = "pair_id", all.x = TRUE, sort = FALSE)
setorder(base, provcd, pair_id)

# Shock window: Jan(prev_wave) to Jun(wave)
base[, shock_start := as.IDate(sprintf("%d-01-01", prev_wave))]
base[, shock_end := as.IDate(sprintf("%d-06-01", wave))]

# Forward realized headline CPI window:
# Jul(wave) to Jun(next_wave). This is the CPI realization AFTER the survey,
# which is what a household surveyed at wave t is trying to predict.
next_wave_map <- data.table(
  wave = c(2012L, 2014L, 2016L, 2018L, 2020L),
  next_wave = c(2014L, 2016L, 2018L, 2020L, 2022L)
)
base <- merge(base, next_wave_map, by = "wave", all.x = TRUE)
base[, forward_start := as.IDate(sprintf("%d-07-01", wave))]
base[, forward_end := fifelse(!is.na(next_wave),
                               as.IDate(sprintf("%d-06-01", next_wave)),
                               as.IDate(NA))]

cum_log_index <- function(cpi_dt, windows_dt, start_col, end_col) {
  vapply(seq_len(nrow(windows_dt)), function(i) {
    vals <- cpi_dt[
      provcd == windows_dt$provcd[i] &
        date >= windows_dt[[start_col]][i] &
        date <= windows_dt[[end_col]][i],
      cpi_index
    ]
    if (length(vals) == 0L || all(is.na(vals))) {
      return(NA_real_)
    }
    sum(log(vals / 100), na.rm = TRUE)
  }, numeric(1))
}

base[, meat_shock := cum_log_index(meat_dt, base, "shock_start", "shock_end")]
base[, grain_shock := cum_log_index(grain_dt, base, "shock_start", "shock_end")]
base[, egg_shock := cum_log_index(egg_dt, base, "shock_start", "shock_end")]
base[, headline_cpi_next := cum_log_index(headline_dt, base, "forward_start", "forward_end")]

out <- base[, .(
  provcd,
  province_name,
  region,
  prev_wave,
  wave,
  wave_pair,
  meat_shock,
  grain_shock,
  egg_shock,
  headline_cpi_next
)]
setorder(out, provcd, wave)

fwrite(out, out_file)

cat(sprintf("[16] Output written: %s\n", out_file))
cat(sprintf("[16] Rows: %d | Provinces: %d | Wave pairs: %d\n",
            nrow(out), uniqueN(out$provcd), uniqueN(out$wave_pair)))

safe_stat <- function(x, fun) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  fun(x, na.rm = TRUE)
}

cat("\n[16] Meat shock summary by wave:\n")
print(out[, .(
  n_non_missing = sum(!is.na(meat_shock)),
  mean = safe_stat(meat_shock, mean),
  sd = safe_stat(meat_shock, sd),
  min = safe_stat(meat_shock, min),
  max = safe_stat(meat_shock, max)
), by = wave])

if (out[wave == 2020L, sum(!is.na(meat_shock))] > 0L) {
  w2020 <- out[wave == 2020L]
  cat(sprintf("\n[16] Wave 2020 meat_shock mean: %.4f, median: %.4f, min: %.4f, max: %.4f\n",
              mean(w2020$meat_shock, na.rm = TRUE),
              median(w2020$meat_shock, na.rm = TRUE),
              min(w2020$meat_shock, na.rm = TRUE),
              max(w2020$meat_shock, na.rm = TRUE)))
}
