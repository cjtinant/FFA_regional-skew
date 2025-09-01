# ==============================================================================
# Script Name:     03d_make_macrozone_layer.R
# Purpose:         Create custom macrozones
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-08-01
# Last Updated:    2025-08-14
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
# - 2025-08-14     Begin merge macrozone regions with low gage count. The approach
#                  uses a greedy loop to iteratively merge regions until all have
#                  at least 30 gages.
#
# Description:     Create custom macrozones: Tallgrass Prairie, Mixed-Grass
#                  Prairie, and Shortgrass Steppe using metadata look-up tables
#                  created in `03b_make_macrozone_lut.R`.
#
# Workflow:
#  1. Load ecoregions and metadata look-up tables
#  2. Summarise and remove regions out of scope with the project
#  3. Join Level IV layer to metadata.
#  4. Identify and merge slivers less than 100 sq-km.
#  5. Aggregate ecoregions into macrozones.
#  6. Generalize macrozones by relabeling macrozone polygons less than 1,000
#     sq-km using nearest neighbors.
#  7. Visualize results and assign region names
#  8. Merge generalized macrozone regions with low gage count (iterative), until
#     all have at least 30 gages.
# 9. Classify gages by macroregion coverage, add region attrs, QA.
# 9. Export updated list of gages, macrozone polygons, macrozone map.
#
# Input/Data URLs:
#   - `us_eco_l4` layer within us_eco_levels.gpkg
#   - docs/metadata/look_up_tables/ecoregion_l3_metadata_lut.csv
#   - docs/metadata/look_up_tables/ecoregion_l4_metadata_lut.csv
#
# Outputs:
#   - data/processed/peakflow_gages/gage_covars.gpkg
#   - data/processed/us_ecoregions/macrozones_gp.gpkg
#   - output/figs/macrozones_map_poster.png
#
# Dependencies:
#   ggrepel, here, RColorBrewer, ragg, sf, tidyverse, units
#
# Related Files:
#   - 03_make_macrozone_lut.R
#   - data/log_README.pdf
#   - R/log_README.pdf
#   - R/README.pdf
#   - notes/script-notes_and_developer-log.pdf
#   - milestone_03_prepare_covariates.pdf
#
# Next Steps:
#   - finish export of results
#
# ==============================================================================
# --- Load libraries ---
library(ggrepel)
library(here)
library(ragg)
library(RColorBrewer)
library(sf)
library(tidyverse)
library(units)
#set.seed(42)

# --- Load custom functions ---
source(file.path(here(), "R", "utils", "spatial", "vector_helpers.R"))

# ------------------------------------------------------------------------------
# 1. Load ecoregions and metadata look-up tables
# ------------------------------------------------------------------------------
# --- Load L4 ecoregions ---
eco_path <- here("data", "processed", "us_ecoregions", "us_eco_levels.gpkg")
layer_name <- "us_eco_l4"
gage_path <- here("data", "processed", "peakflow_gages", "stations_covars.gpkg")

# --- Load metadata look-up tables ---
lut_dir <- here("docs", "metadata", "look_up_tables")
l3_meta_lut <- read_csv(file.path(lut_dir, "ecoregion_l3_metadata_lut.csv"))
l4_meta_lut <- read_csv(file.path(lut_dir, "ecoregion_l4_metadata_lut.csv"))

# --- filter L1 Great Plains ---
eco_l4_gp <- st_read(eco_path, layer = layer_name) %>%
  filter(NA_L1NAME == "GREAT PLAINS")

gages_df <- st_read(gage_path)

# --- enforce 'geom' as active sf column ---
eco_l4_gp <- ensure_geom(eco_l4_gp)
gages_df  <- ensure_geom(gages_df)

# ------------------------------------------------------------------------------
# 2. Summarise and remove regions out of project scope
# ------------------------------------------------------------------------------
# --- Summarise L4 ecoregions ---
eco_l4_gp_summ <- eco_l4_gp %>%
  st_drop_geometry() %>%
  group_by(NA_L2NAME, US_L3NAME, US_L4NAME) %>%
  summarise(
    min  = round(min(area_km2)),
    med  = round(median(area_km2)),
    mean = round(mean(area_km2)),
    max  = round(max(area_km2))
  ) %>%
  arrange(min, med)

