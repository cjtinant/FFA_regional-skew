# ==============================================================================
# Script: 10a_exploratory_modeling_initial_checks.R
# Purpose: Perform initial checks for missing data and remove outliers 
#          from the modeling dataset (e.g., sites with missing terrain covariates).
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Outputs:
# - data/clean/data_covariates_modeling_clean.csv
#
# Notes:
# - This script prepares a clean dataset for exploratory and predictive modeling.
# - Sites with missing elevation or slope are excluded from modeling.
# ==============================================================================

# Load Libraries ---------------------------------------------------------------

library(tidyverse)  # Includes readr, dplyr, tidyr, ggplot2, etc.
library(here)       # File paths
library(janitor)    # clean_names()


# Load Data --------------------------------------------------------------------

covariates_modeling <- read_csv(
  here("data/clean/data_covariates_modeling_no-outlier.csv"))

# Clean column names
covariates_modeling <- covariates_modeling %>%
  clean_names()

# Check for missing data--------------------------------------------------------

# Summarize missing data across all variables
covariates_modeling %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(),
               names_to = "variable",
               values_to = "n_missing") %>%
  filter(n_missing > 0)  # Show only variables with missing

covariates_modeling %>%
  filter(is.na(elev_m) | is.na(slope_deg)) %>%
  select(site_no, dec_lat_va, dec_long_va, elev_m, slope_deg)

# Remove sites with missing elev_m or slope_deg for modeling

covariates_modeling_clean <- covariates_modeling %>%
  filter(!site_no %in% c("05056200", "05422470", "06102500", "08212400"))

# ------------------------------------------------------------------------------
# Export cleaned modeling dataset (no missing elev/slope)

write_csv(covariates_modeling_clean, here("data/clean/data_covariates_modeling_clean.csv"))
