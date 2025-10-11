# ==============================================================================
# Script Name:     02e_ecoreg_parts_l2_qc.R
# Purpose:         Rank GP polygon parts by area, keep a defensible subset,
#                  build clean outline + bbox for elevatr.
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-04
# Last Updated:    2025-10-11
#
# Changelog:
#  2025-10-04      Initial script
#  2025-10-10      Refactor script to remove Texas Coastal Region polygon -- 
#                  behaves differently in terms of flood frequency.
#  2025-10-11      Refactored to correctly write outline and L2 ecoreg.

# Inputs:          data/processed/us_ecoregions/us_eco_levels.gpkg
#                  (layer: us_eco_l2)
# Outputs:         data/processed/study_area/great_plains_outline.gpkg
#                  - gp_ecoreg_5070
#                  - gp_outline_5070       (cleaned/bridged outline, EPSG:5070)
# Notes:
# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(sf)
  library(terra)
  library(maps)     # light basemap
  library(smoothr)
  library(rmapshaper)
  library(units)
})

# --- Load custom functions ---
source(file.path(here(), "R", "utils", "spatial", "as_sf_geom.R"))

# ------------------------------------------------------------------------------
# 1. Load and check inputs
# ------------------------------------------------------------------------------
# --- paths ---
gpkg_file <- file.path(
  here(), "data", "processed", "us_ecoregions", "us_eco_levels.gpkg")

stopifnot(file.exists(gpkg_file))

# --- Load raw data, filter Great Plains, validate ---
gp_raw_l2_sf <- sf::st_read(gpkg_file, layer = "us_eco_l2", quiet = TRUE) %>%
  dplyr::filter(NA_L1NAME == "GREAT PLAINS") %>%
  sf::st_make_valid() %>%
  select(-area_km2)
sf::st_geometry(gp_raw_l2_sf) <- "geom"

message("Raw GP features: ", nrow(gp_raw_l2_sf))
message("Raw CRS: ", sf::st_crs(gp_raw_l2_sf)$input %||% sf::st_crs(gp_raw_l2_sf)$wkt)
message("Raw EPSG: ",sf::st_crs(gp_raw_l2_sf)$epsg)

# --- quick QA ---
gp_raw_empty  <- sum(sf::st_is_empty(gp_raw_l2_sf))
gp_raw_invalid <- sum(!sf::st_is_valid(gp_raw_l2_sf))
message("Empty geoms: ", gp_raw_empty,
        " | invalid after st_make_valid(): ", gp_raw_invalid)
message("Raw CRS: ", sf::st_crs(gp_raw_l2_sf)$input %||% sf::st_crs(gp_raw_l2_sf)$wkt)
message("Raw EPSG: ", sf::st_crs(gp_raw_l2_sf)$epsg)

# ------------------------------------------------------------------------------
# 2. Drop slivers and disjunct areas
# ------------------------------------------------------------------------------
# --- Explode areas rank (largest first) cumulative coverage ---
gp_parts_5070 <- gp_raw_l2_sf %>%
  sf::st_cast("MULTIPOLYGON", warn = FALSE) %>%            # normalize type
  sf::st_cast("POLYGON", group_or_split = TRUE) %>%        # <-- split rows
  dplyr::mutate(part_area_km2 = as.numeric(sf::st_area(geom))/1e6) %>%
  dplyr::arrange(dplyr::desc(part_area_km2)) %>%
  tibble::rowid_to_column("part_id") %>%
  dplyr::mutate(
    total_km2 = sum(part_area_km2),
    cum_km2   = cumsum(part_area_km2),
    cum_frac  = cum_km2/total_km2,
    area_gen_km2 = round(part_area_km2, digits = 0)
  )

# --- sanity: did we really explode? ---
stopifnot(nrow(gp_parts_5070) > nrow(gp_raw_l2_sf))  # should be TRUE now

# --- drop coastal plain, slivers, and disjunct region ---
gp_filt_5070 <- gp_parts_5070 %>%
  filter(NA_L2NAME != "TEXAS-LOUISIANA COASTAL PLAIN") %>%
  filter(area_gen_km2 > 0) %>%         # drops remaining areas l.t. 1 km
  filter(part_id != 6) %>%             # drops disjunct region
  arrange(NA_L2CODE) %>%
  dplyr::mutate(
    total_km2 = sum(part_area_km2),
    cum_km2   = cumsum(part_area_km2),
    cum_frac  = cum_km2/total_km2,
    area_gen_km2 = round(part_area_km2, digits = 0)
  )

