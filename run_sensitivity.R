#!/usr/bin/env Rscript
# run_sensitivity.R - sensitivity-analysis driver for the GLP-1/dementia kit.
# Reads scenarios from sensitivity.R, sets the env vars the analysis scripts
# use (SCENARIO_NAME, RESULTS_DIR, OUTPUT_DIR, COVERAGE_MONTHS), then
# invokes run_all.R as a subprocess. Per-scenario results land in
# RESULTS_DIR/<name>/ and per-scenario intermediates in
# named output_sensitivity/<name>/. For scenarios whose start_step > 1, the
# driver first copies the main OUTPUT_DIR into the scenario output folder so
# that upstream intermediates are reused and main's outputs are untouched.
#
# Usage:
#   Rscript run_sensitivity.R --scenario main
#   Rscript run_sensitivity.R --scenario sens2_trim
#   Rscript run_sensitivity.R --all
#   Rscript run_sensitivity.R --list
#   Rscript run_sensitivity.R --help

ansi   <- if (isatty(stdout())) function(c, x) paste0("\033[", c, "m", x, "\033[0m") else function(c, x) x
red    <- function(x) ansi("31;1", x)
green  <- function(x) ansi("32",   x)
yellow <- function(x) ansi("33",   x)
gray   <- function(x) ansi("90",   x)
bold   <- function(x) ansi("1",    x)

die <- function(msg, fix = NULL) {
  cat("\n", red("ERROR: "), msg, "\n", sep = "")
  if (!is.null(fix)) cat(yellow("  Fix: "), fix, "\n", sep = "")
  quit(save = "no", status = 1, runLast = FALSE)
}

# --- locate script dir & source config.R / sensitivity.R ---------------------
cmd_all <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_all, value = TRUE)
SCRIPT_DIR <- if (length(file_arg)) {
  normalizePath(dirname(sub("^--file=", "", file_arg[1])), mustWork = FALSE)
} else {
  normalizePath(getwd(), mustWork = FALSE)
}

CONFIG <- file.path(SCRIPT_DIR, "config.R")
if (!file.exists(CONFIG)) die(sprintf("config.R not found at %s", CONFIG))

# Seed PROJECT_ROOT from this script's directory when .Renviron hasn't set it.
if (!nzchar(Sys.getenv("PROJECT_ROOT"))) Sys.setenv(PROJECT_ROOT = SCRIPT_DIR)

tryCatch(sys.source(CONFIG, envir = globalenv()),
         error = function(e) die(sprintf("Failed to source config.R: %s", conditionMessage(e))))

SENS_FILE <- file.path(SCRIPT_DIR, "sensitivity.R")
if (!file.exists(SENS_FILE)) die(sprintf("sensitivity.R not found at %s", SENS_FILE))
sys.source(SENS_FILE, envir = globalenv())

RUN_ALL <- file.path(SCRIPT_DIR, "run_all.R")
if (!file.exists(RUN_ALL)) die(sprintf("run_all.R not found at %s", RUN_ALL))

# --- arg parsing -------------------------------------------------------------
opts <- list(scenario = NA_character_, all = FALSE, list = FALSE, help = FALSE)
args <- commandArgs(trailingOnly = TRUE); i <- 1L
while (i <= length(args)) {
  switch(args[i],
    "--scenario" = {
      i <- i + 1L
      if (i > length(args)) die("--scenario requires a name", "e.g. --scenario sens2_trim")
      opts$scenario <- args[i]
    },
    "--all"  = { opts$all  <- TRUE },
    "--list" = { opts$list <- TRUE },
    "--help" = { opts$help <- TRUE },
    "-h"     = { opts$help <- TRUE },
    die(sprintf("Unknown argument: %s", args[i]), "Run with --help.")
  )
  i <- i + 1L
}

if (opts$help) {
  cat("Usage: Rscript run_sensitivity.R [--scenario <name> | --all | --list | --help]\n",
      "  --scenario <name>   run one named scenario\n",
      "  --all               run every sensitivity scenario sequentially\n",
      "  --list              print available scenarios and exit\n",
      "  --help, -h          this message\n",
      "\nThe main analysis is run by run_all.R, not by this driver.\n",
      "Results land in <RESULTS_DIR>/<scenario_name>/; intermediates in\n",
      "output_sensitivity/<scenario_name>/. Per-scenario stdout/stderr is captured\n",
      "at logs/sensitivity_<ts>/<scenario_name>.log.\n",
      sep = "")
  quit(save = "no", status = 0)
}

