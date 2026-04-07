"""
19_distributional_evidence.py
Distributional evidence for the revision-error relationship.
Outputs:
  - outputs/tables/fe_by_revision_category.tex
  - outputs/figures/fe_distribution_by_revision.pdf
  - outputs/figures/fe_distribution_by_revision.png
"""

import os
import numpy as np
import pandas as pd
from scipy import stats
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ── paths ────────────────────────────────────────────────────────────────────
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "processed", "cfps_revision_panel.csv")
TAB_DIR = os.path.join(ROOT, "outputs", "tables")
FIG_DIR = os.path.join(ROOT, "outputs", "figures")
os.makedirs(TAB_DIR, exist_ok=True)
os.makedirs(FIG_DIR, exist_ok=True)

# ── load and restrict sample ─────────────────────────────────────────────────
df = pd.read_csv(DATA)
keep_cols = ["fe_proxy", "revision", "province", "wave"]
df = df.dropna(subset=keep_cols).copy()
print(f"Sample after dropping incomplete cases: N = {len(df):,}")

# ── define revision categories ───────────────────────────────────────────────
def rev_cat(x):
    if x < 0:
        return "Downward"
    elif x == 0:
        return "Unchanged"
    else:
        return "Upward"

df["rev_cat"] = df["revision"].apply(rev_cat)

# ── summary statistics by group ──────────────────────────────────────────────
order = ["Downward", "Unchanged", "Upward"]
rows = []
for cat in order:
    g = df.loc[df["rev_cat"] == cat, "fe_proxy"]
    rows.append({
        "Category": cat,
        "N": int(len(g)),
        "Mean": g.mean(),
        "Median": g.median(),
        "SD": g.std(),
    })

summary = pd.DataFrame(rows)

# difference Upward - Downward with t-test
up = df.loc[df["rev_cat"] == "Upward", "fe_proxy"]
dn = df.loc[df["rev_cat"] == "Downward", "fe_proxy"]
diff_mean = up.mean() - dn.mean()
t_stat, p_val = stats.ttest_ind(up, dn, equal_var=False)

if p_val < 0.01:
    stars = "***"
elif p_val < 0.05:
    stars = "**"
elif p_val < 0.10:
    stars = "*"
else:
    stars = ""

print(f"\nDifference (Upward - Downward): {diff_mean:.4f}  t = {t_stat:.2f}  p = {p_val:.4g}")

# ── write LaTeX table ────────────────────────────────────────────────────────
tex_path = os.path.join(TAB_DIR, "fe_by_revision_category.tex")
with open(tex_path, "w", encoding="utf-8") as f:
    f.write("\\begin{table}[htbp]\n")
    f.write("\\centering\n")
    f.write("\\begin{threeparttable}\n")
    f.write("\\caption{Forecast-Error Distribution by Revision Category}\n")
    f.write("\\label{tab:fe_by_revision}\n")
    f.write("\\begin{tabular}{lcccc}\n")
    f.write("\\toprule\n")
    f.write("Category & $N$ & Mean & Median & SD \\\\\n")
    f.write("\\midrule\n")
    for _, r in summary.iterrows():
        f.write(f"{r['Category']} & {r['N']:,} & {r['Mean']:.4f} & {r['Median']:.4f} & {r['SD']:.4f} \\\\\n")
    f.write("\\midrule\n")
    f.write(f"Difference (Upward $-$ Downward) & & {diff_mean:.4f}{stars} & & \\\\\n")
    f.write("\\bottomrule\n")
    f.write("\\end{tabular}\n")
    f.write("\\begin{tablenotes}[flushleft]\\small\n")
    f.write("\\item \\textit{Notes:} The table reports summary statistics of the forecast-error proxy "
            "by belief-revision category. Downward: revision $< 0$; Unchanged: revision $= 0$; "
            "Upward: revision $> 0$. The difference row reports the mean difference with significance "
            "from a Welch two-sample $t$-test. ")
    f.write("$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.\n")
    f.write("\\end{tablenotes}\n")
    f.write("\\end{threeparttable}\n")
    f.write("\\end{table}\n")

print(f"Table written to {tex_path}")

# ── figure: overlapping densities ────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(6.5, 4.2))

colors = {"Downward": "#2166ac", "Unchanged": "#878787", "Upward": "#b2182b"}
labels_n = {}
for cat in order:
    g = df.loc[df["rev_cat"] == cat, "fe_proxy"]
    labels_n[cat] = f"{cat} ($N$ = {len(g):,})"

for cat in order:
    g = df.loc[df["rev_cat"] == cat, "fe_proxy"]
    ax.hist(g, bins=50, density=True, alpha=0.35, color=colors[cat], label=labels_n[cat])
    # KDE overlay
    xmin, xmax = g.quantile(0.005), g.quantile(0.995)
    xs = np.linspace(xmin, xmax, 300)
    try:
        kde = stats.gaussian_kde(g.dropna())
        ax.plot(xs, kde(xs), color=colors[cat], linewidth=1.5)
    except Exception:
        pass
    # vertical mean line
    ax.axvline(g.mean(), color=colors[cat], linestyle="--", linewidth=1.0, alpha=0.8)

ax.set_xlabel("Forecast Error Proxy", fontsize=11)
ax.set_ylabel("Density", fontsize=11)
ax.legend(frameon=False, fontsize=9)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.tick_params(labelsize=9)

fig.tight_layout()

pdf_path = os.path.join(FIG_DIR, "fe_distribution_by_revision.pdf")
png_path = os.path.join(FIG_DIR, "fe_distribution_by_revision.png")
fig.savefig(pdf_path, bbox_inches="tight")
fig.savefig(png_path, dpi=300, bbox_inches="tight")
plt.close(fig)

print(f"Figure written to {pdf_path}")
print(f"Figure written to {png_path}")
print("Done.")
