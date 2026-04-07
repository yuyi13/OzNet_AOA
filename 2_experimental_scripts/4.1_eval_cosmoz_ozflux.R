#!/usr/bin/env Rscript
# Script: 4.1_eval_cosmoz_ozflux.R
# Objective: Evaluate the archived global and cross-cluster soil-moisture models against CosmOz and OzFlux observations at Yanco.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Extracted CosmOz and OzFlux predictor tables plus trained caret model objects.
# Outputs: Bias, ubRMSE, and correlation CSV summaries in /datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/cosmoz_ozflux/.
# Usage: Rscript 2_experimental_scripts/4.1_eval_cosmoz_ozflux.R
# Dependencies: R packages caret, randomForest, xgboost

library(caret)
library(randomForest)
library(xgboost)

data_root   <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/2_extracted_timeseries"
model_root  <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/3_model_fitting/caret"
output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/cosmoz_ozflux"

predictor_names <- c(
  "dem", "awc", "clay", "silt", "sand",
  "lst_100m", "albedo_100m", "ndvi_100m", "et_100m",
  "tavg", "vpd", "srad", "rain"
)

periods <- list(
  cross_validation = seq(as.Date("2016-01-01"), as.Date("2020-12-31"), by = "day"),
  test_period      = seq(as.Date("2021-01-01"), as.Date("2021-09-13"), by = "day")
)

network_configs <- list(
  CosmOz = list(
    input_file     = file.path(data_root, "CosmOz_Yanco_extracted_data.csv"),
    scale_observed = FALSE
  ),
  OzFlux = list(
    input_file     = file.path(data_root, "OzFlux_Yanco_extracted_data.csv"),
    scale_observed = TRUE
  )
)

model_specs <- list(
  rf  = list(
    global_file        = file.path(model_root, "rf_model_caret_4fold_spatial_cv.rds"),
    cross_cluster_file = file.path(model_root, "rf_model_caret_cross_cluster.rds")
  ),
  xgb = list(
    global_file        = file.path(model_root, "xgb_model_caret_4fold_spatial_cv.rds"),
    cross_cluster_file = file.path(model_root, "xgb_model_caret_cross_cluster.rds")
  )
)

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

rescale_zero_one <- function(values) {
  if (all(is.na(values))) {
    return(values)
  }

  value_range <- range(values, na.rm = TRUE)
  if (diff(value_range) == 0) {
    return(rep(NA_real_, length(values)))
  }

  (values - value_range[1]) / diff(value_range)
}

build_metric_row <- function(period_name, network_name, global_values, cross_values, sample_number) {
  data.frame(
    period        = period_name,
    network       = network_name,
    global        = global_values,
    cross_cluster = cross_values,
    sample_number = sample_number
  )
}

calculate_metrics <- function(eval_df) {
  if (nrow(eval_df) == 0) {
    return(list(bias = NA_real_, ubrmse = NA_real_, cor = NA_real_))
  }

  list(
    bias   = mean(eval_df$value_fitted - eval_df$value_true),
    ubrmse = stats::sd(eval_df$value_fitted - eval_df$value_true),
    cor    = stats::cor(eval_df$value_fitted, eval_df$value_true)
  )
}

for (model_name in names(model_specs)) {
  global_model        <- readRDS(model_specs[[model_name]]$global_file)
  cross_cluster_model <- readRDS(model_specs[[model_name]]$cross_cluster_file)

  row_count   <- length(periods) * length(network_configs)
  bias_rows   <- vector("list", row_count)
  ubrmse_rows <- vector("list", row_count)
  cor_rows    <- vector("list", row_count)
  row_index   <- 1L

  for (period_name in names(periods)) {
    period_dates <- periods[[period_name]]

    for (network_name in names(network_configs)) {
      network_config <- network_configs[[network_name]]
      sm_df          <- read.csv(network_config$input_file)

      if (network_config$scale_observed) {
        sm_df$insitu_sm <- rescale_zero_one(sm_df$insitu_sm)
      }

      keep_columns <- c("time", "insitu_sm", predictor_names)
      sm_df        <- sm_df[, keep_columns, drop = FALSE]
      sm_df        <- stats::na.omit(sm_df)

      period_index      <- which(as.Date(sm_df$time) %in% period_dates)
      response_select   <- sm_df$insitu_sm[period_index]
      predictors_select <- sm_df[period_index, predictor_names, drop = FALSE]

      if (nrow(predictors_select) == 0) {
        bias_rows[[row_index]]   <- build_metric_row(period_name, network_name, NA_real_, NA_real_, 0L)
        ubrmse_rows[[row_index]] <- build_metric_row(period_name, network_name, NA_real_, NA_real_, 0L)
        cor_rows[[row_index]]    <- build_metric_row(period_name, network_name, NA_real_, NA_real_, 0L)
        row_index                <- row_index + 1L
        next
      }

      global_pred <- rescale_zero_one(stats::predict(global_model, newdata = predictors_select))
      cross_pred  <- rescale_zero_one(stats::predict(cross_cluster_model, newdata = predictors_select))

      global_df <- stats::na.omit(
        data.frame(value_true = response_select, value_fitted = global_pred)
      )
      cross_df <- stats::na.omit(
        data.frame(value_true = response_select, value_fitted = cross_pred)
      )

      sample_number  <- min(nrow(global_df), nrow(cross_df))
      global_metrics <- calculate_metrics(global_df)
      cross_metrics  <- calculate_metrics(cross_df)

      bias_rows[[row_index]] <- build_metric_row(
        period_name,
        network_name,
        round(global_metrics$bias, 2),
        round(cross_metrics$bias, 2),
        sample_number
      )
      ubrmse_rows[[row_index]] <- build_metric_row(
        period_name,
        network_name,
        round(global_metrics$ubrmse, 2),
        round(cross_metrics$ubrmse, 2),
        sample_number
      )
      cor_rows[[row_index]] <- build_metric_row(
        period_name,
        network_name,
        round(global_metrics$cor, 2),
        round(cross_metrics$cor, 2),
        sample_number
      )

      row_index <- row_index + 1L
    }
  }

  write.table(
    do.call(rbind, bias_rows),
    file      = file.path(output_root, paste0("bias_", model_name, ".csv")),
    row.names = FALSE,
    sep       = ",",
    quote     = FALSE
  )
  write.table(
    do.call(rbind, ubrmse_rows),
    file      = file.path(output_root, paste0("ubrmse_", model_name, ".csv")),
    row.names = FALSE,
    sep       = ",",
    quote     = FALSE
  )
  write.table(
    do.call(rbind, cor_rows),
    file      = file.path(output_root, paste0("correlation_", model_name, ".csv")),
    row.names = FALSE,
    sep       = ",",
    quote     = FALSE
  )
}
