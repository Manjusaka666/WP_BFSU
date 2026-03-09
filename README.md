# Diagnostic Expectations in China: Reproducible Pipeline

This repository now uses an identification-first workflow in **R + Julia**.

## Entrypoint
Run the full pipeline from the project root:

```powershell
Rscript src/99_run_all.R
```

This executes:
1. R modules for measurement, panel construction, identification, baseline models, heterogeneity, mechanism competition, local projections, policy backtest, publication tables/figures, and Python-parity checks.
2. Julia Bayesian modules for state-space diagnostics and appendix BVAR sensitivity.

## Directory map
- `data/raw/`: original source files (do not overwrite)
- `data/intermediate/`: transformed intermediate datasets
- `data/processed/`: final estimation panel (`csv` + `parquet`)
- `src/`: numbered R/Julia scripts
- `outputs/tables/`: LaTeX booktabs tables
- `outputs/figures/`: publication figures (`pdf` + `png`)
- `outputs/robustness/`: robustness and backtest artifacts
- `v1.3/`: production LaTeX manuscript
- `audit/`: evidence ledger, reproducibility log, variable dictionary, self-critique, and scope limits

## Main scripts
- `src/05_carlson_parkin_quantify.R`
- `src/10_build_panel.R`
- `src/35_identification_main.R`
- `src/40_models_baseline.R`
- `src/45_models_heterogeneity.R`
- `src/50_mechanism_competition.R`
- `src/60_lp_dynamic.R`
- `src/70_policy_backtest.R`
- `src/80_figures_tables.R`
- `src/90_parity_check_with_python.R`
- `src/20_bayes_state_space_diagnostic.jl`
- `src/30_bvar_sign_restrictions.jl`
- `src/99_run_all.R`

## Deterministic settings
- R and Julia scripts use fixed random seeds where simulation is involved.
- `audit/reproducibility_log.md` records executed commands and status codes.

## LaTeX output
Compile:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error -output-directory v1.3 v1.3/Writing_Sample_10p.tex
bibtex v1.3/Writing_Sample_10p
pdflatex -interaction=nonstopmode -halt-on-error -output-directory v1.3 v1.3/Writing_Sample_10p.tex
pdflatex -interaction=nonstopmode -halt-on-error -output-directory v1.3 v1.3/Writing_Sample_10p.tex
```

Final target file: `v1.3/paper_writing_sample.pdf` (copied from compiled manuscript).
