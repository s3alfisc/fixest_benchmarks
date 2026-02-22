#!/usr/bin/env Rscript
# R real-data benchmark runner (fixest)

library(arrow)
library(data.table)
library(fixest)
library(here)
library(jsonlite)

config_path <- here("config", "bench.json")
config <- if (file.exists(config_path)) fromJSON(config_path) else list()
real_cfg <- config$real_data

if (is.null(real_cfg) || length(real_cfg) == 0) {
  stop("No real_data config found in config/bench.json")
}

feols_timer <- function(data, fml, nthreads = 8L) {
  start_time <- Sys.time()
  _ <- feols(fml, data = data, notes = FALSE, warn = FALSE, nthreads = nthreads)
  as.numeric(Sys.time() - start_time, units = "secs")
}

fepois_timer <- function(data, fml) {
  start_time <- Sys.time()
  _ <- fepois(fml, data = data)
  as.numeric(Sys.time() - start_time, units = "secs")
}

feglm_logit_timer <- function(data, fml) {
  start_time <- Sys.time()
  _ <- feglm(fml, data = data, family = "logit", notes = FALSE, warn = FALSE)
  as.numeric(Sys.time() - start_time, units = "secs")
}

get_nthreads <- function() {
  if (!is.null(config$threads$r)) as.integer(config$threads$r) else 8L
}

results <- data.frame()
nthreads <- get_nthreads()
setFixest_nthreads(nthreads)

args <- commandArgs(trailingOnly = TRUE)
benchmark_type <- if (length(args) >= 1) args[1] else "ols"

cat("\n")
cat("================================================================================\n")
cat(sprintf("R REAL-DATA BENCHMARK (%s)\n", toupper(benchmark_type)))
cat("================================================================================\n")

for (i in seq_len(nrow(real_cfg))) {
  ds <- real_cfg[i, ]
  ds_name <- ds$name
  parquet_path <- here(ds$parquet)
  if (!file.exists(parquet_path)) {
    stop("Missing parquet file: ", parquet_path)
  }

  formulas <- ds$formulas[[benchmark_type]]
  if (is.null(formulas)) {
    next
  }
  fml <- formulas$r
  if (is.null(fml) || is.na(fml) || fml == "") {
    next
  }

  data <- read_parquet(parquet_path)
  n_obs <- nrow(data)
  n_iters <- as.integer(ds$n_iters)
  n_fe <- as.integer(ds$n_fe)

  cat(sprintf("\nDataset: %s (n=%s, iters=%d)\n", ds_name, format(n_obs, big.mark = ","), n_iters))

  for (iter in seq_len(n_iters)) {
    est_name <- if (benchmark_type == "poisson") "fixest::fepois" else if (benchmark_type == "logit") "fixest::feglm_logit" else "fixest::feols"
    cat(sprintf("  -> %s (iter %d/%d) ... ", est_name, iter, n_iters))
    flush.console()
    elapsed <- tryCatch({
      if (benchmark_type == "poisson") {
        fepois_timer(data, fml)
      } else if (benchmark_type == "logit") {
        feglm_logit_timer(data, fml)
      } else {
        feols_timer(data, fml, nthreads = nthreads)
      }
    }, error = function(e) {
      cat(sprintf("ERROR: %s\n", conditionMessage(e)))
      NA_real_
    })

    if (is.na(elapsed)) {
      # already printed error
    } else {
      cat(sprintf("%.3fs\n", elapsed))
    }

    results <- rbind(results, data.frame(
      iter = iter,
      time = elapsed,
      est_name = est_name,
      n_fe = n_fe,
      dgp_name = ds_name,
      n_obs = n_obs
    ))
  }
}

output_file <- here(sprintf("results/bench_real_data_%s_r.csv", benchmark_type))
write.csv(results, output_file, row.names = FALSE)
cat(sprintf("\nResults written to: %s\n", output_file))
