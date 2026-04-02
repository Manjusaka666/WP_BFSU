#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Small-sample-robust inference for the baseline OLS regression.

Wild bootstrap (Rademacher weights, 5000 replications) and randomization
inference (5000 permutations) for the preferred specification:

    FE_t = alpha + beta * FR_t + gamma' Z_t + epsilon_t

where Z_t = (Food_CPI_YoY_qavg, M2_YoY, PPI_YoY).

Outputs:
    outputs/tables/bootstrap_inference.tex
"""

from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.regression.linear_model import OLS

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"

RNG_SEED = 20240401
N_BOOT = 5000
N_PERM = 5000


def _ols_beta_fr(y: np.ndarray, X: np.ndarray, fr_idx: int) -> float:
    """Return the OLS coefficient on FR (column fr_idx) from y ~ X."""
    # Normal equations: beta = (X'X)^{-1} X'y
    XtX_inv = np.linalg.solve(X.T @ X, np.eye(X.shape[1]))
    beta = XtX_inv @ (X.T @ y)
    return beta[fr_idx]


def main() -> None:
    ensure_dirs()

    # ---- Load and construct variables (same as 15_baseline_ols_regression) ----
    panel = pd.read_csv(PANEL_FILE)
    panel['_q'] = pd.PeriodIndex(panel['quarter'], freq='Q')
    panel = panel.sort_values('_q').drop(columns=['_q']).reset_index(drop=True)

    panel['CPI_lead1'] = panel['CPI_QoQ_Ann'].shift(-1)
    panel['FE'] = panel['CPI_lead1'] - panel['mu_cp']
    panel['FR'] = panel['mu_cp'] - panel['mu_cp'].shift(1)

    controls = ['Food_CPI_YoY_qavg', 'M2_YoY', 'PPI_YoY']
    use = panel.dropna(subset=['FE', 'FR'] + controls).copy().reset_index(drop=True)

    y = use['FE'].values
    X_df = sm.add_constant(use[['FR'] + controls])
    X = X_df.values
    var_names = X_df.columns.tolist()
    fr_idx = var_names.index('FR')
    n = len(y)

    print(f"[Bootstrap] Sample size N = {n}")

    # ---- OLS point estimate with HAC SE ----
    model = OLS(y, X).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    beta_hat = model.params[fr_idx]
    se_hat = model.bse[fr_idx]
    t_stat = model.tvalues[fr_idx]
    p_asym = model.pvalues[fr_idx]

    print(f"[Bootstrap] OLS beta(FR) = {beta_hat:.4f}")
    print(f"[Bootstrap] Asymptotic p-value = {p_asym:.4f}")

    # ---- Restricted residuals for wild bootstrap ----
    # Under H0: beta_FR = 0, estimate the restricted model
    X_r = np.delete(X, fr_idx, axis=1)
    model_r = OLS(y, X_r).fit()
    y_fitted_r = model_r.fittedvalues
    resid_r = model_r.resid

    rng = np.random.default_rng(RNG_SEED)

    # ---- Wild bootstrap (Rademacher weights) ----
    boot_t_stats = np.empty(N_BOOT)
    boot_betas = np.empty(N_BOOT)

    for b in range(N_BOOT):
        # Rademacher weights: +1 or -1 with equal probability
        w = rng.choice([-1.0, 1.0], size=n)
        y_star = y_fitted_r + resid_r * w

        # OLS on bootstrap sample
        beta_b = _ols_beta_fr(y_star, X, fr_idx)
        boot_betas[b] = beta_b

        # Bootstrap t-statistic (using OLS SE, not HAC, for speed)
        XtX_inv = np.linalg.solve(X.T @ X, np.eye(X.shape[1]))
        e_star = y_star - X @ (XtX_inv @ (X.T @ y_star))
        s2 = np.sum(e_star**2) / (n - X.shape[1])
        se_b = np.sqrt(s2 * XtX_inv[fr_idx, fr_idx])
        boot_t_stats[b] = beta_b / se_b if se_b > 0 else 0.0

    # Wild bootstrap p-value (two-sided, based on t-statistic)
    p_wild = np.mean(np.abs(boot_t_stats) >= np.abs(t_stat))

    # Bootstrap percentile 95% CI
    ci_low = np.percentile(boot_betas, 2.5)
    ci_high = np.percentile(boot_betas, 97.5)

    print(f"[Bootstrap] Wild bootstrap p-value = {p_wild:.4f}")
    print(f"[Bootstrap] Bootstrap 95% CI = [{ci_low:.4f}, {ci_high:.4f}]")

    # ---- Randomization inference ----
    perm_betas = np.empty(N_PERM)
    fr_col = X[:, fr_idx].copy()

    for p in range(N_PERM):
        fr_perm = rng.permutation(fr_col)
        X_perm = X.copy()
        X_perm[:, fr_idx] = fr_perm
        perm_betas[p] = _ols_beta_fr(y, X_perm, fr_idx)

    # One-sided: fraction of permuted betas <= actual beta (testing beta < 0)
    p_ri = np.mean(perm_betas <= beta_hat)

    print(f"[Bootstrap] Randomization p-value = {p_ri:.4f}")

    # ---- Generate LaTeX table ----
    def _fmt_stars(val, pval):
        s = f"{val:.3f}"
        if pval < 0.01:
            s += '***'
        elif pval < 0.05:
            s += '**'
        elif pval < 0.10:
            s += '*'
        return s

    rows = [
        {'Statistic': r'OLS Estimate ($\hat{\beta}_{FR}$)',
         'Value': _fmt_stars(beta_hat, p_asym)},
        {'Statistic': r'HAC Standard Error',
         'Value': f"({se_hat:.3f})"},
        {'Statistic': r'Asymptotic $p$-value (HAC)',
         'Value': f"{p_asym:.4f}"},
        {'Statistic': r'Wild Bootstrap $p$-value (Rademacher, $B=5000$)',
         'Value': f"{p_wild:.4f}"},
        {'Statistic': r'Bootstrap 95\% CI',
         'Value': f"[{ci_low:.3f},\\ {ci_high:.3f}]"},
        {'Statistic': r'Randomization $p$-value ($B=5000$)',
         'Value': f"{p_ri:.4f}"},
        {'Statistic': 'Observations',
         'Value': f"{n}"},
    ]

    df_out = pd.DataFrame(rows)

    write_three_line_table(
        df_out,
        TAB_DIR / 'bootstrap_inference.tex',
        caption='Small-Sample Robust Inference for Forecast Revision Coefficient',
        label='tab:bootstrap_inference',
        notes=[
            r'Preferred specification: $FE_t = \alpha + \beta\, FR_t + \gamma_1\, \text{Food CPI}_{t} + \gamma_2\, M2_{t} + \gamma_3\, PPI_{t} + \varepsilon_t$.',
            r'Wild bootstrap uses Rademacher weights ($\pm 1$) with restricted residuals under $H_0\!: \beta = 0$.',
            r'Randomization $p$-value: fraction of 5,000 permutations yielding $\hat{\beta} \leq$ observed $\hat{\beta}$.',
            r'*** $p<0.01$, ** $p<0.05$, * $p<0.1$.',
        ],
        float_format="{}",
    )

    print(f"\n[Bootstrap] Wrote: {TAB_DIR / 'bootstrap_inference.tex'}")


if __name__ == '__main__':
    main()
