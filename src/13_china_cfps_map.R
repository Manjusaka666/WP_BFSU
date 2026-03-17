##############################################################
# 13_china_cfps_map.R
# Produces Figure: China province map with CFPS coverage
# and PBoC survey city locations.
# Output: outputs/figures/china_cfps_map.pdf
##############################################################

library(sf)
library(ggplot2)
library(dplyr)
library(RColorBrewer)

# ---- 1. Get China province boundaries --------------------------
# Uses rnaturalearth (level=1 gives provinces)
if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
  install.packages("rnaturalearth")
}
if (!requireNamespace("rnaturalearthdata", quietly = TRUE)) {
  install.packages("rnaturalearthdata")
}
library(rnaturalearth)
library(rnaturalearthdata)

china_prov <- ne_states(country = "China", returnclass = "sf")

# ---- 2. CFPS province coverage ---------------------------------
# CFPS 2010 baseline: 25 provinces covering ~95% of population.
# The survey excludes: Tibet, Xinjiang, Qinghai, Ningxia,
# Inner Mongolia, and Hainan (approximately).
cfps_covered <- c(
  "Beijing", "Tianjin", "Hebei", "Shanxi", "Liaoning",
  "Jilin", "Heilongjiang", "Shanghai", "Jiangsu", "Zhejiang",
  "Anhui", "Fujian", "Jiangxi", "Shandong", "Henan",
  "Hubei", "Hunan", "Guangdong", "Chongqing", "Sichuan",
  "Guizhou", "Yunnan", "Shaanxi", "Gansu", "Gansu"
)
# Deduplicate
cfps_covered <- unique(cfps_covered)

# Match names to Natural Earth spelling
china_prov <- china_prov %>%
  mutate(
    cfps = case_when(
      name %in% c(
        "Beijing", "Tianjin", "Hebei", "Shanxi", "Liaoning",
        "Jilin", "Heilongjiang", "Shanghai", "Jiangsu",
        "Zhejiang", "Anhui", "Fujian", "Jiangxi", "Shandong",
        "Henan", "Hubei", "Hunan", "Guangdong", "Chongqing",
        "Sichuan", "Guizhou", "Yunnan", "Shaanxi", "Gansu"
      ) ~ "CFPS covered (25 provinces)",
      TRUE ~ "Not in CFPS sample"
    )
  )

# ---- 3. PBoC survey cities (50 cities, approximate coords) -----
pboc_cities <- data.frame(
  city = c(
    "Beijing", "Shanghai", "Tianjin", "Chongqing",
    "Harbin", "Changchun", "Shenyang", "Dalian",
    "Shijiazhuang", "Taiyuan", "Hohhot",
    "Jinan", "Qingdao", "Zhengzhou",
    "Nanjing", "Hangzhou", "Ningbo", "Hefei",
    "Wuhan", "Changsha", "Nanchang",
    "Guangzhou", "Shenzhen", "Fuzhou", "Xiamen",
    "Nanning", "Haikou", "Guiyang",
    "Chengdu", "Kunming", "Xi'an", "Lanzhou",
    "Xining", "Yinchuan", "Urumqi", "Lhasa",
    "Nanjing", "Suzhou", "Wuxi", "Wenzhou",
    "Zibo", "Tangshan", "Baotou", "Datong",
    "Luoyang", "Wuham", "Zhuhai", "Dongguan",
    "Mianyang", "Zunyi"
  ),
  lon = c(
    116.4, 121.5, 117.2, 106.5,
    126.5, 125.3, 123.4, 121.6,
    114.5, 112.6, 111.8,
    117.0, 120.4, 113.7,
    118.8, 120.2, 121.6, 117.3,
    114.3, 113.0, 115.9,
    113.3, 114.1, 119.3, 118.1,
    108.4, 110.3, 106.7,
    104.1, 102.7, 108.9, 103.8,
    101.8, 106.3, 87.6, 91.1,
    118.8, 120.6, 120.3, 120.7,
    118.1, 118.2, 110.0, 113.3,
    112.5, 114.4, 113.6, 113.7,
    104.7, 106.9
  ),
  lat = c(
    39.9, 31.2, 39.1, 29.6,
    45.8, 43.9, 41.8, 38.9,
    38.0, 37.9, 40.8,
    36.7, 36.1, 34.8,
    32.1, 30.3, 29.9, 31.9,
    30.6, 28.2, 28.7,
    23.1, 22.5, 26.1, 24.5,
    22.8, 20.0, 26.6,
    30.7, 25.0, 34.3, 36.1,
    36.6, 38.5, 43.8, 29.7,
    32.1, 31.3, 31.6, 28.0,
    36.8, 39.6, 40.7, 40.1,
    34.7, 30.6, 22.3, 23.0,
    31.5, 27.7
  )
)
# Remove duplicate rows
pboc_cities <- pboc_cities[!duplicated(pboc_cities$city), ]
pboc_sf <- st_as_sf(pboc_cities, coords = c("lon", "lat"), crs = 4326)

# ---- 4. Plot ---------------------------------------------------
map_colors <- c(
  "CFPS covered (25 provinces)" = "#3182bd",
  "Not in CFPS sample"           = "#deebf7"
)

p <- ggplot() +
  geom_sf(data = china_prov,
          aes(fill = cfps),
          color = "white", linewidth = 0.3) +
  geom_sf(data = pboc_sf,
          shape = 21, size = 1.5,
          fill = "#e6550d", color = "white", stroke = 0.4,
          alpha = 0.85) +
  scale_fill_manual(values = map_colors, name = NULL) +
  coord_sf(
    xlim = c(72, 136),
    ylim = c(17, 54),
    expand = FALSE
  ) +
  labs(
    caption = paste0(
      "Blue: provinces included in CFPS 2010\u20132022 (25 provinces, ",
      "\u224895% of population).\n",
      "Orange dots: approximate locations of the 50 cities in the ",
      "PBoC Urban Depositor Survey."
    )
  ) +
  theme_void(base_size = 9) +
  theme(
    legend.position     = c(0.15, 0.25),
    legend.text         = element_text(size = 7.5),
    legend.key.size     = unit(0.35, "cm"),
    legend.background   = element_rect(fill = "white", color = NA),
    plot.caption        = element_text(size = 6.5, hjust = 0,
                                       margin = margin(t = 4)),
    plot.margin         = margin(4, 4, 4, 4)
  )

# ---- 5. Save ---------------------------------------------------
script_dir <- dirname(normalizePath(sys.frame(1)$ofile, winslash = "/"))
proj_root  <- dirname(script_dir)
out_dir    <- file.path(proj_root, "outputs", "figures")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

ggsave(
  filename = file.path(out_dir, "china_cfps_map.pdf"),
  plot     = p,
  width    = 5.5,
  height   = 3.6,
  device   = cairo_pdf
)
ggsave(
  filename = file.path(out_dir, "china_cfps_map.png"),
  plot     = p,
  width    = 5.5,
  height   = 3.6,
  dpi      = 300
)

message("Map saved to outputs/figures/china_cfps_map.{pdf,png}")
