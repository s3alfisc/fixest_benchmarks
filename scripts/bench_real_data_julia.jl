#!/usr/bin/env julia
# Julia real-data benchmark runner (FixedEffectModels/GLFixedEffectModels)

using CSV
using DataFrames
using Parquet2
using FixedEffectModels
using GLFixedEffectModels
using JSON3

function load_config(path::String)
    if isfile(path)
        return JSON3.read(read(path, String))
    end
    return nothing
end

function get_nested(config, keys::Vector{String}, default)
    cur = config
    for k in keys
        if cur === nothing || !haskey(cur, k)
            return default
        end
        cur = cur[k]
    end
    return cur
end

const CONFIG = load_config("config/bench.json")
const N_THREADS = Int(get_nested(CONFIG, ["threads", "julia"], 8))

function feols_timer(data::DataFrame, formula_str::String; nthreads::Int=N_THREADS)
    formula = eval(Meta.parse("@formula(" * formula_str * ")"))
    start_time = time()
    _ = reg(data, formula, nthreads=nthreads)
    return time() - start_time
end

function fepois_timer(data::DataFrame, formula_str::String)
    formula = eval(Meta.parse("@formula(" * formula_str * ")"))
    start_time = time()
    _ = nlreg(data, formula, Poisson(), LogLink())
    return time() - start_time
end

function feglm_logit_timer(data::DataFrame, formula_str::String)
    formula = eval(Meta.parse("@formula(" * formula_str * ")"))
    start_time = time()
    _ = nlreg(data, formula, Binomial(), LogitLink())
    return time() - start_time
end

function main()
    if CONFIG === nothing || !haskey(CONFIG, "real_data")
        error("No real_data config found in config/bench.json")
    end
    real_cfg = CONFIG["real_data"]

    results = DataFrame(
        iter = Int[],
        time = Union{Float64, Missing}[],
        est_name = String[],
        n_fe = Int[],
        dgp_name = String[],
        n_obs = Int[]
    )

    println()
    println("=" ^ 80)
    benchmark_type = length(ARGS) >= 1 ? ARGS[1] : "ols"
    println("JULIA REAL-DATA BENCHMARK ($(uppercase(benchmark_type)))")
    println("=" ^ 80)

    for ds in real_cfg
        if !haskey(ds, "formulas") || !haskey(ds["formulas"], benchmark_type) || !haskey(ds["formulas"][benchmark_type], "julia")
            continue
        end
        formula = String(ds["formulas"][benchmark_type]["julia"])
        parquet_path = String(ds["parquet"])
        if !isfile(parquet_path)
            error("Missing parquet file: $parquet_path")
        end
        data = DataFrame(Parquet2.Dataset(parquet_path))
        n_obs = nrow(data)
        n_iters = Int(ds["n_iters"])
        n_fe = Int(ds["n_fe"])
        ds_name = String(ds["name"])

        println()
        println("Dataset: $ds_name (n=$(n_obs), iters=$n_iters)")

        for i in 1:n_iters
            if benchmark_type == "poisson"
                est_name = "GLFixedEffectModels Poisson"
            elseif benchmark_type == "logit"
                est_name = "GLFixedEffectModels Logit"
            else
                est_name = "FixedEffectModels.reg"
            end
            print("  -> $(est_name) (iter $i/$n_iters) ... ")
            flush(stdout)
            elapsed = try
                if benchmark_type == "poisson"
                    fepois_timer(data, formula)
                elseif benchmark_type == "logit"
                    feglm_logit_timer(data, formula)
                else
                    feols_timer(data, formula, nthreads=N_THREADS)
                end
            catch e
                println("ERROR: $(string(e))")
                missing
            end

            if ismissing(elapsed)
                # already printed error
            else
                println("$(round(elapsed, digits=3))s")
            end

            push!(results, (i, elapsed, est_name, n_fe, ds_name, n_obs))
        end
    end

    output_file = "results/bench_real_data_$(benchmark_type)_julia.csv"
    mkpath(dirname(output_file))
    CSV.write(output_file, results)
    println()
    println("Results written to: $output_file")
end

main()
