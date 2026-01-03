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

# --- OLS Benchmarks ---

# Run Python OLS benchmarks
bench-python-ols:
    uv run python scripts/bench_python.py --type ols --output results/bench_python_ols.csv

# Run R OLS benchmarks
bench-r-ols:
    Rscript scripts/bench_r.R ols data/benchmark results/bench_r_ols.csv

# Run Julia OLS benchmarks
bench-julia-ols:
    julia --project=. scripts/bench_julia.jl ols data/benchmark results/bench_julia_ols.csv

# Combine OLS results from all languages
combine-ols:
    Rscript scripts/combine_results.R ols

# Run complete OLS benchmark pipeline
bench-ols: generate-data bench-python-ols bench-r-ols bench-julia-ols combine-ols

# --- Poisson Benchmarks ---

# Run Python Poisson benchmarks
bench-python-poisson:
    uv run python scripts/bench_python.py --type poisson --output results/bench_python_poisson.csv

# Run R Poisson benchmarks
bench-r-poisson:
    Rscript scripts/bench_r.R poisson data/benchmark results/bench_r_poisson.csv

# Run Julia Poisson benchmarks
bench-julia-poisson:
    julia --project=. scripts/bench_julia.jl poisson data/benchmark results/bench_julia_poisson.csv

# Combine Poisson results
combine-poisson:
    Rscript scripts/combine_results.R poisson

# Run complete Poisson benchmark pipeline
bench-poisson: generate-data bench-python-poisson bench-r-poisson bench-julia-poisson combine-poisson

# --- Logit Benchmarks ---

# Run Python Logit benchmarks
bench-python-logit:
    uv run python scripts/bench_python.py --type logit --output results/bench_python_logit.csv

# Run R Logit benchmarks
bench-r-logit:
    Rscript scripts/bench_r.R logit data/benchmark results/bench_r_logit.csv

# Run Julia Logit benchmarks
bench-julia-logit:
    julia --project=. scripts/bench_julia.jl logit data/benchmark results/bench_julia_logit.csv

# Combine Logit results
combine-logit:
    Rscript scripts/combine_results.R logit

# Run complete Logit benchmark pipeline
bench-logit: generate-data bench-python-logit bench-r-logit bench-julia-logit combine-logit

# --- All Benchmarks ---

# Run all simulated data benchmarks
bench-all: bench-ols bench-poisson bench-logit

# Full benchmark run (generate data, run all benchmarks)
run-all: generate-data bench-all

# Summarize benchmark results
summarize:
    Rscript summarize_benchmark.R
