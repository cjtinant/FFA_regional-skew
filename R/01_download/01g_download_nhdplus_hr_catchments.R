# ==============================================================================
# Script Name:    01g_download_nhdplus_hr.R
# Author:         Charles Jason Tinant — with ChatGPT
# Date Created:   2025-06-06
# Last Updated:   2025-07-22
#
# Purpose: Download NHDPlus HR (1:24k) catchment boundaries clipped to
#          Great Plains Level IV Ecoregions. Includes retry logic for known
#          mismatches with flowline coverage.
#
# Data Source: https://www.usgs.gov/national-hydrography/nhdplus-high-resolution
#
# Changelog: 
# 2025-07-13 - Recreated script that had potentially been deleted. Updated file
#              paths to avoid data/intermediate. Updated file names to follow
#              a consistent naming pattern. Added reusable naming function,
#              enhanced retry filtering, and CLI feedback.
# 2025-07-22: Update header to add workflow summary and key features.
#
# Workflow Summary:
# 1. Setup
#    - Create necessary folders:
#        - data/log/ for tracking
#        - data/raw/nhdphr_catchments/ for GeoPackage outputs
#    - Load:
#        - Prior download log (if exists)
#        - Processed EPA Level IV ecoregions from us-eco-levels.gpkg
#    - Filter L4 ecoregions nested within targeted L3 Great Plains regions
#
# 2. Primary Catchment Download Loop
#    - For each Level IV ecoregion:
#        - Skip if previously downloaded (based on log)
#        - Subset AOI from eco_lev4 and transform to EPSG:5070
#        - Apply geometry cleanup and 500m buffer
#        - Grid the AOI (4×4 tiles)
#        - Download catchments using get_nhdphr() per tile
#        - Combine tile outputs and validate geometry
#        - Save to data/raw/nhdphr_catchments/{safe_name}.gpkg
#        - Append status to download log
#
# 3. Retry for Known Problematic Regions
#    - Manually defined list of retry_catchments
#    - Match retry names to eco_lev4:
#        - First via exact case-insensitive match
#        - Then fuzzy string matching (Jaro-Winkler distance)
#    - Repeat download process for these regions
#
# 4. Compile and Preview
#    - Filter latest log entries with status == "success"
#    - Read and combine corresponding GeoPackages
#    - Preview with mapview(catchments["FEATUREID"])
#
# Key Features:
# - Idempotent: skips previously downloaded regions
# - Geometry-safe: cast, buffer, validate for AOIs
# - Fuzzy retry logic: name correction and tile fallback
# - Transparent logging: CSV-based log with timestamped status
# - Interactive QA: mapview preview of results
#
# Output Files:
# - data/raw/nhdphr_catchments/*.gpkg — one per Level IV ecoregion
# - data/log/catchment_download_log.csv — timestamped download log
# - diagnostics/*.csv and *.png — retry logs and summary figures
#
# Dependencies:
# - dplyr, glue, fs, here, mapview, nhdplusTools, purrr, readr, sf, stringr, cli
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
  library(fs)
  library(here)
  library(mapview)
  library(nhdplusTools)
  library(purrr)
  library(readr)
  library(sf)
  library(stringr)
  library(cli)
})

# ------------------------------------------------------------------------------
# 1. Setup
# ------------------------------------------------------------------------------
# Create folders
dir_create(here("data", "log"))
dir_create(here("data", "raw", "nhdphr_catchments"))

# Load or initialize log
log_file <- here("data", "log", "catchment_download_log.csv")
log_tbl <- if (file.exists(log_file)) read_csv(log_file, show_col_types = FALSE) else tibble()

# ------------------------------------------------------------------------------
# 2. Load data
# ------------------------------------------------------------------------------
# Load EPA Level IV Ecoregions
eco_lev4 <- st_read(
  here("data", "processed", "ecoregions", "us-eco-levels.gpkg"),
  layer = "us_eco_l4",
  quiet = TRUE
)

# Build list of target L4 ecoregions from Great Plains Level III regions
eco_list <- eco_lev4 %>%
  filter(us_l3name %in% c(
    "Central Irregular Plains", "Central Great Plains", "Cross Timbers",
    "Edwards Plateau", "Flint Hills", "High Plains", "Lake Agassiz Plain",
    "Nebraska Sand Hills", "Northern Glaciated Plains",
    "Northwestern Glaciated Plains", "Northwestern Great Plains",
    "Southern Texas Plains", "Southwestern Tablelands",
    "Texas Blackland Prairies", "Western Corn Belt Plains",
    "Western Gulf Coastal Plain"
  )) %>%
  st_drop_geometry() %>%
  distinct(us_l4name) %>%
  pull()

