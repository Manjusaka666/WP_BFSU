#!/usr/bin/env python
"""
18_cfps_robustness_matrix.py
Run the CFPS household-level revision-error regression under five
alternative codings of the 3-point inflation expectation variable.

Specifications:
  (1) Baseline {-1,0,1}: revision as-is
  (2) Binary rise: revision_rise = 1 if price_exp went from 0/-1 to 1
  (3) Binary fall: revision_fall = 1 if price_exp went from 0/1 to -1
  (4) Drop unchanged: restrict to revision != 0
  (5) Stable respondents: keep pid appearing in 3+ waves

All specifications include province x wave FE and province-clustered SE.
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.stats.sandwich_covariance import cov_cluster
from pathlib import Path

# ---------- paths ----------
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "processed" / "cfps_revision_panel.csv"
OUT_DIR = ROOT / "outputs" / "tables"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_FILE = OUT_DIR / "cfps_robustness_matrix.tex"

# ---------- load data ----------
print(f"Loading data from {DATA}")
df_raw = pd.read_csv(DATA)
print(f"Raw panel: {len(df_raw)} rows")

# ---------- variable definitions ----------
y_var = "fe_proxy"
x_var = "revision"
controls = ["age", "edu_years", "income", "gender", "urban"]
fe_vars = ["province", "wave"]

# ---------- complete-case base sample ----------
need = [y_var, x_var, "price_exp", "price_exp_lag", "pid"] + fe_vars + controls
df = df_raw.dropna(subset=need).copy()
print(f"Complete-case sample: {len(df)} observations")

# ---------- helper: run one regression ----------

def run_spec(data, treatment_var):
    """
    OLS: fe_proxy = a + b*treatment + controls + province x wave FE + e
    Returns (beta, se_clustered, pval, N, R2).
    """
    data = data.copy()
    data["prov_wave"] = data["province"].astype(str) + "_" + data["wave"].astype(str)
    fe_dummies = pd.get_dummies(data["prov_wave"], prefix="pw", drop_first=True, dtype=float)
    # Drop constant columns (empty cells after filtering)
    fe_dummies = fe_dummies.loc[:, fe_dummies.nunique() > 1]
    if fe_dummies.shape[1] == 0:
        fe_dummies = pd.DataFrame(index=data.index)

    y = data[y_var].values
    parts = [np.ones(len(data)), data[treatment_var].values, data[controls].values]
    if fe_dummies.shape[1] > 0:
        parts.append(fe_dummies.values)
    X = np.column_stack(parts)

    model = sm.OLS(y, X).fit()

    # Province-clustered SE for the treatment coefficient (index 1)
    cluster_ids = data["province"].values
    V_cluster = cov_cluster(model, cluster_ids)
    se_cl = np.sqrt(V_cluster[1, 1])
    t_cl = model.params[1] / se_cl
    pval = 2 * (1 - sm.distributions.ECDF(np.abs(np.random.standard_normal(100000)))(np.abs(t_cl)))
    # Use scipy for proper p-value
    from scipy.stats import norm
    pval = 2 * norm.sf(np.abs(t_cl))

    return {
        "beta": model.params[1],
        "se": se_cl,
        "pval": pval,
        "N": len(data),
        "R2": model.rsquared,
    }


def stars(pval):
    if pval < 0.01:
        return "***"
    elif pval < 0.05:
        return "**"
    elif pval < 0.10:
        return "*"
    return ""


# ============================================================
# Specification 1: Baseline {-1, 0, 1}
# ============================================================
print("\n--- Spec 1: Baseline ---")
res1 = run_spec(df, "revision")
print(f"  beta={res1['beta']:.4f}, se={res1['se']:.4f}, N={res1['N']}, R2={res1['R2']:.4f}")

# ============================================================
# Specification 2: Binary rise
# revision_rise = 1 if price_exp == 1 and price_exp_lag in {0, -1}
# ============================================================
print("\n--- Spec 2: Binary rise ---")
df["revision_rise"] = ((df["price_exp"] == 1) & (df["price_exp_lag"].isin([0, -1]))).astype(float)
res2 = run_spec(df, "revision_rise")
print(f"  beta={res2['beta']:.4f}, se={res2['se']:.4f}, N={res2['N']}, R2={res2['R2']:.4f}")

# ============================================================
# Specification 3: Binary fall
# revision_fall = 1 if price_exp == -1 and price_exp_lag in {0, 1}
# ============================================================
print("\n--- Spec 3: Binary fall ---")
df["revision_fall"] = ((df["price_exp"] == -1) & (df["price_exp_lag"].isin([0, 1]))).astype(float)
res3 = run_spec(df, "revision_fall")
print(f"  beta={res3['beta']:.4f}, se={res3['se']:.4f}, N={res3['N']}, R2={res3['R2']:.4f}")

# ============================================================
# Specification 4: Drop unchanged (revision != 0)
# ============================================================
print("\n--- Spec 4: Drop unchanged ---")
df_changed = df[df["revision"] != 0].copy()
res4 = run_spec(df_changed, "revision")
print(f"  beta={res4['beta']:.4f}, se={res4['se']:.4f}, N={res4['N']}, R2={res4['R2']:.4f}")

# ============================================================
# Specification 5: Full panel (all waves, province x wave FE only, no demographic controls)
# ============================================================
print("\n--- Spec 5: Full panel (no demographic controls) ---")
need_minimal = [y_var, x_var, "province", "wave"]
df_full = df_raw.dropna(subset=need_minimal).copy()
print(f"  Full panel sample: {len(df_full)} observations")

def run_spec_no_controls(data, treatment_var):
    """OLS with province x wave FE but no demographic controls."""
    data = data.copy()
    data["prov_wave"] = data["province"].astype(str) + "_" + data["wave"].astype(str)
    fe_dummies = pd.get_dummies(data["prov_wave"], prefix="pw", drop_first=True, dtype=float)
    fe_dummies = fe_dummies.loc[:, fe_dummies.nunique() > 1]

    y = data[y_var].values
    parts = [np.ones(len(data)), data[treatment_var].values]
    if fe_dummies.shape[1] > 0:
        parts.append(fe_dummies.values)
    X = np.column_stack(parts)

    model = sm.OLS(y, X).fit()
    cluster_ids = data["province"].values
    V_cluster = cov_cluster(model, cluster_ids)
    se_cl = np.sqrt(V_cluster[1, 1])
    t_cl = model.params[1] / se_cl
    from scipy.stats import norm
    pval = 2 * norm.sf(np.abs(t_cl))
    return {
        "beta": model.params[1],
        "se": se_cl,
        "pval": pval,
        "N": len(data),
        "R2": model.rsquared,
    }

res5 = run_spec_no_controls(df_full, "revision")
print(f"  beta={res5['beta']:.4f}, se={res5['se']:.4f}, N={res5['N']}, R2={res5['R2']:.4f}")

# ============================================================
# Build LaTeX table
# ============================================================
results = [res1, res2, res3, res4, res5]
col_labels = [
    "Baseline",
    "Binary rise",
    "Binary fall",
    "Drop unchanged",
    "Full panel",
]

ncols = len(results)

lines = []
lines.append(r"\begin{table}[htbp]")
lines.append(r"\centering")
lines.append(r"\caption{CFPS Measurement Robustness}")
lines.append(r"\label{tab:cfps_robustness}")
lines.append(r"\small")
lines.append(r"\begin{tabular}{l" + "c" * ncols + "}")
lines.append(r"\toprule")

# Column numbers
hdr = " & ".join([f"({i+1})" for i in range(ncols)])
lines.append(r" & " + hdr + r" \\")

# Column labels
lbl = " & ".join(col_labels)
lines.append(r" & " + lbl + r" \\")
lines.append(r"\midrule")

# Beta row
beta_cells = []
for r in results:
    s = stars(r["pval"])
    beta_cells.append(f"{r['beta']:.4f}{s}")
lines.append(r"$\hat{\beta}$ & " + " & ".join(beta_cells) + r" \\")

# SE row
se_cells = [f"({r['se']:.4f})" for r in results]
lines.append(r" & " + " & ".join(se_cells) + r" \\")
lines.append(r"\addlinespace")

# N row
n_cells = [f"{r['N']:,}" for r in results]
lines.append(r"Observations & " + " & ".join(n_cells) + r" \\")

# R2 row
r2_cells = [f"{r['R2']:.4f}" for r in results]
lines.append(r"$R^2$ & " + " & ".join(r2_cells) + r" \\")
lines.append(r"\addlinespace")

# Controls indicator
ctrl_cells = ["Yes"] * ncols
ctrl_cells[4] = "No"  # Spec 5 has no demographic controls
lines.append(r"Demographic controls & " + " & ".join(ctrl_cells) + r" \\")

# FE indicator
fe_cells = ["Yes"] * ncols
lines.append(r"Province $\times$ wave FE & " + " & ".join(fe_cells) + r" \\")

lines.append(r"\bottomrule")
lines.append(r"\end{tabular}")

# Notes
lines.append(r"\begin{tablenotes}")
lines.append(r"\small")
lines.append(
    r"\item \textit{Notes:} Dependent variable is the forecast error proxy (fe\_proxy). "
    r"Column~(1) uses the baseline $\{-1,0,1\}$ revision coding. "
    r"Column~(2) codes a binary indicator equal to one when a respondent revises upward to ``prices will rise.'' "
    r"Column~(3) codes a binary indicator for downward revision to ``prices will fall.'' "
    r"Column~(4) drops observations with no revision. "
    r"Column~(5) uses the full multi-wave panel with province$\times$wave fixed effects but no demographic controls. "
    r"Columns~(1)--(4) include province$\times$wave fixed effects and controls for age, education years, income, gender, and urban status. Column~(5) includes province$\times$wave fixed effects only. "
    r"Standard errors (in parentheses) are clustered at the province level. "
    r"$^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$."
)
lines.append(r"\end{tablenotes}")
lines.append(r"\end{table}")

tex = "\n".join(lines)
OUT_FILE.write_text(tex, encoding="utf-8")
print(f"\nTable written to {OUT_FILE}")
print("\n--- Done ---")