eco_l4_gp_filtered <- eco_l4_gp %>%
  filter(!NA_L2NAME %in% "TEXAS-LOUISIANA COASTAL PLAIN")

# ------------------------------------------------------------------------------
# 3. Join ecoregions to macrozone metadata
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
# 4. Identify and merge slivers (< 100 sq-km)
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
# start with border touches; if none, escalate search radius
touch_list <- st_touches(slivers, sources_no_slivers)

radii <- c(2000, 5000, 10000, 20000)  # m
cand_idx <- map2(seq_len(nrow(slivers)), touch_list, function(k, nbrs) {
  if (length(nbrs) > 0) return(nbrs)
  # escalate radii until we find someone
  for (R in radii) {
    cand <- st_is_within_distance(slivers[k, ], sources_no_slivers, dist = R)[[1]]
    if (length(cand) > 0) return(cand)
  }
  integer(0)
})

# rank candidates by (1) same macrozone, (2) distance, (3) area
sliver_neighbors_tab <- map_dfr(seq_len(nrow(slivers)), function(k) {
  nbrs <- cand_idx[[k]]
  if (length(nbrs) == 0) return(NULL)
  d <- st_distance(slivers[k, ], sources_no_slivers[nbrs, ]) %>%
    drop_units() %>%
  as.numeric()
  tibble(sliver_id = slivers$sliver_id[k], neighbor_id = nbrs, dist_m = d)
})

sliver_neighbors <- sliver_neighbors_tab %>%
  left_join(slivers %>% st_drop_geometry() %>%
              select(sliver_id, macrozone_sliver = macrozone),
            by = "sliver_id") %>%
  left_join(sources_no_slivers %>% st_drop_geometry() %>%
              mutate(neighbor_id = source_id) %>%
              select(neighbor_id, macrozone_neighbor = macrozone, area_km2),
            by = "neighbor_id")

slivers_with_targets <- sliver_neighbors %>%
  arrange(sliver_id,
          macrozone_sliver != macrozone_neighbor,   # same macrozone first
          dist_m,                                   # then nearest
          desc(area_km2)) %>%                       # then bigger
  group_by(sliver_id) %>%
  slice(1) %>%
  ungroup() %>%
  select(sliver_id, merge_target_id = neighbor_id)

# --- map slivers and targets ---
eco_l3_l4_poly_with_merge <- eco_l3_l4_poly %>%
  left_join(slivers_with_targets,
            by = join_by(poly_id == sliver_id)
            ) %>%
  mutate(
    final_merge_id = coalesce(merge_target_id, poly_id)  # Slivers take target ID
)

# --- finalize merge ---
eco_merged_poly <- eco_l3_l4_poly_with_merge %>%
  group_by(final_merge_id, macrozone) %>%  # Group by merge ID + macrozone
  summarise(
    area_km2 = sum(area_km2, na.rm = TRUE),  # Optionally re-calculate area
    geom = st_union(geom),
    .groups = "drop"
  ) %>%
  mutate(area_km2 = round(as.numeric(st_area(geom)) / 1e6,
         digits = 1)
         ) %>%
  arrange(area_km2)

# --- clean environment ---
rm(
  eco_l3_l4_poly_with_merge,
  eco_l3_l4_poly,
  eco_l4_gp_summ,
  cand_idx,
  sliver_neighbors,
  sliver_neighbors_tab,
  slivers,
  slivers_with_targets,
  sources_no_slivers
)

# ------------------------------------------------------------------------------
# 5. Aggregate ecoregions into macrozones
# ------------------------------------------------------------------------------
# --- make multipolygons of regions ---
macrozone_parts <- eco_merged_poly %>%
  group_by(macrozone) %>%
  summarise(geom = st_union(geom), .groups = "drop")

