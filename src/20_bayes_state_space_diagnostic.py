"""
Bayesian state-space model for time-varying diagnostic strength beta_t.

Core equations (quarterly):
  FE_t   = alpha + beta_t * FR_t + gamma' Z_t + eps_t,   eps_t ~ N(0, R)
  beta_t = beta_{t-1} + d' X_t + u_t,                    u_t   ~ N(0, Q)

Where:
  - mu_cp: Carlson–Parkin quantified expected inflation for next quarter (pp)
  - CPI_QoQ_Ann: realized CPI Quarter-on-Quarter Annualized inflation rate (pp)
  - FE_t = CPI_QoQ_Ann_{t+1} - mu_cp_t
  - FR_t = mu_cp_t - mu_cp_{t-1}
  - Z_t includes Food CPI control (Food_CPI_YoY_qavg) to address "pork/food cycle" concerns.
  - X_t includes uncertainty proxies (EPU, GPR) to allow state-dependent diagnostic intensity.

Inputs:
  data/processed/panel_quarterly.csv

Outputs:
  outputs/tables/ssm_posterior_params.tex
  outputs/tables/beta_t_path.tex
  outputs/tables/ssm_sample.tex
  outputs/tables/beta_t_path.csv    (for plotting / robustness)
  outputs/figures/beta_t.png
  outputs/figures/beta_t.tex        (LaTeX figure wrapper)

LaTeX requirements (in your paper preamble):
  \\usepackage{booktabs}
  \\usepackage{threeparttable}
  \\usepackage{graphicx}
"""

from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from _paths import PROCESSED_DIR, TAB_DIR, FIG_DIR, ensure_dirs
from utils_latex import write_three_line_table, write_figure_wrapper

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"

# Plotting configuration
plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman"],
    "mathtext.fontset": "cm",
    "axes.unicode_minus": False
})


def _draw_norm(
    mean: np.ndarray, cov: np.ndarray, rng: np.random.Generator
) -> np.ndarray:
    L = np.linalg.cholesky(cov)
    z = rng.standard_normal(mean.shape[0])
    return mean + L @ z


def _inv_gamma_draw(a: float, b: float, rng: np.random.Generator) -> float:
    # If X ~ InvGamma(a,b) with density proportional to x^{-a-1} exp(-b/x),
    # then 1/X ~ Gamma(a, 1/b). We use numpy's gamma(k, theta).
    return 1.0 / rng.gamma(shape=a, scale=1.0 / b)


def carter_kohn_scalar(
    y: np.ndarray,
    H: np.ndarray,
    Z: np.ndarray,
    X: np.ndarray,
    alpha: float,
    gamma: np.ndarray,
    d: np.ndarray,
    R: float,
    Q: float,
    beta0_mean: float,
    beta0_var: float,
    rng: np.random.Generator,
) -> np.ndarray:
    """
    Sample beta_{1:T} for scalar-state linear Gaussian SSM with time-varying observation slope H_t
    and drift X_t' d in the state equation.
    """
    T = y.shape[0]
    beta_f = np.zeros(T)
    P_f = np.zeros(T)
    a_pred = np.zeros(T)
    P_pred = np.zeros(T)

    # Forward filter
    beta_prev = beta0_mean
    P_prev = beta0_var
    for t in range(T):
        a = beta_prev + float(X[t] @ d)
        P = P_prev + Q

        y_t = y[t] - alpha - float(Z[t] @ gamma)
        v = y_t - H[t] * a
        F = (H[t] ** 2) * P + R
        K = (P * H[t]) / F

        beta_curr = a + K * v
        P_curr = P - K * H[t] * P

        beta_f[t] = beta_curr
        P_f[t] = P_curr
        a_pred[t] = a
        P_pred[t] = P

        beta_prev, P_prev = beta_curr, P_curr

    # Backward simulation smoother
    beta = np.zeros(T)
    beta[T - 1] = rng.normal(loc=beta_f[T - 1], scale=np.sqrt(P_f[T - 1]))

    for t in range(T - 2, -1, -1):
        # predicted mean for next period given beta_t: a_{t+1} = beta_f[t] + X_{t+1}' d
        a_next = beta_f[t] + float(X[t + 1] @ d)
        P_next = P_f[t] + Q
        J = P_f[t] / P_next
        mean = beta_f[t] + J * (beta[t + 1] - a_next)
        var = P_f[t] - J * P_next * J
        var = max(var, 1e-12)
        beta[t] = rng.normal(loc=mean, scale=np.sqrt(var))

    return beta


