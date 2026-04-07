#!/usr/bin/env Rscript
# Script: 3.1_calc_aoa_cr_cluster.R
# Objective: Calculate daily AOA and dissimilarity rasters from the cross-cluster validation models.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: Cross-cluster trainDI objects plus daily predictor rasters.
# Outputs: Daily NetCDF files in /datasets/work/d61-af-soilmoisture/work/model_averaging/5_sm_aoa/<model>/cr_cluster/.
# Usage: Rscript 2_experimental_scripts/3.1_calc_aoa_cr_cluster.R <rf|xgb>
# Dependencies: R packages CAST, caret, ncdf4, terra, foreach, doParallel

library(CAST)
library(caret)
library(ncdf4)
library(terra)
library(foreach)
library(doParallel)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1 || !args[[1]] %in% c("rf", "xgb")) {
  stop("Usage: Rscript 5_calc_aoa_cr_cluster.R <rf|xgb>")
}

model_name   <- args[[1]]
static_root  <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/0_static_layers"
fusion_root  <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/1_downscaled_data"
et_root      <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/CMRSET_ET"
climate_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/ANUClim_yanco/bilinear"
model_root   <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/3_model_fitting/caret"
output_root  <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/5_sm_aoa",
  model_name,
  "cr_cluster"
)

dates_of_interest <- seq(as.Date("2016-01-01"), as.Date("2021-12-31"), by = "day")
predictor_names   <- c(
  "dem", "awc", "clay", "silt", "sand",
  "lst_100m", "albedo_100m", "ndvi_100m", "et_100m",
  "tavg", "vpd", "srad", "rain"
)

worker_cluster <- parallel::makePSOCKcluster(24L)
doParallel::registerDoParallel(worker_cluster)
on.exit(parallel::stopCluster(worker_cluster), add = TRUE)

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

build_predictor_stack <- function(date_value) {
  predictor_stack <- c(
    rast(file.path(static_root, "100m", "dem_100m.tif")),
    rast(file.path(static_root, "100m", "awc_100m.tif")),
    rast(file.path(static_root, "100m", "clay_100m.tif")),
    rast(file.path(static_root, "100m", "silt_100m.tif")),
    rast(file.path(static_root, "100m", "sand_100m.tif")),
    rast(file.path(fusion_root, "lst", paste0("ubESTARFM_LST_daytime_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(fusion_root, "albedo", paste0("ESTARFM_albedo_NBAR_cloudrm_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(fusion_root, "ndvi", paste0("ESTARFM_NDVI_NBAR_cloudrm_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(et_root, paste0("CMRSET_Landsat_ET_", format(date_value, "%Y_%m_01"), ".tif"))),
    rast(file.path(climate_root, "tavg", paste0("ANUClimate_v2-0_tavg_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(climate_root, "vpd", paste0("ANUClimate_v2-0_vpd_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(climate_root, "srad", paste0("ANUClimate_v2-0_srad_daily_", format(date_value, "%Y%m%d"), ".tif"))),
    rast(file.path(climate_root, "rain", paste0("ANUClimate_v2-0_rain_daily_", format(date_value, "%Y%m%d"), ".tif")))
  )

  names(predictor_stack) <- predictor_names
  predictor_stack
}

train_di <- readRDS(file.path(model_root, paste0(model_name, "_tdi_caret_cross_cluster.rds")))

foreach::foreach(
  date_index = seq_along(dates_of_interest),
  .packages  = c("CAST", "caret", "ncdf4", "terra")
) %dopar% {
  date_value <- dates_of_interest[date_index]
  message("Processing date: ", format(date_value, "%Y%m%d"))

  predictor_stack <- build_predictor_stack(date_value)
  sm_aoa          <- CAST::aoa(newdata = predictor_stack, trainDI = train_di)
  sm_aoa_stack    <- c(sm_aoa$DI, sm_aoa$AOA)

  writeCDF(
    sm_aoa_stack,
    filename  = file.path(output_root, paste0("sm_aoa_", model_name, "_", format(date_value, "%Y%m%d"), ".nc")),
    varname   = "aoa_metrics",
    longname  = "Dissimilarity index and Area of Applicability",
    overwrite = TRUE
  )
}
