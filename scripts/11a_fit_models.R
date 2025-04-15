# ==============================================================================
# Script: 11a_fit_models.R
# Purpose: Fit and compare statistical models for regional skew estimation.
# Models: Multiple Linear Regression (MLR), Generalized Additive Model (GAM),
#         and Elastic Net Regression (ENet).
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Outputs:
# - results/models/lm_fit.rds
# - results/models/gam_fit.rds
# - results/models/enet_fit.rds
# - results/model_summaries/*.csv
#
# ==============================================================================

# Libraries
library(tidyverse)
library(here)
library(janitor)
library(broom)
library(mgcv)
library(glmnet)
library(tidymodels)

# ------------------------------------------------------------------------------
# Load Data
data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  clean_names()

# Drop site_no if present
data <- data %>% select(-site_no)

# ------------------------------------------------------------------------------
# 1. Multiple Linear Regression (MLR)
lm_fit <- lm(skew ~ ., data = data)

# Save model
saveRDS(lm_fit, here("results/models/lm_fit.rds"))

# Export tidy summary
lm_summary <- broom::tidy(lm_fit)
write_csv(lm_summary, here("results/model_summaries/lm_fit_tidy.csv"))

# ------------------------------------------------------------------------------
# 2. Generalized Additive Model (GAM)
gam_fit <- mgcv::gam(skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg) + 
                       tmean_m01_c + s(ppt_spring_mm) + s(ppt_summer_mm) + 
                       s(ppt_winter_mm),
                     data = data)

# Save model
saveRDS(gam_fit, here("results/models/gam_fit.rds"))

# Export tidy summary
gam_summary <- broom::tidy(gam_fit)
write_csv(gam_summary, here("results/model_summaries/gam_fit_tidy.csv"))

# ------------------------------------------------------------------------------
# 3. Elastic Net Regression (ENet)

set.seed(42)      # why 42? Its the answer to life, the universe, and everything

# Prepare recipe
enet_recipe <- recipe(skew ~ ., data = data) %>%
  step_normalize(all_predictors())

# Specify model
enet_model <- linear_reg(penalty = tune(), mixture = tune()) %>%
  set_engine("glmnet")

# Set up workflow
enet_workflow <- workflow() %>%
  add_model(enet_model) %>%
  add_recipe(enet_recipe)

# Resampling
cv_folds <- vfold_cv(data, v = 10)

# Tuning grid
enet_grid <- grid_regular(penalty(), mixture(), levels = 5)

# Fit with tuning
enet_tuned <- tune_grid(
  enet_workflow,
  resamples = cv_folds,
  grid = enet_grid,
  control = control_grid(save_pred = TRUE)
)

# Compare multiple metrics -- using a vectorized pattern
# Define the metrics to extract
metrics <- c("rmse", "rsq")

# Use map to loop over metrics
enet_check_best_models <- metrics %>%
  set_names() %>%  # So names in output = metric
  map(~ show_best(enet_tuned, metric = .x, n = 5))  # Change n=5 as needed

# flatten the named list
enet_check_best_flat <- enet_check_best_models %>%
  bind_rows(.id = "metric")  # Adds a column "metric" from list names

# Finalize best model
enet_best <- select_best(enet_tuned)
enet_final <- finalize_workflow(enet_workflow, enet_best) %>%
  fit(data)

# Save model
saveRDS(enet_final, here("results/models/enet_fit.rds"))

# Export best tuning parameters
write_csv(enet_best, here("results/model_summaries/enet_fit_best_params.csv"))
write_csv(enet_check_best_flat, 
          here("results/model_summaries/enet_check_best_params.csv"))

