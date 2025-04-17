# ==============================================================================
# Script: 12_model_validation_and_prediction.R
# Purpose: Validate final GAM and Elastic Net models, generate predictions,
#          and create spatial prediction surfaces using GAM
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

# ------------------------------------------------------------------------------
# Step 4: Generate Prediction Surface (GAM)
# ------------------------------------------------------------------------------

# Create seasonal rasters
seasonal_rasters <- build_seasonal_prism_rasters("data/raw/prism/")
ppt_spring_rast <- seasonal_rasters$ppt_spring
ppt_winter_rast <- seasonal_rasters$ppt_winter

# Other raster covariates
tmean_rast <- rast(here("data/raw/prism/PRISM_tmean_30yr_normal_4kmM5_01_bil/PRISM_tmean_30yr_normal_4kmM5_01_bil.bil"))
elev_rast  <- rast(here("data/raw/elevation_ned.tif"))
slope_rast <- terrain(elev_rast, v = "slope", unit = "degrees")

# Reproject all to Albers Equal Area
crs_aea <- st_crs(5070)$wkt
ref_rast <- project(ppt_spring_rast, crs_aea)

align_raster <- function(r) resample(project(r, ref_rast), ref_rast)

cov_stack <- c(
  align_raster(ppt_spring_rast),
  align_raster(ppt_winter_rast),
  align_raster(tmean_rast),
  align_raster(elev_rast),
  align_raster(slope_rast)
)

names(cov_stack) <- c("ppt_spring_mm", "ppt_winter_mm", "tmean_m01_c", "elev_m", "slope_deg")

# Grid of prediction points
sites <- st_read(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names()

# Join latitude for prediction surface
sites_lat <- read_csv(here("data/clean/data_covariates_climate.csv")) %>%
  janitor::clean_names() %>%
  dplyr::select(site_no, starts_with("dec_lat"))

sites <- left_join(sites, sites_lat) %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

# 1. Reproject sites to equal-area CRS first (important!)
sites_aea <- st_transform(sites, crs = crs_aea)

# 2. Union and buffer (now in meters, so buffer works properly)
bbox_area <- st_buffer(st_union(sites_aea), dist = 50000)  # 50 km buffer

# 3. Make grid points in Albers Equal Area
grid_points <- st_make_grid(
  bbox_area,
  cellsize = 10000,       # 10 km spacing
  what = "centers"
) %>%
  st_as_sf(crs = crs_aea)

# Keep only valid raster points
valid_mask <- !is.na(ref_rast)
valid_ids <- raster::extract(valid_mask, vect(grid_points))[, 2]
grid_points_valid <- grid_points[which(valid_ids), ]

# Extract covariates
grid_covariates <- terra::extract(cov_stack, vect(grid_points_valid)) %>%
  bind_cols(grid_points_valid) %>%
  rename_with(~ str_replace(., "layer", "ID"), starts_with("ID")) %>%
  mutate(
    dec_long_va = st_coordinates(grid_points_valid)[, 1],
    dec_lat_va  = st_coordinates(grid_points_valid)[, 2]
  )

# Drop NA values in elevation and slope
grid_covariates_clean <- grid_covariates %>%
  filter(!is.na(elev_m), !is.na(slope_deg))

# Predict from final GAM model
grid_covariates_clean <- grid_covariates_clean %>%
  mutate(pred_skew = as.numeric(predict(gam_model, 
                                        newdata = st_drop_geometry(
                                          grid_covariates_clean))))

# filter extreme values
grid_covariates_filt <- grid_covariates_clean %>%
  filter(
    elev_m >= 0 & elev_m <= max(data$elev_m, na.rm = TRUE),
    slope_deg <= max(data$slope_deg, na.rm = TRUE)
  )

# repredict grid
grid_covariates_repredict <- grid_covariates_filt %>%
  mutate(pred_skew = as.numeric(predict(gam_model,
                                        newdata = st_drop_geometry(.))))



# Example using training means and sds
means <- data %>%
  summarise(across(c(ppt_spring_mm, ppt_winter_mm, tmean_m01_c, elev_m, slope_deg), mean))

sds <- data %>%
  summarise(across(c(ppt_spring_mm, ppt_winter_mm, tmean_m01_c, elev_m, slope_deg), sd))

# Apply to grid
grid_scaled <- grid_covariates_filt %>%
  mutate(
    ppt_spring_mm = (ppt_spring_mm - means$ppt_spring_mm) / sds$ppt_spring_mm,
    ppt_winter_mm = (ppt_winter_mm - means$ppt_winter_mm) / sds$ppt_winter_mm,
    tmean_m01_c   = (tmean_m01_c   - means$tmean_m01_c) / sds$tmean_m01_c,
    elev_m        = (elev_m        - means$elev_m) / sds$elev_m,
    slope_deg     = (slope_deg     - means$slope_deg) / sds$slope_deg
  )

grid_scaled <- grid_scaled %>%
  mutate(pred_skew = as.numeric(predict(
    gam_model, newdata = st_drop_geometry(.))))


# reconvert to sf
grid_covariates_clean <- grid_covariates_clean %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

# Extract coordinates safely from the sf object
coords <- sf::st_coordinates(grid_covariates_clean)

grid_df <- grid_covariates_clean %>%
  mutate(
    x = sf::st_coordinates(.)[, 1],
    y = sf::st_coordinates(.)[, 2]
  ) %>%
  sf::st_drop_geometry() %>%
  dplyr::select(x, y, pred_skew)


summary(grid_df)




# Ensure pred_skew is a vector, not a matrix/list-column
grid_df <- grid_covariates_clean %>%
  mutate(
    pred_skew = as.numeric(pred_skew),
    x = st_coordinates(.)[, 1],
    y = st_coordinates(.)[, 2]
  ) %>%
  st_drop_geometry() %>%
  dplyr::select(x, y, pred_skew)

# Convert predictions to raster
pred_raster <- terra::rast(grid_covariates_clean, 
                           type = "xyz", 
                           crs = sf::st_crs(grid_covariates_clean)$wkt)

# Set predicted skew as the only layer
names(pred_raster) <- "pred_skew"

# Save raster
terra::writeRaster(pred_raster, here("results/rasters/pred_skew_gam.tif"), 
                   overwrite = TRUE)


message("✅ Milestone 12 complete: Test-set metrics and prediction surface ready.")
