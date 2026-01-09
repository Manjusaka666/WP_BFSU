#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Enhanced Descriptive Statistics

Generates comprehensive descriptive tables including:
1. Main variables statistics (extended)
2. Forecast Error (FE) and Forecast Revision (FR) statistics
3. Correlation matrix
4. Sub-period statistics (pre/post 2018)

This provides the foundational empirical characterization that reviewers expect.

Outputs:
    outputs/tables/desc_stats_extended.tex
    outputs/tables/fe_fr_stats.tex
    outputs/tables/correlation_matrix.tex
    outputs/tables/subperiod_stats.tex

LaTeX required packages:
    booktabs
    threeparttable
"""

from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd

from _paths import PROCESSED_DIR, TAB_DIR, ensure_dirs
from utils_latex import write_three_line_table

PANEL_FILE = PROCESSED_DIR / "panel_quarterly.csv"


def compute_stats(series: pd.Series) -> dict:
    """Compute comprehensive statistics for a series"""
    return {
        'Mean': series.mean(),
        'Std': series.std(ddof=1),
        'Min': series.min(),
        'P25': series.quantile(0.25),
        'Median': series.quantile(0.50),
        'P75': series.quantile(0.75),
        'Max': series.max(),
        'N': int(series.notna().sum())
    }


def main():
    ensure_dirs()
    
    panel = pd.read_csv(PANEL_FILE)
    panel['_q'] = pd.PeriodIndex(panel['quarter'], freq='Q')
    panel = panel.sort_values('_q').drop(columns=['_q']).reset_index(drop=True)
    
    # Construct derived variables
    panel['CPI_lead1'] = panel['CPI_YoY'].shift(-1)
    panel['FE'] = panel['CPI_lead1'] - panel['mu_cp']
    panel['FR'] = panel['mu_cp'] - panel['mu_cp'].shift(1)
    
    # ===== Extended descriptive statistics =====
    core_vars = {
        'mu_cp': '定量化通胀预期 (CP方法)',
        'CPI_YoY': 'CPI同比增速',
        'Food_CPI_YoY_qavg': '食品CPI同比',
        'epu_qavg': 'EPU指数',
        'gpr_qavg': 'GPR指数',
        'M2_YoY': 'M2同比增速',
        'PPI_YoY': 'PPI同比增速',
        'Ind_Value_Added_YoY': '工业增加值同比'
    }
    
    stats_rows = []
    for var, label in core_vars.items():
        if var in panel.columns:
            stats = compute_stats(panel[var])
            stats['Variable'] = label
            stats_rows.append(stats)
    
    stats_df = pd.DataFrame(stats_rows)
    cols = ['Variable', 'N', 'Mean', 'Std', 'Min', 'P25', 'Median', 'P75', 'Max']
    stats_df = stats_df[cols]
    
    write_three_line_table(
        stats_df,
        TAB_DIR / 'desc_stats_extended.tex',
        caption='主要变量描述性统计（季度数据，2011Q1-2025Q3）',
        label='tab:desc_extended',
        notes=[
            '通胀变量以百分点为单位。',
            'EPU和GPR为指数（无单位）。',
            'N为非缺失观测数。'
        ],
        float_format='{:.3f}'
    )
    
    # ===== FE and FR statistics =====
    fe_fr_data = panel.dropna(subset=['FE', 'FR']).copy()
    
    fe_fr_rows = []
    for var, label in [('FE', '预测误差 (FE)'), ('FR', '预测修正 (FR)')]:
        stats = compute_stats(fe_fr_data[var])
        stats['Variable'] = label
        fe_fr_rows.append(stats)
    
    # Add correlation
    corr_fe_fr = fe_fr_data[['FE', 'FR']].corr().loc['FE', 'FR']
    fe_fr_rows.append({
        'Variable': 'Corr(FE, FR)',
        'N': int(len(fe_fr_data)),
        'Mean': corr_fe_fr,
        'Std': np.nan,
        'Min': np.nan,
        'P25': np.nan,
        'Median': np.nan,
        'P75': np.nan,
        'Max': np.nan
    })
    
    fe_fr_df = pd.DataFrame(fe_fr_rows)
    fe_fr_df = fe_fr_df[cols]
    
    write_three_line_table(
        fe_fr_df,
        TAB_DIR / 'fe_fr_stats.tex',
        caption='预测误差与预测修正的描述性统计',
        label='tab:fe_fr',
        notes=[
            'FE_t = CPI_{t+1} - μ_t（预测误差）。',
            'FR_t = μ_t - μ_{t-1}（预测修正）。',
            'Corr(FE, FR) < 0 为诊断性预期的初步证据（过度反应）。'
        ],
        float_format='{:.3f}'
    )
    
    # ===== Correlation matrix =====
    corr_vars = ['mu_cp', 'CPI_YoY', 'FE', 'FR', 'Food_CPI_YoY_qavg', 
                 'epu_qavg', 'gpr_qavg', 'M2_YoY', 'PPI_YoY']
    
    corr_data = panel[corr_vars].dropna()
    corr_matrix = corr_data.corr()
    
    # Format correlation matrix for LaTeX
    corr_labels = {
        'mu_cp': 'μ_CP',
        'CPI_YoY': 'CPI',
        'FE': 'FE',
        'FR': 'FR',
        'Food_CPI_YoY_qavg': 'Food',
        'epu_qavg': 'EPU',
        'gpr_qavg': 'GPR',
        'M2_YoY': 'M2',
        'PPI_YoY': 'PPI'
    }
    
    corr_matrix = corr_matrix.rename(index=corr_labels, columns=corr_labels)
    
    # Convert to LaTeX-friendly format
    corr_display = corr_matrix.copy()
    for i in range(len(corr_display)):
        for j in range(i+1, len(corr_display)):
            corr_display.iloc[i, j] = np.nan  # Upper triangle = NaN
    
    # Reset index to make variable names a column
    corr_display = corr_display.reset_index()
    corr_display = corr_display.rename(columns={'index': 'Variable'})
    
    write_three_line_table(
        corr_display,
        TAB_DIR / 'correlation_matrix.tex',
        caption='主要变量相关系数矩阵（下三角）',
        label='tab:corr_matrix',
        notes=[
            '仅显示下三角矩阵以节省空间。',
            '对角线为1（省略）。',
            '基于所有变量均非缺失的样本计算。'
        ],
        float_format='{:.3f}'
    )
    
    # ===== Sub-period statistics =====
    # Split at 2018Q1 (around when trade war escalated)
    panel['year'] = panel['quarter'].str[:4].astype(int)
    panel['is_post2018'] = panel['year'] >= 2018
    
    subperiod_rows = []
    for period, label in [(False, '2011-2017'), (True, '2018-2025')]:
        subset = panel[panel['is_post2018'] == period]
        
        for var in ['mu_cp', 'CPI_YoY', 'FE', 'FR', 'epu_qavg', 'gpr_qavg']:
            if var in subset.columns and subset[var].notna().sum() > 0:
                stats = compute_stats(subset[var])
                subperiod_rows.append({
                    'Period': label,
                    'Variable': var,
                    'N': stats['N'],
                    'Mean': stats['Mean'],
                    'Std': stats['Std'],
                    'Min': stats['Min'],
                    'Max': stats['Max']
                })
    
    subperiod_df = pd.DataFrame(subperiod_rows)
    
    write_three_line_table(
        subperiod_df,
        TAB_DIR / 'subperiod_stats.tex',
        caption='分时期描述性统计：2018年前后对比',
        label='tab:subperiod',
        notes=[
            '2018年为分界点（中美贸易摩擦升级）。',
            '2018年后EPU和GPR均值上升，反映不确定性增强。',
            '预测误差(FE)的波动性在两个时期有所不同。'
        ],
        float_format='{:.3f}'
    )
    
    print(f"[Enhanced Stats] Wrote: {TAB_DIR / 'desc_stats_extended.tex'}")
    print(f"[Enhanced Stats] Wrote: {TAB_DIR / 'fe_fr_stats.tex'}")
    print(f"[Enhanced Stats] Wrote: {TAB_DIR / 'correlation_matrix.tex'}")
    print(f"[Enhanced Stats] Wrote: {TAB_DIR / 'subperiod_stats.tex'}")
    
    # Print key findings
    print("\n=== KEY EMPIRICAL PATTERNS ===")
    print(f"Sample with FE/FR: N={len(fe_fr_data)}")
    print(f"Corr(FE, FR) = {corr_fe_fr:.4f}")
    if corr_fe_fr < 0:
        print("  → Negative correlation: Preliminary evidence for diagnostic expectations!")
    
    print(f"\nMean forecast error: {fe_fr_data['FE'].mean():.4f}")
    if fe_fr_data['FE'].mean() < 0:
        print("  → Systematic over-prediction (expectations > realized inflation)")
    
    print(f"\nPre-2018 EPU mean: {panel[~panel['is_post2018']]['epu_qavg'].mean():.2f}")
    print(f"Post-2018 EPU mean: {panel[panel['is_post2018']]['epu_qavg'].mean():.2f}")


if __name__ == '__main__':
    main()
