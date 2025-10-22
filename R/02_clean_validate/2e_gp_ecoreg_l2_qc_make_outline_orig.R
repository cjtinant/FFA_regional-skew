# ==============================================================================
# Script Name:     02e_gp_ecoreg_l2_qc_make_outline.R
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-04
# Last Updated:    2025-10-17
# Change Log:
#  2025-10-04      Initial script
#  2025-10-10      Refactor prior script to rank L1 Ecoregion polygon parts by
#                  area (e.g. examine and remove slivers) to keep a defensible
#                  subset. The refactored script removes:
#                   - the Texas Coastal Region polygons, which behaves
#                     differently in terms of flood frequency;
#                   - a disjunct L3 Ecoregion: the Texas Blackland Prairies;
#                   - small polygon parts (slivers)
#  2025-10-11      Fix issue with making a study outline, other QA issues.
#  2025-10-12      Merge duplicate scripts, update metadata in the header
#  2025-10-15      Begin visual QA for Texas Plains.
#  2025-10-17      Complete visual QA for Texas Plains.
#
# Purpose:         Make usable L2 Ecoregions to calculate zonal statistics, and
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
#                  (layer: us_eco_l2)
# Outputs:         data/processed/study_area/great_plains_outline.gpkg
#                  - gp_ecoreg_5070
#                  - gp_outline_5070     (cleaned/simplified outline, EPSG:5070;
#                    layers = gp_outline, gp_outline_simple)
# Notes:
# Visual QA at top of script exploring an issue with Texas disjunct region
#  - Unclear why EAST CENTRAL TEXAS PLAINS and
#  - SOUTH CENTRAL PLAINS are not in GP ecoregion.
#  A: Because they are part of the Eastern Temperate Forests L1 ecoregion.
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

# --- Load raw data ---
raw_l2_sf <- sf::st_read(gpkg_file, layer = "us_eco_l2", quiet = TRUE)

# --- filter some L1 Ecoregions ---
raw_l2_sf <- raw_l2_sf %>%
  dplyr::filter(NA_L1NAME != "WATER") %>%
  dplyr::filter(NA_L1NAME != "NORTHERN FORESTS") %>%
  dplyr::filter(NA_L1NAME != "MARINE WEST COAST FOREST") %>%
  dplyr::filter(NA_L1NAME != "NORTHERN FORESTS") %>%
  dplyr::filter(NA_L1NAME != "MEDITERRANEAN CALIFORNIA") %>%
  dplyr::filter(NA_L1NAME != "SOUTHERN SEMIARID HIGHLANDS") %>%
  dplyr::filter(NA_L1NAME != "TROPICAL WET FORESTS") #%>%
#  dplyr::filter(NA_L1NAME != "NORTHWESTERN FORESTED MOUNTAINS") %>%
#  dplyr::filter(NA_L1NAME != "TEMPERATE SIERRAS") %>%
  #   sf::st_make_valid() %>%
  # select(-area_km2)

# --- check l1 names ---
names_L1_filt <- raw_l2_sf %>%
  st_drop_geometry() %>%
  select(NA_L1NAME) %>%
  distinct()


# --- Visual QA: GP and some adjacent L1 Ecoregions ----
qa_ecoreg <- ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = raw_l2_sf,
          aes(geometry = geom,
          fill = NA_L1NAME),
          color = "gray90",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "L1 Ecoregions: NA Desert, Great Plains and Eastern Temperate Forests"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l1_ecoreg_qa.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
       )

# --- check l2 names ---
names_L2_filt <- raw_l2_sf %>%
  st_drop_geometry() %>%
  select(NA_L2NAME) %>%
  distinct()

# --- Visual QA: GP and some adjacent L2 Ecoregions ----
qa_ecoreg <- ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = raw_l2_sf,
          aes(geometry = geom,
              fill = NA_L2NAME),
          color = "gray90",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "L2 Ecoregions: L1 Great Plains and some L2 Ecoregions"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l2_ecoreg_raw.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
)

# --- filter many ecoregions ---
rare_l2_sf <- raw_l2_sf %>%
  dplyr::filter(NA_L2NAME != "OZARK/OUACHITA-APPALACHIAN FORESTS") %>%
  filter(NA_L2NAME != "MISSISSIPPI ALLUVIAL AND SOUTHEAST USA COASTAL PLAINS") %>%
  dplyr::filter(NA_L2NAME != "MIXED WOOD PLAINS") %>%
  dplyr::filter(NA_L2NAME != "COLD DESERTS") %>%
  dplyr::filter(NA_L2NAME != "CENTRAL USA PLAINS")


names_l2_filt2 <- rare_l2_sf %>%
  st_drop_geometry() %>%
  select(NA_L2NAME) %>%
  distinct()

