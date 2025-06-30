# ==============================================================================
# Script Name:    01d_download_nhdplus_hr.R
# Author:         Charles Jason Tinant — with ChatGPT
# Purpose:        Download NHDPlus HR catchments by Level IV Ecoregion
# Date Created:   2025-06-06
# Last Updated:   2025-06-18
#
# Purpose:         Download NHDPlus HR (1:24k) catchment boundaries clipped to
#                  Great Plains
#
# Data URLs: https://www.usgs.gov/national-hydrography/nhdplus-high-resolution
#
# Workflow Summary:
# 1.   Create download folders.
# 2.   Make a list of Level 4 Ecoregions to prepare for download.
# 3.   Split Level 4 Ecoregions into a 5x5 grid for smaller AOI.
# 4.   Preview downloads.
#
# Output:
# -    NHDplus catchment boundaries for the Great Plains Ecoregion aggregated at
#      the Level IV Ecoregion scale.
#
# Dependencies:
# -   dplyr        -   Data manipulation
# -   fs           -   File system operations
# -   glue         -   Formats strings
# -   here         -   Locates files relative to a project root
# -   mapview      -   Interactive viewing of spatial data
# -   nhdplusTools -   Tools for traversing and working with National
#                      Hydrography Dataset Plus (NHDPlus) data.
# -   purrr        -   Functional programming toolkit
# -   readr        -   Reads rectangular data
# -   sf           -   Support for simple feature access, a standardized way to
#                      encode and analyze spatial vector data. Binds to 'GDAL'
# -   stringr      -   Wrappers for string operations
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
})

# ------------------------------------------------------------------------------
# 1. Setup
# ------------------------------------------------------------------------------

# --- make folders
dir_create(here("data", "log"))
dir_create(here("data", "intermediate", "nhdphr_catchments_by_ecoregion"))

# --- make log file
log_file <- here("data", "log", "catchment_download_log.csv")

log_tbl <- if (file.exists(log_file)) {
  read_csv(log_file, show_col_types = FALSE)
} else {
  tibble()
}

# --- get level 4 ecoregions --------------------------------------------------
eco_lev4 <- st_read(
  here("data", "raw", "vector_raw", "ecoregions_unprojected", 
       "us_eco_lev4_GreatPlains_geographic.gpkg")
)

# --- prepare for download --- make a vector of level 4 ecoregions ------------
#     I approached the download piece-wise from level 3 ecoregions to watch
#     for warnings.
eco_list <- eco_lev4 %>%
  filter(us_l3name %in% c(
    "Central Irregular Plains",
    "Central Great Plains",
    "Cross Timbers",
    "Edwards Plateau",
    "Flint Hills",
    "High Plains",
    "Lake Agassiz Plain",
    "Nebraska Sand Hills",
    "Northern Glaciated Plains",
    "Northwestern Glaciated Plains",
    "Northwestern Great Plains",
    "Southern Texas Plains",
    "Southwestern Tablelands",
    "Texas Blackland Prairies",
    "Western Corn Belt Plains",
    "Western Gulf Coastal Plain"
  )) %>%
  st_drop_geometry() %>%
  distinct(us_l4name) %>%
  pull()

# ------------------------------------------------------------------------------
# 2. Download with Retry/Resume and Sliver Fix
# ------------------------------------------------------------------------------

walk2(eco_list, seq_along(eco_list), function(l4name, i) {
  message(glue("🟦 [{i}/{length(eco_list)}] Processing: {l4name}"))

  safe_name <- str_replace_all(l4name, "[^A-Za-z0-9]+", "_")
  out_path <- here("data", "intermediate", 
                   "nhdphr_catchments_by_ecoregion", 
                   glue("{safe_name}.gpkg"))

  if (l4name %in% log_tbl$us_l4name && any(log_tbl$status[log_tbl$us_l4name == l4name] == "success")) {
    message("✅ Already downloaded: {l4name}")
    return(NULL)
  }

  tryCatch({
    eco_aoi <- eco_lev4 %>%
      filter(us_l4name == l4name) %>%
      st_transform(5070) %>%
      st_cast("POLYGON") %>%
      mutate(area = st_area(.)) %>%
      arrange(desc(area)) %>%
      slice(1) %>%
      st_buffer(500) %>%                   # buffer to fix edge slivers
      st_make_valid()                      # fix geometry if needed

    bbox_tiles <- st_make_grid(eco_aoi, n = c(4, 4))

    nhd_list <- imap(bbox_tiles, function(tile_geom, j) {
      tryCatch({
        aoi_tile <- st_sf(tile_id = j, geometry = st_sfc(tile_geom, crs = 5070))
        get_nhdphr(AOI = aoi_tile, type = "nhdpluscatchment", t_srs = 5070)
      }, error = function(e) {
        message(glue("⚠️ Tile {j} failed: {e$message}"))
        NULL
      })
    })

    nhd_combined <- nhd_list %>%
      compact()

    if (length(nhd_combined) == 0) stop("No catchment features returned.")

    nhd_combined <- bind_rows(nhd_combined) %>%
      st_make_valid()

    if (file.exists(out_path)) file_delete(out_path)
    st_write(nhd_combined, out_path, quiet = TRUE)

    log_row <- tibble(
      us_l4name = l4name,
      status = "success",
      message = NA_character_,
      timestamp = as.character(Sys.time())
    )

    write_csv(
      log_row,
      log_file,
      append = file.exists(log_file),
      col_names = !file.exists(log_file)  # write headers only once
    )

    message("✅ Downloaded and saved: {l4name}")
    Sys.sleep(5)

  }, error = function(e) {
    message(glue("❌ Error for {l4name}: {e$message}"))
    log_row <- tibble(
      us_l4name = l4name,
      status = "success",
      message = NA_character_,
      timestamp = as.character(Sys.time())
    )

    write_csv(
      log_row,
      log_file,
      append = file.exists(log_file),
      col_names = !file.exists(log_file)  # write headers only once
    )
  })
})

# ------------------------------------------------------------------------------
# 3. Optional Preview of All Successful Downloads
# ------------------------------------------------------------------------------

# Reload the updated log file AFTER the downloads
log_tbl <- read_csv(log_file, show_col_types = FALSE)

log_latest <- log_tbl %>%
  group_by(us_l4name) %>%
  arrange(desc(timestamp), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  filter(status == "success") %>%
  mutate(
    safe_name = str_replace_all(us_l4name, "[^A-Za-z0-9]+", "_"),
    file_path = here("data", "intermediate", "nhdphr_catchments_by_ecoregion", 
                     paste0(safe_name, ".gpkg"))
  )

# Read and combine all successful catchments
catchments <- map(log_latest$file_path, ~ st_read(.x, quiet = TRUE)) %>%
  bind_rows()

# View
mapview::mapview(catchments["FEATUREID"])

if (interactive()) {
  downloaded_paths <- log_tbl %>%
    filter(status == "success") %>%
    mutate(
      safe_name = str_replace_all(us_l4name, "[^A-Za-z0-9]+", "_"),
      file_path = here(
        "data", "intermediate", "nhdphr_catchments_by_ecoregion", 
                       paste0(safe_name, ".gpkg"))
    ) %>%
    pull(file_path)

  catchments <- map(downloaded_paths, ~ st_read(.x, quiet = TRUE)) %>%
    bind_rows()

  mapview::mapview(catchments["FEATUREID"])
}
