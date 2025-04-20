# ==============================================================================
# Script: 11c_model_evaluation.R
# Purpose: Evaluate and compare performance of GAM and Elastic Net models
#          for predicting station skew.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Workflow:
# 1. Load Final Modeling Dataset
# 2. Evaluate Elastic Net Model Performance
# 3. Evaluate GAM Model Performance
# 4. Compare Model Metrics
# 5. Explore Residuals (including spatial autocorrelation)
# 6. Document and Export Results
#
# Outputs:
# - Model summaries: results/model_summaries/model_eval_comparison.csv
# - Figures: results/figures/obs_vs_pred_[gam|enet].png
# - Residual plots/maps
#
# Notes:
# - Final model choice based on accuracy, interpretability, spatial residuals
# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(tidyverse)
library(here)
library(tidymodels)   # Modeling framework
library(mgcv)         # GAM
library(sf)           # Spatial data handling
library(spdep)        # Spatial autocorrelation
library(broom)        # Tidy model output
library(ggplot2)      # Visualization
library(patchwork)    # Combine plots
library(sf)
library(spdep)        # For Moran's I


# Load Data --------------------------------------------------------------------
data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names()

# Add latitude
data_lat <- read_csv(here("data/clean/data_covariates_climate.csv")) %>%
  janitor::clean_names() %>%
  select(site_no, starts_with("dec_lat"))

data <- left_join(data, data_lat)

# Load Models ------------------------------------------------------------------

# Elastic Net (best tuned workflow from previous step)
enet_best_workflow <- read_rds(here("results/models/enet_fit.rds"))

# GAM final model (refined)
gam_fit_final <- read_rds(here("results/models/gam_fit.rds"))


# ==============================================================================
# Step 1: Generate Elastic Net and GAM Predictions & Metrics -------------------

enet_predictions <- predict(enet_best_workflow, new_data = data)

data <- data %>%
  mutate(pred_gam = predict(gam_fit_final, newdata = data))

data <- data %>%
  mutate(pred_enet = predict(enet_best_workflow, new_data = data) %>% pull(.pred))

# Calculate Metrics for both models --------------------------------------------

# GAM metrics
gam_metrics <- yardstick::metrics(data, truth = skew, estimate = pred_gam)

# Elastic Net metrics
enet_metrics <- yardstick::metrics(data, truth = skew, estimate = pred_enet)

# Compare Metrics Side-by-Side -------------------------------------------------

model_metrics <- bind_rows(
  gam_metrics %>% mutate(model = "GAM"),
  enet_metrics %>% mutate(model = "Elastic Net")
) %>%
  relocate(model, .before = .metric)

# View results
model_metrics

write_csv(model_metrics, here(
  "results/model_summaries/model_metrics_comparison.csv"))

# ==============================================================================
# Step 2: Plot Observed vs Predicted -------------------------------------------

obs_vs_pred_gam <- ggplot(data, aes(x = skew, y = pred_gam)) +
  geom_point(alpha = 0.4) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "Observed vs Predicted — GAM", 
       x = "Observed Skew", 
       y = "Predicted Skew") +
  theme_minimal()

obs_vs_pred_gam

obs_vs_pred_enet <- data %>%
  ggplot(aes(x = skew, y = pred_enet)) +
  geom_point(alpha = 0.4) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "Observed vs Predicted — Elastic Net", 
       x = "Observed Skew", y = "Predicted Skew") +
  theme_minimal()

obs_vs_pred_enet

# Save Figures
ggsave(here("results/figures/obs_vs_pred_gam.png"), 
       obs_vs_pred_gam, width = 6, height = 5, bg = "white")
ggsave(here("results/figures/obs_vs_pred_enet.png"), 
       obs_vs_pred_enet, width = 6, height = 5, bg = "white")

# ==============================================================================
# Step 3: Residual Diagnostics -------------------------------------------------
# Purpose: Check residual patterns and spatial autocorrelation for GAM
# ==============================================================================

# Add residuals to dataset
data <- data %>%
  mutate(
    resid_gam = residuals(gam_fit_final, type = "deviance")
  )

# Histogram of residuals
ggplot(data, aes(x = resid_gam)) +
  geom_histogram(bins = 30, fill = "gray70", color = "black") +
  theme_minimal() +
  labs(title = "Histogram of GAM Residuals")

ggsave(here("results/figures/resid_gam_hist.png"), 
       width = 7, height = 5, bg = "white")

# Residuals vs Fitted
ggplot(data, aes(x = pred_gam, y = resid_gam)) +
  geom_point(alpha = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_minimal() +
  labs(title = "GAM Residuals vs. Fitted Values",
       x = "Predicted Skew", y = "Residual")

ggsave(here("results/figures/resid_gam_vs_fitted.png"), 
       width = 7, height = 5, bg = "white")

# Spatial Autocorrelation: Moran's I -------------------------------------------

# Create neighbors object (using 8 nearest neighbors)
coords <- st_as_sf(data, coords = c("dec_long_va", "dec_lat_va"), crs = 4326)
nb <- spdep::knearneigh(st_coordinates(coords), k = 8)
lw <- spdep::nb2listw(spdep::knn2nb(nb))

moran_test <- spdep::moran.test(data$resid_gam, lw)

# View result
moran_test

# Export Moran's I result to text
capture.output(moran_test, file = here("results/model_summaries/moran_resid_gam.txt"))

broom::tidy(moran_test) %>%
  write_csv(here("results/model_summaries/moran_gam_residuals.csv"))

# ==============================================================================
# Step 5: Explore Residuals ----------------------------------------------------

# GAM Residuals
data <- data %>%
  mutate(resid_gam = skew - pred_gam)

# Moran's I for spatial autocorrelation (optional)
coords <- data %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

nb <- spdep::knearneigh(st_coordinates(coords), k = 8) %>% 
  spdep::knn2nb()

listw <- spdep::nb2listw(nb)

moran_gam <- spdep::moran.test(data$resid_gam, listw)

print(moran_gam)

# ==============================================================================
# Next Steps -------------------------------------------------------------------

# - Plot residual maps
# - Export final tables
# - Document in README

message("Model evaluation complete: Metrics, predictions, and residual analysis ready.")