def main():
    ensure_dirs()
    ap = argparse.ArgumentParser()
    ap.add_argument("--panel", type=str, default=str(PANEL_FILE))
    ap.add_argument("--exp_var", type=str, default="mu_cp")
    ap.add_argument("--infl_var", type=str, default="CPI_QoQ_Ann")
    ap.add_argument(
        "--z_cols", nargs="*", default=["Food_CPI_YoY_qavg", "M2_YoY", "PPI_YoY"]
    )
    ap.add_argument("--x_cols", nargs="*", default=["epu_qavg", "gpr_qavg"])
    ap.add_argument("--draws", type=int, default=6000)
    ap.add_argument("--burn", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=123)
    ap.add_argument("--thin", type=int, default=2)
    ap.add_argument(
        "--standardize_yH",
        type=int,
        default=0,
        help="1: z-score y and H before estimation (useful for index-type exp_var)",
    )
    ap.add_argument(
        "--lambda_Q",
        type=float,
        default=1.0,
        help="Q prior scale factor: aQ0=2, bQ0=lambda_Q*1.0 (smaller=tighter prior on Q)",
    )
    ap.add_argument("--outdir", type=str, default=None)
    args = ap.parse_args()

    panel = pd.read_csv(args.panel)
    if "quarter" not in panel.columns:
        raise ValueError("panel_quarterly.csv must contain 'quarter'.")

    # Sort by quarter
    panel["_q"] = pd.PeriodIndex(panel["quarter"], freq="Q")
    panel = panel.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)

    required = [args.exp_var, args.infl_var] + list(args.z_cols) + list(args.x_cols)
    for c in required:
        if c not in panel.columns:
            raise ValueError(f"Missing required column in panel: {c}")

    # Construct FE (next-quarter forecast error) and FR (forecast revision)
    panel[f"{args.infl_var}_lead1"] = panel[args.infl_var].shift(-1)
    panel["FE_next"] = panel[f"{args.infl_var}_lead1"] - panel[args.exp_var]
    panel["FR"] = panel[args.exp_var] - panel[args.exp_var].shift(1)

    # Controls Z and drivers X
    z_cols = [c for c in args.z_cols if c in panel.columns]
    x_cols = [c for c in args.x_cols if c in panel.columns]

    use = panel.dropna(subset=["FE_next", "FR"] + z_cols + x_cols).copy()
    use = use.reset_index(drop=True)

    y = use["FE_next"].to_numpy(dtype=float)
    H = use["FR"].to_numpy(dtype=float)

    # Optionally standardize y and H (recommended if exp_var is an index not in pp units)
    if int(args.standardize_yH) == 1:
        y = (y - y.mean()) / y.std(ddof=0)
        H = (H - H.mean()) / H.std(ddof=0)

    Z = use[z_cols].to_numpy(dtype=float)
    X = use[x_cols].to_numpy(dtype=float)

    # Standardize Z and X for numerical stability (keep y and H in levels)
    Z = (Z - Z.mean(axis=0)) / Z.std(axis=0, ddof=0)
    X = (X - X.mean(axis=0)) / X.std(axis=0, ddof=0)

    T = y.shape[0]
    kz = Z.shape[1]
    kx = X.shape[1]

    # Priors
    V_theta0 = np.eye(1 + kz) * 100.0**2
    V_d0 = np.eye(kx) * 100.0**2
    aR0, bR0 = 2.0, 1.0
    aQ0, bQ0 = 2.0, args.lambda_Q * 1.0  # Use lambda_Q for prior sensitivity
    beta0_mean, beta0_var = 0.0, 1.0

    rng = np.random.default_rng(args.seed)

    # Initialize
    alpha = 0.0
    gamma = np.zeros(kz)
    d = np.zeros(kx)
    R = 1.0
    Q = 0.1
    beta = np.zeros(T)

    draws = int(args.draws)
    burn = int(args.burn)
    thin = int(args.thin)

    keep_beta = []
    keep_params = []

    X_theta = np.column_stack([np.ones(T), Z])

    for it in range(draws):
        # 1) beta | rest
        beta = carter_kohn_scalar(
            y, H, Z, X, alpha, gamma, d, R, Q, beta0_mean, beta0_var, rng
        )

        # 2) (alpha, gamma) | beta, R  via conjugate Normal
        y_star = y - H * beta
        XtX = X_theta.T @ X_theta
        V0_inv = np.linalg.inv(V_theta0)
        Vn = np.linalg.inv(V0_inv + XtX / R)
        mn = Vn @ (X_theta.T @ y_star / R)
        theta = _draw_norm(mn, Vn, rng)
        alpha = float(theta[0])
        gamma = theta[1:]

        # 3) d | beta, Q  using delta_beta = X d + u
        delta_beta = beta - np.r_[beta0_mean, beta[:-1]]
        # use X_t for the same t (aligned with our state eq)
        Xd = X
        Vd0_inv = np.linalg.inv(V_d0)
        Vdn = np.linalg.inv(Vd0_inv + (Xd.T @ Xd) / Q)
        mdn = Vdn @ (Xd.T @ delta_beta / Q)
        d = _draw_norm(mdn, Vdn, rng)

        # 4) R | eps
        eps = y - (alpha + H * beta + (Z @ gamma))
        aR = aR0 + 0.5 * T
        bR = bR0 + 0.5 * float(eps @ eps)
        R = _inv_gamma_draw(aR, bR, rng)

        # 5) Q | u
        u = delta_beta - (Xd @ d)
        aQ = aQ0 + 0.5 * T
        bQ = bQ0 + 0.5 * float(u @ u)
        Q = _inv_gamma_draw(aQ, bQ, rng)

        if it >= burn and ((it - burn) % thin == 0):
            keep_beta.append(beta.copy())
            keep_params.append([alpha, *gamma.tolist(), *d.tolist(), R, Q])

        if (it + 1) % 1000 == 0:
            print(f"[SSM] iter {it + 1}/{draws}")

    keep_beta = np.asarray(keep_beta)  # nsave x T
    keep_params = np.asarray(keep_params)

    # Posterior summaries
    beta_mean = keep_beta.mean(axis=0)
    beta_p05 = np.quantile(keep_beta, 0.05, axis=0)
    beta_p95 = np.quantile(keep_beta, 0.95, axis=0)

    beta_df = pd.DataFrame(
        {
            "quarter": use["quarter"].to_list(),
            "beta_mean": beta_mean,
            "beta_p05": beta_p05,
            "beta_p95": beta_p95,
        }
    )

    if args.outdir:
        outdir = Path(args.outdir)
        outdir.mkdir(parents=True, exist_ok=True)
        beta_df.to_csv(outdir / "beta_path.csv", index=False, encoding="utf-8-sig")
        print(f"[SSM] wrote: {outdir / 'beta_path.csv'}")

    # Always output LaTeX tables and figures to default paths
    beta_csv = TAB_DIR / "beta_t_path.csv"
    beta_df.to_csv(beta_csv, index=False, encoding="utf-8-sig")

    # LaTeX table for beta path
    write_three_line_table(
        beta_df,
        TAB_DIR / "beta_t_path.tex",
        caption="Time-Varying Diagnostic Intensity $\\beta_t$ (Posterior Mean and 90\\% Interval)",
       label="tab:beta_path",
        notes=[
            "Measurement equation: $FE_t = \\alpha + \\beta_t FR_t + \\gamma'Z_t + \\varepsilon_t$.",
            "When $\\beta_t<0$, forecast revisions are negatively correlated with forecast errors, reflecting overreaction (diagnostic expectations).",
        ],
        float_format="{:.3f}",
    )

    # Posterior parameter table
    names = (
        ["alpha"]
        + [f"gamma_{c}" for c in z_cols]
        + [f"d_{c}" for c in x_cols]
        + ["R_var", "Q_var"]
    )
    summ = []
    for j, nm in enumerate(names):
        col = keep_params[:, j]
        summ.append(
            {
                "param": nm,
                "mean": float(np.mean(col)),
                "sd": float(np.std(col, ddof=1)),
                "p05": float(np.quantile(col, 0.05)),
                "p95": float(np.quantile(col, 0.95)),
            }
        )
    summ_df = pd.DataFrame(summ)
    write_three_line_table(
        summ_df,
        TAB_DIR / "ssm_posterior_params.tex",
        caption="Bayesian State-Space Model: Posterior Summary of Parameters",
        label="tab:ssm_params",
        notes=[
            "Z are standardized control variables (includes food inflation control); X are standardized uncertainty proxies (EPU/GPR).",
            "R\\_var is measurement error variance, Q\\_var is state innovation variance.",
        ],
        float_format="{:.3f}",
    )

    # Sample table (explicitly document 2011 start)
    sample = pd.DataFrame(
        [
            {
                "estimation_start": use["quarter"].iloc[0],
                "estimation_end": use["quarter"].iloc[-1],
                "T_quarters": int(T),
                "note": "Survey series starts from 2011Q1; CP method requires category breakdowns, leading to a potentially shorter effective estimation sample (see Appendix).",
            }
        ]
    )
    write_three_line_table(
        sample,
        TAB_DIR / "ssm_sample.tex",
        caption="SSM Estimation Sample Information",
        label="tab:ssm_sample",
        notes=["Estimation sample consists of quarters where mu\\_cp, CPI\\_YoY, and all control variables are available."],
        float_format="{:.0f}",
    )

    # Plot beta_t with professional styling
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    fig_path = FIG_DIR / "beta_t.png"
    
    # Set publication style
    plt.rcParams['font.family'] = 'serif'
    plt.rcParams['font.serif'] = ['Times New Roman', 'DejaVu Serif']
    plt.rcParams['font.size'] = 10
    plt.rcParams['figure.facecolor'] = 'white'
    plt.rcParams['axes.facecolor'] = 'white'
    plt.rcParams['savefig.dpi'] = 300
    plt.rcParams['savefig.bbox'] = 'tight'
    
    fig, ax = plt.subplots(figsize=(8, 4.5))
    x = np.arange(T)
    
    # Main line - professional blue
    ax.plot(x, beta_mean, color='#2E5090', linewidth=2, label=r'Posterior Mean $\beta_t$')
    
    # Credible interval - light blue fill
    ax.fill_between(x, beta_p05, beta_p95, alpha=0.25, color='#7FA5D2', 
                     label='90% Credible Interval')
    
    # Zero reference line
    ax.axhline(0.0, color='#5A5A5A', linestyle='--', linewidth=1.2, alpha=0.7)
    
    # Styling
    ax.set_xlabel('Quarter', fontsize=11)
    ax.set_ylabel(r'Diagnostic Parameter $\beta_t$', fontsize=11)
    ax.legend(loc='lower left', frameon=False, fontsize=9)
    ax.grid(True, alpha=0.2, linestyle=':', linewidth=0.5)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # X-axis formatting
    ax.set_xticks(x[::max(1, T // 10)])
    ax.set_xticklabels(use["quarter"].to_list()[::max(1, T // 10)], 
                       rotation=45, ha='right', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(fig_path, dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()

    # Figure wrapper tex (relative path from paper root is user-defined; we keep outputs/figures/...)
    write_figure_wrapper(
        image_rel_path="outputs/figures/beta_t.png",
        tex_path=FIG_DIR / "beta_t.tex",
        caption="Posterior Path of Time-Varying Diagnostic Intensity $\\beta_t$ (90\\% Credible Band)",
        label="fig:beta_t",
        width=r"0.95\linewidth",
    )

    print(f"[SSM] wrote: {TAB_DIR / 'ssm_posterior_params.tex'}")
    print(f"[SSM] wrote: {TAB_DIR / 'beta_t_path.tex'}")
    print(f"[SSM] wrote: {TAB_DIR / 'ssm_sample.tex'}")
    print(f"[SSM] wrote: {fig_path}")
    print(f"[SSM] wrote: {FIG_DIR / 'beta_t.tex'}")


if __name__ == "__main__":
    main()
