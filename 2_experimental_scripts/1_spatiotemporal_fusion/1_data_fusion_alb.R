#!/usr/bin/env Rscript
# Script: 1_data_fusion_alb.R
# Objective: Fuse MODIS and Landsat albedo scenes with ubESTARFM to create daily 100 m albedo predictors for the OzNet experiments.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Masked and interpolated MODIS/Landsat albedo rasters plus the external ubESTARFM implementation.
# Outputs: Fused daily albedo rasters in /datasets/work/d61-af-soilmoisture/work/model_averaging/1_downscaled_data/albedo/.
# Usage: Rscript 2_experimental_scripts/1_spatiotemporal_fusion/1_data_fusion_alb.R
# Dependencies: R packages raster; external ubESTARFM.R script

library(raster)

ubestarfm_script <- "/datasets/work/d61-af-soilmoisture/work/users/yu/git_repo/ubESTARFM/0_algorithm/ubESTARFM.R"
source(ubestarfm_script)

has_min_size <- function(paths, min_size) {
  info <- file.info(paths)
  !is.na(info$size) & info$size > min_size
}

product_name <- "MCD43A4"
index_name <- "albedo"
method_name <- "baseline"

modis_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/datafusion_yanco",
  paste0("0_modis_", index_name, "_masked")
)
modis_interp_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/datafusion_yanco",
  paste0("1_modis_", index_name, "_interp")
)
landsat_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/datafusion_yanco",
  paste0("0_landsat_", index_name, "_masked")
)
landsat_interp_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/datafusion_yanco",
  paste0("1_landsat_", index_name, "_interp")
)
output_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/model_averaging/1_downscaled_data",
  index_name
)
tmp_root <- file.path(
  "/datasets/work/d61-af-soilmoisture/work/tmp",
  index_name,
  "bias_correct"
)

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)

dates_of_interest <- seq(as.Date("2015-01-01"), as.Date("2022-12-31"), by = "16 days")

candidate_landsat <- file.path(
  landsat_root,
  format(dates_of_interest, "Landsat_albedo_NBAR_LiangMethod_cloudrm_%Y%m%d.tif")
)
valid_index <- which(has_min_size(candidate_landsat, min_size = 3e6))

candidate_modis <- file.path(
  modis_root,
  format(dates_of_interest[valid_index], "MCD43A4_albedo_NBAR_cloudrm_%Y%m%d.tif")
)
valid_index <- valid_index[has_min_size(candidate_modis, min_size = 1e6)]

valid_dates <- dates_of_interest[valid_index]
train_landsat <- file.path(
  landsat_interp_root,
  format(valid_dates, "Landsat_albedo_NBAR_LiangMethod_cloudrm_%Y%m%d.tif")
)
train_modis <- file.path(
  modis_root,
  format(valid_dates, "MCD43A4_albedo_NBAR_cloudrm_%Y%m%d.tif")
)

pred_modis <- list.files(
  modis_root,
  pattern = "^MCD43A4_albedo_NBAR_cloudrm_\\d{8}\\.tif$",
  full.names = TRUE
)
pred_dates <- as.Date(
  sub(".*_(\\d{8})\\.tif$", "\\1", basename(pred_modis)),
  format = "%Y%m%d"
)
output_files <- file.path(output_root, sub(product_name, "ESTARFM", basename(pred_modis)))

for (pair_index in seq_len(length(train_landsat) - 1)) {
  train_window <- valid_dates[pair_index:(pair_index + 1)]
  pred_index <- which(pred_dates >= train_window[1] & pred_dates < train_window[2])

  for (pred_position in pred_index) {
    ubESTARFM(
      w = 25,
      DN_min = 0,
      DN_max = 1,
      patch_long = 200,
      tmp_path = tmp_root,
      out_path = output_files[pred_position],
      method = method_name,
      rst_fine1 = raster(train_landsat[pair_index]),
      rst_fine2 = raster(train_landsat[pair_index + 1]),
      rst_coarse1 = raster(train_modis[pair_index]),
      rst_coarse2 = raster(train_modis[pair_index + 1]),
      rst_coarse0 = raster(pred_modis[pred_position])
    )
  }
}
