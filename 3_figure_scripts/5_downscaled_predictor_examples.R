#!/usr/bin/env Rscript
# Script: 5_downscaled_predictor_examples.R
# Objective: Reproduce Fig. 5 showing MODIS versus downscaled predictor examples for April 2, 2017.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: MODIS and downscaled albedo, NDVI, and LST rasters under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_05_downscaled_predictor_examples.png
# Usage: Rscript 3_figure_scripts/5_downscaled_predictor_examples.R
# Dependencies: raster

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(raster)

plot_predictor <- function(raster_layer, limits, palette_fn, panel_tag, zoom_box = FALSE) {
  plot(
    raster_layer,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    zlim   = limits,
    col    = palette_fn()
  )
  add_panel_tag(panel_tag)

  if (!zoom_box) {
    rect(146.25, -35.02, 146.35, -34.92, border = "black", lwd = 2.5)
  }
}

data_root   <- get_data_root()
doi         <- as.Date("2017-04-02")
zoom_extent <- extent(146.25, 146.35, -35.02, -34.92)

modis_albedo <- raster(
  file.path(
    data_root,
    "datafusion_yanco",
    "0_modis_albedo_masked",
    paste0("MCD43A4_albedo_NBAR_cloudrm_", format(doi, "%Y%m%d"), ".tif")
  )
)
downscaled_albedo <- raster(
  file.path(
    data_root,
    "1_downscaled_data",
    "albedo",
    paste0("ESTARFM_albedo_NBAR_cloudrm_", format(doi, "%Y%m%d"), ".tif")
  )
)
modis_ndvi <- raster(
  file.path(
    data_root,
    "datafusion_yanco",
    "0_modis_ndvi_masked",
    paste0("MCD43A4_NDVI_NBAR_cloudrm_", format(doi, "%Y%m%d"), ".tif")
  )
)
downscaled_ndvi <- raster(
  file.path(
    data_root,
    "1_downscaled_data",
    "NDVI",
    paste0("ESTARFM_NDVI_NBAR_cloudrm_", format(doi, "%Y%m%d"), ".tif")
  )
)
modis_lst <- raster(
  file.path(
    data_root,
    "datafusion_yanco",
    "0_modis_lst_masked",
    paste0("MOD11A1_LST_daytime_", format(doi, "%Y%m%d"), ".tif")
  )
)
downscaled_lst <- raster(
  file.path(
    data_root,
    "1_downscaled_data",
    "LST",
    paste0("ubESTARFM_LST_daytime_", format(doi, "%Y%m%d"), ".tif")
  )
)

albedo_limits <- c(0, 0.3)
ndvi_limits   <- c(0, 1)
lst_limits    <- c(290, 310)

open_png("fig_05_downscaled_predictor_examples.png", width = 1800, height = 2400, pointsize = 18)
layout(matrix(seq_len(12), nrow = 4, byrow = TRUE))
par(mar = c(0.3, 0.3, 0.3, 0.3))

plot_predictor(modis_albedo, albedo_limits, albedo_palette, "a")
plot_predictor(modis_ndvi, ndvi_limits, ndvi_palette, "b")
plot_predictor(modis_lst, lst_limits, lst_palette, "c")

plot_predictor(crop(modis_albedo, zoom_extent), albedo_limits, albedo_palette, "d", zoom_box = TRUE)
plot_predictor(crop(modis_ndvi, zoom_extent), ndvi_limits, ndvi_palette, "e", zoom_box = TRUE)
plot_predictor(crop(modis_lst, zoom_extent), lst_limits, lst_palette, "f", zoom_box = TRUE)

plot_predictor(downscaled_albedo, albedo_limits, albedo_palette, "g")
plot_predictor(downscaled_ndvi, ndvi_limits, ndvi_palette, "h")
plot_predictor(downscaled_lst, lst_limits, lst_palette, "i")

plot_predictor(crop(downscaled_albedo, zoom_extent), albedo_limits, albedo_palette, "j", zoom_box = TRUE)
plot_predictor(crop(downscaled_ndvi, zoom_extent), ndvi_limits, ndvi_palette, "k", zoom_box = TRUE)
plot_predictor(crop(downscaled_lst, zoom_extent), lst_limits, lst_palette, "l", zoom_box = TRUE)

dev.off()

