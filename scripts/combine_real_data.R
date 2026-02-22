#!/usr/bin/env Rscript
# Combine real-data benchmark results from R, Python, and Julia

library(data.table)
library(here)

args <- commandArgs(trailingOnly = TRUE)
benchmark_type <- if (length(args) >= 1) args[1] else "ols"

results_dir <- here("results")
input_files <- list(
  r = file.path(results_dir, sprintf("bench_real_data_%s_r.csv", benchmark_type)),
  python = file.path(results_dir, sprintf("bench_real_data_%s_python.csv", benchmark_type)),
  julia = file.path(results_dir, sprintf("bench_real_data_%s_julia.csv", benchmark_type))
)
output_file <- file.path(results_dir, sprintf("bench_%s_real_data.csv", benchmark_type))

cat("================================================================================\n")
cat(sprintf("COMBINING REAL-DATA RESULTS: %s\n", toupper(benchmark_type)))
cat("================================================================================\n\n")

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

setcolorder(all_results, c("iter", "time", "est_name", "n_fe", "dgp_name", "n_obs", "language"))
setorder(all_results, dgp_name, est_name, n_fe, iter)
fwrite(all_results, output_file)

cat("\n")
cat("================================================================================\n")
cat("COMBINATION COMPLETE\n")
cat("================================================================================\n")
cat(sprintf("Total rows: %d\n", nrow(all_results)))
cat(sprintf("Output file: %s\n", output_file))
