# ==============================================================================
# Script: 11c_model_evaluation.R
# Purpose: Evaluate and compare Generalized Additive Models (GAM) and 
#          Elastic Net models for predicting station skew.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Workflow:
# 1. Load Final Modeling Dataset & Models
# 2. Generate Predictions for Both Models
# 3. Calculate Performance Metrics (RMSE, R², MAE)
# 4. Visualize Observed vs Predicted Skew
# 5. Residual Diagnostics for GAM
#     - Histogram of residuals
#     - Residuals vs Fitted plot
#     - Moran’s I for spatial autocorrelation
# 6. Export Results (Metrics, Figures, Moran’s I)
#
# Outputs:
# - results/model_summaries/model_metrics_comparison.csv
# - results/model_summaries/moran_gam_residuals.csv
# - results/figures/obs_vs_pred_[gam|enet].png
# - results/figures/resid_gam_hist.png
# - results/figures/resid_gam_vs_fitted.png
#
# Notes:
# - Model choice guided by predictive accuracy, interpretability, and residual behavior.
# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(tidyverse)
library(here)
library(tidymodels)   # Modeling framework
library(mgcv)         # GAM
library(sf)           # Spatial data
library(spdep)        # Spatial autocorrelation
library(broom)        # Tidy output
library(patchwork)    # For multi-panel plots


# Load Data --------------------------------------------------------------------
data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names()

# Join Latitude for spatial analysis
data_lat <- read_csv(here("data/clean/data_covariates_climate.csv")) %>%
  janitor::clean_names() %>%
  select(site_no, starts_with("dec_lat"))

data <- left_join(data, data_lat)

# Load Final Models ------------------------------------------------------------
enet_best_workflow <- read_rds(here("results/models/enet_fit.rds"))
gam_fit_final      <- read_rds(here("results/models/gam_fit.rds"))

# Step 1: Generate Predictions -------------------------------------------------
data <- data %>%
  mutate(
    pred_enet = predict(enet_best_workflow, new_data = data) %>% pull(.pred),
    pred_gam  = predict(gam_fit_final, newdata = data)
  )

# Step 2: Compute Model Metrics ------------------------------------------------
model_metrics <- bind_rows(
  yardstick::metrics(data, truth = skew, estimate = pred_gam) %>%
    mutate(model = "GAM"),
  yardstick::metrics(data, truth = skew, estimate = pred_enet) %>%
    mutate(model = "Elastic Net")
) %>%
  relocate(model, .before = .metric)

write_csv(model_metrics, here("results/model_summaries/model_metrics_comparison.csv"))

# Step 3: Observed vs Predicted Plots ------------------------------------------
obs_vs_pred_gam <- ggplot(data, aes(x = skew, y = pred_gam)) +
  geom_point(alpha = 0.4) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "Observed vs Predicted — GAM", 
       x = "Observed Skew", y = "Predicted Skew") +
  theme_minimal()

ggsave(here("results/figures/obs_vs_pred_gam.png"), obs_vs_pred_gam,
       width = 6, height = 5, bg = "white")

obs_vs_pred_enet <- ggplot(data, aes(x = skew, y = pred_enet)) +
  geom_point(alpha = 0.4) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(title = "Observed vs Predicted — Elastic Net", 
       x = "Observed Skew", y = "Predicted Skew") +
  theme_minimal()

ggsave(here("results/figures/obs_vs_pred_enet.png"), obs_vs_pred_enet,
       width = 6, height = 5, bg = "white")

# Step 4: Residual Diagnostics -------------------------------------------------
data <- data %>%
  mutate(resid_gam = residuals(gam_fit_final, type = "deviance"))

# Histogram of residuals
ggsave(
  ggplot(data, aes(x = resid_gam)) +
    geom_histogram(bins = 30, fill = "gray70", color = "black") +
    theme_minimal() +
    labs(title = "Histogram of GAM Residuals", x = "Residual"),
  filename = here("results/figures/resid_gam_hist.png"),
  width = 7, height = 5, bg = "white"
)

# Residuals vs Fitted
ggsave(
  ggplot(data, aes(x = pred_gam, y = resid_gam)) +
    geom_point(alpha = 0.6) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    theme_minimal() +
    labs(title = "GAM Residuals vs. Fitted Values",
         x = "Predicted Skew", y = "Residual"),
  filename = here("results/figures/resid_gam_vs_fitted.png"),
  width = 7, height = 5, bg = "white"
)

# Step 5: Spatial Autocorrelation (Moran's I) ----------------------------------
coords <- st_as_sf(data, coords = c("dec_long_va", "dec_lat_va"), crs = 4326)
nb <- spdep::knearneigh(st_coordinates(coords), k = 8) %>% spdep::knn2nb()
listw <- spdep::nb2listw(nb)

moran_result <- spdep::moran.test(data$resid_gam, listw)

# Save Moran’s I test results
capture.output(moran_result, file = here("results/model_summaries/moran_resid_gam.txt"))

broom::tidy(moran_result) %>%
  write_csv(here("results/model_summaries/moran_gam_residuals.csv"))

# Wrap Up ----------------------------------------------------------------------
message("Model evaluation complete: Metrics, predictions, residuals, and Moran’s I exported.")