# --- create unique polygons ---
macrozone_parts_exploded <- macrozone_parts %>%
  st_cast("POLYGON") %>%
  mutate(area_km2 = round(as.numeric(st_area(geom)) / 1e6,
                          digits = 1)) %>%
  arrange(area_km2) %>%
  mutate(region_id = row_number()) # Assign a unique ID per contiguous piece

# --- plot results ---
map_eco_merge <- ggplot(macrozone_parts_exploded) +
  geom_sf(aes(fill = macrozone), color = "white", size = 0.2) +
  scale_fill_viridis_d(name = "Macrozone") +
  theme_minimal() +
  labs(
    title = "Merged Ecoregions by Macrozone",
    subtitle = "Slivers merged into nearest polygon within same macrozone",
    caption = "Source: US EPA Ecoregions + Project-specific merges"
  )

# map_eco_merge

# -- clean environment ---
rm(macrozone_parts)

# ------------------------------------------------------------------------------
# 6. Generalize macrozones
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
  summarise(geom = st_union(geom), .groups = "drop") %>%
  mutate(area_km2 = round(as.numeric(st_area(geom)) / 1e6, 0))


# --- check results ---
macrozone_gen_exploded <- macro_gen_dissolved %>%
  st_cast("POLYGON") %>%
  mutate(area_km2 = round(as.numeric(st_area(geom)) / 1e6,
                          digits = 1)) %>%
  arrange(area_km2) %>%
  mutate(region_id = row_number()) # Assign a unique ID per contiguous piece

# --- clean up ---
rm(
  eco_l4_gp_filtered,
  eco_merged_poly,
  macro_generalized,
  macro_non_slivers,
#  nearest_idx,
  macro_gen_dissolved,
  macro_slivers,
  macro_slivers_updated,
  macrozone_parts_exploded
)

# ------------------------------------------------------------------------------
# 7. Visualize results and assign region names
# ------------------------------------------------------------------------------
# --- make a table of region names ---
region_names <- tribble(
  ~region_id, ~region_name,
  1, "Mixed-Grass Tablelands Breaks and Valleys",
  2, "Mixed-Grass Carbonate Cross-Timbers",
  3, "Shortgrass-Steppe Sand Dunes",
  4, "Shortgrass-Steppe Sand Dunes",
  5, "Mixed-Grass Tablelands Breaks and Valleys",
  6, "Mixed-Grass Tablelands Breaks and Valleys",
  7, "Mixed-Grass Tablelands Breaks and Valleys",
  8, "Shortgrass-Steppe Llano Uplift Basin",
  9, "Mixed-Grass Pine-Oak Woodlands and Foothills",
  10, "Tallgrass Fayette Prairie",
  11, "Southern Mixed-Grass Prairie",
  12, "Central Mixed-Grass Prairie",
  13, "Shortgrass-Steppe",
  14, "Northern Mixed-Grass Prairie",
  15, "Prairie Tallgrass Prairie"
)

# --- join region name table ---
macrozone_regions <- left_join(region_names, macrozone_gen_exploded,
                              by = join_by(region_id)) %>%
  select(-region_id) %>%
  arrange(macrozone, region_names) #%>%
#  rename(geom = geometry)

# --- assign colors ---
region_colors <- c(
  # Purples for Tallgrass
  tallgrass_colors <- brewer.pal(3, "Purples")[2:3],  # skip lightest

  # Oranges for Shortgrass
  shortgrass_colors <- brewer.pal(5, "Oranges")[2:4],  # nice warm gradient

  # Greens for Mixed-Grass
  mixedgrass_colors <- brewer.pal(9, "YlGn")[4:9],  # medium to dark green shades

  # Tallgrass (purples)
  "Tallgrass Fayette Prairie" = tallgrass_colors[1],
  "Prairie Tallgrass Prairie" = tallgrass_colors[2],

  # Shortgrass (oranges)
  "Shortgrass-Steppe Sand Dunes"          = shortgrass_colors[1],
  "Shortgrass-Steppe Llano Uplift Basin"  = shortgrass_colors[2],
  "Shortgrass-Steppe"                     = shortgrass_colors[3],

  # Mixed-Grass (greens)
  "Mixed-Grass Tablelands Breaks and Valleys"       = mixedgrass_colors[1],
  "Mixed-Grass Carbonate Cross-Timbers"             = mixedgrass_colors[2],
  "Mixed-Grass Pine-Oak Woodlands and Foothills"    = mixedgrass_colors[3],
  "Southern Mixed-Grass Prairie"                    = mixedgrass_colors[4],
  "Central Mixed-Grass Prairie"                     = mixedgrass_colors[5],
  "Northern Mixed-Grass Prairie"                    = mixedgrass_colors[6]
)

