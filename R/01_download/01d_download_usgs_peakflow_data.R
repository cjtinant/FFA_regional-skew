# ==============================================================================
# Script Name:     01d_download_us_peakflow_data.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    April 2025
# Last Update:     2025-07-28
# Change Log:
# - 2025-07-23     Move notes to notes/script-notes_and_developer-log.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}.
#
# Purpose:         Downloads and combines USGS peak flow data for stream gages
#                  located in the Great Plains Level I Ecoregion. Site list is
#                  based on cleaned and filtered metadata output from prior
#                  steps. This script prepares a unified dataset of raw annual
#                  peak flows for subsequent filtering and analysis.
#
# Workflow Summary:
# 1. Load cleaned site metadata for Great Plains stream gages (ST only)
# 2. Extract unique site IDs and divide into API-safe batches
# 3. Query USGS NWIS for peak flow data using `readNWISpeak()`
# 4. Combine all returned results into a single tidy dataframe
# 5. Attempt date parsing; retain raw strings for diagnostics
# 6. Export the combined dataset for further processing
#
# Input/Data URLs
# - data/raw/peakflow_gages/usgs_sites_pk_ST_only.csv
# Site list is derived from `usgs_site_metadata.csv` (script 01c).
# Outputs:
# - data/raw/peakflow_gages/data_pk_all.csv — all retrieved peak flow records
#
# Dependencies:
# - dataRetrieval  Access USGS NWIS data
# - here           Robust file paths
# - sf             Spatial data (simple features)
# - tidyverse      Data wrangling & visualization
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# --- Load required libraries ---
library(dataRetrieval)
library(here)
library(sf)
library(tidyverse)

# ------------------------------------------------------------------------------
# 1. Load cleaned metadata for usable Great Plains gages
# ------------------------------------------------------------------------------
sites_meta <- read_csv(
  file.path(here(), "data", "raw", "peakflow_gages", "usgs_sites_pk_ST_only.csv")
)

# ------------------------------------------------------------------------------
# 2. Extract unique site numbers and split into ~300-site batches
# ------------------------------------------------------------------------------

site_ids <- unique(sites_meta$site_no)
batch_size <- 300
site_batches <- split(site_ids, ceiling(seq_along(site_ids) / batch_size))

# ------------------------------------------------------------------------------
# 3. Query USGS NWIS for peak flow data using `readNWISpeak()`
# ------------------------------------------------------------------------------

# --- Define a safe wrapper for data retrieval ---
#       (to avoid total failure on individual errors)
safe_read_peak <- safely(readNWISpeak)

# --- Loop through batches, download peak flow data, and store results ---
peak_data_list <- map(site_batches, function(batch) {
  message("Downloading batch of ", length(batch), " sites...")
  result <- safe_read_peak(batch)
  Sys.sleep(0.5) # brief pause between batches to avoid overwhelming API
  if (!is.null(result$result)) {
    result$result # return the result if successful
  } else {
    tibble() # return an empty tibble if an error occurred
  }
})

# ------------------------------------------------------------------------------
# 4. Combine all downloaded results into a single dataframe
# ------------------------------------------------------------------------------
data_pk_raw <- bind_rows(peak_data_list)

# --- Retain raw date strings, attempt parsing, and flag any failures ---
data_pk <- data_pk_raw %>%
  mutate(
    # preserve original raw date string
    peak_dt_raw = peak_dt,
    # attempt to parse as Date
    peak_dt = suppressWarnings(lubridate::ymd(peak_dt_raw)),
    # flag records where parsing failed
    date_parse_failed = is.na(peak_dt) & !is.na(peak_dt_raw)
  )

# ------------------------------------------------------------------------------
# 5. Export full dataset (with raw and parsed dates) to CSV
# ------------------------------------------------------------------------------
write_csv(data_pk, file.path(
  here(), "raw", "peakflow_gages", "usgs_data_pk_all.csv"))