qa_ecoreg <- ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = rare_l2_sf,
          aes(geometry = geom,
              fill = NA_L2NAME),
          color = "gray90",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "L2 Ecoregions: L1 Great Plains and some L2 Ecoregions"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l2_ecoreg_qa.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
)

# --- filter many ecoregions ---
med_rare_l2_sf <- rare_l2_sf %>%
  dplyr::filter(NA_L2NAME != "SOUTHEASTERN USA PLAINS") %>%
  dplyr::filter(NA_L2NAME != "WESTERN CORDILLERA") %>%
  dplyr::filter(NA_L2NAME != "UPPER GILA MOUNTAINS") %>%
#  dplyr::filter(NA_L1NAME != "TEMPERATE SIERRAS") %>%
dplyr::filter(NA_L2NAME != "SOUTHEASTERN USA PLAINS") %>%
  dplyr::filter(NA_L2NAME != "WARM DESERTS")

# --- check l2 names ---
names_L2_filt3 <- med_rare_l2_sf %>%
  st_drop_geometry() %>%
  select(NA_L2NAME) %>%
  distinct()

print(names_L2_filt3)


qa_l2_ecoreg <- ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = med_rare_l2_sf,
          aes(geometry = geom,
              fill = NA_L2NAME),
          color = "gray90",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "L2 Ecoregions: L2 Great Plains"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l2_ecoreg_gp_qa.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
)

# # --- Load raw data, filter Great Plains, validate ----
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
# 2. Drop coastal plains, disjunct area, and slivers
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

qa_ecoreg <- ggplot() +
  geom_sf(data = states_5070,
          aes(geometry = geom),
          fill = NA,
          color = "grey75",
          linewidth = 0.25
  ) +
  geom_sf(data = gp_filt_5070,
          aes(geometry = geom,
              fill = NA_L2NAME),
          color = "gray90",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "QA Check"
  ) +
  theme_minimal(base_size = 8) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank())

# --- save plot ---
out_path_qa_lat <- here("output", "qa_checks", "l2_ecoreg_qa2.png")
ggsave(out_path_qa_lat,
       bg     = "white",
       width  = 11,
       height = 8.5,
       unit   = "in"
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
# 3. QA checks
# ------------------------------------------------------------------------------
# --- Check IDs of kept parts (given cum_frac <= target_cover) and dropped ---
kept_ids <- gp_filt_5070 %>%
  st_drop_geometry()

dropped_ids <- gp_drop_5070 %>%
  st_drop_geometry()

# ------------------------------------------------------------------------------
# 4. Make outline
# ------------------------------------------------------------------------------
# --- parameters for simplifying outline ---
hole_km2 <- 14000      # fill holes smaller than this
part_km2 <- 200      # drop exterior parts smaller than this
#keep_frac <- 0.08    # ms_simplify keep fraction

# --- Merged filtered L2 Ecoregions ---
gp_merged <- gp_filt_5070 %>%
  st_make_valid() %>%
  st_union() %>%
  st_as_sf() %>%
  rename(geom = x) %>%
  st_set_geometry("geom")

# --- Fill interior holes (< hole_km2) ---
gp_noholes <- gp_merged %>%
  smoothr::fill_holes(threshold = set_units(hole_km2, km^2))

# --- Drop tiny exterior parts (< part_km2); keep only largest piece ---
gp_clean <- gp_noholes %>%
  st_make_valid() %>%
  st_cast("MULTIPOLYGON") %>%
  st_cast("POLYGON") %>%
  mutate(a_km2 = set_units(st_area(geom), km^2)) %>%
  filter(as.numeric(a_km2) >= part_km2) %>%
  select(-a_km2) %>%
  st_union() %>%
  st_as_sf()

# --- Keep only largest connected piece ---
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

# --- Check outline ---
summary(st_area(gp_clean))

# --- Visual QA check ---
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
  geom_sf(data = gp_noholes,
          aes(geometry = geom),
          alpha = 0.8,
          fill = "gray80",
          color = "grey35",
          linewidth = 0.2) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "GP Merged Outline and Simplified Outline"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), axis.title = element_blank())

# ------------------------------------------------------------------------------
# 5. Export results
# ------------------------------------------------------------------------------
# --- Export filtered ecoregion ---
out_dir <- file.path(here(), "data", "processed", "study_area",
                       "gp_ecoreg_5070.gpkg")

if (file.exists(out_dir)) fs::file_delete(out_dir)
sf::st_write(gp_filt_5070,
             out_dir,
             layer = "gp_L2_ecoreg",
             quiet = TRUE
)
message("Wrote: ", out_dir)

# --- Export outlines ---
out_path <- here("data", "processed", "study_area", "gp_outline_5070.gpkg")

st_write(gp_clean,
         dsn   = out_path,
         layer = "gp_outline_simple",
         delete_layer = TRUE)

st_write(gp_noholes,
         dsn   = out_path,
         layer = "gp_outline",
         delete_layer = TRUE)


