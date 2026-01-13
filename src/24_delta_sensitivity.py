#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Delta sensitivity for Carlson-Parkin quantification.

For delta in {0.3, 0.5, 0.7}, this script:
  - Computes mu_cp via the CP pipeline
  - Builds a merged quarterly panel
  - Computes summary stats for mu_cp / FE / FR
  - Estimates the baseline OLS (full controls) with HAC(4)
  - Runs the TVP-SSM and summarizes beta_t

Outputs:
  outputs/tables/delta_sensitivity.tex
  outputs/robustness/cp_delta_*.csv
  outputs/robustness/panel_delta_*.csv
  outputs/robustness/SSM_delta_*/
"""
from __future__ import annotations

import sys
import subprocess
from pathlib import Path

import numpy as np
import pandas as pd
import importlib.util

from _paths import INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

ROOT = Path(__file__).resolve().parents[1]
ROBUST_SSM = ROOT / "src" / "robustness" / "ssm_tvp_diagnostic.py"
CP_SCRIPT = ROOT / "src" / "05_carlson_parkin_quantify.py"

spec = importlib.util.spec_from_file_location("cp_quantify", CP_SCRIPT)
cp_module = importlib.util.module_from_spec(spec)
if spec is None or spec.loader is None:
    raise ImportError(f"Unable to load CP module from {CP_SCRIPT}")
spec.loader.exec_module(cp_module)
compute_cp = cp_module.compute_cp

PBOC_FILE = INTERMEDIATE_DIR / "pboc_depositor_survey_quarterly.csv"
PBOC_IDX = INTERMEDIATE_DIR / "pboc_infl_exp_index.csv"
EPU_Q = INTERMEDIATE_DIR / "epu_quarterly.csv"
GPR_Q = INTERMEDIATE_DIR / "gpr_quarterly.csv"
NBS_Q = INTERMEDIATE_DIR / "nbs_macro_quarterly.csv"
FOOD_Q = INTERMEDIATE_DIR / "food_cpi_quarterly.csv"

Z_COLS = ["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"]


def build_panel(cp_df: pd.DataFrame) -> pd.DataFrame:
    df_pboc = pd.read_csv(PBOC_FILE)
    if "report_quarter" in df_pboc.columns and "quarter" not in df_pboc.columns:
        df_pboc = df_pboc.rename(columns={"report_quarter": "quarter"})
    if "price_expectation_index" in df_pboc.columns and "infl_exp_index" not in df_pboc.columns:
        df_pboc = df_pboc.rename(columns={"price_expectation_index": "infl_exp_index"})
    if "quarter" not in df_pboc.columns:
        raise ValueError("pboc_depositor_survey_quarterly.csv must contain 'quarter' or 'report_quarter'.")

    idx = pd.read_csv(PBOC_IDX)
    if "future_price_expectation_index" in idx.columns:
        idx = idx.rename(columns={"future_price_expectation_index": "infl_exp_index_alt"})

    df = df_pboc.merge(idx, on="quarter", how="left")
    df = df.merge(pd.read_csv(EPU_Q), on="quarter", how="left")
    df = df.merge(pd.read_csv(GPR_Q), on="quarter", how="left")
    df = df.merge(pd.read_csv(NBS_Q), on="quarter", how="left")
    df = df.merge(pd.read_csv(FOOD_Q), on="quarter", how="left")

    cp_cols = ["quarter", "mu_cp", "sigma_cp", "effective_sample_share", "delta_used"]
    df = df.merge(cp_df[cp_cols], on="quarter", how="left")

    df["_q"] = pd.PeriodIndex(df["quarter"], freq="Q")
    df = df.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)
    return df


def _ols_hac(y: np.ndarray, X: np.ndarray, maxlags: int = 4) -> tuple[np.ndarray, np.ndarray]:
    XtX = X.T @ X
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ (X.T @ y)
    resid = y - X @ beta

    n, k = X.shape
    S = np.zeros((k, k))
    # lag 0
    for t in range(n):
        xt = X[t : t + 1].T
        S += (resid[t] ** 2) * (xt @ xt.T)

    # lags 1..L with Bartlett weights
    for l in range(1, maxlags + 1):
        w = 1.0 - l / (maxlags + 1)
        for t in range(l, n):
            xt = X[t : t + 1].T
            xt_lag = X[t - l : t - l + 1].T
            S += w * resid[t] * resid[t - l] * (xt @ xt_lag.T + xt_lag @ xt.T)

    cov = XtX_inv @ S @ XtX_inv
    se = np.sqrt(np.diag(cov))
    return beta, se


def compute_ols_beta(use: pd.DataFrame) -> tuple[float, float]:
    X = use[["FR"] + Z_COLS].to_numpy(float)
    X = np.column_stack([np.ones(X.shape[0]), X])
    y = use["FE"].to_numpy(float)
    beta, se = _ols_hac(y, X, maxlags=4)
    # FR is the second coefficient after the constant
    return float(beta[1]), float(se[1])


def run_ssm(panel_path: Path, outdir: Path) -> Path:
    cmd = [
        sys.executable,
        str(ROBUST_SSM),
        "--panel",
        str(panel_path),
        "--outdir",
        str(outdir),
    ]
    subprocess.check_call(cmd, cwd=str(ROOT))
    return outdir / "beta_path.csv"


def summarize_beta(beta_path: Path) -> tuple[float, float]:
    beta_df = pd.read_csv(beta_path)
    beta_mean = beta_df["beta_mean"].to_numpy(float)
    return float(beta_mean.mean()), float((beta_mean < 0).mean())


def main() -> None:
    ensure_dirs()
    deltas = [0.3, 0.5, 0.7]
    rows = []

    for delta in deltas:
        cp_df = compute_cp(PBOC_FILE, NBS_Q, delta)

        cp_out = ROOT / "outputs" / "robustness" / f"cp_delta_{delta:.1f}.csv"
        cp_out.parent.mkdir(parents=True, exist_ok=True)
        cp_df[["quarter","pi_baseline","mu_cp","sigma_cp","delta_used","effective_sample_share"]].to_csv(
            cp_out, index=False, encoding="utf-8-sig"
        )

        panel = build_panel(cp_df)

        panel_out = ROOT / "outputs" / "robustness" / f"panel_delta_{delta:.1f}.csv"
        panel.to_csv(panel_out, index=False, encoding="utf-8-sig")

        panel["CPI_lead1"] = panel["CPI_QoQ_Ann"].shift(-1)
        panel["FE"] = panel["CPI_lead1"] - panel["mu_cp"]
        panel["FR"] = panel["mu_cp"] - panel["mu_cp"].shift(1)

        use = panel.dropna(subset=["FE", "FR"] + Z_COLS).copy()
        use = use.reset_index(drop=True)

        mu_mean = float(use["mu_cp"].mean())
        mu_std = float(use["mu_cp"].std(ddof=1))
        fe_mean = float(use["FE"].mean())
        fe_std = float(use["FE"].std(ddof=1))
        fr_mean = float(use["FR"].mean())
        fr_std = float(use["FR"].std(ddof=1))
        corr = float(use["FE"].corr(use["FR"]))

        beta_ols, se_ols = compute_ols_beta(use)

        outdir = ROOT / "outputs" / "robustness" / f"SSM_delta_{delta:.1f}"
        beta_path = run_ssm(panel_out, outdir)
        beta_mean, share_neg = summarize_beta(beta_path)

        rows.append({
            "Delta (pp)": f"{delta:.1f}",
            "N": f"{int(len(use))}",
            "Mean mu": f"{mu_mean:.3f}",
            "SD mu": f"{mu_std:.3f}",
            "Mean FE": f"{fe_mean:.3f}",
            "SD FE": f"{fe_std:.3f}",
            "Mean FR": f"{fr_mean:.3f}",
            "SD FR": f"{fr_std:.3f}",
            "Corr(FE,FR)": f"{corr:.3f}",
            "OLS beta (SE)": f"{beta_ols:.3f} ({se_ols:.3f})",
            "TVP mean beta": f"{beta_mean:.3f}",
            "Share beta<0": f"{share_neg * 100:.1f}\\%",
        })

    df = pd.DataFrame(rows)
    write_three_line_table(
        df,
        TAB_DIR / "delta_sensitivity.tex",
        caption="Delta Sensitivity for Carlson-Parkin Quantification",
        label="tab:delta_sensitivity",
        notes=[
            "Summary stats use the OLS sample (non-missing FE, FR, and controls).",
            "$FE_t = CPI_{t+1}^{QoQ,ann} - \\mu_t$ and $FR_t = \\mu_t - \\mu_{t-1}$.",
            "OLS includes Food CPI, M2, and PPI with HAC(4) standard errors.",
            "TVP metrics use the posterior-mean $\\beta_t$ path from the TVP-SSM."
        ],
        float_format="{}",
    )

    print(f"[Delta Sensitivity] wrote: {TAB_DIR / 'delta_sensitivity.tex'}")


if __name__ == "__main__":
    main()
