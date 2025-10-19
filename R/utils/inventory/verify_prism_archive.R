# =============================================================================
# =============================================================================
# Script Name:     verify_prism_archive.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-05-14
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-28     Update header information.
#
# Purpose:         Helper function that replicates prism_archive_verify() to
#                  verify all required files exist for each record
#
# Workflow Summary:
# 1. List .bil and companion files in your {prism} archive.
# 2. Verify required files exist for each record.
# 3. Flags any incomplete or malformed downloads.
# 4. Logs results to CSV,
#
# Input/Data URLs:
# - prism files in data/raw
# Outputs:
#   - verification log
#
# Dependencies:
# - dplyr          Data manipulation.
# - fs             File operations.
# - purrr          Functional programming tools.
# - stringr        String operations.
#
# Helper Functions:
#
# Related Milestone Reports:
#
# =============================================================================
verify_prism_flat <- function(flat_dir = "data/raw/prism_flat", output_csv = NULL) {
  library(fs)
  library(dplyr)
  library(purrr)
  library(stringr)

  # Get list of .bil files
  bil_files <- dir_ls(flat_dir, regexp = "\\.bil$")
  core_names <- path_ext_remove(path_file(bil_files))

  results <- map_dfr(core_names, function(base) {
    expected_exts <- c(".bil", ".hdr", ".prj", ".txt")
    expected_files <- file.path(flat_dir, paste0(base, expected_exts))
    found <- file.exists(expected_files)

    tibble(
      core_file = base,
      missing_files = paste(expected_exts[!found], collapse = ", "),
      is_valid = all(found)
    )
  })

  print(results %>% count(is_valid))

  if (!is.null(output_csv)) {
    readr::write_csv(results, output_csv)
  }

  return(results)
}
