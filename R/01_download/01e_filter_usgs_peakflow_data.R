# ==============================================================================
# Script Name:     01e_filter_usgs_peakflow_data.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    April 2025
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-23     Move notes to notes/script-notes_and_developer-log.
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}.
#
# Purpose:         Calculate log-Pearson III station skew for a set of unregulated
#                  and suspected regulation (suspect) gage sites in the Great Plains
#                  (GP) ecoregion with greater than ten years of data. The following
#                  exclusions were applied:
#                    - Years with missing discharge or dates
#                    - Years with dam failure and known regulation flags
#                    - Records of less than 10 years
#                    - Records flagged as Potentially Influential Low Flows (PILFs)
#                  The remaining periods of record were tiered as
#                    - Tier 1: Reliable              ≥20 years, unregulated
#                                                    High confidence, use in core mode
#                    - Tier 2: Short Record          10–19 years, unregulated
#                                                    Moderate confidence, use with
#                                                    caution -- weighting sensitivity
#                    - Tier 3: Suspected Regulation  ≥10 years
#                                                    May bias skew low, use only in
#                                                    sensitivity analysis
#
# Workflow Summary:
# 1. Load raw peak flow dataset.
# 2. Drop records with missing discharge or dates.
# 3. Fill missing peak dates with AG DT where available.
# 4. Tag records for: dam break (code 3), regulated (code 6), and
#      suspect regulation (code 5).
# 5. Remove regulated and dam break records.
# 6. Remove sites with ≥ 10 years of record.
# 7. Flag PILFs using MGBT.
# 8. Remove PILFs and recalculated sites with ≥ 10 years of record.
# 9. Tier remaining sites by:
#      - Tier 1: Reliable (≥20 yrs, unregulated);
#      - Tier 2: Short Record (<20 yrs, unregulated);
#      - Tier 3: Suspected Regulation.
# 10. Calculate station skewness.
# 11. Join covariate data.
# 12. Convert gage summary data to an sf object in Albers Conus projection.
# 13. Export results and metadata.
#
# Input/Data URLs:
# - data/raw/peakflow_gages/usgs_data_pk_all.csv
# Outputs:
# data/raw/peakflow_gages/
# - peakflow_gages/data_pk_core.csv          modeling-ready core data
# - alternative dataset w/ suspect gages     data_pk_blended.csv
# data/meta/
# - peakflow_sites_dropped_in_core.csv       sites lost in core-only analysis
# - peakflow_sites_dropped_summary.csv       summary of dropped site count
# - data/meta/summary_pk_by_site.csv         site-year counts (for 20-yr filter)
#
# Dependencies:
# - e1071          calculate skewness
# - fs             file system ops (dir_create)
# - here           relative path handling
# - MGBT           test for low
# - tidyverse      dplyr, purrr, readr, stringr, etc.
#
# Helper Functions:
#
# Related Milestone Reports:
# - milestone_01_download_prepare_covariates.pdf
# ==============================================================================
# --- Load required libraries ---
library(e1071)
library(fs)
library(glue)
library(here)
library(MGBT)
library(sf)
library(tidyverse)

# ------------------------------------------------------------------------------
# 1. Load peak flow and gage location data
# ------------------------------------------------------------------------------
data_pk <- read_csv(
  file.path(here(), "data", "raw", "peakflow_gages", "usgs_data_pk_all.csv"),
  col_types = cols(ag_gage_ht_cd = col_character())
)

data_site <- read_csv(
  file.path(here(), "data", "raw", "peakflow_gages", "usgs_sites_pk_ST_only.csv")
)

# ------------------------------------------------------------------------------
# 2. Drop NA discharge
# ------------------------------------------------------------------------------
data_pk_drop_na <- data_pk %>%
  filter(!is.na(peak_va))

# ---------------------------------------------------------
# 3. Fill missing peak date with ag_dt
# ------------------------------------------------------------------------------
data_pk_fill_date <- data_pk_drop_na %>%
  mutate(peak_dt = coalesce(peak_dt, ag_dt)) %>%
  filter(!is.na(peak_dt))

# ------------------------------------------------------------------------------
# 4. Tag exclusion flags
# ------------------------------------------------------------------------------

codes <- list(
  dam_break    = "3",
  regulated    = "6",
  suspect      = "5"
)

has_peak_flag <- function(x, code) {
  str_detect(x, glue("(^|,)\\s*{code}(,|$)"))
}

data_pk_tagged <- data_pk_fill_date %>%
  mutate(
    is_break     = has_peak_flag(peak_cd, codes$dam_break),
    is_regulated = has_peak_flag(peak_cd, codes$regulated),
    is_suspect   = has_peak_flag(peak_cd, codes$suspect)
  ) %>%
  mutate(across(
    c(is_break, is_regulated, is_suspect),
    ~ replace_na(.x, FALSE)
  ))

