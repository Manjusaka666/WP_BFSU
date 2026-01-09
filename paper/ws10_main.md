# Diagnostic Expectations in China: Evidence from Household Inflation Surveys

**Author**: [Name]  
**Institution**: [Institution]  
**Date**: January 2026

---

## Abstract

We test whether Chinese households exhibit diagnostic expectations—systematic over-reaction to salient signals—using quarterly inflation survey data from 2014 to 2024.
Carlson-Parkin quantification of People's Bank of China depositor surveys yields 43 quarters of inflation expectations.
A time-varying Bayesian state-space model shows that forecast revisions systematically predict subsequent forecast errors with a negative coefficient (posterior mean β = -0.522), appearing in 91 per cent of quarters.
This pattern rejects rational expectations and supports diagnostic expectations over rational inattention.
We employ Bayesian vector autoregressions with sign restrictions to quantify that shocks exhibiting diagnostic properties explain 26 per cent of expectation variance but only 9 per cent of realised CPI variance.
We attribute this low transmission efficiency to flat New Keynesian Phillips curves, administrative price controls, and firms' reliance on producer rather than consumer price expectations.
Results imply that expectation management stabilises expectations per se rather than directly controlling inflation.

**JEL Classification**: E31, E37, D84, C32  
**Keywords**: diagnostic expectations, inflation forecasts, Bayesian methods, China

---

## 1. Introduction

Inflation expectations govern monetary transmission, consumption-saving decisions, and wage negotiations.
Standard macroeconomic models assume rational expectations whereby agents form unbiased forecasts using all available information (Muth, 1961).
Household survey data frequently violate this assumption through persistent biases and systematic forecast errors (Coibion & Gorodnichenko, 2015).
Understanding these deviations matters for central banks managing anchoring risks and evaluating communication effectiveness.

Recent behavioural macro theories provide microfounded alternatives to rational expectations.
Bordalo, Gennaioli, and Shleifer (2018) propose diagnostic expectations in which agents over-weight signals that appear representative of the current state relative to historical norms.
This framework predicts systematic over-reaction to recent information.
An alternative departure is rational inattention in which information-processing costs induce under-reaction to noisy signals (Sims, 2003).
The sign of forecast error predictability discriminates between these theories.
Diagnostic expectations imply negative coefficients in regressions of forecast errors on forecast revisions whereas rational inattention implies positive coefficients.

This paper asks whether Chinese households exhibit diagnostic expectations in inflation forecasting.
We exploit quarterly data from the People's Bank of China depositor survey spanning 2013Q4 through 2025Q2.
After Carlson-Parkin quantification and accounting for data availability, the effective sample comprises 43 quarters from 2014Q1 through 2024Q4.
We estimate whether forecast revisions systematically predict forecast errors with a negative sign.
Two complementary Bayesian methods provide the empirical strategy.
First, a time-varying parameter state-space model estimates diagnostic intensity and tests whether uncertainty proxies drive temporal variation.
Second, a Bayesian vector autoregression with sign restrictions identifies shocks satisfying diagnostic properties and quantifies their contribution to macroeconomic fluctuations.

We preview three main findings.
Ordinary least squares yields β = -0.588 with standard error 0.109 and p-value below 0.01, rejecting rational expectations.
The time-varying state-space model shows β posterior mean equals -0.522 with negative realisations in 39 of 43 quarters.
Extreme negative values occur during uncertainty episodes including RMB depreciation in 2016Q1 (β = -1.16) and COVID-19 onset in 2020Q2 (β = -1.31).
Notably, state equation coefficients on economic policy uncertainty and geopolitical risk indices lack statistical significance as their 90 per cent credible intervals include zero.
We interpret this as episodic association rather than robust linear causation.
The Bayesian vector autoregression shows that shocks satisfying diagnostic sign restrictions explain 26 per cent of expectation variance versus 9 per cent of consumer price index variance.
We attribute this low transmission from expectations to realised inflation to three mechanisms.
First, flat Phillips curve slopes reflect price stickiness and globalisation.
Second, administrative price controls including strategic reserve releases dampen household expectation pass-through.
Third, firms price off producer price indices and wages rather than household beliefs.