if (opts$list) {
  cat(bold(sprintf("Available scenarios (%d):\n", length(SENSITIVITY_SCENARIOS))))
  w <- max(nchar(names(SENSITIVITY_SCENARIOS)))
  for (nm in names(SENSITIVITY_SCENARIOS)) {
    sc <- SENSITIVITY_SCENARIOS[[nm]]
    ss <- if (is.null(sc$start_step)) 1L else as.integer(sc$start_step)
    cat(sprintf("  %-*s  [from step %2d]  %s\n", w, nm, ss, sc$label))
  }
  quit(save = "no", status = 0)
}

# --- resolve scenarios to run -------------------------------------------------
scenarios_to_run <- if (opts$all) {
  names(SENSITIVITY_SCENARIOS)
} else if (!is.na(opts$scenario)) {
  if (!opts$scenario %in% names(SENSITIVITY_SCENARIOS)) {
    die(sprintf("Unknown scenario: %s", opts$scenario),
        sprintf("Valid: %s", paste(names(SENSITIVITY_SCENARIOS), collapse = ", ")))
  }
  opts$scenario
} else {
  die("No --scenario or --all specified.", "Run with --help or --list.")
}

# --- preflight config values --------------------------------------------------
for (v in c("PROJECT_ROOT", "RESULTS_DIR", "R_BIN")) {
  if (!exists(v, envir = globalenv(), inherits = FALSE) ||
      !is.character(get(v, envir = globalenv())) ||
      !nzchar(get(v, envir = globalenv()))) {
    die(sprintf("config.R missing or has empty %s", v))
  }
}
project_root <- normalizePath(PROJECT_ROOT, winslash = "/", mustWork = TRUE)

# Main results live in `results/main/`; sensitivity scenarios live in
# `results/<scenario>/`. base_results is the parent that holds both.
# config.R's RESULTS_DIR default already points at `results/main`, so we walk
# one level up to find the shared parent.
base_results <- normalizePath(dirname(RESULTS_DIR), winslash = "/", mustWork = FALSE)
main_results <- file.path(base_results, "main")

# Each sensitivity scenario writes its intermediate files to a per-scenario
# folder under output_sensitivity/<name>/, while READS fall back to main's
# OUTPUT_DIR for any file the scenario didn't (re)compute. The fallback is
# implemented inside each analysis script via the MAIN_OUTPUT_DIR env var.
# This is to avoid copying files unnecessarily and save memory/disc space. 
main_output      <- file.path(project_root, "output")
sens_output_base <- file.path(project_root, "output_sensitivity")

r_path <- if (file.exists(R_BIN) && !dir.exists(R_BIN)) {
  normalizePath(R_BIN, winslash = "/", mustWork = FALSE)
} else {
  p <- unname(Sys.which(R_BIN))
  if (!nzchar(p)) die(sprintf("R_BIN '%s' not found on PATH", R_BIN))
  normalizePath(p, winslash = "/", mustWork = FALSE)
}

# --- per-run log dir ----------------------------------------------------------
# One folder per day; reruns on the same day overwrite per-scenario logs.
LOG_DIR <- file.path(project_root, "logs", paste0("sensitivity_", format(Sys.time(), "%Y%m%d")))
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
cat(gray(sprintf("Sensitivity run log dir: %s\n", LOG_DIR)))
cat(gray(sprintf("Scenarios to run: %s\n", paste(scenarios_to_run, collapse = ", "))))

