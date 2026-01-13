#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Model comparison for TVP-SSM vs fixed-parameter baselines.

Outputs:
  outputs/tables/model_comparison.tex
"""
from __future__ import annotations

from pathlib import Path
import numpy as np
import pandas as pd

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"

Z_COLS = ["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"]
X_COLS = ["epu_qavg", "gpr_qavg"]

BASELINE_DIR = Path("outputs/robustness/SSM_prior_baseline")


def load_panel() -> pd.DataFrame:
    panel = pd.read_csv(PANEL_FILE)
    panel["_q"] = pd.PeriodIndex(panel["quarter"], freq="Q")
    panel = panel.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)

    panel["infl_lead1"] = panel["CPI_QoQ_Ann"].shift(-1)
    panel["FE_next"] = panel["infl_lead1"] - panel["mu_cp"]
    panel["FR"] = panel["mu_cp"] - panel["mu_cp"].shift(1)

    use = panel.dropna(subset=["FE_next", "FR"] + Z_COLS + X_COLS).copy()
    use = use.reset_index(drop=True)
    return use


def compute_loglik(y: np.ndarray, H: np.ndarray, Z: np.ndarray,
                   alpha: float, beta: np.ndarray, gamma: np.ndarray, R: float) -> float:
    mu = alpha + beta * H + Z @ gamma
    resid = y - mu
    return float(-0.5 * len(y) * np.log(2 * np.pi * R) - 0.5 * (resid ** 2).sum() / R)


def ols_loglik(y: np.ndarray, X: np.ndarray) -> tuple[float, float]:
    coef, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid = y - X @ coef
    sigma2 = float((resid ** 2).mean())
    loglik = float(-0.5 * len(y) * (np.log(2 * np.pi * sigma2) + 1))
    return loglik, sigma2


def load_tvp_params(outdir: Path) -> tuple[float, np.ndarray, np.ndarray, float]:
    params_file = outdir / "params_summary.csv"
    beta_file = outdir / "beta_path.csv"
    if not params_file.exists():
        raise FileNotFoundError(f"Missing params_summary.csv in {outdir}")
    if not beta_file.exists():
        raise FileNotFoundError(f"Missing beta_path.csv in {outdir}")

    params = pd.read_csv(params_file)
    beta_df = pd.read_csv(beta_file)

    alpha = float(params.loc[params["param"] == "alpha", "mean"].iloc[0])
    gamma = []
    for col in Z_COLS:
        gamma.append(float(params.loc[params["param"] == f"gamma_{col}", "mean"].iloc[0]))
    gamma = np.asarray(gamma)
    R_var = float(params.loc[params["param"] == "R_var", "mean"].iloc[0])

    beta_mean = beta_df["beta_mean"].to_numpy(float)
    return alpha, gamma, beta_mean, R_var


def compute_ic(loglik: float, k: int, T: int) -> tuple[float, float]:
    aic = -2.0 * loglik + 2.0 * k
    bic = -2.0 * loglik + k * np.log(T)
    return aic, bic


def main() -> None:
    ensure_dirs()

    use = load_panel()
    y = use["FE_next"].to_numpy(float)
    H = use["FR"].to_numpy(float)
    Z = use[Z_COLS].to_numpy(float)
    Z = (Z - Z.mean(axis=0)) / Z.std(axis=0, ddof=0)
    T = len(y)

    # OLS baseline: FR only
    X_ols = np.column_stack([np.ones(T), H])
    loglik_ols, _ = ols_loglik(y, X_ols)

    # Fixed-beta SSM: FR + standardized controls
    X_fixed = np.column_stack([np.ones(T), H, Z])
    loglik_fixed, _ = ols_loglik(y, X_fixed)

    # TVP-SSM (EPU+GPR): posterior-mean parameters and beta path
    alpha_tvp, gamma_tvp, beta_tvp, R_tvp = load_tvp_params(BASELINE_DIR)
    loglik_tvp = compute_loglik(y, H, Z, alpha_tvp, beta_tvp, gamma_tvp, R_tvp)

    rows = []

    # k counts coefficients + variance; TVP uses p_eff with time-varying beta_t
    k_ols = 3  # intercept, FR, variance
    k_fixed = 6  # intercept, FR, 3 controls, variance
    k_tvp = 51  # alpha, 3 gamma, 2 d, R, Q, and 43 beta_t

    for model, loglik, k, note in [
        ("OLS (FR only)", loglik_ols, k_ols, "Gaussian OLS baseline"),
        ("SSM (fixed $\\beta$)", loglik_fixed, k_fixed, "OLS with controls"),
        ("TVP-SSM (EPU+GPR)", loglik_tvp, k_tvp, "Posterior-mean TVP"),
    ]:
        aic, bic = compute_ic(loglik, k, T)
        rows.append({
            "Model": model,
            "log_lik": f"{loglik:.1f}",
            "AIC": f"{aic:.1f}",
            "BIC": f"{bic:.1f}",
            "p_eff": f"{k:.1f}",
            "Notes": note,
        })

    df = pd.DataFrame(rows)

    write_three_line_table(
        df,
        TAB_DIR / "model_comparison.tex",
        caption="Model Comparison: Log-Likelihood and Information Criteria",
        label="tab:model_comp",
        notes=[
            "log_lik is total-sample log-likelihood evaluated at point estimates.",
            "For TVP-SSM, log_lik uses posterior-mean parameters and the $\\beta_t$ mean path.",
            "Controls are standardized as in the TVP-SSM; FE/FR are in pp units.",
            "AIC/BIC computed from log_lik and p_eff; p_eff counts time-varying $\\beta_t$ for TVP.",
            "TVP-SSM parameters use posterior means from Table 7 (R_var=9.721, Q_var=1.003).",
        ],
    )

    print(f"[Model Comparison] Wrote: {TAB_DIR / 'model_comparison.tex'}")


if __name__ == "__main__":
    main()
