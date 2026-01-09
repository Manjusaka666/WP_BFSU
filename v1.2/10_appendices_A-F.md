# 附录

## 附录A：Carlson-Parkin定量化方法的技术细节

本附录详细说明Carlson-Parkin方法将问卷定性回答转化为定量通胀预期的步骤。

### A.1 基本假设与理论框架

假设个体对未来通胀$\pi_{t+1}$的主观分布为正态分布$N(\mu_t, \sigma_t^2)$，其中$\mu_t$为主观均值（即我们欲恢复的定量化预期），$\sigma_t^2$为主观方差。个体存在容忍带宽$[-\delta, +\delta]$，当预期通胀落在此区间内时个体回答"基本不变"，低于$-\delta$时回答"下降"，高于$+\delta$时回答"上升"。

设问卷中各选项的原始比例为：
- $p^{up}_{raw}$：选择"上升"的比例
- $p^{same}_{raw}$：选择"基本不变"的比例
- $p^{down}_{raw}$：选择"下降"的比例
- $p^{unsure}_{raw}$：选择"看不准"的比例

满足$p^{up}_{raw} + p^{same}_{raw} + p^{down}_{raw} + p^{unsure}_{raw} = 1$。

### A.2 归一化处理

由于"看不准"反映的是信心不足而非预期方向，我们将其剔除并对剩余三项重新归一化：

$$p^{up}_t = \frac{p^{up}_{raw}}{1 - p^{unsure}_{raw}}$$
$$p^{same}_t = \frac{p^{same}_{raw}}{1 - p^{unsure}_{raw}}$$
$$p^{down}_t = \frac{p^{down}_{raw}}{1 - p^{unsure}_{raw}}$$

满足$p^{up}_t + p^{same}_t + p^{down}_t = 1$。

### A.3 分位数反推

根据正态分布的性质，选择"下降"的比例对应主观分布左尾面积：
$$p^{down}_t = \Phi\left(\frac{-\delta - \mu_t}{\sigma_t}\right)$$

选择"上升"的比例对应主观分布右尾面积：
$$p^{up}_t = 1 - \Phi\left(\frac{+\delta - \mu_t}{\sigma_t}\right)$$

其中$\Phi(\cdot)$为标准正态分布的累积分布函数。

定义标准化分位数：
$$z_d = \Phi^{-1}(p^{down}_t), \quad z_u = \Phi^{-1}(1 - p^{up}_t)$$

则有：
$$z_d = \frac{-\delta - \mu_t}{\sigma_t}$$
$$z_u = \frac{+\delta - \mu_t}{\sigma_t}$$

### A.4 求解主观均值与方差

从上述两式可得：
$$-\delta - \mu_t = \sigma_t \cdot z_d  \quad (A.1)$$
$$+\delta - \mu_t = \sigma_t \cdot z_u  \quad (A.2)$$

将(A.1)式减去(A.2)式：
$$-2\delta = \sigma_t(z_d - z_u)$$

解得主观标准差：
$$\sigma_t = \frac{-2\delta}{z_d - z_u} = \frac{2\delta}{z_u - z_d}  \quad (A.3)$$

注意$z_d < 0 < z_u$（因为$p^{down}_t < 0.5 < 1-p^{up}_t$在大多数情况下成立），故$z_u - z_d > 0$，$\sigma_t > 0$。

将(A.3)代入(A.2)：
$$\mu_t = +\delta - \sigma_t \cdot z_u = +\delta - \frac{2\delta}{z_u - z_d} \cdot z_u  \quad (A.4)$$

或代入(A.1)：
$$\mu_t = -\delta - \sigma_t \cdot z_d = -\delta - \frac{2\delta}{z_u - z_d} \cdot z_d  \quad (A.5)$$

两式应一致，可用于验证计算正确性。

### A.5 实际操作参数选择

**容忍带宽$\delta$的选择**：我们设定$\delta = 0.5$个百分点。这一选择基于：
1. 中国CPI季度同比波动通常在±2个百分点以内
2. 居民对于±0.5个百分点以内的变化可能视为"基本不变"
3. 敏感性分析显示，$\delta \in [0.3, 0.7]$范围内结果稳健

**基准通胀率的调整**：为使定量化预期与当期宏观环境一致，我们以当期CPI同比$\pi_t$作为基准，最终定量化预期为：
$$\mu_t^{final} = \pi_t + \mu_t  \quad (A.6)$$

其中$\mu_t$为由(A.4)或(A.5)计算得到的相对预期变化。

### A.6 数据覆盖情况与缺失模式

CP预期在48个季度可得（2013Q1–2025Q3）。缺失季度为：
- 2011Q1-Q4（初期数据不完整）
- 2012Q1-Q2, 2012Q4（分项占比未公布）
- 2013Q2（统计口径调整）
- 2015Q1（数据发布异常）
- 2020Q4（疫情期间调查中断）

