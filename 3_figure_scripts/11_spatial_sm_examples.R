#!/usr/bin/env Rscript
# Script: 11_spatial_sm_examples.R
# Objective: Reproduce Fig. 11 showing spatial soil-moisture examples for RF and XGB in summer and winter.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Upscaled SM rasters plus study-area AOA rasters under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_11_spatial_sm_examples.png
# Usage: Rscript 3_figure_scripts/11_spatial_sm_examples.R
# Dependencies: raster

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(raster)

get_aoa_outline <- function(model_name, data_root) {
  aoa_raster <- raster(
    file.path(data_root, "6_aoa_metrics", "study_area", paste0("aoa_major_", model_name, "_spatial_cv.tif"))
  )
  aoa_raster[aoa_raster == 0] <- NA
  aoa_raster                  <- aggregate(aoa_raster, fact = 10, fun = max, na.rm = TRUE)
  rasterToPolygons(aoa_raster, fun = function(x) { x == 1 }, dissolve = TRUE)
}

plot_sm_panel <- function(sm_raster, panel_tag, draw_boxes = FALSE, aoa_outline = NULL) {
  plot(
    sm_raster,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    zlim   = c(0, 0.5),
    col    = sm_palette()
  )
  add_panel_tag(panel_tag)

  if (draw_boxes) {
    rect(146.06, -34.77, 146.16, -34.67, border = "black", lwd = 2)
    rect(146.25, -35.02, 146.35, -34.92, border = "black", lwd = 2)
  }

  if (!is.null(aoa_outline)) {
    plot(aoa_outline, add = TRUE, border = "black", lwd = 1.5)
  }
}

plot_zoom_pair <- function(global_raster, local_raster, panel_tags) {
  global_crop <- crop(global_raster, extent(local_raster))
  plot_sm_panel(global_crop, panel_tags[1])
  plot_sm_panel(local_raster, panel_tags[2])
}

data_root        <- get_data_root()
plot_dates       <- as.Date(c("2017-02-01", "2017-08-01"))
cluster_a_extent <- extent(146.06, 146.16, -34.77, -34.67)
cluster_b_extent <- extent(146.25, 146.35, -35.02, -34.92)
rf_aoa_outline   <- get_aoa_outline("rf", data_root)
xgb_aoa_outline  <- get_aoa_outline("xgb", data_root)
panel_tags       <- c(letters, paste0("a", letters[1:10]))

open_png("fig_11_spatial_sm_examples.png", width = 2000, height = 1600, pointsize = 18)
layout(matrix(seq_len(20), nrow = 4, byrow = TRUE))
par(mar = c(0.5, 0.5, 0.5, 0.5))

for (date_idx in seq_along(plot_dates)) {
  date_value <- plot_dates[date_idx]

  rf_global <- raster(
    file.path(
      data_root,
      "4_upscaled_sm",
      "study_area",
      "global",
      "rf",
      paste0("Upscaled_SM_rf_daily_100m_", format(date_value, "%Y%m%d"), ".tif")
    )
  )
  rf_cluster_a <- crop(
    raster(
      file.path(
        data_root,
        "4_upscaled_sm",
        "study_area",
        "clusterA",
        "rf",
        paste0("Upscaled_SM_rf_daily_100m_cluster_A_", format(date_value, "%Y%m%d"), ".tif")
      )
    ),
    cluster_a_extent
  )
  rf_cluster_b <- raster(
    file.path(
      data_root,
      "4_upscaled_sm",
      "study_area",
      "clusterB",
      "rf",
      paste0("Upscaled_SM_rf_daily_100m_cluster_B_", format(date_value, "%Y%m%d"), ".tif")
    )
  )

  xgb_global <- raster(
    file.path(
      data_root,
      "4_upscaled_sm",
      "study_area",
      "global",
      "xgb",
      paste0("Upscaled_SM_xgb_daily_100m_", format(date_value, "%Y%m%d"), ".tif")
    )
  )
  xgb_cluster_a <- crop(
    raster(
      file.path(
        data_root,
        "4_upscaled_sm",
        "study_area",
        "clusterA",
        "xgb",
        paste0("Upscaled_SM_xgb_daily_100m_cluster_A_", format(date_value, "%Y%m%d"), ".tif")
      )
    ),
    cluster_a_extent
  )
  xgb_cluster_b <- raster(
    file.path(
      data_root,
      "4_upscaled_sm",
      "study_area",
      "clusterB",
      "xgb",
      paste0("Upscaled_SM_xgb_daily_100m_cluster_B_", format(date_value, "%Y%m%d"), ".tif")
    )
  )

  rf_cluster_b_crop  <- crop(rf_global, extent(rf_cluster_b))
  xgb_cluster_b_crop <- crop(xgb_global, extent(xgb_cluster_b))

  offset <- (date_idx - 1) * 10

  plot_sm_panel(rf_global, panel_tags[offset + 1], draw_boxes = TRUE, aoa_outline = rf_aoa_outline)
  plot_zoom_pair(rf_global, rf_cluster_a, panel_tags[(offset + 2):(offset + 3)])
  plot_zoom_pair(rf_cluster_b_crop, rf_cluster_b, panel_tags[(offset + 4):(offset + 5)])

  plot_sm_panel(xgb_global, panel_tags[offset + 6], draw_boxes = TRUE, aoa_outline = xgb_aoa_outline)
  plot_zoom_pair(xgb_global, xgb_cluster_a, panel_tags[(offset + 7):(offset + 8)])
  plot_zoom_pair(xgb_cluster_b_crop, xgb_cluster_b, panel_tags[(offset + 9):(offset + 10)])
}

dev.off()