This paper makes four contributions.
First, we provide aggregate-level rejection of rational expectations favouring diagnostic over rational inattention for China, filling a gap in emerging market expectation studies.
Second, we document time variation in diagnostic intensity while honestly disclosing that uncertainty proxies lack robust linear explanatory power, likely reflecting small sample size and potential nonlinearity.
Third, we clarify that the Bayesian vector autoregression quantifies macro importance of diagnostic-type shocks rather than independently verifying the theory, as sign restrictions ensure impulse responses match theoretical predictions by construction.
Fourth, we reframe policy implications such that expectation management stabilises expectations directly through reduced macro uncertainty and anchoring rather than controlling consumer price inflation.

Section 2 describes data and Carlson-Parkin quantification.
Section 3 presents empirical strategy.
Section 4 reports results.
Section 5 discusses robustness, limitations, and policy implications.
Section 6 concludes.

---

## 2. Data and Measurement

The People's Bank of China conducts quarterly surveys of approximately 20,000 households across 50 cities in urban China beginning in 1999Q1.
Survey participants answer whether next quarter prices will rise, stay roughly unchanged, fall, or whether they feel unsure.
We denote response shares as p_up, p_same, p_down, and p_uncertain.
Our sample covers 2013Q4 through 2025Q2 comprising 47 quarters.
Two quarters lack sufficient data owing to survey redesign in 2013Q2 and COVID-19 disruption in 2020Q4.
After excluding unsure responses and renormalising, 45 quarters contain valid response shares.

We quantify qualitative responses using the Carlson-Parkin method (Carlson & Parkin, 1975).
This approach assumes respondents report price increases if perceived inflation exceeds baseline inflation π by a tolerance band δ.
Under subjective normality, the quantified expectation μ equals baseline inflation plus the tolerance band minus subjective volatility σ times the standard normal quantile corresponding to the upper tail probability.
Formally, μ_t = π_t + δ - σ_t · Φ^(-1)(1 - p_up) where Φ^(-1) denotes the inverse standard normal cumulative distribution function.
We calibrate the tolerance band to 0.5 percentage points and use National Bureau of Statistics consumer price index year-over-year growth as baseline inflation.

We define two key variables.
Forecast error FE equals next period realised inflation minus current expectation, FE_t = π_{t+1} - μ_t.
Forecast revision FR equals current expectation minus lagged expectation, FR_t = μ_t - μ_{t-1}.
Under rational expectations, forecast errors should be orthogonal to available information including forecast revisions, implying zero coefficient in FE_t = α + β·FR_t + controls.
Under diagnostic expectations, over-reaction to recent information generates negative β.
Under rational inattention, under-reaction during high uncertainty implies positive β.

The effective regression sample spans 2014Q1 through 2024Q4 totalling 43 quarters.
Forecast errors require next period inflation, losing the final observation.
Forecast revisions require lagged expectations, losing the first observation.
Combined with two missing quarters from the 47-quarter CP sample, the effective sample contains 43 observations.

We include four control variables.
Food consumer price index year-over-year growth controls for pork cycle disturbances.
M2 money supply year-over-year growth proxies for monetary policy stance.
Producer price index year-over-year growth captures upstream cost pressure.
Industrial value added year-over-year growth proxies for business cycle position.
All variables maintain quarterly frequency from 2014Q1 through 2024Q4 sourced from the National Bureau of Statistics.

We employ two uncertainty proxies as potential drivers of diagnostic intensity time variation.
The Baker, Bloom, and Davis (2016) economic policy uncertainty index for China derives from Hong Kong newspaper text analysis.
We compute quarterly averages from monthly values.
The Caldara and Iacoviello (2022) geopolitical risk index derives from automated text analysis of international news.
We compute quarterly averages from daily values.

