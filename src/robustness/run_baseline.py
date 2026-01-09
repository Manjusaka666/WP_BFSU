#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Run baseline estimates used in the manuscript.
"""
from __future__ import annotations
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT/"data"/"panel_quarterly.csv"

def run(cmd):
    print("\n$", " ".join(cmd))
    subprocess.check_call(cmd)

def main():
    py = sys.executable

    # 1) SSM baseline (mu_cp & CPI_YoY; Z includes Food, M2, PPI; X includes EPU, GPR)
    run([py, str(ROOT/"scripts"/"ssm_tvp_diagnostic.py"),
         "--panel", str(PANEL),
         "--exp_var", "mu_cp",
         "--infl_var", "CPI_YoY",
         "--standardize_yH", "0",
         "--outdir", str(ROOT/"outputs"/"ssm_baseline")])

    # 2) BVAR baseline
    run([py, str(ROOT/"scripts"/"bvar_sign_restrictions.py"),
         "--panel", str(PANEL),
         "--vars", "mu_cp","CPI_YoY","Ind_Value_Added_YoY","epu_qavg","gpr_qavg",
         "--exp_var", "mu_cp",
         "--infl_var", "CPI_YoY",
         "--p", "2",
         "--H", "12",
         "--fe_kmax", "4",
         "--outdir", str(ROOT/"outputs"/"bvar_baseline")])

if __name__ == "__main__":
    main()
