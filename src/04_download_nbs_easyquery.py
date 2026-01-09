"""
Download comprehensive macro controls from NBS (National Data) for Top-Tier Economic Research.
Target: Bayesian TVP-VAR / State-Space Models (NK-DE Framework).

Key Variables Covered:
1. Inflation: CPI (YoY), PPI (YoY)
2. Real Activity: Industrial Value Added (YoY), GDP (YoY - Quarterly)
3. Monetary: M2 (YoY)
4. Sentiment/Expectation: Consumer Confidence Index, Real Estate Climate Index

Usage:
  python src/04_download_nbs_easyquery.py --preset full_macro
"""

from __future__ import annotations
import argparse, json
import time
from datetime import datetime
from dataclasses import dataclass
from pathlib import Path
import requests
import pandas as pd
from tqdm import tqdm

BASE = "https://data.stats.gov.cn/english/easyquery.htm"


@dataclass
class SeriesSpec:
    name: str
    dbcode: str  # 'hgyd' for monthly, 'hgjd' for quarterly
    rowcode: str  # usually 'zb' (indicator)
    colcode: str  # usually 'sj' (time)
    indicator_code: str  # The specific ID (e.g., A01030101)


# ---- Top-Tier Journal Presets (Hardcoded NBS Codes) ----
# Note: These codes are standard NBS identifiers.
# If fetch fails, NBS might have rotated codes, but these are stable for "easyquery".
PRESETS = {
    "full_macro": [
        # --- Prices (Inflation) ---
        SeriesSpec("CPI_YoY", "hgyd", "zb", "sj", "A01030101"),
        SeriesSpec("PPI_YoY", "hgyd", "zb", "sj", "A01080101"),
        # --- Real Activity (Output) ---
        SeriesSpec("Ind_Value_Added_YoY", "hgyd", "zb", "sj", "A020101"),
        SeriesSpec("GDP_YoY", "hgjd", "zb", "sj", "A010101"),  # Quarterly
        # --- Monetary & Financial ---
        SeriesSpec("M2_YoY", "hgyd", "zb", "sj", "A0D0102"),
        # --- Sentiment & Expectation Proxies (Crucial for DE) ---
        SeriesSpec("Consumer_Confidence_Index", "hgyd", "zb", "sj", "A0B0101"),
        SeriesSpec("Real_Estate_Climate_Index", "hgyd", "zb", "sj", "A010502"),
    ]
}


def get_timestamp_param():
    """Returns a timestamp to prevent caching"""
    return int(time.time() * 1000)


def query_series(spec: SeriesSpec, start_year=2000, timeout=30):
    """
    Query data for a specific indicator.
    We request the 'last 240 periods' (20 years) to cover 2001-Present.
    """

    # Construct the query payload
    # NBS API is tricky: 'dfwds' specifies the filter.
    # We combine the indicator code (zb) and a time range (sj) if possible,
    # but usually 'sj' in wds with 'last X' works best.

    current_date = datetime.now()

    if spec.dbcode == "Monthly":
        end_period = current_date.strftime("%Y%m")
        start_period = f"{start_year}01"
    else:  # Quarterly
        # Quarter Mapping: A=Q1, B=Q2, C=Q3, D=Q4
        quarter_map = {1: "A", 2: "B", 3: "C", 4: "D"}
        current_quarter = (current_date.month - 1) // 3 + 1
        end_period = f"{current_date.year}{quarter_map[current_quarter]}"
        start_period = f"{start_year}A"

    # 1. Define the indicator filter
    wds = [{"wdcode": "sj", "valuecode": f"{start_period}-{end_period}"}]

    dfwds = [
        {"wdcode": spec.rowcode, "valuecode": spec.indicator_code},
        {"wdcode": "sj", "valuecode": f"{start_period}-{end_period}"},
    ]

    params = {
        "m": "QueryData",
        "dbcode": spec.dbcode,
        "rowcode": spec.rowcode,
        "colcode": spec.colcode,
        "wds": json.dumps(wds),
        "dfwds": json.dumps(dfwds),
        "k1": get_timestamp_param(),
    }

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Referer": "https://data.stats.gov.cn/english/easyquery.htm?cn=A01",
    }

    try:
        r = requests.get(
            BASE, params=params, timeout=timeout, headers=headers, verify=False
        )
        r.raise_for_status()
        j = r.json()
    except Exception as e:
        print(f"Error fetching {spec.name}: {e}")
        return pd.DataFrame()

    # Parse response
    rd = j.get("returndata", {})
    datanodes = rd.get("datanodes", [])

    if not datanodes:
        print(f"Warning: No data found for {spec.name} ({spec.indicator_code})")
        return pd.DataFrame()

    # Map time code -> value
    out = []
    for dn in datanodes:
        # Check if this datanode belongs to our series (double verification)
        # The datanode code usually looks like "zb.A01030101_sj.202310"
        if spec.indicator_code not in dn.get("code", ""):
            continue

        # Extract time and value
        # wds in datanode: [{'wdcode': 'zb', ...}, {'wdcode': 'sj', 'valuecode': '202310', ...}]
        time_code = None
        for w in dn.get("wds", []):
            if w.get("wdcode") == spec.colcode:
                time_code = w.get("valuecode")

        val_data = dn.get("data", {})
        val = val_data.get("data")

        # Handle cases where data is missing or 0 but strictly defined
        if time_code is not None:
            # NBS returns 0 for missing sometimes, or empty string.
            # We treat empty string as NaN.
            if val == "":
                continue
            try:
                out.append((time_code, float(val)))
            except (ValueError, TypeError):
                continue

    df = pd.DataFrame(out, columns=["time_code", "value"]).sort_values("time_code")
    df["series_name"] = spec.name
    df["nbs_code"] = spec.indicator_code
    df["frequency"] = "Quarterly" if spec.dbcode == "hgjd" else "Monthly"

    return df


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--preset",
        default="full_macro",
        choices=list(PRESETS.keys()),
        help="Select variable set",
    )
    ap.add_argument(
        "--out", default="data/raw/nbs_macro_control.csv", help="Output path"
    )
    args = ap.parse_args()

    # Disable SSL warning for NBS (often has cert issues)
    requests.packages.urllib3.disable_warnings()

    print(f"--- Starting NBS Macro Data Download ({args.preset}) ---")
    print(f"Targeting: {len(PRESETS[args.preset])} Top-Tier Journal Variables")

    all_df = []
    for spec in tqdm(PRESETS[args.preset], desc="Fetching Series"):
        df = query_series(spec)
        if not df.empty:
            all_df.append(df)
            # Be polite to the server
            time.sleep(2)

    if all_df:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)

        final_df = pd.concat(all_df, ignore_index=True)

        # Post-processing: Format dates
        # NBS Monthly: 202310 -> 2023-10-01
        # NBS Quarterly: 2023C (Q3) -> Needs mapping?
        # Usually NBS returns 2023A/B/C/D for Q1/Q2/Q3/Q4 in easyquery english or numeric.
        # Let's just save raw first.

        final_df.to_csv(out_path, index=False, encoding="utf-8")

        print(f"\n[Success] Data saved to: {out_path}")
        print("Summary of fetched data:")
        print(
            final_df.groupby(["series_name", "frequency"])["time_code"].agg(
                ["min", "max", "count"]
            )
        )
    else:
        print("\n[Error] No data fetched. Check network or NBS codes.")


if __name__ == "__main__":
    main()
