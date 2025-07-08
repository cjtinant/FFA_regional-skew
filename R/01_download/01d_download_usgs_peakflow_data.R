# ==============================================================================
# Script Name: 01d_download_us_peakflow_data.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
# Last Update: 2025-07-06
#
# Purpose:
# Downloads and combines USGS peak flow data for stream gages located in the
# Great Plains Level I Ecoregion. Site list is based on cleaned and filtered 
# metadata output from prior steps. This script prepares a unified dataset of 
# raw annual peak flows for subsequent filtering and analysis.
#
# Workflow Summary:
# 1. Load cleaned site metadata for Great Plains stream gages (ST only)
# 2. Extract unique site IDs and divide into API-safe batches
# 3. Query USGS NWIS for peak flow data using `readNWISpeak()`
# 4. Combine all returned results into a single tidy dataframe
# 5. Attempt date parsing; retain raw strings for diagnostics
# 6. Export the combined dataset for further processing
#
# Output Files:
# - data/raw/peakflow_gages/data_pk_all.csv — all retrieved peak flow records
#
# Dependencies:
# - tidyverse       → Data wrangling & visualization
# - glue            → String interpolation
# - here            → File paths
# - sf              → Spatial data (simple features)
# - dataRetrieval   → Access USGS NWIS data
#
# Notes:
# - This script does not apply filtering on regulation, dam failure, or record length.
#   Filtering occurs in the subsequent script.
# - Site list is derived from `usgs_site_metadata.csv` (script 01c).
# ==============================================================================

# ---------------------------------------------------------
# Load required libraries
library(tidyverse)      # Includes dplyr, purrr, readr, etc.
library(glue)           # For dynamic string construction
library(here)           # Robust relative file paths
library(sf)             # Spatial feature support (not used here, but included for project consistency)
library(dataRetrieval)  # Functions to access USGS NWIS data

# ---------------------------------------------------------
# Step 1 — Load cleaned metadata for usable Great Plains gages
sites_meta <- read_csv(here("data/raw/peakflow_gages/usgs_site_metadata.csv"))

# Step 2 — Extract unique site numbers and split into ~300-site batches
site_ids <- unique(sites_meta$site_no)
batch_size <- 300
site_batches <- split(site_ids, ceiling(seq_along(site_ids) / batch_size))

# Step 3 — Define a safe wrapper for data retrieval (to avoid total failure on individual errors)
safe_read_peak <- safely(readNWISpeak)

# Step 4 — Loop through batches, download peak flow data, and store results
peak_data_list <- map(site_batches, function(batch) {
  message("Downloading batch of ", length(batch), " sites...")
  result <- safe_read_peak(batch)
  Sys.sleep(0.5)  # brief pause between batches to avoid overwhelming API
  if (!is.null(result$result)) {
    result$result  # return the result if successful
  } else {
    tibble()       # return an empty tibble if an error occurred
  }
})

# Step 5 — Combine all downloaded results into a single dataframe
data_pk_raw <- bind_rows(peak_data_list)

# Step 6 — Retain raw date strings, attempt parsing, and flag any failures
data_pk <- data_pk_raw %>%
  mutate(
    peak_dt_raw = peak_dt,                                      # preserve original raw date string
    peak_dt = suppressWarnings(lubridate::ymd(peak_dt_raw)),    # attempt to parse as Date
    date_parse_failed = is.na(peak_dt) & !is.na(peak_dt_raw)    # flag records where parsing failed
  )

# Step 7 — Export full dataset (with raw and parsed dates) to CSV
write_csv(data_pk, here("data/raw/peakflow_gages/data_pk_all.csv"))

