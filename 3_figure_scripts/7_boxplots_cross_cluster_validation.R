#!/usr/bin/env Rscript
# Script: 7_boxplots_cross_cluster_validation.R
# Objective: Reproduce Fig. 7 showing site-level cross-cluster validation metrics for RF and XGB.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: OzNet site metadata plus RF and XGB cross-cluster validation CSV files under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_07_boxplots_cross_cluster_validation.png
# Usage: Rscript 3_figure_scripts/7_boxplots_cross_cluster_validation.R
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

collect_cluster_metrics <- function(model_name, site_info, validation_dir) {
  metrics_df <- data.frame(
    site   = site_info$sitename,
    group  = ifelse(is.na(site_info$cluster), "Other sites", paste0("Cluster ", site_info$cluster)),
    bias   = NA_real_,
    ubrmse = NA_real_,
    r      = NA_real_
  )

  for (cluster_id in c("A", "B")) {
    validation_path <- file.path(
      validation_dir,
      paste0(model_name, "_validation_cluster_", cluster_id, ".csv")
    )
    validation_df <- read.csv(validation_path)
    target_idx    <- which(site_info$cluster == cluster_id)

    for (row_idx in target_idx) {
      site_name                                     <- site_info$sitename[row_idx]
      metrics_df[row_idx, c("bias", "ubrmse", "r")] <-
        compute_site_metrics(validation_df[validation_df$sitename == site_name, ])
    }
  }

  validation_df <- read.csv(file.path(validation_dir, paste0(model_name, "_validation_cluster_A+B.csv")))
  target_idx    <- which(is.na(site_info$cluster))

  for (row_idx in target_idx) {
    site_name                                     <- site_info$sitename[row_idx]
    metrics_df[row_idx, c("bias", "ubrmse", "r")] <-
      compute_site_metrics(validation_df[validation_df$sitename == site_name, ])
  }

  metrics_df
}

plot_group_metric <- function(metric_df, value_name, y_limits, y_label, panel_tag, colors, add_zero_line = FALSE) {
  ordered_groups <- c("Cluster A", "Cluster B", "Other sites")
  values         <- split(metric_df[[value_name]], factor(metric_df$group, levels = ordered_groups))

  boxplot(
    values,
    col   = colors,
    ylim  = y_limits,
    ylab  = y_label,
    xaxt  = "n"
  )
  stripchart(values, vertical = TRUE, add = TRUE, pch = 19, col = colors)

  if (add_zero_line) {
    abline(h = 0, lty = 2)
  }

  medians <- vapply(values, stats::median, numeric(1), na.rm = TRUE)
  text(
    x      = seq_along(values),
    y      = y_limits[1],
    labels = paste0("Median: ", format_medians(medians)),
    cex    = 0.8
  )
  legend("topright", legend = paste0("(", panel_tag, ")"), bty = "n")
}

oznet_sites    <- read_oznet_sites()
validation_dir <- file.path(get_data_root(), "3_model_fitting", "validation")

rf_metrics  <- collect_cluster_metrics("rf", oznet_sites, validation_dir)
xgb_metrics <- collect_cluster_metrics("xgb", oznet_sites, validation_dir)

open_png("fig_07_boxplots_cross_cluster_validation.png", width = 1650, height = 900, pointsize = 18)
layout(matrix(seq_len(6), nrow = 2, byrow = TRUE))
par(mar = c(4, 4, 2, 1))

rf_colors  <- c("#4c78a8", "#72b7b2", "#bab0ab")
xgb_colors <- c("#f58518", "#e45756", "#b279a2")

plot_group_metric(rf_metrics, "bias", c(-0.1, 0.15), "RF bias", "a", rf_colors, add_zero_line = TRUE)
plot_group_metric(rf_metrics, "ubrmse", c(0.03, 0.15), "RF ubRMSE", "b", rf_colors)
plot_group_metric(rf_metrics, "r", c(0.3, 0.85), "RF R", "c", rf_colors)
plot_group_metric(xgb_metrics, "bias", c(-0.1, 0.15), "XGB bias", "d", xgb_colors, add_zero_line = TRUE)
plot_group_metric(xgb_metrics, "ubrmse", c(0.03, 0.15), "XGB ubRMSE", "e", xgb_colors)
plot_group_metric(xgb_metrics, "r", c(0.3, 0.85), "XGB R", "f", xgb_colors)

dev.off()

