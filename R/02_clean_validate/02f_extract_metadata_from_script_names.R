# =============================================================================
# Script Name:    02f_extract_metadata_from_script_names.R
# Author: Charles Jason Tinant — with ChatGPT 4o
# Date Created:   2025-07-01
# Last Updated:   2025-07-01
# Purpose:        Extract structured information from download scripts and 
#                 generate a CSV tracker.
#
# Description:
#   - Step 1: List scripts in R/01_download/
#   - Step 2: Extract script metadata: step_id, dataset name
#   - Step 3: Standardize dataset names using a manual lookup table
#   - Step 4: Add last modified time from file info
#   - Step 5: Output tracker as CSV
#
# Input: 
#   - R/01_download/*.R
#   - (optional) data/meta/script_name_mapping.csv
#
# Output: 
#   - data/intermediate/download_script_tracker.csv
#
# Dependencies:
#   - fs, stringr, dplyr, readr, here
#
# Notes:
#   - Used in covariate_source_inventory.Rmd to display download script table
# =============================================================================

library(tidyverse)
library(fs)
library(here)

# Step 1: List scripts
download_dir <- here("R/01_download")
script_paths <- dir_ls(download_dir, regexp = "\\.R$")

# Step 2: Create initial tracker
script_tracker <- tibble(
  script = path_file(script_paths),
  full_path = script_paths
) %>%
  mutate(
    step_id = str_extract(script, "^\\d+[a-z]?"),
    dataset = str_remove_all(script, "^\\d+[a-z]?_download_|\\.R$") %>%
      str_replace_all("-", " ") %>%
      str_replace_all("_", " ") %>%
      str_to_title()
  )

# Step 3: Optionally standardize dataset names
name_lookup_path <- here("data/meta/script_name_mapping.csv")
if (file.exists(name_lookup_path)) {
  name_lookup <- read_csv(name_lookup_path, show_col_types = FALSE)
  script_tracker <- script_tracker %>%
    left_join(name_lookup, by = "dataset") %>%
    mutate(dataset = coalesce(Standard_Name, dataset)) %>%
    select(-Standard_Name)
}

# Step 4: Add last modified time
script_tracker <- script_tracker %>%
  mutate(
    last_modified = file_info(full_path)$modification_time
  ) %>%
  select(script, step_id, dataset, last_modified)

# Step 5: Save output
output_path <- here("data/intermediate/download_script_tracker.csv")
write_csv(script_tracker, output_path)