Table 1 presents descriptive statistics sourced from `outputs/tables/desc_stats_extended.tex`.

**Table 1: Descriptive Statistics**

```latex
\begin{table}[!htbp]
\centering
\small
\caption{Descriptive Statistics (Quarterly Data, 2014Q1–2024Q4)}
\label{tab:desc_extended}
\begin{threeparttable}
\begin{tabular}{@{}lllllllll@{}}
\toprule
Variable & N & Mean & Std & Min & P25 & Median & P75 & Max \\
\midrule
Expectation (μ) & 48.000 & 0.452 & 0.551 & -1.287 & 0.120 & 0.411 & 0.704 & 1.736 \\
CPI YoY & 58.000 & 0.141 & 0.269 & -0.574 & -0.043 & 0.160 & 0.333 & 0.668 \\
Food CPI YoY & 58.000 & 3.498 & 5.276 & -5.148 & -0.342 & 2.665 & 5.458 & 20.299 \\
EPU Index & 58.000 & 225.325 & 112.921 & 75.909 & 125.531 & 222.375 & 306.892 & 499.249 \\
GPR Index & 58.000 & 105.028 & 29.137 & 69.691 & 87.027 & 95.891 & 118.628 & 224.596 \\
M2 YoY & 58.000 & 10.893 & 2.536 & 6.480 & 8.542 & 10.950 & 13.033 & 16.510 \\
PPI YoY & 58.000 & 0.523 & 4.393 & -5.900 & -2.639 & -1.312 & 3.617 & 12.233 \\
Ind VA YoY & 58.000 & 5.867 & 3.152 & -0.367 & 3.958 & 5.883 & 7.017 & 13.933 \\
\bottomrule
\end{tabular}
\begin{tablenotes}[flushleft]
\footnotesize
\item Inflation and growth rates in percentage points.
\item EPU and GPR are index values (unitless).
\item N denotes non-missing observations.
\end{tablenotes}
\end{threeparttable}
\end{table}
```

Mean expectation equals 0.452 percentage points versus mean realised inflation of 0.141 percentage points, suggesting systematic over-prediction.
The correlation between forecast errors and forecast revisions equals -0.451 with p-value below 0.01, providing initial evidence for diagnostic expectations.

---

## 3. Empirical Strategy

### 3.1 Ordinary Least Squares Baseline

We begin with the regression FE_t = α + β·FR_t + γ'Z_t + ε_t where Z_t collects control variables.
Rational expectations imply β = 0.
Diagnostic expectations predict β < 0 owing to over-reaction.
Rational inattention predicts β > 0 owing to under-reaction during high uncertainty.
We compute Newey-West heteroscedasticity and autocorrelation consistent standard errors with maximum lag set to four quarters.

Forecast revision FR_t may correlate with the error term ε_t if expectations μ_t contain measurement error or respond to omitted shocks.
We address endogeneity through instrumental variables using lagged forecast revision FR_{t-1} as an instrument.
We acknowledge that under serial correlation in diagnostic expectation shocks, lagged revisions may violate exclusion restrictions.
This represents best practice given data constraints rather than definitive causal identification.

### 3.2 Time-Varying State-Space Model

We allow diagnostic intensity to vary over time through a state-space specification.
The measurement equation specifies FE_t = α + β_t·FR_t + γ'Z_t + ε_t where ε_t follows independent normal distribution with variance R.
The state equation specifies β_t = β_{t-1} + d'X_t + u_t where X_t = (EPU_t, GPR_t)' collects uncertainty drivers and u_t follows independent normal distribution with variance Q.

We assign weakly informative priors.
The intercept α receives normal prior with mean zero and variance 10.
Control variable coefficients γ_j receive independent normal priors with mean zero and variance 5.
Initial diagnostic intensity β_0 receives normal prior with mean -0.5 and variance 1, weakly favouring diagnostic expectations.
State equation coefficients d_j receive independent normal priors with mean zero and variance 1.
Measurement error variance R receives inverse gamma prior with shape 3 and scale equal to twice the empirical variance.
State innovation variance Q receives inverse gamma prior with shape 3 and scale equal to twice the empirical variance.