# ------------------------------------------------------------------------------
# 5. Remove dam break and regulated codes
# ------------------------------------------------------------------------------
data_pk_filtered <- data_pk_tagged %>%
  filter(!is_break & !is_regulated) %>%
  mutate(peak_year = year(peak_dt)) %>%
  select(-date_parse_failed, -is_break, -is_regulated)

# ------------------------------------------------------------------------------
# 6. Remove sites with fewer than 10 years of data
# ------------------------------------------------------------------------------

min_record_years <- 10

site_counts <- data_pk_filtered %>%
  group_by(site_no) %>%
  summarise(n_years = n_distinct(year(peak_dt)), .groups = "drop")

data_pk_filtered_10yr <- data_pk_filtered %>%
  left_join(site_counts, by = c("site_no")) %>%
  filter(n_years >= min_record_years)

# ------------------------------------------------------------------------------
# 7. Flag PILFs
# ------------------------------------------------------------------------------

# --- Transform to list-cols prior to applying MGBT ---
data_pilf_test <- data_pk_filtered_10yr %>%
  group_by(site_no) %>%
  nest()

# ---Safely test for low threshold outliers ---
data_pilf_test <- data_pilf_test %>%
  mutate(mgb_result = map2(data, site_no, function(.x, .id) {
    tryCatch(
      {
        x <- .x$peak_va
        if (length(x) >= 10 && all(x >= 0, na.rm = TRUE)) {
          MGBT(x) # <- NOTE: use MGBT not mgb, and raw values
        } else {
          message("Too few or negative values for site: ", .id)
          NULL
        }
      },
      error = function(e) {
        message("MGBT error for site ", .id, ": ", conditionMessage(e))
        NULL
      }
    )
  }))

# --- Pull low outler threshold from test results ---
pilf_thresholds <- data_pilf_test %>%
  mutate(LOThresh = map_dbl(mgb_result, ~ .x$LOThresh)) %>%
  select(site_no, LOThresh)

# --- Add low outlier threshhold to filtered data ---
data_with_thresh <- data_pk_filtered_10yr %>%
  left_join(pilf_thresholds, by = "site_no") %>%
  mutate(is_pilf = peak_va <= LOThresh)

# ------------------------------------------------------------------------------
# 8. Remove PILFs and corresponding short records
# ------------------------------------------------------------------------------
data_no_pilf <- data_with_thresh %>%
  filter(!is_pilf | is.na(is_pilf)) %>% # keep NA if MGBT failed
  select(-c(is_pilf, n_years, LOThresh, peak_year))

# --- recalculate years of record ---
data_no_pilf <- data_no_pilf %>%
  mutate(peak_year = lubridate::year(peak_dt)) %>%
  group_by(site_no) %>%
  mutate(n_years = n_distinct(peak_year)) %>%
  ungroup()

# --- remove short records ---
data_ge_10 <- data_no_pilf %>%
  group_by(site_no) %>%
  filter(n_distinct(lubridate::year(peak_dt)) >= 10) %>%
  ungroup()

# ------------------------------------------------------------------------------
# 9. Tier remaining records
# ------------------------------------------------------------------------------
site_tiers <- data_ge_10 %>%
  distinct(site_no, is_suspect, n_years) %>%
  mutate(
    tier = case_when(
      !is_suspect & n_years >= 20 ~ "Tier 1: Reliable (≥20 yrs, unregulated)",
      !is_suspect & n_years < 20 ~ "Tier 2: Short Record (<20 yrs, unregulated)",
      is_suspect ~ "Tier 3: Suspected Regulation"
    )
  )

data_tiered <- data_ge_10 %>%
  left_join(site_tiers,
    by = join_by(site_no, is_suspect, n_years)
  )

# ------------------------------------------------------------------------------
# 10. Calculate skew
# ------------------------------------------------------------------------------
# --- log transform the data prior to skew calculation ---
data_tiered <- data_tiered %>%
  mutate(log_peak_va = log10(peak_va))

# --- Calculate skewness per site ---
skew_summary <- data_tiered %>%
  group_by(site_no) %>%
  summarise(
    tier = first(tier),
    n_years = n_distinct(peak_year),
    skew_lp3 = skewness(log_peak_va, type = 1), # type = 1 is sample skewness (same as B17C)
    .groups = "drop"
  )

# ------------------------------------------------------------------------------
# 11. Join and clean covariate data
# ------------------------------------------------------------------------------
gage_summary <- skew_summary %>%
  inner_join(data_site,
    by = "site_no"
  )