# --- plot results ---
map_gen_macrozone <- ggplot(macrozone_regions) +
  geom_sf(aes(fill = region_name, geometry = geom),   # geometry = geom)
          color = "white", linewidth = 0.2) +
  scale_fill_manual(values = region_colors, name = "Named Region") +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 9),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5)
  ) +
  labs(
    title = "Generalized Macrozone Regions",
    subtitle = "Colors grouped by macrozone: Tallgrass (purple), Mixed-Grass 
    (green), Shortgrass (orange)"
  ) +
  guides(fill = guide_legend(
    title.position = "top",
    ncol = 2,                        # or ncol = 3
    byrow = TRUE,
    label.theme = element_text(size = 9)
  ))

# --- clean up ---
rm(
  region_names,
  macrozone_gen_exploded
)

# ------------------------------------------------------------------------------
# Step 8 (iterative): Merge regions until all have at least 30 gages
# ------------------------------------------------------------------------------
# # --- prepare for gage counts ---
macrozone_regions <- macrozone_regions %>%
  rownames_to_column(var = "macro_id") %>%
  mutate(macro_id = as.numeric(macro_id))

# -- ensure geometry column is active ---
stopifnot("geom" %in% names(macrozone_regions))
st_geometry(macrozone_regions) <- "geom"

# -- count gages strictly inside each region --
gage_counts <- gages_df %>%
  st_join(macrozone_regions %>%
            select(macro_id), join = st_within, left = FALSE) %>%
  st_drop_geometry() %>%
  count(macro_id, name = "n_gages")

# --- add counts, prepare starting criteria for gages --
macro_regions_merge <- macrozone_regions %>%
  left_join(gage_counts, by = "macro_id") %>%
  mutate(n_gages = coalesce(n_gages, 0L))

# --- drop disjunct prairie region w/ small gage count ---
macro_regions_merge <- macro_regions_merge %>%
  filter(region_name != "Tallgrass Fayette Prairie")

# -------------------------- parameters ----------------------------------------
min_gages <- 30L     # <- your stopping criterion
max_iter  <- 1000L   # safety valve
# -----------------------------------------------------------------------------

# --- helper: recompute neighbors (touching) each iteration ---
touch_list <- function(x) st_touches(x)

# --- helper: pick best target for index i ---
pick_target <- function(i, z, tl) {
  nbr_idx <- tl[[i]]
  # if isolated (no shared border), fall back to single nearest
  if (length(nbr_idx) == 0) {
    nearest <- st_nearest_feature(z[i, ], z)
    nbr_idx <- setdiff(nearest, i)
    if (length(nbr_idx) == 0) return(NA_integer_)
  }
  
  cand <- z %>%
    st_drop_geometry() %>%
    slice(nbr_idx) %>%
    mutate(idx = nbr_idx)
  
  # prefer same macrozone; otherwise allow cross-macrozone only if
  # no same-macrozone neighbor
  same_cand <- cand %>% filter(macrozone == z$macrozone[i])
  pool <- if (nrow(same_cand) > 0) same_cand else cand
  
  d <- st_distance(z[i, ], z[pool$idx, , drop = FALSE]) %>% drop_units()
  pool %>%
    mutate(.dist = as.numeric(d)) %>%
    arrange(desc(n_gages), desc(area_km2), .dist) %>%
    slice(1) %>%
    pull(idx)
}

merge_log <- tibble(
  iter = integer(), source_id = integer(), target_id = integer(),
  source_name = character(), target_name = character(),
  source_macro = character(), target_macro = character(),
  source_gages = integer(), target_gages = integer(),
  merged_gages = integer(), distance_m = double()
)

