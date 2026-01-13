\
"""
Build the final quarterly panel dataset for estimation.

Inputs:
  data/intermediate/pboc_depositor_survey_quarterly.csv
  data/intermediate/pboc_infl_exp_index.csv
  data/intermediate/epu_quarterly.csv
  data/intermediate/gpr_quarterly.csv
  data/intermediate/nbs_macro_quarterly.csv
  data/intermediate/food_cpi_quarterly.csv
  data/intermediate/pboc_expected_inflation_cp.csv   (optional; created by 05_carlson_parkin_quantify.py)

Outputs:
  data/processed/panel_quarterly.csv
  outputs/tables/sample_overview.tex
  outputs/tables/desc_stats.tex

Design choices (paper-level fixes):
  1) Explicitly document sample start (PBOC available from 2011Q1 in our constructed series).
  2) Include Food CPI control (Food_CPI_YoY_qavg) to address "pork cycle" concerns.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import pandas as pd
import numpy as np

from _paths import INTERMEDIATE_DIR, PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

def _require(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")

def _desc(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    d = df[cols].describe(percentiles=[0.25, 0.5, 0.75]).T
    d = d.rename(columns={"50%": "median"})
    return d[["count","mean","std","min","25%","median","75%","max"]].reset_index(names="variable")

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=str, default=str(PROCESSED_DIR / "panel_quarterly.csv"))
    args = ap.parse_args()

    pboc = INTERMEDIATE_DIR / "pboc_depositor_survey_quarterly.csv"
    pboc_idx = INTERMEDIATE_DIR / "pboc_infl_exp_index.csv"
    epu_q = INTERMEDIATE_DIR / "epu_quarterly.csv"
    gpr_q = INTERMEDIATE_DIR / "gpr_quarterly.csv"
    nbs_q = INTERMEDIATE_DIR / "nbs_macro_quarterly.csv"
    food_q = INTERMEDIATE_DIR / "food_cpi_quarterly.csv"
    cp_q = INTERMEDIATE_DIR / "pboc_expected_inflation_cp.csv"

    for p in [pboc, pboc_idx, epu_q, gpr_q, nbs_q, food_q]:
        _require(p)

    df_pboc = pd.read_csv(pboc)
    if "report_quarter" in df_pboc.columns and "quarter" not in df_pboc.columns:
        df_pboc = df_pboc.rename(columns={"report_quarter": "quarter"})
    if "price_expectation_index" in df_pboc.columns and "infl_exp_index" not in df_pboc.columns:
        df_pboc = df_pboc.rename(columns={"price_expectation_index": "infl_exp_index"})
    if "quarter" not in df_pboc.columns:
        raise ValueError("pboc_depositor_survey_quarterly.csv must contain 'quarter' or 'report_quarter'.")

    # Cross-check index-only file
    idx = pd.read_csv(pboc_idx)
    if "future_price_expectation_index" in idx.columns:
        idx = idx.rename(columns={"future_price_expectation_index": "infl_exp_index_alt"})
    df = df_pboc.merge(idx, on="quarter", how="left")

    # Merge uncertainty and macro controls
    df = df.merge(pd.read_csv(epu_q), on="quarter", how="left")
    df = df.merge(pd.read_csv(gpr_q), on="quarter", how="left")
    df = df.merge(pd.read_csv(nbs_q), on="quarter", how="left")
    df = df.merge(pd.read_csv(food_q), on="quarter", how="left")

    # Optional CP quantified expectations
    if cp_q.exists():
        df = df.merge(pd.read_csv(cp_q)[["quarter","mu_cp","sigma_cp","effective_sample_share","delta_used"]], on="quarter", how="left")

    # Sort by quarter
    df["_q"] = pd.PeriodIndex(df["quarter"], freq="Q")
    df = df.sort_values("_q").drop(columns=["_q"])

    # Save processed panel
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False, encoding="utf-8-sig")

    # Sample overview table (explicitly show 2011 start)
    nonmissing_key = df["infl_exp_index"].notna()
    start_q = df.loc[nonmissing_key, "quarter"].iloc[0] if nonmissing_key.any() else ""
    end_q = df.loc[nonmissing_key, "quarter"].iloc[-1] if nonmissing_key.any() else ""
    overview = pd.DataFrame([{
        "pboc_sample_start": start_q,
        "pboc_sample_end": end_q,
        "n_quarters": int(nonmissing_key.sum()),
        "note": "PBOC depositor survey quarterly series starts from 2011Q1 (based on current scrape and alignment).",
    }])
    write_three_line_table(
        overview,
        TAB_DIR / "sample_overview.tex",
        caption="Sample Coverage and Start Date",
        label="tab:sample_overview",
        notes=[
            "The core survey series comes from PBOC Urban Depositors Survey (Quarterly).",
            "Future extensions can expand the sample if earlier data becomes available."
        ],
        float_format="{:.0f}",
    )

    # Descriptive statistics for key variables
    key_cols = []
    for c in ["infl_exp_index","mu_cp","CPI_YoY","CPI_QoQ_Ann","Food_CPI_YoY_qavg","epu_qavg","gpr_qavg","Ind_Value_Added_YoY","M2_YoY"]:
        if c in df.columns:
            key_cols.append(c)
    desc = _desc(df.dropna(subset=["quarter"]), key_cols)
    write_three_line_table(
        desc,
        TAB_DIR / "desc_stats.tex",
        caption="Descriptive Statistics of Key Variables (Quarterly)",
        label="tab:desc_stats",
        notes=["Mean/Std calculated using available sample. See data appendix for variable definitions."],
        float_format="{:.3f}",
    )

    print(f"[PANEL] wrote: {out}")
    print(f"[PANEL] wrote: {TAB_DIR/'sample_overview.tex'}")
    print(f"[PANEL] wrote: {TAB_DIR/'desc_stats.tex'}")

if __name__ == "__main__":
    main()
