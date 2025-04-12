# ==============================================================================
# Script Name: 03_filter_unregulated_gage_data.R
# Author: Charles Jason Tinant
# Date Created: April 2025
#
# Purpose:
# This script filters peak flow gage data within the Great Plains Level 1 
# Ecoregion to identify long-term, unregulated sites suitable for flood 
# frequency analysis. It applies sequential filters based on years of record 
# and regulation or diversion impacts recorded in the USGS NWIS peak flow data.
#
# Workflow Summary:
# 1. Load peak flow gage sites within the Great Plains from local storage
# 2. Remove sites with less than 20 years of peak flow observations
# 3. Retrieve peak flow observation data for remaining sites (USGS NWIS)
# 4. Remove observations affected by regulation, diversion, or dam failure
# 5. Re-calculate years of unregulated observations per site
# 6. Keep only sites with 20+ years of unregulated observations
# 7. Export filtered sites and peak flow observations for analysis
#
# Output Files:
# - data/sites_pk_eco_gt_20.csv        → Sites in Great Plains with ≥20 years of record
# - data/data_pk_gt_20.csv             → All peak flow data for these sites
# - data/sites_reg_or_lt_20.csv        → Sites regulated or with <20 years of unregulated data
# - data/sites_pk_unreg_gt_20.csv      → Final unregulated sites with ≥20 years of record
# - data/data_pk_unreg_gt_20.csv       → Final unregulated peak flow data
#
# Dependencies:
# - tidyverse       → Data wrangling & visualization
# - glue            → String interpolation
# - here            → File paths
# - sf              → Spatial data (simple features)
# - dataRetrieval   → Access USGS NWIS data
# - process_geometries.R → Custom helper functions for cleaning sf geometries
#
# Notes:
# - Regulation and diversion flags are identified using USGS peak_cd codes:
#   - 3: Dam Failure
#   - 5: Possibly affected by Regulation or Diversion
#   - 6: Definitely affected by Regulation or Diversion
#   - C: Affected by Urbanization, Mining, Channelization, etc.
# - Output data supports regional flood frequency or skew analysis using only 
#   long-term, natural flow conditions.
# ============================================================================== 

# ---------------------------------------------------------
# libraries
library(tidyverse)      # Load 'Tidyverse' packages: ggplot2, dplyr, tidyr, 
#                                 readr, purrr, tibble, stringr, forcats
library(glue)           # For string interpolation
library(here)           # A simpler way to find files
library(sf)             # Simple features for R
library(dataRetrieval)  # Retrieval functions for USGS and EPA hydro & wq data

# ---------------------------------------------------------
# Load sites in Great Plains ecoregion from local storage
sites_eco_only <- read_csv("data/clean/sites_pk_eco_only.csv")

# drop sites with l.t 20 observations
sites_gt_20 <- sites_eco_only %>%
  filter(count_nu >= 20) %>%
  as.data.frame() %>%
  select(-c(na_l1code:geometry))

# check for duplicates
duplicates <- sites_pk_eco_gt_20 %>%
  filter(duplicated(.) | duplicated(., fromLast = TRUE))

# Export sites
write_csv(sites_eco_gt_20, "data/clean/sites_pk_eco_gt_20.csv")

# ---------------------------------------------------------
# Get peakflow data
# Extract unique site numbers
site_ids <- sites_pk_eco_gt_20 %>%
  st_drop_geometry() %>%
  select(site_no) %>%
  distinct() %>%
  pull()

# Define batch size (100–500 works well for USGS services)
batch_size <- 300

site_batches <- split(site_ids, ceiling(seq_along(site_ids) / batch_size))

# Define a safe wrapper around readNWISpeak
safe_read_peak <- safely(readNWISpeak)

# Download in batches with a loop (or use map)
peak_data_list <- map2(
  site_batches,
  seq_along(site_batches),
  ~ {
    message("Processing batch ", .y, " of ", length(site_batches))
    result <- safe_read_peak(.x)
    Sys.sleep(0.5)  # Be kind to the API
    result$result
  }
)

# Combine into a single data frame
data_gt_20 <- bind_rows(peak_data_list)

# Export peak_data_gt_20
write_csv(data_pk_gt_20, "data/clean/data_pk_gt_20")

