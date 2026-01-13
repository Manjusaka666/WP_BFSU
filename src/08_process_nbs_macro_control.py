\
"""
Process NBS macro controls (long format) into monthly wide and quarterly series.

Inputs (do not edit):
  data/raw/nbs_macro_control.csv

Outputs:
  data/intermediate/nbs_macro_monthly_wide.csv   monthly wide table (date index)
  data/intermediate/nbs_macro_quarterly.csv      quarterly panel-ready table (quarter key)
  outputs/tables/nbs_series_coverage.tex         coverage summary

Important:
  - CPI_YoY and PPI_YoY in the raw file are indices (same period last year = 100).
    We convert to YoY inflation rates: (index - 100) in percentage points.
  - GDP_YoY in the raw file is actually quarterly GDP level (time_code like 2000A/2000B/2000C/2000D).
    We keep GDP_level and compute GDP_yoy_pct = 100 * (GDP_level / GDP_level_{t-4} - 1).
"""
from __future__ import annotations
import argparse
from pathlib import Path
import pandas as pd
import numpy as np

from _paths import RAW_DIR, INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

RAW_FILE = RAW_DIR / "nbs_macro_control.csv"

_QMAP = {"A": 1, "B": 2, "C": 3, "D": 4}

def parse_quarter_code(s: str) -> str:
    s = str(s).strip()
    if len(s) != 5 or s[-1] not in _QMAP:
        raise ValueError(f"Unexpected quarterly time_code: {s}")
    year = int(s[:4])
    q = _QMAP[s[-1]]
    return f"{year}Q{q}"

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=str, default=str(RAW_FILE))
    args = ap.parse_args()

    raw = Path(args.raw)
    if not raw.exists():
        raise FileNotFoundError(f"Missing NBS raw file: {raw}")

    df = pd.read_csv(raw)
    required = {"time_code", "value", "series_name", "frequency"}
    if not required.issubset(df.columns):
        raise ValueError(f"NBS raw must contain columns: {sorted(required)}")

    df["series_name"] = df["series_name"].astype(str)

    # Monthly block
    m = df[df["frequency"].astype(str).str.lower().eq("monthly")].copy()
    m["date"] = pd.to_datetime(m["time_code"].astype(str), format="%Y%m", errors="coerce")
    m = m.dropna(subset=["date"])
    m["value"] = pd.to_numeric(m["value"], errors="coerce")
    m = m.dropna(subset=["value"])
    m_wide = m.pivot_table(index="date", columns="series_name", values="value", aggfunc="mean").sort_index()

    # Convert raw indices to rates
    # IMPORTANT: Raw data "CPI_YoY" is actually MoM Index (e.g. 100.9 = 0.9% MoM increase)
    # Early data (2000) contains zeros which would break cumulative product
    
    if "CPI_YoY" in m_wide.columns:
        m_wide["CPI_MoM_Idx"] = m_wide["CPI_YoY"]
        m_wide["CPI_MoM"] = m_wide["CPI_MoM_Idx"] - 100.0
        
        # Find first non-zero index to start cumulative product
        first_valid_idx = m_wide[m_wide["CPI_MoM_Idx"] > 0].index.min()
        
        if pd.notna(first_valid_idx):
            # Reconstruct CPI Level from first valid month (Base=100 at start)
            m_wide.loc[first_valid_idx:, "CPI_Level"] = (
                100.0 * (1.0 + m_wide.loc[first_valid_idx:, "CPI_MoM"] / 100.0).cumprod()
            )
            # Compute true YoY: (Level_t / Level_{t-12} - 1) * 100
            m_wide["CPI_YoY_Rate"] = 100.0 * (m_wide["CPI_Level"] / m_wide["CPI_Level"].shift(12) - 1.0)
        else:
            m_wide["CPI_Level"] = np.nan
            m_wide["CPI_YoY_Rate"] = np.nan
    
    if "PPI_YoY" in m_wide.columns:
        m_wide["PPI_MoM_Idx"] = m_wide["PPI_YoY"]
        m_wide["PPI_MoM"] = m_wide["PPI_MoM_Idx"] - 100.0
        
        first_valid_idx = m_wide[m_wide["PPI_MoM_Idx"] > 0].index.min()
        
        if pd.notna(first_valid_idx):
            m_wide.loc[first_valid_idx:, "PPI_Level"] = (
                100.0 * (1.0 + m_wide.loc[first_valid_idx:, "PPI_MoM"] / 100.0).cumprod()
            )
            m_wide["PPI_YoY_Rate"] = 100.0 * (m_wide["PPI_Level"] / m_wide["PPI_Level"].shift(12) - 1.0)
        else:
            m_wide["PPI_Level"] = np.nan
            m_wide["PPI_YoY_Rate"] = np.nan

    out_m = INTERMEDIATE_DIR / "nbs_macro_monthly_wide.csv"
    m_wide.reset_index().to_csv(out_m, index=False, encoding="utf-8-sig")

    # Monthly -> Quarterly (use last month level for QoQ, mean for others)
    # For inflation rates, we usually average monthly YoY rates.
    # For QoQ Annualized, we need (Level_end_Q / Level_end_PrevQ)^4 - 1
    
    # 1. Add quarter column and reset index to prepare for groupby
    qavg = m_wide.copy()
    qavg["quarter"] = qavg.index.to_period("Q").astype(str)
    qavg = qavg.reset_index(drop=True)
    
    # 2. Define aggregation dict
    agg_dict = {}
    for c in qavg.columns:
        if c == "quarter":
            continue
        elif c in ["CPI_Level", "PPI_Level"]:
            agg_dict[c] = "last"  # Take last month of quarter for price levels
        else:
            agg_dict[c] = "mean"
    
    # 3. Aggregate to quarterly
    q_agg = qavg.groupby("quarter", as_index=False).agg(agg_dict)
    
    # 4. Compute Quarterly rates from aggregated Levels
    if "CPI_Level" in q_agg.columns:
        # QoQ Annualized: ((P_t / P_{t-1})^4 - 1) * 100
        q_agg["CPI_QoQ_Ann"] = 100.0 * ((q_agg["CPI_Level"] / q_agg["CPI_Level"].shift(1))**4 - 1.0)
        # Verify YoY from quarterly levels (vs average of monthly YoY)
        q_agg["CPI_YoY_from_Level"] = 100.0 * (q_agg["CPI_Level"] / q_agg["CPI_Level"].shift(4) - 1.0)
        # Rename the averaged 'CPI_YoY_Rate' to 'CPI_YoY' for compatibility
        if "CPI_YoY_Rate" in q_agg.columns:
            q_agg = q_agg.rename(columns={"CPI_YoY_Rate": "CPI_YoY"})

    # Quarterly block (GDP level)
    q = df[df["frequency"].astype(str).str.lower().eq("quarterly")].copy()
    if not q.empty:
        q["quarter"] = q["time_code"].apply(parse_quarter_code)
        q["value"] = pd.to_numeric(q["value"], errors="coerce")
        q = q.dropna(subset=["value"])
        q_wide = q.pivot_table(index="quarter", columns="series_name", values="value", aggfunc="mean").reset_index()
        if "GDP_YoY" in q_wide.columns:
            q_wide = q_wide.rename(columns={"GDP_YoY": "GDP_level"})
            q_wide = q_wide.sort_values("quarter")
            # compute YoY growth from 4-quarter lag
            q_wide["GDP_yoy_pct"] = 100.0 * (q_wide["GDP_level"] / q_wide["GDP_level"].shift(4) - 1.0)
        q_agg = q_agg.merge(q_wide, on="quarter", how="left")

    out_q = INTERMEDIATE_DIR / "nbs_macro_quarterly.csv"
    q_agg.sort_values("quarter").to_csv(out_q, index=False, encoding="utf-8-sig")

    # Coverage table
    cov_rows = []
    for col in sorted(qavg.columns):
        if col == "quarter":
            continue
        s = qavg[col]
        cov_rows.append({
            "series": col,
            "n_nonmissing": int(s.notna().sum()),
            "start": qavg.loc[s.first_valid_index(), "quarter"] if s.notna().any() else "",
            "end": qavg.loc[s.last_valid_index(), "quarter"] if s.notna().any() else "",
        })
    cov = pd.DataFrame(cov_rows)
    write_three_line_table(
        cov,
        TAB_DIR / "nbs_series_coverage.tex",
        caption="NBS Macro Control Variables Coverage (Quarterly)",
        label="tab:nbs_coverage",
        notes=[
            "CPI\\_YoY, PPI\\_YoY are YoY indices (100 = same as last year); transformed to inflation rates: Index - 100.",
            "GDP\\_level is nominal GDP; GDP\\_yoy\\_pct is computed as 4-quarter lag growth."
        ],
        float_format="{:.0f}",
    )

    print(f"[NBS] wrote: {out_m}")
    print(f"[NBS] wrote: {out_q}")
    print(f"[NBS] wrote: {TAB_DIR/'nbs_series_coverage.tex'}")

if __name__ == "__main__":
    main()
