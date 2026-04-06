#!/usr/bin/env Rscript
# Script: 4_downscaled_predictor_performance.R
# Objective: Reproduce Fig. 4 showing binned density scatterplots for downscaled predictor performance.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: OzNet cleaned site data under OZNET_AOA_DATA_ROOT plus albedo fusion training dates.
# Outputs: 3_figure_scripts/generated/fig_04_downscaled_predictor_performance.png
# Usage: Rscript 3_figure_scripts/4_downscaled_predictor_performance.R
# Dependencies: base R

script_args <- commandArgs(trailingOnly = FALSE)
script_file <- sub("^--file=", "", script_args[grep("^--file=", script_args)][1])
source(file.path(dirname(normalizePath(script_file)), "figure_utils.R"))

get_file_sizes <- function(paths) {
  sizes <- rep(NA_real_, length(paths))
  existing_idx <- which(file.exists(paths))

  if (length(existing_idx) > 0) {
    sizes[existing_idx] <- file.info(paths[existing_idx])$size
  }

  sizes
}

get_albedo_training_dates <- function(data_root) {
  doi <- seq(as.Date("2015-01-01"), as.Date("2022-12-31"), by = 16)
  landsat_dir <- file.path(data_root, "datafusion_yanco", "0_landsat_albedo_masked")
  modis_dir <- file.path(data_root, "datafusion_yanco", "0_modis_albedo_masked")

  landsat_files <- file.path(
    landsat_dir,
    paste0("Landsat_albedo_NBAR_LiangMethod_cloudrm_", format(doi, "%Y%m%d"), ".tif")
  )
  valid_idx <- which(get_file_sizes(landsat_files) > 3e6)

  modis_files <- file.path(
    modis_dir,
    paste0("MCD43A4_albedo_NBAR_cloudrm_", format(doi[valid_idx], "%Y%m%d"), ".tif")
  )
  doi[valid_idx[get_file_sizes(modis_files) > 1e6]]
}

build_density_data <- function(x_values, y_values) {
  density_cols <- densCols(
    x_values,
    y_values,
    colramp = grDevices::colorRampPalette(c("black", "white"))
  )
  density_rank <- col2rgb(density_cols)[1, ] + 1L
  panel_palette <- grDevices::colorRampPalette(c("#fff7bc", "#fd8d3c", "#bd0026"))(256)

  data.frame(
    x   = x_values,
    y   = y_values,
    dens = density_rank,
    col = panel_palette[pmin(density_rank, 256)]
  )
}

plot_density_panel <- function(x_values, y_values, xlim, ylim, xlab, ylab, panel_tag) {
  plot_df <- build_density_data(x_values, y_values)
  plot_df <- plot_df[order(plot_df$dens), ]

  plot(
    plot_df$x,
    plot_df$y,
    pch  = 19,
    col  = plot_df$col,
    xlim = xlim,
    ylim = ylim,
    xlab = xlab,
    ylab = ylab,
    cex  = 0.8
  )
  abline(a = 0, b = 1, lty = 2)

  legend(
    "topleft",
    legend = paste0("(", panel_tag, ") N = ", nrow(plot_df)),
    bty    = "n"
  )
  legend(
    "bottomright",
    legend = c(
      paste0("Bias = ", round(mean(y_values - x_values), 2)),
      paste0("ubRMSE = ", round(stats::sd(y_values - x_values), 2)),
      paste0("R = ", round(stats::cor(y_values, x_values), 2))
    ),
    bty = "n"
  )
}

plot_density_scale <- function(x_values, y_values) {
  x_scaled <- normalise_min_max(x_values)
  y_scaled <- normalise_min_max(y_values)

  density_grid <- grDevices:::.smoothScatterCalcDensity(
    cbind(x_scaled, y_scaled),
    nbin = 128
  )
  density_values <- as.numeric(density_grid$fhat)
  density_values <- density_values[density_values > 0]

  color_key <- data.frame(
    density = seq(0, max(density_values), length.out = 10),
    color   = grDevices::colorRampPalette(c("#fff7bc", "#fd8d3c", "#bd0026"))(10)
  )

  plot(NA, xlim = c(0, 10), ylim = c(0, 11), type = "n", ann = FALSE, axes = FALSE)
  rect(0, 1:10, 1, 2:11, col = color_key$color, border = NA)
  text(2.8, (1:10) + 0.5, signif(color_key$density, 2), adj = 0)
}

data_root <- get_data_root()
oznet_sites <- read_oznet_sites()
study_dates <- seq(as.Date("2016-01-01"), as.Date("2019-12-31"), by = "day")
training_dates <- get_albedo_training_dates(data_root)

site_tables <- vector("list", nrow(oznet_sites))

for (site_idx in seq_len(nrow(oznet_sites))) {
  site_path <- file.path(
    data_root,
    "2_cleaned_data",
    paste0("OzNet_", oznet_sites$sitename[site_idx], "_cleaned_data.csv")
  )
  site_df <- read.csv(site_path)

  site_tables[[site_idx]] <- site_df[
    as.Date(site_df$time) >= min(study_dates) &
      as.Date(site_df$time) <= max(study_dates),
  ]
}

whole_df <- do.call(rbind, site_tables)
whole_df <- whole_df[abs(whole_df$ndvi_100m - whole_df$ndvi_500m) <= 0.4, ]
whole_df <- whole_df[!(as.Date(whole_df$time) %in% training_dates), ]
whole_df <- whole_df[stats::complete.cases(whole_df), ]

open_png("fig_04_downscaled_predictor_performance.png", width = 2400, height = 600, pointsize = 18)
layout(matrix(seq_len(6), nrow = 1), widths = c(5, 2, 5, 2, 5, 2))

par(mar = c(4, 4, 2, 1))
plot_density_panel(
  x_values = whole_df$albedo_500m,
  y_values = whole_df$albedo_100m,
  xlim     = c(0, 0.4),
  ylim     = c(0, 0.4),
  xlab     = "MODIS albedo",
  ylab     = "Downscaled albedo",
  panel_tag = "a"
)

par(mar = c(0, 0, 2, 0))
plot_density_scale(whole_df$albedo_500m, whole_df$albedo_100m)

par(mar = c(4, 4, 2, 1))
plot_density_panel(
  x_values = whole_df$ndvi_500m,
  y_values = whole_df$ndvi_100m,
  xlim     = c(0, 1),
  ylim     = c(0, 1),
  xlab     = "MODIS NDVI",
  ylab     = "Downscaled NDVI",
  panel_tag = "b"
)

par(mar = c(0, 0, 2, 0))
plot_density_scale(whole_df$ndvi_500m, whole_df$ndvi_100m)

par(mar = c(4, 4, 2, 1))
plot_density_panel(
  x_values = whole_df$lst_1km,
  y_values = whole_df$lst_100m,
  xlim     = c(270, 330),
  ylim     = c(270, 330),
  xlab     = "MODIS LST (K)",
  ylab     = "Downscaled LST (K)",
  panel_tag = "c"
)

par(mar = c(0, 0, 2, 0))
plot_density_scale(whole_df$lst_1km, whole_df$lst_100m)

dev.off()
