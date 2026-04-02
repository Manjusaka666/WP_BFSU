"""
18_diagnostic_nk_calibration.py
================================
Simple structural calibration of a 3-equation Diagnostic New Keynesian model.

Model (Bordalo, Gennaioli, Shleifer 2020; Bianchi, Ilut, Saijo 2024):
    Phillips Curve:  pi_t = beta * E_t^theta[pi_{t+1}] + kappa * x_t + u_t
    IS Curve:        x_t  = E_t[x_{t+1}] - sigma^{-1}(i_t - E_t^theta[pi_{t+1}]) + eps_t
    Taylor Rule:     i_t  = phi_pi * pi_t + phi_x * x_t

Diagnostic expectations:
    E_t^theta[pi_{t+1}] = E_t[pi_{t+1}] + theta * (E_t[pi_{t+1}] - E_{t-1}[pi_{t+1}])

The script solves the reduced-form system for each theta on a grid,
computes inflation/output-gap variance driven by cost-push shocks,
welfare loss L(theta) = Var(pi) + lambda_w * Var(x), and the welfare
gain from de-biasing relative to the rational benchmark (theta=0).

Outputs:
    outputs/tables/nk_welfare.tex
    outputs/figures/welfare_theta.pdf
"""

import sys, os
import numpy as np
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
TABLE_DIR = ROOT / "outputs" / "tables"
FIG_DIR = ROOT / "outputs" / "figures"
TABLE_DIR.mkdir(parents=True, exist_ok=True)
FIG_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Calibration
# ---------------------------------------------------------------------------
beta   = 0.99      # quarterly discount factor
kappa  = 0.05      # Phillips curve slope (lower for China)
sigma  = 2.0       # CRRA
phi_pi = 1.5       # Taylor rule on inflation
phi_x  = 0.5       # Taylor rule on output gap
epsilon_ds = 6.0   # Dixit-Stiglitz elasticity of substitution

# Welfare weight on output gap variance (Woodford derivation)
lambda_w = kappa / epsilon_ds

# Shock variances (normalised; levels cancel in welfare-gain ratios)
sigma_u2 = 1.0     # cost-push shock variance
sigma_e2 = 0.0     # demand shock (set to zero -- focus on supply side)

# Theta grid
theta_grid = np.array([0.0, 0.25, 0.50, 0.55, 0.75, 1.00, 1.20, 1.50])

# ---------------------------------------------------------------------------
# Model solution
# ---------------------------------------------------------------------------
# Under the diagnostic NK with a Taylor rule, we substitute the Taylor rule
# into the IS curve and solve the 2-equation system for (pi_t, x_t) as
# functions of the cost-push shock u_t.
#
# After substitution the system in state-space form becomes:
#
#   pi_t = alpha_pi(theta) * u_t   (reduced-form)
#   x_t  = alpha_x(theta)  * u_t
#
# where the coefficients come from solving the contemporaneous system.
#
# --- Derivation (AR(1) cost-push shock u_t = rho_u * u_{t-1} + eps_u) ---
# For simplicity we use an i.i.d. cost-push shock (rho_u=0), which gives
# analytical closed-form solutions. With rho_u=0, E_t[u_{t+1}]=0, and the
# diagnostic distortion operates through lagged beliefs about endogenous
# variables.
#
# Under the minimal-state-variable (MSV) solution conjecture:
#   pi_t = a * u_t
#   x_t  = b * u_t
#
# Rational expectations:
#   E_t[pi_{t+1}] = 0   (u is i.i.d.)
#   E_{t-1}[pi_{t+1}] = 0
# So the diagnostic wedge is zero for an i.i.d. shock under MSV.
#
# To generate a non-trivial diagnostic wedge, we need persistence.
# Use rho_u > 0:  u_t = rho_u * u_{t-1} + eps_u, Var(eps_u) = sigma_u2.
#
# MSV conjecture: pi_t = a * u_t, x_t = b * u_t
#   => E_t[pi_{t+1}] = a * rho_u * u_t
#   => E_{t-1}[pi_{t+1}] = a * rho_u * u_{t-1}
#   => Innovation in expectation = E_t[pi_{t+1}] - E_{t-1}[pi_{t+1}]
#                                = a * rho_u * (u_t - u_{t-1})
#                                = a * rho_u * eps_u_t / ...
#
# Actually, let's work with the state u_t directly.
# E_t[pi_{t+1}] = a * rho_u * u_t
# E_{t-1}[pi_{t+1}] = a * rho_u * E_{t-1}[u_t] = a * rho_u * rho_u * u_{t-1} = a * rho_u^2 * u_{t-1}
#
# Diagnostic expectation:
# E_t^theta[pi_{t+1}] = a*rho_u*u_t + theta*(a*rho_u*u_t - a*rho_u^2*u_{t-1})
#                      = a*rho_u*(1+theta)*u_t - theta*a*rho_u^2*u_{t-1}
#
# This introduces u_{t-1} as a state, so the MSV with only u_t won't work.
# We need the extended state [u_t, u_{t-1}].
#
# Conjecture: pi_t = a1*u_t + a2*u_{t-1}, x_t = b1*u_t + b2*u_{t-1}
#
# This is solvable but messy. For a clean calibration table, we use
# a direct numerical approach: write the system as a VAR and solve via
# the Blanchard-Kahn method adapted for diagnostic expectations.