iter <- 0L

repeat {
  iter <- iter + 1L
  if (iter > max_iter) {
    warning("Reached max_iter without satisfying threshold.")
    break
  }
  
  # find regions below threshold
  low_idx <- which(macro_regions_merge$n_gages < min_gages)
  if (length(low_idx) == 0) break
  
  # greedy: pick the worst (fewest gages); tie-break by smallest area
  i <- low_idx[order(macro_regions_merge$n_gages[low_idx],
                     macro_regions_merge$area_km2[low_idx])[1]]
  
  # recompute neighbor graph for current topology
  tl <- touch_list(macro_regions_merge)
  
  j <- pick_target(i, macro_regions_merge, tl)
  if (is.na(j)) {
    warning("No available neighbor for macro_id ",
            macro_regions_merge$macro_id[i], "; stopping.")
    break
  }
  
  # compute distance (centroid-to-centroid) for logging
  d_ij <- as.numeric(st_distance(
    st_point_on_surface(macro_regions_merge[i, ]$geom),
    st_point_on_surface(macro_regions_merge[j, ]$geom)
  ))
  
  # build merged feature: keep TARGET's identity & labels
  target   <- macro_regions_merge[j, ]
  source   <- macro_regions_merge[i, ]
  new_geom <- st_make_valid(st_union(source$geom, target$geom))
  new_row  <- target %>%
    mutate(
      geom  = new_geom,
      area_km2  = round(as.numeric(st_area(new_geom)) / 1e6, 1),
      n_gages   = target$n_gages + source$n_gages
    )
  
  # update table: drop source+target then add merged target
  macro_regions_merge <- bind_rows(
    macro_regions_merge[-c(i, j), ],
    new_row
  ) %>% arrange(macrozone, region_name)
  st_geometry(macro_regions_merge) <- "geom"
  
  # append to log
  merge_log <- add_row(
    merge_log,
    iter         = iter,
    source_id    = source$macro_id,
    target_id    = target$macro_id,
    source_name  = source$region_name,
    target_name  = target$region_name,
    source_macro = source$macrozone,
    target_macro = target$macrozone,
    source_gages = source$n_gages,
    target_gages = target$n_gages,
    merged_gages = as.integer(new_row$n_gages),
    distance_m   = as.numeric(d_ij)
  )
}

# --- geometry still active? ---
stopifnot(identical(attr(macro_regions_merge, "sf_column"), "geom"))

# --- stop rule satisfied? ---
stopifnot(min(macro_regions_merge$n_gages) >= min_gages)

# --- check for weird geometries ---
any(!st_is_valid(macro_regions_merge))        # should be FALSE
summary(st_area(macro_regions_merge))         # sanity on areas
macro_regions_merge %>%
  st_drop_geometry() %>%
  arrange(n_gages) %>%
  select(region_name, macrozone, n_gages, area_km2) %>%
  print(n = Inf)


zones_iter <- list(zones = macro_regions_merge, log = merge_log)

# --- quick QA summary ---
zones_iter$zones %>%
  st_drop_geometry() %>%
  summarise(
    n_regions = dplyr::n(),
    min_gages = min(n_gages),
    q25 = quantile(n_gages, 0.25),
    median = median(n_gages),
    mean = mean(n_gages),
    max_gages = max(n_gages)
  ) %>% print()

# --- plot results ---
map_macro_merge <- ggplot(macro_regions_merge) +
  geom_sf(aes(fill = region_name, geometry = geom),   # geometry = geom)
          color = "white", linewidth = 0.2) +
  scale_fill_manual(values = region_colors, name = "Named Region") +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 9),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5)
  ) +
  labs(
    title = "Final Macrozone Regions",
    subtitle = "Macroregions with a minimum of 30 gages"
  ) +
  guides(fill = guide_legend(
    title.position = "top",
    ncol = 2,                        # or ncol = 3
    byrow = TRUE,
    label.theme = element_text(size = 9)
  ))

# map_macro_merge

