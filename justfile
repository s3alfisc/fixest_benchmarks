# Top-level settings (override with: just force=true bench-ols)
filter := ""
force := "false"

# Default recipe - show available commands
default:
    @just --list

# Show system information (CPU, RAM, versions)
system-info:
    Rscript scripts/system_info.R

# Install R packages via renv (then rebuild selected packages from source)
install-r:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v gfortran >/dev/null 2>&1; then
        echo "Error: gfortran not found. Install GCC (e.g., 'brew install gcc') to build alpaca from source."
        exit 1
    fi
    libgfortran_path="$(gfortran -print-file-name=libgfortran.dylib 2>/dev/null || true)"
    if [ -z "$libgfortran_path" ] || [ "$libgfortran_path" = "libgfortran.dylib" ]; then
        echo "Error: libgfortran not found via gfortran. Ensure GCC is installed and visible in PATH."
        exit 1
    fi
    libdir="$(cd "$(dirname "$libgfortran_path")" && pwd)"
    makevars_dir=".r_local"
    mkdir -p "$makevars_dir"
    printf "FLIBS = -L%s -lgfortran -lquadmath\nLDFLAGS = -L%s\n" "$libdir" "$libdir" > "$makevars_dir/Makevars"
    R_MAKEVARS_USER="$(pwd)/$makevars_dir/Makevars" Rscript -e 'renv::restore()'
    R_MAKEVARS_USER="$(pwd)/$makevars_dir/Makevars" Rscript -e 'renv::install(c("fixest", "lfe", "alpaca"), type="source")'

# Reinstall fixest from source within renv
reinstall-fixest-source:
    Rscript -e 'renv::remove("fixest"); renv::install("fixest", type="source")'

# Reinstall lfe and alpaca from source within renv
reinstall-lfe-alpaca-source:
    Rscript -e 'renv::remove("lfe"); renv::install("lfe", type="source")'
    Rscript -e 'renv::remove("alpaca"); renv::install("alpaca", type="source")'

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
setup: install-r reinstall-fixest-source reinstall-lfe-alpaca-source install-python install-julia

# Download real-world benchmark datasets
download-data:
    Rscript data/download_taxi.R
    Rscript data/download_medicare_payments.R

# Prepare real-world datasets (download + parquet)
prepare-real-data:
    Rscript scripts/prepare_real_data.R

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

# Real-data benchmarks (OLS only)
bench-real-r:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_r.csv" ]; then
        echo "Skipping: results/bench_real_data_r.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_real_data_r.R ols

bench-real-python:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_python.csv" ]; then
        echo "Skipping: results/bench_real_data_python.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_real_data_python.py --type ols

bench-real-julia:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_julia.csv" ]; then
        echo "Skipping: results/bench_real_data_julia.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_real_data_julia.jl ols

combine-real-data:
    Rscript scripts/combine_real_data.R ols

bench-real-ols: prepare-real-data bench-real-r bench-real-python bench-real-julia combine-real-data summarize-real-data

bench-real-r-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_poisson_r.csv" ]; then
        echo "Skipping: results/bench_real_data_poisson_r.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_real_data_r.R poisson

bench-real-python-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_poisson_python.csv" ]; then
        echo "Skipping: results/bench_real_data_poisson_python.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_real_data_python.py --type poisson

bench-real-julia-poisson:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_poisson_julia.csv" ]; then
        echo "Skipping: results/bench_real_data_poisson_julia.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_real_data_julia.jl poisson

combine-real-data-poisson:
    Rscript scripts/combine_real_data.R poisson

bench-real-poisson: prepare-real-data bench-real-r-poisson bench-real-python-poisson bench-real-julia-poisson combine-real-data-poisson summarize-real-data

bench-real-r-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_logit_r.csv" ]; then
        echo "Skipping: results/bench_real_data_logit_r.csv exists (use force=true to rerun)"
        exit 0
    fi
    Rscript scripts/bench_real_data_r.R logit

bench-real-python-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_logit_python.csv" ]; then
        echo "Skipping: results/bench_real_data_logit_python.csv exists (use force=true to rerun)"
        exit 0
    fi
    uv run python scripts/bench_real_data_python.py --type logit

bench-real-julia-logit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "false" ] && [ -f "results/bench_real_data_logit_julia.csv" ]; then
        echo "Skipping: results/bench_real_data_logit_julia.csv exists (use force=true to rerun)"
        exit 0
    fi
    julia -t 8 --project=. scripts/bench_real_data_julia.jl logit

combine-real-data-logit:
    Rscript scripts/combine_real_data.R logit

bench-real-logit: prepare-real-data bench-real-r-logit bench-real-python-logit bench-real-julia-logit combine-real-data-logit summarize-real-data

bench-real-all: bench-real-ols bench-real-poisson bench-real-logit
