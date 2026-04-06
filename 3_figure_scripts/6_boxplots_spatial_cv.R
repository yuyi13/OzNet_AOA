#!/usr/bin/env Rscript
# Script: 6_boxplots_spatial_cv.R
# Objective: Reproduce Fig. 6 showing site-level bias, ubRMSE, and R for fourfold spatial cross-validation.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: OzNet site metadata plus RF and XGB validation CSV files under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_06_boxplots_spatial_cv.png
# Usage: Rscript 3_figure_scripts/6_boxplots_spatial_cv.R
# Dependencies: base R

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

compute_site_metrics <- function(validation_df) {
  validation_df <- validation_df[stats::complete.cases(validation_df), ]

  c(
    bias   = mean(validation_df$value_fitted - validation_df$value_true),
    ubrmse = stats::sd(validation_df$value_fitted - validation_df$value_true),
    r      = stats::cor(validation_df$value_fitted, validation_df$value_true)
  )
}

collect_iteration_metrics <- function(model_name, site_info, validation_dir) {
  metrics_df <- data.frame(
    site      = site_info$sitename,
    iteration = site_info$iteration,
    bias      = NA_real_,
    ubrmse    = NA_real_,
    r         = NA_real_
  )

  for (iteration_id in sort(unique(site_info$iteration))) {
    validation_path <- file.path(
      validation_dir,
      paste0(model_name, "_validation_iteration_", iteration_id, ".csv")
    )
    validation_df <- read.csv(validation_path)
    target_idx <- which(site_info$iteration == iteration_id)

    for (row_idx in target_idx) {
      site_name <- site_info$sitename[row_idx]
      site_metrics <- compute_site_metrics(validation_df[validation_df$sitename == site_name, ])
      metrics_df[row_idx, c("bias", "ubrmse", "r")] <- site_metrics
    }
  }

  metrics_df
}

plot_metric_boxplot <- function(metric_df, y_limits, y_label, panel_tag, add_zero_line = FALSE) {
  boxplot(
    metric_df,
    col  = c("#4c78a8", "#f58518"),
    ylim = y_limits,
    ylab = y_label,
    xaxt = "n"
  )
  stripchart(metric_df, vertical = TRUE, add = TRUE, pch = 19, col = c("#4c78a8", "#f58518"))

  if (add_zero_line) {
    abline(h = 0, lty = 2)
  }

  legend("topright", legend = paste0("(", panel_tag, ")"), bty = "n")
  text(
    x      = seq_len(ncol(metric_df)),
    y      = y_limits[1],
    labels = paste0("Median: ", format_medians(apply(metric_df, 2, stats::median, na.rm = TRUE))),
    cex    = 0.9
  )
}

oznet_sites <- read_oznet_sites()
validation_dir <- file.path(get_data_root(), "3_model_fitting", "validation")

rf_metrics <- collect_iteration_metrics("rf", oznet_sites, validation_dir)
xgb_metrics <- collect_iteration_metrics("xgb", oznet_sites, validation_dir)

bias_df <- data.frame(RF = rf_metrics$bias, XGB = xgb_metrics$bias)
ubrmse_df <- data.frame(RF = rf_metrics$ubrmse, XGB = xgb_metrics$ubrmse)
cor_df <- data.frame(RF = rf_metrics$r, XGB = xgb_metrics$r)

open_png("fig_06_boxplots_spatial_cv.png", width = 1650, height = 600, pointsize = 18)
layout(matrix(seq_len(3), nrow = 1))
par(mar = c(4, 4, 2, 1))

plot_metric_boxplot(bias_df, c(-0.1, 0.1), "Bias", "a", add_zero_line = TRUE)
plot_metric_boxplot(ubrmse_df, c(0, 0.15), "ubRMSE", "b")
plot_metric_boxplot(cor_df, c(0.3, 1), "R", "c")

dev.off()

