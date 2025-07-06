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
# - purrr:


# ==============================================================================

library(dataRetrieval)
library(dplyr)
library(readr)
library(here)
library(purrr)

# ------------------------------------------------------------------------------
# 1. Load site numbers from prior output
# ------------------------------------------------------------------------------

input_file <- here("data", "raw", "peakflow_gages", "sites_pk_eco_only.csv")
sites_df <- read_csv(input_file, show_col_types = FALSE)

site_ids <- unique(sites_df$site_no)

message("Found ", length(site_ids), " site numbers to retrieve metadata.")

# --- check for potential colocated sites ---
colocated <- sites_df %>%
  filter(colocated == TRUE)

# ------------------------------------------------------------------------------
# 2. Query USGS site metadata using dataRetrieval
# ------------------------------------------------------------------------------

# Split site IDs into chunks (e.g., 500 per request)
chunk_size <- 500
site_id_chunks <- split(site_ids, ceiling(seq_along(site_ids) / chunk_size))

# Loop through chunks and fetch metadata
site_metadata <- map_dfr(site_id_chunks, function(chunk) {
  message("Retrieving ", length(chunk), " sites...")
  Sys.sleep(0.5)  # gentle pause to avoid overloading server
  tryCatch(
    readNWISsite(chunk),
    error = function(e) {
      warning("Failed to fetch one batch: ", e$message)
      return(NULL)
    }
  )
})

message("✅ Retrieved metadata for ", nrow(site_metadata), " sites.")

# ------------------------------------------------------------------------------
# 3. --- Drop duplicates and missing data ---
# ------------------------------------------------------------------------------
missing_in_metadata <- sites_df %>%
  anti_join(site_metadata, by = "site_no")

nrow(missing_in_metadata)  # how many missing?

extra_in_metadata <- site_metadata %>%
  anti_join(sites_df, by = "site_no")

nrow(extra_in_metadata)

dupes_in_metadata <- site_metadata %>%
  group_by(site_no) %>%
  filter(n() > 1) %>%
  ungroup()

site_metadata_clean <- site_metadata %>%
  mutate(priority = case_when(
    agency_cd == "USGS" ~ 1,
    TRUE                ~ 2
  )) %>%
  group_by(site_no) %>%
  arrange(priority) %>%      # put USGS first
  slice(1) %>%               # keep the best-ranked record
  ungroup() %>%
  select(-priority)          # clean up



# --- Extract variable names ---
site_meta_vars <- tibble(variable = colnames(site_metadata_clean))


# ------------------------------------------------------------------------------
# 3. Drop tidal streams, ditches, canals
# ------------------------------------------------------------------------------

sw_site_types <- tibble::tribble(
  ~site_tp_cd, ~description,
  "ST", "Stream – surface-water site on a stream",
  "ST-TS", "Tidal stream",
  "ST-DCH", "Stream – ditch/canal",
  "ST-CA", "Stream – canal",
  "ES", "Estuary",
  "FA-DV", "Facility – diversion structure",
  "FA", "Facility",
)

# check sites by agency and site_code
sites_by_type <- site_metadata_clean %>%
  left_join(sw_site_types, by = "site_tp_cd") %>%
  group_by(agency_cd, site_tp_cd, description) %>%
  summarise(count = n(), .groups = "drop")

# --- keep only streams ---
site_metadata_st <- site_metadata_clean %>%
  filter(site_tp_cd == "ST")

# ------------------------------------------------------------------------------
# 5. --- write results ---
# ------------------------------------------------------------------------------
# --- write metadata results ---
dict_output <- here("data", "meta", "usgs_site_metadata_dictionary.csv")
write_csv(site_meta_vars, dict_output)

# --- write results ---
output_file <- here("data", "raw", "peakflow_gages", "usgs_site_metadata.csv")
write_csv(site_metadata_st, output_file)
message("✅ Cleaned site metadata saved to: ", output_file)
