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

theme_pub <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "serif") +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.title = element_text(face = "bold", hjust = 0),
      plot.subtitle = element_text(hjust = 0),
      axis.title = element_text(face = "bold")
    )
}

save_plot_pair <- function(p, file_stub, width = 8, height = 5) {
  ggsave(filename = paste0(file_stub, ".pdf"), plot = p, width = width, height = height)
  ggsave(filename = paste0(file_stub, ".png"), plot = p, width = width, height = height, dpi = 300)
}

newey_west_se <- function(model, lag = 4) {
  sqrt(diag(sandwich::NeweyWest(model, lag = lag, prewhite = FALSE, adjust = TRUE)))
}

quarter_order <- function(x) {
  order(parse_quarter(x))
}

