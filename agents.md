# AGENTS_WRITING_SAMPLE_GUIDE.md

> **Project:** Writing sample（经济学 PhD 申请）改写与复现
> **Target paper:** 你上传的第二篇（md 版）论文：OLS + TVP-SSM（MCMC）+ BVAR sign restrictions + robustness
> **Non-negotiables:** 可复现、可审计、叙事清晰、识别/测度严谨、贡献可验证、语言达到顶刊标准

---

## 0. 目标与最终交付物（写样本“审稿人视角”标准）

**最终必须交付：**

1. `paper_writing_sample.pdf`（或 .tex/.md→pdf 的完整可编译版本）
2. `replication/` 文件夹：一键复现（至少能从 processed 数据复现所有主表主图）
3. `evidence_ledger.md`：**每一个关键论断** → 对应 **表/图/回归脚本/输出文件** 的索引清单（审稿人式可追溯）
4. `limitations_and_scope.md`：明确样本期、外推边界、识别弱点、潜在偏误与未来工作

**写作质量闸门（必须过）：**

* **Sufficiency（充分性）**：读者不需要“猜你做了什么”；每一步都可从文本→代码→输出被定位
* **Correctness（正确性）**：定义、符号、统计量、滞后、样本期、变换一致；无“口头识别”
* **Parsimony（精炼度）**：删除重复解释、冗余稳健性、无关变量；保留“最强证据链”

---

## 1. 项目结构（与你的目录完全对齐）

你本地结构（摘要）：

* `data/raw/` 原始下载/抓取
* `data/intermediate/` 中间处理（如 CP 定量化、合并面板）
* `data/processed/` 最终估计用（如 `final_analysis.csv` / `panel_quarterly.csv`）
* `src/` 全流程脚本（入口 `00_run_complete_analysis.py`）
* `outputs/tables/` 论文表
* `outputs/figures/` 论文图
* `outputs/robustness/` 稳健性批处理输出

**Agent 工作约定：**

* 任何文本论断必须能在 `outputs/` 找到对应证据；找不到就禁止写进正文（只能写“计划/未来工作”）。
* 任何变量定义必须能在 `src/` 或 `data/processed/` 中被验证；对不上就回滚重写。

---

## 2. Agent 执行总流程（像“技能模块”一样可分解、可测试）

> 借鉴 Skill 逻辑：**每个模块**都有 Trigger / Inputs / Steps / Outputs / Checks / Failure modes。Skill 写法强调“简洁、可发现、可测试、最小上下文”，避免把上下文窗口当垃圾桶。 ([Claude][1])

### Module A — Repo Intake（仓库接管与最小上下文）

**Trigger**：开始改写写样本
**Inputs**：项目目录 + 论文 md + `src/` + `outputs/`
**Steps**：

1. 只读方式扫描：`src/`, `data/processed/`, `outputs/tables/`, `outputs/figures/`
2. 建立 `evidence_ledger.md` 骨架（先列主表主图清单，再补“论断→证据”）
3. 建立 `variable_dictionary.md`（变量名、单位、频率、变换、样本期、缺失处理）
   **Outputs**：`evidence_ledger.md`（空壳但结构完整）+ `variable_dictionary.md`（至少覆盖主回归变量）
   **Checks**：

* 主表主图是否都能定位到具体输出文件？
* 文本中的样本期/频率是否与数据文件一致？

> 建议把“仓库的操作与约定”写入类似 CLAUDE.md 的项目记忆文件：常用命令、入口脚本、输出位置、风格规范。 ([Anthropic][2])

---

### Module B — Reproducibility Pass（可复现性过一遍）

**Trigger**：任何写作改动之前
**Inputs**：`src/00_run_complete_analysis.py`（或等价入口）、`data/processed/`
**Steps**：

1. 从 **processed 数据** 起跑（避免抓取不稳定造成偏差）
2. 复现：OLS → SSM(MCMC) → BVAR → robustness
3. 对比 `outputs/` 是否重写一致（文件时间戳、核心数值 spot-check）
   **Outputs**：`reproducibility_log.md`（记录运行命令、hash、关键输出是否一致）
   **Checks**：

* 主结果能否在干净环境复现？
* 随机种子是否固定？（MCMC/BVAR 尤其关键）

（你已有用于主结果与诊断输出的脚本线索，例如：描述统计扩展表、BVAR sign restriction、SSM 诊断流程等。）
 

---

### Module C — Narrative Rebuild（顶刊叙事重建：先结构、后句子）

**Trigger**：复现通过后
**Inputs**：现有 md 论文各章节
**Steps**：