缺失机制分析表明，缺失主要由于数据发布格式变化，与预期变量本身无关，可视为随机缺失(Missing Completely At Random, MCAR)。

---

## 附录B：TVP-SSM模型的MCMC算法细节

本附录提供贝叶斯状态空间模型Gibbs抽样算法的完整实施细节。

### B.1 模型设定回顾

**测量方程**：
$$FE_t = \alpha + \beta_t FR_t + \gamma' Z_t + \varepsilon_t, \quad \varepsilon_t \sim N(0, R)$$

**状态方程**：
$$\beta_t = \beta_{t-1} + d' X_t + u_t, \quad u_t \sim N(0, Q)$$

参数空间：$\Theta = (\alpha, \gamma, \beta_{1:T}, d, R, Q)$。

### B.2 Gibbs抽样算法

**初始化**（$m=0$）：
- $\alpha^{(0)} = 0$
- $\gamma^{(0)}$ = OLS估计值
- $\beta_t^{(0)} = -0.5$ for all $t$
- $d^{(0)} = \mathbf{0}$
- $R^{(0)}$ = 样本残差方差
- $Q^{(0)} = 0.1$

**迭代**（$m = 1, \ldots, M$）：

**步骤1：抽取测量方程参数$(\alpha, \gamma)$**

给定$\beta_{1:T}^{(m-1)}$, $R^{(m-1)}$和数据$y = (FE_1, \ldots, FE_T)'$，定义调整后因变量：
$$\tilde{y}_t = FE_t - \beta_t^{(m-1)} FR_t$$

堆叠形式：
$$\tilde{y} = Z \psi + \varepsilon, \quad \varepsilon \sim N(0, R^{(m-1)} I_T)$$

