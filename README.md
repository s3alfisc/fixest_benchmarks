# Benchmarks for Fixed-Effect Estimation

This repository contains a set of open-source benchmarks for assessing
the performance of various statistical packages for estimating linear
and generalized linear models. The benchmarks are designed to evaluate
the speed and efficiency of different estimation methods under various
conditions, such as sample size, number of fixed effects, and model
complexity. These benchmarks are scheduled to run weekly on Github
Actions, and the updated results are stored in the `results` directory.

If you would like to contribute to the benchmarks or add alternative
estimators, PRs are welcome. The benchmark scripts are organized by language:
- `scripts/bench_python.py` - Python estimators (pyfixest, linearmodels, statsmodels)
- `scripts/bench_r.R` - R estimators (fixest, lfe)
- `scripts/bench_julia.jl` - Julia estimators (FixedEffectModels)

> [!CAUTION]
>
> As with all benchmarks, these results should be interpreted with
> caution. Performance can vary based on the specific data, model
> specifications, number of cores and RAM available, and other aspects
> of computational environment. Github Actions likely use more limited
> resources than a high-end local machine. But, we use Github Actions to
> ensure that the benchmarks are run in a consistent environment so that
> individuals can use these benchmarks as a potential dev tool.

## Setup

### Prerequisites

You need the following installed on your system:

- **R** (>= 4.4.0)
- **Python** (>= 3.13)
- **Julia** (>= 1.11)
- **[just](https://github.com/casey/just)** - command runner
- **[uv](https://github.com/astral-sh/uv)** - Python package manager

### Installation

Install all dependencies with:

```bash
just setup
```

This runs:
- `renv::restore()` to install R packages from `renv.lock`
- `uv sync` to install Python packages from `pyproject.toml`
- `Pkg.instantiate()` to install Julia packages from `Project.toml`

### Running Benchmarks

The benchmarks use an isolated architecture where each language runs in its own
process. This ensures fair comparisons and allows JIT compilation (e.g., numba)
to persist across iterations.

```bash
# Generate benchmark data (parquet files shared by all languages)
just generate-data

# Run complete benchmark pipelines (generates data + all languages + combines + plots)
just bench-ols          # OLS benchmarks
just bench-poisson      # Poisson benchmarks
just bench-logit        # Logit benchmarks
just bench-all          # All benchmarks

# Run individual language benchmarks (after generate-data)
just bench-python-ols   # Python only
just bench-r-ols        # R only
just bench-julia-ols    # Julia only

# Combine results and generate plots separately (if running languages individually)
just combine-ols        # Merge Python/R/Julia OLS CSVs into results/bench_ols.csv
just combine-all        # Combine all benchmark types (ols, poisson, logit)
just summarize-ols      # Generate OLS plots from combined results
just summarize          # Generate all plots

# System information
just system-info        # Show CPU, RAM, OS, and package versions
```

> **Note:** When using `just bench-ols` or `just bench-all`, the combine and summarize
> steps run automatically. You only need to run `just combine-*` manually if you're
> running individual language benchmarks separately (e.g., `just bench-python-ols`).

#### Benchmark Pipeline Architecture

Each language runs in its own isolated process and outputs results to a separate CSV file:

```
generate-data
    └─> data/benchmark/*.parquet

bench-python-ols ─> results/bench_python_ols.csv
bench-r-ols      ─> results/bench_r_ols.csv
bench-julia-ols  ─> results/bench_julia_ols.csv

combine-ols
    └─> results/bench_ols.csv (merged from all languages)

summarize-ols
    └─> results/plot_ols.svg, results/plot_ols.pdf
```

This isolated architecture is important because:

1. **JIT compilation persists** - Python's numba compiles once and reuses across all iterations within the same process
2. **Fair comparison** - Each language runs independently without interference
3. **Flexibility** - You can re-run a single language without affecting others
4. **Debugging** - Easy to isolate issues to a specific language

When running `just bench-ols` or `just bench-all`, all steps execute automatically.
If you run individual language benchmarks separately, you must combine before summarizing:

```bash
# After running bench-python-ols, bench-r-ols, bench-julia-ols separately:
just combine-ols        # Only combines OLS results
just summarize-ols      # Only generates OLS plots

# Or combine everything at once:
just combine-all        # Combines ols + poisson + logit
just summarize          # Generates all plots
```

Each combine command is independent - `combine-ols` only affects `bench_ols.csv`,
not `bench_poisson.csv` or `bench_logit.csv`.

#### Filtering Datasets

All benchmark commands support an optional filter to run only specific datasets.
For example, to run only "simple" datasets (excluding "difficult"):

```bash
# Filter by dataset name pattern
just bench-ols simple           # Only simple datasets
just bench-python-ols simple    # Python only, simple datasets
just bench-all simple           # All benchmarks, simple datasets only
```

Run `just` to see all available commands.

## Simulation DGP

The code below is used to generate the simulated data for the
benchmarks. The function creates a balanced panel of individuals over a
specified number of years. Additionally workers are assigned to firms.
There are three fixed effects: individual, firm, and year.

How the firms are assigned to individuals can be controlled by the
`type` argument. In the `simple` case, individuals are assigned to firms
randomly. This creates a very “dense” network of individuals and firms
so estimation is relatively fast.

In the `difficult` case, individuals are assigned to firms so as to
create a very “sparse” network. This makes estimation more difficult and
time-consuming. These can be seen as two extreme cases and where a
particular dataset may fall depends on the specific application.


<details closed>
  <summary>DGP Code</summary>
  
``` r

base_dgp <- function(
  n = 1000,
  nb_year = 10,
  nb_indiv_per_firm = 23,
  type = c("simple", "difficult")
) {
  nb_indiv = round(n / nb_year)
  nb_firm = round(nb_indiv / nb_indiv_per_firm)
  indiv_id = rep(1:nb_indiv, each = nb_year)
  year = rep(1:nb_year, times = nb_indiv)

  if (type == "simple") {
    firm_id = sample(1:nb_firm, n, TRUE)
  } else if (type == "difficult") {
    firm_id = rep(1:nb_firm, length.out = n)
  } else {
    stop("Unknown type of dgp")
  }

  x1 = rnorm(n)
  x2 = x1**2

  firm_fe = rnorm(nb_firm)[firm_id]
  unit_fe = rnorm(nb_indiv)[indiv_id]
  year_fe = rnorm(nb_year)[year]
  mu = 1 * x1 + 0.05 * x2 + firm_fe + unit_fe + year_fe
  y = mu + rnorm(length(mu))

  df = data.frame(
    indiv_id = indiv_id,
    firm_id = firm_id,
    year = year,
    x1 = x1,
    x2 = x2,
    y = y,
    exp_y = exp(y),
    negbin_y = MASS::rnegbin(exp(y), theta = 0.5),
    binary_y = as.numeric(y > 0)
  )
  return(df)
}
```
</details>


### OLS Results

![OLS Benchmark Results](results/plot_ols.svg)

### Poisson Results

![Poisson Benchmark Results](results/plot_poisson.svg)

### Logistic Results

![Logistic Benchmark Results](results/plot_logit.svg)

### Real Data

tba