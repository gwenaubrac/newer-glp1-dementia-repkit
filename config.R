# =============================================================================
# config.R
# =============================================================================
# Most users do not need to edit this file. Edit only the sections labelled
# "EDIT IF NEEDED" below.
#
# First-time setup:
#   1. Open code/00-setup.R in RStudio and source it (one-time).
#      It restores R packages and writes a .Renviron with your Snowflake DSN
#      and project paths.
#   2. Then launch the pipeline:
#        macOS:    double-click run_all.command   (or: Rscript run_all.R)
#        Windows:  double-click run_all.bat       (or: Rscript run_all.R)
# =============================================================================


# ------------------------------------------------------------------------------
# 1. STUDY WINDOW - EDIT IF NEEDED
# ------------------------------------------------------------------------------
# Read by 03-identify-new-users.qmd (cohort entry),
# 05-extract-coverage-indicator.do (eligibility-end cutoff), and
# 18-run-survival-analyses.qmd.
STUDY_START <- "2022-05-01"
STUDY_END   <- "2025-12-31"


# ------------------------------------------------------------------------------
# 2. R / QUARTO BINARIES - EDIT IF NEEDED
# ------------------------------------------------------------------------------
# Bare name (resolved on PATH) or an absolute path to the executable.
R_BIN      <- "C:/Program Files/R/R-4.4.2/bin/x64/Rscript.exe"   # Also "Rscript"
QUARTO_BIN <- "quarto"


# ------------------------------------------------------------------------------
# 3. STATA BINARY - EDIT IF NEEDED
# ------------------------------------------------------------------------------
# Auto-resolved per platform. Override the matching row only if your install
# differs from the default name/edition.
STATA_BIN <- switch(
  Sys.info()[["sysname"]],
  Darwin  = "stata-mp",       # macOS, also: "stata-se", "stata"
  Linux   = "stata-mp",       # Linux
  Windows = "C:/Program Files/Stata18/StataMP-64.exe",     # Windows, also: "StataMP-64", "StataSE-64", "Stata-64"
  "stata"
)


# ------------------------------------------------------------------------------
# 4. SNOWFLAKE DATABASE / SCHEMA - EDIT IF NEEDED
# ------------------------------------------------------------------------------
# The Snowflake database (client) and schema (cohort) that hold the patient-
# level claims tables this kit reads from. Every odbc query in the Stata .do
# files and 02-extract-dispensings.qmd builds its table reference as
#   $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.<TABLE>
# so a new cohort/client only needs these two values changed.
SNOWFLAKE_CLIENT <- "DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD"
SNOWFLAKE_COHORT <- "COHORT_1302462"


# --- INTERNALS - auto-detected from .Renviron, do not edit -------------------
PROJECT_ROOT <- Sys.getenv("PROJECT_ROOT")
if (!nzchar(PROJECT_ROOT) || !dir.exists(PROJECT_ROOT)) {
  stop("PROJECT_ROOT is not set. To run any analysis script directly in an ",
       "R session, source code/00-setup.R first in the same session (it loads ",
       ".Renviron). Otherwise launch the full pipeline via run_all.R / ",
       "run_all.command / run_all.bat.")
}
# Normalize once with forward slashes so every derived path (DATA_DIR,
# MAIN_OUTPUT_DIR, OUTPUT_DIR, RESULTS_DIR, etc.) doesn't mix `\` from a
# Windows-style .Renviron with `/` from file.path(). Without this, file paths
# end up like "D:\Users\...\repo/output/foo.rds" and gzfile() (used by
# readRDS) refuses to open them on Windows.
PROJECT_ROOT <- normalizePath(PROJECT_ROOT, winslash = "/", mustWork = FALSE)
Sys.setenv(PROJECT_ROOT = PROJECT_ROOT)

