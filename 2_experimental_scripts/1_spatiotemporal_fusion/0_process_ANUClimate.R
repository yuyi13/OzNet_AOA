#!/usr/bin/env Rscript
# Script: 0_process_ANUClimate.R
# Objective: Resample daily ANUClimate forcing layers to the 100 m OzNet study grid using nearest-neighbour and bilinear interpolation.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Monthly ANUClimate NetCDF files for tavg, vpd, srad, and rain.
# Outputs: Daily GeoTIFF layers in /datasets/work/d61-af-soilmoisture/work/model_averaging/ANUClim_yanco/.
# Usage: Rscript 2_experimental_scripts/1_spatiotemporal_fusion/0_process_ANUClimate.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)

proj_latlon <- "+proj=longlat +datum=WGS84"

anuclimate_root <- "/datasets/work/d61-af-soilmoisture/work/ANUClimate"
output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/ANUClim_yanco"

template_100m <- rast(
  xmin = 146,
  xmax = 147,
  ymin = -35.3,
  ymax = -34.3,
  resolution = 0.001,
  crs = proj_latlon
)

variables <- c("tavg", "vpd", "srad", "rain")
methods <- c(ngb = "near", bilinear = "bilinear")

for (method_name in names(methods)) {
  for (variable_name in variables) {
    dir.create(
      file.path(output_root, method_name, variable_name),
      recursive = TRUE,
      showWarnings = FALSE
    )
  }
}

month_period <- seq(as.Date("2016-01-01"), as.Date("2021-12-01"), by = "month")
all_dates <- seq(as.Date("2016-01-01"), as.Date("2021-12-31"), by = "day")

for (month_date in month_period) {
  day_index <- which(format(all_dates, "%Y%m") == format(month_date, "%Y%m"))
  day_dates <- all_dates[day_index]

  monthly_stacks <- lapply(
    variables,
    function(variable_name) {
      rast(
        file.path(
          anuclimate_root,
          variable_name,
          format(month_date, "%Y"),
          format(
            month_date,
            paste0("ANUClimate_v2-0_", variable_name, "_daily_%Y%m.nc")
          )
        )
      )
    }
  )
  names(monthly_stacks) <- variables

  for (day_position in seq_along(day_dates)) {
    day_date <- day_dates[day_position]

    for (variable_name in variables) {
      day_layer <- monthly_stacks[[variable_name]][[day_position]]

      for (method_name in names(methods)) {
        resampled_layer <- project(
          day_layer,
          template_100m,
          method = methods[[method_name]]
        )

        writeRaster(
          resampled_layer,
          filename = file.path(
            output_root,
            method_name,
            variable_name,
            format(
              day_date,
              paste0("ANUClimate_v2-0_", variable_name, "_daily_%Y%m%d.tif")
            )
          ),
          overwrite = TRUE
        )
      }
    }
  }
}
