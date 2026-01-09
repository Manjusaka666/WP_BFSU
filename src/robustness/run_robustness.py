#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Run a battery of robustness checks for SSM and BVAR.

Outputs:
  outputs/robustness/ssm_summary.tex
  outputs/robustness/bvar_summary.tex
"""

from __future__ import annotations
import subprocess
from pathlib import Path
import sys
import pandas as pd

# Add parent directory to path for utils_latex
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

from utils_latex import write_three_line_table

PANEL = ROOT / "data" / "processed" / "panel_quarterly.csv"
OUT = ROOT / "outputs" / "robustness"
OUT.mkdir(parents=True, exist_ok=True)


def run(cmd):
    print("\n$", " ".join(cmd))
    subprocess.check_call(cmd)


def read_ssm_beta(outdir: Path) -> dict:
    beta = pd.read_csv(outdir / "beta_path.csv")
    mean_beta = beta["beta_mean"].mean()
    share_neg = (beta["beta_mean"] < 0).mean()
    sig_neg = (beta["beta_p95"] < 0).sum()
    return {
        "mean_beta": mean_beta,
        "share_negative": share_neg,
        "n_sig_neg_90": int(sig_neg),
        "start": beta["quarter"].iloc[0],
        "end": beta["quarter"].iloc[-1],
        "T": int(beta.shape[0]),
    }


def read_bvar_acc(outdir: Path) -> dict:
    acc = pd.read_csv(outdir / "acceptance.csv").iloc[0].to_dict()
    return {
        "accept_rate": float(acc["accept_rate"]),
        "accepted_draws": int(acc["accepted_draws"]),
        "posterior_draws": int(acc["posterior_draws"]),
    }


def main():
    py = sys.executable

    # ---------- SSM specs ----------
    ssm_specs = [
        (
            "SSM_baseline",
            dict(
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                z_cols=["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"],
                x_cols=["epu_qavg", "gpr_qavg"],
                standardize_yH=0,
            ),
        ),
        (
            "SSM_Z_food_only",
            dict(
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                z_cols=["Food_CPI_YoY_qavg"],
                x_cols=["epu_qavg", "gpr_qavg"],
                standardize_yH=0,
            ),
        ),
        (
            "SSM_X_epu_only",
            dict(
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                z_cols=["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"],
                x_cols=["epu_qavg"],
                standardize_yH=0,
            ),
        ),
        (
            "SSM_X_gpr_only",
            dict(
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                z_cols=["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"],
                x_cols=["gpr_qavg"],
                standardize_yH=0,
            ),
        ),
        (
            "SSM_alt_expect_index",
            dict(
                exp_var="infl_exp_index",
                infl_var="CPI_YoY",
                z_cols=["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"],
                x_cols=["epu_qavg", "gpr_qavg"],
                standardize_yH=1,
            ),
        ),
    ]

    ssm_rows = []
    for name, spec in ssm_specs:
        outdir = OUT / name
        cmd = [
            py,
            str(ROOT / "src" / "20_bayes_state_space_diagnostic.py"),
            "--panel",
            str(PANEL),
            "--exp_var",
            spec["exp_var"],
            "--infl_var",
            spec["infl_var"],
            "--z_cols",
            *spec["z_cols"],
            "--x_cols",
            *spec["x_cols"],
            "--standardize_yH",
            str(spec["standardize_yH"]),
            "--outdir",
            str(outdir),
        ]
        run(cmd)
        m = read_ssm_beta(outdir)
        m["spec"] = name
        ssm_rows.append(m)

    df_ssm = pd.DataFrame(ssm_rows)
    write_three_line_table(
        df_ssm,
        OUT / "ssm_summary.tex",
        caption="SSM robustness checks summary",
        label="tab:ssm_robustness",
        notes=["Summary of beta_t diagnostics across specifications."],
        float_format="{:.3f}",
    )

    # ---------- BVAR specs ----------
    bvar_specs = [
        (
            "BVAR_baseline_p2",
            dict(
                vars=[
                    "mu_cp",
                    "CPI_YoY",
                    "Ind_Value_Added_YoY",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                p=2,
            ),
        ),
        (
            "BVAR_p1",
            dict(
                vars=[
                    "mu_cp",
                    "CPI_YoY",
                    "Ind_Value_Added_YoY",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                p=1,
            ),
        ),
        (
            "BVAR_p4",
            dict(
                vars=[
                    "mu_cp",
                    "CPI_YoY",
                    "Ind_Value_Added_YoY",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                p=4,
            ),
        ),
        (
            "BVAR_add_food",
            dict(
                vars=[
                    "mu_cp",
                    "CPI_YoY",
                    "Ind_Value_Added_YoY",
                    "Food_CPI_YoY_qavg",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="mu_cp",
                infl_var="CPI_YoY",
                p=2,
            ),
        ),
        (
            "BVAR_alt_infl",
            dict(
                vars=[
                    "mu_cp",
                    "CPI_YoY_idx",
                    "Ind_Value_Added_YoY",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="mu_cp",
                infl_var="CPI_YoY_idx",
                p=2,
            ),
        ),
        (
            "BVAR_alt_expect_index",
            dict(
                vars=[
                    "infl_exp_index",
                    "CPI_YoY",
                    "Ind_Value_Added_YoY",
                    "epu_qavg",
                    "gpr_qavg",
                ],
                exp_var="infl_exp_index",
                infl_var="CPI_YoY",
                p=2,
            ),
        ),
    ]

    bvar_rows = []
    for name, spec in bvar_specs:
        outdir = OUT / name
        cmd = [
            py,
            str(ROOT / "src" / "30_bvar_sign_restrictions.py"),
            "--panel",
            str(PANEL),
            "--vars",
            *spec["vars"],
            "--exp_var",
            spec["exp_var"],
            "--infl_var",
            spec["infl_var"],
            "--p",
            str(spec["p"]),
            "--H",
            "12",
            "--fe_kmax",
            "4",
            "--outdir",
            str(outdir),
        ]
        run(cmd)
        m = read_bvar_acc(outdir)
        m["spec"] = name
        bvar_rows.append(m)

    df_bvar = pd.DataFrame(bvar_rows)
    write_three_line_table(
        df_bvar,
        OUT / "bvar_summary.tex",
        caption="BVAR robustness checks summary",
        label="tab:bvar_robustness",
        notes=["Summary of acceptance rates across specifications."],
        float_format="{:.3f}",
    )

    print("\n[ROBUSTNESS] wrote:", (OUT / "ssm_summary.tex").as_posix())
    print("[ROBUSTNESS] wrote:", (OUT / "bvar_summary.tex").as_posix())


if __name__ == "__main__":
    main()
