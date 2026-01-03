#!/usr/bin/env julia
# Julia benchmark runner for fixed-effect estimation
# Runs FixedEffectModels and GLFixedEffectModels benchmarks on pre-generated parquet data

using Pkg
Pkg.activate(".")

using DataFrames
using Parquet2
using CSV
using StatsModels
using FixedEffectModels
using GLFixedEffectModels

const N_THREADS = 8

# Timer functions
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

# Parse dataset name
function parse_dataset_name(name::String)
    size_map = Dict(
        "1k" => 1_000,
        "10k" => 10_000,
        "100k" => 100_000,
        "500k" => 500_000,
        "1m" => 1_000_000,
        "2m" => 2_000_000
    )
    parts = split(name, "_")
    dgp_type = parts[1]
    n_str = parts[2]
    n_obs = get(size_map, n_str, 0)
    return dgp_type, n_obs
end

# Get estimators and formulas by benchmark type
function get_config(benchmark_type::String)
    if benchmark_type == "ols"
        estimators = [
            ("FixedEffectModels.reg", feols_timer),
        ]
        formulas = [
            (2, "y ~ x1 + fe(indiv_id) + fe(year)"),
            (3, "y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"),
        ]
    elseif benchmark_type == "poisson"
        estimators = [
            ("GLFixedEffectModels Poisson", fepois_timer),
        ]
        formulas = [
            (2, "negbin_y ~ x1 + fe(indiv_id) + fe(year)"),
            (3, "negbin_y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"),
        ]
    elseif benchmark_type == "logit"
        estimators = [
            ("GLFixedEffectModels Logit", feglm_logit_timer),
        ]
        formulas = [
            (2, "binary_y ~ x1 + fe(indiv_id) + fe(year)"),
            (3, "binary_y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"),
        ]
    else
        error("Unknown benchmark type: $benchmark_type")
    end
    return estimators, formulas
end

function run_benchmark(data_dir::String, output_file::String, benchmark_type::String, filter_pattern::Union{String, Nothing}=nothing)
    estimators, formulas = get_config(benchmark_type)

    # Get all parquet files
    parquet_files = sort(filter(f -> endswith(f, ".parquet"), readdir(data_dir, join=true)))
    if isempty(parquet_files)
        error("No parquet files found in $data_dir")
    end

    # Group files by dataset
    datasets = Dict{String, Vector{Tuple{String, Int, String}}}()
    for f in parquet_files
        basename_noext = splitext(basename(f))[1]
        parts = split(basename_noext, "_")
        n_parts = length(parts)
        ds_name = join(parts[1:n_parts-2], "_")
        iter_type = parts[n_parts-1]
        iter_num = parse(Int, parts[n_parts])

        # Apply filter if specified
        if filter_pattern !== nothing && !occursin(filter_pattern, ds_name)
            continue
        end

        if !haskey(datasets, ds_name)
            datasets[ds_name] = []
        end
        push!(datasets[ds_name], (iter_type, iter_num, f))
    end

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
    println("JULIA BENCHMARK: $(uppercase(benchmark_type))")
    println("=" ^ 80)
    filter_info = filter_pattern !== nothing ? " | Filter: '$(filter_pattern)'" : ""
    println("Estimators: $(length(estimators)) | FE configs: $(length(formulas)) | Threads: $N_THREADS$filter_info")

    for ds_name in sort(collect(keys(datasets)))
        dgp_type, n_obs = parse_dataset_name(ds_name)

        println()
        println("-" ^ 80)
        println("Dataset: $ds_name (n=$(format_number(n_obs)))")
        println("-" ^ 80)

        # Sort files: burnin first, then iter
        files = datasets[ds_name]
        sort!(files, by = x -> (x[1] == "burnin" ? 0 : 1, x[2]))

        for (iter_type, iter_num, filepath) in files
            println()
            println("[$iter_type $iter_num] Loading $(basename(filepath))...")

            data = DataFrame(Parquet2.Dataset(filepath))

            for (n_fe, formula) in formulas
                for (est_name, func) in estimators
                    print("  -> $(rpad(est_name, 35)) (FE=$n_fe) ... ")
                    flush(stdout)

                    elapsed = try
                        func(data, formula)
                    catch e
                        missing
                    end

                    if ismissing(elapsed)
                        println("FAILED")
                    else
                        println("$(round(elapsed, digits=3))s")
                    end

                    # Only record non-burnin iterations
                    if iter_type != "burnin"
                        push!(results, (iter_num, elapsed, est_name, n_fe, dgp_type, n_obs))
                    end
                end
            end
        end
    end

    println()
    println("=" ^ 80)
    println("BENCHMARK COMPLETE")
    println("=" ^ 80)

    # Write results
    mkpath(dirname(output_file))
    CSV.write(output_file, results)
    println()
    println("Results written to: $output_file")
end

# Helper function to format numbers with commas
function format_number(n::Int)
    s = string(n)
    result = ""
    for (i, c) in enumerate(reverse(s))
        if i > 1 && (i - 1) % 3 == 0
            result = "," * result
        end
        result = c * result
    end
    return result
end

# Main entry point
function main()
    benchmark_type = length(ARGS) >= 1 ? ARGS[1] : "ols"
    data_dir = length(ARGS) >= 2 ? ARGS[2] : "data/benchmark"
    output_file = length(ARGS) >= 3 ? ARGS[3] : "results/bench_julia.csv"
    filter_pattern = length(ARGS) >= 4 ? ARGS[4] : nothing

    run_benchmark(data_dir, output_file, benchmark_type, filter_pattern)
end

main()
