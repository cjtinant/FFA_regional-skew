# ==============================================================================
# Script Name:     03c_make_macrozone_layer.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-08-01
# Last Updated:    2025-08-05
#
# Changelog:
# - 2025-08-01     Create initial script
# - 2025-08-04     Split initial script
# - 2025-08-05     Added aggregate splinters logiz
# - 2025-08-06     Finalize initial script
#                  - Merged L4 slivers <100 sq-km with nearest neighbors.
#                  - Dissolved to contiguous macrozone (mz) units
#                  - Relabeled mz polygons <1000 sq-km using nearest neighbors
#                  - Created generalized mz layer w clean spatial structure
#
# Purpose:         Create custom macrozones:Tallgrass, Mixed-Grass, and Shortgrass
#                  Prairie using metadata look-up tables created in
#                  `03b_make_macrozone_lut.R`.
#
# Workflow:
# 1. Load Level IV Great Plains Ecoregions layer.
# 2. Load metadata look-up tables.
# 3. Join Level IV layer to metadata.
# 4. Identify and merge slivers less than 100 sq-km.
# 5. Aggregate ecoregions into macrozones.
# 6. Generalize macrozones by relabeling macrozone polygons less than 1000 sq-km
#    using nearest neighbors.
# 7. Export results
#
# Input/Data URLs:
#   - `us_eco_l4` layer within us_eco_levels.gpkg
#   - docs/metadata/look_up_tables/ecoregion_l3_metadata_lut.csv
#   - docs/metadata/look_up_tables/ecoregion_l4_metadata_lut.csv
#
# Outputs:
#   - output/figs/macrozones_map.png
#   - data/processed/us_ecoregions/macrozones_gp.gpkg
#
# Dependencies:
#   tidyverse, here, sf
#
# Related Files:
#   - 03_make_macrozone_lut.R
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - notes/script-notes_and_developer-log.pdf
#   - milestone_03_prepare_covariates.pdf
# ==============================================================================
# --- Load libraries ---
library(tidyverse)
library(here)
library(sf)

# ------------------------------------------------------------------------------
# 1. Load Level IV Great Plains Ecoregions
# ------------------------------------------------------------------------------
eco_path <- here("data", "processed", "us_ecoregions", "us_eco_levels.gpkg")
layer_name <- "us_eco_l4"

eco_l4_gp <- st_read(eco_path, layer = layer_name) %>%
  filter(NA_L1NAME == "GREAT PLAINS")

# ------------------------------------------------------------------------------
# 2. Check and remove regions out of scope with the project
# ------------------------------------------------------------------------------
eco_l4_gp_summ <- eco_l4_gp %>%
  st_drop_geometry() %>%
  group_by(US_L4NAME) %>%
  summarise(
    min  = round(min(area_km2)),
    med  = round(median(area_km2)),
    mean = round(mean(area_km2)),
    max  = round(max(area_km2))
  )

eco_l4_gp_filtered <- eco_l4_gp %>%
  filter(!NA_L2NAME %in% "TEXAS-LOUISIANA COASTAL PLAIN")

# ------------------------------------------------------------------------------
# 2. Load Metadata Look-up Tables
# ------------------------------------------------------------------------------
lut_dir <- here("docs", "metadata", "look_up_tables")
l3_meta_lut <- read_csv(file.path(lut_dir, "ecoregion_l3_metadata_lut.csv"))
l4_meta_lut <- read_csv(file.path(lut_dir, "ecoregion_l4_metadata_lut.csv"))

# ------------------------------------------------------------------------------
# 3. Join Ecoregions to Macrozone Metadata
# ------------------------------------------------------------------------------
eco_l3_poly <- eco_l4_gp_filtered %>%
  left_join(l3_meta_lut, by = join_by(NA_L3CODE)) %>%
  filter(!is.na(macrozone))

eco_l4_poly <- eco_l4_gp_filtered %>%
  left_join(l4_meta_lut, by = join_by(US_L4CODE)) %>%
  filter(!is.na(macrozone))

eco_l3_l4_poly <- bind_rows(eco_l3_poly, eco_l4_poly) %>%
  arrange(US_L4CODE, NA_L3CODE)

