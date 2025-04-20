# ==============================================================================
# Script: 12_model_validation_and_prediction.R
# Purpose: Validate final GAM and Elastic Net models on test set, generate
#          prediction surfaces, and compare performance
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Workflow:
# 1. Split data into training and testing sets
# 2. Evaluate final GAM and Elastic Net models using last_fit()
# 3. Compare performance metrics (RMSE, R^2, MAE)
# 4. Generate prediction surfaces from GAM model
# 5. Map residuals and spatial patterns
# 6. Export metrics, predictions, and visual summaries
#
# Outputs:
# - results/model_summaries/final_test_metrics.csv
# - data/clean/predictions_[model].csv
# - results/figures/predictions_surface_[model].png
# - results/figures/obs_vs_pred_test_[model].png
# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(tidyverse)
library(here)
library(tidymodels)
library(mgcv)
library(sf)
library(broom)
library(ggplot2)
library(terra)       # For spatial rasters
library(raster)
library(fs)





# Prepare for spatial visualization
# Make seasonal rasters--------------------------------------------------------
build_seasonal_prism_rasters <- function(folder, var = "ppt") {
  # List all bil files
  all_bils <- dir_ls(folder, recurse = TRUE, regexp = "\\.bil$", type = "file")
  
  # Filter for precipitation files
  ppt_files <- all_bils[str_detect(all_bils, var)]
  
  # Define month lookup table
  month_labels <- c("01" = "jan", "02" = "feb", "03" = "mar", 
                    "04" = "apr", "05" = "may", "06" = "jun",
                    "07" = "jul", "08" = "aug", "09" = "sep",
                    "10" = "oct", "11" = "nov", "12" = "dec")
  
  # Extract month from filename
  month_numbers <- str_extract(ppt_files, "_(\\d{2})_bil") %>% 
    str_remove_all("_bil|_")
  
  # Create tibble with file paths and labels
  ppt_df <- tibble(
    file = ppt_files,
    month = month_numbers,
    label = month_labels[month]
  )
  
  # Group files by season
  spring_files <- ppt_df %>% filter(month %in% c("04", "05")) %>% pull(file)
  winter_files <- ppt_df %>% filter(month %in% c("12", "01", "02")) %>% pull(file)
  
  # Read and sum into seasonal rasters
  ppt_spring  <- sum(rast(spring_files))
  ppt_winter  <- sum(rast(winter_files))
  
  names(ppt_spring) <- "ppt_spring_mm"
  names(ppt_winter) <- "ppt_winter_mm"
  
  return(list(
    ppt_spring = ppt_spring,
    ppt_winter = ppt_winter
  ))
}

# Path to folder where bil files are unzipped
prism_dir <- "data/raw/prism/"


# Run the function
seasonal_rasters <- build_seasonal_prism_rasters(prism_dir)

# Load Final Dataset ----------------------------------------------------------
data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names()

# make final GAM model
gam_fit_final <- gam(skew ~ s(dec_long_va) + s(ppt_spring_mm) + s(ppt_winter_mm) +
                       s(tmean_m01_c) + s(elev_m) + s(slope_deg), data = data,
                     method = "REML")

saveRDS(gam_fit_final, "results/models/gam_fit.rds")

gam_model <- read_rds("results/models/gam_fit.rds")


# Data Split ------------------------------------------------------------------
set.seed(42)      # why 42? Its the answer to life, the universe, and everything

split <- initial_split(data, prop = 0.8)
train <- training(split)
test <- testing(split)

# Load Final Models -----------------------------------------------------------
gam_model <- read_rds(here("results/models/gam_fit.rds"))
enet_model <- read_rds(here("results/models/enet_fit.rds"))

# Create Workflow for last_fit (ENET) -----------------------------------------
# If enet_model is a fitted workflow already, use last_fit with workflow
# Otherwise, create workflow with prepped recipe & model

# Evaluate Elastic Net on test set --------------------------------------------
# NOTE: If enet_model is NOT a workflow, rebuild it or use predict directly
pred_enet_test <- predict(enet_model, new_data = test) %>%
  bind_cols(test %>% dplyr::select(site_no, skew)) %>%
  rename(pred_enet = .pred)

