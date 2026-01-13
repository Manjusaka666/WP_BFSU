#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bayesian VAR with sign restrictions for "diagnostic expectations" identification.

Restriction (generalized):
  (R1) IRF_exp(0) > 0
  (R2) FE reversal: IRF_infl(h+1) - IRF_exp(h) < 0 for h=0..fe_kmax-1

Where exp is the expectation variable (default mu_cp), infl is inflation (default CPI_QoQ_Ann).

Outputs:
  - acceptance.csv
  - irf_summary.csv (p16/p50/p84 at key horizons)
  - irf.png (bands)
  - fe_reversal.png (derived FE bands from accepted draws)
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

def lagmat(Y: np.ndarray, p: int) -> np.ndarray:
    T, n = Y.shape
    return np.hstack([Y[p - i : T - i, :] for i in range(1, p + 1)])

def bvar_niw_posterior(Y: np.ndarray, p: int, B0: np.ndarray, V0: np.ndarray, S0: np.ndarray, nu0: int):
    T, n = Y.shape
    X = lagmat(Y, p)
    Yt = Y[p:, :]
    X = np.hstack([np.ones((T - p, 1)), X])
    k = X.shape[1]

    V0_inv = np.linalg.inv(V0)
    Vn = np.linalg.inv(V0_inv + X.T @ X)
    Bn = Vn @ (V0_inv @ B0 + X.T @ Yt)
    Sn = S0 + (Yt - X @ Bn).T @ (Yt - X @ Bn) + (Bn - B0).T @ V0_inv @ (Bn - B0)
    nun = nu0 + (T - p)
    return Bn, Vn, Sn, nun

def sample_wishart_bartlett(scale: np.ndarray, df: int, rng: np.random.Generator) -> np.ndarray:
    p = scale.shape[0]
    L = np.linalg.cholesky(scale)
    A = np.zeros((p, p))
    for i in range(p):
        A[i, i] = np.sqrt(rng.chisquare(df - i))
        for j in range(i):
            A[i, j] = rng.normal()
    LA = L @ A
    return LA @ LA.T

