#!/usr/bin/env Rscript
# run_all.R - runs the GLP-1/dementia replication pipeline end-to-end.
# Usage: Rscript run_all.R [--dry-run] [--list] [--from N] [--only N] [--help]

IS_WIN <- .Platform$OS.type == "windows"
if (IS_WIN) try(invisible(system("")), silent = TRUE)  # enable ANSI on Win Terminal

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

PIPELINE <- list(
  c("01-extract-drug-codes.qmd",            "QMD"),
  c("02-extract-dispensings.qmd",           "QMD"),
  c("03-identify-new-users.qmd",            "QMD"),
  c("04-extract-censoring-dates.do",        "STATA"),
  c("05-extract-coverage-indicator.do",     "STATA"),
  c("06-apply-eligibility-criteria.do",     "STATA"),
  c("07-create-eligibility-flowchart.R",  "R"),
  c("08-extract-demographic-covs.do",       "STATA"),
  c("09-extract-comorbidity-covs.do",       "STATA"),
  c("10-extract-medication-covs.do",        "STATA"),
  c("11-extract-provider-zip-cov.do",       "STATA"),
  c("12-merge-covariates.do",                     "STATA"),
  c("13-extract-outcome-occurrences.do",    "STATA"),
  c("14-clean-data.qmd",                    "QMD"),
  c("15a-compute-ipcw.qmd",                 "QMD"),
  c("15b-describe-ipcw.R",                  "R"),
  c("16-compute-iptw.qmd",                  "QMD"),
  c("17-describe-study-sample.qmd",               "QMD"),
  c("18-run-survival-analyses.qmd",         "QMD"),
  c("19-create-plots.qmd",                    "QMD")
)
N <- length(PIPELINE)
step_label <- function(i) sprintf(" [%2d/%d] %-7s %s", i, N,
                                  paste0("(", PIPELINE[[i]][2], ")"), PIPELINE[[i]][1])

# --- arg parsing --------------------------------------------------------------
opts <- list(dry = FALSE, list = FALSE, from = NA_integer_, only = NA_integer_, help = FALSE)
need_int <- function(name, raw) {
  v <- suppressWarnings(as.integer(raw))
  if (is.na(v) || v < 1 || v > N)
    die(sprintf("%s must be an integer between 1 and %d (got: %s)", name, N, raw))
  v
}
args <- commandArgs(trailingOnly = TRUE); i <- 1L
while (i <= length(args)) {
  switch(args[i],
    "--dry-run" = { opts$dry  <- TRUE },
    "--list"    = { opts$list <- TRUE },
    "--help"    = { opts$help <- TRUE },
    "-h"        = { opts$help <- TRUE },
    "--from"    = { i <- i + 1L; opts$from <- need_int("--from", args[i]) },
    "--only"    = { i <- i + 1L; opts$only <- need_int("--only", args[i]) },
    "--only-file" = {
      i <- i + 1L
      if (i > length(args)) die("--only-file requires a filename", "e.g. --only-file 18-run-survival-analyses.qmd")
      target <- args[i]
      idx <- which(vapply(PIPELINE, function(s) identical(s[1], target), logical(1)))
      if (!length(idx)) die(sprintf("--only-file: %s not in PIPELINE", target),
                            "Run with --list to see step names.")
      opts$only <- idx
    },
    die(sprintf("Unknown argument: %s", args[i]), "Run with --help.")
  )
  i <- i + 1L
}
if (!is.na(opts$from) && !is.na(opts$only)) die("--from and --only cannot be combined.")

if (opts$help) {
  cat("Usage: Rscript run_all.R [--dry-run] [--list] [--from N] [--only N] [--help]\n",
      "  --dry-run   preflight only; print resolved config and exit\n",
      "  --list      print step list and exit\n",
      "  --from N    start at step N (1-indexed) and run to end\n",
      "  --only N    run only step N\n",
      "  --only-file F   run only the step whose script is named F\n",
      "  --help, -h  this message\n", sep = "")
  quit(save = "no", status = 0)
}

if (opts$list) {
  cat(bold(sprintf("Pipeline (%d steps):\n", N)))
  for (i in seq_len(N)) cat(step_label(i), "\n", sep = "")
  quit(save = "no", status = 0)
}

