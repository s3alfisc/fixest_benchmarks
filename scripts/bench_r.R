#!/usr/bin/env Rscript
# R benchmark runner for fixed-effect estimation
# Runs fixest and lfe benchmarks on pre-generated parquet data

library(arrow)
library(fixest)
library(lfe)
library(here)

# Configuration
N_THREADS <- 8L
options(lfe.threads = N_THREADS)
setFixest_nthreads(N_THREADS)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
benchmark_type <- if (length(args) >= 1) args[1] else "ols"
data_dir <- if (length(args) >= 2) args[2] else here("data", "benchmark")
output_file <- if (length(args) >= 3) args[3] else here("results", "bench_r.csv")
filter_pattern <- if (length(args) >= 4) args[4] else NULL

# Timer functions
feols_timer <- function(data, fml, nthreads = N_THREADS) {
  start_time <- Sys.time()
  result <- feols(fml, data = data, notes = FALSE, warn = FALSE, nthreads = nthreads)
  as.numeric(Sys.time() - start_time, units = "secs")
}

fepois_timer <- function(data, fml) {
  start_time <- Sys.time()
  result <- fepois(fml, data = data, notes = FALSE, warn = FALSE)
  as.numeric(Sys.time() - start_time, units = "secs")
}

feglm_logit_timer <- function(data, fml) {
  start_time <- Sys.time()
  result <- feglm(fml, data = data, family = "logit", notes = FALSE, warn = FALSE)
  as.numeric(Sys.time() - start_time, units = "secs")
}

lfe_timer <- function(data, fml) {
  start_time <- Sys.time()
  result <- felm(fml, data = data)
  as.numeric(Sys.time() - start_time, units = "secs")
}

# Define estimators and formulas by benchmark type
get_estimators <- function(type) {
  if (type == "ols") {
    list(
      estimators = list(
        list(name = "fixest::feols", func = feols_timer),
        list(name = "lfe::felm", func = lfe_timer)
      ),
      formulas = list(
        list(n_fe = 2L, fixest = y ~ x1 | indiv_id + year, lfe = y ~ x1 | indiv_id + year),
        list(n_fe = 3L, fixest = y ~ x1 | indiv_id + year + firm_id, lfe = y ~ x1 | indiv_id + year + firm_id)
      )
    )
  } else if (type == "poisson") {
    list(
      estimators = list(
        list(name = "fixest::fepois", func = fepois_timer)
      ),
      formulas = list(
        list(n_fe = 2L, fixest = negbin_y ~ x1 | indiv_id + year),
        list(n_fe = 3L, fixest = negbin_y ~ x1 | indiv_id + year + firm_id)
      )
    )
  } else if (type == "logit") {
    list(
      estimators = list(
        list(name = "fixest::feglm_logit", func = feglm_logit_timer)
      ),
      formulas = list(
        list(n_fe = 2L, fixest = binary_y ~ x1 | indiv_id + year),
        list(n_fe = 3L, fixest = binary_y ~ x1 | indiv_id + year + firm_id)
      )
    )
  } else {
    stop("Unknown benchmark type: ", type)
  }
}

# Parse dataset name to get dgp_type and n_obs
parse_dataset_name <- function(name) {
  size_map <- list(
    "1k" = 1000L,
    "10k" = 10000L,
    "100k" = 100000L,
    "500k" = 500000L,
    "1m" = 1000000L,
    "2m" = 2000000L
  )
  parts <- strsplit(name, "_")[[1]]
  dgp_type <- parts[1]
  n_str <- parts[2]
  n_obs <- size_map[[n_str]]
  list(dgp_type = dgp_type, n_obs = n_obs)
}