# 
# 
# # REFACTOR BELOW
# 
# # Load sites in Great Plains ecoregion from local storage
# sites_eco_only <- read_csv("data/raw/peakflow_gages/sites_pk_eco_only.csv")
# 
# # drop sites with l.t 20 observations
# sites_gt_20 <- sites_eco_only %>%
#   filter(count_nu >= 20) %>%
#   as.data.frame() %>%
#   select(-c(na_l1code:geometry))
# 
# # check for duplicates
# duplicates <- sites_pk_eco_gt_20 %>%
#   filter(duplicated(.) | duplicated(., fromLast = TRUE))
# 
# # Export sites
# write_csv(sites_eco_gt_20, "data/clean/sites_pk_eco_gt_20.csv")
# 
# # ---------------------------------------------------------
# # Get peakflow data
# # Extract unique site numbers
# site_ids <- sites_pk_eco_gt_20 %>%
#   st_drop_geometry() %>%
#   select(site_no) %>%
#   distinct() %>%
#   pull()
# 
# # Define batch size (100–500 works well for USGS services)
# batch_size <- 300
# 
# site_batches <- split(site_ids, ceiling(seq_along(site_ids) / batch_size))
# 
# # Define a safe wrapper around readNWISpeak
# safe_read_peak <- safely(readNWISpeak)
# 
# # Download in batches with a loop (or use map)
# peak_data_list <- map2(
#   site_batches,
#   seq_along(site_batches),
#   ~ {
#     message("Processing batch ", .y, " of ", length(site_batches))
#     result <- safe_read_peak(.x)
#     Sys.sleep(0.5)  # Be kind to the API
#     result$result
#   }
# )
# 
# # Combine into a single data frame
# data_gt_20 <- bind_rows(peak_data_list)
# 
# # Export peak_data_gt_20
# write_csv(data_pk_gt_20, "data/clean/data_pk_gt_20")
# 
# # Clean up Global Environment
# rm(list = ls(pattern = "batch"))
# rm(list = ls(pattern = "list"))
# 
# # ---------------------------------------------------------
# # Remove data affected by regulation, diversion, or dam failure
# 
# # make peak flow flag descriptions
# desc_peak_flag <- tribble(
#   ~peak_cd, ~peak_cd_descr,
#   "1", "Discharge is a Maximum Daily Average",
#   "2", "Discharge is an Estimate",
#   "3", "Discharge affected by Dam Failure",
#   "4", "Discharge less than indicated value which is Minimum Recordable Discharge at this site",
#   "5", "Discharge affected to unknown degree by Regulation or Diversion",
#   "6", "Discharge affected by Regulation or Diversion",
#   "7", "Discharge is an Historic Peak",
#   "8", "Discharge actually greater than indicated value",
#   "9", "Discharge due to Snowmelt, Hurricane, Ice-Jam or Debris Dam breakup",
#   "A", "Year of occurrence is unknown or not exact",
#   "Bd", "Day of occurrence is unknown or not exact",
#   "Bm", "Month of occurrence is unknown or not exact",
#   "C", "All or part of the record affected by Urbanization, Mining, Agricultural changes, Channelization, or other",
#   "F", "Peak supplied by another agency",
#   "O", "Opportunistic value not from systematic data collection",
#   "R", "Revised"
# )
# 
# # tidy then check peak_data flags
# data_pk_flags <- data_gt_20 %>%
#   select(-peak_va) %>%
#   distinct() %>%
#   filter(!is.na(peak_cd)) %>%
#   separate(peak_cd, into = c("scratch_1",
#                              "scratch_2",
#                              "scratch_3",
#                              "scratch_4",
#                              "scratch_5"
#   ),
#   sep = ",",
#   remove = FALSE,
#   extra = "merge") %>%
#   pivot_longer(cols = starts_with("scratch")) %>%
#   select(-c(peak_cd, name)) %>%
#   rename(peak_cd = value) %>%
#   distinct() %>%
#   filter(!is.na(peak_cd)) %>%
#   select(site_no, peak_dt, peak_cd) %>%
#   group_by(peak_cd) %>%
#   summarise(count = n())
# 
# data_pk_flags <- left_join(data_pk_flags, desc_peak_flag,
#                            by = join_by(peak_cd)) 
# 
# rm(desc_peak_flag)
# 
# # find percentage of obs with regulation
# n_records <- nrow(data_pk_gt_20)
# 
# data_pk_flags <- data_pk_flags %>%
#   mutate(total_obs = n_records) %>% 
#   mutate(percent_obs = 100 * count / total_obs)
# 
# # pull records with dam fail, regulation, or discharge otherwise affected
# data_regulated <- data_gt_20 %>%
#   filter(peak_cd == "3" |
#            peak_cd == "5" |
#            peak_cd == "6" | 
#            peak_cd == "C"
#   )
# 
# # keep remaining unregulated observations
# data_unregulated <- anti_join(data_gt_20, data_regulated)
# 
# # check that the count is true
# check_count <- nrow(data_gt_20) == nrow(data_regulated) + nrow(data_unregulated)
# 
# # ---------------------------------------------------------
# # get initial set of unregulated sites
# sites_unreg <-sites_gt_20 %>%
#   filter(site_no %in% data_unregulated$site_no)
# 
# # get a new count of years in the unregulated data
# ck_count <- data_unregulated %>%
#   group_by(site_no) %>%
#   summarise(count_nu_new = n())
# 
# sites_unreg <- left_join(sites_unreg, ck_count,
#                               by = join_by(site_no)
#                               ) %>%
#   arrange(count_nu_new)
# 
# rm(ck_count)
# 
# # keep unregulated sites with gt 20 yrs obs
# sites_unreg_gt_20 <- sites_unreg %>%
#   filter(count_nu_new >= 20)
# 
# sites_reg_or_lt_20 <- anti_join(sites_gt_20, sites_unreg_gt_20)
# 
# write_csv(sites_reg_or_lt_20, "data/clean/sites_reg_or_lt_20.csv")
# 
# # filter data for unregulated sites with gt 20 yrs obs
# data_unreg_gt_20 <- data_unregulated %>%
#   filter(site_no %in% sites_unreg_gt_20$site_no)
# 
# ck_final_ave_yr <- nrow(data_unreg_gt_20) / nrow(sites_unreg_gt_20)
# 
# # export data
# write_csv(sites_unreg_gt_20, "data/clean/sites_pk_unreg_gt_20.csv")
# write_csv(data_unreg_gt_20, "data/clean/data_pk_unreg_gt_20.csv")
