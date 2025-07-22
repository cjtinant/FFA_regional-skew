# ==============================================================================
# Script Name:    01o_download_statsgo2.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-06-28
# Last Updated:   2025-06-28
#
# Purpose:        Download STATSGO2 (national soil database) mapunit data
#                 clipped to GP Ecoregion using Soil Data Access (SDA).
#
# Workflow Summary:
# ------------------------------------------------------------------------------
# 1.   Load Great Plains Level I boundary as area of interest (AOI)
# 2.   Union and clean AOI polygon
# 3.   Query intersecting mupolygons via SDA_spatialQuery()
# 4.   Join mukeys to mapunit table via get_mapunit_from_SDA()
# 5.   Save results as CSV
#
# Output:
# -   STATSGO2 mapunit attributes for Great Plains Level I area
#
# Dependencies:
# - dplyr:         Data manipulation
# - fs             File system operations
# - here:          Consistent relative paths: locate files relative to proj root
# - purrr          Functional programming toolkit
# - readr          Reads rectangular data
# - sf             Support for simple feature access, a standardized way to
#                    encode and analyze spatial vector data. Binds to 'GDAL'
# - soilDb         Soil database interface
# ==============================================================================

# 1. Setup ---------------------------------------------------------------------
library(dplyr)
library(fs)
library(here)
library(purrr)
library(readr)
library(sf)
library(soilDB)


# Define output directories
in_dir  <- here("data", "raw", "statsgo2")
intermed_dir <- here("data", "intermediate", "statsgo2")
out_dir <- here("data", "processed", "statsgo2")
dir_create(in_dir)
dir_create(intermed_dir)
dir_create(out_dir)

# Load AOI: Great Plains Level I Ecoregion
aoi_path <- here("data", "processed", "ecoregions", "us-eco-levels.gpkg")
aoi <- st_read(aoi_path,
               layer = "us_eco_l1",
               quiet = TRUE) %>%
  filter(NA_L1NAME == "GREAT PLAINS") %>%
  st_transform(4326)  # SDA requires WGS84

# Union and clean AOI geometry
aoi_union <- st_union(aoi) %>%
  st_make_valid() %>%
  st_buffer(0)  # 0 distance fixes minor topology errors

# ==============================================================================
# 2. Spatial Query for STATSGO Mapunits (chunked) ------------------------------

message("🔍 Querying SDA for STATSGO2 mupolygons in chunks...")

# Break the AOI union into a grid (e.g. 2x2 or 3x3)
grid_chunks <- st_make_grid(aoi_union, n = c(3, 3))  # adjust n if needed

# Run SDA_spatialQuery for each chunk
mu_list <- map(seq_along(grid_chunks), function(i) {
  message("🧩 Querying chunk ", i, " of ", length(grid_chunks), "...")
  geom_chunk <- st_sf(geometry = grid_chunks[i])  # must wrap as sf
  tryCatch({
    SDA_spatialQuery(
      geom = geom_chunk,
      what = "mupolygon",
      db = "STATSGO",
      geomIntersection = FALSE
    )
  }, error = function(e) {
    message("❌ Chunk ", i, " failed: ", e$message)
    NULL
  })
})

# Combine all non-null results
mu_geom <- mu_list %>%
  compact() %>%
  map(function(chunk) {
    tryCatch(
      suppressWarnings(st_make_valid(chunk)),
      error = function(e) {
        message("⚠️ Failed to repair geometry: ", e$message)
      }
    )
  }) %>%
  compact() %>%
  bind_rows() %>%
  distinct(mukey, .keep_all = TRUE)

# Validate result
if (!inherits(mu_geom, "sf") || nrow(mu_geom) == 0) {
  stop("❌ SDA_spatialQuery returned no valid results across all chunks.")
}

message("✅ Retrieved ", nrow(mu_geom), " unique STATSGO mupolygons.")

# ==============================================================================
# 3. Get mapunit attributes ----------------------------------------------------

# Use get_mapunit_from_SDA to join mukeys to attributes
if (inherits(mu_geom, "sf")) {
  mukeys <- unique(mu_geom$mukey)
} else {
  stop("❌ SDA_spatialQuery() did not return an sf object. Check parameters and try again.")
}

message("📦 Querying SDA for mapunit attributes (", length(mukeys), " mukeys)...")

mu_attribs <- get_mapunit_from_SDA(WHERE = paste0("mukey IN (", paste(mukeys, collapse = ","), ")"))

message("✅ Retrieved mapunit attributes.")

# ==============================================================================
# 4. Export Results ------------------------------------------------------------

message("💾 Writing results to: ", out_dir)

write_csv(mu_geom,    file = path(out_dir, "statsgo2_mupolygon.csv"))
write_csv(mu_attribs, file = path(out_dir, "statsgo2_mapunit.csv"))

message("🎉 STATSGO2 download complete.")

message("🗺️ Saving spatial outputs for GIS...")

# Save WGS84 GeoPackage
gpkg_out_wgs84 <- path(intermed_dir, "statsgo2_mupolygon.gpkg")
st_write(mu_geom, gpkg_out_wgs84, delete_dsn = TRUE, quiet = TRUE)
message("📁 Saved WGS84 GeoPackage: ", gpkg_out_wgs84)

# Reproject to CONUS Albers Equal Area (EPSG:5070)
mu_geom_proj <- st_transform(mu_geom, crs = 5070)

gpkg_out_albers <- path(out_dir, "statsgo2_mupolygon.gpkg")
st_write(mu_geom_proj, gpkg_out_albers, delete_dsn = TRUE, quiet = TRUE)
message("📁 Saved projected GeoPackage (EPSG:5070): ", gpkg_out_albers)

# ==============================================================================
# 6. Verify joinability of mapunit attributes ----------------------------------

message("🔍 Verifying that mukey fields match between geometry and attributes...")

if (!"mukey" %in% names(mu_attribs)) {
  warning("⚠️ 'mukey' not found in mapunit attribute table.")
} else if (!"mukey" %in% names(mu_geom)) {
  warning("⚠️ 'mukey' not found in spatial geometry.")
} else {
  unmatched <- setdiff(mu_geom$mukey, mu_attribs$mukey)
  if (length(unmatched) == 0) {
    message("✅ All mukeys in geometry are present in attribute table.")
  } else {
    warning("⚠️ ", length(unmatched),
            " mukeys in geometry are missing from attribute table.")
  }
}
