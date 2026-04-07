#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
20_food_price_heterogeneity.py
Food-price-exposure heterogeneity in the diagnostic slope (CFPS household panel).

Three interaction specifications:
  (1) High CPI: revision x high_cpi (above-median province-level CPI inflation)
  (2) Low income: revision x low_income (below-median household income)
  (3) Combined exposure: revision x high_exposure (both high CPI and low income)

Baseline regression:
    fe_proxy = a + b*revision + controls + province x wave FE + e

Controls: age, edu_years, income, gender, urban
FE: province x wave dummies (drop first)
SE: province-clustered

Output: outputs/tables/cfps_food_heterogeneity.tex
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.stats.sandwich_covariance import cov_cluster
from scipy.stats import norm
from pathlib import Path

# ---- paths ----
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "processed" / "cfps_revision_panel.csv"
OUT_DIR = ROOT / "outputs" / "tables"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_FILE = OUT_DIR / "cfps_food_heterogeneity.tex"

# ---- load and prepare data ----
print(f"Loading data from {DATA}")
df_raw = pd.read_csv(DATA)
print(f"Raw panel: {len(df_raw)} rows")

y_var = "fe_proxy"
x_var = "revision"
controls = ["age", "edu_years", "income", "gender", "urban"]

# Complete cases on the required columns
need = [y_var, x_var, "province", "wave"] + controls + ["cpi_yoy", "income_below_median"]
df = df_raw.dropna(subset=need).copy()
print(f"Complete-case sample: {len(df)} observations")

# ---- construct heterogeneity indicators ----
cpi_median = df["cpi_yoy"].median()
df["high_cpi"] = (df["cpi_yoy"] > cpi_median).astype(float)
df["low_income"] = df["income_below_median"].astype(float)
df["high_exposure"] = ((df["high_cpi"] == 1) & (df["low_income"] == 1)).astype(float)

print(f"CPI median: {cpi_median:.4f}")
print(f"high_cpi share: {df['high_cpi'].mean():.3f}")
print(f"low_income share: {df['low_income'].mean():.3f}")
print(f"high_exposure share: {df['high_exposure'].mean():.3f}")

# ---- province x wave FE dummies ----
df["prov_wave"] = df["province"].astype(str) + "_" + df["wave"].astype(str)
fe_dummies = pd.get_dummies(df["prov_wave"], prefix="pw", drop_first=True, dtype=float)

# ---- helper: stars ----

def stars(pval):
    if pval < 0.01:
        return "***"
    elif pval < 0.05:
        return "**"
    elif pval < 0.10:
        return "*"
    return ""

# ---- helper: run interaction regression ----

def run_interaction(data, fe_dum, moderator_name):
    """
    OLS: fe_proxy = a + b1*revision + b2*moderator + b3*revision*moderator
                    + controls + province x wave FE + e

    Returns dict with beta_base, se_base, pval_base,
    beta_interaction, se_interaction, pval_interaction,
    implied_high_slope, se_implied, pval_implied, N, R2.
    """
    data = data.copy()
    revision = data[x_var].values
    moderator = data[moderator_name].values
    interaction = revision * moderator

    # Design matrix: [const, revision, moderator, interaction, controls, FE dummies]
    X = np.column_stack([
        np.ones(len(data)),         # 0: const
        revision,                   # 1: revision (beta_base)
        moderator,                  # 2: moderator (beta_mod)
        interaction,                # 3: revision x moderator (beta_interaction)
        data[controls].values,      # 4..: controls
        fe_dum.values,              # FE dummies
    ])

    y = data[y_var].values
    model = sm.OLS(y, X).fit()

    # Province-clustered variance-covariance
    cluster_ids = data["province"].values
    V = cov_cluster(model, cluster_ids)

    # Indices: 1 = revision (base), 3 = interaction
    idx_base = 1
    idx_inter = 3

    beta_base = model.params[idx_base]
    se_base = np.sqrt(V[idx_base, idx_base])
    t_base = beta_base / se_base
    pval_base = 2 * norm.sf(np.abs(t_base))

    beta_inter = model.params[idx_inter]
    se_inter = np.sqrt(V[idx_inter, idx_inter])
    t_inter = beta_inter / se_inter
    pval_inter = 2 * norm.sf(np.abs(t_inter))

    # Implied high slope = beta_base + beta_interaction
    implied = beta_base + beta_inter
    se_implied = np.sqrt(V[idx_base, idx_base] + V[idx_inter, idx_inter] + 2 * V[idx_base, idx_inter])
    t_implied = implied / se_implied
    pval_implied = 2 * norm.sf(np.abs(t_implied))

    return {
        "beta_base": beta_base,
        "se_base": se_base,
        "pval_base": pval_base,
        "beta_inter": beta_inter,
        "se_inter": se_inter,
        "pval_inter": pval_inter,
        "implied": implied,
        "se_implied": se_implied,
        "pval_implied": pval_implied,
        "N": len(data),
        "R2": model.rsquared,
    }


# ============================================================
# Run three specifications
# ============================================================

print("\n--- Spec 1: High CPI interaction ---")
res1 = run_interaction(df, fe_dummies, "high_cpi")
print(f"  base={res1['beta_base']:.4f} ({res1['se_base']:.4f}), "
      f"inter={res1['beta_inter']:.4f} ({res1['se_inter']:.4f}), "
      f"implied={res1['implied']:.4f} ({res1['se_implied']:.4f})")