1. 重写 Introduction（按“问题—缺口—贡献—路线图”四段式）
2. Literature：做“定位”而不是“罗列”
3. Method：把识别/测度的“最关键环节”放到正文；细节下沉附录
4. Results：每一节必须回答同一个问题：“这条证据排除了哪些替代解释？”
   **Outputs**：新版 `01_introduction.md` … `09_conclusion.md`（或合并成 `paper.md`）
   **Checks**：

* 每节开头是否有 1–2 句“本节要回答的问题 + 采取的方法”？
* 每个结论句后面是否紧跟证据指针（Table/Figure/Appendix）？

---

### Module D — Evidence Ledger Completion（审稿人式证据链）

**Trigger**：正文基本成型
**Inputs**：正文 + 全部表图
**Steps**：

* 为每个“强断言句”（claim）补充：

  * 证据（表/图/回归）
  * 识别假设（可检验/不可检验）
  * 替代解释与对应稳健性
    **Outputs**：最终 `evidence_ledger.md`
    **Checks**：
* 任意主张是否能在 30 秒内定位到输出文件？
* 若不能：删句或降格表述（from “shows” → “is consistent with”）

---

## 3. 顶刊经济学写作风格规范（必须执行）

> 目标风格：AER / Restud / RES 常见写法：**克制、精准、可验证、少形容词、多结构化信息**。
> 下面给的是“可执行规则 + 原创例句模板（你可以替换变量/国家/时期）”。

### 3.1 语言与句法（Style）

**硬规则：**

* 句子优先短：平均 20–28 词；一段只表达一个逻辑单元
* 少用“obviously / clearly / undoubtedly”；用可证伪表述
* 先给定义再用符号；符号出现一次就要可追溯
* 禁止“概念漂移”：同一对象不要在不同段落换叫法

**动词强度梯度（按证据强弱选择）：**

* 最强：*establish / identify / rule out*（需要明确识别策略）
* 中等：*document / quantify / characterize*（描述性或结构估计）
* 克制：*suggest / is consistent with*（相关性、机制推断）

**原创例句模板（可直接用）：**

* 贡献句（Contribution）

  * *This paper makes three contributions. First, we construct a quarterly measure of households’ inflation expectations from the PBOC depositor survey using a Carlson–Parkin quantification. Second, we estimate a time-varying diagnostic intensity in a state-space framework. Third, we identify a “diagnostic expectations shock” in a Bayesian VAR using sign restrictions implied by forecast-error reversals.*
* 路线图（Roadmap）

  * *Section 2 describes the survey and measurement. Section 3 lays out the baseline regression and the state-space specification. Section 4 presents VAR evidence. Section 5 reports robustness and discusses limitations.*

### 3.2 叙事结构（Narrative）

**Introduction 四段式（强制）：**

1. **Big question & stakes**（为什么重要，宏观/政策含义）
2. **Gap**（现有文献缺什么：测度、识别、样本、机制）
3. **Approach & contributions**（你做了什么，为什么能填缺口）
4. **Preview of findings**（最关键结果 + 量级 + 边界条件）

**每节内部结构（统一模板）：**

* 1–2 句提出问题与方法
* 给最关键定义/方程
* 给结果 + 量级
* 解释：它排除什么替代解释
* 小结：本节对总论点贡献是什么

### 3.3 逻辑链接词库（只用“因果/推理友好”的连接）

* 递进：*Moreover, In addition, Importantly*
* 转折：*However, In contrast, Nevertheless*
* 因果（谨慎用）：*Consistent with, Suggesting that, A natural interpretation is*
* 约束/边界：*In our sample, Under the maintained assumption that, This interpretation is limited by*

### 3.4 理论与模型编排（Model/Method Architecture）

你这篇的“模型”本质是 **测度 + 统计结构**（CP 定量化、SSM、BVAR）。正文编排建议：

1. **Measurement first**：为什么 survey→μ 是必要的，误差结构是什么
2. **Baseline regression**：给出最简式（并说明为什么不是结构因果）
3. **State-space**：用最少方程讲清楚（measurement eq + transition eq）与识别（先验/滤波/后验诊断）
4. **VAR**：把 sign restriction 与“诊断性预期”理论含义一一对应（impact + FE reversal）

（你现有脚本对“预测误差 FE 与预测修正 FR、相关性矩阵、分段统计”等已经写得很“审稿人友好”，建议把它们对应的定义与经济含义放进正文/附录的固定位置。）
 

---

## 4. 上下文工程（Context Engineering）与“像技能一样组织 Agent 工作”

> 核心思想：上下文窗口是公共资源；要做“高信号 token 管理”，并用**压缩/结构化笔记**维护长期一致性。 ([Claude][1])

### 4.1 文件阅读策略（必须遵守）

* **Never break mid-sentence**：任何“分块阅读/摘要”必须以句号、分号或自然段边界切分
* Chunk 建议：英文每块 150–250 词，中文每块 200–400 字
* 每块输出两层笔记：

  1. `facts.md`：事实/定义/样本期/变量
  2. `claims.md`：作者主张 + 证据指针（若无证据则标红）