其中$\psi = (\alpha, \gamma')'$，$Z = [1, Z_1'; \ldots; 1, Z_T']$。

**先验**：$\psi \sim N(\psi_0, \Sigma_0)$，我们设定$\psi_0 = \mathbf{0}$，$\Sigma_0 = 10 \cdot I$。

**后验**：
$$\psi^{(m)} | \cdot \sim N(\psi_T, \Sigma_T)$$

其中：
$$\Sigma_T^{-1} = \Sigma_0^{-1} + \frac{1}{R^{(m-1)}} Z' Z  \quad (B.1)$$
$$\psi_T = \Sigma_T \left( \Sigma_0^{-1} \psi_0 + \frac{1}{R^{(m-1)}} Z' \tilde{y} \right)  \quad (B.2)$$

从$N(\psi_T, \Sigma_T)$抽取$\psi^{(m)}$。

**步骤2：抽取状态路径$\beta_{1:T}$（FFBS算法）**

给定$(\alpha^{(m)}, \gamma^{(m)}, d^{(m-1)}, R^{(m)}, Q^{(m-1)})$。

**2a. Forward Filtering（前向Kalman滤波）**

初始化（$t=0$）：
$$\beta_0 | y_0 \sim N(m_0, C_0)$$
设定$m_0 = -0.5$, $C_0 = 1$。

递推（$t = 1, \ldots, T$）：

**预测步**：
$$a_t = m_{t-1} + d'^{(m-1)} X_t  \quad (B.3)$$
$$R_t = C_{t-1} + Q^{(m-1)}  \quad (B.4)$$

即$\beta_t | y_{1:t-1} \sim N(a_t, R_t)$。

**更新步**：

观测预测误差：
$$f_t = FE_t - \alpha^{(m)} - a_t FR_t - \gamma'^{(m)} Z_t  \quad (B.5)$$

预测误差方差：
$$Q_t = FR_t^2 \cdot R_t + R^{(m)}  \quad (B.6)$$

Kalman增益：
$$K_t = \frac{R_t \cdot FR_t}{Q_t}  \quad (B.7)$$

滤波分布：
$$m_t = a_t + K_t f_t  \quad (B.8)$$
$$C_t = R_t - K_t^2 Q_t  \quad (B.9)$$

即$\beta_t | y_{1:t} \sim N(m_t, C_t)$。

**2b. Backward Sampling（后向抽样）**

初始化（$t=T$）：
$$\beta_T^{(m)} \sim N(m_T, C_T)  \quad (B.10)$$

递推（$t = T-1, \ldots, 1$）：

条件分布均值：
$$h_t = m_t + \frac{C_t}{R_{t+1}}(\beta_{t+1}^{(m)} - a_{t+1})  \quad (B.11)$$

条件分布方差：
$$H_t = C_t - \frac{C_t^2}{R_{t+1}}  \quad (B.12)$$

抽样：
$$\beta_t^{(m)} \sim N(h_t, H_t)  \quad (B.13)$$

得到完整状态路径$\beta_{1:T}^{(m)}$。

**步骤3：抽取状态方程参数$d$**

给定$\beta_{1:T}^{(m)}$, $Q^{(m-1)}$，定义状态增量：
$$\Delta\beta_t = \beta_t^{(m)} - \beta_{t-1}^{(m)}, \quad t=1,\ldots,T$$

回归模型：
$$\Delta\beta = W d + u, \quad u \sim N(0, Q^{(m-1)} I_T)$$

其中$\Delta\beta = (\Delta\beta_1, \ldots, \Delta\beta_T)'$，$W = (X_1', \ldots, X_T')'$。

**先验**：$d \sim N(d_0, \Lambda_0)$，设定$d_0 = \mathbf{0}$，$\Lambda_0 = I$。

**后验**：
$$d^{(m)} | \cdot \sim N(d_T, \Lambda_T)$$

其中：
$$\Lambda_T^{-1} = \Lambda_0^{-1} + \frac{1}{Q^{(m-1)}} W' W  \quad (B.14)$$
$$d_T = \Lambda_T \left( \Lambda_0^{-1} d_0 + \frac{1}{Q^{(m-1)}} W' \Delta\beta \right)  \quad (B.15)$$

从$N(d_T, \Lambda_T)$抽取$d^{(m)}$。

**步骤4：抽取测量误差方差$R$**

给定$(\alpha^{(m)}, \gamma^{(m)}, \beta_{1:T}^{(m)})$，计算残差：
$$e_t = FE_t - \alpha^{(m)} - \beta_t^{(m)} FR_t - \gamma'^{(m)} Z_t$$

残差平方和：
$$SSR_e = \sum_{t=1}^T e_t^2  \quad (B.16)$$

**先验**：$R \sim IG(a_R, b_R)$，设定$a_R = 3$, $b_R = 2 \times s_e^2$（$s_e^2$为初始OLS残差方差）。

**后验**：
$$R^{(m)} | \cdot \sim IG\left(a_R + \frac{T}{2}, b_R + \frac{SSR_e}{2}\right)  \quad (B.17)$$

从逆伽玛分布抽取$R^{(m)}$。

**步骤5：抽取状态扰动方差$Q$**

给定$(\beta_{1:T}^{(m)}, d^{(m)})$，计算状态方程残差：
$$v_t = \Delta\beta_t - d'^{(m)} X_t$$

残差平方和：
$$SSR_v = \sum_{t=1}^T v_t^2  \quad (B.18)$$

**先验**：$Q \sim IG(a_Q, b_Q)$，设定$a_Q = 3$, $b_Q = 2 \times 1.0$。

**后验**：
$$Q^{(m)} | \cdot \sim IG\left(a_Q + \frac{T}{2}, b_Q + \frac{SSR_v}{2}\right)  \quad (B.19)$$

从逆伽玛分布抽取$Q^{(m)}$。

### B.3 MCMC实施参数

- **总迭代次数**：$M = 20000$
- **烧入期**（Burn-in）：前5000次
- **thinning**：每隔10次保留一个样本
- **有效样本量**：$(20000 - 5000)/10 = 1500$次

### B.4 收敛性诊断

**Geweke统计量**：

对每个参数$\theta$，比较前10%样本均值$\bar{\theta}_A$与后50%样本均值$\bar{\theta}_B$：
$$z_{\theta} = \frac{\bar{\theta}_A - \bar{\theta}_B}{\sqrt{Var(\bar{\theta}_A) + Var(\bar{\theta}_B)}}  \quad (B.20)$$

其中方差通过谱密度估计（考虑自相关）。在零假设（已收敛）下，$z_{\theta} \sim N(0,1)$。判据：$|z_{\theta}| < 1.96$。

**有效样本量**：

无效因子：
$$IF = 1 + 2\sum_{k=1}^K \rho_k  \quad (B.21)$$

其中$\rho_k$为滞后$k$阶自相关系数，累加至$\rho_k < 0.05$。

有效样本量：
$$ESS = \frac{S}{IF}  \quad (B.22)$$

判据：$ESS > 400$。

**Gelman-Rubin统计量**：

运行$M=3$条独立链（不同初值），计算：

链内方差：
$$W = \frac{1}{M}\sum_{j=1}^M s_j^2  \quad (B.23)$$

链间方差：
$$B = \frac{S}{M-1}\sum_{j=1}^M (\bar{\theta}_j - \bar{\bar{\theta}})^2  \quad (B.24)$$

潜在尺度缩减因子：
$$\hat{R} = \sqrt{\frac{\hat{Var}(\theta)}{W}}, \quad \hat{Var}(\theta) = \frac{S-1}{S}W + \frac{1}{S}B  \quad (B.25)$$

判据：$\hat{R} < 1.05$。

---

## 附录C：BVAR符号约束的旋转算法

本附录详细说明符号约束识别中的随机正交旋转算法及其测度理论基础。

### C.1 降阶型到结构型的映射

**降阶型**：
$$y_t = c + B_1 y_{t-1} + \cdots + B_p y_{t-p} + e_t, \quad e_t \sim N(0, \Omega)$$

**结构型**：
$$A_0 y_t = A_c + A_1 y_{t-1} + \cdots + A_p y_{t-p} + \varepsilon_t, \quad \varepsilon_t \sim N(0, \Sigma)$$

其中$\Sigma = diag(\sigma_1^2, \ldots, \sigma_k^2)$。

**关系**：
$$e_t = A_0^{-1} \varepsilon_t$$
$$\Omega = A_0^{-1} \Sigma (A_0^{-1})'  \quad (C.1)$$

### C.2 识别问题与Cholesky分解

给定$\Omega$（$k \times k$对称矩阵，$k(k+1)/2$个自由度），需恢复$(A_0^{-1}, \Sigma)$（$k^2 + k$个未知数）。

自由度差：$k^2 + k - k(k+1)/2 = k(k-1)/2$，需要额外约束。

**Cholesky分解**：
$$\Omega = PP', \quad P \text{ 下三角}  \quad (C.2)$$

$P$的每一列可解释为一个结构冲击。

### C.3 正交旋转与Haar测度

任意正交矩阵$Q \in O(k)$（满足$QQ'=I_k$）可生成另一组结构冲击：
$$\tilde{P} = PQ  \quad (C.3)$$

且$\tilde{P}\tilde{P}' = PQQ'P' = PP' = \Omega$。

**正交群**：$O(k) = \{Q \in \mathbb{R}^{k \times k} : QQ' = I_k\}$是紧致李群。

**Haar测度**：$O(k)$上存在唯一的左右不变概率测度$\mu$，称为Haar测度，满足：
$$\mu(Q_0 A) = \mu(A Q_0) = \mu(A), \quad \forall Q_0 \in O(k), A \subset O(k)  \quad (C.4)$$

这是$O(k)$上"均匀分布"的自然定义。

### C.4 QR分解法生成均匀随机正交矩阵

**算法**（Stewart, 1980）：

1. 从$N(0,1)$独立抽取$k^2$个随机数，构成矩阵$M \in \mathbb{R}^{k \times k}$

2. 对$M$进行QR分解：$M = QR$，其中$Q$正交，$R$上三角

3. 标准化：令$D = diag(sign(R_{11}), \ldots, sign(R_{kk}))$，设置：
   $$Q \leftarrow QD, \quad R \leftarrow DR  \quad (C.5)$$
   以保证$R$对角元为正

4. 输出$Q$

**定理**（Stewart, 1980）：上述算法生成的$Q$在Haar测度下均匀分布于$O(k)$。

**证明概要**：
- 标准正态向量的联合分布在正交变换下不变
- QR分解的唯一性（在符号标准化后）保证$Q$的分布不依赖于$M$的特定实现
- 通过不变性原理，$Q$的分布必为Haar测度$\square$

### C.5 符号约束检验算法

对于每次后验抽样$(B_{1:p}, \Omega)$：

1. **Cholesky分解**：$\Omega = PP'$

2. **旋转循环**：For $i = 1$ to $N_{rot}$ (设$N_{rot}=200$):
   
   a) 生成随机正交矩阵$Q_i$（QR分解法，算法C.4）
   
   b) 计算旋转后冲击矩阵：$\tilde{P}_i = P Q_i$
   
   c) 对$\tilde{P}_i$的第$j$列（代表一个结构冲击），计算IRF
   
   d) 检验该冲击的IRF是否满足所有符号约束：
      - 约束1：$IRF_{\mu}(0) > 0$
      - 约束2：$IRF_{\pi}(h+1) - IRF_{\mu}(h) < 0$ for $h=0,1,2,3$
   
   e) 若满足，标记该旋转为"接受"，保存对应的IRF和FEVD

