# Default recipe - show available commands
default:
    @just --list

# Install R packages via renv
install-r:
    Rscript -e 'renv::restore()'

# Install Python packages using uv
install-python:
    #!/usr/bin/env bash
    set -euo pipefail
    # Install uv if not present
    if ! command -v uv &> /dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    # Sync dependencies (creates .venv and uv.lock)
    uv sync

# Install Julia packages via Pkg
install-julia:
    julia --project=. -e 'import Pkg; Pkg.instantiate()'

# Full setup: all languages
setup: install-r install-python install-julia

# Download real-world benchmark datasets
download-data:
    Rscript data/download_taxi.R
    Rscript data/download_medicare_payments.R

# =============================================================================
# NEW ISOLATED BENCHMARK ARCHITECTURE
# =============================================================================

# Generate simulated benchmark data (shared by all languages)
generate-data:
    Rscript scripts/generate_data.R

# --- OLS Benchmarks (with optional filter, e.g., just bench-python-ols simple) ---

# Run Python OLS benchmarks (optional filter: just bench-python-ols [filter])
bench-python-ols filter="":
    uv run python scripts/bench_python.py --type ols --output results/bench_python_ols.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R OLS benchmarks (optional filter: just bench-r-ols [filter])
bench-r-ols filter="":
    Rscript scripts/bench_r.R ols data/benchmark results/bench_r_ols.csv {{ filter }}

# Run Julia OLS benchmarks (optional filter: just bench-julia-ols [filter])
bench-julia-ols filter="":
    julia -t 8 --project=. scripts/bench_julia.jl ols data/benchmark results/bench_julia_ols.csv {{ filter }}

# Combine OLS results from all languages
combine-ols:
    Rscript scripts/combine_results.R ols

# Run complete OLS benchmark pipeline (optional filter)
bench-ols filter="": generate-data (bench-python-ols filter) (bench-r-ols filter) (bench-julia-ols filter) combine-ols summarize-ols

# --- Poisson Benchmarks ---

# Run Python Poisson benchmarks
bench-python-poisson filter="":
    uv run python scripts/bench_python.py --type poisson --output results/bench_python_poisson.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R Poisson benchmarks
bench-r-poisson filter="":
    Rscript scripts/bench_r.R poisson data/benchmark results/bench_r_poisson.csv {{ filter }}

# Run Julia Poisson benchmarks
bench-julia-poisson filter="":
    julia -t 8 --project=. scripts/bench_julia.jl poisson data/benchmark results/bench_julia_poisson.csv {{ filter }}

# Combine Poisson results
combine-poisson:
    Rscript scripts/combine_results.R poisson

# Run complete Poisson benchmark pipeline
bench-poisson filter="": generate-data (bench-python-poisson filter) (bench-r-poisson filter) (bench-julia-poisson filter) combine-poisson summarize-poisson

# --- Logit Benchmarks ---

# Run Python Logit benchmarks
bench-python-logit filter="":
    uv run python scripts/bench_python.py --type logit --output results/bench_python_logit.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R Logit benchmarks
bench-r-logit filter="":
    Rscript scripts/bench_r.R logit data/benchmark results/bench_r_logit.csv {{ filter }}

# Run Julia Logit benchmarks
bench-julia-logit filter="":
    julia -t 8 --project=. scripts/bench_julia.jl logit data/benchmark results/bench_julia_logit.csv {{ filter }}

# Combine Logit results
combine-logit:
    Rscript scripts/combine_results.R logit

# Run complete Logit benchmark pipeline
bench-logit filter="": generate-data (bench-python-logit filter) (bench-r-logit filter) (bench-julia-logit filter) combine-logit summarize-logit

# --- All Benchmarks ---

# Run all simulated data benchmarks
bench-all filter="": (bench-ols filter) (bench-poisson filter) (bench-logit filter)

# Full benchmark run (generate data, run all benchmarks)
run-all filter="": generate-data (bench-all filter)

# Summarize all benchmark results
summarize:
    Rscript summarize_benchmark.R all

# Summarize OLS benchmark results only
summarize-ols:
    Rscript summarize_benchmark.R ols

# Summarize Poisson benchmark results only
summarize-poisson:
    Rscript summarize_benchmark.R poisson

# Summarize Logit benchmark results only
summarize-logit:
    Rscript summarize_benchmark.R logit

# Summarize real data benchmark results only
summarize-real-data:
    Rscript summarize_benchmark.R real_data