# Evaluate GAM on test set ----------------------------------------------------
test <- test %>%
  mutate(pred_gam = predict(gam_model, newdata = test))

# Combine and Compare ---------------------------------------------------------
metrics_gam <- metrics(test, truth = skew, estimate = pred_gam) %>%
  mutate(model = "GAM")

metrics_enet <- metrics(pred_enet_test, truth = skew, estimate = pred_enet) %>%
  mutate(model = "Elastic Net")

model_metrics <- bind_rows(metrics_gam, metrics_enet) %>%
  relocate(model)

write_csv(model_metrics, here("results/model_summaries/final_test_metrics.csv"))

# Observed vs Predicted -------------------------------------------------------
obs_vs_pred_plot <- function(data, model_col, label) {
  ggplot(data, aes(x = skew, y = !!sym(model_col))) +
    geom_point(alpha = 0.4) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    labs(title = paste("Observed vs Predicted -", label),
         x = "Observed Skew", y = "Predicted Skew") +
    theme_minimal()
}

p1 <- obs_vs_pred_plot(test, "pred_gam", "GAM")

p1

p2 <- obs_vs_pred_plot(pred_enet_test, "pred_enet", "Elastic Net")

p2

ggsave(here("results/figures/obs_vs_pred_test_gam.png"), 
       p1, width = 6, height = 5, bg = "white")

ggsave(here("results/figures/obs_vs_pred_test_enet.png"), 
       p2, width = 6, height = 5, bg = "white")

# Export Test Predictions -----------------------------------------------------
write_csv(
  test %>%
    mutate(pred_gam = as.numeric(pred_gam)) %>%
    dplyr::select(site_no, skew, pred_gam),
  here("data/clean/predictions_gam.csv")
)

write_csv(pred_enet_test,
          here("data/clean/predictions_enet.csv"))

# Prediction Surface for GAM --------------------------------------------
# Create raster grid to predict over surface

# Load site data with coordinates
sites <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names() 

# Join latitude for prediction surface
sites_lat <- read_csv(here("data/clean/data_covariates_climate.csv")) %>%
  janitor::clean_names() %>%
  dplyr::select(site_no, starts_with("dec_lat"))

sites <- left_join(sites, sites_lat) %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = 4326)

# Get extent from bounding box
bbox <- st_bbox(sites)

# Create an empty raster using extent()
grid <- terra::rast(
  extent = terra::ext(bbox), 
  resolution = 0.05
)

# Define an equal-area CRS for the continental US
crs_aea <- sf::st_crs(5070)  # NAD83 / Conus Albers

# Reproject sites to equal-area CRS
sites_aea <- st_transform(sites, crs_aea)

# Get bounding box of sites (expanded slightly for margin)
bbox_aea <- st_bbox(sites_aea) %>%
  st_as_sfc(crs = st_crs(sites_aea)) %>%  # KEEP CRS!
  st_buffer(50000)  # buffer 50 km

# Create a Grid of Prediction Points
#   Use expand.grid() or sf::st_make_grid() to create a regular set of points 
#   over the bounding box.

# Make grid of prediction points in AEA
grid_points <- st_make_grid(bbox_aea, cellsize = 10000, what = "centers") %>%
  st_as_sf(crs = st_crs(sites_aea))  # explicitly define CRS again if needed

# Reproject grid points to WGS84
grid_points_wgs <- st_transform(grid_points, crs = 4326)

# Load all PRISM and terrain rasters of final predictors
tmean_rast <- terra::rast(
  here("data/raw/prism/PRISM_tmean_30yr_normal_4kmM5_01_bil/PRISM_tmean_30yr_normal_4kmM5_01_bil.bil"))

elev_rast  <- terra::rast(here("data/raw/elevation_ned.tif"))

slope_rast <- terra::terrain(elev_rast, v = "slope", unit = "degrees")

ppt_spring_rast <- seasonal_rasters$ppt_spring

ppt_winter_rast <- seasonal_rasters$ppt_winter


