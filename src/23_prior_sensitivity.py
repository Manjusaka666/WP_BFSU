#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Prior sensitivity for the TVP-SSM.

Runs two alternative prior settings (looser vs tighter) plus the baseline,
then summarizes beta_t path and a simple fit metric.

Outputs:
  outputs/tables/prior_sensitivity.tex
  outputs/robustness/SSM_prior_{baseline,loose,tight}/
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

ROOT = Path(__file__).resolve().parents[1]
ROBUST_SSM = ROOT / "src" / "robustness" / "ssm_tvp_diagnostic.py"
PANEL = PROCESSED_DIR / "panel_quarterly.csv"

Z_COLS = ["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"]
X_COLS = ["epu_qavg", "gpr_qavg"]


def run_ssm_setting(setting: dict) -> None:
    cmd = [
        sys.executable,
        str(ROBUST_SSM),
        "--panel",
        str(PANEL),
        "--outdir",
        str(setting["outdir"]),
        "--aR0",
        str(setting["aR0"]),
        "--bR0",
        str(setting["bR0"]),
        "--aQ0",
        str(setting["aQ0"]),
        "--bQ0",
        str(setting["bQ0"]),
        "--beta0_mean",
        str(setting["beta0_mean"]),
        "--beta0_var",
        str(setting["beta0_var"]),
    ]
    subprocess.check_call(cmd, cwd=str(ROOT))


def load_panel() -> pd.DataFrame:
    panel = pd.read_csv(PANEL)
    panel["_q"] = pd.PeriodIndex(panel["quarter"], freq="Q")
    panel = panel.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)

    panel["infl_lead1"] = panel["CPI_QoQ_Ann"].shift(-1)
    panel["FE_next"] = panel["infl_lead1"] - panel["mu_cp"]
    panel["FR"] = panel["mu_cp"] - panel["mu_cp"].shift(1)

    use = panel.dropna(subset=["FE_next", "FR"] + Z_COLS + X_COLS).copy()
    use = use.reset_index(drop=True)
    return use


def compute_loglik(y: np.ndarray, H: np.ndarray, Z: np.ndarray, alpha: float, beta: np.ndarray, gamma: np.ndarray, R: float) -> float:
    mu = alpha + beta * H + Z @ gamma
    resid = y - mu
    return float(-0.5 * len(y) * np.log(2 * np.pi * R) - 0.5 * (resid ** 2).sum() / R)


def summarize_setting(setting: dict, use: pd.DataFrame) -> dict:
    outdir = Path(setting["outdir"])
    beta_df = pd.read_csv(outdir / "beta_path.csv")
    params = pd.read_csv(outdir / "params_summary.csv")

    beta_mean = beta_df["beta_mean"].to_numpy(float)
    beta_avg = float(beta_mean.mean())
    beta_min = float(beta_mean.min())
    beta_max = float(beta_mean.max())
    share_neg = float((beta_mean < 0).mean())

    alpha = float(params.loc[params["param"] == "alpha", "mean"].iloc[0])
    gamma = []
    for col in Z_COLS:
        gamma.append(float(params.loc[params["param"] == f"gamma_{col}", "mean"].iloc[0]))
    gamma = np.asarray(gamma)
    R_var = float(params.loc[params["param"] == "R_var", "mean"].iloc[0])

    y = use["FE_next"].to_numpy(float)
    H = use["FR"].to_numpy(float)
    Z = use[Z_COLS].to_numpy(float)
    Z = (Z - Z.mean(axis=0)) / Z.std(axis=0, ddof=0)

    loglik = compute_loglik(y, H, Z, alpha, beta_mean, gamma, R_var)

    return {
        "Setting": setting["name"],
        "Beta mean": beta_avg,
        "Beta range": f"[{beta_min:.2f}, {beta_max:.2f}]",
        "Share beta<0": f"{share_neg * 100:.1f}\\%",
        "LogLik": loglik,
    }


def main() -> None:
    ensure_dirs()

    settings = [
        {
            "name": "Baseline",
            "outdir": ROOT / "outputs" / "robustness" / "SSM_prior_baseline",
            "aR0": 2.0,
            "bR0": 1.0,
            "aQ0": 2.0,
            "bQ0": 1.0,
            "beta0_mean": 0.0,
            "beta0_var": 1.0,
        },
        {
            "name": "Loose priors",
            "outdir": ROOT / "outputs" / "robustness" / "SSM_prior_loose",
            "aR0": 2.0,
            "bR0": 4.0,
            "aQ0": 2.0,
            "bQ0": 4.0,
            "beta0_mean": 0.0,
            "beta0_var": 4.0,
        },
        {
            "name": "Tight priors",
            "outdir": ROOT / "outputs" / "robustness" / "SSM_prior_tight",
            "aR0": 2.0,
            "bR0": 0.25,
            "aQ0": 2.0,
            "bQ0": 0.25,
            "beta0_mean": 0.0,
            "beta0_var": 0.25,
        },
    ]

    for setting in settings:
        run_ssm_setting(setting)

    use = load_panel()
    rows = [summarize_setting(s, use) for s in settings]
    df = pd.DataFrame(rows)

    write_three_line_table(
        df,
        TAB_DIR / "prior_sensitivity.tex",
        caption="Prior sensitivity for the TVP-SSM",
        label="tab:prior_sensitivity",
        notes=[
            "Baseline priors: R,Q ~ Inv-Gamma(2,1), $\\beta_0$ ~ N(0,1).",
            "Loose priors: R,Q ~ Inv-Gamma(2,4), $\\beta_0$ ~ N(0,4).",
            "Tight priors: R,Q ~ Inv-Gamma(2,0.25), $\\beta_0$ ~ N(0,0.25).",
            "LogLik is total-sample log-likelihood at posterior means and the $\\beta_t$ mean path.",
            "FE/FR are in pp units; controls are standardized as in the TVP-SSM.",
        ],
        float_format="{:.3f}",
    )

    print(f"[Prior Sensitivity] wrote: {TAB_DIR / 'prior_sensitivity.tex'}")


if __name__ == "__main__":
    main()
