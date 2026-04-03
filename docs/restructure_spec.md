# JPE-Macro Restructure Specification

## Paper: Diagnostic Inflation Expectations in China
## Author: Jingle Fu (BFSU)
## Target: Journal of Political Economy: Macroeconomics

## Core Result
CFPS household panel (N≈13,700, 7 waves 2010-2022): revision-error coefficient β = -0.55 (p < 0.001) with province-wave FE. Households that revise inflation expectations upward subsequently overshoot. Consistent with diagnostic expectations (Bordalo, Gennaioli, Shleifer 2020).

## Three Data Sources (hierarchy)
1. **CFPS panel** (primary): 7 biennial waves, ~13,700 respondents, 3-point price expectations, province-wave FE identification
2. **PBoC Urban Depositor Survey** (corroboration): 2011Q1-2025Q3, N=32 quarterly, β₁ = -2.24 (p=0.055), Carlson-Parkin quantification
3. **CHFS 2011** (mechanism): ~8,400 households, 5-point expectations (A4008), info channels (A4001), risk attitude (A4003). Cross-sectional channel test is NULL (β = -0.005, SE = 0.022). Forward-tracking: income 2013 β=0.022 (null), 2015 β=0.106 (p<0.10).

## Key Supporting Results
- Mechanism horse race: lagged-error λ = -0.60 (p=0.005), revision coefficient attenuates in joint spec
- Heterogeneity: overreaction is pervasive across income, education, urban/rural (null on interactions)
- Time-varying β_t from Bayesian SSM: intensifies during crises, relaxes in calm periods
- Local projections: revision shocks move errors within 1 quarter, attenuate after
- Salience IV: reduced form -0.41, but F=1.16 (weak). Directional only.
- Policy rule: de-biasing reduces MAE by 17%, improves 68% CI coverage from 42% to 67%
- NK welfare: overreaction at θ=0.55 raises consumption variance loss by 37.6% vs RE

## CHFS Channel Test (IMPORTANT - result is NULL)
High-media coefficient = -0.005 (SE=0.022) after province FE. Null result. Interpretation: overreaction is event-driven (temporal, CFPS captures this) not channel-driven (persistent cross-sectional). Rules out channel-driven version of both diagnostic and rigidity models.

## Main Text Structure (~42 pages text)

### Section 1: Introduction (2 pages MAX)
- Paragraph 1: Question + main answer + key number (β=-0.55)
- Paragraph 2: Identification in one sentence, three contributions
- Paragraph 3: What the paper does NOT establish (limits)
- Paragraph 4: Roadmap (3-4 sentences)
- NO literature survey, NO throat-clearing, NO "this paper is the first to..."

### Section 2: Conceptual Framework (4 pages)
- Diagnostic expectations model: representativeness heuristic, testable prediction (negative revision-error coefficient)
- Information rigidity model: sticky information, testable prediction (positive lagged-error coefficient OR negative but with gradual accumulation)
- Discriminating predictions: what signs/patterns distinguish them
- Keep mathematical notation minimal. State predictions as inequalities.

### Section 3: Data (5 pages)
- 3.1 CFPS: sample, expectations variable, cleaning, summary stats
- 3.2 PBoC Depositor Survey: quarterly series, Carlson-Parkin (brief, details in appendix)
- 3.3 CHFS: 2011 wave, A4008/A4001/A4003, panel linkage
- 3.4 Macroeconomic controls: CPI, food CPI, GPR, EPU
- One summary statistics table combining all sources

### Section 4: Empirical Strategy (4 pages)
- Main specification: revision-error regression with province-wave FE
- Identification assumptions and threats
- IV as corroboration only (1 paragraph, details in appendix)
- Pre-trend and selection checks

### Section 5: Main Results (9 pages)
- 5.1 CFPS baseline (Table 1: panel columns with progressive controls)
- 5.2 Aggregate corroboration (Table 2: PBoC quarterly, bounds)
- 5.3 Mechanism horse race (Table 3: nested diagnostic + rigidity)
- 5.4 CHFS information-channel test (Table 4: 5-column, null result)
- 5.5 Dynamic response (Figure: local projections with 90% bands)

### Section 6: Mechanism Competition (6 pages)
- 6.1 Time-varying diagnostic coefficient (Figure: β_t path from SSM, details in appendix)
- 6.2 State-dependent activation (salience states)
- 6.3 BVAR structural evidence (Figure: IRFs, details in appendix)
- 6.4 Reconciling the evidence: both channels active, diagnostic dominates in revision dynamics

### Section 7: Heterogeneity and Dynamics (5 pages)
- 7.1 Demographic interactions (Table: income, education, urban/rural - all null)
- 7.2 Economic-state heterogeneity
- 7.3 CHFS forward-tracking (1 paragraph + table reference, details in appendix)

### Section 8: Policy Implications (5 pages)
- 8.1 Forecast adjustment rule (derivation, formula)
- 8.2 Out-of-sample backtest (Figure: actual vs adjusted path)
- 8.3 NK welfare calculation (Table: welfare loss under diagnostic vs RE)

### Section 9: Conclusion (2 pages)
- Three contributions restated concretely
- Limitations (honest, specific)
- Two extensions
- No puffery, no "future looks bright"

## Online Appendix Structure
- A: Carlson-Parkin Quantification (from current Section 4)
- B: Bayesian State-Space Model (from current A1)
- C: BVAR Details (from current A2)
- D: Data Construction (from current A3)
- E: Salience IV Details (from current Section 5 IV parts)
- F: Robustness (from current Section 10 + A4)
- G: CHFS Forward-Tracking (from current 09b)
- H: Additional Tables and Figures

## JPE-Macro Style Requirements

### Tables
- Panel structure: Panel A, Panel B headers
- Dependent variable in column headers or first row
- Controls row: "Province FE" Yes/No, "Wave FE" Yes/No, "Demographics" Yes/No
- Bottom rows: Observations, R², Clusters
- Notes: clustering, significance convention (* p<0.10, ** p<0.05, *** p<0.01)
- Use \toprule, \midrule, \bottomrule (booktabs)
- No vertical lines ever
- Multi-column results with proper \multicolumn headers

### Figures
- PDF vector graphics
- Shaded confidence bands (not dashed lines) for IRFs
- Clean sans-serif axis labels
- No gridlines
- Grayscale-safe (use Okabe-Ito palette)
- Panel labels: (a), (b), (c) not (A), (B), (C)

### Prose
- Active voice, first person singular
- One idea per paragraph
- Short sentences preferred
- Economic magnitudes before statistical significance
- No: "underscores", "highlights", "serves as", "leveraging", "crucial", "novel"
- No em-dash overuse
- No rule-of-three padding
- US English (labor, favor) - standard for JPE

### Math
- Define all notation on first use
- Minimize display equations in main text (save for key specifications)
- Inline math for simple expressions
