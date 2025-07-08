# ==============================================================================
# Script: 06_calculate_station_skew.R
# Purpose: Calculate log-Pearson III station skew for unregulated gage sites
#   with ≥20 usable (non-NA, non-zero) peak flow observations. This supports 
# regional skew estimation.
#
# Author: Charles Jason Tinant -- with ChatGPT 4o
# Date Created: April 2025

# Workflow Steps:
# 1. Load unregulated peak flow data (data/clean/data_pk_unreg_gt_20.csv)
# 2. Group by site_no
# 3. Calculate:
#    - log10 of peak flow
#    - sample skew of log-peaks
#    - count of observations (n_obs)
# 4. Export station skew summary to data/clean/station_skew.csv

# ==============================================================================
# Libraries
library(tidyverse)
library(here)
library(e1071)    # For skewness()

# ------------------------------------------------------------------------------
# Load data
data_pk_unreg <- read_csv(here("data/clean/data_pk_unreg_gt_20.csv"))
sites_pk <- read_csv(here("data/clean/sites_pk_gt_20.csv"))

# ------------------------------------------------------------------------------
# Calculate station skew (log10 of peak_va)

station_skew <- data_pk_unreg %>%
  filter(!is.na(peak_va), peak_va > 0) %>%
  group_by(site_no) %>%
  summarise(
    n = n(),
    skew = e1071::skewness(log10(peak_va)),
    .groups = "drop"
  ) %>%
  arrange(n)

# ------------------------------------------------------------------------------
# Add lat/lon for context

station_skew_coords <- station_skew %>%
  left_join(
    sites_pk %>% select(site_no, dec_lat_va, dec_long_va),
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
