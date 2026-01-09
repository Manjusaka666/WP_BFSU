# 论文v1.2格式检查报告

## 一、章节序号连贯性检查

### 当前章节结构
```
00. 摘要
01. 引言
02. 文献综述
    02.1-02.2 基础文献
    02.3 诊断性预期 vs 理性疏忽
03. 数据与变量
04. 计量方法
    04.1 TVP-SSM
    04.2 BVAR
    04.3 两种方法的互补性
[缺失] 05. OLS基准结果（可选，或整合入06节）
06. 实证结果
    06.2 TVP-SSM结果（时变诊断强度）
    06.3 BVAR结果（冲击响应与FEVD）
07. 稳健性检验
08. 讨论与政策启示
09. 结论
10. 附录A-C
```

### ⚠️ 章节序号问题
**问题**：第6节直接从6.2开始，缺少6.1节

**建议修正方案**：
- 方案A（推荐）：将06.2改为5.1，06.3改为5.2，第6节作为独立的"稳健性检验"（当前第7节）
- 方案B：创建06.1节"OLS基准结果"（从v1.1提取）
- 方案C：将06.2和06.3改为06.1和06.2，不设小节标题

**采用方案B**：保持结构完整性

---

## 二、表格编号连贯性检查

### 预期表格编号方案

**第3节：数据与变量**
- 表3.1：主要变量描述性统计 (`desc_stats_extended.tex`)
- 表3.2：相关系数矩阵 (`correlation_matrix.tex`)
- 表3.3：FE与FR统计特征 (`fe_fr_stats.tex`)

**第5节（重新编号为6节）：实证结果**

**6.1 OLS基准结果**（新增）
- 表6.1：OLS回归结果 (`ols_baseline.tex`)
- 表6.2：OLS诊断检验 (`ols_diagnostics.tex`)
- 表6.3：OLS稳健性 (`ols_robustness.tex`)

**6.2 TVP-SSM结果**
- 表6.4：参数后验分布摘要 (`ssm_posterior_params.tex`)
- 表6.5：时变β_t路径（关键时期）(`beta_t_path.tex`)

**6.3 BVAR结果**
- 表6.6：符号约束接受率 (`bvar_acceptance.tex`)
- 表6.7：脉冲响应函数 (`bvar_irf_summary.tex`)
- 表6.8：预测误差方差分解 (`bvar_fevd.tex`)
- 表6.9：历史分解（关键时期）(`bvar_historical.tex`)

**6.4 模型诊断与比较**（可选整合）
- 表6.10：MCMC诊断统计 (`mcmc_diagnostics.tex`)
- 表6.11：模型比较 (`model_comparison.tex`)
- 表6.12：贝叶斯因子 (`bayes_factor.tex`)

**第7节：稳健性检验**
- 表7.1：SSM不同规格汇总 (`robustness/ssm_summary.tex`)
- 表7.2：BVAR不同规格汇总 (`robustness/bvar_summary.tex`)

---

## 三、图表编号连贯性检查

**第6.2节：TVP-SSM结果**
- 图6.1：β_t时变路径与90%置信区间 (`beta_t.png`)

**第6.3节：BVAR结果**
- 图6.2：诊断性预期冲击的IRF (`bvar_irf_de_shock.png`)
- 图6.3：预测误差逆转动态 (`bvar_fe_reversal.png`)

**第6.4节：模型诊断**（可选）
- 图6.4：MCMC轨迹图 (`mcmc_trace.png`)
- 图6.5：自相关函数图 (`mcmc_acf.png`)

**第7节：稳健性检验**
- 图7.1：先验敏感性分析 (`prior_sensitivity.png`)
- 图7.2：SSM不同规格β_t对比 (`robustness_beta_compare.png`)
- 图7.3：BVAR不同规格IRF对比 (`robustness_bvar_compare.png`)

---

## 四、参考文献格式（统一标准）

### 中文文献格式
```
作者姓名. 发表年份. 论文题目[J]. 期刊名称, 卷(期): 起始页-结束页.
```

### 英文文献格式
```
Author, A. A., & Author, B. B. (Year). Title of article. Journal Name, Volume(Issue), Start-End.
```

### 关键文献示例
- Baker, S. R., Bloom, N., & Davis, S. J. (2016). Measuring economic policy uncertainty. *Quarterly Journal of Economics*, 131(4), 1593-1636.
- Bordalo, P., Gennaioli, N., & Shleifer, A. (2018). Diagnostic expectations and credit cycles. *Journal of Finance*, 73(1), 199-227.
- Caldara, D., & Iacoviello, M. (2022). Measuring geopolitical risk. *American Economic Review*, 112(4), 1194-1225.
- Sims, C. A. (2003). Implications of rational inattention. *Journal of Monetary Economics*, 50(3), 665-690.
- Muth, J. F. (1961). Rational expectations and the theory of price movements. *Econometrica*, 29(3), 315-335.

---

## 五、全文字体统一要求

### LaTeX设置
```latex
\documentclass[12pt]{article}
\usepackage{ctex}  % 中文支持

% 字体设置
\setCJKmainfont{SimSun}  % 中文：宋体
\setmainfont{Times New Roman}  % 英文：Times New Roman
\setCJKsansfont{SimHei}  % 中文无衬线：黑体
\setCJKmonofont{FangSong}  % 中文等宽：仿宋

% 数学公式
\usepackage{amsmath, amssymb}
\usepackage{mathptmx}  % Times字体用于数学
```

### 格式要求
- 正文：中文宋体，英文Times New Roman，12pt
- 标题：中文黑体，英文Times New Roman Bold
- 图表标题：中文宋体，英文Times New Roman，10.5pt
- 数学公式：Times New Roman数学字体

---

## 六、修正建议清单

### 立即修正
- [ ] 创建06.1节"OLS基准结果"
- [ ] 重新编号所有表格（3.1-3.3, 6.1-6.12, 7.1-7.2）
- [ ] 重新编号所有图表（6.1-6.5, 7.1-7.3）
- [ ] 在各markdown文件中更新表格图表引用编号

### 建议优化
- [ ] 统一参考文献格式（APA或Chicago）
- [ ] 创建参考文献专用markdown文件
- [ ] LaTeX模板设置字体

---

## 七、文件输出位置

**新增文件**：
- `v1.2/06.1_ols_results.md` - 第6.1节OLS基准结果
- `v1.2/format_check_report.md` - 本格式检查报告
- `v1.2/11_references.md` - 参考文献（待创建）

**已完成文件**（需更新编号）：
- 所有现有章节markdown文件
