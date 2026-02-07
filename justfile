# Top-level settings (override with: just force=true bench-ols)
filter := ""
force := "false"

# Default recipe - show available commands
default:
    @just --list

# Show system information (CPU, RAM, versions)
system-info:
    Rscript scripts/system_info.R

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
    # Install pixi if not present
    if ! command -v pixi &> /dev/null; then
        curl -fsSL https://pixi.sh/install.sh | bash
        export PATH="$HOME/.pixi/bin:$PATH"
    fi
    # Clone or update pyfixest from PR branch
    if [ ! -d "pyfixest" ]; then
        git clone --branch scipy-tol --single-branch \
            https://github.com/py-econometrics/pyfixest.git pyfixest
    else
        cd pyfixest
        git fetch origin
        git reset --hard origin/scipy-tol
        cd ..
    fi
    # Sync other dependencies first (creates .venv)
    uv sync
    # Build pyfixest Rust extension using pixi (unset conflicting env vars)
    cd pyfixest && unset VIRTUAL_ENV CONDA_PREFIX && pixi run -e build maturin-develop && cd ..
    # Install pyfixest into uv environment
    uv pip install -e ./pyfixest

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

# --- OLS Benchmarks (with optional filter, e.g., just filter=simple bench-python-ols) ---

# Run Python OLS benchmarks
bench-python-ols:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_python_ols.csv" ]; then
        echo "Skipping: results/bench_python_ols.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_python.py --type ols --output results/bench_python_ols.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R OLS benchmarks
bench-r-ols:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_r_ols.csv" ]; then
        echo "Skipping: results/bench_r_ols.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_r.R ols data/benchmark results/bench_r_ols.csv {{ filter }}

# Run Julia OLS benchmarks
bench-julia-ols:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_julia_ols.csv" ]; then
        echo "Skipping: results/bench_julia_ols.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_julia.jl ols data/benchmark results/bench_julia_ols.csv {{ filter }}

# Combine OLS results from all languages
combine-ols:
    Rscript scripts/combine_results.R ols

# Run complete OLS benchmark pipeline
bench-ols: generate-data bench-python-ols bench-r-ols bench-julia-ols combine-ols summarize-ols

# --- Poisson Benchmarks ---

# Run Python Poisson benchmarks
bench-python-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_python_poisson.csv" ]; then
        echo "Skipping: results/bench_python_poisson.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_python.py --type poisson --output results/bench_python_poisson.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R Poisson benchmarks
bench-r-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_r_poisson.csv" ]; then
        echo "Skipping: results/bench_r_poisson.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_r.R poisson data/benchmark results/bench_r_poisson.csv {{ filter }}

# Run Julia Poisson benchmarks
bench-julia-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_julia_poisson.csv" ]; then
        echo "Skipping: results/bench_julia_poisson.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_julia.jl poisson data/benchmark results/bench_julia_poisson.csv {{ filter }}

# Combine Poisson results
combine-poisson:
    Rscript scripts/combine_results.R poisson

# Run complete Poisson benchmark pipeline
bench-poisson: generate-data bench-python-poisson bench-r-poisson bench-julia-poisson combine-poisson summarize-poisson

# --- Logit Benchmarks ---

# Run Python Logit benchmarks
bench-python-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_python_logit.csv" ]; then
        echo "Skipping: results/bench_python_logit.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_python.py --type logit --output results/bench_python_logit.csv {{ if filter != "" { "--filter " + filter } else { "" } }}

# Run R Logit benchmarks
bench-r-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_r_logit.csv" ]; then
        echo "Skipping: results/bench_r_logit.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_r.R logit data/benchmark results/bench_r_logit.csv {{ filter }}

# Run Julia Logit benchmarks
bench-julia-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_julia_logit.csv" ]; then
        echo "Skipping: results/bench_julia_logit.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_julia.jl logit data/benchmark results/bench_julia_logit.csv {{ filter }}

# Combine Logit results
combine-logit:
    Rscript scripts/combine_results.R logit

# Run complete Logit benchmark pipeline
bench-logit: generate-data bench-python-logit bench-r-logit bench-julia-logit combine-logit summarize-logit

# --- All Benchmarks ---

# Run all simulated data benchmarks
bench-all: bench-ols bench-poisson bench-logit

# Combine all results from all languages
combine-all: combine-ols combine-poisson combine-logit

# Full benchmark run (generate data, run all benchmarks)
run-all: generate-data bench-all

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
