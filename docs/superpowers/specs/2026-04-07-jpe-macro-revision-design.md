# JPE-Macro Revision Design Spec

## Paper
**Food Price Salience and Inflation Expectation Overreaction: Evidence from China**
Author: Jingle Fu (BFSU)
Target: Journal of Political Economy: Macroeconomics
Date: 2026-04-07

## Problem Statement

The original manuscript was desk-rejected from JPE-Macro. The referee
identified five fatal weaknesses:

1. **Mechanical negative correlation** in the CFPS design: revision and
   forecast error share price_exp_t on both sides.
2. **No credible exogenous variation**: IV is weak (F=1.16), aggregate
   N=32.
3. **Internal inconsistencies**: sample windows, inflation concepts,
   MCMC settings differ across text/tables/code.
4. **Overclaims**: language exceeds what the evidence supports.
5. **Contribution**: does not clear novelty threshold vs. existing
   literature with better-measured expectations.

The referee suggested rebuilding around food-price shocks with regional
heterogeneity.

## Core Identification: Two-Equation Salience Test

### Treatment Variable

MeatShock_{p,t-1→t} = cumulative log meat CPI change in province p
during the inter-wave window:

    MeatShock_p = Σ_m ln(MeatCPI_{pm} / 100)

summed over months between consecutive CFPS fieldwork dates. Meat CPI
data: province-level monthly, 31 provinces, 2011-2025, preceding
month=100.

### Equation 1 (Expectation Response)

    μ_{ipt} = α₁ + β₁ × MeatShock_{p,t-1→t} + γ₁'X_{ipt}
              + δ_p + δ_t + ε₁

- μ ∈ {-1, 0, 1} (fall/same/rise)
- β₁ > 0: meat shocks shift expectations upward
- Estimated by OLS on ordinal coding; ordered probit as robustness

### Equation 2 (Headline CPI Pass-Through)

    π_{p,t→t+1}^headline = α₂ + β₂ × MeatShock_{p,t-1→t}
                            + δ_p + δ_t + ε₂

- Province-level regression (N ≈ 31 × 5 wave-pairs = 155)
- β₂ ≈ 0: meat shocks do not predict FUTURE headline CPI
- Uses province-level headline CPI (YoY) from Excel files

### Equation 3 (Reduced-Form Forecast Error)

    FE_{ipt} = α₃ + β₃ × MeatShock_{p,t-1→t} + γ₃'X_{ipt}
               + δ_p + δ_t + ε₃

- FE_{ipt} = π_{p,t→t+1}^realized - g(μ_{it})
- β₃ < 0: larger meat shocks → more negative forecast errors
- g() converts ordinal to quantitative using province-level CP

### Formal Overreaction Test

Estimate Eq 1 and Eq 2 on the same province-wave sample. Report a
Wald test of H₀: β₁ = β₂. Rejection with β₁ > β₂ is the statistical
footprint of overreaction.

Implementation: seemingly-unrelated regression (SUR) or stacked
regression with equation indicator interactions. Cluster SEs at
province level in both.

## Natural Experiment: African Swine Fever

ASF arrived in China August 2018 via contaminated imported pork. It
spread differentially across provinces based on pig farming intensity.
CFPS waves bracket the episode:

- 2016: pre-ASF baseline
- 2018: ASF onset (August 2018, fieldwork mostly H1)
- 2020: peak aftermath
- 2022: recovery

### Shift-Share IV (Bartik)

Instrument: PreASF_PigIntensity_p × ΔNationalMeatCPI_t

- PreASF_PigIntensity: province-level pig inventory or output share
  from NBS agricultural yearbook, measured pre-2018
- ΔNationalMeatCPI: national meat CPI change in the relevant window
- First-stage: predicts province-level MeatShock
- Identifying assumption: pre-shock pig intensity affects expectations
  only through local meat price exposure

Source for pig intensity: NBS China Statistical Yearbook, "Livestock"
tables. If unavailable at province level, use provincial agricultural
GDP share as proxy.

### Event-Study Figure

Dynamic coefficients for expectation outcome and future headline CPI
around ASF onset:

- x-axis: wave pairs (2012-14, 2014-16, 2016-18, 2018-20, 2020-22)
- y-axis: coefficient on MeatShock
- Separate lines for Eq 1 and Eq 2
- Pre-trend test: coefficients for pre-ASF wave pairs should be near
  zero or flat

## Spillover Diagnostics

Province-level meat shocks may spill across borders through trade and
media.

1. Add neighbor-province average MeatShock as control
2. Re-estimate with Conley (1999) spatial HAC SEs using province
   centroid distances (cutoff: 500km)
3. Add national meat CPI as explicit control to isolate within-province
   deviation from national trend

## Data Pipeline

### Single Inflation Concept

Province-level headline CPI, converted from preceding-month=100 to
YoY percentage change:

    CPI_YoY_{p,m} = (Π_{j=m-11}^{m} MoM_{p,j}/100) - 1) × 100

All forecast errors use this concept. No switching between QoQ and YoY.

### Single Sample Window

- CFPS: waves 2012, 2014, 2016, 2018, 2020, 2022 (drop 2010: no
  expectations variable)
- Province CPI: 2011-2025 monthly
- PBoC: 2011Q1-2023Q4 (locked)

### Pipeline Scripts (new or modified)