# --- make a df of dropped polygons ---
gp_drop_5070 <- gp_parts_5070 %>%
  filter(NA_L2NAME == "TEXAS-LOUISIANA COASTAL PLAIN" |
           area_gen_km2 == 0 |
           part_id == 6
  ) %>%
  arrange(NA_L2CODE) %>%
  dplyr::mutate(
    total_km2 = sum(part_area_km2),
    cum_km2   = cumsum(part_area_km2),
    cum_frac  = cum_km2/total_km2,
    area_gen_km2 = round(part_area_km2, digits = 0)
  )

# ------------------------------------------------------------------------------
# 3. Visual QA checks
# ------------------------------------------------------------------------------
# --- Make states outline ---
states_5070 <- maps::map("state", plot = FALSE, fill = TRUE) %>%
  sf::st_as_sf() %>%
  sf::st_transform(5070)
sf::st_geometry(states_5070) <- "geom"

# --- Plot of results ---
ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_raw_l2_sf,
          aes(geometry = geom),
          fill = "gray90",
          color = "grey35",
          linewidth = 0.4) +
  geom_sf(data = gp_filt_5070,
          aes(geometry = geom),
          fill = "gray70",
          color = "grey35",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "GP Ecoregions Original and Filtered"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), axis.title = element_blank())

# # ------------------------------------------------------------------------------
# # 4. Make Outline
# # ------------------------------------------------------------------------------

hole_km2 <- 400      # fill holes smaller than this
part_km2 <- 150      # drop exterior parts smaller than this
keep_frac <- 0.08    # ms_simplify keep fraction

# 1) Dissolve
gp_merged <- gp_filt_5070 %>%
  st_make_valid() %>%
  st_union() %>%
  st_as_sf() %>%
  rename(geom = x) %>%
  st_set_geometry("geom")

# 2) Fill interior holes (< hole_km2)
gp_noholes <- gp_merged %>%
  smoothr::fill_holes(threshold = set_units(hole_km2, km^2))

# 3) Drop tiny exterior parts (< part_km2); keep only largest piece (optional)
gp_clean <-
  gp_noholes %>%
  st_make_valid() %>%
  st_cast("MULTIPOLYGON") %>%
  st_cast("POLYGON") %>%
  mutate(a_km2 = set_units(st_area(geom), km^2)) %>%
  filter(as.numeric(a_km2) >= part_km2) %>%
  select(-a_km2) %>%
  st_union() %>%
  st_as_sf()

# (optional) keep only largest connected piece
gp_clean <- gp_clean %>% 
  st_set_geometry("geom") %>%
  st_cast("MULTIPOLYGON") %>% 
  st_cast("POLYGON") %>%
  mutate(a = as.numeric(st_area(geom))) %>%
  dplyr::slice_max(a, n = 1, with_ties = FALSE) %>%
  select(-a) %>%
  st_union() %>%
  st_as_sf() %>%
  st_set_geometry("geom")

summary(st_area(gp_clean))

# --- visual check ---
ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_merged,
          aes(geometry = geom),
          fill = "gray70",
          color = "grey35",
          linewidth = 0.2) +
  geom_sf(data = gp_simpl,
          aes(geometry = geom),
          alpha = 0.5,
          fill = "gray80",
          color = "grey35",
          linewidth = 0.2) +
coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "GP Merged and GP Simpl"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), axis.title = element_blank())

# ------------------------------------------------------------------------------
# 3. Check and Write Results
# ------------------------------------------------------------------------------
# --- ids of parts we kept (given cum_frac <= target_cover) ---
kept_ids <- gp_filt_5070 %>%
  st_drop_geometry()

# --- Find dropped parts ---
dropped_ids <- gp_drop_5070 %>%
  st_drop_geometry()


# --- write outputs ---
out_dir <- file.path(here(), "data", "processed", "study_area",
                       "gp_ecoreg_5070.gpkg")

if (file.exists(out_dir)) fs::file_delete(out_dir)
sf::st_write(gp_filt_5070,
             out_dir,
             layer = "gp_L2_ecoreg",
             quiet = TRUE
)
message("Wrote: ", out_dir)

# --- 6. Export outputs ---
out_path <- here("data", "processed", "study_area", "gp_outline_5070.gpkg")

st_write(gp_clean,
         dsn   = out_path,
         layer = "gp_outline",
         delete_layer = TRUE)

st_write(gp_simpl,
         dsn   = out_path,
         layer = "gp_outline_simple",
         delete_layer = TRUE)


