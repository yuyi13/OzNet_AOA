#!/usr/bin/env Rscript
# Script: 3_model_caret_cr_cluster.R
# Objective: Fit random forest and XGBoost soil-moisture models with the archived cross-cluster validation setup.
# Author: Yi Yu
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Cleaned OzNet predictor tables and site cluster assignments.
# Outputs: Caret model objects and CAST trainDI objects in /datasets/work/d61-af-soilmoisture/work/model_averaging/3_model_fitting/caret/.
# Usage: Rscript 2_experimental_scripts/2_spatial_sm_prediction/3_model_caret_cr_cluster.R
# Dependencies: R packages caret, CAST, randomForest, xgboost, doParallel

library(caret)
library(CAST)
library(randomForest)
library(xgboost)
library(doParallel)

site_info_file <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/0_code/oznet_studysites.csv"
cleaned_data_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/2_cleaned_data"
output_root <- "/datasets/work/d61-af-soilmoisture/work/model_averaging/3_model_fitting/caret"

study_start <- as.Date("2016-01-01")
study_end <- as.Date("2019-12-31")
predictor_names <- c(
  "dem", "awc", "clay", "silt", "sand",
  "lst_100m", "albedo_100m", "ndvi_100m", "et_100m",
  "tavg", "vpd", "srad", "rain"
)

worker_cluster <- parallel::makePSOCKcluster(40L)
doParallel::registerDoParallel(worker_cluster)
on.exit(parallel::stopCluster(worker_cluster), add = TRUE)

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

load_site_training_data <- function(site_index, site_info, data_root) {
  site_name <- site_info$sitename[site_index]
  site_file <- file.path(data_root, paste0("OzNet_", site_name, "_cleaned_data.csv"))
  site_df <- read.csv(site_file)

  in_period <- as.Date(site_df$time) >= study_start & as.Date(site_df$time) <= study_end
  site_df <- site_df[in_period, , drop = FALSE]
  site_df$cluster <- site_info$cluster[site_index]

  site_df
}

fit_and_save_model <- function(caret_method, model_label, predictors_train, response_train, cv_index) {
  set.seed(13)
  fitted_model <- caret::train(
    x = predictors_train,
    y = response_train,
    method = caret_method,
    importance = TRUE,
    trControl = caret::trainControl(
      method = "cv",
      index = cv_index,
      allowParallel = TRUE
    )
  )

  saveRDS(
    fitted_model,
    file = file.path(output_root, paste0(model_label, "_model_caret_cross_cluster.rds"))
  )

  train_di <- CAST::trainDI(fitted_model)
  print(train_di)
  saveRDS(
    train_di,
    file = file.path(output_root, paste0(model_label, "_tdi_caret_cross_cluster.rds"))
  )
}

site_info <- read.csv(site_info_file)
training_tables <- vector("list", nrow(site_info))

for (site_index in seq_len(nrow(site_info))) {
  training_tables[[site_index]] <- load_site_training_data(site_index, site_info, cleaned_data_root)
}

whole_df_train <- do.call(rbind, training_tables)

ndvi_outliers <- which(abs(whole_df_train$ndvi_100m - whole_df_train$ndvi_500m) > 0.4)
if (length(ndvi_outliers) > 0) {
  whole_df_train <- whole_df_train[-ndvi_outliers, , drop = FALSE]
}

whole_df_train <- stats::na.omit(whole_df_train)

cluster_ids <- sort(unique(stats::na.omit(whole_df_train$cluster)))
spatial_cluster_idx <- lapply(
  cluster_ids,
  function(cluster_id) {
    which(whole_df_train$cluster != cluster_id)
  }
)

response_train <- whole_df_train[["insitu_sm"]]
predictors_train <- whole_df_train[, predictor_names, drop = FALSE]

fit_and_save_model("rf", "rf", predictors_train, response_train, spatial_cluster_idx)
fit_and_save_model("xgbTree", "xgb", predictors_train, response_train, spatial_cluster_idx)