| Script | Purpose |
|--------|---------|
| src/15_build_province_cpi.R | Parse province CPI Excel files, compute YoY |
| src/16_build_meat_shock.R | Parse meat/grain/egg CPI, compute MeatShock by province-wave |
| src/17_build_cfps_panel_v2.R | Rebuild CFPS panel with province-level CPI match, fixed FE proxy |
| src/18_pig_intensity.R | Construct pre-ASF pig intensity by province |
| src/41_models_salience.R | Estimate Eq 1, 2, 3, Wald test, event study |
| src/42_models_heterogeneity_v2.R | Heterogeneity interactions with meat shock |
| src/43_models_spillover.R | Spillover diagnostics, Conley SEs |
| src/44_models_bartik_iv.R | Shift-share IV |
| src/82_figures_v2.R | New figures: spaghetti plot, event study, binscatter |

### Existing Scripts (keep, modify for consistency)

| Script | Change |
|--------|--------|
| src/05_carlson_parkin_quantify.R | Lock to YoY CPI, single δ |
| src/10_build_panel.R | Lock sample to 2011Q1-2023Q4 |
| src/40_models_baseline.R | Demote to appendix output |
| src/80_figures_tables.R | Keep for appendix figures |

## Main Text Tables

| # | Content | Columns | Key |
|---|---------|---------|-----|
| 1 | Summary statistics | Multi-panel: CFPS, Province CPI, Meat CPI, PBoC | Descriptives |
| 2 | Eq 1: MeatShock → expectations | 5 cols: bivariate, +controls, +prov FE, +wave FE, +prov+wave FE | β₁ |
| 3 | Eq 2: MeatShock → headline CPI | 3 cols: bivariate, +prov FE, +prov+wave FE | β₂ |
| 4 | Formal overreaction: Eq 1 vs Eq 2 | SUR/stacked, Wald test p-value | β₁ vs β₂ |
| 5 | Eq 3: MeatShock → forecast error | 5 cols mirroring Table 2 | β₃ |
| 6 | Heterogeneity interactions | 4 cols: income, education, urban, food share | Interactions |
| 7 | Shift-share IV | First stage + reduced form + 2SLS | Bartik |
| 8 | Spillover diagnostics | 3 cols: baseline, +neighbor shock, Conley SEs | Spatial |
| 9 | Placebo: grain and egg shocks | 3 cols per commodity | Placebo |
| 10 | PBoC aggregate sign check | 3 cols with progressive controls | Consistency |

All tables: booktabs, multicolumn headers, no p-values (stars only),
dependent variable in header, controls indicator rows, N/R²/clusters
in footer. No vertical lines.

## Main Text Figures

| # | Content | Type |
|---|---------|------|
| 1 | Province meat CPI trajectories, ASF highlighted | Spaghetti + shaded event window |
| 2 | Event study: dynamic coefficients around ASF | Two-panel: expectations + CPI |
| 3 | Binscatter: meat shock vs subsequent forecast error | Scatter + fitted line |
| 4 | Heterogeneity forest plot | Coefficient + 95% CI by subgroup |

PDF vector, Okabe-Ito palette, shaded confidence bands, no gridlines,
panel labels (a), (b).

## Appendix Structure

| App | Content |
|-----|---------|
| A | Data construction and variable dictionary |
| B | Province CPI construction details |
| C | Measurement robustness (3-point coding alternatives) |
| D | CFPS revision-error regressions (fixed, demoted) |
| E | Carlson-Parkin quantification |
| F | PBoC aggregate details |
| G | Bayesian SSM (time-varying β_t) |
| H | BVAR structural consistency |
| I | Consistency audit table |
| J | Contribution positioning vs literature |

## Prose Standards

- US English (labor, favor) for JPE
- Active voice, first person singular
- One idea per paragraph
- Economic magnitudes before statistical significance
- No: "underscores", "highlights", "serves as", "leveraging",
  "crucial", "novel", "first to"
- No em-dash overuse, no rule-of-three
- Concrete claims tied to table/figure references

## Sections (LaTeX files)

| File | Section | Target pages |
|------|---------|-------------|
| 01_introduction.tex | Introduction | 2 |
| 02_background.tex | Background and Framework | 4 |
| 03_data.tex | Data | 5 |
| 04_strategy.tex | Empirical Strategy | 4 |
| 05_results.tex | Main Results | 8 |
| 06_heterogeneity.tex | Heterogeneity | 4 |
| 07_robustness.tex | Robustness and Extensions | 5 |
| 08_conclusion.tex | Conclusion | 2 |

## What Is Dropped

- IV exercise with GPR instrument (F=1.16, not salvageable)
- CHFS channel test (null, adds complexity)
- NK welfare calibration (illustrative, not policy-invariant)
- Policy backtest/forecasting application
- Section 04_measurement.tex (folded into data section + appendix)
- Sections 08b, 09, 09b (CHFS mechanism, policy, consequences)

## What Is New

- Province-level meat/grain/egg CPI data pipeline
- Two-equation salience identification
- Shift-share IV with pig intensity
- ASF event study
- Spillover diagnostics with Conley SEs
- Formal Wald test of overreaction
- Contribution positioning table

## Implementation Phases

### Phase 1: Data Pipeline (parallel)
- Build province CPI pipeline (src/15)
- Build meat shock variable (src/16)
- Construct pig intensity (src/18)
- Rebuild CFPS panel with province matching (src/17)

### Phase 2: Estimation (parallel, after Phase 1)
- Salience models: Eq 1, 2, 3 (src/41)
- Heterogeneity (src/42)
- Spillover diagnostics (src/43)
- Bartik IV (src/44)

### Phase 3: Figures and Tables (parallel, after Phase 2)
- Generate all new figures (src/82)
- Format tables to JPE-Macro standard

### Phase 4: Paper Writing (sequential)
- Rewrite all 8 sections
- Build appendix sections
- Fix all label/reference issues from audit
- Lock internal consistency

### Phase 5: Verification
- Compile LaTeX, fix errors
- Cross-check all numbers against output files
- Run consistency audit script
