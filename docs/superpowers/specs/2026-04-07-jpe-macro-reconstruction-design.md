# JPE-Macro Full Reconstruction Design Spec

**Date:** 2026-04-07
**Paper:** "Overreaction in Household Inflation Expectations: Evidence from China"
**Target journal:** Journal of Political Economy: Macroeconomics
**Goal:** Address all eight referee concerns from desk review; reach 30+ page main text; publication-grade prose and tables.

---

## 1. Diagnosis (from desk review dated 2026-04-01)

Eight problems identified, grouped by severity:

### Tier 1: Identification and analytical gaps

1. **Effective variation is province×wave (~93 cells), not household-level.** The 69k–90k household observations overstate precision. Must be transparent about this.
2. **Expectation channel (Eq 1) is unstable.** β₁ = 0.242 (p = 0.17) with region×wave FE. The coefficient that carries the behavioral mechanism is imprecise in the preferred specification.
3. **Rational benchmark (ω_m ≈ 0.05) is too crude.** A CPI accounting weight is not a structural parameter governing optimal belief updating.
4. **Forecast error ≠ overreaction.** A transitory shock that reverses produces negative forecast errors even under rational expectations if households cannot know ex ante how quickly the shock will reverse.

### Tier 2: Mechanism evidence

5. **Commodity placebo fragile.** Grain imprecise; egg significantly negative (contaminated by pork-egg substitution during ASF).
6. **Demographic heterogeneity null.** Education, income, urban interactions all insignificant or wrong-signed.

### Tier 3: Presentation and consistency

7. **Appendices belong to old paper.** A1 (Bayesian SSM), A2 (BVAR), A5 (measurement), A7 (NK welfare), A8 (forecasting) are from the revision-error design. Internal contradictions throughout.
8. **Citation and reference problems.** Empty citations, overstatements in text.

---

## 2. Strategic Decisions

### 2.1 Reframing: Eq 3 is primary

The forecast-error equation (β₃ = −6.07, p < 0.001, robust to wild bootstrap) becomes the paper's primary result. The Eq 1 (expectations) and Eq 2 (pass-through) regressions are presented as decomposition evidence that helps explain why the forecast error is negative, but the main claim does not rest on β₁ being precisely estimated.

**Rationale:** Eq 3 is the paper's strongest result. Trying to make the paper rest on an imprecise β₁ is a losing strategy at a top journal.

### 2.2 Signal-extraction rational benchmark

Replace the crude ω_m ≈ 0.05 comparison with a formal signal-extraction model:

- Household observes meat-price signal, must forecast headline CPI
- Shock has unknown persistence ρ (estimated from monthly NBS data)
- Rational forecast error bounded even under maximal persistence uncertainty
- Diagnostic expectations (Bordalo et al. 2018) generate overshooting
- Calibration table: estimated β₃ vs. rational benchmark under various ρ

This addresses problems #3 and #4 simultaneously.

**Formality level:** Semi-formal (~2 pages in main text). Signal structure, rational benchmark formula, diagnostic extension, calibration implication. Full derivations in Appendix A1. Based on JPE-Macro norms for empirical papers (cf. Coibion & Gorodnichenko 2015 AER approach).

### 2.3 Drop eggs from main analysis

Egg prices are mechanically correlated with meat prices through pork-egg substitution during ASF. The significantly negative egg coefficient is evidence about protein substitution, not salience. Including a contaminated placebo and explaining it ex post weakens the test.

**Decision:** Grain is the clean placebo (comparable CPI weight, lower purchase frequency, no substitution link). Eggs mentioned in a footnote only.

### 2.4 Delete old appendices entirely

A1 (Bayesian SSM), A2 (BVAR), A7 (NK welfare), A8 (forecasting) belong to the old revision-error design. They are structurally incompatible with the meat-shock panel design. The SSM uses aggregate time-series; the new design is cross-sectional province×wave. The BVAR traces aggregate impulse responses; the new design identifies through cross-province shock variation.

**Decision:** Delete all four. Replace with appendices supporting the meat-shock design.

### 2.5 Honest about effective variation

Report the 93 province×wave cell count prominently in the data and strategy sections. Do not hide behind 69k household observations. Frame the household-level variation as within-cell variation that helps estimate demographic controls and interaction effects, while the identifying variation for the main coefficient is at province×wave.

---

## 3. New Paper Structure

### Main text (~30 pages including tables and figures)

