# ==============================================================================
# Function: move_zip_to_archives
# Purpose:  Move .zip (or other) files from domain folders in `data/raw/` into
#           a parallel structure inside `data/raw/archives/`
# Author:   Charles Jason Tinant — with ChatGPT 4o
# Updated:  2025-07-08
# ==============================================================================

move_zip_to_archives <- function(raw_root = here::here("data/raw"),
                                 archive_root = here::here("data/raw/archives"),
                                 file_pattern = "*.zip",
                                 verbose = TRUE) {
  library(fs)
  library(cli)

  # List all subfolders in raw (excluding 'archives')
  domain_folders <- dir_ls(raw_root, type = "directory") %>%
    discard(~ path_file(.) == "archives")

  total_moved <- 0

  for (domain_path in domain_folders) {
    domain_name <- path_file(domain_path)

    # Find matching files in domain folder
    zip_files <- dir_ls(domain_path, recurse = TRUE, glob = file_pattern)

    if (length(zip_files) > 0) {
      # Create subfolder under archives/
      archive_subdir <- path(archive_root, domain_name)
      dir_create(archive_subdir)

      # Move files
      file_move(zip_files, path(archive_subdir, path_file(zip_files)))

      total_moved <- total_moved + length(zip_files)

      if (verbose) {
        cli::cli_alert_success(paste0("Moved {length(zip_files)} {file_pattern}",
                                      "files from {.file {domain_name}} to",
                                      "{.file archives/{domain_name}}"))
      }
    } else if (verbose) {
      cli::cli_alert_info("No {file_pattern} files found in {.file {domain_name}}")
    }
  }

  if (total_moved == 0 && verbose) {
    cli::cli_alert_info("No matching files found in any domain folder.")
  }

  invisible(NULL)
}
