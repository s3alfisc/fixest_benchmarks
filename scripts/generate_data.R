#!/usr/bin/env Rscript
# Generate benchmark datasets and save to parquet for use by all languages
# This script creates reproducible datasets that R, Python, and Julia all use

library(arrow)
library(here)

source(here("dgp_functions.R"))

# Create data directory if needed
data_dir <- here("data", "benchmark")
if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE)
}

# Configuration: datasets to generate
# Format: name, n_obs, type
datasets <- list(
  list(name = "simple_1k",      n = 1e3,  type = "simple"),
  list(name = "difficult_1k",   n = 1e3,  type = "difficult"),
  list(name = "simple_10k",     n = 1e4,  type = "simple"),
  list(name = "difficult_10k",  n = 1e4,  type = "difficult"),
  list(name = "simple_100k",    n = 1e5,  type = "simple"),
  list(name = "difficult_100k", n = 1e5,  type = "difficult"),
  list(name = "simple_500k",    n = 5e5,  type = "simple"),
  list(name = "difficult_500k", n = 5e5,  type = "difficult"),
  list(name = "simple_1m",      n = 1e6,  type = "simple"),
  list(name = "difficult_1m",   n = 1e6,  type = "difficult"),
  list(name = "simple_2m",      n = 2e6,  type = "simple"),
  list(name = "difficult_2m",   n = 2e6,  type = "difficult")
)

# Number of iterations per dataset (including burn-in)
n_iters <- 3L
burn_in <- 1L

set.seed(20250725)

cat("================================================================================\n")
cat("GENERATING BENCHMARK DATASETS\n")
cat("================================================================================\n")
cat(sprintf("Output directory: %s\n", data_dir))
cat(sprintf("Iterations per dataset: %d (+ %d burn-in)\n", n_iters, burn_in))
cat("\n")

for (ds in datasets) {
  cat(sprintf("Dataset: %-20s (n=%s, type=%s)\n",
              ds$name, format(ds$n, big.mark = ","), ds$type))

  for (iter in seq_len(n_iters + burn_in)) {
    iter_type <- if (iter <= burn_in) "burnin" else "iter"
    iter_num <- if (iter <= burn_in) iter else iter - burn_in

    filename <- sprintf("%s_%s_%d.parquet", ds$name, iter_type, iter_num)
    filepath <- file.path(data_dir, filename)

    cat(sprintf("  -> %s ... ", filename))

    df <- base_dgp(n = ds$n, type = ds$type)
    write_parquet(df, filepath)

    cat(sprintf("done (%s rows)\n", format(nrow(df), big.mark = ",")))
  }
  cat("\n")
}

cat("================================================================================\n")
cat("DATA GENERATION COMPLETE\n")
cat("================================================================================\n")
cat(sprintf("Total files: %d\n", length(datasets) * (n_iters + burn_in)))
cat(sprintf("Location: %s\n", data_dir))
