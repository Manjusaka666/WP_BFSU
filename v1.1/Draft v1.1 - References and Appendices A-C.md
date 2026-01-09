# Draft v1.1 -参考文献与附录A-C

## 参考文献

Akerlof, G. A., & Shiller, R. J. (2009). *Animal Spirits: How Human Psychology Drives the Economy, and Why It Matters for Global Capitalism*. Princeton University Press.

Baker, S. R., Bloom, N., & Davis, S. J. (2016). Measuring Economic Policy Uncertainty. *The Quarterly Journal of Economics*, 131(4), 1593–1636.

Barnard, J., McCulloch, R., & Meng, X. L. (2000). Modeling covariance matrices in terms of standard deviations and correlations, with application to shrinkage. *Statistica Sinica*, 10(4), 1281–1311.

Basu, S., & Bundick, B. (2017). Uncertainty shocks in a model of effective demand. *Econometrica*, 85(3), 937–958.

Bernanke, B. S. (1983). Irreversibility, uncertainty, and cyclical investment. *The Quarterly Journal of Economics*, 98(1), 85–106.

Blanchard, O. J., & Quah, D. (1989). The dynamic effects of aggregate demand and supply disturbances. *American Economic Review*, 79(4), 655–673.

Bloom, N. (2009). The impact of uncertainty shocks. *Econometrica*, 77(3), 623–685.

Bordalo, P., Gennaioli, N., & Shleifer, A. (2018). Diagnostic expectations and credit cycles. *The Journal of Finance*, 73(1), 199–227.

Bordalo, P., Gennaioli, N., & Shleifer, A. (2020). Memory, attention, and choice. *The Quarterly Journal of Economics*, 135(3), 1399–1442.

Bruine de Bruin, W., van der Klaauw, W., Downs, J. S., Fischhoff, B., Topa, G., & Armantier, O. (2010). Expectations of inflation: The role of demographic variables, expectation formation, and financial literacy. *Journal of Consumer Affairs*, 44(2), 381–402.

Caldara, D., & Iacoviello, M. (2022). Measuring geopolitical risk. *American Economic Review*, 112(4), 1194–1225.

Carlson, J. A., & Parkin, M. (1975). Inflation expectations. *Economica*, 42(166), 123–138.

Carroll, C. D. (2003). Macroeconomic expectations of households and professional forecasters. *The Quarterly Journal of Economics*, 118(1), 269–298.

Gennaioli, N., & Shleifer, A. (2010). What comes to mind. *The Quarterly Journal of Economics*, 125(4), 1399–1433.

Giannone, D., Lenza, M., & Primiceri, G. E. (2015). Prior selection for vector autoregressions. *Review of Economics and Statistics*, 97(2), 436–451.

Jurado, K., Ludvigson, S. C., & Ng, S. (2015). Measuring uncertainty. *American Economic Review*, 105(3), 1177–1216.

Kahneman, D., & Tversky, A. (1972). Subjective probability: A judgment of representativeness. *Cognitive Psychology*, 3(3), 430–454.

Litterman, R. B. (1986). Forecasting with Bayesian vector autoregressions—Five years of experience. *Journal of Business & Economic Statistics*, 4(1), 25–38.

Lucas, R. E. (1972). Expectations and the neutrality of money. *Journal of Economic Theory*, 4(2), 103–124.

Malmendier, U., & Nagel, S. (2016). Learning from inflation experiences. *The Quarterly Journal of Economics*, 131(1), 53–87.

Mankiw, N. G., & Reis, R. (2002). Sticky information versus sticky prices: a proposal to replace the New Keynesian Phillips Curve. *The Quarterly Journal of Economics*, 117(4), 1295–1328.

Mertens, K., & Ravn, M. O. (2013). The dynamic effects of personal and corporate income tax changes in the United States. *American Economic Review*, 103(4), 1212–1247.

Muth, J. F. (1961). Rational expectations and the theory of price movements. *Econometrica*, 29(3), 315–335.

Oh, J. (2020). The propagation of uncertainty shocks: Rotemberg versus Calvo. *International Economic Review*, 61(3), 1113–1135.

