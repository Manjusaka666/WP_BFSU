\
"""
Process Food CPI (monthly chain index: last month = 100) into YoY inflation and quarterly averages.

Inputs (do not edit):
  data/raw/nbc_food_CPI.csv

Outputs:
  data/intermediate/food_cpi_monthly.csv         columns: date, Food_CPI_MoM_index, Food_CPI_level, Food_CPI_YoY
  data/intermediate/food_cpi_quarterly.csv       columns: quarter, Food_CPI_YoY_qavg
  outputs/tables/food_cpi_coverage.tex           coverage summary

Rationale:
  Controls for China "pork/food cycle" noise in CPI, addressing common referee concerns.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import pandas as pd
import numpy as np

from _paths import RAW_DIR, INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

RAW_FILE = RAW_DIR / "nbc_food_CPI.csv"
TARGET_ROW_PREFIX = "食品类居民消费价格指数(上月=100)"

def parse_ym(s: str) -> pd.Timestamp:
    s = str(s).strip()
    m = pd.Series([s]).str.extract(r"(\d{4})年(\d{1,2})月").iloc[0]
    if pd.isna(m[0]) or pd.isna(m[1]):
        raise ValueError(f"Cannot parse year-month from: {s}")
    return pd.Timestamp(int(m[0]), int(m[1]), 1)

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=str, default=str(RAW_FILE))
    args = ap.parse_args()

    raw = Path(args.raw)
    if not raw.exists():
        raise FileNotFoundError(f"Missing food CPI raw file: {raw}")

    # The first two lines are metadata without commas; skip them.
    df = pd.read_csv(raw, encoding="gbk", skiprows=2)
    if "指标" not in df.columns:
        raise ValueError("Food CPI raw must contain a column named '指标'")

    row = df[df["指标"].astype(str).str.startswith(TARGET_ROW_PREFIX)]
    if row.empty:
        raise ValueError(f"Cannot find target row starting with: {TARGET_ROW_PREFIX}")
    row = row.iloc[0]

    # Build long series: columns are like "2025年11月"
    series = row.drop(labels=["指标"])
    long = series.reset_index()
    long.columns = ["ym", "Food_CPI_MoM_index"]
    long["date"] = long["ym"].apply(parse_ym)
    long["Food_CPI_MoM_index"] = pd.to_numeric(long["Food_CPI_MoM_index"], errors="coerce")
    long = long.dropna(subset=["Food_CPI_MoM_index"]).sort_values("date")

    # Chain to level
    mom_ratio = long["Food_CPI_MoM_index"].values / 100.0
    level = 100.0 * np.cumprod(mom_ratio)
    long["Food_CPI_level"] = level

    # YoY inflation rate (%)
    long["Food_CPI_YoY"] = 100.0 * (long["Food_CPI_level"] / long["Food_CPI_level"].shift(12) - 1.0)

    out_m = INTERMEDIATE_DIR / "food_cpi_monthly.csv"
    long[["date", "Food_CPI_MoM_index", "Food_CPI_level", "Food_CPI_YoY"]].to_csv(out_m, index=False, encoding="utf-8-sig")

    q = long.copy()
    q["quarter"] = q["date"].dt.to_period("Q").astype(str)
    q = q.groupby("quarter", as_index=False)["Food_CPI_YoY"].mean().rename(columns={"Food_CPI_YoY": "Food_CPI_YoY_qavg"})
    out_q = INTERMEDIATE_DIR / "food_cpi_quarterly.csv"
    q.to_csv(out_q, index=False, encoding="utf-8-sig")

    cov = pd.DataFrame([{
        "start": long["date"].min().strftime("%Y-%m"),
        "end": long["date"].max().strftime("%Y-%m"),
        "n_months": int(long.shape[0]),
        "n_quarters": int(q.shape[0]),
    }])
    write_three_line_table(
        cov,
        TAB_DIR / "food_cpi_coverage.tex",
        caption="食品类CPI覆盖情况（上月=100链式指数 -> 同比通胀 -> 季度均值）",
        label="tab:food_cpi_coverage",
        notes=[
            "原始数据为环比链式指数（上月=100），本文先构造水平序列，再计算同比通胀率。"
        ],
        float_format="{:.0f}",
    )

    print(f"[FOOD CPI] wrote: {out_m}")
    print(f"[FOOD CPI] wrote: {out_q}")
    print(f"[FOOD CPI] wrote: {TAB_DIR/'food_cpi_coverage.tex'}")

if __name__ == "__main__":
    main()