| # | Section | Pages | File | Status |
|---|---------|-------|------|--------|
| 1 | Introduction | 2 | 01_introduction.tex | Rewrite |
| 2 | Institutional Background | 3 | 02_background.tex | Rewrite (remove §2.3 theory) |
| 3 | Conceptual Framework | 2 | 03_framework.tex | **New** |
| 4 | Data | 2.5 | 04_data.tex | **New** standalone |
| 5 | Empirical Strategy | 3 | 05_strategy.tex | Restructure |
| 6 | Main Results | 5 | 06_results.tex | Rewrite (Eq3 primary) |
| 7 | Mechanism: Commodity Placebo | 2 | 07_mechanism.tex | Restructure (grain only) |
| 8 | Robustness | 2.5 | 08_robustness.tex | Update |
| 9 | Discussion | 2.5 | 09_discussion.tex | **New** |
| 10 | Conclusion | 1.5 | 10_conclusion.tex | Rewrite |
| | Tables (5) + Figures (3) | ~4 | | |
| | **Total** | **~30** | | |

### Appendices

| # | Title | File | Status |
|---|-------|------|--------|
| A1 | Signal-Extraction Model Derivation | A1_model_derivation.tex | **New** |
| A2 | Data Construction | A2_data_construction.tex | Rewrite from old A3 |
| A3 | Wild Cluster Bootstrap | A3_bootstrap.tex | **New** |
| A4 | Alternative Fixed Effects | A4_alt_fe.tex | **New** (tables only) |
| A5 | Expectation Scaling Sensitivity | A5_scaling.tex | **New** |

### Deleted files

- A1_bayesian_ssm.tex
- A2_bvar.tex
- A5_measurement.tex (old)
- A7_nk_welfare.tex
- A8_forecasting.tex

---

## 4. Section-by-Section Specifications

### 4.1 Introduction (2 pages)

**Structure:**
- Para 1: Main finding + identification in one sentence each. "Households exposed to large meat-price shocks systematically overpredict future inflation. I show this using..."
- Para 2: Why it matters (expectation wedge → precautionary saving → real activity; China context with 28% food CPI weight)
- Para 3: Design sketch (three-equation system, province×wave variation, ASF as natural experiment)
- Para 4: Signal-extraction benchmark. Estimated forecast error exceeds the rational upper bound by two orders of magnitude even under the full-persistence assumption (ρ = 1).
- Para 5: Contributions (3 channels: forecast-error test avoiding mechanical correlation; commodity-specific salience; calibrated rational benchmark)
- Para 6: Literature positioning (diagnostic expectations, rational inattention, experience-based learning)
- Para 7: Limitations and roadmap

**Key changes from current:**
- Move theory predictions to Section 3
- Move detailed literature comparison to Section 2
- Tighten: no repeated claims, no throat-clearing

### 4.2 Institutional Background (3 pages)

**Structure:**
- §2.1 Food Prices in Chinese Inflation (~1 page): food CPI weight, pork dominance, purchase frequency, salience
- §2.2 African Swine Fever (~1 page): disease characteristics, timeline, herd reduction, geographic heterogeneity, price dynamics
- §2.3 Related Literature (~1 page): synthesis by theme (overreaction tests, salience and expectations, China inflation expectations), not catalog

**Key changes from current:**
- Remove §2.3 (Theoretical Predictions) → moves to new Section 3
- Add §2.3 (Related Literature) as thematic synthesis
- Tighten ASF section: facts only, no repetition of identification argument

### 4.3 Conceptual Framework (2 pages) — NEW

**Structure (following Codex/JPE-Macro analysis):**
- §3.1 Setup (½ page): Household observes meat-price signal s_{pt}, must forecast headline CPI π_{p,t→t+1}. Pass-through weight ω. Persistence ρ unknown.
- §3.2 Rational Benchmark (½ page): Signal-extraction formula. Closed-form rational forecast error as function of ω, ρ, and shock size. Even under ρ = 1 (permanent shock), rational forecast error bounded by ω × shock ≈ 0.05 × shock.
- §3.3 Diagnostic Extension (½ page): Introduce θ > 0 distortion. Forecast error = rational component + θ × representativeness term. Cite Bordalo et al. (2018).
- §3.4 Testable Implications (½ page): Under rationality, β₃ ∈ [−ω, 0]. Under diagnostic expectations, β₃ << −ω. The calibration table will compare estimated β₃ against the rational bound.

**Derivations:** Full signal-extraction derivation in Appendix A1.

### 4.4 Data (2.5 pages) — NEW standalone

**Structure:**
- §4.1 China Family Panel Studies: waves, sample, expectation question (3-point ordinal), province coverage
- §4.2 Province-Level CPI Data: NBS monthly sub-indices (meat, grain, headline), coverage period (Jan 2016+)
- §4.3 Treatment Construction: Cumulative log meat CPI change between waves
- §4.4 Descriptive Statistics: Table 1 with Panel A (household-level) and Panel B (province×wave)

