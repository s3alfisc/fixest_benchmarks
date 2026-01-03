# %%
library(nycflights13)
library(tradepolicy)
library(arrow)
source("setup.R")


# %%
# fmt: skip
bench_ols_flights <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, n_fe=, dgp_function=,
    "nycflights13", 5L, nrow(nycflights13::flights), 3L, list(\() 
    nycflights13::flights)
  ),
  estimators = data.table::rowwiseDT(
    est_name=, func=,
    "pyfixest.feols", list(\(df) {
      pyfixest_feols_timer(
        df,
        "arr_delay ~ distance | carrier + origin + dest"
      )
    }),
    "FixedEffectModels.reg", list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "arr_delay ~ distance + fe(carrier) + fe(origin) + fe(dest)",
        nthreads = 8L
      )
    }),
    "fixest::feols", list(\(df) {
      feols_timer(
        df,
        arr_delay ~ distance | carrier + origin + dest,
        nthreads = 8L
      )
    })
  )
)

# %%
# From https://github.com/pachadotdev/capybara/blob/main/dev/benchmarks-no-base.R
ch1_application3 <- tradepolicy::agtpa_applications |>
  as.data.table() |>
  _[year %in% seq(1986, 2006, 4), ] |>
  _[, `:=`(
    exp_year = paste0(exporter, year),
    imp_year = paste0(importer, year),
    year = paste0("intl_border_", year),
    log_trade = log(trade),
    log_dist = log(dist),
    intl_brdr = ifelse(exporter == importer, pair_id, "inter"),
    intl_brdr_2 = ifelse(exporter == importer, 0, 1),
    pair_id_2 = ifelse(exporter == importer, "0-intra", pair_id)
  )] |>
  dcast(... ~ year, value.var = "intl_brdr_2", fill = 0) |>
  _[, sum_trade := sum(trade), by = pair_id]

# fmt: skip
bench_tradepolicy_ols <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, n_fe=, dgp_function=,
    "tradepolicy (OLS)", 5L, nrow(ch1_application3), 3L, list(\() ch1_application3)
  ),
  estimators = data.table::rowwiseDT(
    est_name=, func=,
    "pyfixest.feols", list(\(df) {
      pyfixest_feols_timer(
        df,
        "trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 | exp_year + imp_year + pair_id_2"
      )
    }),
    "FixedEffectModels.reg", list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 + fe(exp_year) + fe(imp_year) + fe(pair_id_2)",
        nthreads = 8L
      )
    }),
    "fixest::feols", list(\(df) {
      feols_timer(
        df,
        trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 | exp_year + imp_year + pair_id_2,
        nthreads = 8L
      )
    })
  )
)

# # fmt: skip
# bench_tradepolicy_ppml <- run_benchmark(
#   dgps = data.table::rowwiseDT(
#     dgp_name=, n_iters=, n_obs=, n_fe=, dgp_function=,
#     "tradepolicy (Poisson)", 5L, nrow(ch1_application3), 3L, list(\() ch1_application3)
#   ),
#   estimators = data.table::rowwiseDT(
#     est_name=, func=,
#     "pyfixest.fepois", list(\(df) {
#       pyfixest_fepois_timer(
#         df,
#         "trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 | exp_year + imp_year + pair_id_2"
#       )
#     }),
#     "GLFixedEffectModels Poisson", list(\(df) {
#       julia_call(
#         "jl_poisson_timer",
#         df,
#         "trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 + fe(exp_year) + fe(imp_year) + fe(pair_id_2)"
#       )
#     }),
#     "fixest::fepois", list(\(df) {
#       fepois_timer(
#         df,
#         trade ~ rta + rta_lag4 + rta_lag8 + rta_lag12 + intl_border_1986 + intl_border_1990 + intl_border_1994 + intl_border_1998 + intl_border_2002 | exp_year + imp_year + pair_id_2
#       )
#     })
#   )
# )

rm(ch1_application3)