# Check if all polygons were matched
if (nrow(eco_l4_gp_filtered) != nrow(eco_l3_l4_poly)) {
  message("⚠️ Not all L4 polygons were matched to metadata.")
}

# --- Add poly_id to polygons ---
eco_l3_l4_poly <- eco_l3_l4_poly %>%
  mutate(poly_id = row_number())

# Check CRS
epsg_code <- st_crs(eco_l3_l4_poly)$epsg

# --- clean up environment ---
rm(eco_l4_gp,
   l3_meta_lut,
   l4_meta_lut,
   eco_l3_poly,
   eco_l4_poly
)

# ------------------------------------------------------------------------------
# 4. Identify and Merge Slivers
# ------------------------------------------------------------------------------
# --- Identify small regions (< 100 sq-km) ---
slivers <- eco_l3_l4_poly %>%
  filter(area_km2 < 100) %>%
  mutate(sliver_id = row_number())

# --- Define candidate targets (non-slivers) ---
sources_no_slivers <- eco_l3_l4_poly %>%
  filter(!(poly_id %in% slivers$poly_id)) %>%
  mutate(source_id = row_number())

# --- Find slivers to all source polygons within 20 km ---
neighbors_idx <- st_is_within_distance(slivers, sources_no_slivers, dist = 2000)

# --- build table of neighbors ---
sliver_neighbors_tab <- map2_dfr(
  .x = slivers$sliver_id,
  .y = neighbors_idx,
  .f = function(sliver_id, neighbor_ids) {
    if (length(neighbor_ids) == 0) return(NULL)
    tibble(
      sliver_id = sliver_id,
      neighbor_id = neighbor_ids
    )
  }
)

# --- join names to slivers ---
sliver_neighbors <- left_join(sliver_neighbors_tab, slivers,
                              by = join_by(sliver_id)) %>%
  select(sliver_id:US_L4NAME, macrozone, geom) %>%
  rename(macrozone_sliver = macrozone,
         geom_sliver = geom,
         US_L4CODE_sliver = US_L4CODE,
         US_L4NAME_sliver = US_L4NAME,
         ) %>%
mutate(area_km2_sliver = round(
  as.numeric(st_area(geom_sliver)) / 1e6,
  digits = 1)) %>%
  left_join(., sources_no_slivers,
            by = c("neighbor_id" = "source_id")) %>%
  select(sliver_id:US_L4NAME, macrozone, geom, poly_id) %>%
  rename(macrozone_neighbor = macrozone,
         geometry_neighbor = geom,
         US_L4CODE_neighbor = US_L4CODE,
         US_L4NAME_neighbor = US_L4NAME
         )

# -- preview results ---
sliver_neighbors_flag <- sliver_neighbors %>%
  group_by(US_L4CODE_sliver, US_L4CODE_neighbor,
           US_L4NAME_sliver, US_L4NAME_neighbor,
           macrozone_sliver, macrozone_neighbor,
           area_km2_sliver
           ) %>%
  summarise(count = n(),
            .groups = "drop") %>%
  filter(macrozone_sliver != macrozone_neighbor)

# --- choose the closest sliver target for merge ---
slivers_with_targets <- sliver_neighbors %>%
  group_by(sliver_id) %>%
  slice(1) %>%  # Accept closest or preferred neighbor
  ungroup() %>%
  select(sliver_id, poly_id, merge_target_id = neighbor_id)

# --- map slivers and targets ---
merge_map <- slivers_with_targets %>%
  select(poly_id, merge_target_id)

eco_l3_l4_poly_with_merge <- eco_l3_l4_poly %>%
  left_join(merge_map, by = "poly_id") %>%
  mutate(
    final_merge_id = coalesce(merge_target_id, poly_id)  # Slivers take on target’s ID
  )

# --- finalize merge ---
eco_merged_poly <- eco_l3_l4_poly_with_merge %>%
  group_by(final_merge_id, macrozone) %>%  # Group by merge ID + macrozone
  summarise(
    area_km2 = sum(area_km2, na.rm = TRUE),  # Optionally re-calculate area
    geometry = st_union(geom),
    .groups = "drop"
  ) %>%
  mutate(area_km2 = round(as.numeric(st_area(geometry)) / 1e6,
         digits = 1))

