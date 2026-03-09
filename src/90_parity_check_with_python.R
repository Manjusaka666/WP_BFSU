#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

new_file <- file.path(project_paths$processed, "panel_quarterly.csv")
old_file <- file.path(project_paths$processed, "panel_quarterly_python_baseline.csv")

if (!file.exists(new_file)) stop("New panel file missing. Run 10_build_panel.R first.")
if (!file.exists(old_file)) {
  cat("[90] Python baseline backup not found; parity check skipped.\n")
  quit(status = 0)
}

new_dt <- fread(new_file)
old_dt <- fread(old_file)

if (!"quarter" %in% names(new_dt) || !"quarter" %in% names(old_dt)) {
  stop("Quarter key missing in at least one panel file.")
}

common_cols <- intersect(names(new_dt), names(old_dt))
num_cols <- common_cols[sapply(common_cols, function(x) is.numeric(new_dt[[x]]) && is.numeric(old_dt[[x]]))]

m <- merge(new_dt[, c("quarter", num_cols), with = FALSE],
           old_dt[, c("quarter", num_cols), with = FALSE],
           by = "quarter", suffixes = c("_r", "_py"))

parity <- rbindlist(lapply(num_cols, function(v) {
  xr <- m[[paste0(v, "_r")]]
  xp <- m[[paste0(v, "_py")]]
  idx <- complete.cases(xr, xp)
  if (!any(idx)) {
    return(data.table(variable = v, n_overlap = 0, corr = NA_real_, mean_abs_diff = NA_real_, max_abs_diff = NA_real_))
  }
  data.table(
    variable = v,
    n_overlap = sum(idx),
    corr = cor(xr[idx], xp[idx]),
    mean_abs_diff = mean(abs(xr[idx] - xp[idx])),
    max_abs_diff = max(abs(xr[idx] - xp[idx]))
  )
}))

fwrite(parity, file.path(project_paths$robustness, "parity_check.csv"))

write_booktabs_table(
  parity,
  file.path(project_paths$tables, "parity_check.tex"),
  caption = "Parity Check: New R Pipeline vs Legacy Python Outputs",
  label = "tab:parity_check",
  notes = c("High correlations indicate successful migration consistency."),
  digits = 3,
  escape = FALSE
)

cat("[90] Parity check complete.\n")

