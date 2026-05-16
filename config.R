# =============================================================================
# config.R — THE ONLY FILE YOU NEED TO EDIT
# =============================================================================
# Set the paths and binaries below, then run the pipeline:
#
#   macOS:     double-click run_all.command   (or:  Rscript run_all.R)
#   Windows:   double-click run_all.bat       (or:  Rscript run_all.R)
#
# run_all.R sources this file and pushes every value into the environment so
# that child R, Quarto, and Stata processes all see the same paths.
#
# RStudio / interactive R users: the same variables in .Renviron (created by
# code/00-setup.R) are used by individual scripts when run interactively.
# =============================================================================

# --- Paths --------------------------------------------------------------------
# PROJECT_ROOT is the absolute path to your local clone of this repo.
PROJECT_ROOT <- "/path/to/your/repo"

DATA_DIR    <- file.path(PROJECT_ROOT, "data")        # input data (not used directly)
OUTPUT_DIR  <- file.path(PROJECT_ROOT, "output")      # intermediate files
RESULTS_DIR <- file.path(PROJECT_ROOT, "novel_res")   # final results

# --- Binaries -----------------------------------------------------------------
# Either a bare name (resolved on PATH) or an absolute path to the executable.
R_BIN      <- "Rscript"
QUARTO_BIN <- "quarto"

# Stata binary name varies by OS and edition; auto-resolved per platform.
# Override the value on the right of the matching row if your install differs.
STATA_BIN <- switch(
  Sys.info()[["sysname"]],
  Darwin  = "stata-mp",       # macOS — also: "stata-se", "stata"
  Linux   = "stata-mp",       # Linux
  Windows = "StataMP-64",     # Windows — also: "StataSE-64", "Stata-64"
  "stata"
)
