# %%
source("setup.R")
source("dgp_functions.R")
options(lfe.threads = 8)
setFixest_nthreads(8)

# %%
# fmt: skip
bench_poisson_small <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "simple", 10L, 1e3, list(\() base_dgp(n = 1e3, type = "simple")),
    "simple", 10L, 1e4, list(\() base_dgp(n = 1e4, type = "simple")),
    "simple",  5L, 1e5, list(\() base_dgp(n = 1e5, type = "simple")),
    "difficult", 10L, 1e3, list(\() base_dgp(n = 1e3, type = "difficult")),
    "difficult", 10L, 1e4, list(\() base_dgp(n = 1e4, type = "difficult")),
    "difficult",  3L, 1e5, list(\() base_dgp(n = 1e5, type = "difficult"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "pyfixest.fepois", 2L, list(\(df) {
      pyfixest_fepois_timer(
        df,
        "exp_y ~ x1 | indiv_id + year"
      )
    }),
    "GLFixedEffectModels Poisson", 2L, list(\(df) {
      julia_call(
        "jl_poisson_timer",
        df,
        "exp_y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "alpaca Poisson", 2L, list(\(df) {
      alpaca_poisson_timer(
        df,
        exp_y ~ x1 | indiv_id + year
      )
    }),
    "fixest::fepois", 2L, list(\(df) {
      fepois_timer(
        df,
        exp_y ~ x1 | indiv_id + year
      )
    }),
    "pyfixest.fepois", 3L, list(\(df) {
      pyfixest_fepois_timer(
        df,
        "exp_y ~ x1 | indiv_id + firm_id + year"
      )
    }),
    "GLFixedEffectModels Poisson", 3L, list(\(df) {
      julia_call(
        "jl_poisson_timer",
        df,
        "exp_y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
      )
    }),
    "alpaca Poisson", 3L, list(\(df) {
      alpaca_poisson_timer(
        df,
        exp_y ~ x1 | indiv_id + firm_id + year      
      )
    }),
    "fixest::fepois", 3L, list(\(df) {
      fepois_timer(
        df,
        exp_y ~ x1 | indiv_id + firm_id + year      
      )
    })
  )
)

# %%
# fmt: skip
bench_poisson_large <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "simple",  3L, 5e5, list(\() base_dgp(n = 5e5, type = "simple")),
    "difficult",  3L, 5e5, list(\() base_dgp(n = 5e5, type = "difficult")),
    "simple",  3L, 1e6, list(\() base_dgp(n = 1e6, type = "simple")),
    "difficult",  3L, 1e6, list(\() base_dgp(n = 1e6, type = "difficult"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "pyfixest.fepois", 2L, list(\(df) {
      pyfixest_fepois_timer(
        df,
        "exp_y ~ x1 | indiv_id + year"
      )
    }),
    "GLFixedEffectModels Poisson", 2L, list(\(df) {
      julia_call(
        "jl_poisson_timer",
        df,
        "exp_y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "fixest::fepois", 2L, list(\(df) {
      fepois_timer(
        df,
        exp_y ~ x1 | indiv_id + year
      )
    }),
    "pyfixest.fepois", 3L, list(\(df) {
      pyfixest_fepois_timer(
        df,
        "exp_y ~ x1 | indiv_id + firm_id + year"
      )
    }),
    "GLFixedEffectModels Poisson", 3L, list(\(df) {
      julia_call(
        "jl_poisson_timer",
        df,
        "exp_y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
      )
    }),
    "fixest::fepois", 3L, list(\(df) {
      fepois_timer(
        df,
        exp_y ~ x1 | indiv_id + firm_id + year      
      )
    })
  )
)

# Combine results
bench_poisson <- rbind(bench_poisson_small, bench_poisson_large)

# %%
if (!dir.exists(here("results"))) {
  dir.create(here("results"))
}
write_and_print_csv(
  bench_poisson,
  here("results", "bench_poisson.csv"),
  row.names = FALSE
)
