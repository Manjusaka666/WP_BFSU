# Referee-1 Attack List and Iteration Log

## Measurement module
- Attack: Carlson-Parkin mapping may be sensitive to uncertain responses and threshold calibration.
- Fix: Added lower/upper bound mapping and explicit effective-sample diagnostics (`cp_bounds.tex`, `cp_coverage.tex`).
- Remaining risk: threshold delta fixed at 0.5pp may still be restrictive in stress episodes.
- Severity: medium

## Identification module
- Attack: Exclusion of media-congestion instrument can be violated by common macro shocks.
- Fix: Added controls, placebo outcomes, anticipation test, permutation-instrument placebo, AR-style interval.
- Remaining risk: first-stage strength is weak (NW F=1.164), so IV-based causal claims are not publication-ready.
- Severity: critical

## Baseline and heterogeneity
- Attack: Negative revision coefficient may be driven by time-aggregation or mechanical overlap.
- Fix: Distinct construction of revision and forecast error, robustness controls, state interactions, monotonicity checks.
- Remaining risk: no household micro panel to test within-group slopes directly.
- Severity: medium

## Mechanism competition
- Attack: Information-rigidity proxy may be underspecified in aggregate data.
- Fix: Horse-race regressions include lagged forecast errors and uncertainty interactions.
- Remaining risk: rigidity may require richer survey expectations distribution to identify separately.
- Severity: medium

## Dynamic and policy modules
- Attack: Local projections and backtests may overfit short samples.
- Fix: horizon-by-horizon reporting, IV LP comparison, rolling-window backtest with explicit metrics.
- Remaining risk: confidence bands remain wide at long horizons.
- Severity: medium

## Bayesian modules
- Attack: Bayesian model could hide weak fit or poor mixing.
- Fix: mandatory Rhat/ESS, trace plots, prior/posterior predictive checks, prior sensitivity table.
- Remaining risk: higher-dimensional nonlinear alternatives not explored due data length.
- Severity: medium

## Fatal issues checkpoint
- Fatal issue candidate: no province-level exposure panel for staggered DiD.
- Resolution: switched main spine to salience-IV path allowed by protocol; documented boundary in `limitations_and_scope.md`.
- Current status: one unresolved fatal issue remains for top-tier causal standards: weak instrument strength in the salience-IV design.
