#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mechanical coupling bias check for FE/FR regression.

Under mu_t = mu*_t + e_t with iid measurement error e_t:
  FE_t = (pi_{t+1} - mu*_t) - e_t
  FR_t = (mu*_t - mu*_{t-1}) + (e_t - e_{t-1})
If Cov(pi_{t+1} - mu*_t, mu*_t - mu*_{t-1}) = 0, then
  beta_mech = Cov(FE_t, FR_t) / Var(FR_t) = -Var(e_t) / Var(FR_t).
Because Var(FR_t) = Var(Delta mu*_t) + 2 Var(e_t),
  beta_mech is bounded in [-0.5, 0).

This script reports sample Var(FR), the bivariate OLS slope, and the
implied upper bound from mechanical coupling.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table


PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"


def main() -> None:
    ensure_dirs()

    panel = pd.read_csv(PANEL_FILE)
    panel["_q"] = pd.PeriodIndex(panel["quarter"], freq="Q")
    panel = panel.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)

    # Construct FE and FR with the same alignment as the baseline OLS.
    panel["CPI_lead1"] = panel["CPI_QoQ_Ann"].shift(-1)
    panel["FE"] = panel["CPI_lead1"] - panel["mu_cp"]
    panel["FR"] = panel["mu_cp"] - panel["mu_cp"].shift(1)

    data = panel.dropna(subset=["FE", "FR"]).copy()
    n_obs = int(data.shape[0])

    fr = data["FR"].to_numpy(float)
    fe = data["FE"].to_numpy(float)
    var_fr = float(np.var(fr, ddof=1))
    cov_fe_fr = float(np.cov(fr, fe, ddof=1)[0, 1])
    beta_ols = cov_fe_fr / var_fr if var_fr > 0 else np.nan

    sigma_e2_max = 0.5 * var_fr
    beta_mech_max = -0.5
    sigma_e2_needed = abs(beta_ols) * var_fr
    ratio_needed = sigma_e2_needed / sigma_e2_max if sigma_e2_max > 0 else np.nan

    rows = [
        {"Statistic": "N (FE/FR sample)", "Value": f"{n_obs:d}"},
        {"Statistic": "Var(FR)", "Value": f"{var_fr:.3f}"},
        {"Statistic": "OLS beta (FE on FR, HAC4)", "Value": f"{beta_ols:.3f}"},
        {"Statistic": "Max mechanical beta", "Value": f"{beta_mech_max:.3f}"},
        {"Statistic": "Max Var(e)", "Value": f"{sigma_e2_max:.3f}"},
        {"Statistic": r"Var(e) needed for $\beta_{OLS}$", "Value": f"{sigma_e2_needed:.3f}"},
        {"Statistic": "Needed/Max Var(e)", "Value": f"{ratio_needed:.2f}"},
    ]

    out_df = pd.DataFrame(rows)
    write_three_line_table(
        out_df,
        TAB_DIR / "coupling_bias.tex",
        caption="Mechanical Coupling Bias: Upper-Bound Check",
        label="tab:coupling_bias",
        notes=[
            r"Under $\mu_t=\mu^*_t+e_t$ with iid $e_t$, $\beta_{mech}=-\mathrm{Var}(e_t)/\mathrm{Var}(FR_t)$.",
            r"Since $\mathrm{Var}(FR_t)=\mathrm{Var}(\Delta \mu^*_t)+2\mathrm{Var}(e_t)$, $\beta_{mech}\in[-0.5,0)$.",
            r"OLS beta is the bivariate slope (same point estimate as HAC(4)).",
        ],
        float_format="{}",
    )

    print(f"[Coupling Bias] Wrote: {TAB_DIR / 'coupling_bias.tex'}")


if __name__ == "__main__":
    main()
