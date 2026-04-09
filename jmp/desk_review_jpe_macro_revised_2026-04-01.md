Below is an English referee-style report. Yes—I would **directly and explicitly recommend Carlson–Parkin quantification** in the report, not as a cosmetic robustness check, but as part of the correction to the paper’s core measurement problem. That recommendation is methodologically defensible because the Carlson–Parkin probability approach is a standard way to convert qualitative inflation-expectation responses into quantitative expectations, although it requires explicit assumptions on the latent distribution and indifference bands. ([European Central Bank][1])

## Referee Report

**Recommendation: Reject**

This paper studies whether households overreact to salient relative-price shocks when forming inflation expectations, using province-level meat CPI shocks in China matched to CFPS household data. The question is interesting and potentially important. The topic fits a literature on expectation formation, overreaction, and diagnostic expectations that is clearly relevant for macroeconomics. However, in its current form, the paper falls well short of the publication standard of a top field journal such as *JPE: Macroeconomics*, which explicitly targets high-quality theoretical and empirical macroeconomic research. The main reason is not that the question lacks promise, but that the paper’s central empirical object, identification logic, and quantitative interpretation are not yet sufficiently credible for the strength of the claims being made. ([芝加哥期刊社][2])

The paper’s central claim is that households in provinces experiencing larger meat-price shocks subsequently make systematically more negative inflation forecast errors, and that the magnitude of this response is far too large to be reconciled with rational updating. The paper further argues that this is evidence of salience-driven diagnostic overreaction. I am not persuaded that the current design can support that conclusion. My view is that the paper contains an interesting pattern, but the present version does not establish the behavioral interpretation at the level required for publication in a leading macro journal. 

### 1. The core dependent variable is not yet a defensible forecast error

The most serious problem is the construction of the key “forecast error” variable. The paper subtracts a three-point ordinal qualitative response, coded as {-1, 0, 1}, from a subsequent realized CPI inflation outcome measured in percentage points. This object is then treated as a forecast error and compared to a rational benchmark derived from CPI weights. In my view, this is not acceptable as the paper’s core empirical object. The issue is not merely that the survey measure is noisy or coarse. The problem is that the left-hand side mixes an ordinal directional response with a cardinal inflation realization and then interprets the coefficient quantitatively as if both components were already expressed in commensurate units. That is too large a leap. 

The horizon mismatch compounds this problem. The CFPS question is framed in terms of whether prices in the “coming year” will rise, stay the same, or fall, whereas the realized outcome is constructed from inter-wave forward CPI over roughly biennial windows using wave midpoints. That makes the realized object only loosely connected to the forecast object elicited by the survey. Once the expectation measure is ordinal and the forecast horizon is not tightly aligned to the realization horizon, the paper’s strongest claim—that the estimated coefficient violates a rational upper bound by a factor of six or more—loses much of its force. 

This is precisely where I think the paper should be revised in a more serious way. I would explicitly recommend replacing the current pseudo-forecast-error construction with a quantification approach for the qualitative expectations, such as **Carlson–Parkin quantification**, implemented at an aggregate cell level where response shares can be defined consistently. That would not solve every problem, but it would move the paper from an internally inconsistent forecast-error measure toward one that is at least coherent in units. This is a standard route in the literature on qualitative inflation-expectation surveys. Carlson–Parkin–type methods were designed for exactly this purpose, though they require maintained assumptions such as normality and an indifference interval. ([European Central Bank][1])

### 2. The “rational bound” is not model-free and is not strong enough to bear the paper’s headline conclusion

The paper presents a signal-extraction benchmark in which the coefficient on the meat shock in the forecast-error regression is bounded by the CPI weight of meat, or by a simple time-aggregation multiple of that weight. The argument is elegant, but it is much less general than the paper suggests. It only works as a sharp rejection of rationality if one accepts a very narrow interpretation of what households may rationally infer from a large meat-price shock. 

