# ==============================================================================
# Script: 09a_dont_run_join_covariates_for_modeling.R
# Purpose: THIS SCRIPT DOCUMENTS REMOVAL OF A SITE PRIOR TO MODELING
#          Join numeric covariates (climate, terrain) with station skew values
#          to create a modeling-ready dataset for exploratory analysis and modeling.
# 
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Outputs:
# - data/clean/data_covariates_modeling.csv
# - data/meta/data_covariates_modeling.csv
#
# ==============================================================================

# Data wrangling and plotting
library(tidyverse)      # Core data science packages (ggplot2, dplyr, tidyr, etc.)

# File path management
library(here)           # Construct file paths relative to project root 
                        # (safe across systems)

# Data cleaning
library(janitor)        # Clean column names, detect duplicates, tabulate values, etc.

# Data summary diagnostics
library(skimr)          # Skim summaries for quick overviews of variables 
                        # (type, NA, histograms, etc.)

# Pairwise plots
library(GGally)         # Extension of ggplot2 for ggpairs() and other matrix plots

# Correlation calculation
library(corrr)          # Tidy calculation of correlations and correlation 
                        # network tools

# Correlation plotting
library(ggcorrplot)     # Visualization of correlation matrices using 
                        # ggplot2-style grammar


library(sf)

library(ggspatial)

library(viridis)

library(tigris)  # for state boundaries

library(terra)

library(elevatr)

library(tidyterra)  # enables geom_spatraster()

library(ggrepel)



# ------------------------------------------------------------------------------
# Load Data
station_skew <- read_csv(here("data/clean/station_skew.csv"))
cov_climate  <- read_csv(here("data/clean/data_covariates_climate.csv"))
cov_terrain  <- read_csv(here("data/clean/data_covariates_terrain.csv"))

# ------------------------------------------------------------------------------
# Join Covariates
covariates_modeling <- station_skew %>%
  left_join(cov_climate, 
            by = c("site_no", "dec_lat_va", "dec_long_va")) %>%
  left_join(cov_terrain,
            by = c("site_no", "dec_lat_va", "dec_long_va"))

# ------------------------------------------------------------------------------
# Explore Join Results
cov_eda <- skimr::skim(covariates_modeling)

# Check for duplicate site_no
covariates_modeling %>% count(site_no) %>% filter(n > 1)

# Check for missing covariates
covariates_modeling %>%
  summarise(across(everything(), ~sum(is.na(.))))

# Check missing
missing_terrain <- covariates_modeling %>%
  filter(is.na(elev_m) | is.na(slope_deg)) %>%
  select(site_no, dec_lat_va, dec_long_va)

# ------------------------------------------------------------------------------
# Manually fill missing elev_m and slope_deg using online lookup (e.g., USGS NED Viewer)
terrain_fixes <- tribble(
  ~site_no,   ~elev_m, ~slope_deg,
  "08212400",  26,      0.5,
  "05422470",  190,     0.3,
  "06102500",  1170,    0.7,
  "05056200",  570,     0.4
)

covariates_modeling <- covariates_modeling %>%
  left_join(terrain_fixes, by = "site_no") %>%
  mutate(
    elev_m = coalesce(elev_m.x, elev_m.y),
    slope_deg = coalesce(slope_deg.x, slope_deg.y)
  ) %>%
  select(-ends_with(".x"), -ends_with(".y"))

# Recheck for missing
cov_eda <- skimr::skim(covariates_modeling) %>%
  arrange(desc(n_missing))

# ------------------------------------------------------------------------------
# Reorder and Rename Key Variables
covariates_modeling <- covariates_modeling %>%
  relocate(site_no, dec_lat_va, dec_long_va, skew, .before = everything()) %>%
  clean_names()

# ------------------------------------------------------------------------------
# Explore Relationships -- Pair-plots
# Need to split up pair plots into smaller chunks

# Create output folder if it doesn't exist
fs::dir_create(here::here("results/figures"))


# Precipitation-only pairplot
prcp_plot <- covariates_modeling %>%
  select(skew, starts_with("ppt")) %>%
  ggpairs() +
  theme_minimal() +
  ggtitle("Precip-only Pairwise Plot")

prcp_plot

# Save to PNG
ggsave(here::here("results/figures/pairs_precipitation.png"),
         width = 10, height = 8, dpi = 300, bg = "white")

# Temp-only pairplot
temp_plot <- covariates_modeling %>%
  select(skew, starts_with("tmean")) %>%
  ggpairs() +
  theme_minimal() +
  ggtitle("Temp-only Pairwise Plot")

temp_plot

# Save to PNG
ggsave(here::here("results/figures/pairs_mean-temp.png"),
       width = 10, height = 8, dpi = 300, bg = "white")

# Terrain + Location pairplot
terrain_plot <- covariates_modeling %>%
  select(skew, elev_m, slope_deg, starts_with("dec")) %>%
  ggpairs() +
  theme_minimal() +
  ggtitle("Terrain Location Pairwise Plot")

terrain_plot 

# Save to PNG
ggsave(here::here("results/figures/pairs_terrain.png"),
       width = 10, height = 8, dpi = 300, bg = "white")