# Set reference raster and reproject to AEA
ref_rast <- ppt_spring_rast  # Reference raster for projection and extent

# Use one raster (e.g., elevation) to create ref_rast in projected CRS
ref_rast <- terra::project(ppt_spring_rast, crs_aea$wkt)

# Now reproject ALL others to match
ppt_spring_rast_aligned <- project(ppt_spring_rast, ref_rast) |> 
  resample(ref_rast)
ppt_winter_rast_aligned <- project(ppt_winter_rast, ref_rast) |> 
  resample(ref_rast)
tmean_rast_aligned       <- project(tmean_rast, ref_rast)       |> 
  resample(ref_rast)
elev_rast_aligned        <- project(elev_rast, ref_rast)        |> 
  resample(ref_rast)
slope_rast_aligned       <- project(slope_rast, ref_rast)       |> 
  resample(ref_rast)

compareGeom(ref_rast, ppt_spring_rast_aligned)

# Combine rasters and rename for clarity
cov_stack <- c(ppt_spring_rast_aligned, ppt_winter_rast_aligned, 
               tmean_rast_aligned, elev_rast_aligned, slope_rast_aligned)

rename_covariates <- function(rstack) {
  names(rstack) <- c("ppt_spring_mm", "ppt_winter_mm", "tmean_m01_c", 
                     "elev_m", "slope_deg")
  rstack
}

cov_stack <- rename_covariates(cov_stack)

names(cov_stack)


grid_points_aea <- st_transform(grid_points, crs = terra::crs(cov_stack))


# Prepare Extraction Function
extract_covariates <- function(points_sf, cov_stack) {
  extracted <- terra::extract(cov_stack, vect(points_sf))
  return(bind_cols(points_sf, extracted))
}


# Predict GAM over grid
grid_covariates <- extract_covariates(grid_points, cov_stack)

# Drop geometry before using with mgcv
grid_cov_df <- grid_covariates %>% 
  st_drop_geometry() %>%
  dplyr::select(-ID)  # terra::extract adds an ID column

# check for possible errors
terra::compareGeom(ref_rast, ppt_spring_rast_aligned, stopOnError = FALSE)


terra::res(ref_rast)
terra::res(ppt_spring_rast_aligned)

terra::ext(ref_rast)
terra::ext(ppt_spring_rast_aligned)

terra::crs(ref_rast, describe = TRUE)
terra::crs(ppt_spring_rast_aligned, describe = TRUE)

terra::plot(ppt_spring_rast_aligned)
plot(st_geometry(grid_points), add = TRUE, col = "red")

plot(ref_rast, main = "Reference Raster + Grid Points")
plot(st_geometry(grid_points), add = TRUE, col = "red")

# Create a mask of valid (non-NA) raster cells
valid_mask <- !is.na(ref_rast)

# Extract valid status for each grid point
valid_ids <- terra::extract(valid_mask, vect(grid_points)) %>%
  pull(2)  # 2nd column has the logical values

# Subset to valid points only
grid_points_valid <- grid_points[which(valid_ids), ]

# Check: Should now fall mostly within raster extent
plot(ref_rast, main = "Valid Grid Points (Clipped)")
plot(st_geometry(grid_points_valid), add = TRUE, col = "red")

grid_covariates <- extract_covariates(grid_points_valid, cov_stack)

# Drop geometry before using with mgcv
grid_cov_df <- grid_covariates %>% 
  st_drop_geometry() %>%
  dplyr::select(-ID)  # terra::extract adds an ID column

summary(grid_covariates)

grid_covariates <- grid_covariates %>%
  mutate(
    dec_long_va = st_coordinates(.)[, 1],
    dec_lat_va  = st_coordinates(.)[, 2]
  )





grid_covariates <- grid_covariates %>%
  mutate(pred_skew = predict(gam_model, newdata = grid_covariates))


# TODO: Residual Spatial Analysis ---------------------------------------------
# Use sf or terra for spatial join and autocorrelation

message("✅ Milestone 12 step complete: Model predictions and test-set evaluation ready.")
