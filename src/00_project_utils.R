# Shared utilities for the AER/QJE-grade replication workflow.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(knitr)
  library(zoo)
})

okabe_ito <- c(
  orange = "#E69F00",
  sky_blue = "#56B4E9",
  bluish_green = "#009E73",
  yellow = "#F0E442",
  blue = "#0072B2",
  vermillion = "#D55E00",
  reddish_purple = "#CC79A7",
  black = "#000000"
)

project_paths <- list(
  raw = file.path("data", "raw"),
  intermediate = file.path("data", "intermediate"),
  processed = file.path("data", "processed"),
  outputs = "outputs",
  tables = file.path("outputs", "tables"),
  figures = file.path("outputs", "figures"),
  robustness = file.path("outputs", "robustness")
)

ensure_paths <- function() {
  dirs <- unlist(project_paths, use.names = FALSE)
  for (d in dirs) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
}

parse_quarter <- function(q) {
  q <- as.character(q)
  q <- gsub("\\s+", "", q)
  as.yearqtr(q, format = "%YQ%q")
}

quarter_to_date <- function(q) {
  as.Date(parse_quarter(q), frac = 1)
}

safe_num <- function(x) {
  suppressWarnings(as.numeric(x))
}

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(x, digits = digits, format = "f"))
}

write_booktabs_table <- function(df, out_file, caption = "", label = "", notes = NULL,
                                 digits = 3, align = NULL, escape = FALSE) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  body <- knitr::kable(
    df,
    format = "latex",
    booktabs = TRUE,
    digits = digits,
    align = align,
    escape = TRUE,
    longtable = FALSE
  )

  lines <- c("\\begin{table}[!htbp]", "\\centering")
  if (nzchar(caption)) lines <- c(lines, paste0("\\caption{", caption, "}"))
  if (nzchar(label)) lines <- c(lines, paste0("\\label{", label, "}"))
  lines <- c(lines, "\\begin{threeparttable}", body)

  if (!is.null(notes) && length(notes) > 0) {
    lines <- c(lines, "\\begin{tablenotes}[flushleft]", "\\footnotesize")
    for (n in notes) {
      n_clean <- gsub("`", "", n, fixed = TRUE)
      n_clean <- gsub("_", "\\_", n_clean, fixed = TRUE)
      lines <- c(lines, paste0("\\item ", n_clean))
    }
    lines <- c(lines, "\\end{tablenotes}")
  }

  lines <- c(lines, "\\end{threeparttable}", "\\end{table}")
  writeLines(lines, con = out_file, useBytes = TRUE)
}

# AER/QJE publication theme.
# Key conventions: no vertical gridlines, no minor gridlines, serif font,
# thin axis lines, bottom legend, restrained title.
theme_pub <- function(base_size = 10) {
  theme_minimal(base_size = base_size, base_family = "serif") %+replace%
    theme(
      # Grid: only horizontal major lines, light grey, thin
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      # Axis
      axis.line          = element_line(colour = "grey30", linewidth = 0.35),
      axis.ticks         = element_line(colour = "grey30", linewidth = 0.3),
      axis.ticks.length  = unit(1.5, "pt"),
      axis.title.x       = element_text(size = rel(0.95), margin = margin(t = 6)),
      axis.title.y       = element_text(size = rel(0.95), margin = margin(r = 6)),
      axis.text          = element_text(colour = "grey20", size = rel(0.85)),
      # Legend
      legend.position    = "bottom",
      legend.title       = element_blank(),
      legend.text        = element_text(size = rel(0.85)),
      legend.key.size    = unit(12, "pt"),
      legend.margin      = margin(t = 2, b = 0),
      # Title / subtitle / caption
      plot.title         = element_text(size = rel(1.05), face = "plain",
                                        hjust = 0, margin = margin(b = 4)),
      plot.subtitle      = element_text(size = rel(0.88), hjust = 0,
                                        colour = "grey30", margin = margin(b = 6)),
      plot.caption       = element_text(size = rel(0.72), hjust = 0, colour = "grey50"),
      plot.margin        = margin(8, 8, 6, 6),
      # Strip (for facets)
      strip.text         = element_text(size = rel(0.9), face = "plain")
    )
}

save_plot_pair <- function(p, file_stub, width = 6.5, height = 4) {
  ggsave(filename = paste0(file_stub, ".pdf"), plot = p,
         width = width, height = height, device = cairo_pdf)
  ggsave(filename = paste0(file_stub, ".png"), plot = p,
         width = width, height = height, dpi = 300)
}

# Significance stars for p-values.
stars <- function(p) {
  ifelse(is.na(p), "",
  ifelse(p < 0.01, "^{***}",
  ifelse(p < 0.05, "^{**}",
  ifelse(p < 0.10, "^{*}", ""))))
}

# Format a coefficient with stars: "$-2.237^{**}$"
fmt_coef <- function(b, p = NA, digits = 3) {
  s <- stars(p)
  paste0("$", formatC(b, digits = digits, format = "f"), s, "$")
}

# Format a standard error in parentheses: "$(1.114)$"
fmt_se <- function(se, digits = 3) {
  paste0("$(", formatC(se, digits = digits, format = "f"), ")$")
}

newey_west_se <- function(model, lag = 4) {
  sqrt(diag(sandwich::NeweyWest(model, lag = lag, prewhite = FALSE, adjust = TRUE)))
}

quarter_order <- function(x) {
  order(parse_quarter(x))
}