# --- locate & source config.R -------------------------------------------------
cmd_all <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_all, value = TRUE)
SCRIPT_DIR <- if (length(file_arg)) {
  normalizePath(dirname(sub("^--file=", "", file_arg[1])), mustWork = FALSE)
} else {
  normalizePath(getwd(), mustWork = FALSE)
}

CONFIG <- file.path(SCRIPT_DIR, "config.R")
if (!file.exists(CONFIG)) die(sprintf("config.R not found at %s", CONFIG))

# Seed PROJECT_ROOT from this script's directory when .Renviron hasn't set it
# yet. config.R reads PROJECT_ROOT from the env, so this makes a fresh clone
# work even before 00-setup.R has been run.
if (!nzchar(Sys.getenv("PROJECT_ROOT"))) Sys.setenv(PROJECT_ROOT = SCRIPT_DIR)

tryCatch(sys.source(CONFIG, envir = globalenv()),
         error = function(e) die(sprintf("Failed to source config.R: %s", conditionMessage(e))))

# --- preflight ----------------------------------------------------------------
REQ <- c("PROJECT_ROOT","DATA_DIR","OUTPUT_DIR","MAIN_OUTPUT_DIR","RESULTS_DIR",
         "R_BIN","QUARTO_BIN","STATA_BIN",
         "SNOWFLAKE_CLIENT","SNOWFLAKE_COHORT")
for (v in REQ) {
  if (!exists(v, envir = globalenv(), inherits = FALSE) ||
      !is.character(get(v, envir = globalenv())) ||
      length(get(v, envir = globalenv())) != 1L ||
      !nzchar(get(v, envir = globalenv())))
    die(sprintf("config.R is missing or has empty %s", v))
}
PROJECT_ROOT <- normalizePath(PROJECT_ROOT, winslash = "/", mustWork = FALSE)
if (!dir.exists(PROJECT_ROOT)) die(sprintf("PROJECT_ROOT does not exist: %s", PROJECT_ROOT))
DATA_DIR        <- normalizePath(DATA_DIR,        winslash = "/", mustWork = FALSE)
OUTPUT_DIR      <- normalizePath(OUTPUT_DIR,      winslash = "/", mustWork = FALSE)
MAIN_OUTPUT_DIR <- normalizePath(MAIN_OUTPUT_DIR, winslash = "/", mustWork = FALSE)
RESULTS_DIR     <- normalizePath(RESULTS_DIR,     winslash = "/", mustWork = FALSE)
Sys.setenv(PROJECT_ROOT = PROJECT_ROOT, DATA_DIR = DATA_DIR, OUTPUT_DIR = OUTPUT_DIR,
           MAIN_OUTPUT_DIR = MAIN_OUTPUT_DIR,
           RESULTS_DIR = RESULTS_DIR, R_BIN = R_BIN, QUARTO_BIN = QUARTO_BIN, STATA_BIN = STATA_BIN,
           SNOWFLAKE_CLIENT = SNOWFLAKE_CLIENT, SNOWFLAKE_COHORT = SNOWFLAKE_COHORT)

# Make sure the per-run output + results folders exist before any step writes
# to them (main = results/main; sensitivity scenarios = results/<scenario>).
dir.create(OUTPUT_DIR,  recursive = TRUE, showWarnings = FALSE)
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

resolve_exe <- function(x, lbl) {
  if (file.exists(x) && !dir.exists(x)) return(normalizePath(x, winslash = "/", mustWork = FALSE))
  p <- unname(Sys.which(x))
  if (!nzchar(p)) die(sprintf("%s not found on PATH: %s", lbl, x),
                      sprintf("Install it or set %s to its full path in config.R.", lbl))
  normalizePath(p, winslash = "/", mustWork = FALSE)
}
R_PATH      <- resolve_exe(R_BIN,      "R_BIN")
QUARTO_PATH <- resolve_exe(QUARTO_BIN, "QUARTO_BIN")
STATA_PATH  <- resolve_exe(STATA_BIN,  "STATA_BIN")

