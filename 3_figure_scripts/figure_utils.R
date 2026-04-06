#!/usr/bin/env Rscript
# Script: figure_utils.R
# Objective: Provide shared helpers for the refactored OzNet_AOA figure scripts.
# Author: Yi Yu; refactored by OpenAI Codex
# Created: 2026-04-06
# Last updated: 2026-04-06
# Inputs: Repository paths plus optional OZNET_AOA_DATA_ROOT and OZNET_GRAPHICS_HELPER environment variables.
# Outputs: Helper functions for figure paths, palettes, summary labels, and common plotting setup.
# Usage: source("3_figure_scripts/figure_utils.R")
# Dependencies: base R

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) == 0) {
    stop("Figure scripts are intended to be run with Rscript.")
  }

  normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
}

get_script_dir <- function() {
  dirname(get_script_path())
}

get_repo_root <- function() {
  normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
}

get_generated_dir <- function() {
  file.path(get_script_dir(), "generated")
}

get_data_root <- function() {
  Sys.getenv(
    "OZNET_AOA_DATA_ROOT",
    unset = "/datasets/work/d61-af-soilmoisture/work/model_averaging"
  )
}

read_oznet_sites <- function() {
  repo_path <- file.path(get_repo_root(), "0_ancillary", "OzNet_study_sites.csv")
  archive_path <- file.path(get_data_root(), "0_code", "oznet_studysites.csv")

  if (file.exists(repo_path)) {
    return(read.csv(repo_path))
  }

  read.csv(archive_path)
}

open_png <- function(filename, width, height, pointsize = 12) {
  output_dir <- get_generated_dir()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  output_path <- file.path(output_dir, filename)
  png(
    filename  = output_path,
    width     = width,
    height    = height,
    pointsize = pointsize,
    family    = "Arial"
  )
  par(family = "Arial")

  invisible(output_path)
}

normalise_min_max <- function(x) {
  value_range <- range(x, na.rm = TRUE)
  span <- diff(value_range)

  if (!is.finite(span) || span == 0) {
    return(rep(NA_real_, length(x)))
  }

  (x - value_range[1]) / span
}

albedo_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#2c7bb6", "#abd9e9", "#ffffbf", "#fdae61", "#d7191c"))(n)
}

ndvi_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#f7fcf5", "#74c476", "#006d2c"))(n)
}

lst_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#313695", "#74add1", "#fdae61", "#d73027", "#a50026"))(n)
}

sm_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#f7fbff", "#9ecae1", "#3182bd", "#08519c", "#08306b"))(n)
}

di_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#5e4fa2", "#3288bd", "#e6f598", "#fdae61", "#d53e4f"))(n)
}

cor_palette <- function(n = 64) {
  grDevices::colorRampPalette(c("#f7fcfd", "#99d8c9", "#2ca25f", "#00441b"))(n)
}

aoa_palette <- function() {
  c("white", "grey60")
}

add_panel_tag <- function(tag, cex = 1.2) {
  legend("topleft", legend = paste0("(", tag, ")"), bty = "n", cex = cex)
}

format_medians <- function(x, digits = 2) {
  format(round(x, digits), nsmall = digits)
}

