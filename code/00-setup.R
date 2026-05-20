# =============================================================================
# 00-setup.R - one-time setup for the repkit.
# =============================================================================
# In RStudio: open this file and click Source (or run line-by-line).
#
# What it does:
#   1. Locates the project root (the directory containing config.R).
#   2. Restores the R package environment with renv (uses renv.lock).
#   3. Writes <project_root>/.Renviron with your Snowflake DSN and the
#      project paths. config.R + run_all.R read these automatically; you do
#      not need to edit any paths yourself.
#
# If a .Renviron already exists at the project root, this script keeps it and
# does not prompt again. Delete the file and re-run if you want to redo setup.
# =============================================================================

# --- locate project root ------------------------------------------------------
locate_script <- function() {
  # RStudio: ask the editor for the active file path.
  if (interactive() &&
      requireNamespace("rstudioapi", quietly = TRUE) &&
      tryCatch(rstudioapi::isAvailable(), error = function(e) FALSE)) {
    ctx <- tryCatch(rstudioapi::getSourceEditorContext(), error = function(e) NULL)
    if (!is.null(ctx) && nzchar(ctx$path)) return(normalizePath(ctx$path, winslash = "/"))
  }
  # Rscript: pull from --file= argument.
  f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(f)) return(normalizePath(sub("^--file=", "", f[1]), winslash = "/"))
  # Fall back to the working directory (script must be sourced from code/ or repo root).
  NA_character_
}

script_path <- locate_script()
search_from <- if (is.na(script_path)) {
  normalizePath(getwd(), winslash = "/")
} else {
  normalizePath(dirname(script_path), winslash = "/")
}

# Walk up at most two levels looking for config.R.
project_root <- NULL
for (cand in c(search_from, dirname(search_from), dirname(dirname(search_from)))) {
  if (file.exists(file.path(cand, "config.R"))) { project_root <- cand; break }
}
if (is.null(project_root))
  stop("Could not locate the project root (looking for config.R). ",
       "Open this file in RStudio, or run from inside <repo>/code/.")

cat("Detected project root: ", project_root, "\n", sep = "")

# --- restore R package environment --------------------------------------------
renv_project <- file.path(project_root, "code")
if (!file.exists(file.path(renv_project, "renv.lock")))
  stop("Expected renv.lock at ", renv_project,
       " - is your clone of the repo complete?")

options(repos = c(CRAN = "https://cloud.r-project.org"))
# yaml is required for renv to parse renv.lock; install yaml + renv at the
# user library so they're available regardless of which library is active.
if (!requireNamespace("yaml", quietly = TRUE)) {
  cat("Installing yaml...\n")
  install.packages("yaml")
}
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv...\n")
  install.packages("renv")
}

cat("Restoring R packages from renv.lock (this can take several minutes the first time)...\n")
renv::restore(project = renv_project, prompt = FALSE)

# --- write .Renviron ----------------------------------------------------------
renviron_path <- file.path(project_root, ".Renviron")
if (file.exists(renviron_path)) {
  cat("\nExisting .Renviron found at: ", renviron_path, "\n", sep = "")
  cat("Keeping it. Delete the file and re-run 00-setup.R to rewrite.\n")
  readRenviron(renviron_path)
} else {
  if (!interactive())
    stop("Need to prompt for the Snowflake DSN. ",
         "Re-run this script interactively (e.g., open it in RStudio).")

  dsn <- readline("Enter your Snowflake DSN (as configured in Windows ODBC): ")
  dsn <- trimws(dsn)
  if (!nzchar(dsn)) stop("DSN cannot be empty.")

  # Only DSN and PROJECT_ROOT go into .Renviron. OUTPUT_DIR and RESULTS_DIR
  # are deliberately NOT written here: config.R derives them from
  # PROJECT_ROOT, and run_sensitivity.R overrides them per scenario via
  # Sys.setenv(). If they were in .Renviron, every subprocess R session
  # would re-read .Renviron at startup and silently override the per-scenario
  # values, sending sensitivity writes back into main's folders.
  lines <- c(
    sprintf("DSN='%s'",          dsn),
    sprintf("PROJECT_ROOT='%s'", project_root)
  )
  writeLines(lines, renviron_path)
  readRenviron(renviron_path)
  cat("\nWrote .Renviron at: ", renviron_path, "\n", sep = "")
}

# --- verify -------------------------------------------------------------------
cat("\nResolved environment (OUTPUT_DIR / RESULTS_DIR are derived by config.R):\n")
for (k in c("DSN", "PROJECT_ROOT"))
  cat(sprintf("  %-13s %s\n", paste0(k, ":"), Sys.getenv(k)))

# Write code/.Rprofile so future R sessions auto-activate the project library.
# Done last so that even if RStudio asks to restart after this file appears,
# the restart happens AFTER all setup work above has finished.
rprofile_path <- file.path(renv_project, ".Rprofile")
if (!file.exists(rprofile_path)) {
  writeLines('source("renv/activate.R")', rprofile_path)
  cat("Wrote ", rprofile_path,
      " (auto-activates the project library on future R sessions).\n", sep = "")
}

cat("\nSetup complete. You can now launch the pipeline:\n",
    "  macOS:    double-click run_all.command\n",
    "  Windows:  double-click run_all.bat\n",
    "  Either:   Rscript run_all.R\n", sep = "")
