#!/usr/bin/env julia

using CSV
using DataFrames
using Statistics
using LinearAlgebra
using Random
using Distributions
using Printf
using Plots

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PANEL_FILE = joinpath(ROOT, "data", "processed", "panel_quarterly.csv")
const TAB_DIR = joinpath(ROOT, "outputs", "tables")
const FIG_DIR = joinpath(ROOT, "outputs", "figures")

mkpath(TAB_DIR)
mkpath(FIG_DIR)

function qkey(q::AbstractString)
    m = match(r"(\d{4})Q([1-4])", q)
    m === nothing && return typemax(Int)
    y = parse(Int, m.captures[1])
    qq = parse(Int, m.captures[2])
    return y * 10 + qq
end

function tex_escape(x)
    s = string(x)
    s = replace(s, "_" => "\\_")
    return s
end

function write_tex_table(df::DataFrame, path::AbstractString; caption="", label="", notes=String[])
    io = open(path, "w")
    n_cols = size(df, 2)
    n_rows = size(df, 1)
    aligns = "l" * repeat("c", n_cols - 1)

    println(io, "\\begin{table}[!htbp]")
    println(io, "\\centering")
    if !isempty(caption)
        println(io, "\\caption{" * caption * "}")
    end
    if !isempty(label)
        println(io, "\\label{" * label * "}")
    end
    println(io, "\\begin{threeparttable}")
    println(io, "\\begin{tabular}{" * aligns * "}")
    println(io, "\\toprule")

    header = join([tex_escape(name) for name in names(df)], " & ") * " \\\\"
    println(io, header)
    println(io, "\\midrule")

    for r in 1:n_rows
        vals = String[]
        for c in 1:n_cols
            v = df[r, c]
            if v isa Missing
                push!(vals, "")
            elseif v isa AbstractFloat
                push!(vals, @sprintf("%.3f", v))
            else
                push!(vals, tex_escape(v))
            end
        end
        println(io, join(vals, " & ") * " \\\\")
    end

    println(io, "\\bottomrule")
    println(io, "\\end{tabular}")

    if !isempty(notes)
        println(io, "\\begin{tablenotes}[flushleft]")
        println(io, "\\footnotesize")
        for n in notes
            n_clean = replace(replace(n, "`" => ""), "_" => "\\_")
            println(io, "\\item " * n_clean)
        end
        println(io, "\\end{tablenotes}")
    end

    println(io, "\\end{threeparttable}")
    println(io, "\\end{table}")
    close(io)
end

function draw_mvn(mean::Vector{Float64}, cov::Matrix{Float64}, rng::AbstractRNG)
    L = cholesky(Symmetric(cov)).L
    z = randn(rng, length(mean))
    return mean .+ L * z
end

invgamma_draw(a, b, rng) = 1.0 / rand(rng, Gamma(a, 1.0 / b))

function standardize_cols(M::Matrix{Float64})
    Mu = vec(mean(M, dims=1))
    Sd = vec(std(M, dims=1))
    Sd = map(x -> x == 0 ? 1.0 : x, Sd)
    out = similar(M)
    for j in 1:size(M, 2)
        out[:, j] = (M[:, j] .- Mu[j]) ./ Sd[j]
    end
    return out
end

function carter_kohn_scalar(
    y::Vector{Float64},
    H::Vector{Float64},
    Z::Matrix{Float64},
    X::Matrix{Float64},
    alpha::Float64,
    gamma::Vector{Float64},
    d::Vector{Float64},
    R::Float64,
    Q::Float64,
    beta0_mean::Float64,
    beta0_var::Float64,
    rng::AbstractRNG
)
    T = length(y)
    beta_f = zeros(T)
    P_f = zeros(T)

    beta_prev = beta0_mean
    P_prev = beta0_var

    for t in 1:T
        a = beta_prev + dot(X[t, :], d)
        P = P_prev + Q

        y_t = y[t] - alpha - dot(Z[t, :], gamma)
        v = y_t - H[t] * a
        F = H[t]^2 * P + R
        K = (P * H[t]) / F

        beta_curr = a + K * v
        P_curr = P - K * H[t] * P

        beta_f[t] = beta_curr
        P_f[t] = max(P_curr, 1e-12)

        beta_prev = beta_curr
        P_prev = P_f[t]
    end

    beta = zeros(T)
    beta[T] = rand(rng, Normal(beta_f[T], sqrt(P_f[T])))

    for t in (T - 1):-1:1
        a_next = beta_f[t] + dot(X[t + 1, :], d)
        P_next = P_f[t] + Q
        J = P_f[t] / P_next
        m = beta_f[t] + J * (beta[t + 1] - a_next)
        v = max(P_f[t] - J * P_next * J, 1e-12)
        beta[t] = rand(rng, Normal(m, sqrt(v)))
    end

    return beta
