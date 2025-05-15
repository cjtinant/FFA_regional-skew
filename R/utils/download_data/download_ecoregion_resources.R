# Script Name:   download_ecoregion_resources.R
# Author:         CJ Tinant - with ChatGPT 4o
# Date Created:   2025-05-12
# Purpose:       Download EPA ecoregion shapefiles, metadata, and layer files

# Description:
#   - Adaptable function that uses here() to ensure project-root-relative paths
#     to download and extract ecoregion shapefiles, metadata, and layer files
#   - Provides safe checks using fs::dir_create() and file_exists() 
#
# Inputs with example usage: 
#  target_dir = here("data/raw/epa_ecoregions"),
#  zip_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/na_cec_eco_l1.zip",
#  zip_path   = here("data/raw/epa_ecoregions/na_eco_lev01.zip"),
#  meta_url   = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.htm",
#  meta_path  = here("data/raw/epa_ecoregions/NA_CEC_Eco_Level1.htm"),
#  lyr_url    = "https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level1.lyr",
#  lyr_path   = here("data/raw/epa_ecoregions/NA_CEC_Eco_Level1.lyr"),
#  remove_zip = TRUE
#   - 
# Outputs: 
#   - Downloaded EPA layer files
#   - Log file of download (e.g., data/log/download_log.csv)
#   - A tibble summarizing what was downloaded and logged in-session
#
# Dependencies: 
# library(here)
# library(glue)
# library(fs)
#
# Notes:
#   - Utility function used in milestone 01a and beyond
# =============================================================================

download_ecoregion_resources <- function(target_dir, 
                                         zip_url, zip_path,
                                         meta_url, meta_path,
                                         lyr_url, lyr_path,
                                         remove_zip = FALSE,
                                         log_csv = here::here("data/log/download_log.csv")) {
  # Ensure target and log directories exist
  fs::dir_create(target_dir)
  fs::dir_create(fs::path_dir(log_csv))
  
  # Store log entries for return
  log_entries <- list()
  
  # Internal helper to log each download
  log_download <- function(file_path, source_url) {
    if (fs::file_exists(file_path)) {
      entry <- tibble::tibble(
        file_name    = basename(file_path),
        file_path    = fs::path_abs(file_path),
        source_url   = source_url,
        timestamp    = Sys.time(),
        file_size_kb = round(fs::file_info(file_path)$size / 1024, 2)
      )
      # Append to CSV
      if (fs::file_exists(log_csv)) {
        readr::write_csv(entry, log_csv, append = TRUE)
      } else {
        readr::write_csv(entry, log_csv)
      }
      log_entries[[length(log_entries) + 1]] <<- entry
    }
  }
  
  # --- Download and log each file ---
  
  # Shapefile ZIP
  if (!fs::file_exists(zip_path)) {
    message("Downloading shapefile ZIP...")
    download.file(zip_url, destfile = zip_path, mode = "wb")
    log_download(zip_path, zip_url)
  } else {
    message("Shapefile ZIP already exists. Skipping download.")
  }
  
  # Unzip contents
  message("Unzipping shapefile contents...")
  unzip(zip_path, exdir = target_dir)
  
  # Optional ZIP cleanup
  if (remove_zip) {
    fs::file_delete(zip_path)
    message("ZIP file deleted after extraction.")
  }
  
  # Metadata HTML
  if (!fs::file_exists(meta_path)) {
    message("Downloading metadata HTML...")
    download.file(meta_url, destfile = meta_path, mode = "wb")
    log_download(meta_path, meta_url)
  }
  
  # Layer file
  if (!fs::file_exists(lyr_path)) {
    message("Downloading layer file...")
    download.file(lyr_url, destfile = lyr_path, mode = "wb")
    log_download(lyr_path, lyr_url)
  }
  
  message("All downloads and logging complete.")
  
  # Return in-session tibble
  dplyr::bind_rows(log_entries)
}