Ramey, V. A. (2016). Macroeconomic shocks and their propagation. *Handbook of Macroeconomics*, 2, 71–162.

Rigobon, R. (2003). Identification through heteroskedasticity. *Review of Economics and Statistics*, 85(4), 777–792.

Romer, C. D., & Romer, D. H. (2004). A new measure of monetary shocks: Derivation and implications. *American Economic Review*, 94(4), 1055–1084.

Rossi, B., & Sekhposyan, T. (2016). Forecast rationality tests in the presence of instabilities, with applications to Federal Reserve and survey forecasts. *Journal of Applied Econometrics*, 31(3), 507–532.

Rubio-Ramirez, J. F., Waggoner, D. F., & Zha, T. (2010). Structural vector autoregressions: Theory of identification and algorithms for inference. *Review of Economic Studies*, 77(2), 665–696.

Shiller, R. J. (2000). *Irrational Exuberance*. Princeton University Press.

Shiller, R. J. (2017). Narrative economics. *American Economic Review*, 107(4), 967–1004.

Sims, C. A. (2003). Implications of rational inattention. *Journal of Monetary Economics*, 50(3), 665–690.

Stewart, G. W. (1980). The efficient generation of random orthogonal matrices with an application to condition estimators. *SIAM Journal on Numerical Analysis*, 17(3), 403–409.

Stock, J. H., & Watson, M. W. (2012). Disentangling the channels of the 2007-2009 recession. *Brookings Papers on Economic Activity*, 2012(1), 81–135.

Uhlig, H. (2005). What are the effects of monetary policy on output? Results from an agnostic identification procedure. *Journal of Monetary Economics*, 52(2), 381–419.

Wright, J. H. (2012). What does monetary policy do to long-term interest rates at the zero lower bound? *The Economic Journal*, 122(564), F447–F466.

---

## 附录A：Carlson-Parkin定量化方法的技术细节

本附录详细说明Carlson-Parkin方法将问卷定性回答转化为定量通胀预期的步骤。

假设个体对未来通胀$\pi_{t+1}$的主观分布为$N(\mu_t, \sigma_t^2)$，存在容忍带宽$[-\delta, +\delta]$，当预期通胀落在此区间内时个体回答"基本不变"，低于$-\delta$时回答"下降"，高于$+\delta$时回答"上升"。记剔除"看不准"后归一化的各项比例为$p^{up}_t$、$p^{same}_t$、$p^{down}_t$。

根据正态分布性质，有：

$$p^{down}_t = \Phi\left(\frac{-\delta - \mu_t}{\sigma_t}\right)$$

$$p^{up}_t = 1 - \Phi\left(\frac{+\delta - \mu_t}{\sigma_t}\right)$$

定义标准化分位数：

$$z_d = \Phi^{-1}(p^{down}_t), \quad z_u = \Phi^{-1}(1 - p^{up}_t)$$

则有：

$$z_d = \frac{-\delta - \mu_t}{\sigma_t}, \quad z_u = \frac{+\delta - \mu_t}{\sigma_t}$$

解得：

$$\sigma_t = \frac{2\delta}{z_u - z_d}$$

$$\mu_t = -\delta - \sigma_t \cdot z_d = +\delta - \sigma_t \cdot z_u$$

在实际操作中，我们设定$\delta = 0.5$个百分点，并以当期CPI同比作为基准通胀率$\pi_t$，最终定量化预期为：

$$\mu_{t} = \pi_t + \delta - \sigma_t \cdot z_u$$

**数据覆盖情况**：CP预期在48个季度可得（2013Q1–2025Q3）。缺失季度为：2011Q1-Q4, 2012Q1-Q2, 2012Q4, 2013Q2, 2015Q1, 2020Q4。

## 附录B：TVP-SSM模型的MCMC算法细节

本附录说明贝叶斯状态空间模型的Gibbs抽样算法。

**算法步骤：**

1. 初始化所有参数$(\alpha, \gamma, \beta_{1:T}, d, R, Q)$

