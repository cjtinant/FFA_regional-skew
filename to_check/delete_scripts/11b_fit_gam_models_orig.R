# ==============================================================================
# Script: 11b_fit_gam_models.R
# Purpose: Fit and refine Generalized Additive Models (GAM) to explore
#          relationships between station skew and key covariates.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Workflow:
# 1. Fit initial GAM models (simple & full)
# 2. Iteratively refine models based on AIC, variable significance, interpretability
# 3. Visualize smooth terms
# 4. Export model outputs (plots, tidy results)
# 5. Compare GAM and Elastic Net model performance
# 6. Document rationale for model decisions
#
# Outputs:
# - Figures: results/figures/gam_smooth_*.png
# - Model summaries: results/model_summaries/gam_fit_*.csv
# - AIC Comparison Tables
#
# Notes:
# - Final model selection guided by AIC reduction and parsimony.
# - Future work: cross-validation and prediction performance evaluation.
# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(tidyverse)    # Data wrangling and visualization
library(here)         # File paths
library(mgcv)         # GAM modeling
library(broom)        # Tidy model output
library(modelr)       # Model utilities


# Load Data --------------------------------------------------------------------
data <- read_csv(
  here("data/clean/data_covariates_modeling_seasonal.csv"))


# Clean Names ------------------------------------------------------------------
data <- data %>%
  janitor::clean_names()

# Drop site_no if present
data <- data %>% select(-site_no)

# Fit GAM Models ---------------------------------------------------------------

## Model 1: Simple GAM with core predictors
gam_fit_simple <- mgcv::gam(
  skew ~  s(dec_long_va) + s(elev_m) + s(slope_deg),
  data = data
)

gam_summ_simple <- summary(gam_fit_simple)

## Model 2: GAM with Climate + Terrain Covariates
gam_fit_climate <- mgcv::gam(
  skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg) +
    s(ppt_spring_mm) + s(ppt_summer_mm) + s(ppt_winter_mm) + s(tmean_m01_c),
  data = data
)

gam_summ_climate <- summary(gam_fit_climate)

# Compare models with AIC
compare_fit_simple_climate <- AIC(gam_fit_simple, gam_fit_climate) %>%
  mutate(name = "simple vs. climate")

# Refit GAM without ppt_summer_mm
gam_fit_refined1 <- mgcv::gam(
  skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg) +
    s(ppt_spring_mm) + s(ppt_winter_mm) + s(tmean_m01_c),
  data = data
)

# View summary of new model
summary(gam_fit_refined1)

# Compare models with AIC
compare_fit_climate_refined1 <- AIC(gam_fit_climate, gam_fit_refined1) %>%
  mutate(name = "climate vs. refined1")

# Refit GAM without elev_m
gam_fit_refined2 <- gam(skew ~ 
                          s(dec_long_va) + 
                          s(slope_deg) + 
                          s(ppt_spring_mm) + 
                          s(ppt_winter_mm) + 
                          s(tmean_m01_c),
                        data = data
                        )

# View summary of new model
summary(gam_fit_refined2)

# Compare models with AIC
AIC(gam_fit_refined1, gam_fit_refined2)

compare_fit_refined1_refined2 <- AIC(gam_fit_refined1, gam_fit_refined2)  %>%
  mutate(name = "refined1 vs. refined2")


# Extract & Export Tidy Model Results ------------------------------------------

## Climate Model Coefficients (Parametric & Smooth)
gam_fit_tidy <- broom::tidy(gam_fit_refined2)

write_csv(gam_fit_tidy, here("results/model_summaries/gam_fit_climate_tidy.csv"))

compare_fit_gam <- bind_rows(
  compare_fit_simple_climate,
  compare_fit_climate_refined1,
  compare_fit_refined1_refined2
  ) %>%
  <drop_row_names> %>%
  distinct()

# Fix below ---
# # Save Model Objects (Optional) ------------------------------------------------
# saveRDS(gam_fit_simple, here("results/model_objects/gam_fit_simple.rds"))
# saveRDS(gam_fit_climate, here("results/model_objects/gam_fit_climate.rds"))
# 
# 
# # Plot Residuals or Smooth Terms ------------------------------------------------
# # ggplot2 or gratia::draw() could be used here
# 
# # Future Steps:
# # - Residual diagnostics
# # - Compare models with AIC/BIC
# # - Visualize partial dependence of key terms
# 
# message("GAM fitting complete: Models saved and results exported.")