gage_summary_clean <- gage_summary %>%
  # drop NA columns
  select(where(~ !all(is.na(.)))) %>%
  # drop constant value columns
  select(where(~ n_distinct(.x, na.rm = TRUE) > 1)) %>%
  # drop cols not needed for the project
  select(-c(
    project_no,
    gw_file_cd,
    tz_cd,
    reliability_cd,
    inventory_dt,
    construction_dt,
    instruments_cd,
    alt_datum_cd,
    alt_acy_va,
    alt_meth_cd,
    map_scale_fc,
    map_nm,
    land_net_ds,
    county_cd,
    state_cd,
    district_cd,
    coord_meth_cd,
    coord_acy_cd,
    lat_va,
    long_va
  ))

# ------------------------------------------------------------------------------
# 12. Convert gage summary data to an sf object in Albers Conus projection
# ------------------------------------------------------------------------------
# --- Split by datum ---
gage_summary_nad27 <- gage_summary_clean %>%
  filter(coord_datum_cd == "NAD27")

gage_summary_nad83 <- gage_summary_clean %>%
  filter(coord_datum_cd == "NAD83")

# --- Check completeness ---
ck_length <- nrow(gage_summary_nad83) +
  nrow(gage_summary_nad27) == nrow(gage_summary_clean)

# --- Convert NAD27 to sf (EPSG:4267) ---
gage_nad27_sf <- gage_summary_nad27 %>%
  st_as_sf(
    coords = c("dec_long_va", "dec_lat_va"),
    crs = 4267,
    remove = FALSE
  )

# --- Transform to NAD83 Albers Equal Area (EPSG:5070) ---
gage_nad27_sf_proj <- st_transform(gage_nad27_sf, crs = 5070)

gage_nad83_sf <- gage_summary_nad83 %>%
  st_as_sf(
    coords = c("dec_long_va", "dec_lat_va"),
    crs = 4269, # EPSG for NAD83 (geographic)
    remove = FALSE
  )

gage_nad83_sf_proj <- st_transform(gage_nad83_sf, crs = 5070)

# --- join results ---
gage_all_sf_proj <- bind_rows(gage_nad27_sf_proj, gage_nad83_sf_proj)

# ------------------------------------------------------------------------------
# 13. Export results and metadata
# ------------------------------------------------------------------------------
# --- Create output path for results ---
output_path <- file.path(
  here(), "data", "processed", "peakflow_gages", "gage_summary_skew.gpkg"
)

# --- Write results to GeoPackage ---
st_write(gage_all_sf_proj,
  output_path,
  layer = "gage_skew",
  delete_layer = TRUE
)

# --- Write results to csv ---
output_path <- file.path(
  here(), "data", "processed", "peakflow_gages", "gage_summary_skew.csv"
)

write_csv(gage_summary_clean, output_path)

# --- Write data to csv ---
output_path <- file.path(
  here(), "data", "processed", "peakflow_gages", "usgs_pk_data.csv"
)

write_csv(data_tiered, output_path)

# --- Write metadata as a data dictionary ---
gage_data_dict <- tribble(
  ~column_name,             ~description,
  "site_no",                "USGS site identifier",
  "tier",                   "Data reliability category by record length and regulation",
  "n_years",                "Number of years in period of record",
  "skew_lp3",               "Sample skewness of log10(peak flow); Bulletin 17C-compatible",
  "station_nm",             "USGS station name (often includes stream name)",
  "dec_lat_va",             "Latitude in decimal degrees",
  "dec_long_va",            "Longitude in decimal degrees",
  "coord_datum_cd",         "Coordinate datum (e.g., NAD27, NAD83)",
  "alt_va",                 "Elevation of gage (feet above datum)",
  "huc_cd",                 "Hydrologic Unit Code (8-digit HUC)",
  "basin_cd",               "Basin code (regional classification)",
  "topo_cd",                "Topographic setting code",
  "drain_area_va",          "Total drainage area (square miles)",
  "contrib_drain_area_va",  "Contributing drainage area (square miles)"
)

output_path <- file.path(here(), "data", "meta", "gage_data_dictionary.csv")

write_csv(gage_data_dict, output_path)

# --- Export a summary of the tiers ---
tier_summary <- skew_summary %>%
  count(tier, sort = TRUE)

write_csv(
  tier_summary,
  file.path(here(), "data", "meta", "summary_tiers_by_gage.csv")
)

# --- Export a summary of the pilf thresholds ---
write_csv(
  pilf_thresholds,
  file.path(here(), "data", "meta", "pilf_thresholds_by_site.csv")
)
