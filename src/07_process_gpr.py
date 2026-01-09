\
"""
Process GPR raw Excel export into clean monthly and quarterly series.

Inputs (do not edit):
  data/raw/data_gpr_export.xlsx

Outputs:
  data/intermediate/gpr_monthly.csv        columns: date, gpr
  data/intermediate/gpr_quarterly.csv      columns: quarter, gpr_qavg
  outputs/tables/gpr_coverage.tex          three-line table with coverage stats

Notes:
  The exported file contains a block of variable-label rows (var_name not null).
  We drop those rows and keep the actual time-series rows (var_name is null).
"""
from __future__ import annotations
import argparse
from pathlib import Path
import pandas as pd

from _paths import RAW_DIR, INTERMEDIATE_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

RAW_FILE = RAW_DIR / "data_gpr_export.xlsx"

def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=str, default=str(RAW_FILE))
    args = ap.parse_args()

    raw = Path(args.raw)
    if not raw.exists():
        raise FileNotFoundError(f"Missing GPR raw file: {raw}")

    df = pd.read_excel(raw)
    # Drop metadata / variable label rows
    if "var_name" in df.columns:
        df = df[df["var_name"].isna()].copy()

    if "month" not in df.columns or "GPR" not in df.columns:
        raise ValueError("GPR raw file must contain columns: 'month' and 'GPR'")

    df["date"] = pd.to_datetime(df["month"])
    df["gpr"] = pd.to_numeric(df["GPR"], errors="coerce")
    df = df.dropna(subset=["date", "gpr"]).sort_values("date")

    out_m = INTERMEDIATE_DIR / "gpr_monthly.csv"
    df[["date", "gpr"]].to_csv(out_m, index=False, encoding="utf-8-sig")

    q = df.copy()
    q["quarter"] = q["date"].dt.to_period("Q").astype(str)
    q = q.groupby("quarter", as_index=False)["gpr"].mean().rename(columns={"gpr": "gpr_qavg"})
    out_q = INTERMEDIATE_DIR / "gpr_quarterly.csv"
    q.to_csv(out_q, index=False, encoding="utf-8-sig")

    cov = pd.DataFrame([{
        "start": df["date"].min().strftime("%Y-%m"),
        "end": df["date"].max().strftime("%Y-%m"),
        "n_months": int(df.shape[0]),
        "n_quarters": int(q.shape[0]),
    }])
    write_three_line_table(
        cov,
        TAB_DIR / "gpr_coverage.tex",
        caption="GPR 数据覆盖情况（原始月度 -> 季度均值）",
        label="tab:gpr_coverage",
        notes=[
            "GPR 来源：Caldara & Iacoviello 维护的 Geopolitical Risk Index。",
            "季度均值采用季度内月度简单平均。"
        ],
        float_format="{:.0f}",
    )

    print(f"[GPR] wrote: {out_m}")
    print(f"[GPR] wrote: {out_q}")
    print(f"[GPR] wrote: {TAB_DIR/'gpr_coverage.tex'}")

if __name__ == "__main__":
    main()