# ------------------------------------------------------------------------------
# 9. Classify gages by macroregion coverage, add region attrs, QA
# ------------------------------------------------------------------------------
# --- Union + prepare (slightly faster & safer) ---
macro_union <- st_make_valid(st_union(st_geometry(macro_regions_merge)))

# --- Make boundary-inclusive membership flag ---
in_macro <- st_covered_by(gages_df, macro_union, sparse = FALSE)[, 1]

gages_flagged <- gages_df %>%
  mutate(in_macro = in_macro)

# --- Join region attributes for inside points (kept NA for outside) ---
gages_flagged <- gages_flagged %>%
  st_join(
    macro_regions_merge %>% select(macro_id, region_name, macrozone),
    join = st_covered_by, left = TRUE
  )

# --- Quick counts and sanity check ---
summary_counts <- gages_flagged %>%
  st_drop_geometry() %>%
  summarise(
    n_total   = dplyr::n(),
    n_inside  = sum(in_macro, na.rm = TRUE),
    n_outside = sum(!in_macro, na.rm = TRUE)
  )

print(summary_counts)

gages_to_drop %>%
  st_drop_geometry() %>%
  group_by(tier) %>%
  summarise(
    N = n(),
    lat_min  = min(lat_dd),
    lat_max  = max(lat_dd),
    long_min = min(long_dd),
    long_max = max(long_dd),
    alt_min  = min(alt_m),
    alt_max  = max(alt_m)
)

# --- nearest region + distance for the outside set (QA) ---
if (any(!gages_flagged$in_macro)) {
  out_idx <- which(!gages_flagged$in_macro)
  nn      <- st_nearest_feature(gages_flagged[out_idx, ], macro_regions_merge)
  d_m     <- as.numeric(st_distance(
    st_point_on_surface(gages_flagged[out_idx, ]$geom),
    st_point_on_surface(macro_regions_merge[nn, ]$geom),
    by_element = TRUE
  ))
  
  gages_outside_qc <- gages_flagged[out_idx, ] %>%
    mutate(nearest_region = macro_regions_merge$region_name[nn],
           nearest_macro  = macro_regions_merge$macrozone[nn],
           dist_to_region_m = d_m) %>%
    st_drop_geometry()
  
  print(gages_outside_qc %>%
          count(nearest_macro, nearest_region, .drop = FALSE) %>%
          arrange(desc(n)))
}

# ------------------------------------------------------------------------------
# 8. Export gages, map, 
# ------------------------------------------------------------------------------
# --- Make gage subsets for export ---
gages_to_keep  <- gages_flagged %>% filter(in_macro)
gages_to_drop  <- gages_flagged %>% filter(!in_macro)

# --- Write updated layer (for tracking) and layer for modeling ---
out_gpkg_all <- here("data","processed","peakflow_gages","gage_covars_all.gpkg")
st_write(gages_flagged,
         dsn = out_gpkg_all,
         layer = "gage_covars",
         delete_layer = TRUE)

out_gpkg_filt <- here("data","processed","peakflow_gages","gage_covars.gpkg")
st_write(gages_to_keep,
         dsn = out_gpkg_filt,
         layer = "gage_covars",
         delete_layer = TRUE)

# --- add a drop log ---
out_csv <- gages_to_drop %>%
  st_drop_geometry()

write_csv(out_csv,
          here("data","processed","peakflow_gages","gage_covars_dropped.csv")
)

# --- export poster quality (big canvas) map ---
map_out_path <- here("output","figs","macroregions_map_poster.png")

ggsave(
  plot     = map_macro_merge,
  filename = map_out_path,
  device   = ragg::agg_png,              # high-quality PNG
  width    = 20, height = 14, units = "in",
  dpi      = 600,
  bg       = "white",
  limitsize = FALSE                      # allow >50 in if you go even bigger
)

# --- save generalized macrozones ---
out_path <- here("data", "processed", "us_ecoregions", "macrozones_gp.gpkg")

st_write(macro_regions_merge,
         dsn = out_path,
         layer = "macrozones_gp",
         delete_layer = TRUE)
