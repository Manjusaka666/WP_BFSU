\
"""
Carlson–Parkin (CP) quantification for PBOC qualitative price expectations.

Inputs (do not edit):
  data/intermediate/pboc_depositor_survey_quarterly.csv   (needs response shares)
  data/intermediate/nbs_macro_quarterly.csv              (baseline CPI inflation rate: CPI_YoY)

Outputs:
  data/intermediate/pboc_expected_inflation_cp.csv       columns:
    quarter, pi_baseline, mu_cp, sigma_cp, delta_used, effective_sample_share
  outputs/tables/cp_coverage.tex                         coverage summary (three-line table)
  outputs/tables/cp_head.tex                             first rows preview (three-line table)

Notes:
  - PBOC shares are typically reported in percent; we convert to fractions.
  - When 'uncertain' share is available, we exclude it and renormalize.
  - If shares are missing for a quarter, CP is not computed (mu_cp and sigma_cp = NaN).
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import norm

from _paths import INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

PBOC_FILE = INTERMEDIATE_DIR / "pboc_depositor_survey_quarterly.csv"
NBS_Q_FILE = INTERMEDIATE_DIR / "nbs_macro_quarterly.csv"
OUT_FILE = INTERMEDIATE_DIR / "pboc_expected_inflation_cp.csv"

def _to_frac(x: float) -> float:
    if pd.isna(x):
        return np.nan
    x = float(x)
    return x/100.0 if x > 1.0 else x

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--pboc", type=str, default=str(PBOC_FILE))
    ap.add_argument("--nbs_q", type=str, default=str(NBS_Q_FILE))
    ap.add_argument("--out", type=str, default=str(OUT_FILE))
    ap.add_argument("--delta", type=float, default=0.5, help="Tolerance band delta (pp)")
    args = ap.parse_args()

    pboc = pd.read_csv(args.pboc)
    nbsq = pd.read_csv(args.nbs_q)

    if "report_quarter" in pboc.columns and "quarter" not in pboc.columns:
        pboc = pboc.rename(columns={"report_quarter": "quarter"})
    if "quarter" not in pboc.columns:
        raise ValueError("PBOC quarterly file must contain 'quarter' or 'report_quarter'.")

    share_cols = ["price_up_share", "price_same_share", "price_down_share", "price_uncertain_share"]
    for c in share_cols:
        if c not in pboc.columns:
            pboc[c] = np.nan

    if "CPI_YoY" not in nbsq.columns:
        raise ValueError("nbs_macro_quarterly.csv must contain 'CPI_YoY' (inflation rate in pp).")

    base = nbsq[["quarter", "CPI_YoY"]].rename(columns={"CPI_YoY": "pi_baseline"})
    df = pboc[["quarter"] + share_cols].merge(base, on="quarter", how="left").sort_values("quarter")

    # fractions
    for c in share_cols:
        df[c] = df[c].map(_to_frac)

    # effective sample (exclude uncertain)
    eff = 1.0 - df["price_uncertain_share"].fillna(0.0)
    df["effective_sample_share"] = eff

    # renormalize
    p_up = df["price_up_share"] / eff
    p_down = df["price_down_share"] / eff

    # CP mapping
    delta = float(args.delta)
    z_u = norm.ppf(1.0 - p_up.clip(1e-6, 1-1e-6))
    z_d = norm.ppf(p_down.clip(1e-6, 1-1e-6))

    sigma = 2.0 * delta / (z_u - z_d)
    mu = df["pi_baseline"] + delta - sigma * z_u

    # mask invalid quarters
    valid = df["pi_baseline"].notna() & df["price_up_share"].notna() & df["price_down_share"].notna() & (eff > 0.5)
    df["sigma_cp"] = np.where(valid, sigma, np.nan)
    df["mu_cp"] = np.where(valid, mu, np.nan)
    df["delta_used"] = delta

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    df[["quarter","pi_baseline","mu_cp","sigma_cp","delta_used","effective_sample_share"]].to_csv(out, index=False, encoding="utf-8-sig")

    # Coverage + preview tables
    cov = pd.DataFrame([{
        "n_quarters_total": int(df.shape[0]),
        "n_quarters_cp": int(df["mu_cp"].notna().sum()),
        "start": df["quarter"].iloc[0],
        "end": df["quarter"].iloc[-1],
        "delta_pp": delta,
    }])
    write_three_line_table(
        cov,
        TAB_DIR / "cp_coverage.tex",
        caption="Carlson–Parkin（CP）定量化：可用样本覆盖情况",
        label="tab:cp_coverage",
        notes=[
            "CP 需要问卷中“上涨/下降/看不准”等占比数据；缺失占比的季度无法计算。",
            "pi\\_baseline 使用 NBS CPI 同比通胀率（百分点）。"
        ],
        float_format="{:.0f}",
    )

    head = df[["quarter","pi_baseline","mu_cp","sigma_cp","effective_sample_share"]].head(10)
    write_three_line_table(
        head,
        TAB_DIR / "cp_head.tex",
        caption="CP 定量化通胀预期（前10期示例）",
        label="tab:cp_head",
        notes=["mu\\_cp 为定量化的下一季度通胀预期（同比，百分点）。"],
        float_format="{:.3f}",
    )

    print(f"[CP] wrote: {out}")
    print(f"[CP] wrote: {TAB_DIR/'cp_coverage.tex'}")
    print(f"[CP] wrote: {TAB_DIR/'cp_head.tex'}")

if __name__ == "__main__":
    main()
