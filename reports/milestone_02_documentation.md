Milestone 02 – Improve Script and Metadata Documentation
================
C.J. Tinant
July 23, 2025

- [Overview of v1.5](#overview-of-v15)
  - [Goal](#goal)
- [Project Structure](#project-structure)
- [v1.5 – Improve Script and Metadata
  Documentation](#v15--improve-script-and-metadata-documentation)
- [v1.5 Tasklist](#v15-tasklist)
  - [Description of Tasks Completed or In
    Progress](#description-of-tasks-completed-or-in-progress)
- [Summary](#summary)

<!--
For issues with pdf add #    keep_tex: true
&#10;# Description of sections:
1. Overview: Brief context — why this milestone matters.
2. Goal: Clear, concise objective for this milestone.
3. Project Structure: Relevant folders and files
4. Tasklist: Checkboxes for each task or improvement item.
5. Next Steps: What follows this milestone — e.g., which milestone will build on this work.
6. Retrospective Summary: Provides a record of key results and an opportunity to reflect on what was accomplished.
-->

# Overview of v1.5

This milestone focuses on strengthening project transparency and
reproducibility by embedding documentation within analysis folders and
formalizing metadata management.

## Goal

Enhance clarity, reproducibility, and maintainability of all project
scripts by standardizing documentation headers, comments, and auxiliary
files.

# Project Structure

``` text
FFA_regional-skew/
├── .gitignore                    # Prevents sensitive/local files from being pushed
├── arcgis_project/              # ArcGIS Pro .aprx project and supporting layers
├── CHANGELOG.Rmd                # Human-readable changelog (semantic versioning)
├── data/                        # Raw, processed, meta, intermediate, and QA data
├── docs/                        # Documentation, workflow notes, metadata, checklists
├── FFA_regional-skew.Rproj      # RStudio project file (keep in root)
├── notebooks/                   # Ad hoc .Rmd/.qmd experiments (empty or minimal)
├── notes/                       # Team notes, meeting logs, brainstorms (convert to .md/.qmd)
├── R/                           # Analysis scripts (milestone-organized)
│   ├── 01_download/             # Download process raw data
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

# v1.5 – Improve Script and Metadata Documentation

# v1.5 Tasklist

| Step | Task | Status |
|----|----|----|
| 2.1 | Standardize header blocks across all R scripts | \[ \] |
| 2.2 | Add `README.md` to each `R/` subfolder | \[ \] |
| 2.3 | Ensure all scripts are self-contained | \[ \] |
| 2.4 | Review document dependencies | \[ \] |
| 2.5 | Review `data/meta/data_dictionary.csv` to define covariates | \[ \] |
| 2.6 | Standardize use of `.Rmd` and `.md` for all folders | \[ \] |
| 2.7 | Develop `log_README.md` templates to include in `R/` and `data/` | \[ \] |
| 2.8 | Link README-style metadata to milestone logs | \[ \] |
| 2.9 | Commit and push changes as tag `v0.5-docs-enhancement` | \[ \] |

## Description of Tasks Completed or In Progress

### 2.1 Standardize header blocks across all R scripts

Check the following are included in all scripts: - Script Name:
01m_download_ned.R - Author: Charles Jason Tinant — with ChatGPT 4o -
Date Created: - Last Updated: - Change Log: - Purpose: - Workflow
Summary: - Input/Data URLs - Outputs - Dependencies - Related Milestone
Reports - Notes

### 2.2 Add README files to each major script directory

The README should include the following:

- High level workflow summaries
- A highlight of important scripts and expected outputs
- Links to data directories and relevant logs

### 2.3 Ensure all scripts are self-contained:

- Use here() for all file paths
- Clearly load libraries at top
- Minimize hard-coded paths or variables

### 2.4 Document dependencies:

- Ensure that each script lists required packages
- Consider using a renv or DESCRIPTION file for reproducibility

### 2.5 Improve inline comments:

- Add clarifying comments to non-obvious code
- Remove commented-out legacy code unless justified
- Cross-reference milestones or related scripts at the top of each file

### Suggested Tags and Commit Messages

If you’re versioning as you go:

    Commit message:
    Add standardized documentation headers to all R/01_download scripts; draft README for data download workflows

    Tag for milestone completion:
    v1.5.0-docs or v02-complete

# Summary

This milestone strengthens reproducibility by formalizing internal
documentation practices. It includes README templates for `R/`
subfolders, a planned data dictionary, and introduces `log_README.md`
documentation inside each milestone to clarify roles, assumptions, and
outputs.
