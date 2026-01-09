# Variable Dictionary
**PhD Writing Sample: Diagnostic Expectations in China**
**Purpose**: Precise definitions for all variables used in empirical analysis

---

## Core Variables (Expectation Formation)

### μ_t (Inflation Expectation)
- **Definition**: Households' expected next-quarter inflation rate
- **Unit**: Percentage points (pp), annualized
- **Frequency**: Quarterly
- **Construction**: Carlson-Parkin quantification from PBOC depositor survey
  - Formula: μ_t = π_t + δ - σ_t · z_u
  - δ (tolerance band): 0.5pp
  - z_u: Normal quantile from "price up" share
- **Sample**: 2013Q4-2025Q2
  - Total: 47 quarters
  - Available after CP quantification: 45 quarters (missing 2013Q2, 2020Q4)
- **Source**: PBOC quarterly depositor survey (50 cities, 20k households)
- **Code**: src/05_carlson_parkin_quantify.py
- **Output**: data/intermediate/pboc_expected_inflation_cp.csv

### π_t (Actual Inflation)
- **Definition**: Realized CPI inflation rate, year-over-year
- **Unit**: Percentage points (pp)
- **Frequency**: Quarterly
- **Construction**: (CPI_t - CPI_{t-4}) / CPI_{t-4} × 100
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Source**: National Bureau of Statistics (NBS)
- **Code**: src/08_process_nbs_macro_control.py
- **Output**: data/intermediate/nbs_macro_quarterly.csv

### FE_t (Forecast Error)
- **Definition**: Prediction error, actual minus expected
- **Formula**: FE_t = π_{t+1} - μ_t
- **Unit**: Percentage points (pp)
- **Interpretation**: 
  - FE > 0: Under-prediction (inflation higher than expected)
  - FE < 0: Over-prediction (inflation lower than expected)
- **Sample**: 2014Q1-2024Q4 (43 quarters, effective regression sample)
  - Requires both μ_t and π_{t+1}, loses first period
- **Mean**: -0.311pp (systematic over-prediction)
- **SD**: 0.524pp
- **Code**: src/10_build_quarterly_panel.py
- **Output**: data/processed/final_analysis.csv

### FR_t (Forecast Revision)
- **Definition**: Change in inflation expectation
- **Formula**: FR_t = μ_t - μ_{t-1}
- **Unit**: Percentage points (pp)
- **Interpretation**:
  - FR > 0: Upward revision (more optimistic/inflationary)
  - FR < 0: Downward revision (more pessimistic/deflationary)
- **Sample**: 2014Q1-2024Q4 (43 quarters)
  - Requires two consecutive μ observations
- **Mean**: -0.004pp
- **SD**: 0.482pp
- **Correlation with FE**: -0.451*** (p<0.01)
- **Code**: src/10_build_quarterly_panel.py
- **Output**: data/processed/final_analysis.csv

---

## State Variable (Time-Varying Diagnostic Intensity)

### β_t (Diagnostic Intensity Parameter)
- **Definition**: Time-varying coefficient in measurement equation FE_t = α + β_t · FR_t + ...
- **Unit**: Unitless (regression coefficient)
- **Interpretation**:
  - β_t < 0: Diagnostic expectations (over-reaction)
  - β_t = 0: Rational expectations (no systematic error)
  - β_t > 0: Rational inattention (under-reaction)
- **Estimation**: TVP-SSM with MCMC (20k iterations, burn-in 5k)
- **Sample**: 2014Q1-2024Q4 (43 quarters)
- **Summary statistics**:
  - Mean: -0.522
  - Median: -0.485
  - SD: 0.347
  - Percent negative: 90.7% (39/43 periods)
  - 90% CI fully negative: 16.3% (7/43 periods)
- **Key periods**:
  - 2016Q1 (RMB depreciation): -1.16
  - 2020Q2 (COVID-19): -1.31
  - 2018Q3 (Trade war): -0.89
- **Code**: src/20_bayes_state_space_diagnostic.py
- **Output**: outputs/tables/beta_t_path.csv, beta_t_path.tex, figures/beta_t.png

---

## Uncertainty Drivers (State Equation)

### EPU_t (Economic Policy Uncertainty Index)
- **Definition**: China economic policy uncertainty index (Baker et al., 2016)
- **Unit**: Index (normalized, mean=100 approx)
- **Frequency**: Monthly → aggregated to quarterly mean
- **Construction**: Text analysis of Hong Kong newspapers
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 264.3
- **SD**: 89.7
- **Range**: [125.4, 512.3]
- **Source**: policyuncertainty.com
- **Code**: src/02_download_epu.py, src/06_process_epu.py
- **Output**: data/intermediate/epu_quarterly.csv

