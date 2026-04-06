#!/usr/bin/env Rscript
# Script: 6_aoa_metrics.R
# Objective: Summarise the daily AOA outputs into median DI and majority AOA maps for each model and validation strategy.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Daily AOA NetCDF files from the spatial cross-validation and cross-cluster workflows.
# Outputs: Summary GeoTIFF rasters in /datasets/work/d61-af-soilmoisture/work/model_averaging/6_aoa_metrics/.
# Usage: Rscript 2_experimental_scripts/3_aoa_assessment/6_aoa_metrics.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)
aoa_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/5_sm_aoa"
output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/6_aoa_metrics"
dates_of_interest <- seq(as.Date("2016-01-01"), as.Date("2019-12-31"), by = "day")
model_names <- c("rf", "xgb")
cv_types <- c("spatial_cv", "cr_cluster")

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

for (model_name in model_names) {
  for (cv_type in cv_types) {
    message("Processing model: ", model_name, " and cv type: ", cv_type)

    aoa_files <- file.path(
      aoa_root,
      model_name,
      cv_type,
      paste0("sm_aoa_", model_name, "_", format(dates_of_interest, "%Y%m%d"), ".nc")
    )
    combined_stack <- rast(aoa_files)

    di_stack <- combined_stack[[seq(1, nlyr(combined_stack), by = 2)]]
    aoa_stack <- combined_stack[[seq(2, nlyr(combined_stack), by = 2)]]

    di_median <- app(di_stack, fun = median, na.rm = TRUE, cores = 40)
    aoa_mean <- app(aoa_stack, fun = mean, na.rm = TRUE, cores = 40)
    aoa_majority <- aoa_mean
    aoa_majority[aoa_majority > 0.5] <- 1
    aoa_majority[aoa_majority <= 0.5] <- 0

    writeRaster(
      di_median,
      filename = file.path(output_root, paste0("di_median_", model_name, "_", cv_type, ".tif")),
      overwrite = TRUE
    )
    writeRaster(
      aoa_majority,
      filename = file.path(output_root, paste0("aoa_major_", model_name, "_", cv_type, ".tif")),
      overwrite = TRUE
    )
  }
}
