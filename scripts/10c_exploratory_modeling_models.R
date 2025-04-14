# ==============================================================================
# Script: 10c_exploratory_modeling_models.R
# Purpose: Initial exploratory model fits to investigate relationships between
#          station skew and covariates (climate & terrain).
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Notes:
# - This script focuses on simple, exploratory models only.
# - Final models, cross-validation, and prediction will follow in later milestones.
# ==============================================================================


# Load Libraries ---------------------------------------------------------------

library(tidyverse)      # Data wrangling & ggplot
library(here)           # File paths
library(janitor)        # Clean names
library(broom)          # Tidy model summaries
library(mgcv)           # GAM models
library(GGally)         # For pairs plots
library(corrr)
library(glmnet)         # Elastic Net models
library(tidymodels)     # Modeling framework


# Load Data --------------------------------------------------------------------

covariates_modeling <- read_csv(
  here("data/clean/data_covariates_modeling_clean.csv")
) %>%
  clean_names()


# ==============================================================================
# Step 1: Initial Linear Model (MLR)
# Explore direction, magnitude of relationships
# ==============================================================================

lm_fit <- lm(skew ~ ., data = covariates_modeling %>% select(-site_no))
summary(lm_fit)

# Export tidy output
lm_fit %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/lm_fit_tidy.csv"))

# ==============================================================================
# Step 2: Explore Non-Linearity using GAM
# Allows flexible smooth terms
# ==============================================================================

# check annual, location, elevation, and slope
gam_fit_ann <- mgcv::gam(skew ~ s(dec_lat_va) + s(dec_long_va) + s(elev_m) + 
                           s(slope_deg) + s(ppt_ann_mm) + s(tmean_ann_c),
                     data = covariates_modeling)

summary(gam_fit_ann)

gam_fit_ann %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/gam_fit_ann_tidy.csv"))

# check monthly temperatures
gam_fit_tmean <- mgcv::gam(skew ~ s(tmean_m01_c)+ s(tmean_m02_c)+ 
                             s(tmean_m03_c) + s(tmean_m04_c) + s(tmean_m05_c) 
                           + s(tmean_m06_c) + s(tmean_m07_c) + s(tmean_m08_c) 
                           + s(tmean_m09_c) + s(tmean_m10_c) + s(tmean_m11_c) 
                           + s(tmean_m12_c), data = covariates_modeling)

summary(gam_fit_tmean)

gam_fit_tmean %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/gam_fit_tmean_tidy.csv"))

# check monthly precipitation
gam_fit_ppt <- mgcv::gam(skew ~ s(ppt_m01_mm)+ s(ppt_m02_mm)+ 
                             s(ppt_m03_mm) + s(ppt_m04_mm) + s(ppt_m05_mm) 
                           + s(ppt_m06_mm) + s(ppt_m07_mm) + s(ppt_m08_mm) 
                           + s(ppt_m09_mm) + s(ppt_m10_mm) + s(ppt_m11_mm) 
                           + s(ppt_m12_mm), data = covariates_modeling)

summary(gam_fit_ppt)

gam_fit_ppt %>%
  broom::tidy() %>%
  write_csv(here("results/model_summaries/gam_fit_ppt_tidy.csv"))

# ==============================================================================
# Step 3: Explore collineary
# ==============================================================================

# Select key variables for collinearity check
covariates_subset <- covariates_modeling %>%
  select(
    skew,
    dec_lat_va, dec_long_va,
    slope_deg, tmean_ann_c,
    tmean_m01_c, tmean_m06_c,
    ppt_m04_mm, ppt_m05_mm, ppt_m10_mm, ppt_m11_mm, ppt_m12_mm
  )

# Spearman correlation matrix
cor_matrix <- covariates_subset %>%
  select(-skew) %>%
  correlate(method = "spearman") %>%
  rearrange(method = "MDS")

write_csv(cor_matrix, here("results/model_summaries/cor_matrix_subset.csv"))

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_subset)

# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# Write to CSV
vif_table %>%
  arrange(desc(vif)) %>%
  write_csv(here::here("data/clean/vif_covariates_subset.csv"))

# Refine key variables 
covariates_refined_subset <- covariates_modeling %>%
  select(
    skew,
    dec_long_va,              # dec_lat_va is correlated with temperature
    slope_deg, 
    elev_m,
    tmean_m01_c, tmean_m06_c, # tmean_ann_c is correlated with dec_lon_va
    ppt_m04_mm,               # ppt_m05_mm is correlated with May precip
    ppt_m12_mm                # ppt_m10_mm, ppt_m11_mm correlated with Dec precip
  )

# Calculate VIF
lm_vif <- lm(skew ~ ., data = covariates_refined_subset)

# Convert VIF to tibble
vif_table <- car::vif(lm_vif) %>%
  enframe(name = "variable", value = "vif")

# Write to CSV
vif_table %>%
  arrange(desc(vif)) %>%
  write_csv(here::here("data/clean/vif_covariates_refined_subset.csv"))


# ==============================================================================
# Step 3: Prepare for Elastic Net Regression
# Penalized regression to address multicollinearity
# ==============================================================================
# 
# x <- covariates_modeling %>%
#   select(-site_no, -skew) %>%
#   as.matrix()
# 
# y <- covariates_modeling$skew
# 
# enet_fit <- glmnet::cv.glmnet(x, y, alpha = 0.5, standardize = TRUE)
# 
# # Plot cross-validation error
# plot(enet_fit)
# 
# # Extract coefficients
# coef(enet_fit, s = "lambda.min")
# 
# # ==============================================================================
# # Step 4: Explore Residuals (MLR & GAM)
# # Look for spatial patterns
# # ==============================================================================
# 
# covariates_modeling <- covariates_modeling %>%
#   mutate(
#     resid_lm = residuals(lm_fit),
#     resid_gam = residuals(gam_fit)
#   )
# 
# # Quick residual plot
# covariates_modeling %>%
#   ggplot(aes(x = dec_long_va, y = dec_lat_va, color = resid_lm)) +
#   geom_point(size = 2) +
#   scale_color_gradient2(low = "blue", mid = "white", high = "red") +
#   theme_minimal() +
#   ggtitle("LM Residuals — Spatial Pattern")
# 
# ggsave(
#   filename = here("results/figures/residuals_lm_spatial.png"),
#   width = 10, height = 8, dpi = 300, bg = "white"
# )
# 
# # Repeat for GAM if useful...
# 
# # ==============================================================================
# # Save Workspace
# # ==============================================================================
# 
# saveRDS(lm_fit, here("results/models/lm_fit.rds"))
# saveRDS(gam_fit, here("results/models/gam_fit.rds"))
# saveRDS(enet_fit, here("results/models/enet_fit.rds"))
# 
# message("Exploratory modeling complete. Ready for further model development.")