# --- run one scenario via run_all.R subprocess --------------------------------
# system2's `env=` REPLACES the child env on Unix, so we Sys.setenv in this
# process before launch and rely on the child inheriting our environment.
run_scenario <- function(name) {
  sc <- SENSITIVITY_SCENARIOS[[name]]
  start_step <- if (is.null(sc$start_step)) 1L else as.integer(sc$start_step)

  cat("\n", bold(sprintf("=== scenario: %s ===\n", name)), sep = "")
  cat(gray(sprintf("  %s\n", sc$label)))
  cat(gray(sprintf("  start step: %d\n", start_step)))

  this_results <- file.path(base_results, name)
  this_output  <- file.path(sens_output_base, name)
  dir.create(this_results, recursive = TRUE, showWarnings = FALSE)
  dir.create(this_output,  recursive = TRUE, showWarnings = FALSE)
  log_file <- file.path(LOG_DIR, paste0(name, ".log"))
  cat(gray(sprintf("  results: %s\n", this_results)))
  cat(gray(sprintf("  output:  %s   (reads fall back to %s)\n",
                   this_output, main_output)))
  cat(gray(sprintf("  log:     %s\n", log_file)))

  if (start_step > 1L && !dir.exists(main_output)) {
    cat(red(sprintf("  X main output not found at %s - run run_all.R first\n",
                    main_output)))
    return(list(name = name, status = 1L, log = log_file, elapsed = "0s"))
  }

  # Writes go to the scenario's OUTPUT_DIR; analysis scripts fall back to
  # MAIN_OUTPUT_DIR for upstream files that weren't (re)computed by this
  # scenario. No upfront copying.
  Sys.setenv(
    SCENARIO_NAME    = name,
    RESULTS_DIR      = this_results,
    OUTPUT_DIR       = this_output,
    MAIN_OUTPUT_DIR  = main_output,
    COVERAGE_MONTHS  = as.character(as.integer(sc$coverage_months))
  )

  run_args <- shQuote(RUN_ALL)
  if (start_step > 1L) run_args <- c(run_args, "--from", as.character(start_step))

  started <- Sys.time()
  status <- tryCatch(
    system2(r_path, run_args,
            stdout = log_file, stderr = log_file, wait = TRUE),
    error = function(e) {
      cat(red(sprintf("  launch error: %s\n", conditionMessage(e))))
      1L
    }
  )
  elapsed <- sprintf("%.1fs", as.numeric(difftime(Sys.time(), started, units = "secs")))

  if (is.null(status) || is.na(status) || status != 0L) {
    cat(red(sprintf("  ✗ %s failed (exit %s, %s)\n", name, status, elapsed)))
    if (file.exists(log_file)) {
      ll <- tryCatch(readLines(log_file, warn = FALSE), error = function(e) character(0))
      if (length(ll)) {
        cat(gray("  --- last 15 lines of log ---\n"))
        cat(paste(tail(ll, 15), collapse = "\n"), "\n", sep = "")
        cat(gray("  --- end ---\n"))
      }
    }
  } else {
    cat(green(sprintf("  ✓ %s done (%s)\n", name, elapsed)))
  }
  list(name = name, status = status, log = log_file, elapsed = elapsed)
}

results <- lapply(scenarios_to_run, run_scenario)

# --- summary ------------------------------------------------------------------
cat("\n", bold("Sensitivity run summary:\n"), sep = "")
n_ok <- 0L; n_bad <- 0L
for (r in results) {
  if (is.null(r$status) || is.na(r$status) || r$status != 0L) {
    cat(red(sprintf("  ✗ %-22s  (exit %s, %s)\n", r$name, r$status, r$elapsed)))
    n_bad <- n_bad + 1L
  } else {
    cat(green(sprintf("  ✓ %-22s  (%s)\n", r$name, r$elapsed)))
    n_ok <- n_ok + 1L
  }
}
cat(sprintf("\n%d passed, %d failed. Logs: %s\n", n_ok, n_bad, LOG_DIR))

# --- refresh main's table 2 ---------------------------------------------------
# table-2-results.csv aggregates the main analysis with every sensitivity
# scenario it can find on disk. Re-run step 18 on the main scenario so the
# table picks up the scenarios we just produced.
if (n_ok > 0L) {
  cat("\n", bold("Refreshing main table 2 with new sensitivity results...\n"), sep = "")
  Sys.setenv(
    SCENARIO_NAME   = "main",
    RESULTS_DIR     = main_results,
    OUTPUT_DIR      = main_output,
    MAIN_OUTPUT_DIR = main_output
  )
  Sys.unsetenv("COVERAGE_MONTHS")
  refresh_log <- file.path(LOG_DIR, "main_table2_refresh.log")
  cat(gray(sprintf("  log: %s\n", refresh_log)))
  refresh_status <- tryCatch(
    system2(r_path,
            c(shQuote(RUN_ALL), "--only-file", "18-run-survival-analyses.qmd"),
            stdout = refresh_log, stderr = refresh_log, wait = TRUE),
    error = function(e) { cat(red(sprintf("  launch error: %s\n", conditionMessage(e)))); 1L }
  )
  if (is.null(refresh_status) || is.na(refresh_status) || refresh_status != 0L) {
    cat(red(sprintf("  ✗ refresh failed (exit %s)\n", refresh_status)))
    if (file.exists(refresh_log)) {
      ll <- tryCatch(readLines(refresh_log, warn = FALSE), error = function(e) character(0))
      if (length(ll)) {
        cat(gray("  --- last 15 lines of log ---\n"))
        cat(paste(tail(ll, 15), collapse = "\n"), "\n", sep = "")
        cat(gray("  --- end ---\n"))
      }
    }
    if (n_bad == 0L) n_bad <- 1L   # surface refresh failure in the exit code
  } else {
    cat(green("  ✓ main table 2 refreshed\n"))
  }
}

quit(save = "no", status = if (n_bad > 0L) 1L else 0L)
