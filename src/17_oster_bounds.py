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

import os
import sys
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
# From eq (14) in 05_identification.tex:
#   Error_{ipt} = alpha + beta * Revision_{ipt} + gamma * X_i
#                 + delta_p + delta_t + eps_{ipt}
y_var = "fe_proxy"
x_var = "revision"
controls = ["age", "edu_years", "income", "gender", "urban"]
fe_vars = ["province", "wave"]

# ---------- sample restriction ----------
# Keep complete cases on outcome, treatment, and FE
need = [y_var, x_var] + fe_vars
df = df.dropna(subset=need)
print(f"After dropping missing on outcome/treatment/FE: {len(df)} rows")

# Fill missing controls with 0 (will be absorbed by FE in controlled spec)
for c in controls:
    if c in df.columns:
        df[c] = df[c].fillna(df[c].median())
    else:
        print(f"  Warning: control variable '{c}' not found, skipping")
        controls = [v for v in controls if v != c]

print(f"Analysis sample: {len(df)} observations")
print(f"Controls: {controls}")

# ---------- create FE dummies ----------
fe_dummies = []
for fe in fe_vars:
    dums = pd.get_dummies(df[fe], prefix=fe, drop_first=True, dtype=float)
    fe_dummies.append(dums)

fe_matrix = pd.concat(fe_dummies, axis=1)


# ---------- Regression 1: Uncontrolled (no FE, no controls) ----------
X_uncontrolled = sm.add_constant(df[[x_var]].values)
y = df[y_var].values

model_unc = sm.OLS(y, X_uncontrolled).fit()
beta_uncontrolled = model_unc.params[1]
r2_uncontrolled = model_unc.rsquared
print(f"\n--- Uncontrolled regression ---")
print(f"  beta = {beta_uncontrolled:.4f}")
print(f"  R2   = {r2_uncontrolled:.6f}")

# ---------- Regression 2: Controlled (with FE + demographics) ----------
X_controlled = np.column_stack([
    np.ones(len(df)),
    df[[x_var]].values,
    df[controls].values if controls else np.empty((len(df), 0)),
    fe_matrix.values
])

model_ctrl = sm.OLS(y, X_controlled).fit()
# beta_controlled is the coefficient on revision (index 1)
beta_controlled = model_ctrl.params[1]
r2_controlled = model_ctrl.rsquared
print(f"\n--- Controlled regression ---")
print(f"  beta = {beta_controlled:.4f}")
print(f"  R2   = {r2_controlled:.6f}")
print(f"  N    = {int(model_ctrl.nobs)}")

# ---------- Oster (2019) bounds ----------
# R2_max: standard convention is min(2.2 * R2_controlled, 1.0)
r2_max = min(2.2 * r2_controlled, 1.0)

# delta* formula:
#   delta* = [(beta_ctrl - beta_target) * (R2_max - R2_ctrl)]
#          / [(beta_unc - beta_ctrl) * (R2_ctrl - R2_unc)]
# where beta_target = 0 (null hypothesis)
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
# beta_adj = beta_ctrl - delta * (beta_unc - beta_ctrl)
#            * (R2_max - R2_ctrl) / (R2_ctrl - R2_unc)
# With delta = 1:
if abs(r2_controlled - r2_uncontrolled) < 1e-12:
    beta_adjusted = beta_controlled
else:
    adjustment = ((beta_uncontrolled - beta_controlled)
                  * (r2_max - r2_controlled)
                  / (r2_controlled - r2_uncontrolled))
    beta_adjusted = beta_controlled - adjustment

print(f"  Bias-adjusted beta (delta=1) = {beta_adjusted:.4f}")
print(f"  (Negative means result survives even with delta=1)")

# ---------- Generate LaTeX table ----------
latex = r"""\begin{table}[htbp]
\centering
\caption{Oster (2019) Selection-on-Observables Bounds: CFPS Household Panel}
\label{tab:oster_bounds}
\begin{tabular}{lc}
\toprule
\textbf{Statistic} & \textbf{Value} \\
\midrule
Uncontrolled $\hat{\beta}$ (no FE, no controls) & """ + f"{beta_uncontrolled:.4f}" + r""" \\
Controlled $\hat{\beta}$ (province + wave FE, demographics) & """ + f"{beta_controlled:.4f}" + r""" \\[4pt]
$R^2$ (uncontrolled) & """ + f"{r2_uncontrolled:.4f}" + r""" \\
$R^2$ (controlled)   & """ + f"{r2_controlled:.4f}" + r""" \\
$R^2_{\max}$ ($= \min\{2.2 \times R^2_{\text{ctrl}}, 1\}$) & """ + f"{r2_max:.4f}" + r""" \\[4pt]
$\delta^*$ (proportional selection ratio) & """ + f"{delta_star:.2f}" + r""" \\
Bias-adjusted $\hat{\beta}$ ($\delta = 1$, $R^2_{\max}$) & """ + f"{beta_adjusted:.4f}" + r""" \\
$N$ & """ + f"{int(model_ctrl.nobs):,}" + r""" \\
\bottomrule
\end{tabular}
\begin{tablenotes}[flushleft]\footnotesize
\item \textit{Notes:} Oster (2019) bounds for the revision--error coefficient
in the CFPS household panel. The uncontrolled regression includes only the
revision variable. The controlled regression adds province and wave fixed effects
plus demographic controls (age, education, income, gender, urban hukou).
$\delta^* > 1$ means selection on unobservables would need to be stronger than
selection on observables to drive the coefficient to zero.
The bias-adjusted $\hat{\beta}$ assumes proportional selection ($\delta = 1$);
a negative value indicates that the result survives full proportional selection.
$R^2_{\max}$ follows the Oster (2019) convention of $2.2 \times R^2_{\text{controlled}}$.
\end{tablenotes}
\end{table}
"""

with open(OUT_FILE, "w", encoding="utf-8") as f:
    f.write(latex)

print(f"\nLaTeX table written to: {OUT_FILE}")
print("\n=== Oster bounds computation complete ===")
