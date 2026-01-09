# Draft v1.1 - 数学附录 D-F：严谨推导与理论基础

## 附录D：TVP-SSM模型的贝叶斯推断完整推导

本附录提供TVP-SSM模型贝叶斯推断的完整数学推导，包括条件后验分布的详细计算和FFBS算法的理论基础。

### D.1 状态空间模型的一般形式与符号定义

考虑一般的线性高斯状态空间模型：

**测量方程**：
$$y_t = X_t \theta_t + Z_t \gamma + \varepsilon_t, \quad \varepsilon_t \sim N(0, R)  \qquad (D.1)$$

**状态方程**：
$$\theta_t = \theta_{t-1} + W_t d + u_t, \quad u_t \sim N(0, Q)  \qquad (D.2)$$

其中：
- $y_t$：观测变量（标量）
- $\theta_t$：时变状态参数（标量）
- $X_t$：状态变量的回归量（标量）
- $Z_t$：固定参数的回归量（向量）
- $\gamma$：固定参数向量
- $W_t$：状态演化的驱动变量（向量）
- $d$：驱动变量系数（向量）
- $R, Q$：方差参数（标量）

在我们的应用中：
- $y_t = FE_t$（预测误差）
- $\theta_t = \beta_t$（诊断性强度）
- $X_t = FR_t$（预测修正）
- $Z_t = (Food\_CPI_t, M2_t, PPI_t)'$
- $W_t = (EPU_t, GPR_t)'$

### D.2 条件后验分布的推导

#### D.2.1 固定参数$(\gamma, \alpha)$的条件后验

给定状态路径$\theta_{1:T}$和方差$R$，测量方程变为线性回归模型：

$$y_t = X_t \theta_t + Z_t \gamma + \alpha + \varepsilon_t$$

其中$\alpha$为截距项。定义$\tilde{y}_t = y_t - X_t \theta_t$，则：

$$\tilde{y}_t = Z_t \gamma + \alpha + \varepsilon_t$$

这是关于$(\gamma, \alpha)$的标准线性回归。堆叠所有$t=1,\ldots,T$：

$$\tilde{y} = \tilde{Z} \psi + \varepsilon, \quad \varepsilon \sim N(0, R I_T)$$

