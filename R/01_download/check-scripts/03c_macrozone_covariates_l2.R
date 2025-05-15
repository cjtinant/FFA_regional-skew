# ------------------------------------------------------------------------------
# 03c_macrozone_covariates_l2.R
# Purpose: Assign Great Plains macrozones (tallgrass, shortgrass, etc.)
# Source: Derived from NA Ecoregion Level II shapefile, filtered to CONUS
# Output: Clean macrozone polygons with area in EPSG:5070
# ------------------------------------------------------------------------------

library(sf)
library(tidyverse)
library(here)

# 1. Load Level II ecoregions (North American extent)
eco_l2_path <- here("data/raw/vector_raw/ecoregions_unprojected/NA_eco_lev2_GreatPlains_geographic.gpkg")
eco_l2 <- sf::read_sf(eco_l2_path)

# 2a. Load Level I ecoregions for masking
us_l1_path <- here("data/raw/vector_raw/ecoregions_unprojected/NA_eco_lev1_GreatPlains_geographic.gpkg")
us_l1 <- sf::read_sf(us_l1_path)

# 2b. Filter to CONUS Great Plains
us_l1_gp <- us_l1 %>%
  filter(na_l1name == "GREAT PLAINS")

# 3. Spatial filter — keep only Level II polygons intersecting CONUS GP
eco_l2 <- st_make_valid(eco_l2)
us_l1_gp <- st_make_valid(us_l1_gp)

# Ensure CRS compatibility
stopifnot(st_crs(eco_l2) == st_crs(us_l1_gp))

eco_l2_conus <- st_filter(eco_l2, us_l1_gp, .predicate = st_intersects)

# 4. Create macrozone classification key
macrozone_key <- tribble(
  ~na_l2name,                           ~macrozone,
  "TEMPERATE PRAIRIES",                "tallgrass",
  "WEST-CENTRAL SEMIARID PRAIRIES",    "mixedgrass",
  "SOUTH CENTRAL SEMIARID PRAIRIES",   "shortgrass",
  "TEXAS-LOUISIANA COASTAL PLAIN",     "semidesert",
  "TAMAULIPAS-TEXAS SEMIARID PLAIN",   "semidesert"
)

# 5. Join macrozones to filtered Level II
eco_macrozone_conus <- eco_l2_conus %>%
  mutate(na_l2name = str_trim(na_l2name)) %>%
  left_join(macrozone_key, by = "na_l2name")

# 6. Clean columns + compute area in meters
eco_macrozone_conus_clean <- eco_macrozone_conus %>%
  select(-shape_leng, -shape_le_1, -shape_area, -text_x, -text_y) %>%
  st_transform(5070) %>%
  mutate(area_m2 = st_area(geometry))

# 7. Save to processed spatial folder
output_path <- here("data/processed/spatial/gp_macrozone_derived_5070.gpkg")

st_write(eco_macrozone_conus_clean, output_path, delete_layer = TRUE)

# Optional: Print summary table
eco_macrozone_conus_clean %>%
  st_drop_geometry() %>%
  count(macrozone, sort = TRUE)

