# %%
source("setup.R")
source("dgp_functions.R")
options(lfe.threads = 2)
setFixest_nthreads(2)

# %%
# fmt: skip
bench_ols_small <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "simple",    10L, 1e3, list(\() base_dgp(n = 1e3, type = "simple")),
    "difficult", 10L, 1e3, list(\() base_dgp(n = 1e3, type = "difficult")),
    "simple",    10L, 1e4, list(\() base_dgp(n = 1e4, type = "simple")),
    "difficult", 10L, 1e4, list(\() base_dgp(n = 1e4, type = "difficult")),
    "simple",    10L, 1e5, list(\() base_dgp(n = 1e5, type = "simple")),
    "difficult",  5L, 1e5, list(\() base_dgp(n = 1e5, type = "difficult")),
    "simple",     5L, 5e5, list(\() base_dgp(n = 5e5, type = "simple")),
    "difficult",  5L, 5e5, list(\() base_dgp(n = 5e5, type = "difficult")),
    "simple",     3L, 1e6, list(\() base_dgp(n = 1e6, type = "simple")),
    "simple",     3L, 2e6, list(\() base_dgp(n = 2e6, type = "simple"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "pyfixest.feols (rust)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 2L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "fixest::feols", 2L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year
      )
    }),
    "pyfixest.feols (rust)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 3L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"
      )
    }),
    "fixest::feols", 3L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year + firm_id
      )
    })
  )
)

# fmt: skip
bench_ols_medium <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "difficult",  3L, 1e6, list(\() base_dgp(n = 1e6, type = "difficult"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "pyfixest.feols (rust)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 2L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "fixest::feols", 2L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year
      )
    }),
    "pyfixest.feols (rust)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 3L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"
      )
    }),
    "fixest::feols", 3L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year + firm_id
      )
    })
  )
)

# fmt: skip
bench_ols_large <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, dgp_function=,
    "difficult",  3L, 2e6, list(\() base_dgp(n = 2e6, type = "difficult"))
  ),
  estimators = data.table::rowwiseDT(
    est_name=, n_fe=, func=,
    "pyfixest.feols (rust)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 2L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 2L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year)"
      )
    }),
    "fixest::feols", 2L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year
      )
    }),
    "pyfixest.feols (rust)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust"
      )
    }),
    "pyfixest.feols (rust-accelerated)", 3L, list(\(df) {
      pyfixest_feols_timer(
        df,
        "y ~ x1 | indiv_id + year + firm_id",
        backend = "rust-accelerated"
      )
    }),
    "FixedEffectModels.reg", 3L, list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "y ~ x1 + fe(indiv_id) + fe(year) + fe(firm_id)"
      )
    }),
    "fixest::feols", 3L, list(\(df) {
      feols_timer(
        df,
        y ~ x1 | indiv_id + year + firm_id
      )
    })
  )
)

bench_ols <- rbindlist(
  list(
    bench_ols_small,
    bench_ols_medium,
    bench_ols_large
  ),
  use.names = TRUE,
  fill = TRUE
)

# %%
# # fmt: skip
# bench_ols_multiple_y <- run_benchmark(
#   dgps = data.table::rowwiseDT(
#     dgp_name=, n_outcomes=, n_iters=, n_obs=, dgp_function=,
#     "difficult", 2L, 10L, 1e3,
#     list(\() base_dgp(n = 1e3, type = "difficult")),
#     "difficult", 2L, 10L, 1e4,
#     list(\() base_dgp(n = 1e4, type = "difficult")),
#     "difficult", 2L,  5L, 1e5,
#     list(\() base_dgp(n = 1e5, type = "difficult")),
#     "difficult", 2L,  5L, 5e5,
#     list(\() base_dgp(n = 5e5, type = "difficult")),
#     "difficult", 2L,  3L, 1e6,
#     list(\() base_dgp(n = 1e6, type = "difficult"))
#   ),
#   estimators = data.table::rowwiseDT(
#     est_name=, n_fe=, func=,
#     "pyfixest.feols", 1L, list(\(df) {
#       pyfixest_feols_timer(
#         df,
#         "y + exp_y ~ x1 | indiv_id + firm_id + year"
#       )
#     }),
#     "FixedEffectModels.reg", 1L, list(\(df) {
#       julia_call(
#         "jl_feols_timer",
#         df,
#         "y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
#       ) +
#       julia_call(
#         "jl_feols_timer",
#         df,
#         "exp_y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
#       )
#     }),
#     "fixest::feols", 1L, list(\(df) {
#       feols_timer(
#         df,
#         c(y, exp_y) ~ x1 | indiv_id + firm_id + year
#       )
#     })
#   )
# )

# %%
# # fmt: skip
# bench_ols_multiple_vcov <- run_benchmark(
#   dgps = data.table::rowwiseDT(
#     dgp_name=, vcov_uses=, n_iters=, n_obs=, dgp_function=,
#     "difficult", "hc1 + clustered", 10L, 1e3,
#     list(\() base_dgp(n = 1e3, type = "difficult")),
#     "difficult", "hc1 + clustered", 10L, 1e4,
#     list(\() base_dgp(n = 1e4, type = "difficult")),
#     "difficult", "hc1 + clustered",  5L, 1e5,
#     list(\() base_dgp(n = 1e5, type = "difficult")),
#     "difficult", "hc1 + clustered",  5L, 5e5,
#     list(\() base_dgp(n = 5e5, type = "difficult")),
#     "difficult", "hc1 + clustered",  3L, 1e6,
#     list(\() base_dgp(n = 1e6, type = "difficult"))
#   ),
#   estimators = data.table::rowwiseDT(
#     est_name=, n_fe=, func=,
#     "pyfixest.feols", 1L, list(\(df) {
#       pyfixest_feols_multiple_vcov_timer(
#         df,
#         "y ~ x1 | indiv_id + firm_id + year",
#         "firm_id"
#       )
#     }),
#     "FixedEffectModels.reg", 1L, list(\(df) {
#       julia_call(
#         "jl_feols_timer",
#         df,
#         "y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)"
#       ) +
#       julia_call(
#         "jl_feols_timer",
#         df,
#         "y ~ x1 + fe(indiv_id) + fe(firm_id) + fe(year)",
#         vcov = "firm_id"
#       )
#     }),
#     "fixest::feols", 1L, list(\(df) {
#       feols_multiple_vcov_timer(
#         df,
#         y  ~ x1 | indiv_id + firm_id + year,
#         cluster = ~firm_id
#       )
#     })
#   )
# )

# %%
if (!dir.exists(here("results"))) {
  dir.create(here("results"))
}
write_and_print_csv(
  bench_ols,
  here("results", "bench_ols.csv"),
  row.names = FALSE
)
# write_and_print_csv(
#   bench_ols_multiple_y,
#   here("results", "bench_ols_multiple_y.csv"),
#   row.names = FALSE
# )
# write_and_print_csv(
#   bench_ols_multiple_vcov,
#   here("results", "bench_ols_multiple_vcov.csv"),
#   row.names = FALSE
# )
