#!/usr/bin/env Rscript
# Script: 1.1_project_static.R
# Objective: Project the static terrain and soil covariates used by the OzNet AOA experiments to the 1 km and 100 m analysis grids.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Original DEM and TERN Landscape Grid rasters on the NCI filesystem.
# Outputs: Static predictor rasters in /datasets/work/d61-af-soilmoisture/work/model_averaging/0_static_layers/.
# Usage: Rscript 2_experimental_scripts/1.1_project_static.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)

proj_latlon <- "+proj=longlat +datum=WGS84"

static_files <- list(
  dem  = "/datasets/work/d61-af-soilmoisture/work/GA_DEM_30m_v01/dems1sv1_0/w001000.adf",
  awc  = "/datasets/work/d61-af-soilmoisture/work/TERN_Landscape_Grids/v2/AvailWaterCap/AWC_90m/000-005cm/AWC_000_005_05_N_P_AU_TRN_N_20210614.tif",
  clay = "/datasets/work/d61-af-soilmoisture/work/TERN_Landscape_Grids/v2/SoilTexture/CLY_000_005_05_N_P_AU_TRN_N_20210902.tif",
  silt = "/datasets/work/d61-af-soilmoisture/work/TERN_Landscape_Grids/v2/SoilTexture/SLT_000_005_05_N_P_AU_TRN_N_20210902.tif",
  sand = "/datasets/work/d61-af-soilmoisture/work/TERN_Landscape_Grids/v2/SoilTexture/SND_000_005_05_N_P_AU_TRN_N_20210902.tif"
)

output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/0_static_layers"
dir.create(file.path(output_root, "1km"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_root, "100m"), recursive = TRUE, showWarnings = FALSE)

template_1km <- rast(
  xmin       = 112,
  xmax       = 154,
  ymin       = -45,
  ymax       = -10,
  resolution = 0.01,
  crs        = proj_latlon
)

template_100m <- rast(
  xmin       = 146,
  xmax       = 147,
  ymin       = -35.3,
  ymax       = -34.3,
  resolution = 0.001,
  crs        = proj_latlon
)

for (layer_name in names(static_files)) {
  layer_raster <- rast(static_files[[layer_name]])

  layer_1km <- project(layer_raster, template_1km, method = "near")
  writeRaster(
    layer_1km,
    filename  = file.path(output_root, "1km", paste0(layer_name, "_1km.tif")),
    overwrite = TRUE
  )

  layer_100m <- project(layer_raster, template_100m, method = "near")
  writeRaster(
    layer_100m,
    filename  = file.path(output_root, "100m", paste0(layer_name, "_100m.tif")),
    overwrite = TRUE
  )
}
