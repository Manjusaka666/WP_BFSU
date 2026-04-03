# LaTeX Format Audit Report (JPE-Macro Manuscript)

Audit scope: `jmp/main.tex` and all `20` files under `jmp/sections/`.
Validation anchors: `outputs/tables/` and `outputs/figures/`.

## Summary

- Total findings: **107**
- CRITICAL: **16**
- WARNING: **44**
- INFO: **47**

Top issue categories:
- `LABEL_UNUSED`: 47
- `LABEL_CONVENTION`: 18
- `LABEL_DUPLICATE`: 16
- `DISPLAY_MATH`: 13
- `FIGURE_ENV`: 13

Audit checklist status:
- `\input{\tabdir/...}` table path existence in `outputs/tables/`: PASS (0 issues)
- `jmp/main.tex` `\input{...}` path validity: PASS (0 issues)
- `\includegraphics{...}` file existence in `outputs/figures/`: PASS (0 issues)
- Figure format preference (`.pdf` preferred): PASS (0 non-PDF findings)
- Undefined references (`\ref/\cref` with no matching `\label`): PASS (0 issues)
- Citation integrity (`\citet/\citep` usage and empty keys): PASS (0 issues)
- Booktabs policy (`\hline` banned): PASS (0 issues)
- Formula-mode checks (unescaped underscores, Greek outside math, inline delimiter style): PASS (0 issues)

## File-by-File Findings

### `jmp/main.tex`
- **WARNING** | line 91 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.

### `jmp/sections/01_introduction.tex`
- **INFO** | line 1 | `LABEL_UNUSED`
  - Issue: Label `sec:intro` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/02_literature.tex`
- **WARNING** | line 24 | `LABEL_CONVENTION`
  - Issue: Label `sub:diagnostic_vs_rigidity` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 24 | `LABEL_UNUSED`
  - Issue: Label `sub:diagnostic_vs_rigidity` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 27 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 29 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 32 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 34 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **INFO** | line 41 | `LABEL_UNUSED`
  - Issue: Label `eq:diagnostic_prediction` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 51 | `LABEL_UNUSED`
  - Issue: Label `eq:rigidity_prediction` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 71 | `LABEL_CONVENTION`
  - Issue: Label `sub:china_context` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 71 | `LABEL_UNUSED`
  - Issue: Label `sub:china_context` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 104 | `LABEL_CONVENTION`
  - Issue: Label `sub:testable_predictions` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 104 | `LABEL_UNUSED`
  - Issue: Label `sub:testable_predictions` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 132 | `LABEL_CONVENTION`
  - Issue: Label `subsub:cut_heterogeneity` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 132 | `LABEL_UNUSED`
  - Issue: Label `subsub:cut_heterogeneity` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/03_institutional_data.tex`
- **WARNING** | line 33 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 35 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 72 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 75 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 88 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **CRITICAL** | line 96 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `subsec:chfs_data` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 96 | `LABEL_CONVENTION`
  - Issue: Label `subsec:chfs_data` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 96 | `LABEL_UNUSED`
  - Issue: Label `subsec:chfs_data` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/03b_chfs_data.tex`
- **CRITICAL** | line 1 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `subsec:chfs_data` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 1 | `LABEL_CONVENTION`
  - Issue: Label `subsec:chfs_data` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 1 | `LABEL_UNUSED`
  - Issue: Label `subsec:chfs_data` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/04_measurement.tex`
- **INFO** | line 1 | `LABEL_UNUSED`
  - Issue: Label `sec:measurement` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 21 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:cp_mean` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 21 | `LABEL_UNUSED`
  - Issue: Label `eq:cp_mean` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 24 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:cp_sd` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 24 | `LABEL_UNUSED`
  - Issue: Label `eq:cp_sd` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/05_identification.tex`
- **INFO** | line 15 | `LABEL_UNUSED`
  - Issue: Label `eq:cfps_panel` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 74 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 77 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.

### `jmp/sections/06_baseline_results.tex`
- **WARNING** | line 17 | `LABEL_CONVENTION`
  - Issue: Label `subsec:cfps_main_result` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 17 | `LABEL_UNUSED`
  - Issue: Label `subsec:cfps_main_result` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 114 | `LABEL_CONVENTION`
  - Issue: Label `subsec:aggregate_corroboration` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 114 | `LABEL_UNUSED`
  - Issue: Label `subsec:aggregate_corroboration` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 188 | `LABEL_CONVENTION`
  - Issue: Label `subsec:dynamic_response` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 188 | `LABEL_UNUSED`
  - Issue: Label `subsec:dynamic_response` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 193 | `LABEL_UNUSED`
  - Issue: Label `eq:lp` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 238 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **INFO** | line 245 | `LABEL_UNUSED`
  - Issue: Label `fig:lp_fe` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 248 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **INFO** | line 255 | `LABEL_UNUSED`
  - Issue: Label `fig:lp_pi` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 261 | `LABEL_CONVENTION`
  - Issue: Label `subsec:iv` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 261 | `LABEL_UNUSED`
  - Issue: Label `subsec:iv` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/07_heterogeneity.tex`
