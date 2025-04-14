# ==============================================================================
# Script: 09_join_covariates_for_modeling.R
# Purpose: Join numeric covariates (climate, terrain) with station skew values
#          for exploratory analysis and modeling. Outputs both:
#          (1) All sites; (2) Outlier removed (high slope site)
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
# ==============================================================================

# Load Libraries
library(tidyverse)
library(here)
library(janitor)
library(skimr)
library(GGally)
library(corrr)
library(ggcorrplot)
library(sf)
library(ggspatial)
library(viridis)
library(tigris)
library(terra)
library(elevatr)
library(tidyterra)
library(ggrepel)
library(fs)

# ------------------------------------------------------------------------------
# Load Data
station_skew <- read_csv(here("data/clean/station_skew.csv"))
cov_climate  <- read_csv(here("data/clean/data_covariates_climate.csv"))
cov_terrain  <- read_csv(here("data/clean/data_covariates_terrain.csv"))

# ------------------------------------------------------------------------------
# Function to Join, Explore, and Output Covariates
process_covariates <- function(cov_terrain, remove_outlier = FALSE) {
  
  out_name <- ifelse(remove_outlier, "no-outlier", "with-outlier")
  outlier_site <- cov_terrain %>% filter(slope_deg == max(slope_deg, na.rm = TRUE)) %>% pull(site_no)
  
  if (remove_outlier) {
    cov_terrain <- cov_terrain %>% filter(site_no != outlier_site)
    station_skew_use <- station_skew %>% filter(site_no != outlier_site)
  } else {
    station_skew_use <- station_skew
  }
  
  covariates_modeling <- station_skew_use %>%
    left_join(cov_climate, by = c("site_no", "dec_lat_va", "dec_long_va")) %>%
    left_join(cov_terrain, by = c("site_no", "dec_lat_va", "dec_long_va")) %>%
    relocate(site_no, dec_lat_va, dec_long_va, skew, .before = everything()) %>%
    clean_names()
  
  # Export final data
  write_csv(covariates_modeling, here(glue::glue("data/clean/data_covariates_modeling_{out_name}.csv")))
  
  # ------------------------------------------------------------------------------
  # Pair Plots
  fs::dir_create(here("results/figures"))
  
  plot_vars <- list(
    precipitation = select(covariates_modeling, skew, starts_with("ppt")),
    temperature   = select(covariates_modeling, skew, starts_with("tmean")),
    terrain       = select(covariates_modeling, skew, elev_m, slope_deg, starts_with("dec"))
  )
  
  walk2(names(plot_vars), plot_vars, ~ {
    p <- ggpairs(.y) + theme_minimal() + ggtitle(str_to_title(.x))
    ggsave(
      here(glue::glue("results/figures/pairs_{.x}_{out_name}.png")),
      p, width = 10, height = 8, dpi = 300, bg = "white"
    )
  })
  
  # ------------------------------------------------------------------------------
  # Heatmap of Correlations
  cor_matrix <- covariates_modeling %>%
    select(where(is.numeric)) %>%
    correlate(method = "spearman") %>%
    rearrange(method = "MDS") %>%
    shave() %>%
    as_matrix()
  
  heatmap_plot <- ggcorrplot(
    cor_matrix,
    lab = TRUE,
    type = "lower",
    show.diag = TRUE,
    lab_size = 2,
    colors = c("blue", "white", "red"),
    outline.color = "gray90"
  ) +
    labs(title = glue::glue("Correlation Heatmap ({out_name})")) +
    theme_minimal(base_size = 10) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(
    here(glue::glue("results/figures/heatmap_covariates_{out_name}.png")),
    heatmap_plot, width = 10, height = 8, dpi = 300, bg = "white"
  )
}

# ------------------------------------------------------------------------------
# Run for Both Versions
process_covariates(cov_terrain, remove_outlier = FALSE)
process_covariates(cov_terrain, remove_outlier = TRUE)

message("Finished generating covariates datasets and plots (with and without outlier). Ready for modeling.")

