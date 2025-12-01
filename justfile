# Default recipe - show available commands
default:
    @just --list

# Install R packages via renv
install-r:
    Rscript -e 'renv::restore()'

# Install Python packages via uv
install-python:
    pip3 install uv
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
bench-all: bench-ols bench-poisson bench-logit

# Full benchmark run (setup data if needed, then run all)
run-all: download-data bench-all bench-real-data

# Summarize benchmark results
summarize:
    Rscript summarize_benchmark.R
