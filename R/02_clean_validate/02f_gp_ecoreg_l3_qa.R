# ==============================================================================
# Script Name:     02e_gp_ecoreg_l3_qa.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-23
# Last Updated:    2025-10-23

# Change Log:
#  2025-10-23      Split from 02e_gp_ecoreg_make_outline
#
# Purpose:         Make usable L3 Ecoregions to calculate zonal statistics, and
#                  study area outline
#
# Workflow Summary:
#  1. Load L2 Ecoregions. Perform quick QA check.
#  2. Drop Texas-Louisiana Coastal Plain, disjunct region, and slivers:
#      - Explode areas rank (largest first) calculate cumulative coverage.
#      - Drop coastal plain, disjunct region, and slivers.
#  3. QA checks.
#  4. Make outline
#  5. Export results.
#
# Inputs:          data/processed/us_ecoregions/us_eco_levels.gpkg
#                    - layer: us_eco_l3
# Outputs:         data/processed/study_area/gp_ecoreg_5070.gpkg
#                    - layer: gp_L3_ecoreg 
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

# --- Make states outline for plotting ----
states_5070 <- maps::map("state", plot = FALSE, fill = TRUE) %>%
  sf::st_as_sf() %>%
  sf::st_transform(5070)

# # --- Load raw data, filter Great Plains, validate ----
gp_raw_l4_sf <- sf::st_read(gpkg_file,
                            layer = "us_eco_l4",
                            quiet = TRUE) %>%
  dplyr::filter(NA_L1NAME == "GREAT PLAINS") %>%
  sf::st_make_valid() %>%
  select(-area_km2)
sf::st_geometry(gp_raw_l4_sf) <- "geom"

# --- quick QA checks ---
message("Raw GP features: ", nrow(gp_raw_l4_sf))
message("Raw CRS: ", sf::st_crs(gp_raw_l4_sf)$input %||% sf::st_crs(gp_raw_l4_sf)$wkt)
message("Raw EPSG: ",sf::st_crs(gp_raw_l4_sf)$epsg)

gp_raw_empty  <- sum(sf::st_is_empty(gp_raw_l4_sf))
gp_raw_invalid <- sum(!sf::st_is_valid(gp_raw_l4_sf))
message("Empty geoms: ", gp_raw_empty,
        " | invalid after st_make_valid(): ", gp_raw_invalid)
message("Raw CRS: ", sf::st_crs(gp_raw_l4_sf)$input %||% sf::st_crs(gp_raw_l4_sf)$wkt)
message("Raw EPSG: ", sf::st_crs(gp_raw_l4_sf)$epsg)

# --- QA: visual check of inputs (L3 ) ---
ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_raw_l4_sf,
          aes(geometry = geom,
              fill = NA_L3NAME),
          color = "gray90",
          linewidth = 0.1) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "Great Plains L3 Ecoregions"
  ) +
  theme_minimal(base_size = 8) +
  theme(legend.position = "none")

# ------------------------------------------------------------------------------
# 2. Drop coastal plains, disjunct area, and slivers
# ------------------------------------------------------------------------------
# --- Explode areas rank (largest first) cumulative coverage ---
gp_parts_5070 <- gp_raw_l4_sf %>%
  sf::st_cast("MULTIPOLYGON", warn = FALSE) %>%            # normalize type
  sf::st_cast("POLYGON", group_or_split = TRUE) %>%        # <-- split rows
  dplyr::mutate(part_area_km2 = as.numeric(sf::st_area(geom))/1e6) %>%
  dplyr::arrange(dplyr::desc(part_area_km2)) %>%
  dplyr::mutate(area_gen_km2 = round(part_area_km2, digits = 0)) %>%
  filter(area_gen_km2 > 0)         # drops remaining areas l.t. 1 km

# --- drop coastal plain, disjunct regions and lobes and slivers ---
gp_filt_5070 <- gp_parts_5070 %>%
  st_make_valid() %>%
  filter(NA_L2NAME != "TEXAS-LOUISIANA COASTAL PLAIN") %>%
  filter(US_L4NAME != "Southern Blackland/Fayette Prairie") %>%  # disjunct
  filter(US_L4NAME != "Lower St. Croix and Vermillion Valleys") %>%  # odd lobe
  arrange(desc(NA_L3NAME)) %>%
  filter(!(area_gen_km2 == 62 & US_L4NAME == "Floodplains and Low Terraces")
         ) %>%
  filter(!(area_gen_km2 == 138 & US_L4NAME == "Floodplains and Low Terraces")
         )  %>%
dplyr::mutate(
  total_km2 = sum(part_area_km2),
  cum_km2   = cumsum(part_area_km2),
  cum_frac  = cum_km2/total_km2,
  area_gen_km2 = round(part_area_km2, digits = 0)
)

# --- merge to L3 level ---
names(gp_filt_5070)                    # get variable names at L4 level

gp_clean_5070 <- gp_filt_5070 %>%
  st_make_valid() %>%
  group_by(US_L3CODE, US_L3NAME, NA_L3CODE, NA_L3NAME,
    NA_L2CODE, NA_L2NAME, NA_L1CODE, NA_L1NAME,
    L3_KEY, L2_KEY, L1_KEY) %>%
  summarise(part_area_km2 = sum(as.numeric(st_area(geom))) / 1e6,
            .groups  = "drop",
            do_union = TRUE
  )  %>%
  dplyr::mutate(
    total_km2 = sum(part_area_km2),
    cum_km2   = cumsum(part_area_km2),
    cum_frac  = cum_km2/total_km2,
    area_gen_km2 = round(part_area_km2, digits = 0)
  )

# --- QA: get names ---
names(gp_clean_5070)                   # get updated variable names

# --- QA: visual check of results ---
ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_clean_5070,
          aes(geometry = geom,
              fill = NA_L3NAME),
          color = "gray90",
          linewidth = 0.1) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "QA Check: Study Area L3 Ecoregions"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l3_ecoreg_qa.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
)

# ------------------------------------------------------------------------------
# 3. Export results
# ------------------------------------------------------------------------------
# --- Export filtered ecoregion ---
out_dir <- file.path(here(), "data", "processed", "study_area",
                       "gp_ecoreg_5070.gpkg")
sf::st_write(gp_filt_5070,
             out_dir,
             layer = "gp_L3_ecoreg",
             quiet = TRUE
)
message("Wrote: ", out_dir)