- **WARNING** | line 108 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **INFO** | line 114 | `LABEL_UNUSED`
  - Issue: Label `fig:heterogeneity_salience` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/08_mechanism.tex`
- **WARNING** | line 15 | `LABEL_CONVENTION`
  - Issue: Label `subsec:horse_race` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 19 | `LABEL_UNUSED`
  - Issue: Label `eq:horse_race` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 66 | `LABEL_CONVENTION`
  - Issue: Label `subsec:mechanism_state` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 66 | `LABEL_UNUSED`
  - Issue: Label `subsec:mechanism_state` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 71 | `LABEL_UNUSED`
  - Issue: Label `eq:mechanism_state` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 111 | `LABEL_UNUSED`
  - Issue: Label `fig:mechanism_beta_t` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 115 | `LABEL_CONVENTION`
  - Issue: Label `subsec:mechanism_chain` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 115 | `LABEL_UNUSED`
  - Issue: Label `subsec:mechanism_chain` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 143 | `LABEL_UNUSED`
  - Issue: Label `fig:mechanism_chain` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 148 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `subsec:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 148 | `LABEL_CONVENTION`
  - Issue: Label `subsec:chfs_info_channel` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **CRITICAL** | line 162 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 162 | `LABEL_UNUSED`
  - Issue: Label `eq:chfs_info_channel` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 207 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.

### `jmp/sections/08b_chfs_mechanism.tex`
- **CRITICAL** | line 2 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `subsec:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 2 | `LABEL_CONVENTION`
  - Issue: Label `subsec:chfs_info_channel` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **CRITICAL** | line 36 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 36 | `LABEL_UNUSED`
  - Issue: Label `eq:chfs_info_channel` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 85 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:chfs_info_channel` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.

### `jmp/sections/09_policy.tex`
- **WARNING** | line 16 | `LABEL_CONVENTION`
  - Issue: Label `policy_rule` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 16 | `LABEL_UNUSED`
  - Issue: Label `policy_rule` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 21 | `LABEL_CONVENTION`
  - Issue: Label `adjusted_forecast` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 21 | `LABEL_UNUSED`
  - Issue: Label `adjusted_forecast` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 92 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **WARNING** | line 156 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.

### `jmp/sections/09b_chfs_consequences.tex`
- **WARNING** | line 2 | `LABEL_CONVENTION`
  - Issue: Label `subsec:chfs_consequences` does not follow required prefix convention (sec/tab/fig/eq/app).
  - Suggested fix: Rename label with required prefix and update references.
- **INFO** | line 2 | `LABEL_UNUSED`
  - Issue: Label `subsec:chfs_consequences` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 25 | `LABEL_UNUSED`
  - Issue: Label `eq:chfs_income` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/10_robustness.tex`
- **INFO** | line 1 | `LABEL_UNUSED`
  - Issue: Label `sec:robustness` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 73 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **CRITICAL** | line 80 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:beta_t_path` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 97 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **CRITICAL** | line 105 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:bvar_irf` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.

### `jmp/sections/11_conclusion.tex`
- No issues found.

### `jmp/sections/A1_bayesian_ssm.tex`
- **INFO** | line 19 | `LABEL_UNUSED`
  - Issue: Label `eq:ssm_measurement` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 22 | `LABEL_UNUSED`
  - Issue: Label `eq:ssm_state` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/A2_bvar.tex`
- **WARNING** | line 8 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 11 | `DISPLAY_MATH`
  - Issue: Display math delimiter `\[ ... \]` detected; policy requires equation/align environments.
  - Suggested fix: Replace with `\begin{equation}` or `\begin{align}`.
- **WARNING** | line 35 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.

### `jmp/sections/A3_data_construction.tex`
- No issues found.

### `jmp/sections/A4_additional_robustness.tex`
- **INFO** | line 6 | `LABEL_UNUSED`
  - Issue: Label `app:iv_details` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 14 | `LABEL_UNUSED`
  - Issue: Label `eq:msi` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 19 | `LABEL_UNUSED`
  - Issue: Label `eq:iv` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 29 | `LABEL_UNUSED`
  - Issue: Label `eq:first_stage` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 31 | `LABEL_UNUSED`
  - Issue: Label `eq:second_stage_revision` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **INFO** | line 33 | `LABEL_UNUSED`
  - Issue: Label `eq:second_stage_fe` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 38 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **INFO** | line 45 | `LABEL_UNUSED`
  - Issue: Label `fig:first_stage_iv` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 155 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **INFO** | line 162 | `LABEL_UNUSED`
  - Issue: Label `fig:uncertainty_states` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/A5_measurement.tex`
- **CRITICAL** | line 21 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:cp_mean` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 21 | `LABEL_UNUSED`
  - Issue: Label `eq:cp_mean` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **CRITICAL** | line 24 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `eq:cp_sd` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **INFO** | line 24 | `LABEL_UNUSED`
  - Issue: Label `eq:cp_sd` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.

### `jmp/sections/A6_robustness_main.tex`
- **INFO** | line 1 | `LABEL_UNUSED`
  - Issue: Label `app:robustness_main` has no `\ref`/`\cref` usage in scanned corpus.
  - Suggested fix: Remove unused label or add a cross-reference.
- **WARNING** | line 73 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **CRITICAL** | line 80 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:beta_t_path` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
- **WARNING** | line 97 | `FIGURE_ENV`
  - Issue: Figure placement `[H]` violates required `[htbp]` or `[!htbp]`.
  - Suggested fix: Change placement to `[htbp]` or `[!htbp]`.
- **CRITICAL** | line 105 | `LABEL_DUPLICATE`
  - Issue: Duplicate label `fig:bvar_irf` defined in multiple files/locations.
  - Suggested fix: Rename to a unique key and update references.
