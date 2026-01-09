#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MCMC Convergence Diagnostics for TVP-SSM

Computes and outputs:
1. Geweke diagnostic (comparing first 10% vs last 50% of chain)
2. Geleman-Rubin R-hat (requires running multiple chains)
3. Effective Sample Size (ESS)
4. Autocorrelation plots

This addresses the critical reviewer question: "How do you know your MCMC converged?"

Outputs:
    outputs/tables/mcmc_diagnostics.tex
    outputs/figures/mcmc_trace.png
    outputs/figures/mcmc_acf.png

LaTeX packages:
    \\usepackage{booktabs}
    \\usepackage{threeparttable}
    \\usepackage{graphicx}
"""

from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

from _paths import PROCESSED_DIR, TAB_DIR, FIG_DIR, ensure_dirs
from utils_latex import write_three_line_table

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"


def geweke_diagnostic(chain: np.ndarray, first: float = 0.1, last: float = 0.5) -> tuple[float, float]:
    """
    Geweke convergence diagnostic comparing means of early vs late portions of chain
    
    Args:
        chain: 1D array of MCMC samples
        first: Fraction of chain to use for "early" (default 0.1 = first 10%)
        last: Fraction of chain to use for "late" (default 0.5 = last 50%)
    
    Returns:
        z_score: Geweke z-statistic
        p_value: Two-sided p-value
    
    Interpretation:
        H0: chain has converged (means are equal)
        |z| < 1.96 => do not reject H0 (good!)
    """
    n = len(chain)
    n1 = int(n * first)
    n2_start = int(n * (1 - last))
    
    A = chain[:n1]
    B = chain[n2_start:]
    
    # Spectral density at zero (accounts for autocorrelation)
    # Simple approximation: variance * (1 + 2*rho_1)
    def spectral_var(x):
        var = np.var(x, ddof=1)
        if len(x) > 2:
            rho1 = np.corrcoef(x[:-1], x[1:])[0, 1]
            return var * (1 + 2 * max(0, rho1))
        return var
    
    var_A = spectral_var(A) / len(A)
    var_B = spectral_var(B) / len(B)
    
    z = (np.mean(A) - np.mean(B)) / np.sqrt(var_A + var_B)
    p_value = 2 * (1 - stats.norm.cdf(abs(z)))
    
    return z, p_value


def compute_ess(chain: np.ndarray, max_lag: int = None) -> float:
    """
    Effective Sample Size via autocorrelation
    
    ESS = N / (1 + 2 * sum(rho_k))
    
    where rho_k is the autocorrelation at lag k
    """
    n = len(chain)
    if max_lag is None:
        max_lag = min(n // 2, 100)
    
    # Demean
    x = chain - np.mean(chain)
    
    # ACF
    c0 = np.dot(x, x) / n
    acf = np.array([np.dot(x[:n-k], x[k:]) / n / c0 for k in range(1, max_lag + 1)])
    
    # Sum until ACF becomes insignificant or negative
    sum_rho = 0.0
    for k, rho_k in enumerate(acf, 1):
        if rho_k < 0.05:  # threshold
            break
        sum_rho += rho_k
    
    inefficiency_factor = 1 + 2 * sum_rho
    ess = n / inefficiency_factor
    
    return max(1.0, ess)


def gelman_rubin_rhat(chains: list[np.ndarray]) -> float:
    """
    Gelman-Rubin R-hat statistic for multiple chains
    
    Args:
        chains: List of M chains, each of length N
    
    Returns:
        R_hat: Potential scale reduction factor
    
    Interpretation:
        R_hat close to 1.0 => converged
        R_hat < 1.1 is the standard threshold
        R_hat < 1.05 is more conservative
    """
    M = len(chains)  # number of chains
    N = len(chains[0])  # length of each chain
    
    # Overall mean
    grand_mean = np.mean([np.mean(chain) for chain in chains])
    
    # Within-chain variance
    W = np.mean([np.var(chain, ddof=1) for chain in chains])
    
    # Between-chain variance
    chain_means = np.array([np.mean(chain) for chain in chains])
    B = N * np.var(chain_means, ddof=1)
    
    # Pooled variance estimate
    var_hat = (N - 1) / N * W + B / N
    
    # R_hat
    R_hat = np.sqrt(var_hat / W)
    
    return R_hat


def plot_trace(chains_dict: dict[str, np.ndarray], outfile: Path):
    """Plot trace plots for key parameters"""
    n_params = len(chains_dict)
    fig, axes = plt.subplots(n_params, 1, figsize=(10, 2 * n_params), sharex=True)
    if n_params == 1:
        axes = [axes]
    
    for ax, (param_name, chain) in zip(axes, chains_dict.items()):
        ax.plot(chain, linewidth=0.5, alpha=0.7)
        ax.set_ylabel(param_name)
        ax.axhline(np.mean(chain), color='r', linestyle='--', linewidth=1)
    
    axes[-1].set_xlabel('Iteration')
    fig.suptitle('MCMC Trace Plots (post-burnin)', y=0.995)
    fig.tight_layout()
    fig.savefig(outfile, dpi=200)
    plt.close(fig)


def plot_acf(chains_dict: dict[str, np.ndarray], outfile: Path, max_lag=40):
    """Plot autocorrelation functions"""
    n_params = len(chains_dict)
    fig, axes = plt.subplots(n_params, 1, figsize=(8, 2 * n_params), sharex=True)
    if n_params == 1:
        axes = [axes]
    
    for ax, (param_name, chain) in zip(axes, chains_dict.items()):
        n = len(chain)
        x = chain - np.mean(chain)
        c0 = np.dot(x, x) / n
        lags = np.arange(0, min(max_lag + 1, n // 2))
        acf_vals = [1.0] + [np.dot(x[:n-k], x[k:]) / n / c0 for k in range(1, len(lags))]
        
        ax.stem(lags, acf_vals, basefmt=" ")
        ax.axhline(0, color='k', linewidth=0.8)
        ax.axhline(0.05, color='r', linestyle='--', linewidth=0.8)
        ax.axhline(-0.05, color='r', linestyle='--', linewidth=0.8)
        ax.set_ylabel(f'{param_name}\\nACF')
        ax.set_ylim(-0.3, 1.1)
    
    axes[-1].set_xlabel('Lag')
    fig.suptitle('Autocorrelation Functions', y=0.995)
    fig.tight_layout()
    fig.savefig(outfile, dpi=200)
    plt.close(fig)


def _draw_norm(mean: np.ndarray, cov: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Draw from multivariate normal distribution"""
    L = np.linalg.cholesky(cov)
    z = rng.standard_normal(mean.shape[0])
    return mean + L @ z