# ------------------------------------------------------------------------------
# Prepare to Check Slope Outlier 
#  Need to download an elevation raster to map below

cov_terrain %>%
  filter(slope_deg == max(slope_deg, na.rm = TRUE))

# convert gage locations to an sf object
crs_data <- 4326     # WGS84 / lon-lat projection

cov_terrain_sf <- cov_terrain %>%
  st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = crs_data)

# Create bounding box for downloading an elevation raster
bbox <- st_bbox(cov_terrain_sf)

# Buffer slightly to avoid edge clipping (optional)
bbox_expand <- bbox + c(-1, -1, 1, 1)  # west, south, east, north

# Create regular grid of points across bbox
grid_points <- st_as_sf(
  st_make_grid(
    st_as_sfc(st_bbox(
      bbox_expand),
      crs = crs_data), 
    cellsize = 0.5, 
    what = "centers"))

# Download Elevation Raster
elev_raster <- get_elev_raster(locations = grid_points, z = 8, clip = "bbox")

# Save raster locally
writeRaster(elev_raster, here("data/raw/elevation_ned.tif"), overwrite = TRUE)

# ------------------------------------------------------------------------------
# Check Slope Outlier 

# Load US States boundaries (lower 48 only)
states <- states(cb = TRUE) %>%
  filter(!STUSPS %in% c("AK", "HI", "PR"))

# Elevation basemap (needs elev raster)
elev_raster <- rast("data/raw/elevation_ned.tif")

# Bounding box with a little buffer
bbox_crop <- st_bbox(cov_terrain_sf) + c(-2, -2, 2, 2)

# Identify outlier site (highest slope)
outlier_site <- cov_terrain_sf %>%
  filter(slope_deg == max(slope_deg, na.rm = TRUE))

# Plot the outlier site geographically
ggplot() +
  # Elevation raster with terrain.colors
  geom_spatraster(data = elev_raster) +
  scale_fill_gradientn(
    colors = terrain.colors(10),
    name = "Elevation (m)"
  ) +
  
  # State boundaries
  geom_sf(data = states, fill = NA, color = "black", size = 0.3) +
  
  # Slope points
  geom_sf(data = cov_terrain_sf, aes(color = slope_deg), size = 1) +
  scale_color_viridis_c(option = "viridis", name = "Slope (deg)") +
  
  coord_sf(xlim = c(bbox_crop["xmin"], bbox_crop["xmax"]),
           ylim = c(bbox_crop["ymin"], bbox_crop["ymax"])) +
  
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text = element_text(size = 10)
  ) +
  
  annotation_north_arrow(
    location = "bl", 
    which_north = "true",
    height = unit(0.8, "cm"),
    width = unit(0.8, "cm"),
    style = north_arrow_fancy_orienteering
  )

# Save
ggsave(here("results/figures/slope_outlier.png"),
       width = 10, height = 8, dpi = 300, bg = "white")

# ------------------------------------------------------------------------------
# Explore Relations -- Heatmap

# Calculate Spearman Correlation Matrix
cor_matrix <- covariates_modeling %>%
  select(where(is.numeric)) %>%
  correlate(method = "spearman") %>%
  rearrange(method = "MDS") %>%  # Optional: Cluster variables
  shave()                        # Lower triangle only

# Convert to matrix for ggcorrplot
cor_matrix <- cor_matrix %>%
  as_matrix()

# Create Heatmap Plot
heatmap_plot <- ggcorrplot(
  cor_matrix,
  lab = TRUE,
  type = "lower",
  show.diag = TRUE,
  lab_size = 2,
  colors = c("blue", "white", "red"),
  outline.color = "gray90",
  tl.cex = 8
) +
  labs(title = "Correlation Heatmap of Numeric Covariates") +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

# Save Output
ggsave(
  filename = here("results/figures/heatmap_covariates.png"),
  plot = heatmap_plot,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)

# ------------------------------------------------------------------------------
# Export Final Modeling Dataset
write_csv(covariates_modeling, here("data/clean/data_covariates_modeling.csv"))

# ------------------------------------------------------------------------------
# Create Metadata
metadata_covariates <- tribble(
  ~variable, ~description, ~units, ~source,
  "site_no", "USGS Site Number", "ID", "USGS NWIS",
  "dec_lat_va", "Latitude", "decimal degrees", "USGS NWIS",
  "dec_long_va", "Longitude", "decimal degrees", "USGS NWIS",
  "skew", "Log-Pearson III Sample Station Skew", "unitless", "Calculated",
  "ppt_ann_mm", "Annual Precipitation Normal", "mm", "PRISM",
  "tmean_ann_C", "Annual Mean Temperature Normal", "deg C", "PRISM",
  "elev_m", "Elevation", "meters", "USGS 3DEP",
  "slope_deg", "Slope", "degrees", "USGS 3DEP"
  # Add more variables as appropriate
)

write_csv(metadata_covariates, here("data/meta/data_covariates_modeling.csv"))

message("Finished joining covariates and station skew. Ready for modeling.")

