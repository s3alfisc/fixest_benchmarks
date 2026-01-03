#!/usr/bin/env Rscript
# Combine benchmark results from R, Python, and Julia into unified CSV files

library(data.table)
library(here)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
benchmark_type <- if (length(args) >= 1) args[1] else "ols"

# Define input and output files
results_dir <- here("results")
input_files <- list(
  r = file.path(results_dir, sprintf("bench_r_%s.csv", benchmark_type)),
  python = file.path(results_dir, sprintf("bench_python_%s.csv", benchmark_type)),
  julia = file.path(results_dir, sprintf("bench_julia_%s.csv", benchmark_type))
)
output_file <- file.path(results_dir, sprintf("bench_%s.csv", benchmark_type))

cat("================================================================================\n")
cat(sprintf("COMBINING RESULTS: %s\n", toupper(benchmark_type)))
cat("================================================================================\n\n")

# Read and combine all results
all_results <- data.table()

for (lang in names(input_files)) {
  filepath <- input_files[[lang]]
  if (file.exists(filepath)) {
    cat(sprintf("Reading %s results: %s\n", lang, basename(filepath)))
    dt <- fread(filepath)
    dt[, language := lang]
    all_results <- rbindlist(list(all_results, dt), fill = TRUE, use.names = TRUE)
  } else {
    cat(sprintf("Skipping %s (file not found: %s)\n", lang, basename(filepath)))
  }
}

if (nrow(all_results) == 0) {
  cat("\nNo results to combine!\n")
  quit(status = 1)
}

# Reorder columns
setcolorder(all_results, c("iter", "time", "est_name", "n_fe", "dgp_name", "n_obs", "language"))

# Sort by n_obs, dgp_name, est_name, n_fe, iter
setorder(all_results, n_obs, dgp_name, est_name, n_fe, iter)

# Write combined results
fwrite(all_results, output_file)

cat("\n")
cat("================================================================================\n")
cat("COMBINATION COMPLETE\n")
cat("================================================================================\n")
cat(sprintf("Total rows: %d\n", nrow(all_results)))
cat(sprintf("Output file: %s\n", output_file))

# Print summary statistics
cat("\n")
cat("Summary by estimator:\n")
print(all_results[, .(
  mean_time = mean(time, na.rm = TRUE),
  n_runs = sum(!is.na(time)),
  n_failed = sum(is.na(time))
), by = .(est_name, n_fe)][order(est_name, n_fe)])
