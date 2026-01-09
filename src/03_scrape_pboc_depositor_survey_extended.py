"""
Scrape PBOC (People's Bank of China) "Urban Depositors Survey" quarterly reports
(城镇储户问卷调查报告), download each PDF, and extract:

A) The attachment table (附件：城镇储户问卷调查指数表):
   - Price Expectation Index (物价预期指数)
   - Income Sentiment Index (收入感受指数)
   - Income Confidence Index (收入信心指数)
   - Employment Sentiment Index (就业感受指数)
   - Employment Expectation Index (就业预期指数)

B) (Optional but recommended) The response shares for price expectations:
   - % expecting prices "up" / "same" / "down" / "uncertain"
   These appear in the PDF main text (e.g., "其中，21.3%的居民预期...").

This script is designed for the actual page structure:
  - A list page (index.html, 11874-<page>.html) contains article links.
  - Each article page contains a single PDF link (relative or absolute).
  - Only the PDF contains the table / text we need.

Usage examples:
  # Crawl the first 400 list pages and download/parse PDFs
  python src/03_scrape_pboc_depositor_survey.py --start_page 1 --max_pages 25

  # Re-run only parsing without re-downloading (it will skip existing PDFs)
  python src/03_scrape_pboc_depositor_survey.py --no_download

Outputs:
  - data/intermediate/pboc_depositor_survey_quarterly_extended.csv  (wide; indices + shares)
  - data/intermediate/pboc_infl_exp_index_extended.csv              (backward-compatible; price index only)
  - data/raw/pboc_depositor_survey/pdfs/*.pdf              (downloaded PDFs)
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import dataclasses
import hashlib
import re
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any, List, Tuple
from urllib.parse import urljoin, urlparse

import pandas as pd
import pdfplumber
import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ----------------------------
# Web locations (PBOC)
# ----------------------------
BASE_LIST_ROOT = "https://www.pbc.gov.cn/goutongjiaoliu/113456/113469/index.html"
LIST_PAGE_FMT = urljoin(BASE_LIST_ROOT, "11040-{page}.html")  # pagination
LIST_PAGE_1 = LIST_PAGE_FMT.format(page=1)  # first page

# ----------------------------
# Regex: article list parsing
# ----------------------------
TITLE_FILTER = "储户问卷调查报告"

# ----------------------------
# Regex: extract "report quarter" from title
# ----------------------------
_TITLE_Q_RE = re.compile(r"(?P<year>\d{4})年(?P<qcn>第[1234]季度)")

_QMAP = {"第1季度": "Q1", "第2季度": "Q2", "第3季度": "Q3", "第4季度": "Q4"}


def infer_quarter_from_title(title: str) -> Optional[str]:
    m = _TITLE_Q_RE.search(title)
    if not m:
        return None
    year = int(m.group("year"))
    q = _QMAP.get(m.group("qcn"), None)
    return f"{year}{q}" if q else None


# ----------------------------
# Regex: parse index table rows in the PDF attachment
# ----------------------------
# The extracted PDF text often contains rows like:
#   2025.Q3 57.1 46.5 45.9 25.8 42.1
# or with spaces:
#   2025. Q3 57.1 46.5 45.9 25.8 42.1
_TABLE_ROW_RE = re.compile(
    r"(?P<year>\d{4})\s*[\.．]\s*Q\s*(?P<q>[1-4])\s+"
    r"(?P<price_sent>\d{1,3}(?:\.\d+)?)\s+"
    r"(?P<price_exp>\d{1,3}(?:\.\d+)?)\s+"
    r"(?P<inc_sent>\d{1,3}(?:\.\d+)?)\s+"
    r"(?P<inc_conf>\d{1,3}(?:\.\d+)?)\s+"
    r"(?P<emp_sent>\d{1,3}(?:\.\d+)?)\s+"
    r"(?P<emp_exp>\d{1,3}(?:\.\d+)?)"
)

# ----------------------------
# Regex: extract price-expectation shares in PDF main text
# Example snippet:
#   其中，21.3%的居民预期下季物价将“上升”，61.0%的居民预期“基本不变”，
#   8.4%的居民预期“下降”，9.3%的居民“看不准”。
# ----------------------------
_PRICE_SHARE_PATTERNS = [
    # Most common modern phrasing (2020s)
    re.compile(
        r"其中，\s*(?P<up>\d+(?:\.\d+)?)%\s*的居民.*?预期.*?下季.*?物价.*?[“\"]上升[”\"].*?"
        r"(?P<same>\d+(?:\.\d+)?)%\s*的居民.*?预期.*?[“\"]基本不变[”\"].*?"
        r"(?P<down>\d+(?:\.\d+)?)%\s*的居民.*?预期..*?[“\"]下降[”\"].*?"
        r"(?P<unc>\d+(?:\.\d+)?)%\s*的居民.*?预期..*?[“\"]看不准[”\"]",
        re.S,
    ),
    # A looser fallback: match in-order percentages followed by keywords
    re.compile(
        r"(?P<up>\d+(?:\.\d+)?)%.*?(上升|上涨|提高).*?"
        r"(?P<same>\d+(?:\.\d+)?)%.*?(基本不变|不变).*?"
        r"(?P<down>\d+(?:\.\d+)?)%.*?(下降|下跌|降低).*?"
        r"(?P<unc>\d+(?:\.\d+)?)%.*?(看不准|难以预计)",
        re.S,
    ),
]


# ----------------------------
# HTTP session with retries
# ----------------------------
def make_session(timeout: int = 30) -> requests.Session:
    s = requests.Session()
    retries = Retry(
        total=5,
        backoff_factor=0.5,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retries, pool_connections=50, pool_maxsize=50)
    s.mount("http://", adapter)
    s.mount("https://", adapter)
    s.headers.update({"User-Agent": "Mozilla/5.0"})
    return s


def get_html(session: requests.Session, url: str, timeout: int = 30) -> str:
    r = session.get(url, timeout=timeout)
    r.raise_for_status()
    r.encoding = r.apparent_encoding
    return r.text


def parse_list_page(html: str, base_url: str) -> List[Dict[str, str]]:
    """
    Return list of {title, href, date_str} items from a list page.
    PBOC list pages now use table rows: <tr><td><a href="...">title</a></td><td>date</td></tr>
    """
    soup = BeautifulSoup(html, "lxml")
    out = []
    for tr in soup.select("tr"):
        a = tr.select_one("a[href]")
        if not a:
            continue
        title = a.get_text(strip=True)
        if TITLE_FILTER not in title:
            continue
        href = a.get("href", "")
        # Assume date is in the next td
        tds = tr.select("td")
        date_str = None
        if len(tds) >= 2:
            ds = tds[1].get_text(strip=True)
            if re.match(r"\d{4}-\d{2}-\d{2}", ds):
                date_str = ds
        out.append({"title": title, "href": urljoin(base_url, href), "date": date_str})
    return out


def find_pdf_url(article_url: str, html: str) -> Optional[str]:
    soup = BeautifulSoup(html, "lxml")
    # Prefer explicit anchors ending with .pdf
    for a in soup.select("a[href]"):
        href = a.get("href", "").strip()
        if href.lower().endswith(".pdf"):
            return urljoin(article_url, href)
    # Fallback: sometimes the site uses direct numeric pdf URLs without .pdf text in href
    m = re.search(r"https?://[^\s\"']+\.pdf", html, flags=re.I)
    if m:
        return m.group(0)
    return None


def safe_slug(s: str, max_len: int = 120) -> str:
    # safe filename on Windows/macOS/Linux
    s = re.sub(r"[\\/:*?\"<>|]+", "_", s)
    s = re.sub(r"\s+", "", s)
    return s[:max_len]


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download_file(
    session: requests.Session, url: str, out: Path, timeout: int = 60
) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(out.suffix + ".part")
    with session.get(url, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 20):
                if chunk:
                    f.write(chunk)
    tmp.replace(out)


def extract_pdf_text(pdf_path: Path, max_pages: Optional[int] = None) -> str:
    texts = []
    with pdfplumber.open(pdf_path) as pdf:
        n = len(pdf.pages)
        end = n if max_pages is None else min(n, max_pages)
        for i in range(end):
            t = pdf.pages[i].extract_text() or ""
            if t:
                texts.append(t)
    return "\n".join(texts)


def extract_index_table(blob: str) -> List[Dict[str, Any]]:
    rows = []
    for m in _TABLE_ROW_RE.finditer(blob):
        year = int(m.group("year"))
        q = int(m.group("q"))
        quarter = f"{year}Q{q}"
        rows.append(
            {
                "quarter": quarter,
                "price_sentiment_index": float(m.group("price_sent")),
                "price_expectation_index": float(m.group("price_exp")),
                "income_sentiment_index": float(m.group("inc_sent")),
                "income_confidence_index": float(m.group("inc_conf")),
                "employment_sentiment_index": float(m.group("emp_sent")),
                "employment_expectation_index": float(m.group("emp_exp")),
            }
        )
    # de-dup within a single PDF (rare, but safe)
    if rows:
        df = pd.DataFrame(rows).drop_duplicates(subset=["quarter"], keep="last")
        return df.to_dict(orient="records")
    return []


def extract_price_shares(blob: str) -> Dict[str, float]:
    out: Dict[str, float] = {}
    # Try patterns in order (strict -> loose)
    for pat in _PRICE_SHARE_PATTERNS:
        m = pat.search(blob)
        if not m:
            continue
        out = {
            "price_up_share": float(m.group("up")),
            "price_same_share": float(m.group("same")),
            "price_down_share": float(m.group("down")),
            "price_uncertain_share": float(m.group("unc")),
        }
        break
    return out


@dataclasses.dataclass
class ReportTask:
    title: str
    quarter_title: Optional[str]
    article_url: str
    report_date: Optional[str]
    pdf_url: str


def build_tasks(
    session: requests.Session,
    start_page: int,
    max_pages: int,
    sleep: float,
    timeout: int,
) -> List[ReportTask]:
    tasks: List[ReportTask] = []
    seen = set()

    for page in range(start_page, start_page + max_pages):
        list_url = LIST_PAGE_FMT.format(page=page)
        try:
            html = get_html(session, list_url, timeout=timeout)
        except Exception as e:
            print(f"[PBOC] stop at list page={page} ({list_url}): {e}", file=sys.stderr)
            break

        items = parse_list_page(html, BASE_LIST_ROOT)
        if not items:
            print(f"[PBOC] no items on list page={page}, continuing.", file=sys.stderr)
            continue

        for it in items:
            art_url = it["href"]
            if art_url in seen:
                continue
            seen.add(art_url)

            try:
                art_html = get_html(session, art_url, timeout=timeout)
            except Exception as e:
                print(f"[PBOC] article fetch failed: {art_url} -> {e}", file=sys.stderr)
                continue

            pdf_url = find_pdf_url(art_url, art_html)
            if not pdf_url:
                # Some very old reports may be HTML-only; skip for now.
                continue

            tasks.append(
                ReportTask(
                    title=it["title"],
                    quarter_title=infer_quarter_from_title(it["title"]),
                    article_url=art_url,
                    report_date=it.get("date"),
                    pdf_url=pdf_url,
                )
            )
            if sleep:
                time.sleep(sleep)

    return tasks


def process_one(
    session: requests.Session,
    t: ReportTask,
    pdf_dir: Path,
    timeout: int,
    no_download: bool,
) -> Dict[str, Any]:
    pdf_name = safe_slug(t.title) + ".pdf"
    pdf_path = pdf_dir / pdf_name

    if (not no_download) and (not pdf_path.exists()):
        download_file(session, t.pdf_url, pdf_path, timeout=timeout)

    # Parse PDF text (small PDFs; parse all pages)
    blob = extract_pdf_text(pdf_path, max_pages=None)

    # 1) Parse index table rows
    table_rows = extract_index_table(blob)

    # pick the row that matches the report quarter (if present)
    chosen = None
    if t.quarter_title:
        for r in table_rows:
            if r["quarter"] == t.quarter_title:
                chosen = r
                break
    if chosen is None and table_rows:
        # fallback: last row is usually the latest quarter
        chosen = sorted(table_rows, key=lambda x: x["quarter"])[-1]

    # 2) Price shares (optional)
    shares = extract_price_shares(blob)

    out: Dict[str, Any] = {
        "report_title": t.title,
        "report_quarter": t.quarter_title,
        "report_date": t.report_date,
        "article_url": t.article_url,
        "pdf_url": t.pdf_url,
        "pdf_path": str(pdf_path),
        "pdf_sha256": sha256_file(pdf_path) if pdf_path.exists() else None,
    }

    if chosen:
        out.update(chosen)
    else:
        # keep NaNs for indices
        out.update(
            {
                "quarter": t.quarter_title,
                "price_sentiment_index": None,
                "price_expectation_index": None,
                "income_sentiment_index": None,
                "income_confidence_index": None,
                "employment_sentiment_index": None,
                "employment_expectation_index": None,
            }
        )

    out.update(shares)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start_page", type=int, default=1, help="Start list page number")
    ap.add_argument(
        "--max_pages",
        type=int,
        default=400,
        help="How many list pages to crawl (approx 20 items/page)",
    )
    ap.add_argument(
        "--sleep",
        type=float,
        default=0.05,
        help="Politeness sleep between list/article requests",
    )
    ap.add_argument("--timeout", type=int, default=30, help="HTTP timeout (seconds)")

    ap.add_argument("--pdf_dir", default="data/raw/pboc_depositor_survey/pdfs")
    ap.add_argument(
        "--out_wide",
        default="data/intermediate/pboc_depositor_survey_quarterly_extended.csv",
    )
    ap.add_argument(
        "--out_price_index",
        default="data/intermediate/pboc_infl_exp_index_extended.csv",
    )

    ap.add_argument(
        "--max_workers", type=int, default=6, help="Concurrency for download+parse"
    )
    ap.add_argument(
        "--no_download",
        action="store_true",
        help="Skip downloading; parse only existing PDFs",
    )
    args = ap.parse_args()

    session = make_session(timeout=args.timeout)

    pdf_dir = Path(args.pdf_dir)
    pdf_dir.mkdir(parents=True, exist_ok=True)

    out_wide = Path(args.out_wide)
    out_wide.parent.mkdir(parents=True, exist_ok=True)

    out_price = Path(args.out_price_index)
    out_price.parent.mkdir(parents=True, exist_ok=True)

    print(
        f"[PBOC] crawling list pages: start={args.start_page}, max_pages={args.max_pages}"
    )
    tasks = build_tasks(
        session, args.start_page, args.max_pages, args.sleep, args.timeout
    )
    print(f"[PBOC] found {len(tasks)} depositor-survey reports with PDFs")

    if not tasks:
        raise SystemExit(
            "No tasks found. The PBOC page template may have changed, or network access is blocked."
        )

    rows: List[Dict[str, Any]] = []

    # Use a separate session per worker (requests.Session is not fully thread-safe).
    def worker(tt: ReportTask) -> Dict[str, Any]:
        s = make_session(timeout=args.timeout)
        return process_one(s, tt, pdf_dir, args.timeout, args.no_download)

    with cf.ThreadPoolExecutor(max_workers=max(1, args.max_workers)) as ex:
        futs = [ex.submit(worker, t) for t in tasks]
        for fut in cf.as_completed(futs):
            try:
                rows.append(fut.result())
            except Exception as e:
                print(f"[PBOC] one report failed: {e}", file=sys.stderr)

    df = pd.DataFrame(rows)

    # Deduplicate by quarter (keep latest report_date if available; else keep last seen)
    # Some PDFs include a trailing table spanning multiple quarters; we select the row matching report_quarter,
    # so dedupe should be safe.
    if "quarter" in df.columns:
        # normalize quarter strings to 'YYYYQn'
        def norm_q(x):
            if pd.isna(x):
                return x
            x = str(x).strip()
            m = re.match(r"(\d{4})Q([1-4])", x)
            return f"{m.group(1)}Q{m.group(2)}" if m else x

        df["quarter"] = df["quarter"].map(norm_q)

        # sortable report_date
        if "report_date" in df.columns:
            df["_report_date_sort"] = pd.to_datetime(df["report_date"], errors="coerce")
        else:
            df["_report_date_sort"] = pd.NaT

        df = (
            df.sort_values(["quarter", "_report_date_sort"])
            .drop_duplicates(subset=["quarter"], keep="last")
            .drop(columns=["_report_date_sort"])
        )

    df = df.sort_values("quarter").reset_index(drop=True)

    df.to_csv(out_wide, index=False, encoding="utf-8-sig")
    print(f"[PBOC] wrote wide dataset: {out_wide} ({len(df)} rows)")

    # Backward-compatible output expected by other scripts: just price index
    if "price_expectation_index" in df.columns:
        df_price = df[["quarter", "price_expectation_index"]].rename(
            columns={"price_expectation_index": "future_price_expectation_index"}
        )
        df_price.to_csv(out_price, index=False, encoding="utf-8-sig")
        print(f"[PBOC] wrote price-index series: {out_price} ({len(df_price)} rows)")


if __name__ == "__main__":
    main()