### 4.2 Compaction（上下文压缩）机制

* 每完成一个 Module，就更新一次 `PROJECT_STATE.md`：

  * 已确认的定义
  * 已复现的输出
  * 未解决的问题（按优先级）
  * 下一步要改的 3–5 件事
    （这是 Anthropic 提倡的“structured note-taking / compaction”在工程侧的落地方式。） ([Anthropic][3])

### 4.3 模块化写作 = “可触发、可测试、可复用”

参考 Skill authoring best practices：**短、结构化、用真实用例测试**；只写模型“不会自动知道的那部分”，避免把常识写进上下文。 ([Claude][1])

你可以把每个写作模块按如下头部写在 `AGENTS_WORKLOG.md` 中：

* **Trigger**（何时调用）
* **Inputs**（具体文件路径）
* **Outputs**（写到哪里）
* **Success criteria**（怎么判定完成）
* **Failure modes**（常见错：样本期错、变量错、符号错、结果不可复现）

---

## 5. 证据与可追溯性：Evidence Ledger 模板（强制）

在 `evidence_ledger.md` 用以下格式记录每条主张：

* **Claim ID**: C-Intro-01
* **Statement**: *We find that diagnostic intensity rises sharply during high-uncertainty episodes.*
* **Evidence**: Figure `beta_t.png`; Table `ssm_posterior_params.tex`
* **Code**: `src/20_bayes_state_space_*.py`
* **Assumptions**: state-space linearity; priors; measurement error
* **Alt explanations**: structural breaks, survey composition shifts
* **Robustness**: prior sensitivity, sub-sample, alternative uncertainty proxy
* **Status**: ✅ / ⚠️ / ❌

（你的 BVAR 识别脚本对“DE shock 应满足 μ 上升且随后 FE 反转为负”已经把经济含义写进注释了；这种写法非常适合直接转写成正文识别段落。）


---

## 6. 写样本的“严厉审稿人清单”（提交前自审）

### 6.1 读者最关心的 10 个问题（逐条必须能回答）

1. 你的核心问题是什么？**一句话**能说清吗？
2. 你测度的 μ（通胀预期）与 survey 原始问题之间的映射是否透明？（附问卷截图/样例）
3. 诊断性预期的“可检验含义”是什么？你的证据对应哪一条含义？
4. OLS 在这里的角色是什么（描述性/机制性）？你有没有避免把相关性写成因果？
5. TVP-SSM 的状态变量是什么？如何识别？先验为何合理？MCMC 是否收敛？
6. VAR 的 sign restriction 是否过强/过弱？接受率如何？
7. 样本期只有 43 期有效样本时，参数不确定性与过拟合如何处理？
8. 最关键的稳健性是哪 2–3 个？其余是否删掉？
9. 与现有文献相比，你的“新增信息”是什么？
10. 你的结论外推到哪里就不成立？

### 6.2 “降格用语”规则（避免被一票否决）

* 没有清晰识别策略：不用 *causal, effect, impact*
* 没有排除替代解释：不用 *rule out, establish*
* 样本短、结构变化多：必须写 *in our sample / within 2011Q1–2025Q3*

---

## 7. 项目关键脚本（Agent 应优先阅读的“真相来源”）

> 这些文件决定“你到底做了什么”，正文必须与之完全一致。

* **PBOC 问卷抓取与指标抽取**：
* **描述统计 + FE/FR + 相关矩阵 + 分时期统计**：
* **BVAR sign restrictions（诊断性冲击识别与 IRF/FEVD 输出）**：

---

## 8. 工具/Agent 的 tool-calling 与运行纪律（简明）

* 若 agent 需要调用外部工具/函数：严格遵守“定义工具→模型提出调用→执行→把结果回填→再生成文本”的闭环，避免把“工具输出”当成最终结论。 ([OpenAI Platform][4])
* agent 的输出必须区分：

  * **Results**（来自 outputs 的事实）
  * **Interpretation**（有条件的解释）
  * **Speculation/Future work**（明确标注）

---

## 9. 最终打包与提交（Writing sample 标准形态）

提交包建议：

```
submission/
  paper/
    paper.pdf
    paper.tex (or paper.md)
    appendix.pdf (optional)
  replication/
    README.md
    environment.yml (or requirements.txt)
    run.sh (one-click)
    src/ (only necessary scripts)
    data/processed/ (or instructions to build)
    outputs/ (generated)
  audit/
    evidence_ledger.md
    variable_dictionary.md
    reproducibility_log.md
    limitations_and_scope.md
```

README 至少包含：运行命令、数据来源与许可证、随机种子、预期运行时长、如何定位主表主图。

---