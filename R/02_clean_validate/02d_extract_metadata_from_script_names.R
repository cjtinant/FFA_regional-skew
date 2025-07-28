# =============================================================================
# Script Name:     02d_extract_metadata_from_script_names.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-01
# Last Updated:    2025-07-25
# Change Log:
# - 2025-07-25     Update header information;
#                  move notes to `script-notes_and_developer-log`
#
# Purpose:         Extract structured information from download scripts and
#                  generate a CSV tracker. Results are used in
#                  `covariate_source_inventory.Rmd` to display a download script
#                  table.
#
# Workflow Summary:
# 1. List scripts in R/01_download/
# 2. Extract script metadata step_id, dataset name
# 3. Standardize dataset names using a manual lookup table
# 4. Add last modified time from file info
# 5. Output tracker as CSV
#
# Input/Data URLs:
#   - R/01_download/*.R
#   - data/meta/script_name_mapping.csv
#
# Outputs:
# - data/meta/download_script_tracker.csv
#
# Dependencies:
# - tidyverse      General data wrangling, import and export.
# - fs             File interface system.
# - here           Consistent relative paths.
#
# Helper Functions:
#
# Related Milestone Reports:
# =============================================================================
# --- Load libraries ---
library(tidyverse)
library(fs)
library(here)

# ------------------------------------------------------------------------------
# 1. List scripts
# ------------------------------------------------------------------------------
download_dir <- here("R/01_download")
script_paths <- dir_ls(download_dir, regexp = "\\.R$")

# ------------------------------------------------------------------------------
# 2. Create initial tracker
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 3. Optionally standardize dataset names
# ------------------------------------------------------------------------------
name_lookup_path <- here("data/meta/script_name_mapping.csv")
if (file.exists(name_lookup_path)) {
  name_lookup <- read_csv(name_lookup_path, show_col_types = FALSE)
  script_tracker <- script_tracker %>%
    left_join(name_lookup, by = "dataset") %>%
    mutate(dataset = coalesce(Standard_Name, dataset)) %>%
    select(-Standard_Name)
}

# ------------------------------------------------------------------------------
# 4. Add last modified time
# ------------------------------------------------------------------------------
script_tracker <- script_tracker %>%
  mutate(
    last_modified = file_info(full_path)$modification_time
  ) %>%
  select(script, step_id, dataset, last_modified)

# ------------------------------------------------------------------------------
# 5. Save output
# ------------------------------------------------------------------------------
output_path <- here("data/intermediate/download_script_tracker.csv")
write_csv(script_tracker, output_path)
