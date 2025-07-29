Milestone 02 – Improve Script and Metadata Documentation
================
C.J. Tinant
July 29, 2025

- [Overview of v1.5.1](#overview-of-v151)
  - [Goal](#goal)
- [Project Structure](#project-structure)
- [v1.5.1 – Improve Script and Metadata
  Documentation](#v151--improve-script-and-metadata-documentation)
- [v1.5.1 Tasklist](#v151-tasklist)
  - [Description of Tasks Completed or In
    Progress](#description-of-tasks-completed-or-in-progress)
- [Next Steps](#next-steps)
- [Summary](#summary)

<!--
For issues with pdf add #    keep_tex: true
-->

# Overview of v1.5.1

<!--
Brief context — why this milestone matters
-->

This milestone focuses on strengthening project transparency and
reproducibility by embedding documentation within analysis folders and
formalizing metadata management.

## Goal

<!--
Clear, concise objective for this milestone.
-->

Enhance clarity, reproducibility, and maintainability of all project
scripts by standardizing documentation headers, comments, and auxiliary
files.

# Project Structure

<!--
Relevant folders and files
-->

``` text
FFA_regional-skew/
├── .gitignore                  # Prevents sensitive/local files from being pushed
├── arcgis_project/             # ArcGIS Pro .aprx project and supporting layers
├── CHANGELOG.Rmd               # Human-readable changelog (semantic versioning)
├── data/                       # Raw, processed, meta, intermediate, and QA data
├── docs/                       # Documentation, workflow notes, metadata, checklists
├── FFA_regional-skew.Rproj     # RStudio project file (keep in root)
├── notebooks/                  # Ad hoc .Rmd/.qmd experiments (empty or minimal)
├── notes/                      # Team notes, meeting logs, brainstorms
├── R/                          # Analysis scripts (milestone-organized)
│   ├── 01_download/            # Download process raw data
│   ├── 02_clean_validate/      # QA scripts and validation checks
│   ├── 03_covariates/          # Covariate extraction
│   ├── 04_modeling/            # Statistical modeling (GAMs, Elastic Net, etc.)
│   ├── 06_eval/                # Model diagnostics, residuals, validation
│   └── utils/                  # Reusable functions (organized by domain)
├── README.md                   # GitHub-readable overview and navigation aid
├── README.Rmd                  # Editable RMarkdown version
├── reports/                    # Knitted .Rmd/.qmd milestone reports
├── results/                    # Manuscript-ready figures, models, and outputs
├── sandbox/                    # Staging area for review
```

# v1.5.1 – Improve Script and Metadata Documentation

# v1.5.1 Tasklist

<!--
Clear, concise objective for this milestone.
Relevant folders and files
-->

| Step | Task | Status |
|----|----|----|
| 2.1 | Standardize header blocks across R scripts | \[X\] |
| 2.2 | Add `README.md` to each `R/` subfolder | \[X\] |
| 2.3 | Ensure all scripts are self-contained | \[X\] |
| 2.4 | Review document dependencies | \[X\] |
| 2.5 | Review `docs/metadata` covariates | \[X\] |
| 2.6 | Standardize use of `.Rmd` and `.md` for all folders | \[X\] |
| 2.7 | Develop `log_README.md` templates to include in `R/` and `data/` | \[X\] |
| 2.8 | Link README-style metadata to milestone logs | \[ \] |
| 2.9 | Commit and push changes as tag `v1.6-docs-enhancement` | \[ \] |

## Description of Tasks Completed or In Progress

### 2.1 Standardize header blocks across all R scripts

This milestone relates to the following folders in `R/01_downloads`,
`R/02_clean_validate`, and `R/utils`. Check the following are included
in all scripts: - Script Name line 20 - Author: line 20 - Date Created
line 20 - Last Updated line 20 - Change Log new line bulleted - Purpose
line 20 - Workflow Summary new line numbered - Input/Data URLs new line
bulleted - Outputs new line bulleted – add subfolder - Dependencies new
line bulleted – description on line 20 - Helper Functions new line
bulleted - Related Milestone Reports new line bulleted - Move notes to
Move notes to notes/script-notes_and_developer-log - Make a consistent
use of `=====` and `------`

### 2.2 Add README files to each major script directory

The README should include the following:

- High level workflow summaries
- A highlight of important scripts and expected outputs
- Links to data directories and relevant logs

### 2.3 Ensure all scripts are self-contained:

- Use here() for all file paths
- Clearly load libraries at top
- Minimize hard-coded paths or variables

### 2.4 Review Document dependencies:

- Ensure that each script lists required packages
- Consider using a renv or DESCRIPTION file for reproducibility
- Add clarifying comments to non-obvious code
- Remove commented-out legacy code unless justified
- Cross-reference milestones or related scripts at the top of each file

### 2.5 Review `docs/metadata` covariates

The file `docs/data_dictionary.pdf` summarizes
`docs/metadata/descriptions/covariate_metadata_vxx.csv`

Check the following items exist: - Variable names - Descriptions -
Units - Data types - Possible value ranges - Notes about relevance,
quality, or source

### 2.6 Standardize use of `.Rmd` and `.md` for all folders

1.  Define Purpose for Each Format

- `.Rmd` = Source file for dynamic documents with embedded R code (used
  for knitting reports, README files, summaries).
- `.md` = Output file (or static version) typically created by knitting
  an .Rmd or manually written for simple documentation (e.g., GitHub
  READMEs).

2.  Audit Each Folder Check folders like `docs/`, `data/`, `notes/`,
    `reports/`:

- Is there an `.Rmd` file with analysis, notes, or a README?
- Is there a matching .md file? If yes, is it auto-generated?
- Is the .md up to date with the `.Rmd`?

🛠️ 3. Standardize Conventions

- Every folder should have a README.Rmd with dynamic content (e.g.,
  script summary, table of outputs).
- Then, knit it to README.md for GitHub display or static viewing.

🧹 4. Clean Up Inconsistencies

- Remove stale .md files that aren’t backed by an .Rmd.

- Rename files for consistency (e.g., avoid both readme.md and
  README.md).

- Ensure every .Rmd can knit cleanly and reproducibly to .md.

### 2.7 Develop `log_README.md` templates to include in `R/` and `data/`

Create standardized log templates (log_README.md) for documenting
changes, decisions, and file-level notes within the project R/ and data/
directories.

The purpose is to act like a local changelog or activity log specific to
that folder to capture:

- Script or file additions/removals
- Data transformations or validation steps
- Notes about known issues, exceptions, or edits
- Author/date stamps for transparency
- Help maintain folder-level traceability for collaborative or long-term
  projects

### Suggested Tags and Commit Messages

If you’re versioning as you go:

    Commit message:
    Add standardized documentation headers to all R/01_download scripts; draft README for data download workflows

    Tag for milestone completion:
    v1.5.0-docs or v02-complete

# Next Steps

<!-- What follows this milestone — e.g., which milestone will build on this work.
-->

# Summary

<!--
Retrospective record of key results and an opportunity to reflect on what was
accomplished.
-->

This milestone strengthens reproducibility by formalizing internal
documentation practices. It includes README templates for `R/`
subfolders, a planned data dictionary, and introduces `log_README.md`
documentation inside each milestone to clarify roles, assumptions, and
outputs.
