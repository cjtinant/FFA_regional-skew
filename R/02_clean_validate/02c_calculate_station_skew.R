# ==============================================================================
# Script: 02c_calculate_station_skew.R
# Purpose: Calculate log-Pearson III station skew for unregulated gage sites
#   with ≥20 usable (non-NA, non-zero) peak flow observations. This supports 
# regional skew estimation.
#
# Author: Charles Jason Tinant -- with ChatGPT 4o
# Date Created: April 2025
# Last Update: July 14, 2025
#
# Changelog:
# - Updated for data_pk_blended.csv and data_pk_core.csv
#
# Workflow Summary:
# 1. Load peak flow data
# 2. Group by site_no
# 3. Calculate:
#    - log10 of peak flow
#    - sample skew of log-peaks
#    - count of observations (n_obs)
# 4. Export station skew summary to data/clean/station_skew.csv
#
# Notes: Refer to 01e_filter_usgs_peakflow_data.R
#        Zero Flows and Potentially Influential Low Flows (PILFs) -- 
#        see Bulletin 17C.
#        Including zero flows or outliers (especially on the low end) can
#        distort the estimation of the log-Pearson Type III distribution,
#        biasing skewness, mean, and standard deviation.
#        PILFs may skew the lower tail, producing unrealistic estimates for
#        rare floods.
# Key Concepts to Use:
#  1. Zero Flows: If zero values are present, treat them as PILFs if they are
#        not hydrologically plausible or reflect measurement anomalies.
#  2. Potentially Influential Low Flows (PILFs):
#        Detected using the Multiple Grubbs-Beck Test (MGBT).
#        MGBT applies a modified Grubbs test to the log-transformed peak flow
#        series.
#        Uses order statistics to identify low-end outliers.
#        Flags observations below a calculated threshold discharge. 
# 3. Hydrologic Context:
#        Even if flagged statistically, hydrologic judgment is needed.
#        The analyst must justify exclusion or inclusion based on:
#            Watershed response
#            Channel storage
#            Local climate or event details
#
#   Bulletin 17C explicitly recommends using the Multiple Grubbs-Beck Test
#   (MGBT) to identify low-end outliers, including:
#       Zero flows
#       Near-zero flows like 0.01, 0.02, 0.05, etc.
#   These values can artificially deflate the log-transformed distribution,
#   leading to:
#       Underestimated skewness
#       Misleading exceedance probabilities (e.g., 1% AEP floods)
#   MGBT Works on the log-transformed peak flow series and
#       Sequentially tests low-end order statistics using a modified Grubbs test
#       Identifies the smallest observations that deviate significantly from the
#       rest under a normality assumption
#       Flags them as PILFs if they cross the lower threshold
#
#   When applying MGBT:
#   Ensure your values are strictly positive before log transformation 
#   (remove or screen zeros first)
#   Keep a copy of the original untransformed values for reference and 
#   justification.
#   Maintain a flag column like is_pilf in your dataset for documentation
# ==============================================================================
# Libraries
# Install directly from USGS GitLab
#remotes::install_git("https://code.usgs.gov/water/peakfqr.git")

remotes::install_gitlab("water/peakfqr", 
                        host = "code.usgs.gov"
)



library(tidyverse)
library(here)
# library(e1071)    # For skewness()
library(EflowStats)

# ------------------------------------------------------------------------------
# 1. Load data
# ------------------------------------------------------------------------------

data_pk <- read_csv(
  here("data/raw/peakflow_gages/data_pk_blended.csv"))
# data_pk_core <- read_csv(
#   here("data/processed/peakflow_gages/data_pk_core.csv"))

site_metadata <- read_csv(
  here("data/raw/peakflow_gages/usgs_sites_pk_ST_only.csv"))

# ------------------------------------------------------------------------------
# 2. Recheck length data
# ------------------------------------------------------------------------------

ck_len <- data_pk %>%
  filter(!is.na(peak_va)) %>%
  group_by(site_no) %>%
  summarise(n = n()) 

# add test here

data_pk <- data_pk %>%
  mutate(is_zero = case_when(
    peak_va == 0 ~ "TRUE",
    TRUE ~ "FALSE"
  ))

data_nonzero <- data_pk %>% 
  filter(peak_va > 0)

data_nonzero <- data_nonzero %>%
  mutate(log_peak_va = log10(peak_va))

mgbt_result <- mGBT(data_nonzero$log_peak_va)



# ---------------------------------------------------------
# 10. Export datasets and metadata
# ---------------------------------------------------------
# Create a folder named "peakflow_gages" inside data/processed
dir_create(here("data", "processed", "peakflow_gages"))
















# ------------------------------------------------------------------------------
# 1. Calculate station skew (log10 of peak_va)
# ------------------------------------------------------------------------------

station_skew_blend <- data_pk_blended %>%
  filter(!is.na(peak_va), peak_va > 0) %>%
  group_by(site_no) %>%
  summarise(
    n = n(),
    skew = e1071::skewness(log10(peak_va)),
    .groups = "drop"
  ) %>%
  arrange(n)

ck_lt_20 <- station_skew_blend %>%
  filter(n < 20)

ck_lt_20_dat <- data_pk_blended %>%
  filter(site_no %in% ck_lt_20$site_no)

# ------------------------------------------------------------------------------
# Add metadata and filter less

station_skew_blend_coords <- station_skew_blend %>%
  left_join(
    site_metadata %>% select(site_no,
                             station_nm,
                             dec_lat_va,
                             dec_long_va,
                             alt_va,
                             drain_area_va,
                             contrib_drain_area_va
                             ),
    by = "site_no"
  )

# ------------------------------------------------------------------------------
# Summary statistics of skew

station_skew_coords %>%
  summarise(
    n_sites = n(),
    min_skew = min(skew, na.rm = TRUE),
    median_skew = median(skew, na.rm = TRUE),
    max_skew = max(skew, na.rm = TRUE)
  )

# ------------------------------------------------------------------------------
# Quick plot of skew values

ggplot(station_skew_coords, aes(x = skew)) +
  geom_histogram(binwidth = 0.2,
                 fill = "steelblue",
                 color = "white") +
  labs(
    title = "Distribution of Station Skew",
    x = "Station Skew (log-space, sample skewness)",
    y = "Number of Sites"
  ) +
  theme_minimal()

# ------------------------------------------------------------------------------
# Export results
write_csv(station_skew_coords, here("data/clean/station_skew.csv"))
write_csv(sites_lt_20_skew, here("data/clean/problem_sites_lt_20_skew.csv"))

# Message on completion
message("Station skew calculation complete. Output written to: data/clean/station_skew.csv")
