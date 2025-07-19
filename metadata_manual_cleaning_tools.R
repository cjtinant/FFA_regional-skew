# ==============================================================================
# Script Name: metadata_manual_cleaning_tools
# Author: Charles Jason Tinant — adapted with ChatGPT 4o
# Created:      2025-07-17
# Last Updated: 2025-07-19
# Purpose: Manual tools for metatdata cleaning
# ==============================================================================

library(here)
library(janitor)
library(tidyverse)
library(waldo)

# ==============================================================================
# Script Section: Compare CSV versions of covariate metadata
# Purpose: Compare two versions of a covariate metadata CSV to identify
#          structural and content-level changes.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Define paths to old and new CSV versions
# ------------------------------------------------------------------------------

old_csv <- here("docs", "metadata", "covariates_metadata_split", 
                "NA_CEC_Eco_Level2_attributes.csv")
new_csv <- here("docs", "metadata", "covariates_metadata_split", 
                "NA_CEC_Eco_Level3_attributes.csv")

# ------------------------------------------------------------------------------
# 2. Read and clean both CSV files
# ------------------------------------------------------------------------------

df_old <- read_csv(old_csv, show_col_types = FALSE) %>% clean_names()
df_new <- read_csv(new_csv, show_col_types = FALSE) %>% clean_names()

# ------------------------------------------------------------------------------
# 3. Compare data frames using waldo (structural + value differences)
# ------------------------------------------------------------------------------

cat("\n--- Structural and Value Differences (waldo) ---\n")
waldo::compare(df_old, df_new)

# ------------------------------------------------------------------------------
# 4. Compare row-level differences using dplyr anti_join
# ------------------------------------------------------------------------------

cat("\n--- Rows in NEW but not in OLD ---\n")
anti_join(df_new, df_old)

cat("\n--- Rows in OLD but not in NEW ---\n")
anti_join(df_old, df_new)

# ==============================================================================
# Script Section: Convert TXT to CSV
# Purpose: Compare two versions of a covariate metadata CSV to identify
#          structural and content-level changes.
# ==============================================================================
# Path to input legend file
input_table <- here("docs", "metadata",
                    "koppen_geiger_legend.txt")

# 1. Read all lines
legend_lines <- read_lines(input_table)

# 2. Filter only lines that look like legend entries
data_lines <- legend_lines[str_detect(legend_lines, "^\\s*\\d+:")]

# 3. Extract fields using regex
legend_df <- data_lines %>%
  str_match("^\\s*(\\d+):\\s+(\\w+)\\s+(.*?)\\s+\\[(\\d+)\\s+(\\d+)\\s+(\\d+)\\]") %>%
  as.data.frame() %>%
  as_tibble() %>%
  select(
    code = V2,
    class = V3,
    description = V4,
    r = V5, g = V6, b = V7
  ) %>%
  mutate(
    across(c(code, r, g, b), as.integer),
    hex = rgb(r, g, b, maxColorValue = 255)
  )


# 4. Write to CSV
write_csv(legend_df, here("docs", "metadata",
                          "koppen_geiger_class_legend.csv"))








