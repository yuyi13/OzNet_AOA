#!/usr/bin/env Rscript
# Script: 4.3_compare_to_smap_10km.R
# Objective: Compare daily 100 m soil-moisture predictions aggregated to 10 km against SMAP L2 retrievals.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: SMAP 10 km NetCDF files and daily upscaled soil-moisture rasters.
# Outputs: NetCDF metric layers in /datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/smap_pixelwise/.
# Usage: Rscript 2_experimental_scripts/4.3_compare_to_smap_10km.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)
proj_latlon   <- "+proj=longlat +datum=WGS84"
smap_root     <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/SMAP/SMAP_L2_SM_vol"
upscaled_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/4_upscaled_sm/100m/global"
output_root   <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/smap_pixelwise"

periods <- list(
  cross_validation = seq(as.Date("2016-01-01"), as.Date("2019-12-31"), by = "day"),
  test_period      = seq(as.Date("2020-01-01"), as.Date("2021-12-31"), by = "day")
)
model_names <- c("rf", "xgb")
roi_10km    <- rast(xmin = 146, xmax = 147, ymin = -35.3, ymax = -34.3, resolution = 0.1, crs = proj_latlon)

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

pixel_cor <- function(sm_simulated_stack, sm_reference_stack) {
  sm_simulated_array <- as.array(sm_simulated_stack)
  sm_reference_array <- as.array(sm_reference_stack)

  n_row      <- dim(sm_reference_array)[1]
  n_col      <- dim(sm_reference_array)[2]
  cor_matrix <- matrix(NA_real_, nrow = n_row, ncol = n_col)

  for (row_index in seq_len(n_row)) {
    for (col_index in seq_len(n_col)) {
      cor_matrix[row_index, col_index] <- stats::cor(
        sm_simulated_array[row_index, col_index, ],
        sm_reference_array[row_index, col_index, ],
        use = "pairwise.complete.obs"
      )
    }
  }

  cor_raster      <- rast(cor_matrix, crs = crs(sm_reference_stack))
  ext(cor_raster) <- ext(sm_reference_stack)
  cor_raster
}

load_smap_stack <- function(years, roi_10km) {
  smap_stack <- rast()

  for (year_value in years) {
    smap_year  <- rast(file.path(smap_root, paste0("SMAP_Australia_", year_value, "_10km.nc")))
    smap_year  <- crop(smap_year, roi_10km)
    smap_stack <- c(smap_stack, smap_year)
  }

  smap_stack
}

smap_stack <- load_smap_stack(2016:2021, roi_10km)

for (period_name in names(periods)) {
  target_dates <- periods[[period_name]]
  smap_select  <- smap_stack[[which(time(smap_stack) %in% target_dates)]]

  for (model_name in model_names) {
    message("Processing ", model_name, " for ", period_name, "...")

    upscaled_stack <- rast(
      file.path(
        upscaled_root,
        model_name,
        paste0("Upscaled_SM_", model_name, "_daily_100m_", format(target_dates, "%Y%m%d"), ".tif")
      )
    )
    upscaled_10km <- aggregate(upscaled_stack, fact = 100, fun = mean, na.rm = TRUE)

    difference_stack <- upscaled_10km - smap_select
    bias_raster      <- app(difference_stack, fun = mean, na.rm = TRUE, cores = 32)
    ubrmse_raster    <- app(difference_stack, fun = stats::sd, na.rm = TRUE, cores = 32)
    cor_raster       <- pixel_cor(upscaled_10km, smap_select)

    metrics_stack        <- c(bias_raster, ubrmse_raster, cor_raster)
    names(metrics_stack) <- c("bias", "ubRMSE", "cor")

    writeCDF(
      metrics_stack,
      filename  = file.path(output_root, paste0("metrics_", model_name, "_", period_name, "_10km.nc")),
      varname   = "metrics",
      longname  = "bias, ubRMSE, and correlation",
      overwrite = TRUE
    )
  }
}
