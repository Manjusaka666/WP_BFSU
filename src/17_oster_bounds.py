#!/usr/bin/env python3
"""
17_oster_bounds.py
Compute Oster (2019) selection-on-observables bounds for the CFPS
household panel revision-error regression.

Oster's delta* measures proportional selection: how strong would
selection on unobservables need to be, relative to selection on
observables, to drive the treatment coefficient to zero.

Reference: Oster, E. (2019). "Unobservable Selection and Coefficient
Stability: Theory and Evidence." Journal of Business & Economic
Statistics, 37(2), 187-204.
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

# ---------- paths ----------
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "processed" / "cfps_revision_panel.csv"
OUT_DIR = ROOT / "outputs" / "tables"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_FILE = OUT_DIR / "oster_bounds.tex"

# ---------- load data ----------
print(f"Loading data from {DATA}")
df = pd.read_csv(DATA)
print(f"Raw panel: {len(df)} rows")

# ---------- variable definitions ----------
y_var = "fe_proxy"
x_var = "revision"
controls = ["age", "edu_years", "income", "gender", "urban"]
fe_vars = ["province", "wave"]

# ---------- sample restriction ----------
# Complete cases on ALL variables used in the controlled regression
# (no median imputation -- matches the paper's claimed N)
need = [y_var, x_var] + fe_vars + controls
df = df.dropna(subset=need)
print(f"Complete-case analysis sample: {len(df)} observations")
print(f"Controls: {controls}")
print(f"FE: province x wave (interaction)")

# ---------- create province-by-wave interaction FE dummies ----------
# This is the key fix: use interaction FE (delta_{pt}), not additive
df["prov_wave"] = df["province"].astype(str) + "_" + df["wave"].astype(str)
fe_dummies = pd.get_dummies(df["prov_wave"], prefix="pw", drop_first=True, dtype=float)
n_fe = fe_dummies.shape[1]
print(f"Province x wave FE cells: {df['prov_wave'].nunique()} ({n_fe} dummies)")

# ---------- Regression 1: Uncontrolled (no FE, no controls) ----------
X_uncontrolled = sm.add_constant(df[[x_var]].values)
y = df[y_var].values

model_unc = sm.OLS(y, X_uncontrolled).fit()
beta_uncontrolled = model_unc.params[1]
r2_uncontrolled = model_unc.rsquared
print(f"\n--- Uncontrolled regression ---")
print(f"  beta = {beta_uncontrolled:.4f}")
print(f"  R2   = {r2_uncontrolled:.6f}")

# ---------- Regression 2: Controlled (province x wave FE + demographics) ----------
X_controlled = np.column_stack([
    np.ones(len(df)),
    df[[x_var]].values,
    df[controls].values,
    fe_dummies.values
])

model_ctrl = sm.OLS(y, X_controlled).fit()
beta_controlled = model_ctrl.params[1]
r2_controlled = model_ctrl.rsquared
se_controlled = model_ctrl.bse[1]
print(f"\n--- Controlled regression (province x wave FE) ---")
print(f"  beta = {beta_controlled:.4f}")
print(f"  SE   = {se_controlled:.4f}")
print(f"  R2   = {r2_controlled:.6f}")
print(f"  N    = {int(model_ctrl.nobs)}")

# Also run additive FE for comparison
fe_add = []
for fe in fe_vars:
    dums = pd.get_dummies(df[fe], prefix=fe, drop_first=True, dtype=float)
    fe_add.append(dums)
fe_add_matrix = pd.concat(fe_add, axis=1)

X_additive = np.column_stack([
    np.ones(len(df)),
    df[[x_var]].values,
    df[controls].values,
    fe_add_matrix.values
])
model_add = sm.OLS(y, X_additive).fit()
print(f"\n--- Additive FE comparison ---")
print(f"  beta (province + wave) = {model_add.params[1]:.4f}")
print(f"  beta (province x wave) = {beta_controlled:.4f}")

# ---------- Oster (2019) bounds ----------
r2_max = min(2.2 * r2_controlled, 1.0)
beta_target = 0.0

numerator = (beta_controlled - beta_target) * (r2_max - r2_controlled)
denominator = (beta_uncontrolled - beta_controlled) * (r2_controlled - r2_uncontrolled)

if abs(denominator) < 1e-12:
    print("\nWarning: denominator near zero, delta* is undefined")
    delta_star = np.inf
else:
    delta_star = numerator / denominator

print(f"\n--- Oster (2019) bounds ---")
print(f"  R2_max       = {r2_max:.6f}")
print(f"  delta*       = {delta_star:.4f}")
print(f"  |delta*| > 1 : {abs(delta_star) > 1}")

# ---------- Bias-adjusted beta (delta = 1) ----------
if abs(r2_controlled - r2_uncontrolled) < 1e-12:
    beta_adjusted = beta_controlled
else:
    adjustment = ((beta_uncontrolled - beta_controlled)
                  * (r2_max - r2_controlled)
                  / (r2_controlled - r2_uncontrolled))
    beta_adjusted = beta_controlled - adjustment

print(f"  Bias-adjusted beta (delta=1) = {beta_adjusted:.4f}")

# ---------- Also compute province-clustered SE ----------
# Group variable for clustering
clusters = df["province"].values
from statsmodels.stats.sandwich_covariance import cov_cluster
cov_cl = cov_cluster(model_ctrl, clusters)
se_clustered = np.sqrt(cov_cl[1, 1])
t_clustered = beta_controlled / se_clustered
from scipy import stats as sp_stats
p_clustered = 2 * sp_stats.t.sf(abs(t_clustered), df=model_ctrl.df_resid)
print(f"\n--- Province-clustered inference ---")
print(f"  SE (clustered) = {se_clustered:.4f}")
print(f"  t-stat         = {t_clustered:.2f}")
print(f"  p-value        = {p_clustered:.6f}")

# ---------- Star convention ----------
def stars(p):
    if p < 0.01: return "***"
    if p < 0.05: return "**"
    if p < 0.10: return "*"
    return ""

# ---------- Generate LaTeX table ----------
N_str = f"{int(model_ctrl.nobs):,}"
star_unc = ""  # uncontrolled has no clustering
star_ctrl = stars(p_clustered)

latex = r"""\begin{table}[htbp]
\centering
\begin{threeparttable}
\caption{Oster (2019) Selection-on-Observables Bounds: CFPS Household Panel}
\label{tab:oster_bounds}
{\small
\begin{tabular}{lc}
\toprule
Statistic & Value \\
\midrule
\multicolumn{2}{l}{\textit{Panel A: Baseline Specifications}} \\
\addlinespace
Uncontrolled $\hat{\beta}$ (no FE, no controls) & $""" + f"{beta_uncontrolled:.4f}" + r"""$ \\
Controlled $\hat{\beta}$ (province $\times$ wave FE, demographics) & $""" + f"{beta_controlled:.4f}" + star_ctrl + r"""$ \\
 & (""" + f"{se_clustered:.4f}" + r""") \\
\addlinespace
$R^{2}$ (uncontrolled) & $""" + f"{r2_uncontrolled:.4f}" + r"""$ \\
$R^{2}$ (controlled) & $""" + f"{r2_controlled:.4f}" + r"""$ \\
Fixed effects (controlled) & Province $\times$ wave \\
Controls (controlled) & Yes \\
\addlinespace
\multicolumn{2}{l}{\textit{Panel B: Oster Bounds}} \\
\addlinespace
$R^2_{\max}$ ($= \min\{2.2 \times R^2_{\text{ctrl}}, 1\}$) & $""" + f"{r2_max:.4f}" + r"""$ \\
$\delta^*$ (proportional selection ratio) & $""" + f"{delta_star:.2f}" + r"""$ \\
Bias-adjusted $\hat{\beta}$ ($\delta = 1$, $R^2_{\max}$) & $""" + f"{beta_adjusted:.4f}" + r"""$ \\
$N$ & $""" + N_str + r"""$ \\
\bottomrule
\end{tabular}
}
\begin{tablenotes}[flushleft]
\footnotesize
\item \textit{Notes:} Oster (2019) bounds for the revision--error coefficient in the CFPS household panel. The uncontrolled regression includes only the revision variable. The controlled regression adds province $\times$ wave fixed effects plus demographic controls (age, education, income, gender, urban status). Standard error in parentheses is clustered at the province level. $\delta^* > 1$ means selection on unobservables would need to be stronger than selection on observables to drive the coefficient to zero. The bias-adjusted $\hat{\beta}$ assumes proportional selection ($\delta = 1$); a negative value indicates that the result survives full proportional selection. $R^2_{\max}$ follows the Oster (2019) convention of $2.2 \times R^2_{\text{controlled}}$. $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$.
\end{tablenotes}
\end{threeparttable}
\end{table}
"""

with open(OUT_FILE, "w", encoding="utf-8") as f:
    f.write(latex)

print(f"\nLaTeX table written to: {OUT_FILE}")
print("\n=== Oster bounds computation complete ===")
