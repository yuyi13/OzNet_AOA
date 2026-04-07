#!/usr/bin/env Rscript
# Script: demo.R
# Objective: Demonstrate AOA calculation for an XGBoost soil-moisture model using OzNet training data and example predictor rasters.
# Author: Yi Yu
# Created: 2025-04-27
# Last updated: 2026-04-07
# Inputs: OzNet cleaned tables, static rasters, and dynamic rasters under 0_ancillary/.
# Outputs: Model RDS files in 1_aoa_demo/ and figures/fig_aoa_demo.jpg.
# Usage: Rscript 1_aoa_demo/demo.R
# Dependencies: R packages ncdf4, terra, raster, caret, CAST, RColorBrewer, xgboost

required_packages <- c(
  "ncdf4",
  "terra",
  "raster",
  "caret",
  "CAST",
  "RColorBrewer",
  "xgboost"
)

for (package_name in required_packages) {
  if (!requireNamespace(package_name, quietly = TRUE)) {
    install.packages(package_name, repos = "https://cloud.r-project.org")
  }
}

library(ncdf4)
library(terra)
library(raster)
library(caret)
library(CAST)
library(RColorBrewer)
library(xgboost)

path_to_oznet   <- "0_ancillary/OzNet_cleaned_data"
path_to_static  <- "0_ancillary/var_static"
path_to_dynamic <- "0_ancillary/var_dynamic"
out_path        <- "1_aoa_demo"
figures_path    <- "figures"

dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_path, recursive = TRUE, showWarnings = FALSE)

study_dates <- seq(as.Date("2016-01-01"), as.Date("2019-12-31"), by = "day")
oznet_valid <- read.csv("0_ancillary/OzNet_study_sites.csv")

training_tables <- vector("list", nrow(oznet_valid))

for (site_index in seq_len(nrow(oznet_valid))) {
  site_name       <- oznet_valid$sitename[site_index]
  single_df_train <- read.csv(
    file.path(path_to_oznet, paste0("OzNet_", site_name, "_cleaned_data.csv"))
  )

  in_period <- as.Date(single_df_train$time) >= study_dates[1] &
    as.Date(single_df_train$time) <= study_dates[length(study_dates)]

  single_df_train                <- single_df_train[in_period, , drop = FALSE]
  single_df_train$fold           <- oznet_valid$iteration[site_index]
  training_tables[[site_index]]  <- single_df_train
}

whole_df_train <- do.call(rbind, training_tables)

# Remove extreme NDVI disagreements between native and downscaled predictors.
huge_ndvi_diff <- which(abs(whole_df_train$ndvi_100m - whole_df_train$ndvi_500m) > 0.4)
if (length(huge_ndvi_diff) > 0) {
  whole_df_train <- whole_df_train[-huge_ndvi_diff, , drop = FALSE]
}
whole_df_train <- na.omit(whole_df_train)

# CAST::CreateSpacetimeFolds can prepare location/time-aware folds for spatiotemporal tasks.
# spatial_cv <- CAST::CreateSpacetimeFolds(
#   whole_df_train,
#   spacevar = "sitename",
#   timevar = NA,
#   k = 4,
#   class = NA,
#   seed = 13
# )

spatial_cv_idx <- vector("list", 4)
for (fold_index in seq_len(4)) {
  spatial_cv_idx[[fold_index]] <- which(whole_df_train$fold != fold_index)
}

predictor_names <- c(
  "dem", "awc", "clay", "silt", "sand",
  "lst_100m", "albedo_100m", "ndvi_100m", "et_100m",
  "tavg", "vpd", "srad", "rain"
)
response_train   <- whole_df_train[["insitu_sm"]]
predictors_train <- whole_df_train[, predictor_names, drop = FALSE]

set.seed(13)
xgb_model <- caret::train(
  x          = predictors_train,
  y          = response_train,
  method     = "xgbTree",
  importance = TRUE,
  trControl  = trainControl(method = "cv", index = spatial_cv_idx)
)

saveRDS(
  xgb_model,
  file = file.path(out_path, "xgb_model_caret_4fold_spatial_cv.rds")
)

xgb_tdi <- trainDI(xgb_model)
print(xgb_tdi)

saveRDS(
  xgb_tdi,
  file = file.path(out_path, "xgb_tdi_caret_4fold_spatial_cv.rds")
)

