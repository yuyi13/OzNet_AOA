#!/usr/bin/env Rscript
# Script: 15_smap_performance_maps.R
# Objective: Reproduce Fig. 15 showing SMAP-based bias, ubRMSE, and R maps for RF and XGB in CV and test periods.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: RF/XGB SMAP evaluation NetCDF files plus study-area AOA rasters under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_15_smap_performance_maps.png
# Usage: Rscript 3_figure_scripts/15_smap_performance_maps.R
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
  aoa_raster <- aggregate(aoa_raster, fact = 10, fun = max, na.rm = TRUE)
  rasterToPolygons(aoa_raster, fun = function(x) { x == 1 }, dissolve = TRUE)
}

plot_metric_panel <- function(metric_raster, zlim, palette_values, panel_tag, add_boxes = FALSE, aoa_outline = NULL) {
  plot(
    metric_raster,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    zlim   = zlim,
    col    = palette_values
  )
  add_panel_tag(panel_tag, cex = 0.9)

  median_value <- round(stats::median(getValues(metric_raster), na.rm = TRUE), 2)
  legend("bottomleft", legend = paste0("Median: ", median_value), bty = "n", cex = 0.8)

  if (add_boxes) {
    rect(146.06, -34.77, 146.16, -34.67, border = "black", lwd = 1.5)
    rect(146.25, -35.02, 146.35, -34.92, border = "black", lwd = 1.5)
  }

  if (!is.null(aoa_outline)) {
    plot(aoa_outline, add = TRUE, border = "black", lwd = 1.2, lty = 2)
  }
}

data_root <- get_data_root()
smap_dir <- file.path(data_root, "7_evaluations", "smap_pixelwise")
cluster_a_extent <- extent(146.06, 146.16, -34.77, -34.67)
cluster_b_extent <- extent(146.25, 146.35, -35.02, -34.92)
yanco_template <- raster(
  ext = extent(146, 147, -35.3, -34.3),
  res = 0.01,
  crs = "+proj=longlat +datum=WGS84 +no_defs"
)
panel_tags <- c(letters, paste0("a", letters[1:10]))
rf_aoa_outline <- get_aoa_outline("rf", data_root)
xgb_aoa_outline <- get_aoa_outline("xgb", data_root)

open_png("fig_15_smap_performance_maps.png", width = 2400, height = 2400, pointsize = 14)
layout(matrix(seq_len(36), nrow = 6, byrow = TRUE))
par(mar = c(0.5, 0.5, 0.5, 0.5))

period_lookup <- c("cross-validation", "test_period")
panel_counter <- 1L

for (period_name in period_lookup) {
  rf_metrics <- stack(file.path(smap_dir, paste0("metrics_rf_", period_name, "_10km.nc")))
  xgb_metrics <- stack(file.path(smap_dir, paste0("metrics_xgb_", period_name, "_10km.nc")))

  rf_metrics <- projectRaster(rf_metrics, yanco_template, method = "ngb")
  xgb_metrics <- projectRaster(xgb_metrics, yanco_template, method = "ngb")

  for (region_name in c("study_area", "cluster_a", "cluster_b")) {
    if (region_name == "study_area") {
      rf_subset <- rf_metrics
      xgb_subset <- xgb_metrics
      add_boxes <- TRUE
    } else if (region_name == "cluster_a") {
      rf_subset <- crop(rf_metrics, cluster_a_extent)
      xgb_subset <- crop(xgb_metrics, cluster_a_extent)
      add_boxes <- FALSE
    } else {
      rf_subset <- crop(rf_metrics, cluster_b_extent)
      xgb_subset <- crop(xgb_metrics, cluster_b_extent)
      add_boxes <- FALSE
    }

    rf_bias <- rf_subset[[1]]
    rf_ubrmse <- rf_subset[[2]]
    rf_cor <- rf_subset[[3]]
    xgb_bias <- xgb_subset[[1]]
    xgb_ubrmse <- xgb_subset[[2]]
    xgb_cor <- xgb_subset[[3]]

    rf_bias[rf_bias < -0.08] <- -0.08
    rf_bias[rf_bias > 0.08] <- 0.08
    rf_ubrmse[rf_ubrmse > 0.15] <- 0.15
    rf_cor[rf_cor < 0] <- 0

    xgb_bias[xgb_bias < -0.08] <- -0.08
    xgb_bias[xgb_bias > 0.08] <- 0.08
    xgb_ubrmse[xgb_ubrmse > 0.15] <- 0.15
    xgb_cor[xgb_cor < 0] <- 0

    plot_metric_panel(
      rf_bias,
      c(-0.08, 0.08),
      grDevices::colorRampPalette(c("#2166ac", "#f7f7f7", "#b2182b"))(64),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) rf_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L

    plot_metric_panel(
      rf_ubrmse,
      c(0, 0.15),
      sm_palette(),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) rf_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L

    plot_metric_panel(
      rf_cor,
      c(0, 1),
      cor_palette(),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) rf_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L

    plot_metric_panel(
      xgb_bias,
      c(-0.08, 0.08),
      grDevices::colorRampPalette(c("#2166ac", "#f7f7f7", "#b2182b"))(64),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) xgb_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L

    plot_metric_panel(
      xgb_ubrmse,
      c(0, 0.15),
      sm_palette(),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) xgb_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L

    plot_metric_panel(
      xgb_cor,
      c(0, 1),
      cor_palette(),
      panel_tags[panel_counter],
      add_boxes = add_boxes,
      aoa_outline = if (add_boxes) xgb_aoa_outline else NULL
    )
    panel_counter <- panel_counter + 1L
  }
}

dev.off()

