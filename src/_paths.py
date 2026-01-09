\
from __future__ import annotations
from pathlib import Path

# Project root = parent of /src
PROJECT_ROOT = Path(__file__).resolve().parents[1]

DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
INTERMEDIATE_DIR = DATA_DIR / "intermediate"
PROCESSED_DIR = DATA_DIR / "processed"

OUTPUTS_DIR = PROJECT_ROOT / "outputs"
FIG_DIR = OUTPUTS_DIR / "figures"
TAB_DIR = OUTPUTS_DIR / "tables"

def ensure_dirs() -> None:
    for p in [RAW_DIR, INTERMEDIATE_DIR, PROCESSED_DIR, FIG_DIR, TAB_DIR]:
        p.mkdir(parents=True, exist_ok=True)