其中$\psi = (\gamma', \alpha)'$，$\tilde{Z} = [Z_1', 1; \ldots; Z_T', 1]'$。

**先验**：$\psi \sim N(\psi_0, \Sigma_0)$

**似然**：$p(\tilde{y} | \psi, R) \propto \exp\left\{-\frac{1}{2R}(\tilde{y} - \tilde{Z}\psi)'(\tilde{y} - \tilde{Z}\psi)\right\}$

**后验**（正态共轭）：

$$\psi | \tilde{y}, \theta_{1:T}, R \sim N(\psi_T, \Sigma_T)$$

其中：

$$\Sigma_T^{-1} = \Sigma_0^{-1} + \frac{1}{R} \tilde{Z}' \tilde{Z}  \qquad (D.3)$$

$$\psi_T = \Sigma_T \left( \Sigma_0^{-1} \psi_0 + \frac{1}{R} \tilde{Z}' \tilde{y} \right)  \qquad (D.4)$$

#### D.2.2 驱动变量系数$d$的条件后验

给定$\theta_{1:T}$和$Q$，状态方程可写为：

$$\Delta \theta_t := \theta_t - \theta_{t-1} = W_t d + u_t$$

堆叠$t=1,\ldots,T$（注意$\theta_0$为初值）：

$$\Delta \theta = W d + u, \quad u \sim N(0, Q I_T)$$

其中$\Delta\theta = (\Delta\theta_1, \ldots, \Delta\theta_T)'$，$W = (W_1', \ldots, W_T')'$。

**先验**：$d \sim N(d_0, \Lambda_0)$

**似然**：$p(\Delta\theta | d, Q) \propto \exp\left\{-\frac{1}{2Q}(\Delta\theta - Wd)'(\Delta\theta - Wd)\right\}$

**后验**：

$$d | \theta_{1:T}, Q \sim N(d_T, \Lambda_T)$$

其中：

$$\Lambda_T^{-1} = \Lambda_0^{-1} + \frac{1}{Q} W' W  \qquad (D.5)$$

$$d_T = \Lambda_T \left( \Lambda_0^{-1} d_0 + \frac{1}{Q} W' \Delta\theta \right)  \qquad (D.6)$$

#### D.2.3 方差参数的条件后验

**测量误差方差$R$**：

给定$\theta_{1:T}, \psi$，残差为$e_t = y_t - X_t\theta_t - Z_t\gamma - \alpha$。

**先验**：$R \sim IG(a_R, b_R)$

**似然**：$p(y | \theta, \psi, R) \propto R^{-T/2} \exp\left\{-\frac{1}{2R}\sum_t e_t^2\right\}$

**后验**：

$$R | y, \theta_{1:T}, \psi \sim IG\left(a_R + \frac{T}{2}, b_R + \frac{SSR_e}{2}\right)  \qquad (D.7)$$

其中$SSR_e = \sum_{t=1}^T e_t^2$。

**状态扰动方差$Q$**：

给定$\theta_{1:T}, d$，残差为$v_t = \Delta\theta_t - W_t d$。

**先验**：$Q \sim IG(a_Q, b_Q)$

**后验**：

$$Q | \theta_{1:T}, d \sim IG\left(a_Q + \frac{T}{2}, b_Q + \frac{SSR_v}{2}\right)  \qquad (D.8)$$

其中$SSR_v = \sum_{t=1}^T v_t^2$。

### D.3 状态变量的条件后验：Forward Filtering Backward Sampling

#### D.3.1 Kalman滤波的递推公式

给定$(\psi, d, R, Q)$和数据$y_{1:T}$，我们需要计算$p(\theta_t | y_{1:t})$（滤波分布）。

**初始化**（$t=0$）：

$$\theta_0 | y_0 \sim N(m_0, C_0)$$

其中$m_0, C_0$为先验均值和方差。

**预测步骤**（$t-1 \to t$）：

基于状态方程，$t$期的先验分布为：

$$\theta_t | y_{1:t-1} \sim N(a_t, R_t)$$

其中：

$$a_t = m_{t-1} + W_t d  \qquad (D.9)$$

$$R_t = C_{t-1} + Q  \qquad (D.10)$$

**更新步骤**（观测$y_t$后）：

观测方程的预测误差为：

$$f_t = y_t - X_t a_t - Z_t \gamma - \alpha$$

预测误差方差为：

$$Q_t = X_t^2 R_t + R  \qquad (D.11)$$

Kalman增益为：

$$K_t = R_t X_t / Q_t  \qquad (D.12)$$

滤波分布更新为：

$$\theta_t | y_{1:t} \sim N(m_t, C_t)$$

其中：

$$m_t = a_t + K_t f_t  \qquad (D.13)$$

$$C_t = R_t - K_t^2 Q_t  \qquad (D.14)$$

**递推至$t=T$**，得到所有滤波分布$\{N(m_t, C_t)\}_{t=1}^T$。

#### D.3.2 后向抽样的条件分布

Forward Filtering完成后，我们从$t=T$倒推至$t=1$进行抽样。

**初始化**（$t=T$）：

从滤波分布抽取：

$$\theta_T \sim N(m_T, C_T)  \qquad (D.15)$$

**递推**（$t < T$）：

给定$\theta_{t+1}$，条件分布$p(\theta_t | \theta_{t+1}, y_{1:t})$可通过贝叶斯定理推导。

从状态方程和滤波分布，可得联合分布：

$$\begin{pmatrix} \theta_t \\ \theta_{t+1} \end{pmatrix} \Bigg| y_{1:t} \sim N\left(\begin{pmatrix} m_t \\ a_{t+1} \end{pmatrix}, \begin{pmatrix} C_t & C_t \\ C_t & R_{t+1} \end{pmatrix}\right)$$

条件分布为：

$$\theta_t | \theta_{t+1}, y_{1:t} \sim N(h_t, H_t)  \qquad (D.16)$$

其中：

$$h_t = m_t + \frac{C_t}{R_{t+1}}(\theta_{t+1} - a_{t+1})  \qquad (D.17)$$

$$H_t = C_t - \frac{C_t^2}{R_{t+1}}  \qquad (D.18)$$

**抽样过程**：

For $t = T-1, T-2, \ldots, 1$:
$$\theta_t \sim N(h_t, H_t)$$

最终得到完整状态路径$\theta_{1:T}$的一次后验抽样。

### D.4 先验分布的共轭性证明

**定理**：在线性高斯状态空间模型中，若对所有参数采用正态或逆伽玛先验，则所有条件后验分布均为封闭形式（正态或逆伽玛）。

**证明**：

1. **固定参数$\psi$**：
   
   似然为高斯，先验为高斯，后验为高斯（正态是其自身的共轭先验）。见方程(D.3)-(D.4)。

2. **驱动变量系数$d$**：
   
   同理，后验为正态。见方程(D.5)-(D.6)。

3. **方差参数$R, Q$**：
   
   似然为$p(data | variance) \propto variance^{-n/2} \exp\{-SSE/(2 \cdot variance)\}$，这是逆伽玛的核。逆伽玛先验导致逆伽玛后验。见方程(D.7)-(D.8)。

4. **状态变量$\theta_{1:T}$**：
   
   FFBS算法的每一步均涉及正态分布的条件化和边缘化，结果仍为正态。见方程(D.15)-(D.18)。

因此，所有条件后验具有封闭形式，Gibbs抽样可高效实施。$\square$

### D.5 MCMC收敛性诊断的理论基础

#### D.5.1 Geweke诊断统计量

Geweke (1992)提出通过比较链的早期和晚期样本均值判断收敛。

记Markov链为$\{\theta^{(s)}\}_{s=1}^S$，定义：

- $\bar{\theta}_A$：前$n_A$个样本的均值（如前10%）
- $\bar{\theta}_B$：后$n_B$个样本的均值（如后50%）

若链已收敛，两个均值应来自同一平稳分布。Geweke统计量为：

$$z = \frac{\bar{\theta}_A - \bar{\theta}_B}{\sqrt{Var(\bar{\theta}_A) + Var(\bar{\theta}_B)}}  \qquad (D.19)$$

其中方差通过谱密度估计（考虑自相关）。在零假设（已收敛）下，$z \sim N(0,1)$。

**判据**：$|z| < 1.96$（5%水平）判为收敛。

#### D.5.2 有效样本量与无效因子

由于MCMC抽样的样本存在自相关，有效样本量(ESS)小于名义样本量$S$。定义：

$$ESS = \frac{S}{IF}  \qquad (D.20)$$

其中$IF$为无效因子(Inefficiency Factor)：

$$IF = 1 + 2\sum_{k=1}^K \rho_k  \qquad (D.21)$$

$\rho_k$为滞后$k$阶的样本自相关系数，求和至自相关不显著为止。

**解释**：$IF$衡量"多少次相关抽样等价于一次独立抽样"。$IF=1$表示无自相关（最优），$IF$越大表示效率越低。

**经验法则**：$ESS > 400$被认为足以进行可靠推断。

#### D.5.3 Gelman-Rubin诊断

Gelman-Rubin (1992)通过运行$M$条独立链比较"链间方差"与"链内方差"。

记第$j$条链($j=1,\ldots,M$)的样本为$\{\theta_j^{(s)}\}_{s=1}^S$。

**链内方差**：

$$W = \frac{1}{M}\sum_{j=1}^M s_j^2, \quad s_j^2 = \frac{1}{S-1}\sum_{s=1}^S (\theta_j^{(s)} - \bar{\theta}_j)^2  \qquad (D.22)$$

**链间方差**：

$$B = \frac{S}{M-1}\sum_{j=1}^M (\bar{\theta}_j - \bar{\bar{\theta}})^2  \qquad (D.23)$$

其中$\bar{\bar{\theta}} = \frac{1}{M}\sum_j \bar{\theta}_j$。

**方差估计量**：

$$\hat{Var}(\theta) = \frac{S-1}{S}W + \frac{1}{S}B  \qquad (D.24)$$

**潜在尺度缩减因子**（Potential Scale Reduction Factor, PSRF）：

$$\hat{R} = \sqrt{\frac{\hat{Var}(\theta)}{W}}  \qquad (D.25)$$

**判据**：$\hat{R} < 1.1$（或更严格地$< 1.05$）判为收敛。直觉上，若$\hat{R} \approx 1$，说明链间方差接近链内方差，链已混合良好。

## 附录E：BVAR符号约束识别的理论基础

本附录提供BVAR符号约束识别的完整数学推导，包括正交旋转的测度理论和识别集的形式化定义。

### E.1 降阶型到结构型的映射

#### E.1.1 VAR的降阶型与结构型

**降阶型**（Reduced Form）：

$$y_t = c + B_1 y_{t-1} + \cdots + B_p y_{t-p} + e_t, \quad e_t \sim N(0, \Omega)  \qquad (E.1)$$

**结构型**（Structural Form）：

$$A_0 y_t = A_c + A_1 y_{t-1} + \cdots + A_p y_{t-p} + \varepsilon_t, \quad \varepsilon_t \sim N(0, \Sigma)  \qquad (E.2)$$

其中$\Sigma = diag(\sigma_1^2, \ldots, \sigma_k^2)$为对角矩阵（标准化假设）。

**关系**：

$$e_t = A_0^{-1} \varepsilon_t$$

$$\Omega = A_0^{-1} \Sigma (A_0^{-1})'  \qquad (E.3)$$

#### E.1.2 识别问题

给定$\Omega$（从数据估计得到），需要恢复$(A_0, \Sigma)$。但方程(E.3)提供的约束不足：

- $\Omega$是$k \times k$对称矩阵，有$k(k+1)/2$个独立元素
- $A_0^{-1}$有$k^2$个元素，$\Sigma$有$k$个元素（对角）
- 总计$k^2 + k$个未知数

自由度差：$k^2 + k - k(k+1)/2 = k(k-1)/2$

因此需要$k(k-1)/2$个额外约束才能点识别。

**传统方法**：

- Cholesky分解：令$A_0$为下三角单位对角矩阵（$k(k-1)/2$个零约束）
- 长期约束：施加$k(k-1)/2$个冲击的长期效应约束

**符号约束方法**：不施加精确的零约束，而是施加不等式约束，得到部分识别(set identification)。

### E.2 正交旋转的测度理论

#### E.2.1 Cholesky分解与正交群

对$\Omega$进行Cholesky分解：

$$\Omega = PP', \quad P \text{ 下三角}  \qquad (E.4)$$

$P$的每一列可解释为一个结构冲击（经过某种标准化）。但这仅是无穷多可能分解中的一个。

**关键观察**：任意正交矩阵$Q \in O(k)$（满足$QQ'=I_k$）可生成另一组结构冲击：

$$\tilde{P} = PQ  \qquad (E.5)$$

且$\tilde{P}\tilde{P}' = PQQ'P' = PP' = \Omega$。

因此，所有可能的结构冲击矩阵形成集合$\{PQ : Q \in O(k)\}$。

#### E.2.2 Haar测度：正交群上的均匀分布

正交群$O(k) = \{Q \in \mathbb{R}^{k \times k} : QQ' = I_k\}$是一个紧致李群（compact Lie group）。

**Haar测度**：$O(k)$上存在唯一的左右不变测度$\mu$（归一化为$\mu(O(k))=1$），称为Haar测度。它是$O(k)$上"均匀分布"的自然定义。

**性质**：对任意$Q_0 \in O(k)$和可测集$A \subset O(k)$，

$$\mu(Q_0 A) = \mu(A Q_0) = \mu(A)  \qquad (E.6)$$

即测度在群运算下不变。

**直觉**：Haar测度保证"没有任何方向比其他方向更受偏好"，实现真正的随机性。

#### E.2.3 QR分解法生成均匀随机正交矩阵

**算法**（Stewart, 1980）：

1. 从$N(0,1)$独立抽取$k^2$个随机数，构成矩阵$M \in \mathbb{R}^{k \times k}$

2. 对$M$进行QR分解：$M = QR$，其中$Q$正交，$R$上三角

3. 标准化：令$D = diag(sign(R_{11}), \ldots, sign(R_{kk}))$，
   
   $$Q \leftarrow QD$$
   
   以保证$R$对角元为正（去除符号歧义）

4. 输出$Q$

**定理**（St ewart, 1980）：上述算法生成的$Q$在Haar测度下均匀分布于$O(k)$。

**证明概要**：

- 标准正态向量的联合分布在正交变换下不变
- QR分解的唯一性（在符号标准化后）保证$Q$的分布不依赖于$M$的特定实现
- 通过不变性原理，$Q$的分布必为Haar测度

$\square$

### E.3 符号约束的集合识别

#### E.3.1 识别集的形式化定义

记脉冲响应函数为$IRF(Q, h, j)$，表示通过旋转$Q$得到的第$j$个冲击在期数$h$的响应。

**符号约束集合**：

$$\mathcal{C} = \{(v, h) : IRF_v(Q, h, j) \lessgtr 0\}  \qquad (E.7)$$

其中$v \in \{1, \ldots, k\}$指变量，$\lessgtr$表示不等式方向（可为$>$或$<$）。

**识别集**：

$$\mathcal{Q}_{identified} = \{Q \in O(k) : \text{第}j\text{列满足所有}(v,h) \in \mathcal{C}\text{的约束}\}  \qquad (E.8)$$

**部分识别**：一般而言，$\mathcal{Q}_{identified}$不是单点集（点识别），而是$O(k)$的子集（集合识别）。

#### E.3.2 识别集的大小：Lebesgue测度

虽然$O(k)$的Haar测度归一化为1，但子集$\mathcal{Q}_{identified}$的测度$\mu(\mathcal{Q}_{identified})$量化了"满足约束的旋转占比"。

**经验估计**：通过Monte Carlo抽样，

$$\hat{\mu}(\mathcal{Q}_{identified}) = \frac{\#\{Q^{(i)} \in \mathcal{Q}_{identified}\}}{N_{trials}}  \qquad (E.9)$$

在我们的应用中，$N_{trials}=200$，每次后验抽样的接受率约为$1.59/200 \approx 0.008$，表明识别集相对"小"，识别相对"紧"。

#### E.3.3 贝叶斯推断下的部分识别

在贝叶斯框架下，部分识别通过后验分布自然处理：

1. 对每次后验抽样$(B_{1:p}, \Omega)$，计算$P$（Cholesky分解）

2. 生成$N_{rot}$个随机$Q \sim Haar(O(k))$

3. 对每个$Q$，检验$PQ$的第$j$列是否满足符号约束

4. 保留所有满足的$(Q, IRF(Q))$

5. 汇总所有后验抽样的满足结果，形成IRF的后验分布

**关键**：不需要"选择"哪一个$Q$是"真实"的，而是保留所有满足约束的$Q$，让数据的不确定性和识别的不确定性共同反映在后验分布中。

### E.4 脉冲响应函数的计算

#### E.4.1 结构冲击到IRF的映射

给定结构冲击矩阵$A_0^{-1}$（实际为$PQ$的某一列）和VAR系数$B_{1:p}$，变量$y$对冲击$\varepsilon_j$的IRF为：

$$IRF_{yj}(h) = \frac{\partial y_{t+h}}{\partial \varepsilon_{jt}}  \qquad (E.10)$$

**递推公式**：

记伴随矩阵$A = [B_1, \ldots, B_p, 0_{k \times k(n-p)}]'$（$kp \times kp$）。

定义增广状态向量$Y_t = (y_t', y_{t-1}', \ldots, y_{t-p+1}')'$。

则VAR可写为：

$$Y_t = c^* + A Y_{t-1} + e_t^*  \qquad (E.11)$$

其中$e_t^* = (e_t', 0', \ldots, 0')'$。

冲击$\varepsilon_j$对$Y_{t+h}$的影响为：

$$\frac{\partial Y_{t+h}}{\partial \varepsilon_{jt}} = A^h \cdot (A_0^{-1} e_j)  \qquad (E.12)$$

其中$e_j$为第$j$个标准基向量。

提取$Y$的前$k$个元素，即得$y$对冲击$j$在期数$h$的IRF。

#### E.4.2 预测误差逆转的IRF计算

在我们的应用中，关键约束涉及"预测误差逆转"：

$$FE_h = IRF_{\pi}(h+1) - IRF_{\mu}(h)  \qquad (E.13)$$

这需要计算两个变量（$\pi$和$\mu$）在不同期数的IRF，然后作差。

**实施**：

For $h = 0, 1, 2, 3$:

1. 计算$IRF_{\mu}(h)$和$IRF_{\pi}(h+1)$

2. 检验$IRF_{\pi}(h+1) - IRF_{\mu}(h) < 0$

3. 若所有$h$均满足，接受该结构冲击

这一检验直接对应经济理论的预测：预期的跳升超过实际通胀的响应，导致预测误差为负。

## 附录F：诊断性预期的微观基础

本附录提供诊断性预期理论的微观基础，推导从个体诊断性行为到总体预测误差系统性偏差的理论联系。

### F.1 代表性启发的形式化模型

#### F.1.1 基准：贝叶斯更新

考虑个体$i$对未来通胀$\pi_{t+1}$形成预期。个体观察到信号$s_t$，该信号满足：

$$s_t = \pi_{t+1} + \eta_t, \quad \eta_t \sim N(0, \sigma_\eta^2)  \qquad (F.1)$$

先验分布：$\pi_{t+1} \sim N(\pi^{prior}, \sigma_\pi^2)$

标准贝叶斯后验均值为：

$$\mu_i^{Bay} = \omega s_t + (1-\omega) \pi^{prior}  \qquad (F.2)$$

其中权重$\omega = \frac{\sigma_\pi^2}{\sigma_\pi^2 + \sigma_\eta^2}$（信号的精度权重）。

#### F.1.2 诊断性预期：过度加权代表性信号

Bordalo et al. (2018)提出，个体不仅更新信念，还会"高亮"那些在当前状态下特别具有代表性的特征。

**代表性的定义**：信号$s$的代表性通过"诊断比率"衡量：

$$\kappa(s|\theta) = \frac{p(s|\theta)}{p(s)}  \qquad (F.3)$$

其中$\theta$为关注的假设状态，$p(s)$为基准分布下信号的概率。

**诊断性预期**：主观概率为标准贝叶斯概率乘以诊断比率的$\theta$次幂：

$$p^{DE}(s|\theta) \propto p(s|\theta) \cdot \kappa(s|\theta)^\theta = p(s|\theta)^{1+\theta} \cdot p(s)^{-\theta}  \qquad (F.4)$$

其中$\theta \geq 0$为诊断性参数（behavioral parameter，注意与状态参数不同，这里用$\theta$仅为符号沿袭Bordalo原文）。

**预期的形成**：在线性正态设定下，可以证明（Bordalo et al., 2018, Appendix）：

$$\mu_i^{DE} = \omega(1+\theta) s_t + (1-\omega(1+\theta)) \pi^{prior}  \qquad (F.5)$$

相比贝叶斯预期，诊断性预期对信号的权重从$\omega$放大到$\omega(1+\theta)$。

#### F.1.3 预测误差的理论特征

**预测误差**：

$$FE_i = \pi_{t+1} - \mu_i^{DE}$$

代入(F.1)和(F.5)：

$$FE_i = \pi_{t+1} - [\omega(1+\theta) s_t + (1-\omega(1+\theta)) \pi^{prior}]$$

$$= \pi_{t+1} - \omega(1+\theta)(\pi_{t+1} + \eta_t) - (1-\omega(1+\theta))\pi^{prior}$$

$$= [1 - \omega(1+\theta)](\pi_{t+1} - \pi^{prior}) - \omega(1+\theta)\eta_t  \qquad (F.6)$$

**预期修正**：

从$t-1$到$t$，个体接收新信号$s_t$，修正预期为：

$$FR_i = \mu_i^{DE}(s_t) - \mu_i^{DE}(s_{t-1})$$

$$= \omega(1+\theta)(s_t - s_{t-1})  \qquad (F.7)$$

### F.2 从微观到宏观的聚合

#### F.2.1 个体异质性与总体预期

假设经济中有连续统个体$i \in [0,1]$，个体$i$观察到带异质性的信号：

$$s_{it} = \pi_{t+1} + \eta_{it}, \quad \eta_{it} \sim N(0, \sigma_\eta^2)$$

个体的诊断性参数也可能异质：$\theta_i \sim F_\theta$。

**总体预期**（聚合）：

$$\mu_t = \int_0^1 \mu_i^{DE} di$$

假设信号噪音$\eta_{it}$在个体间独立，则根据大数定律，噪音项聚合后消失：

$$\mu_t \approx \bar{\omega}(1+\bar{\theta})\pi_{t+1} + (1-\bar{\omega}(1+\bar{\theta}))\pi^{prior}  \qquad (F.8)$$

其中$\bar{\omega}, \bar{\theta}$为平均值。

#### F.2.2 总体预测误差与修正的关系

**总体预测误差**：

$$FE_t = \pi_{t+1} - \mu_t$$

代入(F.8)：

$$FE_t = [1 - \bar{\omega}(1+\bar{\theta})](\pi_{t+1} - \pi^{prior})  \qquad (F.9)$$

**总体预测修正**（从$t-1$到$t$）：

假设从$t-1$到$t$，实际通胀从$\pi_t$变化到$\pi_{t+1}$。总体预期修正近似为：

$$FR_t \approx \bar{\omega}(1+\bar{\theta})(\pi_{t+1} - \pi_t)  \qquad (F.10)$$

### F.3 预测误差的理论性质

#### F.3.1 理性预期基准：正交性

在理性预期下（$\theta = 0$），预测误差仅包含不可预测的噪音。形式化地：

$$E[FE_t | I_t] = 0  \qquad (F.11)$$

其中$I_t$为$t$期信息集。因此，$FE_t$与任何$t$期可获得的信息（包括$FR_t$）正交：

$$Cov(FE_t, FR_t) = 0 \quad \text{(理性预期)}  \qquad (F.12)$$

#### F.3.2 诊断性预期的偏离：系统性负相关

在诊断性预期下（$\theta > 0$），从(F.9)和(F.10)可得：

$$Cov(FE_t, FR_t) = Cov\left([1-\bar{\omega}(1+\bar{\theta})](\pi_{t+1} - \pi^{prior}), \bar{\omega}(1+\bar{\theta})(\pi_{t+1} - \pi_t)\right)$$

假设$\pi_t$与$\pi_{t+1}$独立（或弱相关），并且$Var(\pi_{t+1}) > 0$，则：

$$Cov(FE_t, FR_t) \approx -\bar{\omega}^2(1+\bar{\theta})^2 Var(\pi_{t+1}) < 0  \qquad (F.13)$$

**结论**：诊断性预期导致预测误差与预测修正系统性负相关。这正是我们在经验测量方程中检验的核心假说：

$$FE_t = \alpha + \beta FR_t + \varepsilon_t, \quad \beta < 0 \quad \text{(诊断性预期)}  \qquad (F.14)$$

其中$\beta$的理论值近似为：

$$\beta \approx -\frac{\bar{\omega}^2(1+\bar{\theta})^2 Var(\pi_{t+1})}{\bar{\omega}^2(1+\bar{\theta})^2 Var(\pi_{t+1} - \pi_t)}  \qquad (F.15)$$

在$\theta > 0$时，$\beta < 0$。$\theta$越大（诊断性越强），$|\beta|$越大（负相关越强）。

#### F.3.3 经验含义与识别策略

**含义1**：$\beta < 0$是诊断性预期的充要条件（在上述线性正态框架下）。

**含义2**：$\beta$的时变性可反映诊断性强度$\theta$的时变性。若某些时期$|\beta_t|$更大，提示该时期诊断性更强。

**含义3**：不确定性可能通过两个渠道影响$\beta$：
1. 降低$\bar{\omega}$（信号精度下降）——减小$|\beta|$
2. 提高$\bar{\theta}$（注意力集中于极端信号）——增大$|\beta|$

净效应取决于哪个渠道占主导，这正是我们在状态方程中检验的机制。

**结论**：诊断性预期理论不仅预测了$\beta < 0$这一定性特征，还提供了$\beta$数值大小和时变性的微观基础，为经验模型的结构化和解释提供了坚实的理论支撑。