rst_dem  <- rast(file.path(path_to_static, "DEM_100m_resampled.tif"))
rst_awc  <- rast(file.path(path_to_static, "AWC_100m_resampled.tif"))
rst_clay <- rast(file.path(path_to_static, "CLY_100m_resampled.tif"))
rst_silt <- rast(file.path(path_to_static, "SLT_100m_resampled.tif"))
rst_sand <- rast(file.path(path_to_static, "SND_100m_resampled.tif"))

rst_alb  <- rast(file.path(path_to_dynamic, "ESTARFM_albedo_NBAR_cloudrm_20160205.tif"))
rst_lst  <- rast(file.path(path_to_dynamic, "ubESTARFM_LST_cloudrm_20160205.tif"))
rst_ndvi <- rast(file.path(path_to_dynamic, "ESTARFM_NDVI_NBAR_cloudrm_20160205.tif"))
rst_et   <- rast(file.path(path_to_dynamic, "CMRSET_Landsat_ET_2016_02_01.tif"))
rst_tavg <- rast(file.path(path_to_dynamic, "ANUClimate_v2-0_tavg_daily_20160205.tif"))
rst_vpd  <- rast(file.path(path_to_dynamic, "ANUClimate_v2-0_vpd_daily_20160205.tif"))
rst_srad <- rast(file.path(path_to_dynamic, "ANUClimate_v2-0_srad_daily_20160205.tif"))
rst_rain <- rast(file.path(path_to_dynamic, "ANUClimate_v2-0_rain_daily_20160205.tif"))

pred_stk <- c(
  rst_dem, rst_awc, rst_clay, rst_silt, rst_sand,
  rst_lst, rst_alb, rst_ndvi, rst_et,
  rst_tavg, rst_vpd, rst_srad, rst_rain
)

names(pred_stk) <- predictor_names

pred_sm <- terra::predict(pred_stk, model = xgb_model, na.rm = TRUE)

aoa_metric <- aoa(newdata = pred_stk, trainDI = xgb_tdi)

sm_di             <- aoa_metric$DI
sm_di[sm_di > 5]  <- 5
sm_di[sm_di < 0]  <- 0

sm_aoa <- aoa_metric$AOA

print(aoa_metric)

sm_colours <- colorRampPalette(
  c("white", "peru", "orange", "yellow", "forestgreen", "deepskyblue", "navy", "black")
)
spectral_ramp <- colorRampPalette(RColorBrewer::brewer.pal(11, "Spectral"))

jpeg(
  file.path(figures_path, "fig_aoa_demo.jpg"),
  width  = 1150,
  height = 450
)

layout(cbind(1, 2, 3))
par(mar = c(0.5, 0.5, 4, 0.5), family = "Arial")

image(
  raster(pred_sm),
  zlim = c(0, 0.5),
  col  = sm_colours(64),
  xaxt = "n",
  yaxt = "n",
  xlab = NA,
  ylab = NA
)
rect(146.06, -34.77, 146.16, -34.67, lwd = 3)
rect(146.25, -35.02, 146.35, -34.92, lwd = 3)
mtext("SM prediction", side = 3, cex = 2)

image(
  raster(sm_di),
  zlim = c(0, 5),
  col  = spectral_ramp(64),
  xaxt = "n",
  yaxt = "n",
  xlab = NA,
  ylab = NA
)
rect(146.06, -34.77, 146.16, -34.67, lwd = 3)
rect(146.25, -35.02, 146.35, -34.92, lwd = 3)
mtext("DI", side = 3, cex = 2)

legend(
  "topleft",
  legend = paste0("Threshold = ", round(xgb_tdi$threshold, 2)),
  cex    = 2.5,
  bty    = "n"
)

image(
  raster(sm_aoa),
  col  = c("transparent", "grey"),
  xaxt = "n",
  yaxt = "n",
  xlab = NA,
  ylab = NA
)
rect(146.06, -34.77, 146.16, -34.67, lwd = 3)
rect(146.25, -35.02, 146.35, -34.92, lwd = 3)
mtext("AOA", side = 3, cex = 2)

aoa_values <- as.vector(sm_aoa)
aoa_perc   <- length(which(aoa_values == 1)) / length(aoa_values) * 100

legend(
  "topleft",
  legend = paste0("Area = ", round(aoa_perc, 1), "%"),
  cex    = 2.5,
  bty    = "n"
)

dev.off()
