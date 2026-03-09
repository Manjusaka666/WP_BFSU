# Variable Dictionary

| Variable | Unit | Frequency | Transformation | Sample handling | Source |
|---|---|---|---|---|---|
| `quarter` | quarter ID | quarterly | string key (`YYYYQq`) | used for merge and sort | merged panel |
| `mu_cp` | percentage points | quarterly | Carlson-Parkin quantified expectation | requires valid up/down shares | PBoC survey + NBS CPI |
| `mu_cp_lower` / `mu_cp_upper` | percentage points | quarterly | bound allocations for uncertain responses | sensitivity bounds | `src/05_carlson_parkin_quantify.R` |
| `effective_sample_share` | share in [0,1] | quarterly | `1 - uncertain_share` | low-share observations flagged | PBoC survey |
| `infl_exp_index` | index points | quarterly | raw survey expectation index | used as alternative expectation measure | PBoC survey |
| `FR_cp` | percentage points | quarterly | `mu_cp_t - mu_cp_{t-1}` | NA at sample start | constructed |
| `FE_next_cp` | percentage points | quarterly | `CPI_QoQ_Ann_{t+1} - mu_cp_t` | NA near sample end | constructed |
| `CPI_QoQ_Ann` | percentage points annualized | quarterly | from macro panel | lead by one quarter for forecast error | NBS macro file |
| `CPI_YoY_rate` | percentage points | quarterly | `CPI_YoY - 100` when index scale | aligned to inflation-rate interpretation | NBS macro file |
| `PPI_YoY_rate` | percentage points | quarterly | `PPI_YoY - 100` when index scale | aligned to inflation-rate interpretation | NBS macro file |
| `Food_CPI_YoY_qavg` | percentage points | quarterly | quarterly mean of monthly food CPI YoY | control for food-cycle shocks | NBS food CPI |
| `M2_YoY` | percentage points | quarterly | as reported | macro control | NBS macro file |
| `epu_qavg` | index | quarterly | quarterly average | uncertainty state variable | China EPU |
| `gpr_qavg` | index | quarterly | quarterly average | uncertainty state variable | GPR index |
| `msi_raw` | z-score index | quarterly | `0.6*z(EPU)+0.4*z(expectation index)` | endogenous salience regressor | constructed |
| `media_congestion_iv` | z-score index | quarterly | `-z(GPR)` | excluded instrument in salience-IV | constructed |

Notes:
- Forecast error, expectational bias, revision, and level are kept distinct in code and tables.
- Units are always stated in output tables to avoid index-vs-rate ambiguity.
- Missing values are handled by complete-case selection within each module, with sample counts reported in corresponding tables.
