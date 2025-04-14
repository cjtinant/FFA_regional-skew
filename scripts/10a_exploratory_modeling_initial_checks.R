# ==============================================================================
# Script: 10_exploratory_modeling.R
# Purpose: Exploratory modeling of station skew using climate and terrain covariates.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Notes:
# - This script focuses on exploratory modeling only.
# - Final modeling and cross-validation workflows will follow in later milestones.
#
# ==============================================================================


# Load Libraries ---------------------------------------------------------------

library(tidyverse)      # Core data manipulation
library(here)           # File paths
library(janitor)        # Clean names
library(GGally)         # Pairplots
library(corrr)          # Correlation
library(ggcorrplot)     # Correlation heatmap
library(broom)          # Tidy regression output
library(mgcv)           # Generalized Additive Models
library(glmnet)         # Elastic Net Regression
library(tidymodels)     # Modeling framework
library(sf)             # Spatial data
library(spdep)          # Spatial autocorrelation


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