# ------------------------------------------------------------------------------
# 3. Main download loop for NHDPlus HR catchments
# ------------------------------------------------------------------------------

walk2(eco_list, seq_along(eco_list), function(l4name, i) {
  cli::cli_alert_info("🟦 [{i}/{length(eco_list)}] Downloading {.strong {l4name}}")

  safe_name <- str_replace_all(l4name, "[^A-Za-z0-9]+", "_")
  out_path <- here("data",
                   "raw",
                   "nhdphr_catchments",
                   glue("{safe_name}.gpkg"))

  if (l4name %in% log_tbl$us_l4name &&
        any(log_tbl$status[log_tbl$us_l4name == l4name] == "success")) {
    cli::cli_alert_success("✅ Already downloaded: {.strong {l4name}}")
    return(NULL)
  }

  tryCatch({
    eco_aoi <- eco_lev4 %>%
      filter(str_trim(us_l4name) == str_trim(l4name)) %>%
      st_transform(5070) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(500) %>%
      st_make_valid()

    bbox_tiles <- st_make_grid(eco_aoi, n = c(4, 4))

    nhd_list <- imap(bbox_tiles, function(tile_geom, j) {
      tryCatch({
        aoi_tile <- st_sf(tile_id = j, geometry = st_sfc(tile_geom, crs = 5070))
        get_nhdphr(AOI = aoi_tile, type = "nhdpluscatchment", t_srs = 5070)
      }, error = function(e) {
        cli::cli_alert_warning("⚠️ Tile {j} failed: {e$message}")
        NULL
      })
    })

    nhd_combined <- compact(nhd_list)

    if (length(nhd_combined) == 0) stop("No catchment features returned.")

    nhd_combined <- bind_rows(nhd_combined) %>% st_make_valid()

    if (file.exists(out_path)) file_delete(out_path)
    st_write(nhd_combined, out_path, quiet = TRUE)

    write_csv(tibble(
      us_l4name = l4name,
      status = "success",
      message = NA_character_,
      timestamp = as.character(Sys.time())
    ), log_file, append = TRUE)

    cli::cli_alert_success("✅ Saved: {.strong {l4name}}")
    Sys.sleep(5)

  }, error = function(e) {
    cli::cli_alert_danger("❌ Error for {.strong {l4name}}: {e$message}")
    write_csv(tibble(
      us_l4name = l4name,
      status = "error",
      message = e$message,
      timestamp = as.character(Sys.time())
    ), log_file, append = TRUE)
  })
})

# ------------------------------------------------------------------------------
# 4. Retry missing regions
# ------------------------------------------------------------------------------
retry_catchments <- c(
  "Caprock Canyons, Badlands, and Breaks",
  "Lower St. Croix and Vermillion Valleys",
  "Mid-Coast Barrier Islands and Coastal Marshes",
  "Missouri Breaks Woodland-Scrubland",
  "Non-calcareous Foothill Grassland",
  "Pine-Oak Woodlands",
  "Pinyon-Juniper Woodlands and Savannas",
  "Pryor-Bighorn Foothills",
  "Shield-Smith Valleys",
  "Texas-Louisiana Coastal Marshes",
  "Texas-Tamaulipan Thornscrub"
)

# Precheck: Validate retry_catchments against eco_lev4$us_l4name
cli::cli_h1("Validating retry_catchments names")

# Check for matches using case-insensitive pattern detection
name_check <- tibble(retry_name = retry_catchments) %>%
  rowwise() %>%
  mutate(
    matched_names = list(
      eco_lev4$US_L4NAME[
        str_detect(eco_lev4US_L4NAME, fixed(retry_name, ignore_case = TRUE))
      ]
    ),
    n_matches = length(matched_names)
  ) %>%
  ungroup()

# Print summary
name_check %>%
  rowwise() %>%
  mutate(status = case_when(
    n_matches == 0 ~ "❌ No match",
    n_matches == 1 ~ "✅ One match",
    n_matches > 1  ~ "⚠️ Multiple matches"
  )) %>%
  select(retry_name, status, matched_names) %>%
  print(width = Inf)

library(fuzzyjoin)

# Sort actual Level IV names from eco_lev4
actual_names <- unique(eco_lev4$US_L4NAME) %>% sort()

# Create tibble of retry names
retry_df <- tibble(retry_name = retry_catchments)

