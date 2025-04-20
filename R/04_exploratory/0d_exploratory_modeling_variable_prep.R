# ==============================================================================
# Script: 10d_exploratory_modeling_variable-prep.R
# Purpose: Prepare refined modeling dataset with reduced covariate set
#          for linear models, GAMs, and penalized regression (Elastic Net).
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Notes:
# - This script finalizes a reduced set of covariates for modeling station skew.
# - The covariate selection is informed by exploratory analysis (pair plots, 
#   correlation matrix, and VIF analysis).
#
# Final Covariates:
#   - Latitude (dec_lat_va)
#   - Longitude (dec_long_va)
#   - Elevation (elev_m)
#   - Slope (slope_deg)
#   - January Mean Temperature (tmean_m01_c)
#   - Spring Precipitation Total (ppt_spring_mm)
#   - Summer Precipitation Total (ppt_summer_mm)
#   - Winter Precipitation Total (ppt_winter_mm)
#
# Outputs:
# - data/clean/data_covariates_modeling_final.csv
# - data/meta/data_covariates_modeling_final.csv
#
# ==============================================================================

# Load Libraries ---------------------------------------------------------------

library(tidyverse)
library(here)
library(janitor)
library(mgcv)           # GAM models
library(broom)

# Load Data --------------------------------------------------------------------

covariates_modeling <- read_csv(here("data/clean/data_covariates_modeling_clean.csv")) %>%
  clean_names()

# Step 1: Calculate Seasonal Climate Variables ---------------------------------

# Precipitation by Season
covariates_modeling <- covariates_modeling %>%
  mutate(
    ppt_winter_mm = rowSums(select(., ppt_m12_mm, ppt_m01_mm, ppt_m02_mm), 
                            na.rm = TRUE),
    ppt_spring_mm = rowSums(select(., ppt_m03_mm, ppt_m04_mm, ppt_m05_mm, 
                                   ppt_m06_mm), na.rm = TRUE),
    ppt_summer_mm = rowSums(select(., ppt_m07_mm, ppt_m08_mm, ppt_m09_mm), 
                            na.rm = TRUE),
    ppt_fall_mm   = rowSums(select(., ppt_m10_mm, ppt_m11_mm), na.rm = TRUE)
  ) 

# ==============================================================================
# Step 2: Initial Linear Model (MLR)
# Explore direction, magnitude of relationships
# ==============================================================================

lm_fit <- lm(skew ~ ., data = covariates_modeling %>% 
               select(skew, dec_lat_va, dec_long_va, ppt_spring_mm, 
                      ppt_summer_mm, ppt_fall_mm, ppt_winter_mm, tmean_m01_c, 
                      tmean_m06_c, elev_m, slope_deg))

summary(lm_fit)

# Export tidy output
lm_fit %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/lm_fit_tidy.csv"))

# ==============================================================================
# Step 3: Explore Non-Linearity using GAM
# Allows flexible smooth terms
# ==============================================================================

gam_fit <- mgcv::gam(skew ~ s(dec_lat_va) + s(dec_long_va) +
                     s(ppt_spring_mm) + s(ppt_summer_mm) + s(ppt_fall_mm)
                     + s(ppt_winter_mm) + s(tmean_m01_c) + s(tmean_m06_c) + 
                       s(elev_m) +  s(slope_deg),
                         data = covariates_modeling)

summary(gam_fit)

gam_fit %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/gam_fit_tidy.csv"))


# Suggested Implications for Variable Reduction:
#   → Core Predictors to Keep:
#   Latitude (spatial trend)
# January & June temperature (representing cold and warm season dynamics)
# Spring & Winter precipitation (seasonality effect)
# Slope (terrain influence)
#
# Candidates for Removal or Simplification:
#   Elevation (if collinear with slope/lat)
# Summer & Fall precipitation (not significant here)
# Longitude (weak signal)

# ==============================================================================
# Step 4: Explore collineary
# ==============================================================================
# Sequentially dropping variables to reduce multicolinearity

covariates_subset <- covariates_modeling %>% 
  select(skew, dec_lat_va, dec_long_va, ppt_spring_mm, 
       ppt_summer_mm, ppt_fall_mm, ppt_winter_mm, tmean_m01_c, 
       tmean_m06_c, elev_m, slope_deg)

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_subset)

# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# drop latitude which is HIGHLY correlated
covariates_subset <- covariates_modeling %>% 
  select(skew, dec_long_va, ppt_spring_mm, 
         ppt_summer_mm, ppt_fall_mm, ppt_winter_mm, tmean_m01_c, 
         tmean_m06_c, elev_m, slope_deg)

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_subset)


# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# drop ppt_fall_mm -- Extremely high VIF (38) 
#   - Not significant in the GAM.
#   - Fall effects were not prominent in prior modeling.
covariates_subset <- covariates_modeling %>% 
  select(skew, dec_long_va, ppt_spring_mm, 
         ppt_summer_mm, ppt_winter_mm, tmean_m01_c, 
         tmean_m06_c, elev_m, slope_deg)

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_subset)

# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# Examine tmean_m06_c vs tmean_m01_c
#   - Both show non-linear effects.
#   - Keep tmean_m01_c (January), as it's more consistently significant.
#   - Not significant in the GAM.
#   - Fall effects were not prominent in prior modeling.
covariates_subset <- covariates_modeling %>% 
  select(skew, dec_long_va, ppt_spring_mm, 
         ppt_summer_mm, ppt_winter_mm, tmean_m01_c, 
         elev_m, slope_deg)

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_subset)

# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# ==============================================================================
# Step 5: Select Final Covariate Set
# ==============================================================================

covariates_modeling <- covariates_modeling %>%
  select(
    site_no, dec_long_va, skew,
    elev_m, slope_deg, tmean_m01_c,
    ppt_spring_mm, ppt_summer_mm, ppt_winter_mm,
  )

# Step 3: Export Cleaned Data --------------------------------------------------

write_csv(covariates_modeling, here("data/clean/data_covariates_modeling_seasonal.csv"))

# Step 4: Create Metadata ------------------------------------------------------

# Document variables and source
metadata_covariates <- tribble(
  ~variable, ~description, ~units, ~source,
  "site_no", "USGS Site Number", "ID", "USGS NWIS",
  "dec_lat_va", "Latitude", "decimal degrees", "USGS NWIS",
  "dec_long_va", "Longitude", "decimal degrees", "USGS NWIS",
  "skew", "Log-Pearson III Sample Station Skew", "unitless", "Calculated",
  "elev_m", "Elevation", "meters", "USGS 3DEP",
  "slope_deg", "Slope", "degrees", "USGS 3DEP",
  "ppt_spring_mm", "Spring (Apr-May) Precipitation", "mm", "PRISM",
  "ppt_fall_mm", "Fall (Oct-Nov) Precipitation", "mm", "PRISM",
  "ppt_winter_mm", "Winter (Dec-Feb) Precipitation", "mm", "PRISM"
)

write_csv(metadata_covariates, here("data/meta/data_covariates_modeling_seasonal.csv"))

message("Finished preparing seasonal covariates for modeling.")
