# Evidence Ledger

## C-Intro-01
- Statement: Diagnostic revisions predict subsequent forecast errors with a negative coefficient.
- Evidence: `outputs/tables/identification_main.tex`, `outputs/tables/ols_baseline.tex`
- Code: `src/35_identification_main.R`, `src/40_models_baseline.R`
- Assumptions: media-congestion exclusion, correct timing alignment, HAC validity in short sample
- Alt explanations: omitted common shocks, simultaneous policy interventions
- Robustness: placebo outcomes, anticipation test, permutation IV placebo (`outputs/tables/placebo_tests.tex`)
- Status: ⚠️ generated, but causal strength limited by weak-IV diagnostics (F=1.164)

## C-Ident-02
- Statement: The instrument is relevant and not weak enough to drive the main sign mechanically.
- Evidence: `outputs/tables/iv_first_stage.tex`, `outputs/figures/identification_first_stage.pdf`
- Code: `src/35_identification_main.R`
- Assumptions: first-stage linear approximation, robust F proxy in single-IV setup
- Alt explanations: relevance from shared omitted trend
- Robustness: Anderson-Rubin style interval, reduced-form consistency
- Status: ❌ weak-IV threshold not met (F=1.164; AR interval wide)

## C-Het-03
- Statement: Diagnostic intensity strengthens under high salience/uncertainty states.
- Evidence: `outputs/tables/heterogeneity_interactions.tex`, `outputs/tables/heterogeneity_monotonicity.tex`, `outputs/figures/heterogeneity_salience.pdf`
- Code: `src/45_models_heterogeneity.R`
- Assumptions: tercile partition captures state dependence rather than noise
- Alt explanations: regime composition shifts
- Robustness: interaction and monotonicity checks
- Status: ⚠️ generated; interpretation is descriptive because IV relevance is weak

## C-Mech-04
- Statement: Data favor diagnostic over information-rigidity channel in horse-race regressions.
- Evidence: `outputs/tables/mechanism_horse_race.tex`, `outputs/tables/revision_predicts_error.tex`
- Code: `src/50_mechanism_competition.R`
- Assumptions: lagged error adequately proxies rigidity in aggregate data
- Alt explanations: misspecified persistence dynamics
- Robustness: joint specification with uncertainty interaction
- Status: ✅ generated in current pipeline run (2026-02-11)

## C-Dyn-05
- Statement: Revision shocks move forecast errors quickly; inflation response is smaller over the same horizons.
- Evidence: `outputs/tables/lp_dynamic.tex`, `outputs/figures/lp_forecast_error.pdf`, `outputs/figures/lp_inflation.pdf`
- Code: `src/60_lp_dynamic.R`
- Assumptions: LP linearity and horizon-wise exogeneity in instrumented setup
- Alt explanations: horizon-specific omitted shocks
- Robustness: OLS LP and IV LP side-by-side
- Status: ✅ generated in current pipeline run (2026-02-11)

## C-Policy-06
- Statement: A coefficient-mapped policy adjustment improves out-of-sample forecast metrics.
- Evidence: `outputs/tables/policy_backtest_metrics.tex`, `outputs/tables/policy_rule_formula.tex`, `outputs/figures/policy_backtest_path.pdf`
- Code: `src/70_policy_backtest.R`
- Assumptions: rolling-window stationarity, policy rule stability
- Alt explanations: luck from small backtest sample
- Robustness: naive baseline comparison and coverage diagnostics
- Status: ✅ generated in current pipeline run (2026-02-11)

## C-Bayes-07
- Statement: Bayesian state-space estimates pass convergence and predictive diagnostics under prior sensitivity.
- Evidence: `outputs/tables/mcmc_diagnostics.tex`, `outputs/tables/ppc_summary.tex`, `outputs/tables/prior_sensitivity.tex`, `outputs/figures/beta_t.pdf`
- Code: `src/20_bayes_state_space_diagnostic.jl`
- Assumptions: Gaussian state-space structure, shrinkage prior plausibility
- Alt explanations: short-sample overfitting, posterior multimodality
- Robustness: multi-chain Rhat/ESS, prior and posterior predictive checks
- Status: ✅ generated in current pipeline run (2026-02-11)

## C-BVAR-08
- Statement: Appendix BVAR dynamics are structurally consistent with the diagnostic chain under non-circular restrictions.
- Evidence: `outputs/tables/bvar_acceptance.tex`, `outputs/tables/bvar_irf_summary.tex`, `outputs/tables/bvar_fevd.tex`, `outputs/tables/bvar_sensitivity.tex`
- Code: `src/30_bvar_sign_restrictions.jl`
- Assumptions: salience-anchored sign restrictions identify interpretable shocks
- Alt explanations: low acceptance and rotation fragility
- Robustness: acceptance accounting, prior and lag sensitivity
- Status: ✅ generated in current pipeline run (2026-02-11)
