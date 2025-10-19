# ==============================================================================
# Script:          metadata_manual_cleaning_tools.R
# Author:          Charles Jason Tinant — adapted with ChatGPT 4o
# Date Created:    2025-07-17
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-27     Update header information;
#                  move notes to `script-notes_and_developer-log`
# - 2025-07-28     Update script to use {here} consistently;
#                  Run {styler}; Updated header metadata.
#
# Purpose:         Manual tools for metadata cleaning.
#                  Section A: Compare CSV versions of covariate metadata
#                  Compare two versions of a covariate metadata CSV to identify
#                  structural and content-level changes.
#                  Section B:  Convert TXT to CSV
#
# Workflow Summary:
# -- Section A: --
# 1. Define paths to old and new CSV versions
# 2. Read and clean both CSV files
# 3. Reorder and align df_old to match df_new's structure
# 4. Compare data frames using waldo (structural + value differences)
# 5. Compare row-level differences using dplyr anti_join
# 6. Compare selected variable by name using a join
# 7. Compare row-level differences using dplyr anti_join
# -- Section B: --
# 1. Read text file
# 2. Filter only lines that look like legend entries
# 3. Extract fields using regex
# 4. Write to CSV
#
# Input/Data URLs:
# - User defined
# Outputs:
# - User defined to ~/docs/metadata/
#
# Dependencies:
# - here           Consistent relative paths
# - janitor        Tools for cleaning dirty data
# - tidyverse      General data wrangling, import and export.
# - waldo          Compare complex R objects and reveal the key differences.
#
# Helper Functions:
#
# Related Milestone Reports:
# ==============================================================================
# Section A: Compare CSV versions of covariate metadata
# ==============================================================================
# --- Load libraries ---
library(here)
library(janitor)
library(tidyverse)
library(waldo)

# ------------------------------------------------------------------------------
# 1. Define paths to old and new CSV versions
# ------------------------------------------------------------------------------
old_csv <- here(
  "docs", "metadata",
  "ecoregion_data-dictionary_v01.csv"
)
new_csv <- here(
  "docs", "metadata",
  "ecoregion_eco_l4_no_st_attributes.csv"
)

# ------------------------------------------------------------------------------
# 2. Read and clean both CSV files
# ------------------------------------------------------------------------------
df_old <- read_csv(old_csv, show_col_types = FALSE) %>%
  clean_names()

df_new <- read_csv(new_csv, show_col_types = FALSE) %>%
  clean_names()

# ------------------------------------------------------------------------------
# 3. Reorder and align df_old to match df_new's structure
# ------------------------------------------------------------------------------
# Identify all columns in df_new
new_cols <- names(df_new)

# Safely handle empty df_old
if (nrow(df_old) < 1) {
  message("⚠️ df_old has 0 rows. Creating NA-filled aligned version.")

  df_old_extended <- tibble(!!!setNames(rep(list(NA), length(new_cols)), new_cols)) %>%
    slice(rep(1, nrow(df_new))) # Match new's row count
} else {
  # Identify any missing columns
  missing_cols <- setdiff(new_cols, names(df_old))

  if (length(missing_cols) > 0) {
    # Add NA columns matching row count
    na_cols <- as_tibble(setNames(rep(list(NA), length(missing_cols)), missing_cols)) %>%
      slice(rep(1, nrow(df_old)))
    df_old <- bind_cols(df_old, na_cols)
  }

  # Reorder to match df_new
  df_old_extended <- df_old %>%
    select(all_of(new_cols))
}

# ------------------------------------------------------------------------------
# 4. Compare data frames using waldo (structural + value differences)
# ------------------------------------------------------------------------------
cat("\n--- Structural and Value Differences (waldo) ---\n")
waldo::compare(df_old_extended, df_new)

# ------------------------------------------------------------------------------
# 5. Compare row-level differences using dplyr anti_join
# ------------------------------------------------------------------------------
cat("\n--- Rows in NEW but not in OLD ---\n")
anti_join(df_new, df_old)

cat("\n--- Rows in OLD but not in NEW ---\n")
anti_join(df_old, df_new)

# ------------------------------------------------------------------------------
# 6. Compare selected variable by name using a join
# ------------------------------------------------------------------------------
compare_metadata_column <- function(df_old, df_new, var_to_ck) {
  old_var <- df_old %>%
    select(variable_name, value_old = !!sym(var_to_ck))

  new_var <- df_new %>%
    select(variable_name, value_new = !!sym(var_to_ck))

  full_join(new_var, old_var, by = "variable_name") %>%
    #    filter(value_old != value_new) %>%
    print(n = Inf)
}

compare_metadata_column(df_old, df_new, "notes")

# ------------------------------------------------------------------------------
# 7. Compare row-level differences using dplyr anti_join
# ------------------------------------------------------------------------------
# Save aligned old version for inspection
write_csv(df_old_aligned, here(
  "docs", "metadata", "covariates_metadata_split",
  "skew_covariates_metadata_v071.csv"
))

# ==============================================================================
# Script Section B: Convert TXT to CSV
# ==============================================================================
# --- Path to input text file ---
input_table <- here(
  "docs", "metadata",
  "koppen-geiger_legend.txt"
)

# ------------------------------------------------------------------------------
# 1. Read text file
# ------------------------------------------------------------------------------
# --- Path to input text file ---
input_table <- here(
  "docs", "metadata",
  "koppen-geiger_legend.txt"
)

# --- Read all lines ---
legend_lines <- read_lines(input_table)

# ------------------------------------------------------------------------------
# 2. Filter only lines that look like legend entries
# ------------------------------------------------------------------------------
data_lines <- legend_lines[str_detect(legend_lines, "^\\s*\\d+:")]

# ------------------------------------------------------------------------------
# 3. Extract fields using regex
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 4. Write to CSV
# ------------------------------------------------------------------------------
write_csv(
  legend_df,
  file.path(here(), docs, metadata, koppen - geiger_class_legend.csv)
)
