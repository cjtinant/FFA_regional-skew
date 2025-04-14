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
  here("data/clean/data_covariates_modeling_clean.csv"))

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

# ==============================================================================
# Step 1: Correlation Exploration & Variable Reduction
# Purpose: Identify and address multicollinearity
# Method: Pairwise plots, correlation matrix
# ==============================================================================

# Pairwise plot
covariates_modeling %>%
  select(skew, starts_with("ppt"), starts_with("tmean"), elev_m, slope_deg) %>%
  ggpairs()

# Correlation matrix
cor_matrix <- covariates_modeling %>%
  select(where(is.numeric)) %>%
  correlate(method = "spearman") %>%
  rearrange(method = "MDS")

# Plot correlation heatmap
cor_matrix %>%
  as_matrix() %>%
  ggcorrplot(lab = TRUE)

# Consider removing/reducing correlated variables (>0.7?)


# ==============================================================================
# Step 2: Multiple Linear Regression (MLR)
# Purpose: Establish baseline interpretable model
# Method: lm() regression
# ==============================================================================

mlr_model <- lm(skew ~ ., data = covariates_modeling %>%
                  select(skew, ppt_ann_mm, tmean_ann_c, elev_m, slope_deg))

summary(mlr_model)

# Residual plots
plot(mlr_model)


# ==============================================================================
# Step 3: Generalized Additive Models (GAM)
# Purpose: Explore non-linear relationships flexibly
# Method: mgcv::gam()
# ==============================================================================

gam_model <- mgcv::gam(skew ~ s(ppt_ann_mm) + s(tmean_ann_c) + s(elev_m) + s(slope_deg),
                       data = covariates_modeling)

summary(gam_model)

# Plot smooths
plot(gam_model, pages = 1, residuals = TRUE)


# ==============================================================================
# Step 4: Elastic Net Regression
# Purpose: Penalized regression for variable selection
# Method: glmnet()
# ==============================================================================

# Prepare data
x <- covariates_modeling %>%
  select(-site_no, -dec_lat_va, -dec_long_va, -skew) %>%
  as.matrix()

y <- covariates_modeling$skew

# Elastic Net with cross-validation
cv_model <- cv.glmnet(x, y, alpha = 0.5, family = "gaussian")

plot(cv_model)

coef(cv_model, s = "lambda.min")


# ==============================================================================
# Step 5: Alternative Exploration of Non-Linearities
# Purpose: Explore complex relationships or thresholds
# Method: Decision Trees, Random Forest
# ==============================================================================

# Placeholder for future modeling (if needed)


# ==============================================================================
# Step 6: Spatial Exploration of Residuals
# Purpose: Identify unexplained spatial structure
# Method: Moran's I or mapping residuals
# ==============================================================================

# Example with MLR residuals
covariates_modeling <- covariates_modeling %>%
  mutate(resid_mlr = resid(mlr_model))

# Moran's I (if spatial object exists)
# coords <- st_as_sf(covariates_modeling, coords = c("dec_long_va", "dec_lat_va"), crs = 4326)
# nb <- spdep::knn2nb(spdep::knearneigh(st_coordinates(coords), k = 5))
# lw <- spdep::nb2listw(nb, style = "W")
# spdep::moran.test(covariates_modeling$resid_mlr, lw)


# ==============================================================================
# Next Steps / Notes -----------------------------------------------------------

# - Summarize findings from exploratory modeling
# - Determine most useful covariates for final modeling
# - Consider transformations or derived variables
# - Prepare final modeling dataset (Milestone 11)

message("Exploratory modeling completed for Milestone 10.")
