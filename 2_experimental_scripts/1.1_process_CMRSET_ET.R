#!/usr/bin/env Rscript
# Script: 1.1_process_CMRSET_ET.R
# Objective: Project monthly CMRSET Landsat ET tiles to the 100 m OzNet study grid used in the experiments.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Monthly CMRSET ET rasters on the NCI filesystem.
# Outputs: Monthly ET rasters in /datasets/work/d61-af-soilmoisture/work/model_averaging/CMRSET_ET/.
# Usage: Rscript 2_experimental_scripts/1.1_process_CMRSET_ET.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)

proj_latlon <- "+proj=longlat +datum=WGS84"

cmrset_root <- "/datasets/work/d61-af-soilmoisture/work/TERN_Landscape_Grids/CMRSET_Landsat_ET_v2.2/data.tern.org.au/landscapes/aet/v2_2"
output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/CMRSET_ET"

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

template_100m <- rast(
  xmin       = 146,
  xmax       = 147,
  ymin       = -35.3,
  ymax       = -34.3,
  resolution = 0.001,
  crs        = proj_latlon
)

# The archived workflow used a short monthly ET example period.
dates_of_interest <- seq(as.Date("2020-03-01"), as.Date("2020-05-01"), by = "month")

for (date_value in dates_of_interest) {
  input_file <- file.path(
    cmrset_root,
    format(date_value, "%Y"),
    format(date_value, "%Y_%m_01"),
    format(date_value, "CMRSET_LANDSAT_V2_2_%Y_%m_01_ETa_0000087552-0000131328.cog.tif")
  )

  et_raster <- rast(input_file)
  et_100m   <- project(et_raster, template_100m, method = "near")

  writeRaster(
    et_100m,
    filename  = file.path(
      output_root,
      format(date_value, "CMRSET_Landsat_ET_%Y_%m_01.tif")
    ),
    overwrite = TRUE
  )
}
