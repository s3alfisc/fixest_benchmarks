# Pyfixest timer functions using CSV + subprocess (no reticulate)

# Use pixi's Python environment (pyfixest built from source)
.pyfixest_python_path <- here::here("pyfixest", ".pixi", "envs", "dev", "bin", "python")
.pyfixest_cli_path <- here::here("timers", "pyfixest_cli.py")

.run_pyfixest_timer <- function(df, formula, method = "feols") {
  # Write data to temp CSV
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)
  data.table::fwrite(df, tmp_csv)

  # Call Python CLI

  cmd <- sprintf(
    '%s %s "%s" "%s" --method %s',
    shQuote(.pyfixest_python_path),
    shQuote(.pyfixest_cli_path),
    tmp_csv,
    formula,
    method
  )

  result <- system(cmd, intern = TRUE)

  # Parse elapsed time from stdout
  as.numeric(result)
}

pyfixest_feols_timer <- function(df, formula) {
  .run_pyfixest_timer(df, formula, method = "feols")
}

pyfixest_fepois_timer <- function(df, formula) {
  .run_pyfixest_timer(df, formula, method = "fepois")
}

pyfixest_feglm_logit_timer <- function(df, formula) {
  .run_pyfixest_timer(df, formula, method = "feglm_logit")
}

pyfixest_feols_multiple_vcov_timer <- function(df, formula, cluster) {
  # For now, just run feols - multiple vcov timing needs more complex handling
  .run_pyfixest_timer(df, formula, method = "feols")
}