# ---------------------------------------------------------------------------
# Numerical solution via undetermined coefficients
# ---------------------------------------------------------------------------
# State: s_t = [u_t, u_{t-1}]'
# u_t = rho_u * u_{t-1} + eps_t
#
# Conjecture: pi_t = [a1, a2] . s_t,  x_t = [b1, b2] . s_t
#
# E_t[pi_{t+1}] = a1*rho_u*u_t + a2*u_t  -- wait, let me be more careful.
#
# pi_{t+1} = a1*u_{t+1} + a2*u_t = a1*(rho_u*u_t + eps_{t+1}) + a2*u_t
# E_t[pi_{t+1}] = (a1*rho_u + a2)*u_t
#
# E_{t-1}[pi_{t+1}] = E_{t-1}[a1*u_{t+1} + a2*u_t]
#                    = a1*E_{t-1}[u_{t+1}] + a2*E_{t-1}[u_t]
#                    = a1*rho_u^2*u_{t-1} + a2*rho_u*u_{t-1}
#                    = (a1*rho_u^2 + a2*rho_u)*u_{t-1}
#
# Diagnostic:
# E_t^theta[pi_{t+1}] = (a1*rho_u+a2)*u_t + theta*[(a1*rho_u+a2)*u_t - (a1*rho_u^2+a2*rho_u)*u_{t-1}]
#                      = (1+theta)*(a1*rho_u+a2)*u_t - theta*(a1*rho_u^2+a2*rho_u)*u_{t-1}
#
# Similarly for x:
# x_{t+1} = b1*u_{t+1} + b2*u_t
# E_t[x_{t+1}] = (b1*rho_u + b2)*u_t
#
# Now substitute into the three equations.