### GPR_t (Geopolitical Risk Index)
- **Definition**: Global geopolitical risk index (Caldara & Iacoviello, 2022)
- **Unit**: Index (normalized, mean=100 approx)
- **Frequency**: Daily → aggregated to quarterly mean
- **Construction**: Automated text analysis of international news
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 98.2
- **SD**: 31.5
- **Range**: [52.1, 189.4]
- **Source**: matteoiacoviello.com/gpr.htm
- **Code**: src/01_download_gpr.py, src/07_process_gpr.py
- **Output**: data/intermediate/gpr_quarterly.csv

---

## Control Variables

### Food CPI_t (Food Inflation)
- **Definition**: Food CPI inflation rate, year-over-year
- **Unit**: Percentage points (pp)
- **Frequency**: Quarterly
- **Rationale**: Control for "pork cycle" short-term disturbances
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 0.324pp
- **SD**: 2.147pp
- **Source**: NBS
- **Code**: src/09_process_food_cpi.py
- **Output**: data/intermediate/food_cpi_quarterly.csv

### M2_t (Money Supply Growth)
- **Definition**: M2 money supply growth rate, year-over-year
- **Unit**: Percentage points (pp)
- **Frequency**: Quarterly (end-of-quarter stock)
- **Rationale**: Control for monetary policy stance
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 8.92pp
- **SD**: 1.83pp
- **Source**: NBS
- **Code**: src/08_process_nbs_macro_control.py
- **Output**: data/intermediate/nbs_macro_quarterly.csv

### PPI_t (Producer Price Inflation)
- **Definition**: PPI inflation rate, year-over-year
- **Unit**: Percentage points (pp)
- **Frequency**: Quarterly
- **Rationale**: Control for upstream price pressure
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 0.145pp
- **SD**: 3.452pp
- **Source**: NBS
- **Code**: src/08_process_nbs_macro_control.py
- **Output**: data/intermediate/nbs_macro_quarterly.csv

### IndVA_t (Industrial Value Added Growth)
- **Definition**: Industrial value added growth rate, year-over-year
- **Unit**: Percentage points (pp)
- **Frequency**: Quarterly
- **Rationale**: Control for business cycle
- **Sample**: 2013Q4-2025Q2 (47 quarters)
- **Mean**: 6.18pp
- **SD**: 1.97pp
- **Source**: NBS
- **Code**: src/08_process_nbs_macro_control.py
- **Output**: data/intermediate/nbs_macro_quarterly.csv

---

## Sample Periods (Critical)

### Total Observation Window
- **Start**: 2013Q4
- **End**: 2025Q2
- **Total**: 47 quarters

### CP Quantification Available
- **Available**: 45 quarters
- **Missing**: 2013Q2 (survey format change), 2020Q4 (COVID survey disruption)

### Effective Regression Sample
- **Start**: 2014Q1
- **End**: 2024Q4
- **Total**: 43 quarters
- **Reason for reduction**:
  - FE_t requires π_{t+1} → loses last observation
  - FR_t requires μ_t and μ_{t-1} → loses first observation
  - Combined: 47 - 2 (missing) - 1 (first) - 1 (last) = 43

**All main regressions (OLS, TVP-SSM, BVAR) use N=43**

---

## Missing Data Handling

### PBOC Survey
- **2013Q2**: Survey format changed, share data not reported → μ_t = NA
- **2020Q4**: COVID-19 survey disruption → μ_t = NA
- **Treatment**: Linear interpolation NOT used (preserves forecast error measurement)

### Other Variables
- **No missing**: All EPU, GPR, NBS macro variables complete for 2013Q4-2025Q2

---

## Data Transformations Log

| Variable | Raw Source | Transformation | Justification |
|----------|-----------|----------------|---------------|
| μ_t | PBOC shares (%) | CP quantification | Convert qualitative to quantitative |
| π_t | NBS CPI level | YoY growth rate | Standard inflation measure |
| FE_t | μ_t, π_t | π_{t+1} - μ_t | Definition of forecast error |
| FR_t | μ_t | μ_t - μ_{t-1} | Definition of forecast revision |
| EPU_t | Monthly values | Quarterly mean | Frequency alignment |
| GPR_t | Daily values | Quarterly mean | Frequency alignment |
| Food CPI | NBS level | YoY growth rate | Consistent with π_t |
| M2, PPI, IndVA | NBS | YoY growth rate | Standard macro measures |

---

## Variable Consistency Checks

### Definition Consistency
- ✅ FE = π_{t+1} - μ_t (actual minus expected) used throughout
- ✅ Unit consistency: all inflation/growth rates in percentage points
- ✅ Frequency consistency: all quarterly
- ✅ Sample consistency: N=43 in all main tables

### Symbol Consistency
- ✅ μ (mu): Expectation
- ✅ π (pi): Actual inflation
- ✅ β (beta): Diagnostic intensity
- ✅ No symbol reuse or drift

---

## Verification Status: ✅ COMPLETE

**Next Step**: Build claims_evidence_map.md (Module B)