# %%
# Load medicare claims data
# fmt: skip
medicare <- fread(
  here("data/Medicare_Provider_Util_Payment_PUF_CY2016.txt"),
  sep = "\t",
  skip = 2, # firstobs = 3 in SAS means skip first 2 lines
  header = FALSE,
  col.names = c("npi", "nppes_provider_last_org_name", "nppes_provider_first_name", "nppes_provider_mi", "nppes_credentials", "nppes_provider_gender", "nppes_entity_code", "nppes_provider_street1", "nppes_provider_street2", "nppes_provider_city", "nppes_provider_zip", "nppes_provider_state", "nppes_provider_country", "provider_type", "medicare_participation_indicator", "place_of_service", "hcpcs_code", "hcpcs_description", "hcpcs_drug_indicator", "line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "average_submitted_chrg_amt", "average_Medicare_payment_amt", "average_Medicare_standard_amt"),
  colClasses = list(
    character = c("npi", "nppes_provider_last_org_name", "nppes_provider_first_name", "nppes_provider_mi", "nppes_credentials", "nppes_provider_gender", "nppes_entity_code", "nppes_provider_street1", "nppes_provider_street2", "nppes_provider_city", "nppes_provider_zip", "nppes_provider_state", "nppes_provider_country", "provider_type", "medicare_participation_indicator", "place_of_service", "hcpcs_code", "hcpcs_description", "hcpcs_drug_indicator"),
    numeric = c("line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "average_submitted_chrg_amt", "average_Medicare_payment_amt", "average_Medicare_standard_amt")
  )
)

# fmt: skip
bench_medicare_ols <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, n_fe=, dgp_function=,
    "Medicare Provider", 3L, nrow(medicare), 3L, list(\() medicare)
  ),
  estimators = data.table::rowwiseDT(
    est_name=, func=,
    "pyfixest.feols", list(\(df) {
      pyfixest_feols_timer(
        df,
        "average_Medicare_payment_amt ~ line_srvc_cnt + bene_unique_cnt | nppes_provider_state + provider_type + hcpcs_code"
      )
    }),
    "FixedEffectModels.reg", list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "average_Medicare_payment_amt ~ line_srvc_cnt + bene_unique_cnt + fe(nppes_provider_state) + fe(provider_type) + fe(hcpcs_code)",
        nthreads = 8L
      )
    }),
    "fixest::feols", list(\(df) {
      feols_timer(
        df,
        average_Medicare_payment_amt ~ line_srvc_cnt + bene_unique_cnt | nppes_provider_state + provider_type + hcpcs_code,
        nthreads = 8L
      )
    })
  )
)

rm(medicare)

# %%
nyc <- read_parquet(here("data/nyc_taxi.parquet"))

# fmt: skip
bench_nyc_taxi_ols <- run_benchmark(
  dgps = data.table::rowwiseDT(
    dgp_name=, n_iters=, n_obs=, n_fe=, dgp_function=,
    "nyc taxi", 5L, nrow(nyc), 3L, list(\() nyc)
  ),
  estimators = data.table::rowwiseDT(
    est_name=, func=,
    "pyfixest.feols", list(\(df) {
      pyfixest_feols_timer(
        df,
        "tip_amount ~ trip_distance + passenger_count | dofw + vendor_id + payment_type"
      )
    }),
    "FixedEffectModels.reg", list(\(df) {
      julia_call(
        "jl_feols_timer",
        df,
        "tip_amount ~ trip_distance + passenger_count + fe(dofw) + fe(vendor_id) + fe(payment_type)",
        nthreads = 8L
      )
    }),
    "fixest::feols", list(\(df) {
      feols_timer(
        df,
        tip_amount ~ trip_distance + passenger_count | dofw + vendor_id + payment_type,
        nthreads = 8L
      )
    })
  )
)

rm(nyc)

# %%
bench_real_data <- rbindlist(
  list(
    bench_ols_flights,
    bench_tradepolicy_ols,
    # bench_tradepolicy_ppml,
    bench_nyc_taxi_ols,
    bench_medicare_ols
  ),
  use.names = TRUE,
  fill = TRUE
)

write_and_print_csv(
  bench_real_data,
  here("results", "bench_ols_real_data.csv"),
  row.names = FALSE
)