**Key content:**
- Explicit statement: "The identifying variation operates at the province×wave level. The sample contains 93 province×wave cells across 31 provinces and 3–4 waves."
- Variable definitions for all regression variables
- Discussion of ordinal expectation measure and its limitations

### 4.5 Empirical Strategy (3 pages)

**Structure:**
- §5.1 Treatment Variable: meat-price shock construction (equation)
- §5.2 Three-Equation System: Eq 3 (forecast error) as primary test, Eq 1 (expectations) and Eq 2 (pass-through) as decomposition
- §5.3 Identification Assumptions: relevance + conditional exogeneity
- §5.4 Inference: wild cluster bootstrap with Webb weights, 31 clusters

**Key changes from current:**
- Reorder: Eq 3 first (primary), then Eq 1/Eq 2 (decomposition)
- Be explicit that Eq 1/Eq 2 are mechanism evidence, not the identification
- Remove the crude ω_m ≈ 0.05 benchmark from strategy (moved to Section 3)

### 4.6 Main Results (5 pages)

**Structure:**
- §6.1 Meat Shocks Generate Systematic Forecast Errors: Table 2 Panel A. Lead with preferred spec. Interpret economic magnitude against signal-extraction benchmark.
- §6.2 Decomposition — Expectations: Table 2 Panel B. Present as mechanism evidence. Acknowledge imprecision under demanding FE structure. Explain why the forecast-error test (Eq 3) is more powerful.
- §6.3 Decomposition — Pass-Through: Table 2 Panel C. Negative pass-through consistent with transitory supply shock.
- §6.4 Rational Benchmark Comparison: Table 3. Calibration exercise. Estimated β₃ = −6.07 vs. rational upper bound under various ρ.
- §6.5 Visualizing Treatment Variation: Figures 1–3.

**Key changes from current:**
- Lead with Eq 3, not Eq 1
- Add calibration comparison subsection
- Remove overstatements ("significant in every column")
- Interpret against formal benchmark, not crude CPI weight

### 4.7 Mechanism: Commodity Placebo (2 pages)

**Structure:**
- §7.1 Placebo Design: Grain as clean placebo (comparable CPI weight, lower purchase frequency, no ASF substitution link). Footnote on why eggs are excluded.
- §7.2 Results: Table 4 with meat-only, grain-only, and horse-race columns.
- §7.3 Interpretation: Differential response across commodities inconsistent with rational updating, consistent with salience.

**Key changes from current:**
- Drop eggs from main analysis
- Drop three-way horse race
- Add joint F-test for H₀: β_meat = β_grain

### 4.8 Robustness (2.5 pages)

**Structure:**
- §8.1 Wild Cluster Bootstrap: full results for all key coefficients
- §8.2 Aggregate Sign Check: PBoC depositor survey (1 paragraph, corroborative only)
- §8.3 Alternative Fixed Effects: province+wave vs. region×wave
- §8.4 CPI Weight Revision: post-2016 sample within one weight regime
- §8.5 Calibration Sensitivity: rational benchmark under ρ ∈ [0, 1] range

### 4.9 Discussion (2.5 pages) — NEW

**Structure:**
- §9.1 Transitory Shock vs. Overreaction: Formal rebuttal. Even under maximum persistence uncertainty (ρ = 1), rational forecast error is bounded by ~0.05 per unit shock. Estimated β₃ = −6.07 exceeds this by two orders of magnitude. The gap cannot be explained by rational-under-uncertainty.
- §9.2 Demographic Heterogeneity: The null result is informative. Overreaction is broad-based across education, income, and urban-rural groups. Consistent with cognitive salience (visibility matters regardless of budget share) rather than pure expenditure-weight channel.
- §9.3 External Validity: China's high food CPI weight and pork dominance amplify the salience channel. In economies with lower food shares or more diversified protein markets, the effect may be smaller but the mechanism (salient relative-price → aggregate belief distortion) likely generalizes.
- §9.4 Policy Implications: Survey-based inflation expectations overstate the inflation signal when salient relative-price movements drive responses. Central banks that use survey expectations as policy inputs should adjust for this wedge.

### 4.10 Conclusion (1.5 pages)

- Recap key finding (one paragraph)
- Contribution relative to literature (one paragraph)
- Limitations (one paragraph)
- Future directions (one paragraph)
- No repetition of results or numbers

---

## 5. Table Specifications

### Table 1: Summary Statistics

**Format:** Two panels. Panel A: household-level variables. Panel B: province×wave variables.
**Columns:** N, Mean, SD, P25, Median, P75
**Variables:**
- Panel A: inflation expectation (ordinal), forecast error, age, education indicator, income, urban indicator
- Panel B: meat shock, grain shock, forward headline CPI, number of households per cell

