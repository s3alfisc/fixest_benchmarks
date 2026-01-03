# Pyfixest timer functions using CSV + subprocess (no reticulate)

# Use pixi's Python environment (pyfixest built from source)
.pyfixest_python_path <- here::here("pyfixest", ".pixi", "envs", "dev", "bin", "python")
.pyfixest_cli_path <- here::here("timers", "pyfixest_cli.py")

.run_pyfixest_timer <- function(df, formula, method = "feols", backend = "rust", timeout = 300L) {
  # Write data to temp CSV
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)
  data.table::fwrite(df, tmp_csv)

  # Call Python CLI
  cmd <- sprintf(
    '%s %s "%s" "%s" --method %s --backend %s --timeout %d',
    shQuote(.pyfixest_python_path),
    shQuote(.pyfixest_cli_path),
    tmp_csv,
    formula,
    method,
    backend,
    timeout
  )

  result <- system(cmd, intern = TRUE)

  # Check for OOM or TIMEOUT sentinel values
  if (length(result) == 0 || result %in% c("OOM", "TIMEOUT")) {
    return(NA_real_)
  }

  # Parse elapsed time from stdout
  as.numeric(result)
}

pyfixest_feols_timer <- function(df, formula, backend = "rust") {
  .run_pyfixest_timer(df, formula, method = "feols", backend = backend)
}

pyfixest_fepois_timer <- function(df, formula, backend = "rust") {
  .run_pyfixest_timer(df, formula, method = "fepois", backend = backend)
}

pyfixest_feglm_logit_timer <- function(df, formula, backend = "rust") {
  .run_pyfixest_timer(df, formula, method = "feglm_logit", backend = backend)
}

pyfixest_feols_multiple_vcov_timer <- function(df, formula, cluster, backend = "rust") {
  # For now, just run feols - multiple vcov timing needs more complex handling
  .run_pyfixest_timer(df, formula, method = "feols", backend = backend)
}

# linearmodels AbsorbingLS timer
# Formula format: "y ~ x1 | fe1 + fe2" (same as pyfixest/fixest)
absorbingls_timer <- function(df, formula, timeout = 300L) {
  .run_pyfixest_timer(df, formula, method = "absorbingls", timeout = timeout)
}

# statsmodels OLS timer (via formula API)
# Formula format: "y ~ x1 | fe1 + fe2" - FEs will be converted to C() dummies
# WARNING: This will likely OOM on large datasets due to dummy variable explosion
statsmodels_ols_timer <- function(df, formula, timeout = 300L) {
  .run_pyfixest_timer(df, formula, method = "statsmodels_ols", timeout = timeout)
}
