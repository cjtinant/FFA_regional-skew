# =============================================================================
# File:           move_low_priority_duplicates.R
# Purpose:        Identify and relocate low-priority duplicate vector files 
#                 from `data/raw/vector_raw/` to a holding folder (e.g., 
#                 `to_check/duplicates/`) based on file type and redundancy.
#
# Author:         CJ Tinant
# Date:           2025-04-21
# Project:        FFA Regional Skew Estimation
#
# Inputs:         - duplicate_vector_summary.csv (from 01a_check_spatial_sources.Rmd)
#
# Outputs:        - spatial_source_checklist.csv (audit log of duplicate handling)
#                 - Suggested R `file.rename()` commands to move files
#
# Usage:          source("R/utils/move_low_priority_duplicates.R")
#                 move_low_priority_duplicates()
#
# Notes:          - Prefers `.gpkg` files and flags others for potential relocation
#                 - Does not delete files — moves them safely for review
#                 - Run interactively to confirm before final cleanup
#
# Related:        01a_check_spatial_sources.Rmd, milestone_02_documentation.Rmd
# =============================================================================


library(tidyverse)
library(fs)
library(here)

move_low_priority_duplicates <- function(input_csv = here("to_check/duplicate_vector_summary.csv"),
                                         output_csv = here("to_check/spatial_source_checklist.csv"),
                                         move_dir = here("to_check/duplicates")) {
  
  # Load duplicates
  dup_df <- read_csv(input_csv, show_col_types = FALSE)
  
  # Create target folder
  dir_create(move_dir)
  
  # Tag priority: keep gpkg, deprioritize others
  dup_df <- dup_df %>%
    mutate(
      action = case_when(
        file_type == "gpkg" ~ "keep",
        TRUE ~ "move"
      ),
      dest_path = if_else(action == "move",
                          file.path(move_dir, basename(path)),
                          NA_character_)
    )
  
  # Write checklist for recordkeeping
  write_csv(dup_df, output_csv)
  
  # Generate move script (you can use this manually or as a batch command)
  move_script <- dup_df %>%
    filter(action == "move") %>%
    mutate(move_cmd = glue::glue("file.rename('{path}', '{dest_path}')")) %>%
    pull(move_cmd)
  
  cat("# Run these commands to move low-priority duplicates:\n")
  cat(paste(move_script, collapse = "\n"))
}