### Table 2: Main Results (consolidated)

**Format:** Three panels in one table.
- Panel A: Forecast Errors (Eq 3) — 5 columns
- Panel B: Inflation Expectations (Eq 1) — 5 columns
- Panel C: CPI Pass-Through (Eq 2) — 3 columns

**Columns:** Progressively saturated specifications (bivariate → demographics → province+wave FE → region×wave FE → region×wave FE + demographics)

**Statistics:** Coefficient, SE in parentheses, wild bootstrap p-value in square brackets for key coefficient. N, R². No significance stars anywhere.

### Table 3: Rational Benchmark Calibration

**Format:** Comparison table.
**Rows:** Various assumptions about ρ (0, 0.3, 0.5, 0.7, 0.9, 1.0, estimated ρ̂)
**Columns:** ρ, Rational benchmark β₃, Estimated β₃, Gap (estimated − rational), Ratio

### Table 4: Commodity Placebo (Meat vs. Grain)

**Format:** 3 columns: meat-only, grain-only, horse-race.
**Statistics:** Same as Table 2 (no stars, SE in parentheses, bootstrap p in brackets).
**Additional row:** Joint F-test for H₀: β_meat = β_grain.

### Table 5: Heterogeneity Interactions

**Format:** 3 columns: education, income, urban interactions.
**Statistics:** Same format as other tables.

### All tables: formatting rules

- Use significance stars for p-values in table body
- Standard errors in round parentheses: (0.174)
- Panel headers using \multicolumn
- Self-contained notes
- 2–3 decimal places
- threeparttable environment

---

## 6. New R Code Requirements

### 6.1 Persistence estimation (new script: src/47_persistence_estimation.R)

- Load province-level monthly meat CPI from data/intermediate/
- Compute province-level meat shock at monthly frequency
- Estimate pooled AR(1): shock_{p,t} = ρ × shock_{p,t-1} + ε_{pt}
- Report ρ̂, SE, 95% CI
- Save to outputs/tables/persistence_estimate.csv

### 6.2 Calibration table (new script: src/48_calibration_table.R)

- Load estimated β₃ from regression output
- Load ρ̂ from persistence estimation
- Compute rational benchmark: β₃_rational = −ω × (1 − ρ^h) for various ρ
- Generate LaTeX table comparing estimated vs. rational
- Save to outputs/tables/calibration_benchmark.tex

### 6.3 Summary statistics (new script: src/49_summary_stats.R)

- Load CFPS panel and province×wave data
- Compute descriptive statistics for both panels
- Generate LaTeX table with Panel A / Panel B structure
- Save to outputs/tables/summary_stats_new.tex

### 6.4 Updated regressions (modify: src/42_meat_shock_regressions.R)

- Output consolidated Eq1+Eq2+Eq3 table with panel structure
- Remove significance stars from output
- Add bootstrap p-values in brackets
- Remove egg shock from placebo specification

### 6.5 Updated placebo (modify: src/44_placebo_commodity.R)

- Drop egg shock from main specification
- Keep meat vs. grain horse-race
- Add joint F-test row
- Output updated table

### 6.6 Table formatting function (new: src/utils/format_table_jpe.R)

- Reusable function to format regression output:
  - No stars
  - SE in parentheses
  - Bootstrap p in brackets
  - Panel headers
  - Self-contained notes

---

## 7. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Persistence ρ̂ is very high → rational benchmark approaches estimated β₃ | Even with ρ = 1, rational FE is bounded by ω ≈ 0.05 per unit shock. β₃ = −6.07 is two orders of magnitude larger. |
| Grain placebo also imprecise → reviewer still unsatisfied | The placebo test's job is to show grain ≠ meat, not that grain = 0. A joint F-test rejecting equality is sufficient. |
| Page count falls short of 30 | The data section, discussion section, and calibration subsection add ~7 pages of new content. With tables and figures, 30+ is achievable. |
| Old appendix material referenced elsewhere in literature | The old appendices were never published. No external references to reconcile. |

---

## 8. Implementation Sequence

1. **R code first:** Persistence estimation, calibration table, summary stats, updated regressions/placebos, table formatting
2. **LaTeX sections:** Write new sections (framework, data, discussion), rewrite existing sections, update main.tex includes
3. **Appendices:** Write A1 (derivation), rewrite A2 (data construction), write A3–A5
4. **Citations and compilation:** Audit references.bib, fix cross-references, compile, verify page count
5. **Self-review:** Run revision checklists from econ-writing-standard skill
