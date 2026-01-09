\
"""
Download China Mainland-paper EPU (Economic Policy Uncertainty) monthly series.

Data host: policyuncertainty.com
  - China Mainland Papers EPU: https://www.policyuncertainty.com/china_monthly.html
  - Direct file: https://www.policyuncertainty.com/media/China_Mainland_Paper_EPU.xlsx

Usage:
  python src/02_download_epu.py --out data/raw/china_epu.xlsx
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path
import requests

URL = "https://www.policyuncertainty.com/media/China_Mainland_Paper_EPU.xlsx"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="data/raw/china_epu.xlsx")
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    try:
        with requests.get(URL, stream=True, timeout=args.timeout) as r:
            r.raise_for_status()
            tmp = out.with_suffix(out.suffix + ".part")
            with open(tmp, "wb") as f:
                for chunk in r.iter_content(chunk_size=1<<20):
                    if chunk:
                        f.write(chunk)
            tmp.replace(out)
        print(f"[EPU] saved to: {out}")
    except Exception as e:
        print(f"[EPU] download failed ({URL}).", file=sys.stderr)
        print("If you are behind a firewall, try:", file=sys.stderr)
        print("  - switching network / using a server", file=sys.stderr)
        print("  - manual download from the website, then place the file into data/raw/", file=sys.stderr)
        raise

if __name__ == "__main__":
    main()