def solve_nk_diagnostic(theta, rho_u=0.8):
    """
    Solve the diagnostic NK model by undetermined coefficients.

    State: s_t = [u_t, u_{t-1}]
    Conjecture: pi_t = a1*u_t + a2*u_{t-1}
                x_t  = b1*u_t + b2*u_{t-1}

    Returns (a1, a2, b1, b2).
    """
    # Define shorthand
    rho = rho_u

    # We need to solve a linear system for (a1, a2, b1, b2).
    #
    # Phillips Curve: pi_t = beta * E_t^theta[pi_{t+1}] + kappa * x_t + u_t
    #
    # Coefficient on u_t:
    #   a1 = beta*(1+theta)*(a1*rho + a2) + kappa*b1 + 1
    # Coefficient on u_{t-1}:
    #   a2 = -beta*theta*(a1*rho^2 + a2*rho) + kappa*b2
    #
    # IS Curve (with Taylor rule substituted):
    #   x_t = E_t[x_{t+1}] - (1/sigma)*(i_t - E_t^theta[pi_{t+1}])
    #   i_t = phi_pi*pi_t + phi_x*x_t
    #
    # So: x_t = E_t[x_{t+1}] - (1/sigma)*(phi_pi*pi_t + phi_x*x_t - E_t^theta[pi_{t+1}])
    #     x_t + (phi_x/sigma)*x_t = E_t[x_{t+1}] - (phi_pi/sigma)*pi_t + (1/sigma)*E_t^theta[pi_{t+1}]
    #     x_t*(1 + phi_x/sigma) = E_t[x_{t+1}] - (phi_pi/sigma)*pi_t + (1/sigma)*E_t^theta[pi_{t+1}]
    #
    # Let chi = 1 + phi_x/sigma
    #
    # Coefficient on u_t:
    #   chi*b1 = (b1*rho + b2) - (phi_pi/sigma)*a1 + (1/sigma)*(1+theta)*(a1*rho+a2)
    # Coefficient on u_{t-1}:
    #   chi*b2 = 0 - (phi_pi/sigma)*a2 + (1/sigma)*(-theta)*(a1*rho^2 + a2*rho)
    #          = -(phi_pi/sigma)*a2 - (theta/sigma)*(a1*rho^2 + a2*rho)

    chi = 1.0 + phi_x / sigma

    # System of 4 linear equations in 4 unknowns (a1, a2, b1, b2):
    #
    # (1) a1 - beta*(1+theta)*rho*a1 - beta*(1+theta)*a2 - kappa*b1 = 1
    # (2) a2 + beta*theta*rho^2*a1 + beta*theta*rho*a2 - kappa*b2 = 0
    # (3) (phi_pi/sigma)*a1 - (1/sigma)*(1+theta)*rho*a1 - (1/sigma)*(1+theta)*a2
    #     + chi*b1 - rho*b1 - b2 = 0
    # (4) (phi_pi/sigma)*a2 + (theta/sigma)*rho^2*a1 + (theta/sigma)*rho*a2
    #     + chi*b2 = 0

    A = np.zeros((4, 4))
    c = np.zeros(4)

    # Equation (1): PC, coeff on u_t
    A[0, 0] = 1.0 - beta*(1+theta)*rho          # a1
    A[0, 1] = -beta*(1+theta)                     # a2
    A[0, 2] = -kappa                               # b1
    A[0, 3] = 0.0                                  # b2
    c[0] = 1.0

    # Equation (2): PC, coeff on u_{t-1}
    A[1, 0] = beta*theta*rho**2                    # a1
    A[1, 1] = 1.0 + beta*theta*rho                 # a2
    A[1, 2] = 0.0                                  # b1
    A[1, 3] = -kappa                                # b2
    c[1] = 0.0

    # Equation (3): IS, coeff on u_t
    A[2, 0] = phi_pi/sigma - (1+theta)*rho/sigma  # a1
    A[2, 1] = -(1+theta)/sigma                     # a2
    A[2, 2] = chi - rho                             # b1
    A[2, 3] = -1.0                                  # b2
    c[2] = 0.0

    # Equation (4): IS, coeff on u_{t-1}
    A[3, 0] = theta*rho**2/sigma                   # a1
    A[3, 1] = phi_pi/sigma + theta*rho/sigma        # a2
    A[3, 2] = 0.0                                   # b1
    A[3, 3] = chi                                    # b2
    c[3] = 0.0

    coeffs = np.linalg.solve(A, c)
    return coeffs  # (a1, a2, b1, b2)


