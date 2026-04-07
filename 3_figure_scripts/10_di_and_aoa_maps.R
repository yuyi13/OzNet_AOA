#!/usr/bin/env Rscript
# Script: 10_di_and_aoa_maps.R
# Objective: Reproduce Fig. 10 showing study-area median DI and AOA maps for RF and XGB under CV and CC.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Median DI rasters, AOA rasters, and threshold RDS files under OZNET_AOA_DATA_ROOT.
# Outputs: 3_figure_scripts/generated/fig_10_di_and_aoa_maps.png
# Usage: Rscript 3_figure_scripts/10_di_and_aoa_maps.R
# Dependencies: raster

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(raster)

plot_di_panel <- function(di_raster, threshold_value, panel_tag) {
  di_raster[di_raster < 0] <- 0
  di_raster[di_raster > 5] <- 5

  plot(
    di_raster,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    zlim   = c(0, 5),
    col    = di_palette()
  )
  rect(146.06, -34.77, 146.16, -34.67, border = "black", lwd = 2)
  rect(146.25, -35.02, 146.35, -34.92, border = "black", lwd = 2)
  legend(
    "topleft",
    legend = paste0("(", panel_tag, ") Threshold = ", round(threshold_value, 2)),
    bty    = "n"
  )
}

plot_aoa_panel <- function(aoa_raster, panel_tag) {
  plot(
    aoa_raster,
    legend = FALSE,
    axes   = FALSE,
    box    = FALSE,
    col    = aoa_palette()
  )
  rect(146.06, -34.77, 146.16, -34.67, border = "black", lwd = 2)
  rect(146.25, -35.02, 146.35, -34.92, border = "black", lwd = 2)

  aoa_values <- getValues(aoa_raster)
  aoa_share  <- sum(aoa_values == 1, na.rm = TRUE) / sum(!is.na(aoa_values)) * 100

  legend(
    "topleft",
    legend = paste0("(", panel_tag, ") Area = ", round(aoa_share, 1), "%"),
    bty    = "n"
  )
}

data_root <- get_data_root()
aoa_dir   <- file.path(data_root, "6_aoa_metrics", "study_area")
caret_dir <- file.path(data_root, "3_model_fitting", "caret")

config <- data.frame(
  model            = c("rf", "rf", "xgb", "xgb"),
  caret_suffix     = c("4fold_spatial_cv", "cross_cluster", "4fold_spatial_cv", "cross_cluster"),
  aoa_suffix       = c("spatial_cv", "cr_cluster", "spatial_cv", "cr_cluster"),
  stringsAsFactors = FALSE
)

open_png("fig_10_di_and_aoa_maps.png", width = 1600, height = 800, pointsize = 18)
layout(matrix(seq_len(8), nrow = 2, byrow = TRUE))
par(mar = c(0.5, 0.5, 0.5, 0.5))

panel_tags <- letters[seq_len(8)]

for (row_idx in seq_len(nrow(config))) {
  threshold_info <- readRDS(
    file.path(
      caret_dir,
      paste0(config$model[row_idx], "_tdi_caret_", config$caret_suffix[row_idx], ".rds")
    )
  )
  di_raster <- raster(
    file.path(
      aoa_dir,
      paste0("di_median_", config$model[row_idx], "_", config$aoa_suffix[row_idx], ".tif")
    )
  )
  aoa_raster <- raster(
    file.path(
      aoa_dir,
      paste0("aoa_major_", config$model[row_idx], "_", config$aoa_suffix[row_idx], ".tif")
    )
  )

  plot_di_panel(di_raster, threshold_info$threshold, panel_tags[(row_idx - 1) * 2 + 1])
  plot_aoa_panel(aoa_raster, panel_tags[(row_idx - 1) * 2 + 2])
}

dev.off()