2. 对于第$m$次迭代：
   
   a) **抽取测量方程参数**：给定$\beta_{1:T}$和数据，从测量方程构造似然函数
   
   $$p(\alpha, \gamma | \beta_{1:T}, y, R) \propto p(y | \alpha, \gamma, \beta_{1:T}, R) \cdot p(\alpha, \gamma)$$
   
   由于正态先验和正态似然的共轭性，条件后验为多元正态分布，可直接抽样。
   
   b) **抽取状态路径**：给定$(\alpha, \gamma, d, R, Q)$，使用Forward Filtering Backward Sampling (FFBS)算法抽取$\beta_{1:T}$
   
   - **Forward Filtering**：运行Kalman滤波，计算每期的滤波分布$p(\beta_t | y_{1:t})$
   - **Backward Sampling**：从$t=T$倒推至$t=1$，从条件分布$p(\beta_t | \beta_{t+1}, y_{1:t})$抽样
   
   c) **抽取状态方程参数**：给定$\beta_{1:T}$，从状态方程回归$\Delta\beta_t$对$X_t$，抽取$d$
   
   $$p(d | \beta_{1:T}, Q) \propto p(\beta_{1:T} | d, Q) \cdot p(d)$$
   
   同样利用正态共轭性直接抽样。
   
   d) **抽取方差参数**：
   
   - 测量误差方差：$R | \alpha, \gamma, \beta_{1:T}, y \sim IG(a_R + T/2, b_R + SSR_R/2)$
   - 状态扰动方差：$Q | \beta_{1:T}, d \sim IG(a_Q + T/2, b_Q + SSR_Q/2)$

3. 重复步骤2共20000次，丢弃前5000次（烧入期），每隔10次保留一个样本

4. **收敛诊断**：
   - Geweke统计量：比较链前10%与后50%的均值差异
   - 有效样本量：通过自相关函数计算无效因子
   - Gelman-Rubin统计量：运行多条独立链比较链间与链内方差

## 附录C：BVAR符号约束的旋转算法

本附录说明符号约束识别中的随机正交旋转算法。

给定降阶型VAR的协方差矩阵$\Omega$，进行Cholesky分解得$\Omega = PP'$，其中$P$为下三角矩阵。任意正交矩阵$Q$（满足$QQ'=I$）可生成另一组结构冲击$\tilde{P} = PQ$，使得$\tilde{P}\tilde{P}' = \Omega$。

**随机正交矩阵生成（QR分解法）：**

1. 从标准正态分布$N(0,1)$独立抽取$k \times k$矩阵$M$的每个元素

2. 对$M$进行QR分解：$M = QR$，其中$Q$为正交矩阵，$R$为上三角矩阵

3. 调整符号：令$D = diag(sign(R_{11}), \ldots, sign(R_{kk}))$，设置$Q \leftarrow QD$，$R \leftarrow DR$

4. 得到的$Q$在Haar测度下均匀分布于正交群$O(k)$

**符号约束检验与接受-拒绝：**

对于每次后验抽样$(B_{1:p}, \Omega)$：

1. Cholesky分解：$\Omega = PP'$

2. For $i = 1$ to $N_{rot}$ (设$N_{rot}=200$):
   
   a) 生成随机正交矩阵$Q_i$（QR分解法）
   
   b) 计算旋转后冲击矩阵：$\tilde{P}_i = P Q_i$
   
   c) 对$\tilde{P}_i$的每一列（代表一个结构冲击），计算IRF
   
   d) 检验该冲击的IRF是否满足所有符号约束：
   
   - $IRF_{\mu}(0) > 0$
   - $IRF_{\pi}(h+1) - IRF_{\mu}(h) < 0$ for $h=0,1,2,3$
   
   e) 若满足，标记该旋转为"接受"，保存对应的IRF

3. 如果200次旋转中至少有一次满足约束，则该后验抽样被接受

4. 重复2000次后验抽样，汇总所有接受的IRF形成后验推断

**计算优化**：

- 预计算VAR伴随矩阵的幂次，加速IRF计算
- 并行化旋转过程（每个后验抽样的200次旋转可并行）
- 早停：若在前50次旋转中已找到10个满足约束的冲击，停止该后验抽样的后续旋转
