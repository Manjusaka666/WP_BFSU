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

# Force English month-name parsing (e.g., "Dec 2025") on non-English system locales.
invisible(Sys.setlocale("LC_TIME", "C"))

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

  # Drop rows with missing dates or values (trailing empty columns)
  dt_long <- dt_long[!is.na(date) & !is.na(cpi_index)]

  # Resolve province name aliases (Xizang -> Tibet etc.)
  dt_long[, province_name := resolve_province_name(province_name)]

  # Add province code
  pmap <- get_province_map()
  dt_long <- merge(dt_long, pmap[, .(name_en, provcd, region)],
                   by.x = "province_name", by.y = "name_en", all.x = TRUE)

  # Warn about unmatched provinces
  unmatched <- dt_long[is.na(provcd), unique(province_name)]
  if (length(unmatched) > 0) {
    message(sprintf("[15] WARNING: unmatched province names in %s: %s",
                    commodity_label, paste(unmatched, collapse = ", ")))
  }

  dt_long[!is.na(provcd), .(provcd, province_name, region, date, commodity, cpi_index)]
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
cat(sprintf("[15] Grain CPI: %d obs, %d provinces, %s to %s\n",
            nrow(grain), uniqueN(grain$provcd),
            min(grain$date), max(grain$date)))
cat(sprintf("[15] Eggs CPI: %d obs, %d provinces, %s to %s\n",
            nrow(eggs), uniqueN(eggs$provcd),
            min(eggs$date), max(eggs$date)))

# --- Parse headline CPI Excel files ---
excel_files <- sort(list.files(project_paths$raw,
                               pattern = "CPI_Monthly By Province.*\\.xlsx$",
                               full.names = TRUE))

parse_headline_excel <- function(filepath) {
  invisible(Sys.setlocale("LC_TIME", "C"))

  # Read Excel: skip first 3 metadata rows, row 4 = "Region, Dec YYYY, ..."
  dt <- as.data.table(read_excel(filepath, skip = 3))
  prov_col <- names(dt)[1]
  setnames(dt, prov_col, "province_name")

  # Keep only province data rows (drop footnotes, "National" total, etc.)
  pmap <- get_province_map()
  all_names <- c(pmap$name_en, province_aliases$alias)
  dt <- dt[province_name %in% all_names]

  month_cols <- setdiff(names(dt), "province_name")
  dt_long <- melt(dt, id.vars = "province_name",
                  variable.name = "month_label",
                  value.name = "cpi_index")
  dt_long[, month_label := as.character(month_label)]
  dt_long[, date := as.Date(paste0("01 ", month_label), format = "%d %b %Y")]
  dt_long[, cpi_index := as.numeric(cpi_index)]
  dt_long <- dt_long[!is.na(date) & !is.na(cpi_index)]

  # Resolve aliases
  dt_long[, province_name := resolve_province_name(province_name)]

  dt_long <- merge(dt_long, pmap[, .(name_en, provcd, region)],
                   by.x = "province_name", by.y = "name_en", all.x = TRUE)
  dt_long[, commodity := "headline"]

  unmatched <- dt_long[is.na(provcd), unique(province_name)]
  if (length(unmatched) > 0) {
    message(sprintf("[15] WARNING: unmatched provinces in headline (%s): %s",
                    basename(filepath), paste(unmatched, collapse = ", ")))
  }

  dt_long[!is.na(provcd), .(provcd, province_name, region, date, commodity, cpi_index)]
}

headline_list <- lapply(excel_files, function(f) {
  tryCatch(parse_headline_excel(f), error = function(e) {
    message(sprintf("[15] WARNING: could not parse %s: %s", basename(f), e$message))
    NULL
  })
})
headline_list <- headline_list[!vapply(headline_list, is.null, logical(1))]
headline <- rbindlist(headline_list)

if (nrow(headline) > 0) {
  fwrite(headline, file.path(project_paths$intermediate, "province_headline_cpi.csv"))
  cat(sprintf("[15] Headline CPI: %d obs, %d provinces, %s to %s\n",
              nrow(headline), uniqueN(headline$provcd),
              min(headline$date), max(headline$date)))
} else {
  cat("[15] WARNING: headline CPI parsing returned 0 rows. Check Excel format.\n")
}

cat("[15] Province CPI parsing complete.\n")