# Clean up Global Environment
rm(list = ls(pattern = "batch"))
rm(list = ls(pattern = "list"))

# ---------------------------------------------------------
# Remove data affected by regulation, diversion, or dam failure

# make peak flow flag descriptions
desc_peak_flag <- tribble(
  ~peak_cd, ~peak_cd_descr,
  "1", "Discharge is a Maximum Daily Average",
  "2", "Discharge is an Estimate",
  "3", "Discharge affected by Dam Failure",
  "4", "Discharge less than indicated value which is Minimum Recordable Discharge at this site",
  "5", "Discharge affected to unknown degree by Regulation or Diversion",
  "6", "Discharge affected by Regulation or Diversion",
  "7", "Discharge is an Historic Peak",
  "8", "Discharge actually greater than indicated value",
  "9", "Discharge due to Snowmelt, Hurricane, Ice-Jam or Debris Dam breakup",
  "A", "Year of occurrence is unknown or not exact",
  "Bd", "Day of occurrence is unknown or not exact",
  "Bm", "Month of occurrence is unknown or not exact",
  "C", "All or part of the record affected by Urbanization, Mining, Agricultural changes, Channelization, or other",
  "F", "Peak supplied by another agency",
  "O", "Opportunistic value not from systematic data collection",
  "R", "Revised"
)

# tidy then check peak_data flags
data_pk_flags <- data_gt_20 %>%
  select(-peak_va) %>%
  distinct() %>%
  filter(!is.na(peak_cd)) %>%
  separate(peak_cd, into = c("scratch_1",
                             "scratch_2",
                             "scratch_3",
                             "scratch_4",
                             "scratch_5"
  ),
  sep = ",",
  remove = FALSE,
  extra = "merge") %>%
  pivot_longer(cols = starts_with("scratch")) %>%
  select(-c(peak_cd, name)) %>%
  rename(peak_cd = value) %>%
  distinct() %>%
  filter(!is.na(peak_cd)) %>%
  select(site_no, peak_dt, peak_cd) %>%
  group_by(peak_cd) %>%
  summarise(count = n())

data_pk_flags <- left_join(data_pk_flags, desc_peak_flag,
                           by = join_by(peak_cd)) 

rm(desc_peak_flag)

# find percentage of obs with regulation
n_records <- nrow(data_pk_gt_20)

data_pk_flags <- data_pk_flags %>%
  mutate(total_obs = n_records) %>% 
  mutate(percent_obs = 100 * count / total_obs)

# pull records with dam fail, regulation, or discharge otherwise affected
data_regulated <- data_gt_20 %>%
  filter(peak_cd == "3" |
           peak_cd == "5" |
           peak_cd == "6" | 
           peak_cd == "C"
  )

# keep remaining unregulated observations
data_unregulated <- anti_join(data_gt_20, data_regulated)

# check that the count is true
check_count <- nrow(data_gt_20) == nrow(data_regulated) + nrow(data_unregulated)

# ---------------------------------------------------------
# get initial set of unregulated sites
sites_unreg <-sites_gt_20 %>%
  filter(site_no %in% data_unregulated$site_no)

# get a new count of years in the unregulated data
ck_count <- data_unregulated %>%
  group_by(site_no) %>%
  summarise(count_nu_new = n())

sites_unreg <- left_join(sites_unreg, ck_count,
                              by = join_by(site_no)
                              ) %>%
  arrange(count_nu_new)

rm(ck_count)

# keep unregulated sites with gt 20 yrs obs
sites_unreg_gt_20 <- sites_unreg %>%
  filter(count_nu_new >= 20)

sites_reg_or_lt_20 <- anti_join(sites_gt_20, sites_unreg_gt_20)

write_csv(sites_reg_or_lt_20, "data/clean/sites_reg_or_lt_20.csv")

# filter data for unregulated sites with gt 20 yrs obs
data_unreg_gt_20 <- data_unregulated %>%
  filter(site_no %in% sites_unreg_gt_20$site_no)

ck_final_ave_yr <- nrow(data_unreg_gt_20) / nrow(sites_unreg_gt_20)

# export data
write_csv(sites_unreg_gt_20, "data/clean/sites_pk_unreg_gt_20.csv")
write_csv(data_unreg_gt_20, "data/clean/data_pk_unreg_gt_20.csv")
