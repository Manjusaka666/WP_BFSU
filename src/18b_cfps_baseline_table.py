#!/usr/bin/env python3
"""
18b_cfps_baseline_table.py
Create the CFPS household panel baseline table with progressive controls.
Three columns: (1) bivariate, (2) + demographics, (3) + province×wave FE.
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.stats.sandwich_covariance import cov_cluster
from scipy import stats as sp_stats
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "processed" / "cfps_revision_panel.csv"
OUT = ROOT / "outputs" / "tables" / "cfps_baseline.tex"

df = pd.read_csv(DATA)

y_var = "fe_proxy"
x_var = "revision"
controls = ["age", "edu_years", "income", "gender", "urban"]
fe_vars = ["province", "wave"]

# Complete cases on all variables
need = [y_var, x_var] + fe_vars + controls
df = df.dropna(subset=need)
print(f"N = {len(df)}")

# Province × wave FE
df["prov_wave"] = df["province"].astype(str) + "_" + df["wave"].astype(str)
pw_dummies = pd.get_dummies(df["prov_wave"], prefix="pw", drop_first=True, dtype=float)

clusters = df["province"].values
y = df[y_var].values

def stars(p):
    if p < 0.01: return "^{***}"
    if p < 0.05: return "^{**}"
    if p < 0.10: return "^{*}"
    return ""

results = []

# Column 1: Bivariate
X1 = sm.add_constant(df[[x_var]].values)
m1 = sm.OLS(y, X1).fit()
cov1 = cov_cluster(m1, clusters)
se1 = np.sqrt(cov1[1, 1])
t1 = m1.params[1] / se1
p1 = 2 * sp_stats.t.sf(abs(t1), df=m1.df_resid)
results.append({"beta": m1.params[1], "se": se1, "p": p1,
                "n": int(m1.nobs), "r2": m1.rsquared,
                "demo": False, "fe": False})

# Column 2: + Demographics
X2 = np.column_stack([np.ones(len(df)), df[[x_var]].values, df[controls].values])
m2 = sm.OLS(y, X2).fit()
cov2 = cov_cluster(m2, clusters)
se2 = np.sqrt(cov2[1, 1])
t2 = m2.params[1] / se2
p2 = 2 * sp_stats.t.sf(abs(t2), df=m2.df_resid)
results.append({"beta": m2.params[1], "se": se2, "p": p2,
                "n": int(m2.nobs), "r2": m2.rsquared,
                "demo": True, "fe": False})

# Column 3: + Province × Wave FE
X3 = np.column_stack([np.ones(len(df)), df[[x_var]].values,
                       df[controls].values, pw_dummies.values])
m3 = sm.OLS(y, X3).fit()
cov3 = cov_cluster(m3, clusters)
se3 = np.sqrt(cov3[1, 1])
t3 = m3.params[1] / se3
p3 = 2 * sp_stats.t.sf(abs(t3), df=m3.df_resid)
results.append({"beta": m3.params[1], "se": se3, "p": p3,
                "n": int(m3.nobs), "r2": m3.rsquared,
                "demo": True, "fe": True})

# Print summary
for i, r in enumerate(results):
    print(f"Col {i+1}: beta={r['beta']:.4f}, SE={r['se']:.4f}, p={r['p']:.6f}, N={r['n']}, R2={r['r2']:.4f}")

# Generate LaTeX
def fmt_coef(b, p):
    return f"${b:.3f}{stars(p)}$"

def fmt_se(s):
    return f"({s:.3f})"

def fmt_n(n):
    return f"{n:,}"

latex = r"""\begin{table}[htbp]
\centering
\begin{threeparttable}
\caption{CFPS Household Panel: Baseline Revision--Error Regressions}
\label{tab:cfps_baseline}
{\small
\begin{tabular}{lccc}
\toprule
 & \multicolumn{3}{c}{Dependent variable: Forecast error proxy$_{it+1}$} \\
\cmidrule(lr){2-4}
 & (1) & (2) & (3) \\
\midrule
"""

# Beta row
latex += r"$\hat{\beta}$ (revision) "
for r in results:
    latex += f"& {fmt_coef(r['beta'], r['p'])} "
latex += r"\\" + "\n"

# SE row
latex += " "
for r in results:
    latex += f"& {fmt_se(r['se'])} "
latex += r"\\" + "\n"

latex += r"\addlinespace" + "\n"

# N row
latex += "Observations "
for r in results:
    latex += f"& {fmt_n(r['n'])} "
latex += r"\\" + "\n"

# R2 row
latex += "$R^2$ "
for r in results:
    latex += f"& {r['r2']:.3f} "
latex += r"\\" + "\n"

latex += r"\addlinespace" + "\n"

# FE indicators
latex += r"Demographics & $\times$ & $\checkmark$ & $\checkmark$ \\" + "\n"
latex += r"Province $\times$ wave FE & $\times$ & $\times$ & $\checkmark$ \\" + "\n"

latex += r"""\bottomrule
\end{tabular}
}
\begin{tablenotes}[flushleft]
\footnotesize
\item \textit{Notes:} The dependent variable is a forecast-error proxy constructed by matching household inflation expectations (coded $\{-1,0,1\}$) to subsequent province-level realized CPI inflation. The revision variable is the inter-wave change in expectation coding. Demographic controls: age, education years, income, gender, urban status. Standard errors in parentheses are clustered at the province level. $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$.
\end{tablenotes}
\end{threeparttable}
\end{table}
"""

with open(OUT, "w", encoding="utf-8") as f:
    f.write(latex)

print(f"\nTable written to {OUT}")
