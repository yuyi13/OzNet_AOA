#!/usr/bin/env Rscript
# Script: 2.2_model_prediction.R
# Objective: Predict daily 100 m soil moisture for the full study area and the two archived cluster subregions.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Trained caret models plus static, fused, ET, and ANUClimate raster predictors.
# Outputs: Daily prediction rasters in /datasets/work/d61-af-soilmoisture/work/model_averaging/4_upscaled_sm/100m/.
# Usage: Rscript 2_experimental_scripts/2.2_model_prediction.R <rf|xgb>
# Dependencies: R packages ncdf4, terra, randomForest, xgboost

library(ncdf4)
library(terra)
library(randomForest)
library(xgboost)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1 || !args[[1]] %in% c("rf", "xgb")) {
  stop("Usage: Rscript 4_model_prediction.R <rf|xgb>")
}

model_name      <- args[[1]]
static_root     <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/0_static_layers"
fusion_root     <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/1_downscaled_data"
et_root         <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/CMRSET_ET"
climate_root    <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/ANUClim_yanco/bilinear"
model_root      <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/3_model_fitting/caret"
prediction_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/4_upscaled_sm/100m"

dates_of_interest <- seq(as.Date("2016-01-01"), as.Date("2021-12-31"), by = "day")
predictor_names   <- c(
  "dem", "awc", "clay", "silt", "sand",
  "lst_100m", "albedo_100m", "ndvi_100m", "et_100m",
  "tavg", "vpd", "srad", "rain"
)

xgb_predict <- function(model, data, ...) {
  predict(model, newdata = as.matrix(data), ...)
}

build_output_filename <- function(model_name, date_value, suffix = NULL) {
  name_parts <- c("Upscaled_SM", model_name, "daily", "100m")
  if (!is.null(suffix)) {
    name_parts <- c(name_parts, suffix)
  }

  paste0(paste(name_parts, collapse = "_"), "_", format(date_value, "%Y%m%d"), ".tif")
}

crop_if_needed <- function(raster_layer, region_extent) {
  if (is.null(region_extent)) {
    return(raster_layer)
  }

  terra::crop(raster_layer, region_extent)
}

build_predictor_stack <- function(date_value, region_extent = NULL) {
  static_layers <- list(
    dem  = rast(file.path(static_root, "100m", "dem_100m.tif")),
    awc  = rast(file.path(static_root, "100m", "awc_100m.tif")),
    clay = rast(file.path(static_root, "100m", "clay_100m.tif")),
    silt = rast(file.path(static_root, "100m", "silt_100m.tif")),
    sand = rast(file.path(static_root, "100m", "sand_100m.tif"))
  )

  dynamic_layers <- list(
    lst_100m    = rast(file.path(fusion_root, "lst", paste0("ubESTARFM_LST_daytime_", format(date_value, "%Y%m%d"), ".tif"))),
    albedo_100m = rast(file.path(fusion_root, "albedo", paste0("ESTARFM_albedo_NBAR_cloudrm_", format(date_value, "%Y%m%d"), ".tif"))),
    ndvi_100m   = rast(file.path(fusion_root, "ndvi", paste0("ESTARFM_NDVI_NBAR_cloudrm_", format(date_value, "%Y%m%d"), ".tif"))),
    et_100m     = rast(file.path(et_root, paste0("CMRSET_Landsat_ET_", format(date_value, "%Y_%m_01"), ".tif"))),
    tavg        = rast(file.path(climate_root, "tavg", paste0("ANUClimate_v2-0_tavg_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    vpd         = rast(file.path(climate_root, "vpd", paste0("ANUClimate_v2-0_vpd_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    srad        = rast(file.path(climate_root, "srad", paste0("ANUClimate_v2-0_srad_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    rain        = rast(file.path(climate_root, "rain", paste0("ANUClimate_v2-0_rain_daily_", format(date_value, "%Y%m%d"), ".tif")))
  )

  layer_list <- c(static_layers, dynamic_layers)
  if (!is.null(region_extent)) {
    layer_list <- lapply(
      layer_list,
      function(raster_layer) {
        crop_if_needed(raster_layer, region_extent)
      }
    )
  }

  predictor_stack        <- do.call(c, layer_list)
  names(predictor_stack) <- predictor_names

  predictor_stack
}

predict_soil_moisture <- function(model_fit, predictor_stack, model_name) {
  if (model_name == "xgb") {
    prediction_raster <- terra::predict(
      predictor_stack,
      model = model_fit,
      fun   = xgb_predict,
      na.rm = TRUE
    )
  } else {
    prediction_raster <- terra::predict(
      predictor_stack,
      model = model_fit,
      na.rm = TRUE
    )
  }

  prediction_raster[prediction_raster < 0] <- NA
  prediction_raster
}

write_prediction_series <- function(model_fit, output_dir, region_extent = NULL, suffix = NULL) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  for (date_value in dates_of_interest) {
    message("Predicting ", format(date_value, "%Y-%m-%d"), "...")
    predictor_stack   <- build_predictor_stack(date_value, region_extent = region_extent)
    prediction_raster <- predict_soil_moisture(model_fit, predictor_stack, model_name)

    writeRaster(
      prediction_raster,
      filename  = file.path(output_dir, build_output_filename(model_name, date_value, suffix = suffix)),
      overwrite = TRUE
    )
  }
}

global_model      <- readRDS(file.path(model_root, paste0(model_name, "_model_caret_4fold_spatial_cv.rds")))
global_output_dir <- file.path(prediction_root, "global", model_name)
write_prediction_series(global_model, global_output_dir)

cluster_model   <- readRDS(file.path(model_root, paste0(model_name, "_model_caret_cross_cluster.rds")))
cluster_regions <- list(
  cluster_A = ext(146.06, 146.16, -34.77, -34.62),
  cluster_B = ext(146.25, 146.35, -35.02, -34.92)
)

for (region_name in names(cluster_regions)) {
  cluster_output_dir <- file.path(
    prediction_root,
    sub("_", "", region_name),
    model_name
  )
  write_prediction_series(
    cluster_model,
    cluster_output_dir,
    region_extent = cluster_regions[[region_name]],
    suffix        = region_name
  )
}
