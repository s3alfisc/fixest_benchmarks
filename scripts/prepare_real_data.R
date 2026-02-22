#!/usr/bin/env Rscript
# Prepare real-world datasets for benchmarking (download if missing, write parquet)

library(arrow)
library(data.table)
library(here)
library(jsonlite)

config_path <- here("config", "bench.json")
config <- if (file.exists(config_path)) fromJSON(config_path) else list()
real_cfg <- config$real_data

if (is.null(real_cfg) || length(real_cfg) == 0) {
  stop("No real_data config found in config/bench.json")
}

real_dir <- here("data", "real")
if (!dir.exists(real_dir)) {
  dir.create(real_dir, recursive = TRUE)
}

ensure_nyc_taxi <- function() {
  taxi_parquet <- here("data", "nyc_taxi.parquet")
  if (!file.exists(taxi_parquet)) {
    source(here("data", "download_taxi.R"))
  }
  taxi_out <- here("data", "real", "nyc_taxi.parquet")
  if (!file.exists(taxi_out)) {
    file.copy(taxi_parquet, taxi_out, overwrite = TRUE)
  }
}

ensure_medicare <- function() {
  medicare_txt <- here("data", "Medicare_Provider_Util_Payment_PUF_CY2016.txt")
  if (!file.exists(medicare_txt)) {
    source(here("data", "download_medicare_payments.R"))
  }
  medicare_out <- here("data", "real", "medicare.parquet")
  if (!file.exists(medicare_out)) {
    medicare <- fread(
      medicare_txt,
      sep = "\t",
      skip = 2,
      header = FALSE,
      col.names = c("npi", "nppes_provider_last_org_name", "nppes_provider_first_name", "nppes_provider_mi", "nppes_credentials", "nppes_provider_gender", "nppes_entity_code", "nppes_provider_street1", "nppes_provider_street2", "nppes_provider_city", "nppes_provider_zip", "nppes_provider_state", "nppes_provider_country", "provider_type", "medicare_participation_indicator", "place_of_service", "hcpcs_code", "hcpcs_description", "hcpcs_drug_indicator", "line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "average_submitted_chrg_amt", "average_Medicare_payment_amt", "average_Medicare_standard_amt"),
      colClasses = list(
        character = c("npi", "nppes_provider_last_org_name", "nppes_provider_first_name", "nppes_provider_mi", "nppes_credentials", "nppes_provider_gender", "nppes_entity_code", "nppes_provider_street1", "nppes_provider_street2", "nppes_provider_city", "nppes_provider_zip", "nppes_provider_state", "nppes_provider_country", "provider_type", "medicare_participation_indicator", "place_of_service", "hcpcs_code", "hcpcs_description", "hcpcs_drug_indicator"),
        numeric = c("line_srvc_cnt", "bene_unique_cnt", "bene_day_srvc_cnt", "average_Medicare_allowed_amt", "average_submitted_chrg_amt", "average_Medicare_payment_amt", "average_Medicare_standard_amt")
      )
    )
    write_parquet(medicare, medicare_out)
  }
}

ensure_nycflights13 <- function() {
  flights_out <- here("data", "real", "nycflights13.parquet")
  if (!file.exists(flights_out)) {
    suppressPackageStartupMessages(library(nycflights13))
    write_parquet(nycflights13::flights, flights_out)
  }
}

ensure_tradepolicy <- function() {
  trade_out <- here("data", "real", "tradepolicy.parquet")
  if (!file.exists(trade_out)) {
    suppressPackageStartupMessages(library(tradepolicy))
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
    write_parquet(ch1_application3, trade_out)
  }
}

cat("Preparing real data (download on demand)...\n")
ensure_nyc_taxi()
ensure_medicare()
ensure_nycflights13()
ensure_tradepolicy()
cat("Real data ready in data/real\n")