3. **接受判定**：若200次旋转中至少有一次满足约束，则该后验抽样被接受

4. **汇总**：重复2000次后验抽样，汇总所有接受的IRF形成后验推断

### C.6 脉冲响应函数的计算

给定VAR系数$B_{1:p}$和结构冲击矩阵$A_0^{-1} = PQ$，变量$y$对冲击$\varepsilon_j$在期数$h$的IRF为：
$$IRF_{yj}(h) = \frac{\partial y_{t+h}}{\partial \varepsilon_{jt}}  \quad (C.6)$$

**递推公式**：

定义伴随矩阵：
$$A = \begin{bmatrix} B_1 & B_2 & \cdots & B_{p-1} & B_p \\ I_k & 0 & \cdots & 0 & 0 \\ 0 & I_k & \cdots & 0 & 0 \\ \vdots & \vdots & \ddots & \vdots & \vdots \\ 0 & 0 & \cdots & I_k & 0 \end{bmatrix}_{kp \times kp}  \quad (C.7)$$

增广状态向量$Y_t = (y_t', y_{t-1}', \ldots, y_{t-p+1}')'$，则：
$$Y_t = c^* + A Y_{t-1} + e_t^*  \quad (C.8)$$

其中$e_t^* = (e_t', 0', \ldots, 0')'$。

冲击$\varepsilon_j$对$Y_{t+h}$的影响：
$$\frac{\partial Y_{t+h}}{\partial \varepsilon_{jt}} = A^h \cdot (A_0^{-1} e_j)  \quad (C.9)$$

提取前$k$个元素得$IRF_{yj}(h)$。

### C.7 计算优化技巧

- **矩阵预计算**：预先计算$A^0, A^1, \ldots, A^H$，避免重复幂运算
- **并行化**：200次旋转可并行处理
- **早停策略**：若前50次旋转已找到10个满足约束的冲击，停止该后验抽样的后续旋转
- **稀疏存储**：仅存储满足约束的IRF，节省内存

---

## 附录D：TVP-SSM条件后验分布的详细推导

本附录提供TVP-SSM模型所有条件后验分布的完整数学推导。

### D.1 固定参数$(\gamma, \alpha)$的条件后验

给定状态路径$\beta_{1:T}$和方差$R$，测量方程为：
$$FE_t = \alpha + \beta_t FR_t + \gamma' Z_t + \varepsilon_t  \quad (D.1)$$

定义$\tilde{FE}_t = FE_t - \beta_t FR_t$，则：
$$\tilde{FE}_t = \alpha + \gamma' Z_t + \varepsilon_t  \quad (D.2)$$

堆叠所有$t=1,\ldots,T$：
$$\tilde{y} = \tilde{Z} \psi + \varepsilon, \quad \varepsilon \sim N(0, R I_T)  \quad (D.3)$$

其中$\psi = (\alpha, \gamma')'$，$\tilde{Z} = [1, Z_1'; \ldots; 1, Z_T']'_{T \times (k+1)}$。

**先验**：$\psi \sim N(\psi_0, \Sigma_0)$

**似然**：
$$p(\tilde{y} | \psi, R) = (2\pi R)^{-T/2} \exp\left\{-\frac{1}{2R}(\tilde{y} - \tilde{Z}\psi)'(\tilde{y} - \tilde{Z}\psi)\right\}  \quad (D.4)$$

**后验**（利用正态共轭性）：
$$\psi | \tilde{y}, \beta_{1:T}, R \sim N(\psi_T, \Sigma_T)  \quad (D.5)$$

精度矩阵：
$$\Sigma_T^{-1} = \Sigma_0^{-1} + \frac{1}{R} \tilde{Z}' \tilde{Z}  \quad (D.6)$$

后验均值：
$$\psi_T = \Sigma_T \left( \Sigma_0^{-1} \psi_0 + \frac{1}{R} \tilde{Z}' \tilde{y} \right)  \quad (D.7)$$

**推导细节**：

后验核为：
$$p(\psi | \tilde{y}) \propto \exp\left\{-\frac{1}{2}[(\psi-\psi_0)'\Sigma_0^{-1}(\psi-\psi_0) + \frac{1}{R}(\tilde{y}-\tilde{Z}\psi)'(\tilde{y}-\tilde{Z}\psi)]\right\}$$

展开二次型：
$$= \exp\left\{-\frac{1}{2}[\psi'(\Sigma_0^{-1} + \frac{1}{R}\tilde{Z}'\tilde{Z})\psi - 2\psi'(\Sigma_0^{-1}\psi_0 + \frac{1}{R}\tilde{Z}'\tilde{y}) + const]\right\}$$

配方得$N(\psi_T, \Sigma_T)$，其中$\Sigma_T^{-1} = \Sigma_0^{-1} + \frac{1}{R}\tilde{Z}'\tilde{Z}$。$\square$

### D.2 驱动变量系数$d$的条件后验

给定$\beta_{1:T}$和$Q$，状态方程为：
$$\beta_t = \beta_{t-1} + d' X_t + u_t  \quad (D.8)$$

定义$\Delta\beta_t = \beta_t - \beta_{t-1}$，堆叠：
$$\Delta\beta = W d + u, \quad u \sim N(0, Q I_T)  \quad (D.9)$$

其中$W = [X_1', \ldots, X_T']'_{T \times k_x}$。

**先验**：$d \sim N(d_0, \Lambda_0)$

**后验**：
$$d | \beta_{1:T}, Q \sim N(d_T, \Lambda_T)  \quad (D.10)$$

其中：
$$\Lambda_T^{-1} = \Lambda_0^{-1} + \frac{1}{Q} W' W  \quad (D.11)$$
$$d_T = \Lambda_T \left( \Lambda_0^{-1} d_0 + \frac{1}{Q} W' \Delta\beta \right)  \quad (D.12)$$

推导同D.1，利用正态共轭性。$\square$

### D.3 方差参数的条件后验

**测量误差方差$R$**：

给定$(\alpha, \gamma, \beta_{1:T})$，残差：
$$e_t = FE_t - \alpha - \beta_t FR_t - \gamma' Z_t  \quad (D.13)$$

**先验**：$R \sim IG(a_R, b_R)$，密度：
$$p(R) \propto R^{-(a_R+1)} \exp\{-b_R/R\}  \quad (D.14)$$

**似然**：
$$p(FE | R, \cdot) = (2\pi R)^{-T/2} \exp\left\{-\frac{1}{2R}\sum_t e_t^2\right\}  \quad (D.15)$$

**后验**：
$$p(R | \cdot) \propto R^{-(a_R + T/2 + 1)} \exp\left\{-\frac{b_R + SSR_e/2}{R}\right\}  \quad (D.16)$$

其中$SSR_e = \sum_t e_t^2$。这是$IG(a_R + T/2, b_R + SSR_e/2)$的核。$\square$

**状态扰动方差$Q$**：

给定$(\beta_{1:T}, d)$，残差：
$$v_t = \beta_t - \beta_{t-1} - d' X_t  \quad (D.17)$$

同理推导，后验为：
$$Q | \cdot \sim IG(a_Q + T/2, b_Q + SSR_v/2)  \quad (D.18)$$

其中$SSR_v = \sum_t v_t^2$。$\square$

### D.4 状态变量的条件后验：FFBS算法理论

**目标**：从$p(\beta_{1:T} | y_{1:T}, \theta)$抽样，其中$\theta = (\alpha, \gamma, d, R, Q)$。

**分解**：
$$p(\beta_{1:T} | y_{1:T}) = p(\beta_T | y_{1:T}) \prod_{t=1}^{T-1} p(\beta_t | \beta_{t+1}, y_{1:t})  \quad (D.19)$$

**Forward Filtering**提供$p(\beta_t | y_{1:t})$，**Backward Sampling**利用(D.19)递推抽样。

#### D.4.1 Kalman滤波递推

**预测**（$t-1 \to t$）：

由状态方程和$\beta_{t-1} | y_{1:t-1} \sim N(m_{t-1}, C_{t-1})$：
$$\beta_t | y_{1:t-1} \sim N(a_t, R_t)  \quad (D.20)$$

其中：
$$a_t = E[\beta_t | y_{1:t-1}] = E[\beta_{t-1} + d'X_t + u_t | y_{1:t-1}] = m_{t-1} + d'X_t  \quad (D.21)$$
$$R_t = Var[\beta_t | y_{1:t-1}] = Var[\beta_{t-1} | y_{1:t-1}] + Q = C_{t-1} + Q  \quad (D.22)$$

**更新**（观测$y_t = FE_t$后）：

联合分布：
$$\begin{pmatrix} \beta_t \\ y_t \end{pmatrix} \Bigg| y_{1:t-1} \sim N\left(\begin{pmatrix} a_t \\ \alpha + a_t FR_t + \gamma'Z_t \end{pmatrix}, \begin{pmatrix} R_t & R_t FR_t \\ R_t FR_t & FR_t^2 R_t + R \end{pmatrix}\right)  \quad (D.23)$$

预测误差：
$$f_t = y_t - E[y_t | y_{1:t-1}] = y_t - \alpha - a_t FR_t - \gamma'Z_t  \quad (D.24)$$

预测误差方差：
$$Q_t = Var[y_t | y_{1:t-1}] = FR_t^2 R_t + R  \quad (D.25)$$

条件分布（正态条件性质）：
$$\beta_t | y_{1:t} \sim N(m_t, C_t)  \quad (D.26)$$

其中：
$$m_t = a_t + \frac{Cov(\beta_t, y_t | y_{1:t-1})}{Var(y_t | y_{1:t-1})} f_t = a_t + \frac{R_t FR_t}{Q_t} f_t  \quad (D.27)$$

定义Kalman增益$K_t = \frac{R_t FR_t}{Q_t}$，则：
$$m_t = a_t + K_t f_t  \quad (D.28)$$

条件方差：
$$C_t = R_t - \frac{(R_t FR_t)^2}{Q_t} = R_t - K_t^2 Q_t  \quad (D.29)$$

#### D.4.2 后向抽样的条件分布推导

给定$\beta_{t+1}$和$y_{1:t}$，需要$p(\beta_t | \beta_{t+1}, y_{1:t})$。

由状态方程，联合分布：
$$\begin{pmatrix} \beta_t \\ \beta_{t+1} \end{pmatrix} \Bigg| y_{1:t} \sim N\left(\begin{pmatrix} m_t \\ a_{t+1} \end{pmatrix}, \begin{pmatrix} C_t & C_t \\ C_t & R_{t+1} \end{pmatrix}\right)  \quad (D.30)$$

其中$Cov(\beta_t, \beta_{t+1} | y_{1:t}) = C_t$（因为$\beta_{t+1} = \beta_t + d'X_{t+1} + u_{t+1}$，而$u_{t+1} \perp y_{1:t}, \beta_t$）。

条件分布：
$$\beta_t | \beta_{t+1}, y_{1:t} \sim N(h_t, H_t)  \quad (D.31)$$

其中：
$$h_t = m_t + \frac{C_t}{R_{t+1}}(\beta_{t+1} - a_{t+1})  \quad (D.32)$$
$$H_t = C_t - \frac{C_t^2}{R_{t+1}}  \quad (D.33)$$

这正是附录B中(B.11)-(B.12)式。$\square$

---

## 附录E：BVAR识别的测度理论基础

本附录提供符号约束识别的严格测度理论基础。

### E.1 正交群的拓扑与测度

**定义**：正交群$O(k) = \{Q \in \mathbb{R}^{k \times k} : QQ' = I_k\}$。

**拓扑性质**：
1. $O(k)$是$\mathbb{R}^{k \times k}$的闭子集（因为$QQ'=I$是闭条件）
2. $O(k)$是有界的（$||Q||_F = \sqrt{k}$）
3. 由Heine-Borel定理，$O(k)$是紧致的

**群结构**：
- 单位元：$I_k$
- 逆元：$Q^{-1} = Q'$
- 群运算：矩阵乘法

$O(k)$是李群（拓扑群且局部同胚于欧氏空间）。

### E.2 Haar测度的存在性与唯一性

**定理**（Haar, 1933）：设$G$为局部紧致拓扑群，则$G$上存在（在乘法常数意义下）唯一的左不变Radon测度$\mu$，即：
$$\mu(gA) = \mu(A), \quad \forall g \in G, A \text{ Borel可测}  \quad (E.1)$$

对于紧致群，左不变测度也是右不变测度，可归一化为概率测度。

**推论**：$O(k)$是紧致李群，存在唯一的归一化Haar测度$\mu$满足$\mu(O(k)) = 1$。

### E.3 QR分解法的数学证明

**定理**（Stewart, 1980）：设$M \in \mathbb{R}^{k \times k}$的每个元素独立同分布于$N(0,1)$。对$M$进行QR分解得$M = QR$（$Q$正交，$R$上三角且对角元为正），则$Q$在Haar测度下均匀分布于$O(k)$。

**证明**：

步骤1：$M$的分布在正交变换下不变。

对任意固定的$Q_0 \in O(k)$，$\tilde{M} = Q_0 M$的每个元素仍为i.i.d. $N(0,1)$（因正态联合分布在正交变换下不变）。故$M$与$Q_0 M$同分布。

步骤2：QR分解的唯一性（在符号标准化后）。

给定任意非奇异矩阵$M$，QR分解$M = QR$在要求$R$对角元为正的条件下是唯一的。

步骤3：不变性传递。

设$M = Q_1 R_1$为$M$的QR分解，设$Q_0 M = Q_2 R_2$为$Q_0 M$的QR分解。

由$Q_0 M = Q_0 Q_1 R_1 = Q_2 R_2$，而$Q_0 Q_1$正交，故$Q_2 = Q_0 Q_1$（在符号标准化下）。

由步骤1，$Q_1$与$Q_2 = Q_0 Q_1$同分布，即$Q_1$的分布在左乘$Q_0$下不变。对所有$Q_0 \in O(k)$成立。

步骤4：由左不变性的唯一性，$Q_1$的分布必为Haar测度。$\square$

### E.4 部分识别与识别集

**定义**：符号约束集合$\mathcal{C} = \{(v, h, s) : s \cdot IRF_v(Q, h, j) > 0\}$，其中$s \in \{+1, -1\}$。

**识别集**：
$$\mathcal{Q}_{identified} = \{Q \in O(k) : \text{第}j\text{列满足所有}(v,h,s) \in \mathcal{C}\}  \quad (E.2)$$

**Lebesgue测度**（在Haar测度意义下）：
$$\mu(\mathcal{Q}_{identified}) = \int_{\mathcal{Q}_{identified}} d\mu(Q)  \quad (E.3)$$

**Monte Carlo估计**：
$$\hat{\mu}(\mathcal{Q}_{identified}) = \frac{1}{N}\sum_{i=1}^N \mathbb{1}\{Q_i \in \mathcal{Q}_{identified}\}  \quad (E.4)$$

其中$Q_i \sim Haar(O(k))$独立抽取。

**本研究结果**：$\hat{\mu}(\mathcal{Q}_{identified}) \approx 0.008$（平均每次后验抽样约1.59/200次旋转满足约束），表明识别集相对"小"，识别相对"紧致"。

---

## 附录F：诊断性预期的微观基础

本附录提供从个体诊断性行为到总体预测误差的完整理论推导。

### F.1 代表性启发的形式化

**标准贝叶斯更新**：

个体观察信号$s_t$，先验$\pi_{t+1} \sim N(\pi^{prior}, \sigma_\pi^2)$，信号$s_t = \pi_{t+1} + \eta_t$，$\eta_t \sim N(0, \sigma_\eta^2)$。

后验均值：
$$\mu^{Bay} = \omega s_t + (1-\omega) \pi^{prior}  \quad (F.1)$$

其中精度权重$\omega = \frac{\sigma_\pi^2}{\sigma_\pi^2 + \sigma_\eta^2}$。

**诊断性预期**（Bordalo et al., 2018）：

代表性通过"诊断比率"衡量：
$$\kappa(s|\theta) = \frac{p(s|\theta)}{p(s)}  \quad (F.2)$$

诊断性主观概率：
$$p^{DE}(s|\theta) \propto p(s|\theta)^{1+\theta} \cdot p(s)^{-\theta}  \quad (F.3)$$

在线性正态设定下（见Bordalo et al., 2018 Appendix）：
$$\mu^{DE} = \omega(1+\theta) s_t + (1-\omega(1+\theta)) \pi^{prior}  \quad (F.4)$$

### F.2 预测误差的理论推导

**个体预测误差**：
$$FE_i = \pi_{t+1} - \mu_i^{DE}$$

代入$s_t = \pi_{t+1} + \eta_t$和(F.4)：
$$FE_i = \pi_{t+1} - [\omega(1+\theta)(\ + \eta_t) + (1-\omega(1+\theta))\pi^{prior}]$$

$$= [1 - \omega(1+\theta)](\pi_{t+1} - \pi^{prior}) - \omega(1+\theta)\eta_t  \quad (F.5)$$

**个体预测修正**：
$$FR_i = \mu_i^{DE}(s_t) - \mu_i^{DE}(s_{t-1})$$

$$= \omega(1+\theta)(s_t - s_{t-1})  \quad (F.6)$$

### F.3 从个体到总体的聚合

假设连续统个体$i \in [0,1]$，信号$s_{it} = \pi_{t+1} + \eta_{it}$，$\eta_{it} \sim N(0, \sigma_\eta^2)$独立。

**总体预期**：
$$\mu_t = \int_0^1 \mu_i^{DE} di = \omega(1+\theta) \int_0^1 s_{it} di + (1-\omega(1+\theta))\pi^{prior}$$

由大数定律，$\int_0^1 s_{it} di \to \pi_{t+1}$（噪音对消）：
$$\mu_t \approx \omega(1+\theta)\pi_{t+1} + (1-\omega(1+\theta))\pi^{prior}  \quad (F.7)$$

**总体预测误差**：
$$FE_t = \pi_{t+1} - \mu_t = [1 - \omega(1+\theta)](\pi_{t+1} - \pi^{prior})  \quad (F.8)$$

**总体预测修正**（简化假设下）：

若$\pi_t$服从AR(1)：$\pi_{t+1} = \rho \pi_t + \epsilon_{t+1}$，则：
$$FR_t \approx \omega(1+\theta)(\pi_{t+1} - \pi_t)  \quad (F.9)$$

### F.4 协方差与回归系数

假设$\pi_{t+1}$与$\pi_t$的相关性足够弱（或为白噪声），则：

$$Cov(FE_t, FR_t) = Cov([1-\omega(1+\theta)](\pi_{t+1} - \pi^{prior}), \omega(1+\theta)(\pi_{t+1} - \pi_t))$$

$$\approx -\omega^2(1+\theta)^2 Var(\pi_{t+1})  \quad (F.10)$$

（因为$\pi_{t+1}$与$-\pi_t$近似正交）

故$Cov(FE_t, FR_t) < 0$当$\theta > 0$。

**回归系数**：
$$\beta = \frac{Cov(FE_t, FR_t)}{Var(FR_t)} \approx \frac{-\omega^2(1+\theta)^2 Var(\pi_{t+1})}{\omega^2(1+\theta)^2 Var(\pi_{t+1} - \pi_t)}  \quad (F.11)$$

简化得：
$$\beta \approx -\frac{Var(\pi_{t+1})}{Var(\pi_{t+1} - \pi_t)} < 0  \quad (F.12)$$

**结论**：
1. $\theta > 0$ $\Rightarrow$ $\beta < 0$（诊断性预期的充分条件）
2. $|\beta|$随$\theta$增大而增大
3. 不确定性通过影响$\omega$和$\theta$间接影响$|\beta|$

---

**附录完**
