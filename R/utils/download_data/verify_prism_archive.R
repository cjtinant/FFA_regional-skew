# =============================================================================
# Script Name:    verify_prism_archive.R
# Author:         CJ Tinant
# Date Created:   2025-05-14
# Purpose:        Helper function that replicates prism_archive_verify() 
#                 to verify all required files exist for each record
#
#
# Description:
#   - Step 1: Lists .bil and companion files in your {prism} archive
#   - Step 2: Verifies that all required files exist for each record
#   - Step 3: Flags any incomplete or malformed downloads
#   - Step 4: Logs results to CSV
#
#
# Input: 
#   - prism files in data/raw
#
#
# Output: 
#   - verification log
#
# Dependencies:
#   - [e.g., xml2, dplyr, terra, fs]
#
# Notes:
#   - Milestone 01
#
# Example use:Check your archive location (e.g., annual PPT)
# verify_prism_archive("data/raw/prism", 
#                        output_csv = "data/log/prism_qc.csv")

# =============================================================================

#' [Function Title — e.g., Extract metadata from XML]
#'
#' [One-sentence summary of the function’s purpose.]
#'
#' @param [param_name] [Description of what this argument expects.]
#' @param [param_name2] [If applicable, include other parameters.]
#'
#' @return [Description of the return value: tibble, list, vector, etc.]
#'
#' @examples
#' [Example usage, e.g., function_name("path/to/file")]
#'
#' @export

# [your_function_name] <- function([param1], [param2 = NULL]) {
  # Your code here

# updated -- not verified --
verify_prism_flat <- function(flat_dir = "data/raw/prism_flat", output_csv = NULL) {
  library(fs)
  library(dplyr)
  library(stringr)
  
  # Get list of .bil files
  bil_files <- dir_ls(flat_dir, regexp = "\\.bil$")
  core_names <- path_ext_remove(path_file(bil_files))
  
  results <- purrr::map_dfr(core_names, function(base) {
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

# # Mods I made to run the function
# verify_prism_archive <- function(archive_dir = "prism", output_csv = NULL) {
#   library(fs)
#   library(dplyr)
#   library(stringr)
#   
#   # All folders in archive directory (each should correspond to one download)
#   folders <- dir_ls(archive_dir, type = "directory")
#   
#   results <- purrr::map_dfr(folders, function(f) {
#     files <- dir_ls(f, recurse = FALSE)
#     
#     # Extract the expected core filename (should be identical across sidecars)
#     core_name <- basename(f)
#     
#     # Define expected extensions
#     expected_exts <- c(".bil", 
#                        ".xml", 
#                        ".hdr", 
#                        ".info.txt",
#                        ".prj", 
#                        ".bil.aux.xml",
#                        ".stx"
#                        )
#     expected_files <- file.path(f, paste0(core_name, expected_exts))
#     
#     # Check which are present
#     found <- file.exists(expected_files)
#     
#     tibble(
#       folder = f,
#       core_file = core_name,
#       missing_files = paste(expected_exts[!found], collapse = ", "),
#       is_valid = all(found)
#     )
#   })
#   
# #  # Print summary
# #  print(results %>% count(is_valid))
# 
#   # write summary as tibble
#   prism_qc <- results
#   
#   # Optional: write to CSV
#   if (!is.null(output_csv)) {
#     readr::write_csv(results, output_csv)
#   }
#   
#   return(results)
# }


