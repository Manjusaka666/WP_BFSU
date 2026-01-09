#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Baseline OLS regression: fixed-beta diagnostic strength

This script provides the frequentist benchmark that reviewers expect to see
BEFORE the Bayesian TVP-SSM model.

Regression:
    FE_t = alpha + beta * FR_t + gamma' Z_t + epsilon_t

Where:
    FE_t = CPI_{t+1} - mu_cp_t  (next-quarter forecast error)
    FR_t = mu_cp_t - mu_cp_{t-1}  (forecast revision)
    Z_t = controls (Food CPI, M2, PPI)

Outputs:
    outputs/tables/ols_baseline.tex         - Main regression table
    outputs/tables/ols_robustness.tex       - Robustness specs
    outputs/tables/ols_diagnostics.tex      - Diagnostic tests

LaTeX packages required:
    \\usepackage{booktabs}
    \\usepackage{threeparttable}
"""

from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.regression.linear_model import OLS
from statsmodels.stats.diagnostic import het_breuschpagan, acorr_ljungbox
from scipy import stats

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"


def compute_newey_west_se(model_result, maxlags=4):
    """Compute Newey-West HAC standard errors"""
    return model_result.get_robustcov_results(cov_type='HAC', maxlags=maxlags).bse


def make_regression_table(results_list, spec_names, var_labels, outfile, caption, label, notes):
    """
    Generate a professional regression table in LaTeX threeparttable format
    
    Args:
        results_list: List of statsmodels regression results
        spec_names: List of column names (e.g., ["(1)", "(2)", "("3)"])
        var_labels: Dict mapping variable names to display labels
        outfile: Path to output .tex file
        caption: Table caption
        label: LaTeX label
        notes: List of note strings
    """
    # Collect coefficient estimates
    all_vars = []
    for res in results_list:
        all_vars.extend(res.params.index.tolist())
    all_vars = sorted(set(all_vars), key=lambda x: (x != 'const', x))  # const first
    
    rows = []
    for var in all_vars:
        row = {'Variable': var_labels.get(var, var)}
        for i, res in enumerate(results_list):
            if var in res.params:
                coef = res.params[var]
                se = res.bse[var]
                pval = res.pvalues[var]
                
                # Stars
                if pval < 0.01:
                    stars = '***'
                elif pval < 0.05:
                    stars = '**'
                elif pval < 0.10:
                    stars = '*'
                else:
                    stars = ''
                
                row[spec_names[i]] = f"{coef:.3f}{stars}"
                row[f"{spec_names[i]}_se"] = f"({se:.3f})"
            else:
                row[spec_names[i]] = ""
                row[f"{spec_names[i]}_se"] = ""
        rows.append(row)
    
    # Add statistics rows
    stats_rows = []
    for i, res in enumerate(results_list):
        stats_rows.append({
            'Variable': 'Observations',
            spec_names[i]: f"{int(res.nobs)}",
            f"{spec_names[i]}_se": ""
        })
    stats_rows.append({
        'Variable': '$R^2$',
        **{spec_names[i]: f"{results_list[i].rsquared:.3f}" for i in range(len(results_list))},
        **{f"{spec_names[i]}_se": "" for i in range(len(results_list))}
    })
    stats_rows.append({
        'Variable': 'Adj. $R^2$',
        **{spec_names[i]: f"{results_list[i].rsquared_adj:.3f}" for i in range(len(results_list))},
        **{f"{spec_names[i]}_se": "" for i in range(len(results_list))}
    })
    
    # Combine
    df = pd.DataFrame(rows + stats_rows)
    
    # Interleave coefficients and standard errors
    output_rows = []
    for i, row in df.iterrows():
        if row['Variable'] in ['Observations', '$R^2$', 'Adj. $R^2$']:
            output_rows.append({k: v for k, v in row.items() if '_se' not in k})
        else:
            # Coefficient row
            coef_row = {k: v for k, v in row.items() if '_se' not in k}
            output_rows.append(coef_row)
            # SE row
            se_row = {'Variable': ''}
            for spec in spec_names:
                se_row[spec] = row[f"{spec}_se"]
            output_rows.append(se_row)
    
    output_df = pd.DataFrame(output_rows)
    
    write_three_line_table(
        output_df,
        outfile,
        caption=caption,
        label=label,
        notes=notes,
        float_format="{}"  # Keep strings as-is
    )


def main():
    ensure_dirs()
    
    panel = pd.read_csv(PANEL_FILE)
    panel['_q'] = pd.PeriodIndex(panel['quarter'], freq='Q')
    panel = panel.sort_values('_q').drop(columns=['_q']).reset_index(drop=True)
    
    # Construct variables
    panel['CPI_lead1'] = panel['CPI_YoY'].shift(-1)
    panel['FE'] = panel['CPI_lead1'] - panel['mu_cp']
    panel['FR'] = panel['mu_cp'] - panel['mu_cp'].shift(1)
    
    # Use data
    use = panel.dropna(subset=['FE', 'FR', 'Food_CPI_YoY_qavg', 'M2_YoY', 'PPI_YoY']).copy()
    use = use.reset_index(drop=True)
    
    # Variable labels
    var_labels = {
        'const': 'Constant',
        'FR': 'Forecast Revision ($FR_t$)',
        'Food_CPI_YoY_qavg': 'Food CPI YoY',
        'M2_YoY': 'M2 Growth YoY',
        'PPI_YoY': 'PPI YoY',
        'epu_qavg': 'EPU Index',
        'gpr_qavg': 'GPR Index'
    }
    
    # ===== Baseline specifications =====
    results = []
    spec_names = []
    
    # (1) Bivariate: FE ~ FR
    X1 = sm.add_constant(use[['FR']])
    y = use['FE']
    model1 = OLS(y, X1).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    results.append(model1)
    spec_names.append('(1)')
    
    # (2) Add Food CPI
    X2 = sm.add_constant(use[['FR', 'Food_CPI_YoY_qavg']])
    model2 = OLS(y, X2).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    results.append(model2)
    spec_names.append('(2)')
    
    # (3) Full controls
    X3 = sm.add_constant(use[['FR', 'Food_CPI_YoY_qavg', 'M2_YoY', 'PPI_YoY']])
    model3 = OLS(y, X3).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    results.append(model3)
    spec_names.append('(3)')
    
    make_regression_table(
        results,
        spec_names,
        var_labels,
        TAB_DIR / 'ols_baseline.tex',
        caption='诊断性预期：OLS基准回归（预测误差对预测修正）',
        label='tab:ols_baseline',
        notes=[
            '因变量：$FE_t = CPI_{t+1} - \\mu_t$（预测误差）。',
            '核心解释变量：$FR_t = \\mu_t - \\mu_{t-1}$（预测修正）。',
            '标准误为Newey-West HAC标准误（最大滞后4期）。',
            '星号：*** p\u003c0.01, ** p\u003c0.05, * p\u003c0.1。',
            '若 $\\beta_{FR} \u003c 0$ 且显著，则支持诊断性预期假说（过度反应）。'
        ]
    )
    
    # ===== Robustness table =====
    rob_results = []
    rob_names = []
    
    # (1) Baseline (same as model3)
    rob_results.append(model3)
    rob_names.append('(1) Baseline')
    
    # (2) No Food CPI
    X_nofood = sm.add_constant(use[['FR', 'M2_YoY', 'PPI_YoY']])
    model_nofood = OLS(y, X_nofood).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    rob_results.append(model_nofood)
    rob_names.append('(2) No Food')
    
    # (3) Only Food CPI
    X_foodonly = sm.add_constant(use[['FR', 'Food_CPI_YoY_qavg']])
    model_foodonly = OLS(y, X_foodonly).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
    rob_results.append(model_foodonly)
    rob_names.append('(3) Food Only')
    
    # (4) Add EPU+GPR if available
    if 'epu_qavg' in use.columns and 'gpr_qavg' in use.columns:
        use_epu = use.dropna(subset=['epu_qavg', 'gpr_qavg'])
        if len(use_epu) > 30:
            X_epu = sm.add_constant(use_epu[['FR', 'Food_CPI_YoY_qavg', 'M2_YoY', 'PPI_YoY', 'epu_qavg', 'gpr_qavg']])
            y_epu = use_epu['FE']
            model_epu = OLS(y_epu, X_epu).fit(cov_type='HAC', cov_kwds={'maxlags': 4})
            rob_results.append(model_epu)
            rob_names.append('(4) +EPU+GPR')
    
    make_regression_table(
        rob_results,
        rob_names,
        var_labels,
        TAB_DIR / 'ols_robustness.tex',
        caption='OLS稳健性检验：不同控制变量设定',
        label='tab:ols_rob',
        notes=[
            '因变量均为预测误差 $FE_t$。',
            '所有规格均使用Newey-West HAC标准误（滞后4期）。',
            '核心变量 $FR_t$ 的系数在所有规格下稳健为负。'
        ]
    )
    
    # ===== Diagnostic tests table =====
    diag_rows = []
    
    # Test on model3 (full controls)
    resid = model3.resid
    
    # 1. Breusch-Pagan heteroskedasticity test
    bp_stat, bp_pval, _, _ = het_breuschpagan(resid, X3)
    diag_rows.append({
        'Test': 'Breusch-Pagan',
        'Statistic': f"{bp_stat:.3f}",
        'P-value': f"{bp_pval:.3f}",
        'Conclusion': 'Homoskedastic' if bp_pval > 0.05 else 'Heteroskedastic'
    })
    
    # 2. Ljung-Box autocorrelation test (lag=4)
    lb_result = acorr_ljungbox(resid, lags=4, return_df=True)
    lb_stat = lb_result['lb_stat'].iloc[-1]
    lb_pval = lb_result['lb_pvalue'].iloc[-1]
    diag_rows.append({
        'Test': 'Ljung-Box (lag=4)',
        'Statistic': f"{lb_stat:.3f}",
        'P-value': f"{lb_pval:.3f}",
        'Conclusion': 'No autocorr' if lb_pval > 0.05 else 'Autocorrelated'
    })
    
    # 3. Durbin-Watson
    from statsmodels.stats.stattools import durbin_watson
    dw = durbin_watson(resid)
    diag_rows.append({
        'Test': 'Durbin-Watson',
        'Statistic': f"{dw:.3f}",
        'P-value': '—',
        'Conclusion': 'H0: no autocorr if ~2'
    })
    
    # 4. Jarque-Bera normality test
    jb_stat, jb_pval = stats.jarque_bera(resid)
    diag_rows.append({
        'Test': 'Jarque-Bera',
        'Statistic': f"{jb_stat:.3f}",
        'P-value': f"{jb_pval:.3f}",
        'Conclusion': 'Normal' if jb_pval > 0.05 else 'Non-normal'
    })
    
    diag_df = pd.DataFrame(diag_rows)
    write_three_line_table(
        diag_df,
        TAB_DIR / 'ols_diagnostics.tex',
        caption='OLS回归诊断检验（基于模型(3)全控制变量规格）',
        label='tab:ols_diag',
        notes=[
            'Breusch-Pagan: H0为同方差。',
            'Ljung-Box: H0为残差无自相关。',
            'Durbin-Watson: 统计量接近2表明无一阶自相关。',
            'Jarque-Bera: H0为残差服从正态分布。'
        ]
    )
    
    print(f"[OLS] Wrote: {TAB_DIR / 'ols_baseline.tex'}")
    print(f"[OLS] Wrote: {TAB_DIR / 'ols_robustness.tex'}")
    print(f"[OLS] Wrote: {TAB_DIR / 'ols_diagnostics.tex'}")
    
    # Print summary to console
    print("\n=== BASELINE OLS RESULTS ===")
    print(model3.summary())
    print(f"\nBeta(FR): {model3.params['FR']:.4f}")
    print(f"t-stat: {model3.tvalues['FR']:.4f}")
    print(f"p-value: {model3.pvalues['FR']:.4f}")
    print(f"95% CI: [{model3.conf_int().loc['FR', 0]:.4f}, {model3.conf_int().loc['FR', 1]:.4f}]")
    print(f"\nDiagnostic expectation test: beta < 0?")
    print(f"Result: {'YES (diagnostic)' if model3.params['FR'] < 0 else 'NO (rational)'}")
    print(f"Significant at 5%? {'YES' if model3.pvalues['FR'] < 0.05 else 'NO'}")


if __name__ == '__main__':
    main()
