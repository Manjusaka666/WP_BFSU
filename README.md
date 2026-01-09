\
# Diagnostic Expectations × Uncertainty（中国）：可复现代码与数据结构

本仓库用于复现并推进你的 Working Paper 研究设计：  
**用 PBOC 储户问卷数据 + Carlson–Parkin 定量化 + 贝叶斯状态空间（TVP）+ BVAR 符号约束**，识别并刻画在 **EPU/GPR 高企时居民是否更“诊断性”（过度反应）**。

---

## 目录结构（严格按你的要求）

- `data/raw/`        原始下载文件（**不要编辑**）
- `data/intermediate/`  清洗/解析后的中间序列（月度/季度）
- `data/processed/`  最终用于估计的季度面板
- `src/`             脚本
- `outputs/`         结果输出（`tables/` 和 `figures/`）

---

## 你当前的原始数据文件（已对齐到代码的**固定文件名**）

放在 `data/raw/`：
- `China_Mainland_Paper_EPU.xlsx`（你手动下载的 China EPU）
- `data_gpr_export.xlsx`（你手动下载的 GPR 导出）
- `nbs_macro_control.csv`（你手动下载的 NBS 宏观控制变量）
- `nbc_food_CPI.csv`（食品类 CPI 链式指数，解决“猪周期/食品噪声”质疑）

放在 `data/intermediate/`（你已整理好的 PBOC 中间数据）：
- `pboc_depositor_survey_quarterly.csv`（含季度指数与分项占比）
- `pboc_infl_exp_index.csv`（指数的补充/核对）

---

## 论文层面两项“小修正”已落在代码里

1) **样本从 2011Q1 开始**  
`src/10_build_quarterly_panel.py` 会在 `outputs/tables/sample_overview.tex` 中明确写出样本起止与说明（避免审稿人质疑“样本缺口/口径”）。

2) **加入食品通胀控制（Food CPI）**  
`src/09_process_food_cpi.py` 构造 `Food_CPI_YoY_qavg`，并在  
`src/20_bayes_state_space_diagnostic.py` 的测量方程控制变量 `Z_t` 中**强制纳入**，用于应对“中国 CPI = 猪肉指数”的典型质疑。

---

## 一键运行（推荐）

在项目根目录执行：

```bash
python src/00_run_all.py
```

它会依次运行：
1. `06_process_epu.py`  → `data/intermediate/epu_monthly.csv`, `epu_quarterly.csv`
2. `07_process_gpr.py`  → `data/intermediate/gpr_monthly.csv`, `gpr_quarterly.csv`
3. `08_process_nbs_macro_control.py` → `data/intermediate/nbs_macro_quarterly.csv`
4. `09_process_food_cpi.py` → `data/intermediate/food_cpi_quarterly.csv`
5. `05_carlson_parkin_quantify.py` → `data/intermediate/pboc_expected_inflation_cp.csv`
6. `10_build_quarterly_panel.py` → `data/processed/panel_quarterly.csv`
7. `20_bayes_state_space_diagnostic.py` → SSM 估计 + `beta_t` 路径
8. `30_bvar_sign_restrictions.py` → BVAR 符号约束 IRF（包含“预测误差反转”识别）

---

## 输出（全部为可直接嵌入论文的 LaTeX 三线表）

所有表格输出都在 `outputs/tables/`，例如：
- `sample_overview.tex`：样本起止、季度数
- `desc_stats.tex`：描述性统计
- `cp_coverage.tex` / `cp_head.tex`：CP 定量化覆盖与示例
- `ssm_posterior_params.tex`：状态空间模型参数后验摘要
- `beta_t_path.tex`：`beta_t` 全样本路径（均值 + 90% 区间）
- `bvar_irf_summary.tex`：BVAR IRF 汇总（中位数 + 68% 区间）
- `bvar_acceptance.tex`：符号约束接受率

图形输出在 `outputs/figures/`，并附带同名 `.tex` wrapper（可直接 `\input{...}`）：
- `beta_t.png` 与 `beta_t.tex`

---

## LaTeX 依赖（写进论文 preamble）

表格与图形 wrapper 需要：

```tex
\usepackage{booktabs}
\usepackage{threeparttable}
\usepackage{graphicx}
```

---

## 重要口径（你在正文/附录应明确）

- **CPI_YoY 与 PPI_YoY**：原始为“同比指数（=100）”，代码中统一转化为**通胀率（指数-100，百分点）**。
- **CP 定量化**：当问卷缺少“上涨/下降”分项占比时，该季度无法计算 `mu_cp`（会产生缺失）。这会导致 SSM 的有效样本短于 2011Q1–2024Q4（需在附录说明）。
- **BVAR 识别（审稿人友好）**：诊断性预期冲击不仅要求 `mu_cp` 当期上升，还要求未来 1–4 期的 **FE_realized 为负**（预测误差反转），直接回应“黑箱识别”质疑。

---

