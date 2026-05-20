# =============================================================================
# sensitivity.R - scenario definitions for the GLP-1/dementia kit
# =============================================================================
# Defines each sensitivity scenario as a named list of parameter values that
# inherits from `.main` and overrides only the fields that differ. The main
# analysis is not a scenario - it is what `run_all.R` runs with no overrides.
#
# Sourced by run_sensitivity.R (the driver) and by the four parameterized
# analysis scripts (05, 14, 16, 18). Those scripts call get_scenario(), which
# reads SCENARIO_NAME from the environment and returns the matching list,
# falling back to the main defaults when SCENARIO_NAME is unset or "main".
#
# `start_step` is the first pipeline step (see PIPELINE in run_all.R) that
# differs from main. run_sensitivity.R copies main's OUTPUT_DIR into a
# per-scenario output folder and then launches `run_all.R --from <start_step>`,
# so upstream intermediate files are reused without being overwritten.
# Step indices: 5 = 05-extract-coverage-indicator; 14 = 14-clean-data;
# 15 = 15a-compute-ipcw; 17 = 16-compute-iptw; 19 = 18-run-survival-analyses.
# =============================================================================

.main <- list(
  label               = "Main analysis (default settings, no sensitivity override)",
  weight_method       = "iptw",          # "iptw" or "ebal"
  weight_trimming     = FALSE,           # logical
  trimming_pct        = NULL,            # numeric in (0, 0.5) or NULL
  use_ipcw            = FALSE,           # logical; only affects PP analysis
  require_metformin   = FALSE,           # logical
  coverage_months     = 12L,             # 6 or 12
  followup_start      = "after_grace",   # "after_grace" (index+90d) or "index_date"
  extra_followup_days = 0L,              # 0 in main analysis; >N to require additional followup beyond 90 days
  max_baseline_age    = Inf              # numeric; Inf disables the cap
)

.override <- function(base, ...) modifyList(base, list(...))

SENSITIVITY_SCENARIOS <- list(
  sens1_ebal = .override(.main,
    label = "Entropy balancing weights instead of IPTW",
    start_step = 17L,                    # 16-compute-iptw
    weight_method = "ebal"),

  sens2_trim = .override(.main,
    label = "2.5% asymmetric trimming of IPTW weights",
    start_step = 17L,                    # 16-compute-iptw
    weight_trimming = TRUE,
    trimming_pct = 0.025),

  sens4_pp_ipcw = .override(.main,
    label = "Per-protocol with IPCW in addition to IPTW",
    start_step = 15L,                    # 15a-compute-ipcw
    use_ipcw = TRUE),

  sens5_metformin = .override(.main,
    label = "Restrict to patients with prior metformin use at baseline",
    start_step = 14L,                    # 14-clean-data
    require_metformin = TRUE),

  sens6_6mo_coverage = .override(.main,
    label = "Require 6 months (instead of 12) of continuous insurance coverage",
    start_step = 5L,                     # 05-extract-coverage-indicator
    coverage_months = 6L),

  sens7_index_followup = .override(.main,
    label = "Start follow-up at index date (include early events)",
    start_step = 14L,                    # 14-clean-data
    followup_start = "index_date"),

  sens8_6mo_followup = .override(.main,
    label = "Require 6 months of follow-up after index, excluding early events",
    start_step = 14L,                    # 14-clean-data
    extra_followup_days = 90L),

  sens9_age_cap = .override(.main,
    label = "Exclude patients aged >85 at baseline",
    start_step = 14L,                    # 14-clean-data
    max_baseline_age = 85)
)

# Called by analysis scripts: returns the scenario named by SCENARIO_NAME env
# var, or the main defaults when SCENARIO_NAME is unset or "main". Errors
# loudly on an unknown name.
get_scenario <- function() {
  nm <- Sys.getenv("SCENARIO_NAME", unset = "main")
  if (!nzchar(nm) || identical(nm, "main")) return(.main)
  if (!nm %in% names(SENSITIVITY_SCENARIOS)) {
    stop(sprintf("SCENARIO_NAME='%s' is not a known scenario. Valid: main, %s",
                 nm, paste(names(SENSITIVITY_SCENARIOS), collapse = ", ")),
         call. = FALSE)
  }
  SENSITIVITY_SCENARIOS[[nm]]
}