In the model, households observe a meat-price shock and forecast future headline inflation. But in practice, households may rationally interpret a salient food-price surge as a signal not only about the direct mechanical contribution of meat to CPI, but also about broader food inflation, supply-chain stress, local inflation persistence, market conditions, or policy credibility. Once that broader informational interpretation is allowed, the CPI-weight bound is no longer a clean, model-free rationality bound. It becomes the implication of one specific and restrictive model. That is too weak a foundation for the paper’s repeated claim that “rationality is rejected regardless of persistence beliefs.” 

This matters because the paper’s behavioral interpretation rests heavily on this benchmark. If the benchmark is not robust, then the gap between the estimate and the bound cannot by itself identify diagnostic expectations. At most, it shows that the observed response is large relative to a narrow accounting-based benchmark.

### 3. The identification strategy remains too close to a single-episode cross-province comparison

The paper’s treatment variation is effectively at the province-by-wave level, and most of the identifying power comes from the ASF-driven 2018–2020 surge and the subsequent reversal. This makes the design much closer to a low-dimensional event-based comparison than to a fully convincing panel strategy. The household-level sample size is large, but the identifying variation is not. The paper itself acknowledges that the relevant treatment varies at the province-wave level, and that the effective cell count is small. That sharply limits how much one should learn from apparently precise household-level regressions. 

This would be less troubling if the paper had a cleaner source of exogenous provincial exposure. It does not. The text repeatedly invokes the biology of ASF spread and pre-determined herd geography, but that narrative is not turned into a serious research design. There is no properly executed instrument based on herd density, disease exposure, transport-network exposure, or outbreak timing. There is no convincing event-study design built around heterogeneous pre-exposure. There is no triple-difference structure that would isolate meat-specific salience from broader province-specific macro conditions. As a result, the paper remains vulnerable to province-specific time-varying confounds that are not removed by province fixed effects and region-by-wave fixed effects. 

The identification problem is particularly important because the paper wants a behavioral interpretation, not just a reduced-form correlation. That requires much more discipline than is currently present.

### 4. The mechanism evidence is suggestive, but far from decisive

The mechanism section argues for salience-driven overreaction by showing that meat shocks matter while grain shocks do not, and by showing limited demographic heterogeneity. I do not think this is strong enough. Grain is not an ideal placebo. It differs from meat in purchase frequency, volatility, government stabilization, and media salience. Therefore, a weak or null grain response does not isolate salience. It may simply indicate that grain is a different kind of signal. 

Similarly, the demographic heterogeneity results are too thin to carry the proposed mechanism. The absence of strong interactions with education, income, or urban status is not enough to establish that the channel is cognitive salience rather than expenditure shares, information frictions, or differential exposure to local inflation. A stronger paper would need either direct measures of salience exposure, richer placebo categories, or external evidence on media intensity or shopping-frequency channels.

### 5. The paper has serious internal consistency problems

Independently of the identification concerns, the manuscript is not yet clean enough for serious journal review. There are several internal inconsistencies that will undermine referee confidence immediately.

Most importantly, the paper is inconsistent about geographic coverage. In some places it states that the sample spans 31 provinces and that inference uses 31 clusters, while elsewhere it describes the CFPS public-use data as covering 25 provinces. The official CFPS documentation states that the 2010 baseline national survey was launched in **25 provinces/municipalities/autonomous regions**. If the effective sample in the present paper truly covers 31 provincial units, that must be documented clearly and reconciled with the underlying survey documentation. At present, the manuscript reads as internally inconsistent on this basic point.  ([isss.pku.edu.cn][3])

There are also coefficient inconsistencies. The abstract reports one headline coefficient, the introduction reports another, Table 2 reports yet another preferred estimate, and Table 5 compares the rational bound to a different coefficient again. For a paper whose entire thesis turns on one central magnitude, that is unacceptable. Likewise, the appendix material appears contaminated by content from a different quarterly macro/PBoC-based project, with variable definitions that do not align with the CFPS meat-shock design in the main text. These are not cosmetic editorial issues. They raise concerns about whether the current draft, data construction, tables, and appendices have been fully synchronized. 

