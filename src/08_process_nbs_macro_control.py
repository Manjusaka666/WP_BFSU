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

    # Convert index-style YoY to inflation rates
    if "CPI_YoY" in m_wide.columns:
        m_wide["CPI_YoY_idx"] = m_wide["CPI_YoY"]
        m_wide["CPI_YoY"] = m_wide["CPI_YoY_idx"] - 100.0
    if "PPI_YoY" in m_wide.columns:
        m_wide["PPI_YoY_idx"] = m_wide["PPI_YoY"]
        m_wide["PPI_YoY"] = m_wide["PPI_YoY_idx"] - 100.0

    out_m = INTERMEDIATE_DIR / "nbs_macro_monthly_wide.csv"
    m_wide.reset_index().to_csv(out_m, index=False, encoding="utf-8-sig")

    # Monthly -> Quarterly averages
    qavg = m_wide.copy()
    qavg["quarter"] = qavg.index.to_period("Q").astype(str)
    qavg = qavg.reset_index(drop=True).groupby("quarter", as_index=False).mean(numeric_only=True)

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
        qavg = qavg.merge(q_wide, on="quarter", how="left")

    out_q = INTERMEDIATE_DIR / "nbs_macro_quarterly.csv"
    qavg.sort_values("quarter").to_csv(out_q, index=False, encoding="utf-8-sig")

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
        caption="NBS 宏观控制变量覆盖情况（季度频率）",
        label="tab:nbs_coverage",
        notes=[
            "CPI_YoY、PPI_YoY 为同比指数（=100 表示与上年同期持平），本文转化为通胀率：指数-100。",
            "GDP_level 为季度GDP水平，GDP_yoy_pct 按四季度滞后计算同比增速。"
        ],
        float_format="{:.0f}",
    )

    print(f"[NBS] wrote: {out_m}")
    print(f"[NBS] wrote: {out_q}")
    print(f"[NBS] wrote: {TAB_DIR/'nbs_series_coverage.tex'}")

if __name__ == "__main__":
    main()
