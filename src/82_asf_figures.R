#!/usr/bin/env Rscript
# 82_asf_figures.R
# ASF event-study figures:
# 1. Meat CPI time series by province (spaghetti plot highlighting ASF onset)
# 2. Meat shock distribution across waves (box/violin plot)

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

invisible(Sys.setlocale("LC_TIME", "C"))
source(file.path("src", "00_project_utils.R"))
source(file.path("src", "17_province_code_map.R"))
ensure_paths()

fig_dir <- project_paths$figures
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# --- Figure 1: Province meat CPI time series ---
meat <- fread(file.path(project_paths$intermediate, "province_meat_cpi.csv"))
meat[, date := as.IDate(date)]

# Normalize: cumulative log index from first observation per province
meat[, cum_log := cumsum(log(cpi_index / 100)), by = provcd]

# Ensure region column exists (may already be in CSV from parser)
if (!"region" %in% names(meat)) {
  pmap <- get_province_map()
  meat <- merge(meat, pmap[, .(provcd, region)], by = "provcd", all.x = TRUE)
}

# ASF onset line
asf_date <- as.IDate("2018-08-01")

p1 <- ggplot(meat, aes(x = date, y = cum_log, group = provcd, colour = region)) +
  geom_line(alpha = 0.5, linewidth = 0.4) +
  geom_vline(xintercept = asf_date, linetype = "dashed", colour = "red", linewidth = 0.6) +
  annotate("text", x = asf_date + 60, y = max(meat$cum_log, na.rm = TRUE) * 0.95,
           label = "ASF onset\n(Aug 2018)", hjust = 0, size = 3, colour = "red") +
  labs(
    x = NULL, y = "Cumulative log meat CPI",
    title = "Province-Level Meat CPI Trajectories",
    subtitle = "Each line is one province; vertical line marks African Swine Fever onset"
  ) +
  scale_colour_brewer(palette = "Set2", name = "Region") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_meat_cpi_spaghetti.pdf"), p1,
       width = 8, height = 5.5, device = cairo_pdf)
cat(sprintf("[82] Wrote %s\n", file.path(fig_dir, "fig_meat_cpi_spaghetti.pdf")))

# --- Figure 2: Meat shock distribution by wave ---
shocks <- fread(file.path(project_paths$intermediate, "province_wave_shocks.csv"))
shocks <- shocks[!is.na(meat_shock)]
shocks[, wave_label := as.factor(wave)]

p2 <- ggplot(shocks, aes(x = wave_label, y = meat_shock)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90", width = 0.5) +
  geom_jitter(aes(colour = region), width = 0.15, size = 1.5, alpha = 0.7) +
  geom_hline(yintercept = 0, linetype = "dotted", colour = "grey50") +
  labs(
    x = "CFPS wave", y = "Meat shock (cumulative log CPI)",
    title = "Distribution of Province-Level Meat Price Shocks by Wave"
  ) +
  scale_colour_brewer(palette = "Set2", name = "Region") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_meat_shock_distribution.pdf"), p2,
       width = 7, height = 5, device = cairo_pdf)
cat(sprintf("[82] Wrote %s\n", file.path(fig_dir, "fig_meat_shock_distribution.pdf")))

# --- Figure 3: Headline vs Meat CPI scatter ---
shocks_plot <- shocks[!is.na(headline_cpi_next)]
p3 <- ggplot(shocks_plot, aes(x = meat_shock, y = headline_cpi_next)) +
  geom_point(aes(colour = region), size = 2, alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, colour = "black", linewidth = 0.6) +
  labs(
    x = "Meat shock (cumulative log CPI)",
    y = "Forward headline CPI (cumulative log)",
    title = "Meat Shock vs. Forward Realized Headline CPI"
  ) +
  scale_colour_brewer(palette = "Set2", name = "Region") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "fig_meat_vs_headline.pdf"), p3,
       width = 7, height = 5, device = cairo_pdf)
cat(sprintf("[82] Wrote %s\n", file.path(fig_dir, "fig_meat_vs_headline.pdf")))

cat("[82] All ASF figures complete.\n")