### 6. Contribution relative to the literature is not yet strong enough for this outlet

There is already a substantial literature showing that agents overweight salient signals, that households respond strongly to frequently observed prices, and that overreaction can arise in macroeconomic expectations. The paper cites the right references, but the current empirical execution does not yet move the frontier enough relative to that literature. Existing work has already documented overreaction in expectations and the importance of salient consumer prices for household inflation beliefs. A top field journal will ask what this paper adds beyond a China-specific application with a pork-price episode. At the moment, the answer is not compelling enough. ([美国经济学会][4])

To be publishable at this level, the paper would need either a much cleaner causal design or a much deeper macroeconomic contribution. Right now it has neither. The empirical design is not clean enough to support strong behavioral inference, and the macroeconomic implications remain mostly verbal.

## Required revisions for a serious resubmission elsewhere

If the author wishes to turn this into a credible paper, I would recommend a substantial redesign rather than marginal revision.

First, the expectation and realization horizons need to be aligned using actual interview timing as closely as the data permit. The current wave-midpoint approximation is too crude for the strength of the paper’s claims. 

Second, the current forecast-error construction should be abandoned. I would explicitly recommend using **Carlson–Parkin quantification** or a related qualitative-to-quantitative conversion method at the province-wave level, provided the response shares are available and the identifying assumptions are stated clearly. If such quantification is not feasible at the desired level, then the paper should stop framing the left-hand side as a cardinal forecast error and instead move to ordered-response or share-based designs with more modest interpretation. Carlson–Parkin is not perfect—it imposes additional structure—but it is methodologically far more defensible than subtracting an ordinal code from realized inflation in percentage points. ([European Central Bank][1])

Third, the ASF narrative should be turned into a real identification design. A serious revision would exploit pre-ASF herd density, distance to early outbreaks, transport-network exposure, or another predetermined source of differential vulnerability. Without that step, the paper will continue to look like a strong correlation wrapped in a quasi-experimental narrative.

Fourth, the mechanism section should be strengthened materially. Better placebo categories, direct salience proxies, or evidence on media intensity would all help.

Fifth, the manuscript must be cleaned thoroughly. The province coverage issue, the coefficient inconsistencies, and the appendix contamination all need to be fixed before the paper can be assessed seriously.

## Final assessment

My recommendation is **reject**. The paper is built around a good question and a potentially useful setting, but the current version does not meet the evidentiary standard required for publication in *JPE: Macroeconomics*. The main empirical object is not yet defensible, the rational benchmark is too model-dependent, the identification is too loose for the claimed behavioral interpretation, and the manuscript still contains serious internal inconsistencies. ([芝加哥期刊社][2]) 

On your specific question: yes, I would **directly propose Carlson–Parkin quantification** in the review report. I would phrase it as a necessary correction to the paper’s current measurement strategy, with one qualification: it should be implemented at an aggregate level where response shares are meaningful, and the paper must acknowledge the additional assumptions that Carlson–Parkin imposes.

[1]: https://www.ecb.europa.eu/pub/pdf/scpwps/ecbwp1417.pdf?utm_source=chatgpt.com "Quantifying the qualitative responses of the output purchasing ..."
[2]: https://www.journals.uchicago.edu/pb-assets/docs/division/2025-UCPJ-catalog-web-1733433501303.pdf?utm_source=chatgpt.com "CATALOG"
[3]: https://www.isss.pku.edu.cn/cfps/docs/20220302153803194600.pdf?utm_source=chatgpt.com "CFPS China Family Panel Studies"
[4]: https://www.aeaweb.org/articles?id=10.1257%2Faer.20181219&utm_source=chatgpt.com "Overreaction in Macroeconomic Expectations"