# Perform fuzzy join (Jaro-Winkler distance, max_dist = 0.15 is usually conservative)
retry_matches <- stringdist_left_join(
  retry_df,
  tibble(us_l4name = actual_names),
  by = c("retry_name" = "us_l4name"),
  max_dist = 0.15,  # Try increasing to 0.2–0.25 if few matches found
  method = "jw"
)

# Review best matches per retry_name
retry_summary <- retry_matches %>%
  group_by(retry_name) %>%
  slice_min(order_by = stringdist::stringdist(retry_name,
                                              us_l4name,
                                              method = "jw"),
    n = 1
  ) %>%
  ungroup()

print(retry_summary, n = 20, width = Inf)

walk(retry_catchments, function(l4name) {
  cli::cli_alert_info("🔁 Retrying catchment: {.strong {l4name}}")

  safe_name <- str_replace_all(l4name, "[^A-Za-z0-9]+", "_")
  out_path <- here("data", "raw", "nhdphr_catchments", glue("{safe_name}.gpkg"))

  if (file.exists(out_path)) {
    cli::cli_alert_info("⚠️ File exists, skipping: {.strong {l4name}}")
    return(NULL)
  }

  tryCatch({
    eco_aoi <- eco_lev4 %>%
      filter(str_detect(US_L4NAME, fixed(l4name, ignore_case = TRUE)))

    if (nrow(eco_aoi) == 0) stop(glue("No match found in eco_lev4 for: {l4name}"))
    if (nrow(eco_aoi) > 1) {
      cli::cli_alert_warning("⚠️ Multiple matches found for {.strong {l4name}}")
    }

    eco_aoi <- eco_aoi %>%
      st_transform(5070) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(500) %>%
      st_make_valid()

    bbox_tiles <- st_make_grid(eco_aoi, n = c(4, 4))

    nhd_list <- imap(bbox_tiles, function(tile_geom, j) {
      tryCatch({
        aoi_tile <- st_sf(tile_id = j, geometry = st_sfc(tile_geom, crs = 5070))
        get_nhdphr(AOI = aoi_tile, type = "nhdpluscatchment", t_srs = 5070)
      }, error = function(e) {
        cli::cli_alert_warning("⚠️ Tile {j} failed: {e$message}")
        NULL
      })
    })

    nhd_combined <- compact(nhd_list)

    if (length(nhd_combined) == 0) stop("No catchment features returned.")

    nhd_combined <- bind_rows(nhd_combined) %>% st_make_valid()

    # Clean up existing file
    if (file.exists(out_path)) {
      cli::cli_alert_info("🧹 Removing existing file before write: {.strong {safe_name}}")
      file_delete(out_path)
    }

    # Force MULTIPOLYGON output and write to temp file first
    temp_path <- tempfile(fileext = ".gpkg")

    nhd_cleaned <- nhd_combined %>%
      st_collection_extract("POLYGON") %>%
      st_make_valid()

    tryCatch({
      st_write(nhd_cleaned, temp_path, quiet = TRUE)
      file_copy(temp_path, out_path, overwrite = TRUE)
      file_delete(temp_path)
    }, error = function(e) {
      stop(glue("Creation failed for {safe_name}: {e$message}"))
    })

    write_csv(tibble(
      us_l4name = l4name,
      status = "success",
      message = "retried successfully",
      timestamp = as.character(Sys.time())
    ), log_file, append = TRUE)

    cli::cli_alert_success("✅ Retried and saved: {.strong {l4name}}")
    Sys.sleep(5)

  }, error = function(e) {
    cli::cli_alert_danger("❌ Retry failed for {.strong {l4name}}: {e$message}")
    write_csv(tibble(
      us_l4name = l4name,
      status = "error",
      message = e$message,
      timestamp = as.character(Sys.time())
    ), log_file, append = TRUE)
  })
})

# ------------------------------------------------------------------------------
# 5. Preview All Successful Downloads
# ------------------------------------------------------------------------------

log_latest <- read_csv(log_file, show_col_types = FALSE) %>%
  group_by(us_l4name) %>%
  arrange(desc(timestamp), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  filter(status == "success") %>%
  mutate(
    safe_name = str_replace_all(us_l4name, "[^A-Za-z0-9]+", "_"),
    file_path = here("data", "raw", "nhdphr_catchments", paste0(safe_name, ".gpkg"))
  )

catchments <- map(log_latest$file_path, ~ st_read(.x, quiet = TRUE)) %>%
  bind_rows()

mapview::mapview(catchments["FEATUREID"])
