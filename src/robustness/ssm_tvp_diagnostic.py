#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TVP-SSM (Bayesian state-space) estimation of time-varying diagnostic strength beta_t.

Model (quarterly):
  FE_t   = alpha + beta_t * FR_t + gamma' Z_t + eps_t,   eps_t ~ N(0, R)
  beta_t = beta_{t-1} + d' X_t + u_t,                    u_t   ~ N(0, Q)

Default construction (if you use exp_var=mu_cp, infl_var=CPI_QoQ_Ann):
  FE_t = infl_{t+1} - exp_t
  FR_t = exp_t - exp_{t-1}

Outputs:
  - beta_path.csv: quarter, beta_mean, beta_p05, beta_p95
  - params_summary.csv: posterior summaries
  - beta_t.png: plot of beta_t with 90% band

Notes:
  - For alternative expectation measures (e.g., an index), levels may not be comparable to inflation in pp.
    In that case, consider --standardize_yH 1 to interpret only the sign of beta_t.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

def _draw_norm(mean: np.ndarray, cov: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    L = np.linalg.cholesky(cov)
    z = rng.standard_normal(mean.shape[0])
    return mean + L @ z

def _inv_gamma_draw(a: float, b: float, rng: np.random.Generator) -> float:
    # If X ~ InvGamma(a,b) with density proportional to x^{-a-1} exp(-b/x),
    # then 1/X ~ Gamma(a, 1/b).
    return 1.0 / rng.gamma(shape=a, scale=1.0/b)

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
    """Sample beta_{1:T} for scalar-state linear Gaussian SSM with observation slope H_t and drift X_t' d."""
    T = y.shape[0]
    beta_f = np.zeros(T)
    P_f = np.zeros(T)

    beta_prev = beta0_mean
    P_prev = beta0_var

    for t in range(T):
        a = beta_prev + float(X[t] @ d)
        P = P_prev + Q

        y_t = y[t] - alpha - float(Z[t] @ gamma)
        v = y_t - H[t] * a
        F = (H[t]**2) * P + R
        K = (P * H[t]) / F

        beta_curr = a + K * v
        P_curr = P - K * H[t] * P

        beta_f[t] = beta_curr
        P_f[t] = P_curr

        beta_prev, P_prev = beta_curr, P_curr

    # Backward simulation smoother
    beta = np.zeros(T)
    beta[T-1] = rng.normal(loc=beta_f[T-1], scale=np.sqrt(P_f[T-1]))

    for t in range(T-2, -1, -1):
        a_next = beta_f[t] + float(X[t+1] @ d)
        P_next = P_f[t] + Q
        J = P_f[t] / P_next
        mean = beta_f[t] + J * (beta[t+1] - a_next)
        var = P_f[t] - J * P_next * J
        var = max(var, 1e-12)
        beta[t] = rng.normal(loc=mean, scale=np.sqrt(var))

    return beta

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--panel", type=str, required=True)
    ap.add_argument("--exp_var", type=str, default="mu_cp")
    ap.add_argument("--infl_var", type=str, default="CPI_QoQ_Ann")
    ap.add_argument("--z_cols", nargs="*", default=["Food_CPI_YoY_qavg","M2_YoY","PPI_YoY"])
    ap.add_argument("--x_cols", nargs="*", default=["epu_qavg","gpr_qavg"])
    ap.add_argument("--draws", type=int, default=6000)
    ap.add_argument("--burn", type=int, default=1000)
    ap.add_argument("--thin", type=int, default=2)
    ap.add_argument("--seed", type=int, default=123)
    ap.add_argument("--standardize_yH", type=int, default=0, help="1: z-score y and H before estimation (useful for index-type exp_var)")
    ap.add_argument("--outdir", type=str, default="outputs/ssm")
    args = ap.parse_args()

    panel = pd.read_csv(args.panel)
    if "quarter" not in panel.columns:
        raise ValueError("panel must contain 'quarter'.")

    panel["_q"] = pd.PeriodIndex(panel["quarter"], freq="Q")
    panel = panel.sort_values("_q").drop(columns=["_q"]).reset_index(drop=True)

    for c in [args.exp_var, args.infl_var] + list(args.z_cols) + list(args.x_cols):
        if c not in panel.columns:
            raise ValueError(f"Missing column: {c}")

    panel["infl_lead1"] = panel[args.infl_var].shift(-1)
    panel["FE_next"] = panel["infl_lead1"] - panel[args.exp_var]
    panel["FR"] = panel[args.exp_var] - panel[args.exp_var].shift(1)

    z_cols = [c for c in args.z_cols if c in panel.columns]
    x_cols = [c for c in args.x_cols if c in panel.columns]

    use = panel.dropna(subset=["FE_next","FR"] + z_cols + x_cols).copy().reset_index(drop=True)
    if use.shape[0] < 20:
        raise RuntimeError(f"Too few usable observations: {use.shape[0]}")

    y = use["FE_next"].to_numpy(float)
    H = use["FR"].to_numpy(float)

    # Optionally standardize y and H (recommended if exp_var is an index not in pp units)
    if int(args.standardize_yH) == 1:
        y = (y - y.mean()) / y.std(ddof=0)
        H = (H - H.mean()) / H.std(ddof=0)

    Z = use[z_cols].to_numpy(float)
    X = use[x_cols].to_numpy(float)

    # Standardize Z and X for stability
    Z = (Z - Z.mean(axis=0)) / Z.std(axis=0, ddof=0)
    X = (X - X.mean(axis=0)) / X.std(axis=0, ddof=0)

    T = y.shape[0]
    kz = Z.shape[1]
    kx = X.shape[1]

    # Priors
    V_theta0 = np.eye(1 + kz) * (100.0**2)
    V_d0 = np.eye(kx) * (100.0**2)
    aR0, bR0 = 2.0, 1.0
    aQ0, bQ0 = 2.0, 1.0
    beta0_mean, beta0_var = 0.0, 1.0

    rng = np.random.default_rng(int(args.seed))

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
        beta = carter_kohn_scalar(y, H, Z, X, alpha, gamma, d, R, Q, beta0_mean, beta0_var, rng)

        # 2) (alpha, gamma) | beta, R
        y_star = y - H * beta
        XtX = X_theta.T @ X_theta
        V0_inv = np.linalg.inv(V_theta0)
        Vn = np.linalg.inv(V0_inv + XtX / R)
        mn = Vn @ (X_theta.T @ y_star / R)
        theta = _draw_norm(mn, Vn, rng)
        alpha = float(theta[0])
        gamma = theta[1:]

        # 3) d | beta, Q
        delta_beta = beta - np.r_[beta0_mean, beta[:-1]]
        Vd0_inv = np.linalg.inv(V_d0)
        Vdn = np.linalg.inv(Vd0_inv + (X.T @ X) / Q)
        mdn = Vdn @ (X.T @ delta_beta / Q)
        d = _draw_norm(mdn, Vdn, rng)

        # 4) R | eps
        eps = y - (alpha + H * beta + (Z @ gamma))
        aR = aR0 + 0.5 * T
        bR = bR0 + 0.5 * float(eps @ eps)
        R = _inv_gamma_draw(aR, bR, rng)

        # 5) Q | u
        u = delta_beta - (X @ d)
        aQ = aQ0 + 0.5 * T
        bQ = bQ0 + 0.5 * float(u @ u)
        Q = _inv_gamma_draw(aQ, bQ, rng)

        if it >= burn and ((it - burn) % thin == 0):
            keep_beta.append(beta.copy())
            keep_params.append([alpha, *gamma.tolist(), *d.tolist(), R, Q])

        if (it+1) % 1000 == 0:
            print(f"[SSM] iter {it+1}/{draws}")

    keep_beta = np.asarray(keep_beta)
    keep_params = np.asarray(keep_params)

    beta_mean = keep_beta.mean(axis=0)
    beta_p05 = np.quantile(keep_beta, 0.05, axis=0)
    beta_p95 = np.quantile(keep_beta, 0.95, axis=0)

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    beta_df = pd.DataFrame({
        "quarter": use["quarter"].tolist(),
        "beta_mean": beta_mean,
        "beta_p05": beta_p05,
        "beta_p95": beta_p95,
    })
    beta_df.to_csv(outdir/"beta_path.csv", index=False, encoding="utf-8-sig")

    # Parameter summary
    names = (["alpha"] + [f"gamma_{c}" for c in z_cols] + [f"d_{c}" for c in x_cols] + ["R_var","Q_var"])
    summ=[]
    for j,nm in enumerate(names):
        col = keep_params[:, j]
        summ.append({
            "param": nm,
            "mean": float(np.mean(col)),
            "sd": float(np.std(col, ddof=1)),
            "p05": float(np.quantile(col, 0.05)),
            "p95": float(np.quantile(col, 0.95)),
        })
    pd.DataFrame(summ).to_csv(outdir/"params_summary.csv", index=False, encoding="utf-8-sig")

    # Plot beta_t
    plt.figure(figsize=(9,3))
    x = np.arange(len(beta_mean))
    plt.plot(x, beta_mean)
    plt.fill_between(x, beta_p05, beta_p95, alpha=0.2)
    plt.axhline(0.0, linewidth=1.0)
    tick_step = max(1, len(x)//10)
    plt.xticks(x[::tick_step], beta_df["quarter"].iloc[::tick_step], rotation=45, ha="right")
    plt.tight_layout()
    plt.savefig(outdir/"beta_t.png", dpi=200)
    plt.close()

    print("[SSM] wrote:", (outdir/"beta_path.csv").as_posix())
    print("[SSM] wrote:", (outdir/"params_summary.csv").as_posix())
    print("[SSM] wrote:", (outdir/"beta_t.png").as_posix())

if __name__ == "__main__":
    main()
