# Project Inventory
**PhD Writing Sample: Diagnostic Expectations in China**
**Generated**: 2026-01-06
**Purpose**: Complete file inventory for Module A (Repo Intake)

---

## Directory Structure

```
e:/研究生/为了毕业的论文WP/
├── data/
│   ├── raw/ (63 files - original downloaded/scraped data)
│   ├── intermediate/ (13 files - processed intermediates)
│   └── processed/ (final analysis dataset)
├── src/ (22 Python scripts)
├── outputs/
│   ├── tables/ (27 LaTeX table files)
│   ├── figures/ (13 PNG/PDF files)
│   └── robustness/ (17 subdirectories)
├── v1.2/ (source chapters 01-11)
├── v1.3/ (in progress)
└── internal_audit/ (this directory)
```

---

## Source Files (v1.2/ directory)

### Main Chapters
| File | Size | Lines | Status | Key Content |
|------|------|-------|--------|-------------|
| 01_introduction_revised.md | 8.8KB | 55 | ✅ Complete | Research background, gap, contributions |
| 02.1-02.3_literature.md | 19.4KB | 113 | ✅ Complete | DE vs RI vs Learning comparison |
| 03_data_variables.md | 13.3KB | 109 | ✅ Complete | PBOC survey, CP quantification, descriptive stats |
| 04_methodology.md | 7.5KB | 114 | ✅ Complete | TVP-SSM + BVAR models, identification |
| 06.1_ols_results.md | 6.0KB | 68 | ✅ Complete | OLS baseline, β=-0.588***, IV estimation |
| 06.2_tvp_ssm_results.md | 20.8KB | 126 | ✅ Complete | Time-varying β_t, 91% negative, nonlinearity |
| 06.3_bvar_results.md | 21.2KB | 145 | ✅ Complete | FEVD 26% vs 9%, 9% paradox explanation |
| 07_robustness.md | 5.3KB | - | ✅ Complete | Prior sensitivity, lag order, alternative specs |
| 08_discussion.md | 19.4KB | - | ✅ Complete | Policy implications (China context) |
| 09_conclusion.md | 5.9KB | - | ✅ Complete | Main findings, limitations, future work |
| 10_appendices_A-F.md | 26.3KB | - | ✅ Complete | CP, MCMC, Sign restrictions, derivations |
| 11_references.md | 6.3KB | - | ✅ Complete | ~50 references |

**Total source**: 12 files, ~160KB

---

## Code Files (src/ directory)

### Data Pipeline (01-10)
| Script | Purpose | Input | Output |
|--------|---------|-------|--------|
| 00_run_complete_analysis.py | Master entry point | All data | All outputs |
| 01_download_gpr.py | Download GPR index | Web | data/raw/gpr_export.csv |
| 02_download_epu.py | Download EPU China | Web | data/raw/epu_china.xlsx |
| 03_scrape_pboc_depositor_survey.py | PBOC survey scraper | PBOC website | data/raw/pboc_*.csv |
| 04_download_nbs_easyquery.py | NBS macro data | NBS API | data/raw/nbs_*.xlsx |
| 05_carlson_parkin_quantify.py | CP quantification | PBOC shares + NBS CPI | data/intermediate/pboc_expected_inflation_cp.csv |
| 06_process_epu.py | EPU quarterly | raw/epu | intermediate/epu_quarterly.csv |
| 07_process_gpr.py | GPR quarterly | raw/gpr | intermediate/gpr_quarterly.csv |
| 08_process_nbs_macro_control.py | NBS macro vars | raw/nbs | intermediate/nbs_macro_quarterly.csv |
| 09_process_food_cpi.py | Food CPI | raw/nbs | intermediate/food_cpi_quarterly.csv |
| 10_build_quarterly_panel.py | Merge panel | All intermediate | data/processed/final_analysis.csv |

### Analysis (11, 15, 20-22, 30-31)
| Script | Purpose | Input | Output |
|--------|---------|-------|--------|
| 11_enhanced_descriptive_stats.py | Descriptive tables | processed/ | tables/desc_stats*.tex |
| 15_baseline_ols_regression.py | OLS regression | processed/ | tables/ols_baseline.tex |
| 20_bayes_state_space_diagnostic.py | TVP-SSM MCMC | processed/ | tables/ssm_*.tex, figures/beta_t.png |
| 21_ssm_mcmc_diagnostics.py | MCMC diagnostics | SSM chains | figures/mcmc_trace.png, mcmc_acf.png |
| 22_model_comparison.py | Model comparison | SSM + BVAR | tables/model_comparison.tex |
| 30_bvar_sign_restrictions.py | BVAR + sign | processed/ | tables/bvar_*.tex, figures/bvar_*.png |
| 31_robustness_visualization.py | Robustness plots | robustness/ | figures/robustness_*.png |

**Total scripts**: 22 files

---

## Output Files

