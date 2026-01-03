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

# Download benchmark datasets
download-data:
    Rscript data/download_taxi.R
    Rscript data/download_medicare_payments.R

# Run individual benchmarks
bench-ols:
    Rscript bench_ols.R

bench-poisson:
    Rscript bench_poisson.R

bench-logit:
    Rscript bench_logit.R

bench-real-data:
    Rscript bench_real_data.R

# Run all simulated data benchmarks
bench-all: bench-ols bench-poisson bench-logit bench-real-data

# Full benchmark run (setup data if needed, then run all)
run-all: download-data bench-all

# Summarize benchmark results
summarize:
    Rscript summarize_benchmark.R
