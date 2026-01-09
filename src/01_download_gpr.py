\
"""
Download GPR (Geopolitical Risk) monthly series from Caldara & Iacoviello.

Preferred: the *latest* monthly dataset linked from the GPR webpage.
Fallback: gpr_web_latest.xlsx (older snapshot).

Usage:
  python src/01_download_gpr.py --out data/raw/gpr.xlsx
"""
from __future__ import annotations
import argparse, os, sys
from pathlib import Path
import requests

CANDIDATE_URLS = [
    # NOTE: this file may be an older snapshot depending on the authors' hosting
    "https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls",
    "https://www.matteoiacoviello.com/gpr_files/gpr_web_latest.xlsx",
]

def download(url: str, out_path: Path, timeout: int = 60) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        tmp = out_path.with_suffix(out_path.suffix + ".part")
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(chunk_size=1<<20):
                if chunk:
                    f.write(chunk)
        tmp.replace(out_path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="data/raw/gpr_downloaded.xlsx")
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    out = Path(args.out)
    errors = []
    for url in CANDIDATE_URLS:
        try:
            print(f"[GPR] downloading: {url}")
            download(url, out, timeout=args.timeout)
            print(f"[GPR] saved to: {out}")
            return
        except Exception as e:
            errors.append((url, repr(e)))
            print(f"[GPR] failed: {url} -> {e}", file=sys.stderr)

    raise SystemExit(f"All GPR downloads failed:\n{errors}")

if __name__ == "__main__":
    main()