CODE_DIR <- file.path(PROJECT_ROOT, "code")
if (!dir.exists(CODE_DIR)) die(sprintf("code/ directory not found at %s", CODE_DIR))
missing <- vapply(PIPELINE, function(s) !file.exists(file.path(CODE_DIR, s[1])), logical(1))
if (any(missing))
  die(sprintf("Missing script(s) in %s:\n  - %s", CODE_DIR,
              paste(vapply(PIPELINE[missing], `[`, character(1), 1), collapse = "\n  - ")))

if (!file.exists(file.path(PROJECT_ROOT, ".Renviron")))
  cat(yellow("WARNING: .Renviron not found (only needed for interactive use).\n"))

if (opts$dry) {
  cat(bold("Resolved configuration\n"))
  rows <- c(
    sprintf("  OS           : %s", Sys.info()[["sysname"]]),
    sprintf("  SCRIPT_DIR   : %s", SCRIPT_DIR),
    sprintf("  PROJECT_ROOT : %s", PROJECT_ROOT),
    sprintf("  DATA_DIR     : %s", DATA_DIR),
    sprintf("  OUTPUT_DIR   : %s", OUTPUT_DIR),
    sprintf("  RESULTS_DIR  : %s", RESULTS_DIR),
    sprintf("  R_BIN        : %s  ->  %s", R_BIN,      R_PATH),
    sprintf("  QUARTO_BIN   : %s  ->  %s", QUARTO_BIN, QUARTO_PATH),
    sprintf("  STATA_BIN    : %s  ->  %s", STATA_BIN,  STATA_PATH))
  for (r in rows) cat(gray(r), "\n", sep = "")
  cat("\n", bold(sprintf("Pipeline (%d steps):\n", N)), sep = "")
  for (i in seq_len(N)) cat(step_label(i), "\n", sep = "")
  cat("\n", green("Dry run OK.\n"), sep = "")
  quit(save = "no", status = 0)
}

# --- write Stata globals ------------------------------------------------------
# Every .do file starts with `include "_globals.do"`. Regenerate it now so that
# scenario-specific env vars (SCENARIO_NAME, COVERAGE_MONTHS, RESULTS_DIR) are
# reflected in this run's globals.
globals_path <- write_globals_do()
cat(gray(sprintf("Stata globals: %s\n", globals_path)))

# --- runners ------------------------------------------------------------------
build_argv <- function(engine, script) switch(engine,
  R     = c(R_PATH, script),
  QMD   = c(QUARTO_PATH, "render", script),
  STATA = if (IS_WIN) c(STATA_PATH, "/e", "do", script) else c(STATA_PATH, "-b", "do", script))

# Live stream + tee to log_file. system2() concatenates args via /bin/sh
# without quoting, so on Unix we wrap the whole pipeline as `bash -c '...'`
# (otherwise `;` and `|` are parsed by sh before bash sees them and
# `set -o pipefail` never takes effect). On Windows we hand a temp .ps1 to
# PowerShell, which avoids cmd.exe quoting hell.
run_tee <- function(argv, log_file) {
  if (IS_WIN) {
    psq <- function(x) sprintf("'%s'", gsub("'", "''", x, fixed = TRUE))
    cmd <- paste(vapply(argv, psq, character(1)), collapse = " ")
    ps <- sprintf("$ErrorActionPreference='SilentlyContinue'\n& %s 2>&1 | Tee-Object -FilePath %s\nexit $LASTEXITCODE\n",
                  cmd, psq(log_file))
    f <- tempfile(fileext = ".ps1"); writeLines(ps, f); on.exit(unlink(f), add = TRUE)
    system2("powershell", c("-NoProfile","-ExecutionPolicy","Bypass","-File", f), wait = TRUE)
  } else {
    cmd <- paste(vapply(argv, shQuote, character(1)), collapse = " ")
    sh  <- sprintf("set -o pipefail; %s 2>&1 | tee %s", cmd, shQuote(log_file))
    system(paste("bash -c", shQuote(sh)), wait = TRUE)
  }
}

