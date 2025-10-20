# ==============================================================================
# Script Name:     03p_lev3_prism_seasonal_sd_by_ecoregion.R
# Author:          CJ Tinant — with GPT-5 Thinking


# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-10-19
# Last Updated:    2025-10-19
# Changelog:
#  2025-10-19      Initial script.
#
# Purpose:         Compute std. deviation of seasonal PRISM ppt totals
#                  (1991–2020) aggregated to Level III ecoregions.
#
# General Workflow Summary:
#  1. Load monthly precip stack
#  2. Group months into seasons. Sum precipitation for each season:
#       Uses purrr to loop over seasons, pick the months, sum those raster
#       layers.” Here’s the breakdown:
#         seasonal_totals <- map(season_map, \(m) sum(r_ppt[[m]])) %>% rast()
#         `season_map` is a named list mapping each season to the month names.
#         `map(...)` iterates over that list.
#         `\(m)` ... is a base-R anonymous function (same as function(m) ...).
#         `r_ppt[[m]]` selects a subset of layers from your SpatRaster by name
#            (e.g., r_ppt[["dec","jan","feb"]]).
#         each call to `sum(r_ppt[[m]])` calls terra::sum() across those layers,
#         returning a single seasonal raster (pixelwise sum) -- in this case a
#         a named list of 4 SpatRasters (DJF, MAM, JJA, SON). 
#       Here is a more tidyverse way to write it:
#         seasonal_totals <- season_map %>%
#           map(\(m) r_ppt[[m]] %>% terra::sum(na.rm = TRUE)) %>%
#           rast() %>%
#           { names(.) <- names(season_map); . }
#  3. Compute standard deviation of seasonal totals
#  4. Aggregate SD to Level III Ecoregions (coverage-weighted mean in 5070)
#  5. Export results
#
# Dependencies:    tidyverse, terra, sf, exactextractr, here
#
# Inputs:          data/processed/prism/prism_ppt_monthly_4km_1991_2020.tif
#                  data/processed/ecoregions/us_eco_l3.gpkg
# Outputs:         data/covars/prism_seasonal_sd_l3.csv
#                  data/output/qa_checks/prism_seasonal_sd_5070.tif"
# Next Steps:
# ==============================================================================
# --- load libraries ---
suppressPackageStartupMessages({
  library(exactextractr)
  library(here)
  library(sf)
  library(terra)
  library(tidyverse)
})

# ------------------------------------------------------------------------------
# 1. Load data
# ------------------------------------------------------------------------------
eco_l3 <- st_read(
  here("data", "processed", "study_area", "gp_ecoreg_5070.gpkg"))

# --- Keep PRISM normals at native 800 m in their delivery CRS ---
r_ppt <- rast(
  here("data", "processed", "prism", "ppt_monthly_mm_stack.tif"))

# ------------------------------------------------------------------------------
# 2. Sum precipitation by season
# ------------------------------------------------------------------------------
# Build seasons at native grid
# --- 2. Group months into seasons ----
month_names <- c("jan","feb","mar","apr","may","jun",
                 "jul","aug","sep","oct","nov","dec")

names(r_ppt) <- month_names

season_map <- list(
  DJF = c("dec","jan","feb"),
  MAM = c("mar","apr","may"),
  JJA = c("jun","jul","aug"),
  SON = c("sep","oct","nov")
)

# --- Sum precipitation for each season ---
seasonal_totals <- map(season_map, \(m) sum(r_ppt[[m]])) %>%
  rast()

# --- quick sanity checks ---
seasonal_totals

plot(seasonal_totals$DJF)   # should look like a precip total map for DJF

terra::global(seasonal_totals, "mean", na.rm = TRUE)

# ------------------------------------------------------------------------------
# 3. Compute standard deviation of seasonal totals
# ------------------------------------------------------------------------------
# --- SD of seasonal totals (one-layer raster) ---
r_sd <- terra::app(seasonal_totals,
                   fun   = sd,
                   na.rm = TRUE
)

names(r_sd) <- "ppt_seasonal_sd_mm"

# --- quick sanity checks ---
print(r_sd)

terra::global(r_sd, c("min","mean","max"), na.rm = TRUE)

# ------------------------------------------------------------------------------
# 4. Aggregate SD to Level III Ecoregions (coverage-weighted mean in 5070)
# ------------------------------------------------------------------------------
# --- clip the grid to GP polygons to speed up extraction ---
r_sd_gp <- r_sd %>%
  terra::crop(terra::vect(eco_l3)) %>%
  terra::mask(terra::vect(eco_l3))

eco_l3$prism_ppt_seasonal_sd_mm <-
  exactextractr::exact_extract(
    r_sd_gp,
    eco_l3,
    fun = "mean"
)

# --- quick sanity check ---
plot(r_sd_gp)

terra::hist(r_sd_gp)

terra::global(r_sd_gp,  c("min","mean","max"), na.rm=TRUE)

# ecoregion sanity
eco_l3 %>%
  st_drop_geometry() %>%
  slice_max(prism_ppt_seasonal_sd_mm, n = 10) %>%
  select(NA_L3CODE, NA_L3NAME, prism_ppt_seasonal_sd_mm)

# ------------------------------------------------------------------------------
# 5. Export results
# ------------------------------------------------------------------------------
# -- export SD table ---
out_table <- here("data","covars","l3_prism_seasonal_sd.csv")

sd_table <- eco_l3 %>%
  st_drop_geometry() %>%
  select(NA_L3CODE, NA_L3NAME, prism_ppt_seasonal_sd_mm) %>%
  arrange(NA_L3CODE)

readr::write_csv(sd_table, out_table)

# --- export raster for QA maps ---
out_rast <- here("output","qa_checks","prism_seasonal_sd_5070.tif")

terra::writeRaster(
  r_sd_gp,
  out_rast,
  gdal = c("TILED=YES","COMPRESS=LZW","BIGTIFF=YES"),
  overwrite = TRUE
)