# Main benchmark function
run_benchmark <- function(data_dir, output_file, benchmark_type, filter_pattern = NULL) {
  config <- get_estimators(benchmark_type)

  # Get all parquet files
  parquet_files <- sort(list.files(data_dir, pattern = "\\.parquet$", full.names = TRUE))
  if (length(parquet_files) == 0) {
    stop("No parquet files found in ", data_dir)
  }

  # Group files by dataset
  datasets <- list()
  for (f in parquet_files) {
    basename <- tools::file_path_sans_ext(basename(f))
    parts <- strsplit(basename, "_")[[1]]
    # e.g., "simple_1k_burnin_1" -> ds_name = "simple_1k", iter_type = "burnin", iter_num = 1
    n_parts <- length(parts)
    ds_name <- paste(parts[1:(n_parts - 2)], collapse = "_")
    iter_type <- parts[n_parts - 1]
    iter_num <- as.integer(parts[n_parts])

    # Apply filter if specified
    if (!is.null(filter_pattern) && !grepl(filter_pattern, ds_name)) {
      next
    }

    if (is.null(datasets[[ds_name]])) {
      datasets[[ds_name]] <- list()
    }
    datasets[[ds_name]] <- c(datasets[[ds_name]], list(list(
      iter_type = iter_type,
      iter_num = iter_num,
      filepath = f
    )))
  }

  results <- data.frame()

  cat("\n")
  cat("================================================================================\n")
  cat(sprintf("R BENCHMARK: %s\n", toupper(benchmark_type)))
  cat("================================================================================\n")
  filter_info <- if (!is.null(filter_pattern)) sprintf(" | Filter: '%s'", filter_pattern) else ""
  cat(sprintf("Estimators: %d | FE configs: %d | Threads: %d%s\n",
              length(config$estimators), length(config$formulas), N_THREADS, filter_info))

  for (ds_name in sort(names(datasets))) {
    parsed <- parse_dataset_name(ds_name)
    dgp_type <- parsed$dgp_type
    n_obs <- parsed$n_obs

    cat("\n")
    cat("--------------------------------------------------------------------------------\n")
    cat(sprintf("Dataset: %s (n=%s)\n", ds_name, format(n_obs, big.mark = ",")))
    cat("--------------------------------------------------------------------------------\n")

    # Sort files: burnin first, then iter
    files <- datasets[[ds_name]]
    files <- files[order(sapply(files, function(x) {
      if (x$iter_type == "burnin") 0 else 1
    }), sapply(files, function(x) x$iter_num))]

    for (file_info in files) {
      iter_type <- file_info$iter_type
      iter_num <- file_info$iter_num
      filepath <- file_info$filepath

      cat(sprintf("\n[%s %d] Loading %s...\n", iter_type, iter_num, basename(filepath)))
      data <- read_parquet(filepath)

      for (fml_config in config$formulas) {
        n_fe <- fml_config$n_fe

        for (est in config$estimators) {
          est_name <- est$name
          func <- est$func

          # Get appropriate formula
          if (grepl("lfe", est_name)) {
            fml <- fml_config$lfe
          } else {
            fml <- fml_config$fixest
          }

          cat(sprintf("  -> %-35s (FE=%d) ... ", est_name, n_fe))
          flush.console()

          elapsed <- tryCatch({
            func(data, fml)
          }, error = function(e) {
            NA_real_
          })

          if (is.na(elapsed)) {
            cat("FAILED\n")
          } else {
            cat(sprintf("%.3fs\n", elapsed))
          }

          # Only record non-burnin iterations
          if (iter_type != "burnin") {
            results <- rbind(results, data.frame(
              iter = iter_num,
              time = elapsed,
              est_name = est_name,
              n_fe = n_fe,
              dgp_name = dgp_type,
              n_obs = n_obs
            ))
          }
        }
      }
    }
  }

  cat("\n")
  cat("================================================================================\n")
  cat("BENCHMARK COMPLETE\n")
  cat("================================================================================\n")

  # Write results
  if (!dir.exists(dirname(output_file))) {
    dir.create(dirname(output_file), recursive = TRUE)
  }
  write.csv(results, output_file, row.names = FALSE)
  cat(sprintf("\nResults written to: %s\n", output_file))
}

# Run benchmark
run_benchmark(data_dir, output_file, benchmark_type, filter_pattern)