# Stata -b is silent on stdout; it writes <basename>.log to CWD. Run, then
# copy the log to our run directory, tail it, and scan for `r(NNN);` errors
# (Stata can return exit 0 even after one). The .do file's first line is
# `include "_globals.do"`, which sets every $X global from config.R.
run_stata <- function(argv, script_file, our_log) {
  cat(gray("  (Stata batch mode is silent; output shown after the run completes.)\n"))
  status <- system2(argv[1], argv[-1], wait = TRUE)
  log_name <- sub("\\.do$", ".log", script_file, ignore.case = TRUE)
  stata_log <- file.path(PROJECT_ROOT, log_name)
  if (file.exists(stata_log)) {
    lines <- tryCatch(readLines(stata_log, warn = FALSE), error = function(e) character(0))
    # Move (not copy) into LOG_DIR so the project root doesn't accumulate
    # duplicate <step>.log files between runs.
    if (file.exists(our_log)) file.remove(our_log)
    moved <- file.rename(stata_log, our_log)
    if (!moved) {
      file.copy(stata_log, our_log, overwrite = TRUE)
      file.remove(stata_log)
    }
    cat(gray(sprintf("  --- last 30 lines of %s ---\n", log_name)))
    if (length(lines)) cat(paste(tail(lines, 30), collapse = "\n"), "\n", sep = "")
    cat(gray("  --- end ---\n"))
    errs <- grep("^r\\([0-9]+\\);", lines, value = TRUE)
    if (length(errs) && status == 0) {
      cat(yellow(sprintf("WARNING: Stata error in log but exit 0: %s\n",
                         paste(errs, collapse = "; "))))
      status <- 1L
    }
  } else {
    cat(yellow(sprintf("WARNING: expected Stata log not found at %s\n", stata_log)))
  }
  status
}

# --- main loop ----------------------------------------------------------------
to_run <- (
  if (!is.na(opts$only))      opts$only
  else if (!is.na(opts$from)) seq(opts$from, N)
  else                        seq_len(N)
)

LOG_DIR <- file.path(PROJECT_ROOT, "logs", format(Sys.time(), "%Y%m%d"))
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
cat(gray(sprintf("Logs: %s\n", LOG_DIR)))

overall_start <- Sys.time()
current <- NA_integer_

tryCatch({
  for (idx in to_run) {
    current <- idx
    file <- PIPELINE[[idx]][1]; engine <- PIPELINE[[idx]][2]
    script_path <- normalizePath(file.path(CODE_DIR, file), winslash = "/", mustWork = TRUE)
    log_file <- file.path(LOG_DIR, sub("\\.(qmd|R|do)$", ".log", file, ignore.case = TRUE))

    cat("\n", bold(sprintf("[%2d/%d] %s", idx, N, file)),
        gray(sprintf("  (%s)  %s\n", engine, format(Sys.time(), "%H:%M:%S"))), sep = "")
    started <- Sys.time()

    old_wd <- setwd(PROJECT_ROOT); on.exit(setwd(old_wd), add = TRUE, after = FALSE)
    argv <- build_argv(engine, script_path)
    status <- if (engine == "STATA") run_stata(argv, file, log_file) else run_tee(argv, log_file)
    setwd(old_wd)

    elapsed <- sprintf("%.1fs", as.numeric(difftime(Sys.time(), started, units = "secs")))
    if (!is.null(status) && !is.na(status) && status != 0) {
      cat("\n", red(sprintf("  ✗ step %d failed (exit %s, elapsed %s)\n",
                            idx, status, elapsed)), sep = "")
      if (file.exists(log_file)) {
        ll <- tryCatch(readLines(log_file, warn = FALSE), error = function(e) character(0))
        if (length(ll)) {
          cat(gray("  --- last 20 lines of log ---\n"))
          cat(paste(tail(ll, 20), collapse = "\n"), "\n", sep = "")
          cat(gray("  --- end ---\n"))
        }
        cat(yellow(sprintf("  Full log: %s\n", log_file)))
      }
      quit(save = "no", status = 1, runLast = FALSE)
    }
    cat(green(sprintf("  ✓ step %d done (%s)\n", idx, elapsed)))
  }
}, interrupt = function(e) {
  cat("\n", red(sprintf("Interrupted at step %s.\n",
                         if (is.na(current)) "?" else current)), sep = "")
  quit(save = "no", status = 130, runLast = FALSE)
})

overall <- sprintf("%.1fs", as.numeric(difftime(Sys.time(), overall_start, units = "secs")))
cat("\n", green(bold(sprintf("Pipeline complete in %s.\n", overall))), sep = "")
cat("Results: ", RESULTS_DIR, "\nLogs:    ", LOG_DIR, "\n", sep = "")
