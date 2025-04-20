# ==============================================================================
# Script: 11b_fit_gam_models.R
# Purpose: Fit and refine Generalized Additive Models (GAMs) to explore
#          relationships between station skew and covariates.
#
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created: April 2025
#
# Workflow:
# 1. Fit initial GAM models (simple & climate-rich)
# 2. Iteratively refine models based on AIC and interpretability
# 3. Export tidy model summaries and AIC comparisons
# 4. Visualize smooth terms 
#
# Outputs:
# - GAM model summary: results/model_summaries/gam_fit_climate_tidy.csv
# - AIC comparisons: results/model_summaries/gam_fit_aic_comparisons.csv
#
# Notes:
# - Final GAM includes: dec_long_va, slope_deg, ppt_spring_mm, ppt_winter_mm, tmean_m01_c
# ==============================================================================

# Load Libraries ---------------------------------------------------------------
library(tidyverse)
library(here)
library(mgcv)
library(broom)
library(gratia)  # GAM visualization tools

# Load & Clean Data ------------------------------------------------------------
data <- read_csv(here("data/clean/data_covariates_modeling_seasonal.csv")) %>%
  janitor::clean_names() %>%
  select(-site_no)  # Drop ID column if present

# ------------------------------------------------------------------------------
# Fit GAM Models ---------------------------------------------------------------

# Model 1: Simple Terrain/Location Model
gam_fit_simple <- gam(
  skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg),
  data = data
)

# Model 2: Climate-Inclusive Model
gam_fit_climate <- gam(
  skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg) +
    s(ppt_spring_mm) + s(ppt_summer_mm) + s(ppt_winter_mm) + 
    s(tmean_m01_c),
  data = data
)

# Compare AIC: Simple vs Climate
compare_fit_simple_climate <- AIC(gam_fit_simple, gam_fit_climate) %>%
  mutate(name = "simple vs climate")

# Refined Model 1: Drop ppt_summer_mm
gam_fit_refined1 <- gam(
  skew ~ s(dec_long_va) + s(elev_m) + s(slope_deg) +
    s(ppt_spring_mm) + s(ppt_winter_mm) + s(tmean_m01_c),
  data = data
)

compare_fit_climate_refined1 <- AIC(gam_fit_climate, gam_fit_refined1) %>%
  mutate(name = "climate vs refined1")

# Refined Model 2: Drop elev_m
gam_fit_refined2 <- gam(
  skew ~ s(dec_long_va) + s(slope_deg) +
    s(ppt_spring_mm) + s(ppt_winter_mm) + s(tmean_m01_c),
  data = data
)

compare_fit_refined1_refined2 <- AIC(gam_fit_refined1, gam_fit_refined2) %>%
  mutate(name = "refined1 vs refined2")

# ------------------------------------------------------------------------------
# Export Tidy Coefficients from Final Model
gam_fit_tidy <- tidy(gam_fit_refined2)
write_csv(gam_fit_tidy, here("results/model_summaries/gam_fit_climate_tidy.csv"))

# ------------------------------------------------------------------------------
# Export AIC Comparison Table
compare_fit_gam <- bind_rows(
  compare_fit_simple_climate,
  compare_fit_climate_refined1,
  compare_fit_refined1_refined2
) %>%
  janitor::clean_names() %>%
  mutate(across(where(is.numeric), round, digits = 3)) %>%
  relocate(name, .before = everything())

write_csv(compare_fit_gam, here("results/model_summaries/gam_fit_aic_comparisons.csv"))

# ==============================================================================
# Visualize GAM Smooth Terms
# ==============================================================================

# Create output folder (if not exists)
fs::dir_create(here("results/figures/gam_terms"))

# Draw all smooths together in a facetted plot
smooth_plot_all <- gratia::draw(gam_fit_refined2, scales = "free") +
  theme_minimal(base_size = 12) +
  ggtitle("GAM Smooth Terms — Refined Climate Model")

ggsave(
  filename = here("results/figures/gam_terms/smooth_terms_combined.png"),
  plot = smooth_plot_all,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Draw all smooths together in one facetted plot
smooth_plot_all <- draw(gam_fit_refined2, scales = "free") +
  theme_minimal(base_size = 12) +
  ggtitle("GAM Smooth Terms — Refined Climate Model")

smooth_plot_all

# Save combined smooth plot
ggsave(
  filename = here("results/figures/gam_terms/smooth_terms_combined.png"),
  plot = smooth_plot_all,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Automatically create individual plots
terms <- gratia::smooth_terms(gam_fit_refined2)

purrr::walk(terms, ~{
  p <- draw(gam_fit_refined2, select = .x) +
    theme_minimal(base_size = 12) +
    ggtitle(glue::glue("GAM Smooth: {.x}"))
  
  ggsave(
    filename = here(glue::glue("results/figures/gam_terms/smooth_{.x}.png")),
    plot = p,
    width = 6,
    height = 4,
    dpi = 300,
    bg = "white"
  )
})

# ==============================================================================
# Export GAM Model Summary Tables
# ==============================================================================

# Parametric Coefficients
gam_tidy_param <- broom::tidy(gam_fit_refined2, parametric = TRUE)

write_csv(
  gam_tidy_param,
  here("results/model_summaries/gam_fit_refined2_parametric.csv")
)

# Smooth Terms (edf, F, p-value)
gam_tidy_smooth <- broom::tidy(gam_fit_refined2, parametric = FALSE)

write_csv(
  gam_tidy_smooth,
  here("results/model_summaries/gam_fit_refined2_smooth.csv")
)

# AIC Comparison Table
compare_fit_gam <- bind_rows(
  compare_fit_simple_climate,
  compare_fit_climate_refined1,
  compare_fit_refined1_refined2
) %>%
  janitor::clean_names() %>%
  mutate(across(where(is.numeric), round, 3))

write_csv(
  compare_fit_gam,
  here("results/model_summaries/gam_fit_compare_aic.csv")
)

