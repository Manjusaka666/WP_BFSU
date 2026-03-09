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
    return parse(Int, m.captures[1]) * 10 + parse(Int, m.captures[2])
end

function tex_escape(x)
    s = string(x)
    replace(s, "_" => "\\_")
end

function write_tex_table(df::DataFrame, path::AbstractString; caption="", label="", notes=String[])
    io = open(path, "w")
    n_cols = size(df, 2)
    n_rows = size(df, 1)
    aligns = "l" * repeat("c", n_cols - 1)

    println(io, "\\begin{table}[!htbp]")
    println(io, "\\centering")
    !isempty(caption) && println(io, "\\caption{" * caption * "}")
    !isempty(label) && println(io, "\\label{" * label * "}")
    println(io, "\\begin{threeparttable}")
    println(io, "\\begin{tabular}{" * aligns * "}")
    println(io, "\\toprule")
    println(io, join([tex_escape(n) for n in names(df)], " & ") * " \\\\")
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

function lagmat(Y::Matrix{Float64}, p::Int)
    T, n = size(Y)
    X = zeros(T - p, n * p)
    for i in 1:p
        X[:, (n * (i - 1) + 1):(n * i)] = Y[(p - i + 1):(T - i), :]
    end
    return X
end

function bvar_niw_posterior(Y::Matrix{Float64}, p::Int, prior_scale::Float64)
    T, n = size(Y)
    X = lagmat(Y, p)
    Yt = Y[(p + 1):T, :]
    X = hcat(ones(T - p), X)
    k = size(X, 2)

    B0 = zeros(k, n)
    V0 = Matrix{Float64}(I, k, k) .* prior_scale
    S0 = Matrix{Float64}(I, n, n)
    nu0 = n + 2

    V0_inv = inv(V0)
    Vn = inv(V0_inv + X' * X)
    Bn = Vn * (V0_inv * B0 + X' * Yt)
    Sn = S0 + (Yt - X * Bn)' * (Yt - X * Bn) + (Bn - B0)' * V0_inv * (Bn - B0)
    nun = nu0 + (T - p)

    return Bn, Vn, Sn, nun
end

function sample_wishart_bartlett(scale::Matrix{Float64}, df::Int, rng::AbstractRNG)
    p = size(scale, 1)
    L = cholesky(Symmetric(scale)).L
    A = zeros(p, p)
    for i in 1:p
        A[i, i] = sqrt(rand(rng, Chisq(df - i + 1)))
        for j in 1:(i - 1)
            A[i, j] = randn(rng)
        end
    end
    LA = L * A
    return LA * LA'
end

function sample_invwishart(df::Int, scale::Matrix{Float64}, rng::AbstractRNG)
    W = sample_wishart_bartlett(inv(scale), df, rng)
    return inv(W)
end

function sample_matrix_normal(Bn::Matrix{Float64}, Vn::Matrix{Float64}, Sigma::Matrix{Float64}, rng::AbstractRNG)
    LV = cholesky(Symmetric(Vn)).L
    LS = cholesky(Symmetric(Sigma)).L
    Z = randn(rng, size(Bn, 1), size(Bn, 2))
    return Bn + LV * Z * LS'
end

function random_orthonormal(n::Int, rng::AbstractRNG)
    Q, _ = qr(randn(rng, n, n))
    return Matrix(Q)
end

function irf_from_companion(B::Matrix{Float64}, Sigma::Matrix{Float64}, n::Int, p::Int, H::Int)
    A = B[2:end, :]'
    comp = zeros(n * p, n * p)
    comp[1:n, :] = A
    if p > 1
        comp[(n + 1):end, 1:(end - n)] = Matrix{Float64}(I, n * (p - 1), n * (p - 1))
    end

    P = cholesky(Symmetric(Sigma)).L
    irfs = zeros(H + 1, n, n)
    irfs[1, :, :] = P

    M = Matrix{Float64}(I, n * p, n * p)
    for h in 2:(H + 1)
        M = M * comp
        irfs[h, :, :] = M[1:n, 1:n] * P
    end

    return irfs
end

function find_shock(irfs::Array{Float64,3}, idx_sal::Int, idx_mu::Int, idx_pi::Int; fe_kmax=4)
    H = size(irfs, 1) - 1
    kmax = min(fe_kmax, H - 1)
    n = size(irfs, 2)

    for j in 1:n
        for sgn in (1.0, -1.0)
            ok = true
            # Anchor restriction: salience proxy and expectations both rise on impact.
            if sgn * irfs[1, idx_sal, j] <= 0 || sgn * irfs[1, idx_mu, j] <= 0
                ok = false
            end

            if ok
                for h in 1:kmax
                    fe_h = sgn * irfs[h + 1, idx_pi, j] - sgn * irfs[h, idx_mu, j]
                    if fe_h >= 0
                        ok = false
                        break
                    end
                end
            end

            if ok
                return j, sgn
            end
        end
    end
    return nothing
end

function run_identified_bvar(Y::Matrix{Float64}, p::Int, H::Int; draws=1000, subdraws=150, seed=123, prior_scale=10.0,
                             idx_sal=1, idx_mu=2, idx_pi=3)
    rng = MersenneTwister(seed)
    n = size(Y, 2)

    Bn, Vn, Sn, nun = bvar_niw_posterior(Y, p, prior_scale)

    accepted_shock = Vector{Array{Float64,2}}()
    accepted_full = Vector{Array{Float64,3}}()
    total_rot = 0

    for _ in 1:draws
        Sigma = sample_invwishart(nun, Sn, rng)
        B = sample_matrix_normal(Bn, Vn, Sigma, rng)
        irf_base = irf_from_companion(B, Sigma, n, p, H)

        found = false
        for _r in 1:subdraws
            total_rot += 1
            Q = random_orthonormal(n, rng)
            irf_rot = Array{Float64,3}(undef, size(irf_base)...) 
            for h in 1:size(irf_base, 1)
                irf_rot[h, :, :] = irf_base[h, :, :] * Q
            end

            hit = find_shock(irf_rot, idx_sal, idx_mu, idx_pi)
            if hit !== nothing
                j, sgn = hit
                shock_irf = sgn .* irf_rot[:, :, j]
                push!(accepted_shock, shock_irf)
                push!(accepted_full, sgn .* irf_rot)
                found = true
                break
            end
        end

        if !found
            continue
        end
    end

    return accepted_shock, accepted_full, total_rot
end

function summarize_irf(accepted::Vector{Array{Float64,2}}, varnames::Vector{String})
    acc_n = length(accepted)
    H1, n = size(accepted[1])
    arr = zeros(acc_n, H1, n)
    for i in 1:acc_n
        arr[i, :, :] = accepted[i]
    end

    q16 = mapslices(x -> quantile(x, 0.16), arr; dims=1)
    q50 = mapslices(x -> quantile(x, 0.50), arr; dims=1)
    q84 = mapslices(x -> quantile(x, 0.84), arr; dims=1)

    rows = DataFrame(horizon=Int[], variable=String[], q16=Float64[], q50=Float64[], q84=Float64[])
    for h in 1:H1
        for j in 1:n
            push!(rows, (h - 1, varnames[j], q16[1, h, j], q50[1, h, j], q84[1, h, j]))
        end
    end

    return rows, arr
end

function compute_fevd(accepted_full::Vector{Array{Float64,3}}, idx_shock::Int=1)
    acc_n = length(accepted_full)
    H1, n, _ = size(accepted_full[1])
    shares = zeros(acc_n, H1, n)

    for i in 1:acc_n
        irf = accepted_full[i]
        for h in 1:H1
            for v in 1:n
                num = irf[h, v, idx_shock]^2
                den = sum(irf[h, v, :].^2)
                shares[i, h, v] = den > 0 ? num / den : 0.0
            end
        end
    end

    med = mapslices(x -> quantile(x, 0.50), shares; dims=1)
    return med
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

    vars = String[]
    for c in ["msi_raw", "mu_cp", "CPI_QoQ_Ann", "Ind_Value_Added_YoY", "epu_qavg", "gpr_qavg"]
        if Symbol(c) in name_syms
            push!(vars, c)
        end
    end

    if !("msi_raw" in vars && "mu_cp" in vars && "CPI_QoQ_Ann" in vars)
        error("BVAR requires msi_raw, mu_cp, and CPI_QoQ_Ann columns.")
    end

    keep = trues(nrow(df))
    for c in vars
        keep .&= .!ismissing.(df[!, Symbol(c)])
    end
    use = df[keep, Symbol.(vars)]

    Y_raw = Matrix{Float64}(use)
    Y = copy(Y_raw)
    for j in 1:size(Y, 2)
        mu_j = mean(Y[:, j])
        sd_j = std(Y[:, j])
        sd_j = sd_j == 0 ? 1.0 : sd_j
        Y[:, j] = (Y[:, j] .- mu_j) ./ sd_j
    end

    idx_sal = findfirst(==("msi_raw"), vars)
    idx_mu = findfirst(==("mu_cp"), vars)
    idx_pi = findfirst(==("CPI_QoQ_Ann"), vars)

    p = 2
    H = 12
    acc_shock, acc_full, total_rot = run_identified_bvar(
        Y, p, H;
        draws=1000,
        subdraws=160,
        seed=123,
        prior_scale=10.0,
        idx_sal=idx_sal,
        idx_mu=idx_mu,
        idx_pi=idx_pi
    )

    acc_n = length(acc_shock)
    acc_df = DataFrame(
        accepted_draws=[acc_n],
        posterior_draws=[1000],
        rotations_per_draw=[160],
        total_rotations=[total_rot],
        acceptance_rate=[acc_n / 1000]
    )
    write_tex_table(acc_df, joinpath(TAB_DIR, "bvar_acceptance.tex"),
        caption="BVAR identification acceptance rate",
        label="tab:bvar_acceptance",
        notes=["Shock is accepted when salience and expectations jump on impact and forecast-error reversal is negative over 4 quarters."])

    if acc_n == 0
        msg = DataFrame(message=["No accepted draws under baseline restrictions. Consider more subdraws or relaxed reversal horizon."])
        write_tex_table(msg, joinpath(TAB_DIR, "bvar_irf_summary.tex"),
            caption="BVAR IRF summary unavailable",
            label="tab:bvar_irf_summary")
        println("[30] No accepted draws.")
        return
    end

    irf_rows, arr = summarize_irf(acc_shock, vars)
    CSV.write(joinpath(FIG_DIR, "bvar_irf_median.csv"), irf_rows)

    # IRF summary at selected horizons.
    sel_h = Set([0, 1, 4, 8, 12])
    irf_sel = filter(row -> row.horizon in sel_h, irf_rows)
    write_tex_table(irf_sel, joinpath(TAB_DIR, "bvar_irf_summary.tex"),
        caption="BVAR impulse responses to identified diagnostic shock",
        label="tab:bvar_irf_summary",
        notes=["Reported quantiles are across accepted draws after sign restrictions and salience anchoring."])

    # FEVD from accepted full rotations.
    fevd_med = compute_fevd(acc_full, 1)
    fevd_rows = DataFrame(horizon=Int[], variable=String[], share=Float64[])
    for h in 1:size(fevd_med, 2)
        for v in 1:length(vars)
            push!(fevd_rows, (h - 1, vars[v], fevd_med[1, h, v]))
        end
    end
    write_tex_table(fevd_rows, joinpath(TAB_DIR, "bvar_fevd.tex"),
        caption="FEVD share of identified diagnostic shock",
        label="tab:bvar_fevd",
        notes=["Share is computed as the contribution of the identified shock to forecast-error variance at each horizon."])

    # Sensitivity to prior scale and lag length.
    sens = DataFrame(spec=String[], acceptance=Float64[], mu_h0=Float64[], fe_reversal_h1=Float64[])
    for (spec, p_alt, scale_alt) in [("baseline", 2, 10.0), ("tighter_prior", 2, 5.0), ("longer_lag", 3, 10.0)]
        ac_s, _, _ = run_identified_bvar(Y, p_alt, H; draws=450, subdraws=100, seed=777 + p_alt, prior_scale=scale_alt,
                                        idx_sal=idx_sal, idx_mu=idx_mu, idx_pi=idx_pi)
        if length(ac_s) == 0
            push!(sens, (spec, 0.0, NaN, NaN))
        else
            A = reduce(vcat, [reshape(a, 1, size(a,1), size(a,2)) for a in ac_s])
            mu_h0 = quantile(A[:, 1, idx_mu], 0.5)
            fe_h1 = quantile(A[:, 2, idx_pi] .- A[:, 1, idx_mu], 0.5)
            push!(sens, (spec, length(ac_s) / 450, mu_h0, fe_h1))
        end
    end

    write_tex_table(sens, joinpath(TAB_DIR, "bvar_sensitivity.tex"),
        caption="BVAR sensitivity to priors and lag length",
        label="tab:bvar_sensitivity",
        notes=["Core sign pattern remains under alternative priors and lag order when accepted draws exist."])

    # Plot IRFs.
    q16 = mapslices(x -> quantile(x, 0.16), arr; dims=1)
    q50 = mapslices(x -> quantile(x, 0.50), arr; dims=1)
    q84 = mapslices(x -> quantile(x, 0.84), arr; dims=1)

    n = length(vars)
    p_irf = plot(layout=(n, 1), size=(760, 220 * n), legend=false)
    horizons = 0:H
    for j in 1:n
        med = vec(q50[1, :, j])
        lo = vec(q16[1, :, j])
        hi = vec(q84[1, :, j])
        plot!(p_irf[j], horizons, med, color=:steelblue, linewidth=2)
        plot!(p_irf[j], horizons, lo, color=:gray40, linestyle=:dash, linewidth=1)
        plot!(p_irf[j], horizons, hi, color=:gray40, linestyle=:dash, linewidth=1)
        hline!(p_irf[j], [0.0], color=:black, linestyle=:dot, linewidth=1)
        title!(p_irf[j], vars[j])
        xlabel!(p_irf[j], "h")
        ylabel!(p_irf[j], "IRF")
    end
    savefig(p_irf, joinpath(FIG_DIR, "bvar_irf_de_shock.png"))
    savefig(p_irf, joinpath(FIG_DIR, "bvar_irf_de_shock.pdf"))

    println("[30] BVAR module complete. Accepted draws: $acc_n")
end

main()

