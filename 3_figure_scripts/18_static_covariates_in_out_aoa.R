#!/usr/bin/env Rscript
# Script: 18_static_covariates_in_out_aoa.R
# Objective: Reproduce Fig. 18 showing violin plots of static covariates within and outside the AOA.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Static raster layers, irrigation raster, and the RF study-area AOA raster.
# Outputs: 3_figure_scripts/generated/fig_18_static_covariates_in_out_aoa.png
# Usage: Rscript 3_figure_scripts/18_static_covariates_in_out_aoa.R
# Dependencies: raster, vioplot

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

library(raster)
library(vioplot)

extract_masked_values <- function(source_raster, mask_raster, mask_value) {
  values <- getValues(mask(source_raster, mask_raster, maskvalue = mask_value))
  values[!is.na(values)]
}

plot_violin_panel <- function(value_list, fill_color, panel_tag, sample_size) {
  vioplot(
    value_list[[1]],
    value_list[[2]],
    value_list[[3]],
    value_list[[4]],
    value_list[[5]],
    col   = fill_color,
    xaxt  = "n",
    ylim  = c(-0.1, 1),
    names = c("DEM", "AWC", "Clay", "Sand", "Irrigation")
  )
  legend(
    "topleft",
    legend = paste0("(", panel_tag, ") N = ", format(sample_size, big.mark = ",")),
    bty    = "n"
  )

  medians <- vapply(value_list, stats::median, numeric(1), na.rm = TRUE)
  points(seq_along(value_list), medians, col = "red", pch = 19, cex = 1.4)
  text(seq_along(value_list), -0.08, labels = format_medians(medians), col = "red", cex = 0.9)
}

data_root       <- get_data_root()
static_dir      <- file.path(data_root, "0_static_layers", "100m")
irrigation_path <- "/datasets/work/d61-af-soilmoisture/work/agri_drought/irrigation_area/gmia_v5_aei_pct.asc"
aoa_path        <- file.path(data_root, "6_aoa_metrics", "study_area", "aoa_major_rf_spatial_cv.tif")

dem  <- raster(file.path(static_dir, "dem_100m.tif"))
awc  <- raster(file.path(static_dir, "awc_100m.tif"))
clay <- raster(file.path(static_dir, "clay_100m.tif"))
sand <- raster(file.path(static_dir, "sand_100m.tif"))

dem <- calc(dem, fun = normalise_min_max)
awc <- calc(awc, fun = normalise_min_max)

irrigation                  <- raster(irrigation_path)
projection(irrigation)      <- "+proj=longlat +datum=WGS84 +no_defs"
irrigation                  <- projectRaster(irrigation, dem, method = "ngb")
irrigation                  <- irrigation * 0.01
irrigation[irrigation == 0] <- NA

aoa <- raster(aoa_path)
aoa <- aggregate(aoa, fact = 10, fun = max, na.rm = TRUE)
aoa <- resample(aoa, dem, method = "ngb")

within_aoa <- list(
  dem        = extract_masked_values(dem, aoa, 0),
  awc        = extract_masked_values(awc, aoa, 0),
  clay       = extract_masked_values(clay, aoa, 0),
  sand       = extract_masked_values(sand, aoa, 0),
  irrigation = extract_masked_values(irrigation, aoa, 0)
)
outside_aoa <- list(
  dem        = extract_masked_values(dem, aoa, 1),
  awc        = extract_masked_values(awc, aoa, 1),
  clay       = extract_masked_values(clay, aoa, 1),
  sand       = extract_masked_values(sand, aoa, 1),
  irrigation = extract_masked_values(irrigation, aoa, 1)
)

open_png("fig_18_static_covariates_in_out_aoa.png", width = 1400, height = 600, pointsize = 18)
layout(matrix(seq_len(2), nrow = 1))
par(mar = c(4, 3, 2, 2))

plot_violin_panel(within_aoa, "#4c78a8", "a", length(within_aoa$dem))
plot_violin_panel(outside_aoa, "#f58518", "b", length(outside_aoa$dem))

dev.off()
