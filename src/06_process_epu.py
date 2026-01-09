\
"""
Process China Mainland Paper EPU raw Excel into clean monthly and quarterly series.

Inputs (do not edit):
  data/raw/China_Mainland_Paper_EPU.xlsx

Outputs:
  data/intermediate/epu_monthly.csv        columns: date, epu
  data/intermediate/epu_quarterly.csv      columns: quarter, epu_qavg
  outputs/tables/epu_coverage.tex          three-line table with coverage stats
"""
from __future__ import annotations
import argparse
from pathlib import Path
import pandas as pd

from _paths import RAW_DIR, INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

RAW_FILE = RAW_DIR / "China_Mainland_Paper_EPU.xlsx"
SHEET = "EPU 2000 onwards"

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=str, default=str(RAW_FILE))
    ap.add_argument("--sheet", type=str, default=SHEET)
    args = ap.parse_args()

    raw = Path(args.raw)
    if not raw.exists():
        raise FileNotFoundError(f"Missing EPU raw file: {raw}")

    df = pd.read_excel(raw, sheet_name=args.sheet)
    df = df.rename(columns={c: c.strip() if isinstance(c, str) else c for c in df.columns})
    keep = df[["year", "month", "EPU"]].copy()
    keep = keep.dropna(subset=["year", "month", "EPU"])
    keep["year"] = keep["year"].astype(int)
    keep["month"] = keep["month"].astype(int)
    keep["date"] = pd.to_datetime(dict(year=keep["year"], month=keep["month"], day=1))
    keep["epu"] = pd.to_numeric(keep["EPU"], errors="coerce")
    keep = keep.dropna(subset=["epu"]).sort_values("date")
    out_m = INTERMEDIATE_DIR / "epu_monthly.csv"
    keep[["date", "epu"]].to_csv(out_m, index=False, encoding="utf-8-sig")

    q = keep.copy()
    q["quarter"] = q["date"].dt.to_period("Q").astype(str)
    q = q.groupby("quarter", as_index=False)["epu"].mean().rename(columns={"epu": "epu_qavg"})
    out_q = INTERMEDIATE_DIR / "epu_quarterly.csv"
    q.to_csv(out_q, index=False, encoding="utf-8-sig")

    cov = pd.DataFrame([{
        "start": keep["date"].min().strftime("%Y-%m"),
        "end": keep["date"].max().strftime("%Y-%m"),
        "n_months": int(keep.shape[0]),
        "n_quarters": int(q.shape[0]),
        "missing_epu": int(keep["epu"].isna().sum()),
    }])
    write_three_line_table(
        cov,
        TAB_DIR / "epu_coverage.tex",
        caption="China EPU 数据覆盖情况（原始月度 -> 季度均值）",
        label="tab:epu_coverage",
        notes=[
            "EPU 来源：policyuncertainty.com (Davis, Liu and Sheng 版本)。",
            "季度均值采用季度内月度简单平均。"
        ],
        float_format="{:.0f}",
    )

    print(f"[EPU] wrote: {out_m}")
    print(f"[EPU] wrote: {out_q}")
    print(f"[EPU] wrote: {TAB_DIR/'epu_coverage.tex'}")

if __name__ == "__main__":
    main()