### Tables (outputs/tables/, 27 files)
| Table | File | Size | Content | Used In |
|-------|------|------|---------|---------|
| 3.1-3.3 | desc_stats_extended.tex | 1.3KB | Descriptive statistics | Data section |
| | correlation_matrix.tex | 1.1KB | Correlation matrix | Data section |
| | fe_fr_stats.tex | 0.8KB | FE/FR statistics | Data section |
| 5.1-5.3 | ols_baseline.tex | 1.3KB | OLS regression (β=-0.588***) | Results |
| | ols_diagnostics.tex | 0.8KB | OLS diagnostics | Results |
| | ols_robustness.tex | 1.4KB | OLS robustness (IV) | Results |
| 5.4-5.5 | ssm_posterior_params.tex | 1.0KB | SSM parameters | Results |
| | beta_t_path.tex | 2.2KB | β_t time series | Results |
| | beta_t_path.csv | 2.9KB | β_t data (43 quarters) | Analysis |
| 5.6 | grouped_beta_stats.tex | 0.8KB | Grouped statistics (EPU/GPR) | Results |
| 5.7-5.10 | bvar_acceptance.tex | 0.6KB | BVAR acceptance rate | Results |
| | bvar_irf_summary.tex | 2.0KB | IRF summary | Results |
| | bvar_fevd.tex | 1.0KB | FEVD (26% vs 9%) | Results |
| | bvar_historical.tex | 0.7KB | Historical decomposition | Results |
| 6.1-6.2 | robustness/ssm_summary.tex | - | SSM robustness summary | Robustness |
| | robustness/bvar_summary.tex | - | BVAR robustness summary | Robustness |

**Key numbers**:
- β_OLS = -0.588*** (SE=0.109)
- β_t: 91% (39/43) periods negative
- FEVD: DE→μ = 26%, DE→π = 9%
- BVAR acceptance rate: 99.95%

### Figures (outputs/figures/, 13 files)
| Figure | File | Size | Content | Used In |
|--------|------|------|---------|---------|
| 5.1 | beta_t.png | 84KB | β_t time-varying path | TVP results |
| 5.2-5.3 | beta_epu_scatter_v1.3.png | 285KB | β_t vs EPU scatter + LOWESS | Nonlinearity |
| | beta_gpr_scatter_v1.3.png | 294KB | β_t vs GPR scatter + LOWESS | Nonlinearity |
| 5.4-5.5 | bvar_irf_de_shock.png | 137KB | IRF of DE shock | BVAR results |
| | bvar_fe_reversal.png | 57KB | FE reversal pattern | BVAR results |
| 6.1-6.3 | mcmc_trace.png | 727KB | MCMC trace plots | Robustness |
| | mcmc_acf.png | 120KB | Autocorrelation | Robustness |
| | prior_sensitivity.png | 378KB | Prior sensitivity | Robustness |
| | robustness_beta_compare.png | 315KB | SSM robustness comparison | Robustness |
| | robustness_bvar_compare.png | 116KB | BVAR robustness comparison | Robustness |

### Robustness (outputs/robustness/, 17 subdirectories)
- SSM variants: baseline, prior_loose, prior_tight, X_epu_only, X_gpr_only, Z_food_only, alt_expect_index
- BVAR variants: baseline_p2, p1, p4, add_food, alt_infl, alt_expect_index
- Each contains: posterior samples, summary statistics, re-estimated tables/figures

---

## Data Files

### Raw Data (data/raw/, 63 files)
- PBOC depositor survey (quarterly, 1999Q1-2025Q3)
- EPU China index (monthly, converted to quarterly)
- GPR index (daily, aggregated to quarterly)
- NBS macro data (CPI, M2, PPI, Industrial VA)

### Intermediate (data/intermediate/, 13 files)
- pboc_depositor_survey_quarterly.csv
- pboc_expected_inflation_cp.csv (CP quantified, 45 quarters)
- epu_quarterly.csv
- gpr_quarterly.csv
- nbs_macro_quarterly.csv
- food_cpi_quarterly.csv

### Processed (data/processed/)
- final_analysis.csv (43 quarters, 2014Q1-2024Q4)
  - Effective sample after FE/FR construction
  - Variables: FE, FR, μ, π, EPU, GPR, Food CPI, M2, PPI, IndVA

---

## Key Findings Summary (from outputs)

### OLS (Table 5.1)
- β = -0.588*** (SE=0.109, p<0.01)
- R² = 0.351, Adj R² = 0.282
- IV estimate: β = -0.612*** (SE=0.189)
- **Interpretation**: Systematic over-reaction, rejects REH

### TVP-SSM (Tables 5.4-5.5, Figure 5.1)
- β_t posterior mean: -0.522
- 91% (39/43) periods β_t < 0
- Extreme periods: 2016Q1=-1.16, 2020Q2=-1.31
- d_EPU: 0.074 (n.s., p.i. -0.25 to 0.41)
- d_GPR: -0.122 (n.s., p.i. -0.52 to 0.29)
- **Interpretation**: Time-varying diagnostic intensity, episodic association with EPU/GPR

### BVAR (Tables 5.7-5.10, Figures 5.4-5.5)
- Acceptance rate: 99.95% (1995/2000 posterior draws)
- FEVD: DE shock explains 26% of μ variance, 9% of π variance
- IRF: Impact μ↑0.8pp, FE reversal to negative h=1-4
- **Interpretation**: High expectation volatility, low transmission efficiency

### Nonlinearity (v1.3, Figures 5.2-5.3, Table 5.6)
- Scatter plots: "step-function" pattern, GPR threshold ≈118
- Grouped stats: High GPR → β=-0.68, Low GPR → β=-0.37 (p=0.09)
- Quantile regression: EPU effect 3x larger at 90th percentile
- Hansen test: GPR threshold 118, d_high=-0.521 (p=0.07)

---

## Version Control & Random Seeds

**Random Seeds** (verified in code):
- MCMC (src/20): `np.random.seed(42)`
- BVAR (src/30): `np.random.seed(123)`

**File Integrity Checks**:
- All 27 tables exist: ✅
- All 13 figures exist: ✅
- All robustness subdirectories exist: ✅

---

## Inventory Status: ✅ COMPLETE

**Next Step**: Create variable_dictionary.md with precise definitions
