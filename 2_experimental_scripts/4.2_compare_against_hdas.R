#!/usr/bin/env Rscript
# Script: 4.2_compare_against_hdas.R
# Objective: Compare daily model predictions against the archived HDAS field-campaign observations.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-07
# Inputs: HDAS campaign CSV files and daily upscaled soil-moisture rasters.
# Outputs: Per-date comparison CSV files and correlation summaries in /datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/hdas_comparison/.
# Usage: Rscript 2_experimental_scripts/4.2_compare_against_hdas.R
# Dependencies: R packages ncdf4, terra

library(ncdf4)
library(terra)

proj_latlon  <- "+proj=longlat +datum=WGS84"
hdas_configs <- list(
  HDAS_2019 = list(
    input_root = "/datasets/work/d61-af-soilmoisture/work/model_averaging/HDAS_Yanco/HDAS_2019/csv",
    parse_date = function(file_name) {
      as.Date(sub(".*?(\\d{8})\\.csv$", "\\1", basename(file_name)), format = "%Y%m%d")
    }
  ),
  HDAS_2021 = list(
    input_root = "/datasets/work/d61-af-soilmoisture/work/model_averaging/HDAS_Yanco/HDAS_2021/2-Processed-Data/csv",
    parse_date = function(file_name) {
      as.Date(sub(".*?(\\d{4}_\\d{2}_\\d{2})\\.csv$", "\\1", basename(file_name)), format = "%Y_%m_%d")
    }
  )
)
upscaled_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/4_upscaled_sm/100m/global"
output_root   <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/7_evaluations/hdas_comparison"
model_names   <- c("rf", "xgb")

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

extract_comparison <- function(csv_file, campaign_name, model_name, parse_date_fn) {
  date_value <- parse_date_fn(csv_file)
  hdas_df    <- read.csv(csv_file)

  upscaled_file <- file.path(
    upscaled_root,
    model_name,
    paste0("Upscaled_SM_", model_name, "_daily_100m_", format(date_value, "%Y%m%d"), ".tif")
  )
  upscaled_raster <- rast(upscaled_file)

  hdas_points     <- terra::vect(hdas_df[, c("lon", "lat")], geom = c("lon", "lat"), crs = proj_latlon)
  upscaled_values <- terra::extract(upscaled_raster, hdas_points)[, 2]

  comparison_df <- data.frame(
    lat         = hdas_df$lat,
    lon         = hdas_df$lon,
    hdas_sm     = round(hdas_df$soil_moisture, 3),
    upscaled_sm = round(upscaled_values, 3)
  )

  model_output_dir <- file.path(output_root, model_name)
  dir.create(model_output_dir, recursive = TRUE, showWarnings = FALSE)

  write.table(
    comparison_df,
    file      = file.path(
      model_output_dir,
      paste0(campaign_name, "_", format(date_value, "%Y%m%d"), "_comparison.csv")
    ),
    row.names = FALSE,
    sep       = ",",
    quote     = FALSE
  )

  data.frame(
    date        = format(date_value, "%Y%m%d"),
    correlation = stats::cor(comparison_df$hdas_sm, comparison_df$upscaled_sm, use = "complete.obs")
  )
}

for (model_name in model_names) {
  correlation_rows <- list()
  row_index        <- 1L

  for (campaign_name in names(hdas_configs)) {
    campaign_config <- hdas_configs[[campaign_name]]
    csv_files       <- list.files(campaign_config$input_root, pattern = "\\.csv$", full.names = TRUE)

    for (csv_file in csv_files) {
      correlation_rows[[row_index]] <- extract_comparison(
        csv_file,
        campaign_name,
        model_name,
        campaign_config$parse_date
      )
      row_index <- row_index + 1L
    }
  }

  if (length(correlation_rows) == 0) {
    correlation_rows[[1]] <- data.frame(date = character(), correlation = numeric())
  }

  write.table(
    do.call(rbind, correlation_rows),
    file      = file.path(output_root, paste0("hdas_correlation_", model_name, ".csv")),
    row.names = FALSE,
    sep       = ",",
    quote     = FALSE
  )
}
