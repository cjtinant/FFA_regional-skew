# ==============================================================================
# Title:    Query and Clean Site Metadata from WQP and NWIS
# Script Name: 04_find_clean_export_site_summaries.R
# Author: Charles Jason Tinant using ChatGPT 4o
# Date Created: April 2025
# Purpose:  Automate retrieval, cleaning and export of site metadata for unregulated 
#           gages with ≥20 years of record from:
#             (1) Water Quality Portal (WQP)
#             (2) USGS National Water Information System (NWIS)


# Inputs: 
#   - data/sites_pk_unreg_gt_20.csv     # Final set of unregulated sites
#
# Outputs (conditionally written if data exist):
#   - data/site_summary_WDP_clean.csv   # Cleaned WQP site metadata
#   - data/site_summary_NWIS_clean.csv  # Cleaned NWIS site metadata
#
# Dependencies:
#   - dataRetrieval
#   - dplyr
#   - purrr
#   - glue
#   - readr
#
# Workflow Steps:
# ------------------------------------------------------------------------------
# 1. Load target sites (unregulated, ≥20 years) from local CSV
# 2. Extract unique site numbers (site_no)
# 3. Split site numbers into API-safe batches (~300 per batch)
# 4. Query WQP for site metadata in batches using readWQPsummary()
#    - Handle errors with purrr::safely()
#    - Pause 0.5s between batches to avoid throttling
# 5. Combine and clean WQP results
#    - Drop columns entirely NA
# 6. Query NWIS for site metadata in batches using readNWISsite()
#    - Handle errors with purrr::safely()
#    - Pause 0.5s between batches to avoid throttling
# 7. Combine and clean NWIS results
#    - Drop columns entirely NA
#    - Relocate key ID columns (agency_cd, site_no, station_nm, lat/long)
# 8. Write cleaned site summaries to CSV only if data exist
#    - Outputs named using pattern: site_summary_<source>_clean.csv

# Purpose:

#
# Specifically, this script:
#   1. Removes columns that are entirely NA (common in WDP outputs).
#   2. Reorders key identifying columns (agency_cd, site_no, station_nm, 
#      lat/long coordinates) to the front for easier review.
#   3. Writes cleaned site summary tables to CSV only if the resulting 
#      dataframe has ≥1 row (avoids writing empty files from failed WDP queries).


# Notes:
# The script is designed for workflows that query multiple USGS gage sites via 
#   dataRetrieval functions (readNWISsite, readWQPsummary).
# ------------------------------------------------------------------------------
# - This script is API-intensive — be considerate with API limits.
# - Cleaning step preserves only non-empty columns.
# - Designed to fail gracefully on partial data or bad queries.
# - Export filenames follow pattern: site_summary_{source}_clean.csv
# ==============================================================================

# libraries
library(tidyverse)      # Load 'Tidyverse' packages: ggplot2, dplyr, tidyr, 
#                                 readr, purrr, tibble, stringr, forcats
library(here)           # A simpler way to find files
library(dataRetrieval)  # Retrieval functions for USGS and EPA hydro & wq data
library(glue)           # For string interpolation

# ---------------------------------------------------------
# Load final unregulated sites with ≥20 years of record
sites <- read_csv("data/sites_pk_unreg_gt_20.csv")

# ---------------------------------------------------------
# Get Summary of Site Data Available from Water Quality Portal
# Extract unique site numbers
site_ids <- sites %>%
  select(site_no) %>%
  distinct() %>%
  pull()

# Define batch size (100–500 is safe for USGS & WQP services)
batch_size <- 300

# Split site IDs into batches
site_batches <- split(site_ids, ceiling(seq_along(site_ids) / batch_size))

# Define a safe wrapper for readWQPsummary
safe_read_summary <- purrr::safely(readWQPsummary)

# Download summary data in batches
summary_data_list <- purrr::map2(
  site_batches,
  seq_along(site_batches),
  ~ {
    message(glue::glue("Processing batch {.y} of {length(site_batches)}"))
    result <- safe_read_summary(.x)
    Sys.sleep(0.5)  # Pause to avoid overloading API
    result$result
  }
)

# Combine into a single data frame
site_summary_WDP <- bind_rows(summary_data_list)

# Drop NA variables
site_summary_WDP_clean <- site_summary_WDP %>%
  # Drop columns that are entirely NA
  select(where(~ !all(is.na(.)))) 

# Safe wrapper for readNWISsite
safe_read_nwis <- purrr::safely(readNWISsite)

# Download NWIS site data in batches
summary_data_list <- purrr::map2(
  site_batches,
  seq_along(site_batches),
  ~ {
    message(glue("Processing batch {.y} of {length(site_batches)}"))
    result <- safe_read_nwis(.x)
    Sys.sleep(0.5)  # Be kind to USGS servers
    result$result
  }
)

# Combine into a single dataframe
site_summary_NWIS <- bind_rows(summary_data_list)

# Drop NA variables
site_summary_NWIS_clean <- site_summary_NWIS %>%
  # Drop columns that are entirely NA
  select(where(~ !all(is.na(.)))) %>%
  
  # Reorder key columns to the front
  relocate(
    agency_cd, site_no, station_nm, lat_va, long_va, dec_lat_va, dec_long_va,
    .before = everything()
  )
# ------------------------------------------------------------------------------
# Clean & Export Site Summaries from NWIS and WDP
#
# This chunk:
# - Removes columns that are entirely NA
# - Reorders key columns to the front
# - Writes cleaned CSV outputs *only if* data exist
#
# Works for both NWIS and WDP site summaries.
# ------------------------------------------------------------------------------

# Function to clean site summary tables
clean_site_summary <- function(df) {
  df %>%
    select(where(~ !all(is.na(.)))) %>%  # Remove all-NA columns
    relocate(any_of(c(
      "agency_cd", "site_no", "station_nm", 
      "lat_va", "long_va", "dec_lat_va", "dec_long_va"
    )), .before = everything())
}

# Clean both NWIS and WDP site summaries
site_summary_NWIS_clean <- clean_site_summary(site_summary_NWIS)
site_summary_WDP_clean  <- clean_site_summary(site_summary_WDP)

# List for export loop
site_summary_list <- list(
  NWIS = site_summary_NWIS_clean,
  WDP  = site_summary_WDP_clean
)

# Write CSVs only if data exist
purrr::imap(site_summary_list, ~ {
  if (nrow(.x) > 0) {
    file_name <- glue::glue("data/site_summary_{.y}_clean.csv")
    message(glue::glue("Writing {file_name}"))
    write_csv(.x, file_name)
  } else {
    message(glue::glue("No data in site_summary_{.y}_clean — skipping write"))
  }
})