def compute_variances(a1, a2, b1, b2, rho_u=0.8, sigma_eps2=1.0):
    """
    Compute unconditional Var(pi) and Var(x) given the solution coefficients.

    pi_t = a1*u_t + a2*u_{t-1}
    x_t  = b1*u_t + b2*u_{t-1}
    u_t  = rho_u*u_{t-1} + eps_t

    Var(u_t) = sigma_eps2 / (1 - rho_u^2)
    Cov(u_t, u_{t-1}) = rho_u * Var(u_t)
    """
    var_u = sigma_eps2 / (1.0 - rho_u**2)
    cov_u = rho_u * var_u

    var_pi = a1**2 * var_u + a2**2 * var_u + 2*a1*a2*cov_u
    var_x  = b1**2 * var_u + b2**2 * var_u + 2*b1*b2*cov_u

    return var_pi, var_x


# ---------------------------------------------------------------------------
# Main computation
# ---------------------------------------------------------------------------
rho_u = 0.8  # persistence of cost-push shock

results = []
for theta in theta_grid:
    a1, a2, b1, b2 = solve_nk_diagnostic(theta, rho_u=rho_u)
    var_pi, var_x = compute_variances(a1, a2, b1, b2, rho_u=rho_u, sigma_eps2=sigma_u2)
    loss = var_pi + lambda_w * var_x
    results.append({
        'theta': theta,
        'var_pi': var_pi,
        'var_x': var_x,
        'loss': loss,
    })

# Compute welfare gain from de-biasing (percentage reduction in loss)
loss_rational = results[0]['loss']
for r in results:
    r['welfare_gain_pct'] = 100.0 * (r['loss'] - loss_rational) / loss_rational

# ---------------------------------------------------------------------------
# Print results
# ---------------------------------------------------------------------------
print("\n" + "="*80)
print("Diagnostic NK Welfare Calibration Results")
print("="*80)
print(f"{'theta':>8s} {'Var(pi)':>12s} {'Var(x)':>12s} {'Loss L':>12s} {'Welfare Cost %':>16s}")
print("-"*64)
for r in results:
    print(f"{r['theta']:8.2f} {r['var_pi']:12.4f} {r['var_x']:12.4f} {r['loss']:12.4f} {r['welfare_gain_pct']:16.2f}")

# Key numbers
theta_055 = [r for r in results if abs(r['theta'] - 0.55) < 0.01][0]
theta_100 = [r for r in results if abs(r['theta'] - 1.00) < 0.01][0]
print(f"\nWelfare cost at theta=0.55 (household estimate): {theta_055['welfare_gain_pct']:.2f}%")
print(f"Welfare cost at theta=1.00 (aggregate implied):  {theta_100['welfare_gain_pct']:.2f}%")

# ---------------------------------------------------------------------------
# LaTeX table
# ---------------------------------------------------------------------------
tex_lines = []
tex_lines.append(r"\begin{table}[htbp]")
tex_lines.append(r"\centering")
tex_lines.append(r"\caption{Welfare Costs of Diagnostic Inflation Expectations}")
tex_lines.append(r"\label{tab:nk_welfare}")
tex_lines.append(r"\begin{tabular}{ccccc}")
tex_lines.append(r"\toprule")
tex_lines.append(r"$\theta$ & $\mathrm{Var}(\pi)$ & $\mathrm{Var}(x)$ & Loss $\mathcal{L}(\theta)$ & Welfare Cost (\%) \\")
tex_lines.append(r"\midrule")
for r in results:
    mark = ""
    if abs(r['theta'] - 0.55) < 0.01:
        mark = r"$^{\dagger}$"
    elif abs(r['theta'] - 1.00) < 0.01:
        mark = r"$^{\ddagger}$"
    tex_lines.append(
        f"  {r['theta']:.2f}{mark} & {r['var_pi']:.4f} & {r['var_x']:.4f} & "
        f"{r['loss']:.4f} & {r['welfare_gain_pct']:.2f} \\\\"
    )
