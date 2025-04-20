# ==============================================================================
  # Script: 10b_exploratory_modeling_correlation.R
  # Purpose: Explore relationships among numeric covariates and station skew 
  #          to inform modeling strategies.
  #
  # Author: Charles Jason Tinant — with ChatGPT 4o
  # Date Created: April 2025
  #
  # Notes:
  # - This script focuses on correlation exploration only.
  # - Final modeling and cross-validation workflows will follow in later milestones.
  #
  # Outputs:
  # - Spearman correlation matrix (data/clean/cor_matrix_clean.csv)
  # - Correlation heatmap figure (results/figures/heatmap_covariates_no-labels.png)
  # ==============================================================================


# Load Libraries ---------------------------------------------------------------

library(tidyverse)      # Core data manipulation
library(here)           # File paths
library(janitor)        # Clean names
library(corrr)          # Correlation calculation
library(ggcorrplot)     # Correlation heatmap plotting

# Load Data --------------------------------------------------------------------

covariates_modeling <- read_csv(
  here("data/clean/data_covariates_modeling_clean.csv")
  ) %>%
  clean_names()


# Step 1: Check for Remaining Missing Data -------------------------------------

# Summarize missing data across all variables
covariates_modeling %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(),
               names_to = "variable",
               values_to = "n_missing") %>%
  filter(n_missing > 0)  # Show only variables with missing


# Step 1: Check for Remaining Missing Data -------------------------------------

covariates_modeling %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  filter(n_missing > 0)

# Step 2: Calculate Spearman Correlation Matrix --------------------------------

cor_matrix <- covariates_modeling %>%
  select(where(is.numeric)) %>%
  correlate(method = "spearman") %>%
  rearrange(method = "MDS")  # Reorder similar variables


# Step 3: Visualize as Heatmap -------------------------------------------------

heatmap_plot <- ggcorrplot::ggcorrplot(
  cor_matrix %>% corrr::as_matrix(),
  type = "lower",
  lab = FALSE,  # No numeric labels to reduce clutter
  colors = c("blue", "white", "red"),
  outline.color = "gray90",
  tl.cex = 8
) +
  labs(title = "Spearman Correlation Heatmap of Numeric Covariates") +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1)
  )
 
heatmap_plot

# Step 4: Save Outputs ---------------------------------------------------------

ggsave(
  filename = here("results/figures/heatmap_covariates_no-labels.png"),
  plot = heatmap_plot,
  width = 10, height = 8, dpi = 300, bg = "white"
)

write_csv(cor_matrix, here("data/clean/cor_matrix_clean.csv"))


# ==============================================================================
# Notes on Interpretation ------------------------------------------------------
#
# Key Findings:
# - station_skew is not strongly correlated with any single covariate.
# - Strong inter-correlations observed among climate variables 
#   (monthly and annual precipitation & temperature).
# - Weak correlations between terrain variables (elev_m, slope_deg) 
#   and both skew and climate covariates.
#
# Next Steps:
# - Consider dimensionality reduction (Elastic Net, PCA) or 
#   representative variable selection to address multi-collinearity.
# - Explore non-linear modeling approaches (GAM).
# ==============================================================================

