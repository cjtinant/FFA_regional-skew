# ==============================================================================
# Script Name:    01c_download_usgs_site_metadata.R
# Author:         Charles Jason Tinant — with ChatGPT
# Date Created:   2025-07-05
#
# Purpose:        Download detailed site metadata for filtered USGS peak flow
#                 gages located inside the Great Plains Ecoregion.
#
# Input:          sites_pk_eco_only.csv (tabular output from 01b script)
# Output:         usgs_site_metadata.csv with extended attributes
#
# Dependencies:
# - dataRetrieval: To retrieve USGS site metadata
# - dplyr, readr:  For data manipulation and export
# - here:          For consistent paths
# ==============================================================================

library(dataRetrieval)
library(dplyr)
library(readr)
library(here)

# ------------------------------------------------------------------------------
# 1. Load site numbers from prior output
# ------------------------------------------------------------------------------

input_file <- here("data", "raw", "peakflow_gages", "sites_pk_eco_only.csv")
sites_df <- read_csv(input_file, show_col_types = FALSE)

site_ids <- unique(sites_df$site_no)

message("Found ", length(site_ids), " site numbers to retrieve metadata.")

# ------------------------------------------------------------------------------
# 2. Query USGS site metadata using dataRetrieval
# ------------------------------------------------------------------------------

site_metadata <- readNWISsite(site_ids)

if (nrow(site_metadata) == 0) {
  stop("❌ No site metadata returned. Check site numbers.")
}

# Optional: Select relevant fields and arrange
site_metadata_clean <- site_metadata %>%
  select(site_no, station_nm, dec_lat_va, dec_long_va,
         huc_cd, state_cd, county_cd, agency_cd,
         drain_area_va, alt_va, alt_datum_cd,
         site_tp_cd, tz_cd, construction_dt) %>%
  arrange(site_no)

# ------------------------------------------------------------------------------
# 3. Write output to CSV
# ------------------------------------------------------------------------------

output_dir <- here("data", "intermediate")
fs::dir_create(output_dir)

output_file <- file.path(output_dir, "usgs_site_metadata.csv")
write_csv(site_metadata_clean, output_file)

message("✅ Metadata saved to: ", output_file)