def _inv_gamma_draw(a: float, b: float, rng: np.random.Generator) -> float:
    """Draw from inverse gamma distribution"""
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
    Forward filter backward sampler for scalar state SSM
    """
    T = y.shape[0]
    beta_f = np.zeros(T)
    P_f = np.zeros(T)
    
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
        
        beta_prev, P_prev = beta_curr, P_curr
    
    # Backward sampler
    beta = np.zeros(T)
    beta[T - 1] = rng.normal(loc=beta_f[T - 1], scale=np.sqrt(P_f[T - 1]))
    
    for t in range(T - 2, -1, -1):
        a_next = beta_f[t] + float(X[t + 1] @ d)
        P_next = P_f[t] + Q
        J = P_f[t] / P_next
        mean = beta_f[t] + J * (beta[t + 1] - a_next)
        var = P_f[t] - J * P_next * J
        var = max(var, 1e-12)
        beta[t] = rng.normal(loc=mean, scale=np.sqrt(var))
    
    return beta


def main():
    """
    This script runs multiple independent MCMC chains to compute convergence diagnostics.
    """
    ensure_dirs()
    
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--panel', default=str(PANEL_FILE))
    ap.add_argument('--n_chains', type=int, default=3, help='Number of independent chains for R-hat')
    ap.add_argument('--draws_per_chain', type=int, default=5000)
    ap.add_argument('--burn', type=int, default=1000)
    ap.add_argument('--seed_base', type=int, default=123)
    args = ap.parse_args()
    
    # Load data (same as 20_bayes_state_space_diagnostic.py)
    panel = pd.read_csv(args.panel)
    panel['_q'] = pd.PeriodIndex(panel['quarter'], freq='Q')
    panel = panel.sort_values('_q').drop(columns=['_q']).reset_index(drop=True)
    
    panel['CPI_lead1'] = panel['CPI_YoY'].shift(-1)
    panel['FE_next'] = panel['CPI_lead1'] - panel['mu_cp']
    panel['FR'] = panel['mu_cp'] - panel['mu_cp'].shift(1)
    
    z_cols = ['Food_CPI_YoY_qavg', 'M2_YoY', 'PPI_YoY']
    x_cols = ['epu_qavg', 'gpr_qavg']
    
    use = panel.dropna(subset=['FE_next', 'FR'] + z_cols + x_cols).copy().reset_index(drop=True)
    
    y = use['FE_next'].to_numpy(dtype=float)
    H = use['FR'].to_numpy(dtype=float)
    Z = use[z_cols].to_numpy(dtype=float)
    X = use[x_cols].to_numpy(dtype=float)
    
    # Standardize
    Z = (Z - Z.mean(axis=0)) / Z.std(axis=0, ddof=0)
    X = (X - X.mean(axis=0)) / X.std(axis=0, ddof=0)
    
    T, kz, kx = y.shape[0], Z.shape[1], X.shape[1]
    
    # Priors
    V_theta0 = np.eye(1 + kz) * 100**2
    V_d0 = np.eye(kx) * 100**2
    aR0, bR0 = 2.0, 1.0
    aQ0, bQ0 = 2.0, 1.0
    beta0_mean, beta0_var = 0.0, 1.0
    
    # Run M chains
    all_chains_params = {f'chain_{m}': [] for m in range(args.n_chains)}
    
    for m in range(args.n_chains):
        print(f"\n=== Running chain {m+1}/{args.n_chains} ===")
        rng = np.random.default_rng(args.seed_base + m * 1000)
        
        # Initialize
        alpha, gamma, d = 0.0, np.zeros(kz), np.zeros(kx)
        R, Q, beta = 1.0, 0.1, np.zeros(T)
        
        X_theta = np.column_stack([np.ones(T), Z])
        keep_params = []
        
        for it in range(args.draws_per_chain):
            # MCMC steps (same as 20_bayes_...)
            beta = carter_kohn_scalar(y, H, Z, X, alpha, gamma, d, R, Q, beta0_mean, beta0_var, rng)
            
            y_star = y - H * beta
            XtX = X_theta.T @ X_theta
            V0_inv = np.linalg.inv(V_theta0)
            Vn = np.linalg.inv(V0_inv + XtX / R)
            mn = Vn @ (X_theta.T @ y_star / R)
            theta = _draw_norm(mn, Vn, rng)
            alpha = float(theta[0])
            gamma = theta[1:]
            
            delta_beta = beta - np.r_[beta0_mean, beta[:-1]]
            Vd0_inv = np.linalg.inv(V_d0)
            Vdn = np.linalg.inv(Vd0_inv + (X.T @ X) / Q)
            mdn = Vdn @ (X.T @ delta_beta / Q)
            d = _draw_norm(mdn, Vdn, rng)
            
            eps = y - (alpha + H * beta + Z @ gamma)
            aR = aR0 + 0.5 * T
            bR = bR0 + 0.5 * float(eps @ eps)
            R = _inv_gamma_draw(aR, bR, rng)
            
            u = delta_beta - X @ d
            aQ = aQ0 + 0.5 * T
            bQ = bQ0 + 0.5 * float(u @ u)
            Q = _inv_gamma_draw(aQ, bQ, rng)
            
            if it >= args.burn:
                keep_params.append([alpha, gamma[0], d[0], R, Q])
            
            if (it + 1) % 1000 == 0:
                print(f"  Chain {m+1}: iter {it + 1}/{args.draws_per_chain}")
        
        all_chains_params[f'chain_{m}'] = np.array(keep_params)
    
    # Diagnostics table
    param_names = ['alpha', 'gamma[0]', 'd[0]', 'R', 'Q']
    diag_rows = []
    
    for j, pname in enumerate(param_names):
        # Extract parameter j from all chains
        chains = [all_chains_params[f'chain_{m}'][:, j] for m in range(args.n_chains)]
        
        # Geweke (use first chain)
        z, p = geweke_diagnostic(chains[0])
        
        # R-hat
        rhat = gelman_rubin_rhat(chains)
        
        # ESS (use first chain)
        ess = compute_ess(chains[0])
        
        diag_rows.append({
            'Parameter': pname,
            'Geweke_z': f"{z:.3f}",
            'Geweke_p': f"{p:.3f}",
            'R_hat': f"{rhat:.4f}",
            'ESS': f"{int(ess)}",
            'Converged': '✓' if (abs(z) < 1.96 and rhat < 1.1 and ess > 400) else '✗'
        })
    
    diag_df = pd.DataFrame(diag_rows)
    write_three_line_table(
        diag_df,
        TAB_DIR / 'mcmc_diagnostics.tex',
        caption='MCMC收敛性诊断检验',
        label='tab:mcmc_diag',
        notes=[
            'Geweke: H0为链已收敛（前10\\\\%与后50\\\\%均值相等），|z|<1.96为通过。',
            f'Gelman-Rubin: 基于{args.n_chains}条独立链，$\\\\hat{{R}}<1.1$（保守：<1.05）为通过。',
            'ESS: 有效样本量，ESS>400为经验阈值。',
            '收敛判断：同时满足Geweke、R-hat和ESS标准。'
        ]
    )
    
    # Trace and ACF plots (use first chain for visualization)
    chain0 = all_chains_params['chain_0']
    plot_dict = {pname: chain0[:, j] for j, pname in enumerate(param_names)}
    
    plot_trace(plot_dict, FIG_DIR / 'mcmc_trace.png')
    plot_acf(plot_dict, FIG_DIR / 'mcmc_acf.png')
    
    print(f"\n[MCMC Diagnostics] Wrote: {TAB_DIR / 'mcmc_diagnostics.tex'}")
    print(f"[MCMC Diagnostics] Wrote: {FIG_DIR / 'mcmc_trace.png'}")
    print(f"[MCMC Diagnostics] Wrote: {FIG_DIR / 'mcmc_acf.png'}")
    
    # Print summary
    print("\n=== CONVERGENCE SUMMARY ===")
    print(diag_df.to_string(index=False))
    
    all_pass = all(diag_df['Converged'] == '✓')
    print(f"\nOverall convergence: {'PASS ✓' if all_pass else 'FAIL ✗'}")
    if not all_pass:
        print("⚠ Some parameters failed convergence tests. Consider:")
        print("  - Increasing burn-in period")
        print("  - Running more iterations")
        print("  - Checking prior specifications")


if __name__ == '__main__':
    main()
