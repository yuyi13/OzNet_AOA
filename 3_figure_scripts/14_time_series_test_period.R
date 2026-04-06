#!/usr/bin/env Rscript
# Script: 14_time_series_test_period.R
# Objective: Reproduce Fig. 14 showing test-period time series for RF and XGB against CosmOz and OzFlux.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Extracted time-series CSVs plus trained RF/XGB caret models under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_14_time_series_test_period.png
# Usage: Rscript 3_figure_scripts/14_time_series_test_period.R
# Dependencies: caret, randomForest, xgboost

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(caret)
library(randomForest)
library(xgboost)

predict_wetness <- function(model_object, predictors_df) {
  normalise_min_max(as.numeric(predict(model_object, newdata = predictors_df)))
}

load_network_series <- function(data_root, network_name) {
  csv_path <- file.path(data_root, "2_extracted_timeseries", paste0(network_name, "_Yanco_extracted_data.csv"))
  sm_df <- read.csv(csv_path)

  if (network_name == "OzFlux") {
    sm_df$insitu_sm <- normalise_min_max(sm_df$insitu_sm)
  }

  sm_df
}

prepare_predictions <- function(sm_df, rf_model_cv, rf_model_cc, xgb_model_cv, xgb_model_cc) {
  complete_idx <- which(stats::complete.cases(sm_df))
  predictor_idx <- c(5:9, 13:20)

  sm_df$rf_cv <- sm_df$rf_cc <- sm_df$xgb_cv <- sm_df$xgb_cc <- NA_real_

  if (length(complete_idx) > 0) {
    predictors_df <- sm_df[complete_idx, predictor_idx]

    sm_df$rf_cv[complete_idx] <- predict_wetness(rf_model_cv, predictors_df)
    sm_df$rf_cc[complete_idx] <- predict_wetness(rf_model_cc, predictors_df)
    sm_df$xgb_cv[complete_idx] <- predict_wetness(xgb_model_cv, predictors_df)
    sm_df$xgb_cc[complete_idx] <- predict_wetness(xgb_model_cc, predictors_df)
  }

  sm_df
}

plot_time_series_panel <- function(sm_df, date_range, network_label, model_label, cv_col, cc_col, colors, panel_tag) {
  selected_idx <- which(as.Date(sm_df$time) %in% date_range)
  rain_series <- sm_df$rain[selected_idx]
  rain_series[rain_series == 0] <- NA

  plot(
    as.POSIXct(sm_df$time[selected_idx]),
    rain_series,
    type = "h",
    axes = FALSE,
    col  = "grey80",
    lwd  = 4,
    xlab = "",
    ylab = ""
  )
  axis(side = 4, cex.axis = 1.1)

  par(new = TRUE)
  plot(
    as.POSIXct(sm_df$time[selected_idx]),
    sm_df[[cv_col]][selected_idx],
    type = "l",
    col  = colors[1],
    ylim = c(0, 1.1),
    lwd  = 2.5,
    xlab = "",
    ylab = "Wetness"
  )
  lines(as.POSIXct(sm_df$time[selected_idx]), sm_df[[cc_col]][selected_idx], col = colors[2], lwd = 2.5)
  lines(as.POSIXct(sm_df$time[selected_idx]), sm_df$insitu_sm[selected_idx], col = "black", lwd = 2.5)

  legend(
    "topleft",
    legend = paste0("(", panel_tag, ") ", network_label, " (", model_label, ")"),
    bty    = "n"
  )

  metrics_df <- sm_df[selected_idx, c("insitu_sm", cv_col, cc_col)]
  metrics_df <- metrics_df[stats::complete.cases(metrics_df), ]

  cv_metrics <- c(
    mean(metrics_df[[cv_col]] - metrics_df$insitu_sm),
    stats::sd(metrics_df[[cv_col]] - metrics_df$insitu_sm),
    stats::cor(metrics_df[[cv_col]], metrics_df$insitu_sm)
  )
  cc_metrics <- c(
    mean(metrics_df[[cc_col]] - metrics_df$insitu_sm),
    stats::sd(metrics_df[[cc_col]] - metrics_df$insitu_sm),
    stats::cor(metrics_df[[cc_col]], metrics_df$insitu_sm)
  )

  legend(
    "top",
    legend = c(
      paste0("CV: Bias = ", round(cv_metrics[1], 2), ", ubRMSE = ", round(cv_metrics[2], 2), ", R = ", round(cv_metrics[3], 2)),
      paste0("CC: Bias = ", round(cc_metrics[1], 2), ", ubRMSE = ", round(cc_metrics[2], 2), ", R = ", round(cc_metrics[3], 2))
    ),
    col = colors,
    lty = 1,
    bty = "n",
    cex = 0.85
  )
}

data_root <- get_data_root()
rf_model_cv <- readRDS(file.path(data_root, "3_model_fitting", "caret", "rf_model_caret_4fold_spatial_cv.rds"))
rf_model_cc <- readRDS(file.path(data_root, "3_model_fitting", "caret", "rf_model_caret_cross_cluster.rds"))
xgb_model_cv <- readRDS(file.path(data_root, "3_model_fitting", "caret", "xgb_model_caret_4fold_spatial_cv.rds"))
xgb_model_cc <- readRDS(file.path(data_root, "3_model_fitting", "caret", "xgb_model_caret_cross_cluster.rds"))
test_dates <- seq(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day")

cosmoz_df <- prepare_predictions(
  load_network_series(data_root, "CosmOz"),
  rf_model_cv,
  rf_model_cc,
  xgb_model_cv,
  xgb_model_cc
)
ozflux_df <- prepare_predictions(
  load_network_series(data_root, "OzFlux"),
  rf_model_cv,
  rf_model_cc,
  xgb_model_cv,
  xgb_model_cc
)

open_png("fig_14_time_series_test_period.png", width = 4000, height = 3200, pointsize = 16)
layout(matrix(seq_len(4), nrow = 4))
par(mar = c(3, 3, 0.5, 2.8))

plot_time_series_panel(cosmoz_df, test_dates, "CosmOz", "RF", "rf_cv", "rf_cc", c("#4c78a8", "#72b7b2"), "a")
plot_time_series_panel(cosmoz_df, test_dates, "CosmOz", "XGB", "xgb_cv", "xgb_cc", c("#f58518", "#e45756"), "b")
plot_time_series_panel(ozflux_df, test_dates, "OzFlux", "RF", "rf_cv", "rf_cc", c("#4c78a8", "#72b7b2"), "c")
plot_time_series_panel(ozflux_df, test_dates, "OzFlux", "XGB", "xgb_cv", "xgb_cc", c("#f58518", "#e45756"), "d")

dev.off()