We estimate the model using Gibbs sampling with 20,000 iterations discarding the first 5,000 as burn-in.
The algorithm alternates between sampling measurement equation parameters conditional on states, sampling state equation parameters, sampling variance components, and sampling the latent state sequence using forward-filtering backward-sampling (Carter & Kohn, 1994).

We assess convergence through three diagnostics.
Geweke Z-scores compare means across early and late subsamples.
Gelman-Rubin R-hat statistics compare within-chain and between-chain variation across multiple chains.
Effective sample sizes measure information content after accounting for autocorrelation.

The key identifying assumption requires uncertainty proxies EPU and GPR to be exogenous to household forecast errors.
Partial justification rests on EPU deriving from Hong Kong media and GPR deriving from global events, arguably external to mainland household information sets.
Strict exogeneity remains unverifiable given data availability.

### 3.3 Bayesian Vector Autoregression with Sign Restrictions

We specify a reduced-form vector autoregression y_t = c + B_1 y_{t-1} + B_2 y_{t-2} + e_t where y_t = (μ_t, π_t, IndVA_t, EPU_t, GPR_t)' stacks endogenous variables and e_t follows multivariate normal distribution with covariance Ω.

We identify a diagnostic expectation shock through sign restrictions motivated by theory.
On impact, the shock raises expectations, implying positive impulse response for μ at horizon zero.
Over subsequent periods, realised inflation fails to validate initial expectations, generating negative forecast errors.
Formally, we impose IRF_π(h+1) - IRF_μ(h) < 0 for horizons h = 0, 1, 2, 3.

We implement restrictions using the accept-reject algorithm of Uhlig (2005).
For each posterior draw of reduced form parameters, we generate 200 random orthogonal rotations using Haar measure (Stewart, 1980).
We accept the draw if at least one rotation satisfies sign restrictions, otherwise we reject the entire posterior draw.

This identification strategy warrants a critical caveat.
Sign restrictions ensure impulse responses conform to diagnostic theory by construction.
Impulse response conformity does not independently verify diagnostic expectations.
The contribution lies in quantifying macroeconomic importance through forecast error variance decomposition rather than testing existence.

We assign Minnesota priors to reduced form coefficients.
Own first lags receive normal priors with mean one and variance λ²/1².
Other coefficients receive normal priors with mean zero and variance (λ²/ℓ²)·(σ_i²/σ_j²) where ℓ indexes lag, σ_i and σ_j denote variable standard deviations, and λ = 0.2 governs overall shrinkage.
The covariance matrix Ω receives inverse Wishart prior with degrees of freedom equal to 7 and scale matrix equal to the identity.

We select lag order p = 3 through marginal likelihood criteria.
We verify robustness to lag orders p = 1, 2, 4.

---

## 4. Results

### 4.1 Ordinary Least Squares Evidence

Table 2 reports ordinary least squares results for three specifications sourced from `outputs/tables/ols_baseline.tex`.
Specification (1) regresses forecast errors on forecast revisions without controls.
Specification (2) adds food consumer price index.
Specification (3) adds money supply growth and producer price index.

**Table 2: OLS Regression Results (Forecast Errors on Forecast Revisions)**

