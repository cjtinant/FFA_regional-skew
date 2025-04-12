# ==============================================================================
# Script: 05_update_problem_sites.R
# Purpose: Identify and remove sites with <20 usable peak flow records from
#          unregulated gage data, update site lists, and export cleaned data.
# Author: Charles Jason Tinant -- with ChatGPT 4o
# Date Created: April 2025
#
# ==============================================================================

# Libraries
library(tidyverse)   # Data wrangling

# -----------------------------------------------
# Load data
data_pk_unreg <- read_csv(here("data/clean/data_pk_unreg_gt_20.csv"))
sites_pk <- read_csv(here("data/clean/sites_pk_gt_20.csv"))
sites_reg_or_lt_20 <- read_csv(here("data/clean/sites_reg_or_lt_20.csv"))
site_summary_NWIS <- read_csv(here("data/clean/site_summary_NWIS_clean.csv"))

# ------------------------------------------------------------------------------
# Summarize site peak_va conditions
site_summary <- data_pk_unreg %>%
  group_by(site_no) %>%
  summarise(
    n_obs = n(),
    n_missing = sum(is.na(peak_va)),
    n_zero = sum(peak_va == 0, na.rm = TRUE),
    n_non_missing = n_obs - n_missing,
    n_missing_or_zero = n_missing + n_zero,
    n_non_missing_and_non_zero = n_obs - n_missing_or_zero,
    .groups = "drop"
  )

# ------------------------------------------------------------------------------
# Split sites based on 20 or more usable observations
sites_lt_20 <- site_summary %>%
  filter(n_non_missing_and_non_zero < 20) %>%
  pull(site_no)

sites_ge_20 <- site_summary %>%
  filter(n_non_missing_and_non_zero >= 20) %>%
  pull(site_no)

# ------------------------------------------------------------------------------
# Prepare problem site data
problem_sites <- sites_pk %>%
  filter(site_no %in% sites_lt_20) %>%
  left_join(site_summary, by = "site_no")

data_problem_sites <- data_pk_unreg %>%
  filter(site_no %in% sites_lt_20)

# ------------------------------------------------------------------------------
# Update datasets

data_pk_unreg_clean <- data_pk_unreg %>%
  filter(site_no %in% sites_ge_20)

sites_pk_clean <- sites_pk %>%
  filter(site_no %in% sites_ge_20)

sites_reg_or_lt_20_updated <- bind_rows(sites_reg_or_lt_20, problem_sites)

site_summary_NWIS_clean <- site_summary_NWIS %>%
  filter(site_no %in% sites_ge_20)

# ------------------------------------------------------------------------------
# Export updated datasets

write_csv(data_pk_unreg_clean, here("data/clean/data_pk_unreg_gt_20.csv"))
write_csv(sites_pk_clean, here("data/clean/sites_pk_gt_20.csv"))
write_csv(sites_reg_or_lt_20_updated, here("data/clean/sites_reg_or_lt_20.csv"))
write_csv(site_summary_NWIS_clean, here("data/clean/site_summary_NWIS_clean.csv"))

# Optional: Export problem sites for tracking
write_csv(problem_sites, here("data/clean/problem_sites_skew.csv"))
write_csv(data_problem_sites, here("data/clean/data_problem_sites_skew.csv"))

