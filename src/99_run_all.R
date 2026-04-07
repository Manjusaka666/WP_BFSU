#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

audit_log <- file.path("audit", "reproducibility_log.md")
dir.create("audit", showWarnings = FALSE, recursive = TRUE)

append_log <- function(lines) {
  cat(lines, file = audit_log, append = TRUE, sep = "\n")
}

run_step <- function(cmd, args = character()) {
  cat(sprintf("\n[RUN] %s %s\n", cmd, paste(args, collapse = " ")))
  t0 <- Sys.time()
  status <- system2(cmd, args = args)
  t1 <- Sys.time()
  append_log(c(
    sprintf("- `%s %s`", cmd, paste(args, collapse = " ")),
    sprintf("  - started: %s", format(t0, "%Y-%m-%d %H:%M:%S")),
    sprintf("  - ended: %s", format(t1, "%Y-%m-%d %H:%M:%S")),
    sprintf("  - status: %s", status)
  ))
  if (status != 0) stop(sprintf("Step failed: %s", paste(c(cmd, args), collapse = " ")))
}

append_log(c("# Reproducibility Log", "", sprintf("## Run date: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), ""))

# Core R pipeline.
r_scripts <- c(
  # --- Data construction ---
  "15_build_province_cpi.R",
  "16_build_meat_shock.R",
  "12_build_cfps_panel.R",
  # --- Main analysis ---
  "42_meat_shock_regressions.R",
  "43_heterogeneity_meat.R",
  "44_placebo_commodity.R",
  "46_wild_bootstrap.R",
  # --- Figures ---
  "82_asf_figures.R"
)

for (s in r_scripts) {
  run_step("Rscript", c(file.path("src", s)))
}

# Julia Bayesian modules.
run_step("julia", c(file.path("src", "20_bayes_state_space_diagnostic.jl")))
run_step("julia", c(file.path("src", "30_bvar_sign_restrictions.jl")))

# Replication artifact.
dir.create("replication", showWarnings = FALSE, recursive = TRUE)
rep_file <- file.path("replication", "run_replication.ps1")
writeLines(c(
  "Rscript src/99_run_all.R"
), rep_file)

# Mirror latest outputs into v1.3 directories.
dir.create(file.path("v1.3", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("v1.3", "figures"), recursive = TRUE, showWarnings = FALSE)

if (dir.exists(project_paths$tables)) {
  file.copy(list.files(project_paths$tables, full.names = TRUE), file.path("v1.3", "tables"), overwrite = TRUE)
}
if (dir.exists(project_paths$figures)) {
  file.copy(list.files(project_paths$figures, full.names = TRUE), file.path("v1.3", "figures"), overwrite = TRUE)
}

cat("[99] Full pipeline completed successfully.\n")

