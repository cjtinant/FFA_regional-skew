# ==============================================================================
# Script Name:    01f_split_xlsx_into_csv.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   May 2025
# Last Updated:   2025-07-17
#
# Purpose:
# Extract each worksheet from a covariate metadata Excel workbook (.xlsx)
# into a separate, modular .csv file. These CSVs are lightweight, versionable,
# GitHub-compatible, and suitable for direct use in R scripts or automated QA.
# This script supports a clean, maintainable metadata structure for modeling.
#
# Workflow summary:
# 1. 
#
# Input / Output files: user defined
#
# Dependencies:
# - fs             safer file system ops (dir_create)
# - glue           readable string formatting
# - here           relative path handling
# - readr          for writing CSV files
# - readxl         for reading Excel files

# ==============================================================================
library(dplyr)
library(fs)
library(glue)
library(here)
library(janitor)
library(readr)
library(readxl)
library(waldo)
# ------------------------------------------------------------------------------
# 1. (Optional) Compare Excel file versions
# ------------------------------------------------------------------------------
# Define paths
old_file <- here("docs", "metadata", 
                 "regional_skew_covariates_metadata_by_scale_v022.xlsx"
                 )
new_file <-  here("docs", "metadata", 
                  "skew_covariates_metadata_v023.xlsx"
                  )

# List sheets (assumes same sheet names in both files)
sheets_old <- excel_sheets(old_file)
sheets_new <- excel_sheets(new_file)

# Check: do both files have same sheets?
if (!identical(sheets_old, sheets_new)) {
  warning("⚠️ Sheet names differ between files. Proceeding with intersection.")
}
sheets_to_compare <- intersect(sheets_old, sheets_new)

# ---- Compare sheets using Waldo ----
for (sheet in sheets_to_compare) {
  cat("\n--- Comparing Sheet:", sheet, "---\n")
  
  df_old <- read_excel(old_file, sheet = sheet) %>% clean_names()
  df_new <- read_excel(new_file, sheet = sheet) %>% clean_names()
  
  waldo::compare(df_old, df_new)
}

# ---- Compare rows using antijoin() ----

sheet_name <- sheets_to_compare

df_old <- read_excel(old_file, sheet = sheet_name) %>% clean_names()
df_new <- read_excel(new_file, sheet = sheet_name) %>% clean_names()

# Rows in new but not old
anti_join(df_new, df_old)

# Rows in old but not new
anti_join(df_old, df_new)

# ------------------------------------------------------------------------------
# 2. Define file paths
# ------------------------------------------------------------------------------
xlsx_path <- here("docs", "metadata", 
                  "skew_covariates_metadata_v023.xlsx"
                  )

output_dir <- here("docs", "metadata", "covariates_metadata_split")

# Create output directory if it doesn't exist
dir_create(output_dir, recurse = TRUE)

# ------------------------------------------------------------------------------
# 2. Extract sheets and write individual CSVs
# ------------------------------------------------------------------------------

sheets <- excel_sheets(xlsx_path)

for (sheet in sheets) {
  df <- read_excel(xlsx_path, sheet = sheet)
  
  # Clean sheet name for filename use
  base <- gsub("[^A-Za-z0-9]+", "_", sheet) |>
    tolower() |>
    trimws()

  out_file <- path(output_dir, glue("covariates_{base}.csv"))
  
  if (file_exists(out_file)) {
    message("⏭️  Skipping existing file: ", out_file)
    next
  }

  write_csv(df, out_file)
  message("✔️  Wrote: ", out_file)
}