tex_lines.append(r"\bottomrule")
tex_lines.append(r"\end{tabular}")
tex_lines.append(r"\begin{tablenotes}")
tex_lines.append(r"\small")
tex_lines.append(r"\item \textit{Notes:} Welfare loss $\mathcal{L}(\theta) = \mathrm{Var}(\pi) + \lambda \, \mathrm{Var}(x)$ with $\lambda = \kappa/\varepsilon = 0.05/6 \approx 0.0083$.")
tex_lines.append(r"\item Calibration: $\beta=0.99$, $\kappa=0.05$, $\sigma=2$, $\phi_\pi=1.5$, $\phi_x=0.5$, $\rho_u=0.8$.")
tex_lines.append(r"\item Welfare cost is the percentage increase in loss relative to rational benchmark ($\theta=0$).")
tex_lines.append(r"\item $^{\dagger}$ Household survey estimate ($\hat{\beta}_{\mathrm{rev}} \approx -0.55$). $^{\ddagger}$ Aggregate implied ($\hat{\beta}_{\mathrm{rev}} \approx -2.24$).")
tex_lines.append(r"\end{tablenotes}")
tex_lines.append(r"\end{table}")

tex_path = TABLE_DIR / "nk_welfare.tex"
with open(tex_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(tex_lines))
print(f"\nTable written to {tex_path}")

# ---------------------------------------------------------------------------
# Figure: welfare loss as a function of theta
# ---------------------------------------------------------------------------
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

theta_fine = np.linspace(0, 1.5, 200)
losses_fine = []
for th in theta_fine:
    a1, a2, b1, b2 = solve_nk_diagnostic(th, rho_u=rho_u)
    vp, vx = compute_variances(a1, a2, b1, b2, rho_u=rho_u, sigma_eps2=sigma_u2)
    losses_fine.append(vp + lambda_w * vx)
losses_fine = np.array(losses_fine)
welfare_cost_fine = 100.0 * (losses_fine - losses_fine[0]) / losses_fine[0]

fig, ax = plt.subplots(1, 1, figsize=(7, 4.5))
ax.plot(theta_fine, welfare_cost_fine, 'k-', linewidth=2, label=r'Welfare cost $\Delta\mathcal{L}(\theta)$')

# Vertical lines at empirical estimates
ax.axvline(x=0.55, color='#2166ac', linestyle='--', linewidth=1.5,
           label=r'$\hat{\theta}=0.55$ (household)')
ax.axvline(x=1.0, color='#b2182b', linestyle='--', linewidth=1.5,
           label=r'$\hat{\theta}=1.00$ (aggregate)')

# Mark the points
ax.plot(0.55, theta_055['welfare_gain_pct'], 'o', color='#2166ac', markersize=8, zorder=5)
ax.plot(1.00, theta_100['welfare_gain_pct'], 'o', color='#b2182b', markersize=8, zorder=5)

# Annotate
ax.annotate(f"{theta_055['welfare_gain_pct']:.1f}%",
            xy=(0.55, theta_055['welfare_gain_pct']),
            xytext=(0.55+0.12, theta_055['welfare_gain_pct']+2),
            fontsize=10, color='#2166ac',
            arrowprops=dict(arrowstyle='->', color='#2166ac', lw=1.2))
ax.annotate(f"{theta_100['welfare_gain_pct']:.1f}%",
            xy=(1.0, theta_100['welfare_gain_pct']),
            xytext=(1.0+0.12, theta_100['welfare_gain_pct']-3),
            fontsize=10, color='#b2182b',
            arrowprops=dict(arrowstyle='->', color='#b2182b', lw=1.2))

ax.set_xlabel(r'Diagnostic parameter $\theta$', fontsize=12)
ax.set_ylabel(r'Welfare cost relative to RE (\%)', fontsize=12)
ax.set_title('Welfare Cost of Diagnostic Inflation Expectations', fontsize=13)
ax.legend(loc='upper left', fontsize=10)
ax.set_xlim(0, 1.55)
ax.set_ylim(bottom=0)
ax.grid(True, alpha=0.3)
fig.tight_layout()

fig_path = FIG_DIR / "welfare_theta.pdf"
fig.savefig(fig_path, dpi=300, bbox_inches='tight')
fig.savefig(str(fig_path).replace('.pdf', '.png'), dpi=300, bbox_inches='tight')
print(f"Figure written to {fig_path}")

print("\nDone.")