# --- clean environment ---
rm(
  eco_l3_l4_poly_with_merge,
  eco_l3_l4_poly,
  eco_l4_gp_summ,
  merge_map,
  neighbors_idx,
  sliver_neighbors,
  sliver_neighbors_flag,
  sliver_neighbors_tab,
  slivers,
  slivers_with_targets,
  sources_no_slivers
)

# ------------------------------------------------------------------------------
# 5. Aggregate Ecoregions into Macrozones
# ------------------------------------------------------------------------------
# --- make multipolygons of regions ---
macrozone_parts <- eco_merged_poly %>%
  group_by(macrozone) %>%
  summarise(geometry = st_union(geometry), .groups = "drop")

# --- create unique polygons ---
macrozone_parts_exploded <- macrozone_parts %>%
  st_cast("POLYGON") %>%
  mutate(area_km2 = round(as.numeric(st_area(geometry)) / 1e6,
                          digits = 1)) %>%
  arrange(area_km2) %>%
  mutate(region_id = row_number()) # Assign a unique ID per contiguous piece

# --- plot results ---
ggplot(macrozone_parts_exploded) +
  geom_sf(aes(fill = macrozone), color = "white", size = 0.2) +
  scale_fill_viridis_d(name = "Macrozone") +
  theme_minimal() +
  labs(
    title = "Merged Ecoregions by Macrozone",
    subtitle = "Slivers merged into nearest polygon within same macrozone",
    caption = "Source: US EPA Ecoregions + Project-specific merges"
  )

# -- clean environment ---
rm(macrozone_parts)

# ------------------------------------------------------------------------------
# 6. Generalize Macrozones
# ------------------------------------------------------------------------------
# --- Identify small regions (< 1000 sq-km) ---
macro_slivers <- macrozone_parts_exploded %>%
  filter(area_km2 < 1000) %>%
  mutate(sliver_id = row_number())

macro_non_slivers <- macrozone_parts_exploded %>%
  filter(!(region_id %in% macro_slivers$region_id)) %>%
  mutate(source_id = row_number())

# Use st_nearest_feature to get index of closest larger polygon
nearest_idx <- st_nearest_feature(macro_slivers, macro_non_slivers)

# Join in macrozone of nearest neighbor
macro_slivers_updated <- macro_slivers %>%
  mutate(
    nearest_id = nearest_idx,
    new_macrozone = macro_non_slivers$macrozone[nearest_id]
  )

macro_generalized <- bind_rows(
  macro_non_slivers,                               # keep large ones as-is
  macro_slivers_updated %>%
    select(-macrozone) %>%
    rename(macrozone = new_macrozone)              # update sliver label
)

macro_gen_dissolved <- macro_generalized %>%
  group_by(macrozone) %>%
  summarise(geometry = st_union(geometry), .groups = "drop") %>%
  mutate(area_km2 = round(as.numeric(st_area(geometry)) / 1e6, 0))


# --- check results ---
macrozone_gen_exploded <- macro_gen_dissolved %>%
  st_cast("POLYGON") %>%
  mutate(area_km2 = round(as.numeric(st_area(geometry)) / 1e6,
                          digits = 1)) %>%
  arrange(area_km2) %>%
  mutate(region_id = row_number()) # Assign a unique ID per contiguous piece

# ------------------------------------------------------------------------------
# 7. Export Results
# ------------------------------------------------------------------------------
# --- plot and save results ---
ggplot(macro_gen_dissolved) +
  geom_sf(aes(fill = macrozone), color = "white", size = 0.2) +
  scale_fill_viridis_d() +
  theme_minimal() +
  labs(title = "Generalized Macrozones (Fragments <1000 sq-km Relabeled)")

out_path <- here("output", "figs", "macrozones_map.png")

ggsave(out_path,
       bg = "white",
       units = "in")

# --- save generalized macrozones ---
out_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")

st_write(macro_gen_dissolved, out_path)
