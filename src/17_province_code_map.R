#!/usr/bin/env Rscript
# 17_province_code_map.R
# Province name <-> GB/T 2260 code mapping + macro-region assignment.
# Shared lookup used by CPI parsing and CFPS panel construction.

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

# Alias lookup for NBS name variants
province_aliases <- data.table(
  alias = c("Xizang", "Neimenggu", "Inner Mongolia Autonomous Region"),
  name_en = c("Tibet", "Inner Mongolia", "Inner Mongolia")
)

get_province_map <- function() {
  copy(province_map)
}

# Resolve NBS province names (handles Xizang/Tibet etc.)
resolve_province_name <- function(names_vec) {
  out <- names_vec
  for (i in seq_len(nrow(province_aliases))) {
    out[out == province_aliases$alias[i]] <- province_aliases$name_en[i]
  }
  out
}
