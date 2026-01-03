# %%
source("setup.R")
source("dgp_functions.R")
options(lfe.threads = 8)
setFixest_nthreads(8)

# %%
# fmt: skip
bench_logit_small <- run_benchmark(
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
    "GLFixedEffectModels logit", 2L, list(\(df) {
      julia_call(
        "jl_logit_timer",
        df,
        "binary_y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "alpaca logit", 2L, list(\(df) {
      alpaca_feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + year
      )
    }),
    "fixest logit", 2L, list(\(df) {
      feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + year
      )
    }),
    "GLFixedEffectModels logit", 3L, list(\(df) {
      julia_call(
        "jl_logit_timer",
        df,
        "binary_y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
      )
    }),
    "alpaca logit", 3L, list(\(df) {
      alpaca_feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + firm_id + year      
      )
    }),
    "fixest logit", 3L, list(\(df) {
      feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + firm_id + year      
      )
    })
  )
)

# fmt: skip
bench_logit_large <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "simple",  3L, 5e5, list(\() base_dgp(n = 5e5, type = "simple")),
    "difficult",  3L, 5e5, list(\() base_dgp(n = 5e5, type = "difficult")),
    "simple",  3L, 1e6, list(\() base_dgp(n = 1e6, type = "simple")),
    "difficult",  3L, 1e6, list(\() base_dgp(n = 1e6, type = "difficult"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "GLFixedEffectModels logit", 2L, list(\(df) {
      julia_call(
        "jl_logit_timer",
        df,
        "binary_y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "fixest logit", 2L, list(\(df) {
      feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + year
      )
    }),
    "GLFixedEffectModels logit", 3L, list(\(df) {
      julia_call(
        "jl_logit_timer",
        df,
        "binary_y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
      )
    }),
    "fixest logit", 3L, list(\(df) {
      feglm_logit_timer(
        df,
        binary_y ~ x1 | indiv_id + firm_id + year      
      )
    })
  )
)

# Combine results
bench_logit <- rbind(bench_logit_small, bench_logit_large)

# %%
if (!dir.exists(here("results"))) {
  dir.create(here("results"))
}
write_and_print_csv(
  bench_logit,
  here("results", "bench_logit.csv"),
  row.names = FALSE
)
