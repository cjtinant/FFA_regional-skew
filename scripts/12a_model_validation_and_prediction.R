# ==============================================================================
# Script: 12a_model_validation_and_prediction.R
# Purpose: Validate final GAM and Elastic Net models, generate predictions,
#          and create spatial prediction surfaces using GAM (planned)
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Outputs:
# - results/model_summaries/final_test_metrics.csv
# - data/clean/predictions_[gam|enet].csv
# - results/figures/obs_vs_pred_test_[model].png
# ==============================================================================

# Load Libraries ---------------------------------------------------------------

library(here)
library(tidymodels)
library(mgcv)
library(sf)
library(broom)
library(ggplot2)
library(terra)
library(raster)
library(fs)
library(tidyverse)
library(conflicted)

conflicted::conflict_prefer("select", "dplyr")
conflicts_prefer(dplyr::filter)
# ------------------------------------------------------------------------------
# Function: Build Seasonal PRISM Rasters
# ------------------------------------------------------------------------------

build_seasonal_prism_rasters <- function(folder, var = "ppt") {
  all_bils <- dir_ls(folder, recurse = TRUE, regexp = "\\.bil$")
  ppt_files <- all_bils[str_detect(all_bils, var)]
  month_numbers <- str_extract(ppt_files, "_(\\d{2})_bil") %>%
    str_remove_all("_bil|_")
  
  ppt_df <- tibble(file = ppt_files, month = month_numbers)
  
  spring_files <- ppt_df %>% filter(month %in% c("04", "05")) %>% pull(file)
  winter_files <- ppt_df %>% filter(month %in% c("12", "01", "02")) %>% pull(file)
  
  list(
    ppt_spring = sum(rast(spring_files)),
    ppt_winter = sum(rast(winter_files))
  )
}

# ------------------------------------------------------------------------------
# Load Data and Fit Final GAM
# ------------------------------------------------------------------------------

data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names()

gam_fit_final <- gam(
  skew ~ s(dec_long_va) + s(ppt_spring_mm) + s(ppt_winter_mm) +
    s(tmean_m01_c) + s(elev_m) + s(slope_deg),
  data = data, method = "REML"
)

saveRDS(gam_fit_final, "results/models/gam_fit.rds")
gam_model <- read_rds("results/models/gam_fit.rds")
enet_model <- read_rds("results/models/enet_fit.rds")

# ------------------------------------------------------------------------------
# Step 1: Evaluate Model Performance on Test Set
# ------------------------------------------------------------------------------

set.seed(42)
split <- initial_split(data, prop = 0.8)
train <- training(split)
test <- testing(split)

# Predict and bind
test <- test %>%
  mutate(pred_gam = predict(gam_model, newdata = test))

pred_enet_test <- predict(enet_model, new_data = test) %>%
  bind_cols(test %>% select(site_no, skew)) %>%
  rename(pred_enet = .pred)

# Evaluate
model_metrics <- bind_rows(
  metrics(test, truth = skew, estimate = pred_gam) %>% mutate(model = "GAM"),
  metrics(pred_enet_test, truth = skew, estimate = pred_enet) %>% mutate(model = "Elastic Net")
) %>%
  relocate(model)

write_csv(model_metrics, here("results/model_summaries/final_test_metrics.csv"))

# ------------------------------------------------------------------------------
# Step 2: Observed vs Predicted Plots
# ------------------------------------------------------------------------------

obs_vs_pred_plot <- function(data, model_col, label) {
  ggplot(data, aes(x = skew, y = !!sym(model_col))) +
    geom_point(alpha = 0.4) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    labs(title = paste("Observed vs Predicted —", label),
         x = "Observed Skew", y = "Predicted Skew") +
    theme_minimal()
}

ggsave(here("results/figures/obs_vs_pred_test_gam.png"),
       obs_vs_pred_plot(test, "pred_gam", "GAM"), width = 6, height = 5, bg = "white")

ggsave(here("results/figures/obs_vs_pred_test_enet.png"),
       obs_vs_pred_plot(pred_enet_test, "pred_enet", "Elastic Net"),
       width = 6, height = 5, bg = "white")

# ------------------------------------------------------------------------------
# Step 3: Export Test Predictions
# ------------------------------------------------------------------------------

write_csv(
  test %>%
    mutate(pred_gam = as.numeric(pred_gam)) %>%
    select(site_no, skew, pred_gam),
  here("data/clean/predictions_gam.csv")
)

write_csv(pred_enet_test, here("data/clean/predictions_enet.csv"))
