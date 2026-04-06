#!/usr/bin/env Rscript
# Script: 12_hdas_comparison.R
# Objective: Reproduce Fig. 12 showing HDAS comparisons against RF and XGB predictions on four campaign dates.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: HDAS raster stack, campaign dates, and upscaled RF/XGB rasters under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_12_hdas_comparison.png
# Usage: Rscript 3_figure_scripts/12_hdas_comparison.R
# Dependencies: raster

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(raster)

plot_map_panel <- function(raster_layer, panel_tag, draw_extent = NULL) {
  plot(
    raster_layer,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    zlim   = c(0, 0.5),
    col    = sm_palette()
  )
  add_panel_tag(panel_tag)

  if (!is.null(draw_extent)) {
    rect(
      xmin(draw_extent),
      ymin(draw_extent),
      xmax(draw_extent),
      ymax(draw_extent),
      border = "black",
      lwd    = 2
    )
  }
}

format_fit <- function(fit_object) {
  paste0(
    "y = ",
    round(coef(fit_object)[2], 2),
    "x + ",
    round(coef(fit_object)[1], 2)
  )
}

plot_scatter_panel <- function(reference_values, cv_values, cc_values, colors, panel_tag) {
  comparison_df <- data.frame(hdas = reference_values, cv = cv_values, cc = cc_values)
  comparison_df <- comparison_df[stats::complete.cases(comparison_df), ]
  comparison_df <- comparison_df[abs(comparison_df$cv - comparison_df$hdas) <= 0.25, ]

  cv_fit <- lm(cv ~ hdas, data = comparison_df)
  cc_fit <- lm(cc ~ hdas, data = comparison_df)

  plot(
    comparison_df$hdas,
    comparison_df$cv,
    pch  = 15,
    col  = colors[1],
    xlim = c(0, 0.5),
    ylim = c(0, 0.5),
    xlab = "HDAS SM",
    ylab = "Predicted SM"
  )
  points(comparison_df$hdas, comparison_df$cc, pch = 16, col = colors[2])
  abline(a = 0, b = 1, lty = 2)
  abline(cv_fit, col = colors[1], lwd = 2, lty = 2)
  abline(cc_fit, col = colors[2], lwd = 2, lty = 2)

  legend("topleft", legend = paste0("(", panel_tag, ")"), bty = "n")
  legend(
    "bottomright",
    legend = c(
      paste0("CV: ", format_fit(cv_fit)),
      paste0("CC: ", format_fit(cc_fit)),
      paste0("N = ", nrow(comparison_df))
    ),
    col = c(colors, NA),
    pch = c(15, 16, NA),
    lty = c(NA, NA, NA),
    bty = "n"
  )
}

data_root <- get_data_root()
hdas_stack <- stack(file.path(data_root, "HDAS_Yanco", "hdas_spatial_stack.nc"))
metrics_df <- read.csv(file.path(data_root, "7_evaluations", "hdas_metrics.csv"))
selected_idx <- c(2, 3, 10, 11)
panel_tags <- c(letters, paste0("a", letters[1:10]))

rf_cv_dir <- file.path(data_root, "4_upscaled_sm", "study_area", "global", "rf")
rf_cc_dir <- file.path(data_root, "4_upscaled_sm", "study_area", "clusterA", "rf")
xgb_cv_dir <- file.path(data_root, "4_upscaled_sm", "100m", "global", "xgb")
xgb_cc_dir <- file.path(data_root, "4_upscaled_sm", "100m", "clusterA", "xgb")

open_png("fig_12_hdas_comparison.png", width = 3200, height = 2400, pointsize = 16)
layout(matrix(seq_len(28), nrow = 4, byrow = TRUE))
par(mar = c(1.8, 1.8, 1.5, 1.2))

for (row_idx in seq_along(selected_idx)) {
  metric_idx <- selected_idx[row_idx]
  date_value <- as.Date(metrics_df$date[metric_idx], format = "%Y-%m-%d")
  hdas_raster <- hdas_stack[[metric_idx]]
  hdas_extent <- extent(hdas_raster)

  rf_cv <- crop(
    raster(file.path(rf_cv_dir, paste0("Upscaled_SM_rf_daily_100m_", format(date_value, "%Y%m%d"), ".tif"))),
    hdas_extent
  )
  rf_cc <- crop(
    raster(file.path(rf_cc_dir, paste0("Upscaled_SM_rf_daily_100m_cluster_A_", format(date_value, "%Y%m%d"), ".tif"))),
    hdas_extent
  )
  xgb_cv <- crop(
    raster(file.path(xgb_cv_dir, paste0("Upscaled_SM_xgb_daily_100m_", format(date_value, "%Y%m%d"), ".tif"))),
    hdas_extent
  )
  xgb_cc <- crop(
    raster(file.path(xgb_cc_dir, paste0("Upscaled_SM_xgb_daily_100m_cluster_A_", format(date_value, "%Y%m%d"), ".tif"))),
    hdas_extent
  )

  tag_offset <- (row_idx - 1) * 7

  plot_map_panel(hdas_raster, panel_tags[tag_offset + 1])
  plot_map_panel(rf_cv, panel_tags[tag_offset + 2], draw_extent = hdas_extent)
  plot_map_panel(rf_cc, panel_tags[tag_offset + 3], draw_extent = hdas_extent)
  plot_scatter_panel(
    reference_values = getValues(hdas_raster),
    cv_values        = getValues(rf_cv),
    cc_values        = getValues(rf_cc),
    colors           = c("#4c78a8", "#72b7b2"),
    panel_tag        = panel_tags[tag_offset + 4]
  )
  plot_map_panel(xgb_cv, panel_tags[tag_offset + 5], draw_extent = hdas_extent)
  plot_map_panel(xgb_cc, panel_tags[tag_offset + 6], draw_extent = hdas_extent)
  plot_scatter_panel(
    reference_values = getValues(hdas_raster),
    cv_values        = getValues(xgb_cv),
    cc_values        = getValues(xgb_cc),
    colors           = c("#f58518", "#e45756"),
    panel_tag        = panel_tags[tag_offset + 7]
  )
}

dev.off()