def sample_invwishart(df: int, scale: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    W = sample_wishart_bartlett(np.linalg.inv(scale), df=df, rng=rng)
    return np.linalg.inv(W)

def sample_matrix_normal(Bn: np.ndarray, Vn: np.ndarray, Sigma: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    LV = np.linalg.cholesky(Vn)
    LS = np.linalg.cholesky(Sigma)
    Z = rng.normal(size=Bn.shape)
    return Bn + LV @ Z @ LS.T

def irf_from_companion(B: np.ndarray, Sigma: np.ndarray, n: int, p: int, H: int) -> np.ndarray:
    A = B[1:, :].T  # n x (n*p)

    comp = np.zeros((n * p, n * p))
    comp[:n, :] = A
    if p > 1:
        comp[n:, :-n] = np.eye(n * (p - 1))

    P = np.linalg.cholesky(Sigma)
    irfs = np.zeros((H + 1, n, n))
    irfs[0] = P

    M = np.eye(n * p)
    for h in range(1, H + 1):
        M = M @ comp
        irfs[h] = M[:n, :n] @ P
    return irfs

def random_orthonormal(n: int, rng: np.random.Generator) -> np.ndarray:
    Q, _ = np.linalg.qr(rng.normal(size=(n, n)))
    return Q

def plot_irf_bands(h, med, lo, hi, names, title, out_png: Path):
    out_png.parent.mkdir(parents=True, exist_ok=True)
    n = len(names)
    fig, axes = plt.subplots(n, 1, figsize=(7, 2.0 * n), sharex=True)
    if n == 1:
        axes = [axes]
    for i, ax in enumerate(axes):
        ax.fill_between(h, lo[:, i], hi[:, i], alpha=0.25)
        ax.plot(h, med[:, i], linewidth=1.5)
        ax.axhline(0.0, linewidth=0.8)
        ax.set_ylabel(names[i])
    axes[-1].set_xlabel("Horizon (quarters)")
    fig.suptitle(title, y=0.995)
    fig.tight_layout()
    fig.savefig(out_png, dpi=200)
    plt.close(fig)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--panel", type=str, required=True)
    ap.add_argument("--vars", nargs="+", default=["mu_cp","CPI_QoQ_Ann","Ind_Value_Added_YoY","epu_qavg","gpr_qavg"])
    ap.add_argument("--exp_var", type=str, default="mu_cp")
    ap.add_argument("--infl_var", type=str, default="CPI_QoQ_Ann")
    ap.add_argument("--p", type=int, default=2)
    ap.add_argument("--H", type=int, default=12)
    ap.add_argument("--draws", type=int, default=2000)
    ap.add_argument("--subdraws", type=int, default=200)
    ap.add_argument("--fe_kmax", type=int, default=4)
    ap.add_argument("--seed", type=int, default=123)
    ap.add_argument("--outdir", type=str, default="outputs/bvar")
    args = ap.parse_args()

    df = pd.read_csv(args.panel)
    missing = [c for c in args.vars if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns in panel: {missing}")

    df_use = df[args.vars].dropna().copy()
    if df_use.shape[0] < (args.p + 15):
        raise RuntimeError(f"Too few observations after dropna: {df_use.shape[0]}")

    # standardize
    Y_raw = df_use.to_numpy(float)
    Y = (Y_raw - Y_raw.mean(axis=0)) / Y_raw.std(axis=0, ddof=0)
    T, n = Y.shape
    varnames = args.vars

    if args.exp_var not in varnames or args.infl_var not in varnames:
        raise ValueError("--exp_var and --infl_var must be included in --vars")

    idx_exp = varnames.index(args.exp_var)
    idx_infl = varnames.index(args.infl_var)

    # NIW prior (weakly informative)
    k = 1 + n * args.p
    B0 = np.zeros((k, n))
    V0 = np.eye(k) * 10.0
    S0 = np.eye(n)
    nu0 = n + 2

    Bn, Vn, Sn, nun = bvar_niw_posterior(Y, args.p, B0, V0, S0, nu0)
    rng = np.random.default_rng(int(args.seed))

    accepted = []
    tried_rot = 0

    def find_de_shock_column(irfs: np.ndarray):
        H = irfs.shape[0] - 1
        kmax = min(int(args.fe_kmax), H - 1)
        for j in range(n):
            for sgn in (+1, -1):
                if sgn * irfs[0, idx_exp, j] <= 0:
                    continue
                ok = True
                for h in range(0, kmax):
                    fe_h = (sgn * irfs[h + 1, idx_infl, j]) - (sgn * irfs[h, idx_exp, j])
                    if fe_h >= 0:
                        ok = False
                        break
                if ok:
                    return j, sgn
        return None

    H = int(args.H)
    for _ in range(int(args.draws)):
        Sigma = sample_invwishart(df=nun, scale=Sn, rng=rng)
        B = sample_matrix_normal(Bn, Vn, Sigma, rng=rng)
        irfs_base = irf_from_companion(B, Sigma, n=n, p=int(args.p), H=H)

        found = False
        for _sd in range(int(args.subdraws)):
            tried_rot += 1
            Q = random_orthonormal(n, rng=rng)
            irfs_rot = irfs_base @ Q
            res = find_de_shock_column(irfs_rot)
            if res is not None:
                j, sgn = res
                accepted.append(sgn * irfs_rot[:, :, j])  # (H+1, n)
                found = True
                break
        # if not found: reject draw

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    acc_n = len(accepted)
    acc = pd.DataFrame([{
        "accepted_draws": acc_n,
        "posterior_draws": int(args.draws),
        "rotations_per_draw": int(args.subdraws),
        "total_rotations": tried_rot,
        "accept_rate": acc_n / int(args.draws),
    }])
    acc.to_csv(outdir/"acceptance.csv", index=False, encoding="utf-8-sig")

    if acc_n == 0:
        print("[BVAR] 0 accepted draws. Try smaller fe_kmax or larger subdraws.")
        return

    accepted = np.asarray(accepted)  # (acc_n, H+1, n)
    q16 = np.quantile(accepted, 0.16, axis=0)
    q50 = np.quantile(accepted, 0.50, axis=0)
    q84 = np.quantile(accepted, 0.84, axis=0)

    # key horizons
    key_h = sorted(set([0,1,2,4,8,H]))
    rows=[]
    for i,nm in enumerate(varnames):
        for h in key_h:
            rows.append({"variable": nm, "h": h, "p16": q16[h,i], "p50": q50[h,i], "p84": q84[h,i]})
    pd.DataFrame(rows).to_csv(outdir/"irf_summary.csv", index=False, encoding="utf-8-sig")

    # plots
    hgrid = np.arange(H+1)
    plot_irf_bands(hgrid, q50, q16, q84, varnames, "IRFs to identified DE shock", outdir/"irf.png")

    # derived FE reversal plot (bands computed from accepted draws, not from marginal quantiles)
    kmax = min(int(args.fe_kmax), H-1)
    fe_draws = []
    for d in accepted:
        fe = np.array([d[h+1, idx_infl] - d[h, idx_exp] for h in range(kmax)])
        fe_draws.append(fe)
    fe_draws = np.asarray(fe_draws)
    fe_q16 = np.quantile(fe_draws, 0.16, axis=0)
    fe_q50 = np.quantile(fe_draws, 0.50, axis=0)
    fe_q84 = np.quantile(fe_draws, 0.84, axis=0)

    hh = np.arange(kmax)
    plt.figure(figsize=(7,3))
    plt.fill_between(hh, fe_q16, fe_q84, alpha=0.25)
    plt.plot(hh, fe_q50, linewidth=1.5)
    plt.axhline(0.0, linewidth=0.8)
    plt.title("Derived FE reversal: IRF(infl_{h+1} - exp_{h})")
    plt.xlabel("h (quarters)")
    plt.ylabel("FE IRF (std. units)")
    plt.tight_layout()
    plt.savefig(outdir/"fe_reversal.png", dpi=200)
    plt.close()

    print(f"[BVAR] accepted: {acc_n}/{int(args.draws)}")
    print("[BVAR] wrote:", (outdir/"irf_summary.csv").as_posix())
    print("[BVAR] wrote:", (outdir/"acceptance.csv").as_posix())
    print("[BVAR] wrote:", (outdir/"irf.png").as_posix())
    print("[BVAR] wrote:", (outdir/"fe_reversal.png").as_posix())

if __name__ == "__main__":
    main()