print("\n--- Spec 2: Low income interaction ---")
res2 = run_interaction(df, fe_dummies, "low_income")
print(f"  base={res2['beta_base']:.4f} ({res2['se_base']:.4f}), "
      f"inter={res2['beta_inter']:.4f} ({res2['se_inter']:.4f}), "
      f"implied={res2['implied']:.4f} ({res2['se_implied']:.4f})")

print("\n--- Spec 3: Combined exposure interaction ---")
res3 = run_interaction(df, fe_dummies, "high_exposure")
print(f"  base={res3['beta_base']:.4f} ({res3['se_base']:.4f}), "
      f"inter={res3['beta_inter']:.4f} ({res3['se_inter']:.4f}), "
      f"implied={res3['implied']:.4f} ({res3['se_implied']:.4f})")

# ============================================================
# Build LaTeX table
# ============================================================

results = [res1, res2, res3]
col_labels = [
    r"High CPI",
    r"Low income",
    r"Combined",
]

ncols = len(results)

lines = []
lines.append(r"\begin{table}[htbp]")
lines.append(r"\centering")
lines.append(r"\caption{Food-Price Exposure Heterogeneity in the Diagnostic Slope}")
lines.append(r"\label{tab:cfps_food_heterogeneity}")
lines.append(r"\small")
lines.append(r"\begin{threeparttable}")
lines.append(r"\begin{tabular}{l" + "c" * ncols + "}")
lines.append(r"\toprule")

# Column numbers
hdr = " & ".join([f"({i+1})" for i in range(ncols)])
lines.append(r" & " + hdr + r" \\")

# Column sub-headers with multicolumn
sublbl = " & ".join([rf"\multicolumn{{1}}{{c}}{{{l}}}" for l in col_labels])
lines.append(r" & " + sublbl + r" \\")
lines.append(r"\midrule")

# --- Panel A: Base effect (revision) ---
lines.append(r"\addlinespace")
beta_cells = []
for r in results:
    s = stars(r["pval_base"])
    beta_cells.append(f"{r['beta_base']:.4f}{s}")
lines.append(r"Revision ($\hat{\beta}_1$) & " + " & ".join(beta_cells) + r" \\")

se_cells = [f"({r['se_base']:.4f})" for r in results]
lines.append(r" & " + " & ".join(se_cells) + r" \\")
lines.append(r"\addlinespace")

# --- Interaction term ---
inter_cells = []
for r in results:
    s = stars(r["pval_inter"])
    inter_cells.append(f"{r['beta_inter']:.4f}{s}")
lines.append(r"Revision $\times$ Moderator ($\hat{\beta}_3$) & " + " & ".join(inter_cells) + r" \\")

se_cells = [f"({r['se_inter']:.4f})" for r in results]
lines.append(r" & " + " & ".join(se_cells) + r" \\")
lines.append(r"\addlinespace")

# --- Implied high slope ---
impl_cells = []
for r in results:
    s = stars(r["pval_implied"])
    impl_cells.append(f"{r['implied']:.4f}{s}")
lines.append(r"Implied high-exposure slope ($\hat{\beta}_1 + \hat{\beta}_3$) & " + " & ".join(impl_cells) + r" \\")

se_cells = [f"({r['se_implied']:.4f})" for r in results]
lines.append(r" & " + " & ".join(se_cells) + r" \\")
lines.append(r"\midrule")

# --- Fit statistics ---
n_cells = [f"{r['N']:,}" for r in results]
lines.append(r"Observations & " + " & ".join(n_cells) + r" \\")

r2_cells = [f"{r['R2']:.4f}" for r in results]
lines.append(r"$R^2$ & " + " & ".join(r2_cells) + r" \\")
lines.append(r"\addlinespace")

# --- Indicators ---
lines.append(r"Controls & " + " & ".join(["Yes"] * ncols) + r" \\")
lines.append(r"Province $\times$ wave FE & " + " & ".join(["Yes"] * ncols) + r" \\")
lines.append(r"Province-clustered SE & " + " & ".join(["Yes"] * ncols) + r" \\")

lines.append(r"\bottomrule")
lines.append(r"\end{tabular}")

# Notes
lines.append(r"\begin{tablenotes}[flushleft]")
lines.append(r"\footnotesize")
lines.append(
    r"\item \textit{Notes:} Dependent variable is the forecast error proxy (fe\_proxy). "
    r"The moderator in column~(1) is an indicator for above-median province-level CPI inflation "
    r"(high\_cpi). "
    r"The moderator in column~(2) is an indicator for below-median household income "
    r"(low\_income), capturing higher food budget shares. "
    r"The moderator in column~(3) requires both conditions simultaneously "
    r"(high\_cpi $\times$ low\_income), identifying households most exposed to food-price inflation signals. "
    r"All specifications include controls for age, education years, income, gender, and urban status, "
    r"province$\times$wave fixed effects, and province-clustered standard errors. "
    r"$^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$."
)
lines.append(r"\end{tablenotes}")
lines.append(r"\end{threeparttable}")
lines.append(r"\end{table}")

tex = "\n".join(lines)
OUT_FILE.write_text(tex, encoding="utf-8")
print(f"\nTable written to {OUT_FILE}")
print("\n--- Done ---")