# Snowflake DSN
SNOWFLAKE_DSN <- Sys.getenv("DSN")
if (!nzchar(SNOWFLAKE_DSN)) {
  stop("DSN is not set. To run any analysis script directly in an R session, ",
       "source code/00-setup.R first in the same session (it prompts for the ",
       "DSN and writes .Renviron).")
}

DATA_DIR    <- file.path(PROJECT_ROOT, "data")                                       # input data (not used directly)
# Main analysis intermediate files always live under <PROJECT_ROOT>/output.
# OUTPUT_DIR is settable via env var so run_sensitivity.R can redirect a
# scenario's writes into output_sensitivity/<scenario>/, while MAIN_OUTPUT_DIR
# stays pinned to the main folder so analysis scripts can fall back to it
# when an upstream file isn't present in the scenario's OUTPUT_DIR.
MAIN_OUTPUT_DIR <- file.path(PROJECT_ROOT, "output")
OUTPUT_DIR  <- Sys.getenv("OUTPUT_DIR",  unset = MAIN_OUTPUT_DIR)                    # intermediate files
# Main analysis results live in results/main/; sensitivity scenarios live in
# results/<scenario>/ (set by run_sensitivity.R).
RESULTS_DIR <- Sys.getenv("RESULTS_DIR", unset = file.path(PROJECT_ROOT, "results", "main"))

# Normalize any path that came in via env var so we never mix slashes.
OUTPUT_DIR      <- normalizePath(OUTPUT_DIR,      winslash = "/", mustWork = FALSE)
MAIN_OUTPUT_DIR <- normalizePath(MAIN_OUTPUT_DIR, winslash = "/", mustWork = FALSE)
RESULTS_DIR     <- normalizePath(RESULTS_DIR,     winslash = "/", mustWork = FALSE)
DATA_DIR        <- normalizePath(DATA_DIR,        winslash = "/", mustWork = FALSE)

# Pin study dates + Snowflake namespace + main output anchor into the env so
# .do / .qmd scripts can read them. The Stata globals are also written into
# _globals.do below.
Sys.setenv(STUDY_START      = STUDY_START,
           STUDY_END        = STUDY_END,
           SNOWFLAKE_CLIENT = SNOWFLAKE_CLIENT,
           SNOWFLAKE_COHORT = SNOWFLAKE_COHORT,
           MAIN_OUTPUT_DIR  = MAIN_OUTPUT_DIR)

# Writes <PROJECT_ROOT>/_globals.do containing one `global X "value"` per
# config entry. Every .do file `include`s this file at the top, so all paths
# and study parameters flow from config.R into Stata without env-var games.
# Written as raw bytes - guarantees no UTF-8 BOM (Stata reports BOMs as
# "ï»¿ is not a valid command name r(199)").
write_globals_do <- function() {
  globals <- list(
    PROJECT_ROOT     = PROJECT_ROOT,
    DATA_DIR         = DATA_DIR,
    OUTPUT_DIR       = OUTPUT_DIR,
    MAIN_OUTPUT_DIR  = MAIN_OUTPUT_DIR,
    RESULTS_DIR      = RESULTS_DIR,
    STUDY_START      = STUDY_START,
    STUDY_END        = STUDY_END,
    COVERAGE_MONTHS  = Sys.getenv("COVERAGE_MONTHS", unset = "12"),
    SCENARIO_NAME    = Sys.getenv("SCENARIO_NAME",   unset = "main"),
    SNOWFLAKE_DSN    = SNOWFLAKE_DSN,
    SNOWFLAKE_CLIENT = SNOWFLAKE_CLIENT,
    SNOWFLAKE_COHORT = SNOWFLAKE_COHORT
  )
  lines <- c(
    "* Auto-generated by config.R, do not edit by hand.",
    "* Regenerated each time the pipeline runs (or when you source config.R).",
    sprintf('global %s "%s"', names(globals), unlist(globals))
  )
  path <- file.path(PROJECT_ROOT, "_globals.do")
  writeBin(charToRaw(paste(lines, collapse = "\n")), path)
  invisible(path)
}
