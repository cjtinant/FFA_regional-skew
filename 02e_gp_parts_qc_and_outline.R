# ==============================================================================
# Script Name:     02e_gp_parts_qc_and_outline.R
# Purpose:         Rank GP polygon parts by area, keep a defensible subset,
#                  build clean outline + bbox for elevatr.
# Author:          CJ Tinant — with GPT-5 Thinking
# Date Created:    2025-10-04
# Last Updated:    2025-10-04
# Inputs:          data/processed/us_ecoregions/us_eco_levels.gpkg
#                  (layer: us_eco_l1)
# Outputs:         data/processed/study_area/great_plains_outline.gpkg
#                  - gp_outline_5070       (cleaned/bridged outline, EPSG:5070)
# Notes:
# ==============================================================================
# --- Load libraries ---
suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
  library(sf)
  library(terra)
  library(maps)  # light basemap
})

# --- Load custom functions ---
source(file.path(here(), "R", "utils", "spatial", "as_sf_geom.R"))

# ------------------------------------------------------------------------------
# 1. Load and check inputs
# ------------------------------------------------------------------------------
# --- paths ---
gpkg_file <- file.path(
  here(), "data", "processed", "us_ecoregions", "us_eco_levels.gpkg")

out_dir   <- file.path(here(), "data", "processed", "study_area")
fs::dir_create(out_dir)
out_gpkg  <- file.path(out_dir, "great_plains_outline.gpkg")

stopifnot(file.exists(gpkg_file))

# --- Load raw data, filter Great Plains, validate ---
gp_raw_sf <- sf::st_read(gpkg_file, layer = "us_eco_l1", quiet = TRUE) %>%
  dplyr::filter(NA_L1NAME == "GREAT PLAINS") %>%
  sf::st_make_valid() %>%
  select(-area_km2)
sf::st_geometry(gp_raw_sf) <- "geom"

message("Raw GP features: ", nrow(gp_raw_sf))
message("Raw CRS: ", sf::st_crs(gp_raw_sf)$input %||% sf::st_crs(gp_raw_sf)$wkt)
message("Raw EPSG: ",sf::st_crs(gp_raw_sf)$epsg)

# --- quick QA ---
gp_raw_empty  <- sum(sf::st_is_empty(gp_raw_sf))
gp_raw_invalid <- sum(!sf::st_is_valid(gp_raw_sf))
message("Empty geoms: ", gp_raw_empty,
        " | invalid after st_make_valid(): ", gp_raw_invalid)
message("Raw CRS: ", sf::st_crs(gp_raw_sf)$input %||% sf::st_crs(gp_raw_sf)$wkt)
message("Raw EPSG: ", sf::st_crs(gp_raw_sf)$epsg)

# ------------------------------------------------------------------------------
# 2. Drop slivers and disjunct areas
# ------------------------------------------------------------------------------
# --- Explode areas rank (largest first) cumulative coverage ---
gp_parts_5070 <- gp_raw_sf %>%
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
stopifnot(nrow(gp_parts_5070) > nrow(gp_raw_sf))  # should be TRUE now

# --- Keep-set rule ---
target_cover <- 0.9995   # >= 99.95% total area

# --- drop according keep-set rule ---
gp_outline_5070 <- gp_parts_5070 %>%
  dplyr::filter(cum_frac <= target_cover) %>%
  dplyr::summarise(.groups = "drop") %>%
  sf::st_make_valid()
sf::st_geometry(gp_outline_5070) <- "geom"

# ------------------------------------------------------------------------------
# 3. Check and write results
# ------------------------------------------------------------------------------
# --- ids of parts we kept (given cum_frac <= target_cover) ---
kept_ids <- gp_parts_5070 %>% filter(cum_frac <= target_cover) %>% pull(part_id)

# --- Find dropped parts ---
dropped <- gp_parts_5070 %>% filter(!part_id %in% kept_ids)
summary_dropped <- dropped %>%
  summarise(
    n_parts    = dplyr::n(),
    drop_km2   = sum(part_area_km2),
    drop_frac  = drop_km2 / first(total_km2)
  )

print(summary_dropped)

dropped %>%
  arrange(desc(part_area_km2)) %>%
  select(part_id, part_area_km2) %>%
  print(n = 10)

# --- log coverage + counts ---
kept_frac <- max(gp_parts_5070$cum_frac[gp_parts_5070$cum_frac <= target_cover])
parts_before <- nrow(gp_parts_5070)
parts_kept   <- nrow(sf::st_cast(gp_outline_5070, "POLYGON"))
message(sprintf(
  "Kept coverage: %.5f ; parts: %d -> %d", kept_frac, parts_before, parts_kept
))

# --- write outputs ---
if (file.exists(out_gpkg)) fs::file_delete(out_gpkg)
sf::st_write(gp_outline_5070,
             out_gpkg,
             layer = "gp_outline_5070",
             quiet = TRUE
)
message("Wrote: ", out_gpkg)

# ------------------------------------------------------------------------------
# 4. Visual QA checks
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
  geom_sf(data = gp_outline_5070,
          aes(geometry = geom),
          fill = "grey90",
          color = "grey25",
          linewidth = 0.4) +
  coord_sf(crs = sf::st_crs(5070)) +
  labs(
    title    = "Great Plains outline (cleaned)",
    subtitle = sprintf("Kept coverage: %.3f  |  parts: %d → %d",
                       kept_frac, parts_before, parts_kept)
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), axis.title = element_blank())

# --- Plot of dropped parts ---
ggplot() +
  geom_sf(data = states_5070, aes(geometry = geom),
          fill = NA,
          color = "grey80",
          linewidth = 0.25) +
  # geom_sf(data = gp_outline_5070,
  #         aes(geometry = geom),
  #         fill = "grey92",
  #         color = "grey35",
  #         linewidth = 0.4) +
  geom_sf(data = dropped, aes(geometry = geom),
          fill = NA,
          color = "firebrick",
          linewidth = 0.6) +
  coord_sf(crs = st_crs(5070)) +
  labs(title = "Dropped GP parts (red)") +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(),
        axis.title = element_blank()
)