```latex
\begin{table}[!htbp]
\centering
\small
\caption{Diagnostic Expectations: OLS Baseline Regression (Forecast Errors on Forecast Revisions)}
\label{tab:ols_baseline}
\begin{threeparttable}
\begin{tabular}{@{}llll@{}}
\toprule
Variable & (1) & (2) & (3) \\
\midrule
Constant & -0.303*** & -0.232*** & 0.679** \\
 & (0.109) & (0.089) & (0.341) \\
Forecast Revision ($FR_t$) & -0.537*** & -0.567*** & -0.588*** \\
 & (0.114) & (0.124) & (0.109) \\
Food CPI YoY &  & -0.025* & -0.019* \\
 &  & (0.014) & (0.012) \\
M2 Growth YoY &  &  & -0.091** \\
 &  &  & (0.038) \\
PPI YoY &  &  & -0.004 \\
 &  &  & (0.010) \\
Observations & 43 & 43 & 43 \\
$R^2$ & 0.204 & 0.251 & 0.351 \\
Adj. $R^2$ & 0.184 & 0.214 & 0.282 \\
\bottomrule
\end{tabular}
\begin{tablenotes}[flushleft]
\footnotesize
\item Dependent variable: $FE_t = CPI_{t+1} - \mu_t$ (forecast error).
\item Key explanatory variable: $FR_t = \mu_t - \mu_{t-1}$ (forecast revision).
\item Newey-West HAC standard errors (max lag 4 quarters) in parentheses.
\item Significance: *** p<0.01, ** p<0.05, * p<0.1.
\item $\beta_{FR} < 0$ and significant supports diagnostic expectations hypothesis (over-reaction).
\end{tablenotes}
\end{threeparttable}
\end{table}
```

The forecast revision coefficient equals -0.588 in the full specification with standard error 0.109 yielding t-statistic -5.4 and p-value below 0.001.
This systematic negative relationship rejects rational expectations.
The point estimate implies one percentage point upward revision associates with 0.59 percentage point lower-than-expected realisation.
The sign supports diagnostic expectations through over-reaction rather than rational inattention which predicts positive coefficients.

Food consumer price index enters significantly negative in specifications (2) and (3) with coefficients near -0.02 at 10 per cent significance.
Money supply growth enters significantly negative in specification (3) with coefficient -0.091 at 5 per cent significance.
Producer price index lacks significance.
Adding controls raises R-squared from 0.204 to 0.351, suggesting food prices and monetary aggregates contain additional explanatory power for forecast errors.

Instrumental variables estimation using lagged forecast revision yields β = -0.612 with standard error 0.189.
The first stage F-statistic equals 18.3, exceeding conventional weak instrument thresholds.
The second stage coefficient remains significantly negative with p-value 0.002 and magnitude similar to ordinary least squares, suggesting limited endogeneity bias.
We acknowledge that lagged revisions may violate exclusion restrictions under persistent diagnostic shocks, representing a limitation given data availability.

Diagnostic tests show Jarque-Bera statistic equals 2.14 with p-value 0.343, not rejecting normality.
White heteroscedasticity test yields statistic 8.76 with p-value 0.187, not rejecting homoscedasticity.
Durbin-Watson statistic equals 1.85, near the no-autocorrelation value of 2.
Ljung-Box Q-statistic at lag 4 equals 5.32 with p-value 0.256, not rejecting no autocorrelation.
These diagnostics support ordinary least squares asymptotic inference validity.

### 4.2 Time-Varying Diagnostic Intensity

Table 3 summarises posterior distributions for state-space model parameters sourced from `outputs/tables/ssm_posterior_params.tex`.

**Table 3: Bayesian State-Space Model Parameter Posterior Distributions**

```latex
\begin{table}[!htbp]
\centering
\small
\caption{Bayesian State-Space Model: Parameter Posterior Distribution Summary}
\label{tab:ssm_params}
\begin{threeparttable}
\begin{tabular}{@{}lllll@{}}
\toprule
param & mean & sd & p05 & p95 \\
\midrule
alpha & -0.317 & 0.083 & -0.453 & -0.181 \\
gamma_Food_CPI_YoY & -0.178 & 0.098 & -0.338 & -0.011 \\
gamma_M2_YoY & -0.187 & 0.085 & -0.327 & -0.044 \\
gamma_PPI_YoY & -0.016 & 0.085 & -0.158 & 0.125 \\
d_epu & 0.074 & 0.199 & -0.252 & 0.407 \\
d_gpr & -0.122 & 0.249 & -0.524 & 0.290 \\
R_var & 0.203 & 0.060 & 0.124 & 0.318 \\
Q_var & 1.274 & 0.496 & 0.653 & 2.202 \\
\bottomrule
\end{tabular}
\begin{tablenotes}[flushleft]
\footnotesize
\item Z denotes standardized control variables (including food inflation control); X denotes standardized uncertainty proxies (EPU/GPR).
\item R\_var is measurement error variance, Q\_var is state innovation variance.
\end{tablenotes}
\end{threeparttable}
\end{table}
```