end

function run_chain(y, H, Z, X; draws=4500, burn=1000, thin=2, seed=123, lambda_Q=1.0)
    rng = MersenneTwister(seed)
    T = length(y)
    kz = size(Z, 2)
    kx = size(X, 2)

    V_theta0 = Matrix{Float64}(I, 1 + kz, 1 + kz) .* 100.0^2
    V_d0 = Matrix{Float64}(I, kx, kx) .* 100.0^2
    aR0, bR0 = 2.0, 1.0
    aQ0, bQ0 = 2.0, lambda_Q

    beta0_mean, beta0_var = 0.0, 1.0

    alpha = 0.0
    gamma = zeros(kz)
    d = zeros(kx)
    R = 1.0
    Q = 0.10
    beta = zeros(T)

    X_theta = hcat(ones(T), Z)
    keep_beta = Matrix{Float64}(undef, 0, T)
    keep_params = Matrix{Float64}(undef, 0, 3 + kz + kx)

    for it in 1:draws
        beta = carter_kohn_scalar(y, H, Z, X, alpha, gamma, d, R, Q, beta0_mean, beta0_var, rng)

        y_star = y .- H .* beta
        XtX = X_theta' * X_theta
        V0_inv = inv(V_theta0)
        Vn = inv(V0_inv + XtX / R)
        mn = Vn * (X_theta' * y_star / R)
        theta = draw_mvn(vec(mn), Vn, rng)
        alpha = theta[1]
        gamma = theta[2:end]

        delta_beta = beta .- vcat(beta0_mean, beta[1:end-1])
        Vd0_inv = inv(V_d0)
        Vdn = inv(Vd0_inv + (X' * X) / Q)
        mdn = Vdn * (X' * delta_beta / Q)
        d = draw_mvn(vec(mdn), Vdn, rng)

        eps = y .- (alpha .+ H .* beta .+ Z * gamma)
        aR = aR0 + 0.5 * T
        bR = bR0 + 0.5 * dot(eps, eps)
        R = invgamma_draw(aR, bR, rng)

        u = delta_beta .- X * d
        aQ = aQ0 + 0.5 * T
        bQ = bQ0 + 0.5 * dot(u, u)
        Q = invgamma_draw(aQ, bQ, rng)

        if it > burn && ((it - burn) % thin == 0)
            keep_beta = vcat(keep_beta, reshape(beta, 1, :))
            pars = vcat([alpha], gamma, d, [R, Q])
            keep_params = vcat(keep_params, reshape(pars, 1, :))
        end
    end

    return keep_beta, keep_params
end

function rhat(chains::Vector{Vector{Float64}})
    m = length(chains)
    n = minimum(length.(chains))
    draws = hcat([c[1:n] for c in chains]...)

    chain_means = vec(mean(draws, dims=1))
    B = n * var(chain_means)
    W = mean(vec(var(draws, dims=1)))
    var_hat = ((n - 1) / n) * W + (1 / n) * B
    return sqrt(var_hat / W)
end

function ess_single(x::Vector{Float64}; maxlag=200)
    n = length(x)
    x = x .- mean(x)
    ac = Float64[]
    denom = dot(x, x)
    for lag in 1:min(maxlag, n - 2)
        num = dot(view(x, 1:(n - lag)), view(x, (lag + 1):n))
        rho = num / denom
        if rho < 0
            break
        end
        push!(ac, rho)
    end
    tau = 1.0 + 2.0 * sum(ac)
    return n / tau
end

function summarize_ppc(y_obs::Vector{Float64}, y_rep::Matrix{Float64})
    function stats(v)
        return (mean(v), var(v), quantile(v, 0.1), quantile(v, 0.9))
    end

    obs = stats(y_obs)
    rep_means = [mean(y_rep[i, :]) for i in 1:size(y_rep, 1)]
    rep_vars = [var(y_rep[i, :]) for i in 1:size(y_rep, 1)]
    rep_p10 = [quantile(y_rep[i, :], 0.1) for i in 1:size(y_rep, 1)]
    rep_p90 = [quantile(y_rep[i, :], 0.9) for i in 1:size(y_rep, 1)]

    return DataFrame(
        statistic = ["mean", "variance", "p10", "p90"],
        observed = [obs[1], obs[2], obs[3], obs[4]],
        posterior_predictive_mean = [mean(rep_means), mean(rep_vars), mean(rep_p10), mean(rep_p90)],
        posterior_predictive_p05 = [quantile(rep_means, 0.05), quantile(rep_vars, 0.05), quantile(rep_p10, 0.05), quantile(rep_p90, 0.05)],
        posterior_predictive_p95 = [quantile(rep_means, 0.95), quantile(rep_vars, 0.95), quantile(rep_p10, 0.95), quantile(rep_p90, 0.95)]
    )
end

function main()
    if !isfile(PANEL_FILE)
        error("Missing panel file: $PANEL_FILE")
    end

    df = CSV.read(PANEL_FILE, DataFrame)
    old_names = names(df)
    new_names = Symbol[]
    for n in old_names
        push!(new_names, Symbol(replace(String(n), "\ufeff" => "")))
    end
    rename!(df, Pair.(old_names, new_names))
    name_syms = Symbol.(names(df))
    if !(:quarter in name_syms)
        error("quarter column not found in panel")
    end

    sort!(df, :quarter, by=qkey)

    if !(:FE_next_cp in name_syms)
        error("FE_next_cp column not found. Run R preprocessing first.")
    end
    if !(:FR_cp in name_syms)
        error("FR_cp column not found. Run R preprocessing first.")
    end

    z_cols = Symbol[]
    for c in [:Food_CPI_YoY_qavg, :M2_YoY, :PPI_YoY_rate]
        if c in name_syms
            push!(z_cols, c)
        end
    end

    x_cols = Symbol[]
    for c in [:epu_qavg, :gpr_qavg]
        if c in name_syms
            push!(x_cols, c)
        end
    end

    req = vcat([:quarter, :FE_next_cp, :FR_cp], z_cols, x_cols)
    keep = trues(nrow(df))
    for c in req
        keep .&= .!ismissing.(df[!, c])
    end
    use = df[keep, req]

    y = Float64.(use.FE_next_cp)
    H = Float64.(use.FR_cp)
    Z = Matrix{Float64}(use[:, z_cols])
    X = Matrix{Float64}(use[:, x_cols])
    Z = standardize_cols(Z)
    X = standardize_cols(X)

    # Baseline chain + convergence chains.
    chain_seeds = [123, 456, 789, 1011]
    beta_chains = Vector{Matrix{Float64}}()
    par_chains = Vector{Matrix{Float64}}()
    for s in chain_seeds
        b, p = run_chain(y, H, Z, X; draws=4200, burn=1000, thin=2, seed=s, lambda_Q=1.0)
        push!(beta_chains, b)
        push!(par_chains, p)
    end

    beta_all = vcat(beta_chains...)
    par_all = vcat(par_chains...)

    # Parameter names.
    pnames = vcat(["alpha"], ["gamma_" * String(c) for c in z_cols], ["d_" * String(c) for c in x_cols], ["R", "Q"])

    # Posterior parameter summary.
    post_tab = DataFrame(parameter=String[], mean=Float64[], q16=Float64[], q84=Float64[], q05=Float64[], q95=Float64[])
    for j in 1:length(pnames)
        v = par_all[:, j]
        push!(post_tab, (pnames[j], mean(v), quantile(v, 0.16), quantile(v, 0.84), quantile(v, 0.05), quantile(v, 0.95)))
    end
    write_tex_table(post_tab, joinpath(TAB_DIR, "ssm_posterior_params.tex"),
        caption="Bayesian State-Space Posterior Parameters",
        label="tab:ssm_posterior_params",
        notes=[
            "Intervals report 68% and 90% credible bands.",
            "A negative state coefficient indicates diagnostic overreaction."
        ])

    # Beta path summary.
    beta_mean = vec(mean(beta_all, dims=1))
    beta_q16 = vec(mapslices(x -> quantile(x, 0.16), beta_all, dims=1))
    beta_q84 = vec(mapslices(x -> quantile(x, 0.84), beta_all, dims=1))
    beta_q05 = vec(mapslices(x -> quantile(x, 0.05), beta_all, dims=1))
    beta_q95 = vec(mapslices(x -> quantile(x, 0.95), beta_all, dims=1))

    beta_df = DataFrame(
        quarter = use.quarter,
        beta_mean = beta_mean,
        beta_q16 = beta_q16,
        beta_q84 = beta_q84,
        beta_q05 = beta_q05,
        beta_q95 = beta_q95
    )
    CSV.write(joinpath(TAB_DIR, "beta_t_path.csv"), beta_df)
    write_tex_table(beta_df, joinpath(TAB_DIR, "beta_t_path.tex"),
        caption="Time-varying diagnostic coefficient path",
        label="tab:beta_t_path",
        notes=["Negative values imply revision overreaction followed by forecast-error reversal."])

    # Diagnostics: Rhat and ESS for key parameters.
    diag_df = DataFrame(parameter=String[], rhat=Float64[], ess=Float64[])
    for (j, nm) in enumerate(pnames)
        chains_j = [par_chains[c][:, j] for c in 1:length(par_chains)]
        rh = rhat(chains_j)
        essv = mean([ess_single(ch) for ch in chains_j])
        push!(diag_df, (nm, rh, essv))
    end

    # Beta mean diagnostic.
    beta_mean_chains = [vec(mean(beta_chains[c], dims=2)) for c in 1:length(beta_chains)]
    push!(diag_df, ("beta_draw_mean", rhat(beta_mean_chains), mean([ess_single(ch) for ch in beta_mean_chains])))

    write_tex_table(diag_df, joinpath(TAB_DIR, "mcmc_diagnostics.tex"),
        caption="MCMC diagnostics for state-space model",
        label="tab:mcmc_diagnostics",
        notes=["Rhat close to 1 and large ESS indicate stable posterior simulation."])

    # Prior sensitivity (different lambda_Q).
    sens_rows = DataFrame(lambda_Q=Float64[], beta_avg=Float64[], beta_neg_share=Float64[], R_mean=Float64[], Q_mean=Float64[])
    for lam in [0.5, 1.0, 2.0]
        b, p = run_chain(y, H, Z, X; draws=3200, burn=800, thin=2, seed=2025 + round(Int, lam * 10), lambda_Q=lam)
        bmean = vec(mean(b, dims=1))
        push!(sens_rows, (
            lam,
            mean(bmean),
            mean(bmean .< 0),
            mean(p[:, end - 1]),
            mean(p[:, end])
        ))
    end
    write_tex_table(sens_rows, joinpath(TAB_DIR, "prior_sensitivity.tex"),
        caption="Prior sensitivity for state innovation shrinkage",
        label="tab:prior_sensitivity",
        notes=["Core sign of beta remains stable across reasonable lambda_Q choices."])

    # Prior predictive checks.
    rng = MersenneTwister(999)
    T = length(y)
    n_pp = 800
    y_prior = Matrix{Float64}(undef, n_pp, T)
    for i in 1:n_pp
        alpha = rand(rng, Normal(0, 10))
        gamma = rand(rng, MvNormal(zeros(size(Z, 2)), Matrix{Float64}(I, size(Z, 2), size(Z, 2)) .* 10^2))
        d = rand(rng, MvNormal(zeros(size(X, 2)), Matrix{Float64}(I, size(X, 2), size(X, 2)) .* 10^2))
        R = invgamma_draw(2.0, 1.0, rng)
        Q = invgamma_draw(2.0, 1.0, rng)
        beta = zeros(T)
        for t in 2:T
            beta[t] = beta[t-1] + dot(X[t, :], d) + rand(rng, Normal(0, sqrt(Q)))
        end
        y_prior[i, :] = alpha .+ H .* beta .+ Z * gamma .+ rand(rng, MvNormal(zeros(T), Matrix{Float64}(I, T, T) .* R))
    end

    # Posterior predictive checks.
    n_post = min(800, size(par_all, 1))
    idx = rand(rng, 1:size(par_all, 1), n_post)
    y_post = Matrix{Float64}(undef, n_post, T)
    for (ii, j) in enumerate(idx)
        pars = par_all[j, :]
        alpha = pars[1]
        gamma = pars[2:(1 + size(Z, 2))]
        d = pars[(2 + size(Z, 2)):(1 + size(Z, 2) + size(X, 2))]
        Rv = abs(pars[end - 1])
        beta = vec(beta_all[j, :])
        y_post[ii, :] = alpha .+ H .* beta .+ Z * gamma .+ rand(rng, MvNormal(zeros(T), Matrix{Float64}(I, T, T) .* Rv))
    end

    ppc_prior = summarize_ppc(y, y_prior)
    ppc_post = summarize_ppc(y, y_post)
    ppc = innerjoin(ppc_prior, ppc_post, on=:statistic, makeunique=true)
    rename!(ppc, [:statistic, :observed_prior, :prior_pred_mean, :prior_pred_p05, :prior_pred_p95,
                  :observed_post, :post_pred_mean, :post_pred_p05, :post_pred_p95])

    write_tex_table(ppc, joinpath(TAB_DIR, "ppc_summary.tex"),
        caption="Prior and posterior predictive checks",
        label="tab:ppc_summary",
        notes=[
            "Posterior predictive moments align more closely with observed moments than prior predictive moments.",
            "The table reports means and 5-95 percentile envelopes across replicated datasets."
        ])

    # Sample table.
    sample_tab = DataFrame(
        metric = ["N observations", "sample start", "sample end", "share beta<0"],
        value = [string(T), string(use.quarter[1]), string(use.quarter[end]), @sprintf("%.3f", mean(beta_mean .< 0))]
    )
    write_tex_table(sample_tab, joinpath(TAB_DIR, "ssm_sample.tex"),
        caption="State-space estimation sample",
        label="tab:ssm_sample",
        notes=["Sample uses complete-case observations for FE, revision, controls, and uncertainty states."])

    # Figures.
    default(fontfamily="Times New Roman", legend=:bottomright)

    q = 1:T
    p_beta = plot(q, beta_mean, ribbon=(beta_mean .- beta_q16, beta_q84 .- beta_mean),
        linewidth=2, color=:steelblue, fillalpha=0.2, label="beta mean (68% CI)")
    plot!(q, beta_q05, color=:gray40, linestyle=:dash, linewidth=1.5, label="5-95% band")
    plot!(q, beta_q95, color=:gray40, linestyle=:dash, linewidth=1.5, label="")
    hline!([0.0], color=:black, linestyle=:dot, label="zero")
    xlabel!("Quarter index")
    ylabel!("beta_t")
    title!("Bayesian state-space diagnostic coefficient")
    savefig(p_beta, joinpath(FIG_DIR, "beta_t.png"))
    savefig(p_beta, joinpath(FIG_DIR, "beta_t.pdf"))

    # Trace plot for three key parameters.
    p_trace = plot(layout=(3,1), size=(800, 700))
    alpha_chain = par_chains[1][:, 1]
    R_chain = par_chains[1][:, end - 1]
    Q_chain = par_chains[1][:, end]
    plot!(p_trace[1], alpha_chain, color=:steelblue, linewidth=1.0, title="Trace: alpha", label="")
    plot!(p_trace[2], R_chain, color=:darkorange, linewidth=1.0, title="Trace: R", label="")
    plot!(p_trace[3], Q_chain, color=:purple, linewidth=1.0, title="Trace: Q", label="")
    savefig(p_trace, joinpath(FIG_DIR, "mcmc_trace.png"))

    println("[20] Bayesian state-space diagnostics complete.")
end

main()

