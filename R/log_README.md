R Script Folder Log
================

# 📁 `R/` — Script Log

This log tracks major changes, additions, and decisions related to R
scripts in the project. It supplements the global `CHANGELOG.md` by
providing folder-level context for code evolution, script structure, and
workflow logic.

All entries are reverse chronological. Please include the date, your
initials, and a brief summary.

------------------------------------------------------------------------

## 📌 Log Entries

### 2025-07-29 — C.J.T.

- Standardized use of `.Rmd` and `.md` across all subfolders
- Added `log_README.Rmd` to document folder-level decisions
- Updated script headers in `R/01_download/` and `R/02_clean_validate/`
  to include milestone cross-references

### 2025-07-22 — C.J.T.

- Improved metadata blocks and dependencies across key scripts in
  `R/01_download/`
- Verified file paths and output locations for reproducibility
- Added `README.Rmd` and knitted to `README.md` for GitHub rendering

------------------------------------------------------------------------

## 🧩 Conventions

- Use `{here}` for all paths.
- Follow naming: `01a_task-name.R`, `02b_task-name.R`, etc.
- Scripts should run independently when possible.