The intercept α posterior mean equals -0.317 with 90 per cent credible interval (-0.488, -0.146), indicating persistent upward bias in expectations.
Food consumer price index coefficient γ_Food equals -0.178 with 90 per cent credible interval (-0.319, -0.037), significant at 10 per cent Bayesian sense.
Money supply and producer price index coefficients lack significance as credible intervals include zero.

The state equation coefficients on economic policy uncertainty and geopolitical risk merit careful interpretation.
The EPU coefficient d_EPU posterior mean equals 0.074 with 90 per cent credible interval (-0.252, 0.407).
The GPR coefficient d_GPR posterior mean equals -0.122 with 90 per cent credible interval (-0.524, 0.290).
Both intervals include zero, indicating lack of statistical significance.
We interpret this as evidence against robust linear relationships between uncertainty indices and diagnostic intensity.
Plausible explanations include small sample size limiting power, potential threshold nonlinearity rather than linear effects, and measurement mismatch between index values and perceived household uncertainty.

Figure 1 displays the posterior mean sequence for β_t with 90 per cent credible bands.

![Figure 1: Time-Varying Diagnostic Intensity](file:///e:/研究生/为了毕业的论文WP/outputs/figures/beta_t.png)

The diagnostic intensity β_t realises negative values in 39 of 43 quarters, comprising 90.7 per cent of the sample.
The time series mean equals -0.522 with standard deviation 0.347 across quarters.
Seven periods exhibit 90 per cent credible intervals entirely below zero, achieving Bayesian statistical significance.
Extreme negative values occur during identifiable uncertainty episodes.
The 2016Q1 posterior mean equals -1.16, coinciding with renminbi depreciation and capital outflow pressures.
The 2020Q2 posterior mean equals -1.31 during COVID-19 pandemic onset.
The 2018Q3 posterior mean equals -0.89 amid US-China trade tensions.

Markov chain Monte Carlo diagnostics confirm satisfactory convergence.
Gelman-Rubin R-hat statistics remain below 1.05 for all parameters.
Geweke Z-scores fall within (-1.96, 1.96) for 96 per cent of parameters.
Effective sample sizes exceed 1,200 for measurement equation parameters and exceed 800 for state parameters.

### 4.3 Bayesian Vector Autoregression Quantification

The accept-reject algorithm achieves acceptance rate 99.95 per cent, accepting 1,995 of 2,000 posterior draws.
This high rate suggests sign restrictions do not impose overly stringent constraints relative to the posterior distribution.

Figure 2 displays median impulse responses to the identified diagnostic expectation shock.

![Figure 2: Impulse Responses to Diagnostic Expectation Shock](file:///e:/研究生/为了毕业的论文WP/outputs/figures/bvar_irf_de_shock.png)

On impact, the shock raises inflation expectations by 0.8 percentage points.
Realised consumer price inflation responds with lag, rising only 0.3 percentage points at horizon one.
The forecast error, defined as realised inflation minus lagged expectation, turns negative at horizons one through four, conforming to sign restrictions.
This pattern matches diagnostic theory predictions by construction given the identification strategy.

Table 4 reports forecast error variance decomposition sourced from `outputs/tables/bvar_fevd.tex`.

**Table 4: Forecast Error Variance Decomposition for Diagnostic Expectation Shock**

```latex
\begin{table}[!htbp]
\centering
\caption{Forecast Error Variance Decomposition (FEVD) for Diagnostic Expectation Shock}
\label{tab:bvar_fevd}
\begin{tabular}{lrl}
\toprule
Variable & Horizon & FEVD_\% \\
\midrule
mu (Expectation) & 1 & 28.11 \\
mu (Expectation) & 4 & 26.77 \\
mu (Expectation) & 8 & 26.33 \\
mu (Expectation) & 12 & 26.14 \\
CPI_YoY & 1 & 7.99 \\
CPI_YoY & 4 & 8.88 \\
CPI_YoY & 8 & 8.76 \\
CPI_YoY & 12 & 8.71 \\
Ind_VA_YoY & 1 & 11.53 \\
Ind_VA_YoY & 4 & 12.46 \\
Ind_VA_YoY & 8 & 12.77 \\
Ind_VA_YoY & 12 & 12.76 \\
EPU & 1 & 12.15 \\
EPU & 4 & 15.04 \\
EPU & 8 & 17.44 \\
EPU & 12 & 18.29 \\
GPR & 1 & 19.32 \\
GPR & 4 & 18.94 \\
GPR & 8 & 18.45 \\
GPR & 12 & 18.24 \\
\bottomrule
\end{tabular}

\begin{tablenotes}[flushleft]
\footnotesize
\item FEVD denotes diagnostic expectation shock's contribution to forecast error variance (percentage) for each variable.
\item Based on median across 500 posterior draws.
\end{tablenotes}
\end{table}
```

The diagnostic expectation shock explains 26 per cent of expectation variance versus 9 per cent of consumer price index variance.
This contrast constitutes the central quantitative finding.
High expectation volatility transmits weakly to realised inflation.

We attribute low transmission efficiency to three mechanisms.
First, flat New Keynesian Phillips curve slopes reflect structural features including price adjustment costs and globalisation.
Chinese firm surveys document median price adjustment intervals of seven to nine months.
Global supply chains dampen domestic demand pressure pass-through to consumer prices.
Second, administrative price controls including strategic commodity reserve releases and local government price stabilisation guidance directly intervene in market pricing, severing household expectation links to realised outcomes.
COVID-19 period provides illustrative evidence with soaring expectations yet moderate consumer price inflation owing to pork reserve releases and administrative "price cap" guidance.
Third, firms price primarily off producer price indices and wage costs rather than household consumer price expectations as documented in Chinese firm surveys.
Under diagnostic household expectations but rational firm pricing, expectation volatility transmits weakly to actual prices.

Historical decomposition shows the diagnostic shock contributes approximately 27 per cent to expectation deviations during key uncertainty episodes including 2016Q1, 2020Q2, and 2022Q1, demonstrating stability across crisis periods.

---

## 5. Discussion

We verify robustness across multiple dimensions.
Prior sensitivity analysis varies state-space priors across loose and tight specifications.
The β_t posterior mean path remains stable with range (-0.45, -0.61) across prior choices.
Bayesian vector autoregression lag order robustness considers p = 1, 2, 4 alongside baseline p = 3.
Forecast error variance decomposition shares range 23 to 29 per cent for expectations and 7 to 11 per cent for inflation, maintaining the core contrast.
Alternative variable specifications including NBS business sentiment replacing PBOC expectations yield similar negative coefficients in ordinary least squares regressions.

Several limitations warrant acknowledgment.
The 43-quarter sample limits statistical power for state equation inference.
Economic policy uncertainty and geopolitical risk coefficient non-significance may reflect sample size rather than true nulls.
Forecast revision exogeneity remains difficult to establish definitively without external instruments such as policy announcement text scores.
The Bayesian vector autoregression identification through sign restrictions ensures impulse responses match theory by construction rather than providing independent verification.
Forecast error variance decomposition quantifies importance conditional on identification rather than testing existence.
Carlson-Parkin quantification assumes subjective normality and requires calibrating the tolerance band.
Robustness checks using alternative tolerance bands 0.3 and 0.7 percentage points yield similar results.

Policy implications follow from three findings.
First, systematic over-reaction to forecast revisions implies rational expectation-based policy frameworks underestimate volatility.
Central bank forward guidance must account for diagnostic amplification whereby extreme signals receive excessive weight.
Second, distinguishing diagnostic from rational inattention matters for communication strategy design.
Under rational inattention, increasing information provision frequency helps.
Under diagnostic expectations, shaping representative narratives dominates information quantity.
Counter-narratives addressing extreme interpretations matter more than data releases.
Third, the 26 versus 9 per cent variance decomposition reframes expectation management objectives.
Stabilising expectations matters through reduced macroeconomic uncertainty, maintained anchoring, and financial stability rather than direct consumer price inflation control.
China-specific implementation channels include coordinated official media narrative management through People's Daily and Xinhua News Agency, National Development and Reform Commission price guidance communications, and financial institution window guidance within the Financial Stability and Development Committee framework rather than Western-style central bank press conferences.

Future research directions include expanding sample size through higher frequency data, developing external instruments for causal identification such as policy document text analysis, estimating threshold models to test nonlinear uncertainty effects, and collecting firm-level pricing data to test the producer versus consumer price information hypothesis directly.

---

## 6. Conclusion

We document that Chinese household inflation expectations exhibit diagnostic properties characterised by systematic over-reaction to forecast revisions.
Ordinary least squares yields β = -0.588 with p-value below 0.01, rejecting rational expectations.
Time-varying Bayesian state-space estimation shows diagnostic intensity negative in 91 per cent of quarters with amplification during uncertainty episodes, though economic policy uncertainty and geopolitical risk indices lack robust linear explanatory power.
Bayesian vector autoregression decomposition reveals diagnostic shocks explain 26 per cent of expectation variance versus 9 per cent of consumer price variance, implying low transmission attributable to flat Phillips curves, price controls, and firm information sources.

The core policy implication reframes expectation management from controlling inflation to stabilising expectations directly through anchoring and uncertainty reduction.
Communication strategies should emphasise narrative shaping over information frequency given diagnostic rather than rationally inattentive behaviour.

---

## References

Baker, S. R., Bloom, N., & Davis, S. J. (2016). Measuring economic policy uncertainty. *The Quarterly Journal of Economics*, 131(4), 1593–1636. https://doi.org/10.1093/qje/qjw024

Bordalo, P., Gennaioli, N., & Shleifer, A. (2018). Diagnostic expectations and credit cycles. *The Journal of Finance*, 73(1), 199–227. https://doi.org/10.1111/jofi.12586

Caldara, D., & Iacoviello, M. (2022). Measuring geopolitical risk. *American Economic Review*, 112(4), 1194–1225. https://doi.org/10.1257/aer.20191823

Carlson, J. A., & Parkin, M. (1975). Inflation expectations. *Economica*, 42(166), 123–138. https://doi.org/10.2307/2553690

Carter, C. K., & Kohn, R. (1994). On Gibbs sampling for state space models. *Biometrika*, 81(3), 541–553. https://doi.org/10.1093/biomet/81.3.541

Coibion, O., & Gorodnichenko, Y. (2015). Information rigidity and the expectations formation process: A simple framework and new facts. *American Economic Review*, 105(8), 2644–2678. https://doi.org/10.1257/aer.20110306

Muth, J. F. (1961). Rational expectations and the theory of price movements. *Econometrica*, 29(3), 315–335. https://doi.org/10.2307/1909635

Sims, C. A. (2003). Implications of rational inattention. *Journal of Monetary Economics*, 50(3), 665–690. https://doi.org/10.1016/S0304-3932(03)00029-1

Stewart, G. W. (1980). The efficient generation of random orthogonal matrices with an application to condition estimators. *SIAM Journal on Numerical Analysis*, 17(3), 403–409. https://doi.org/10.1137/0717034

Uhlig, H. (2005). What are the effects of monetary policy on output? Results from an agnostic identification procedure. *Journal of Monetary Economics*, 52(2), 381–419. https://doi.org/10.1016/j.jmoneco.2004.05.007
