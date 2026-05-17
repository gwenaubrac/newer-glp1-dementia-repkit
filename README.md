# GLP-1 Agonists and Risk of Incident Dementia: Reproducibility Kit

A reproducibility kit for a pharmacoepidemiology study comparing the risk of incident all-cause dementia among new users of GLP-1 receptor agonists (semaglutide or tirzepatide) versus active comparators (SGLT2 inhibitors, DPP-4 inhibitors, and sulfonylureas) in older adults with type 2 diabetes and overweight or obesity.

## Quick start

Once R, Quarto, and Stata are installed (see [Software Requirements](#software-requirements)) and the R environment has been restored via `code/00-setup.R`:

1. **Edit `config.R`** at the project root — set `PROJECT_ROOT` to your local clone path. Adjust `STATA_BIN` if your Stata edition differs from the default.
2. **Run the pipeline:**
   - **macOS**: double-click `run_all.command` in Finder (or in Terminal: `./run_all.command`)
   - **Windows**: double-click `run_all.bat` in Explorer (or in any terminal: `run_all.bat`)
   - **Any platform / terminal**: `Rscript run_all.R`

The runner sources `config.R`, validates paths and binaries, then executes the 20 numbered scripts in `code/` in order. Per-step logs are written to `logs/<timestamp>/`. Useful flags: `--list`, `--dry-run`, `--from N`, `--only N`, `--help`.

To run directly from terminal, I did:
cd my/repo/path
"C:/Program Files/R/R-4.4.2/bin/x64/Rscript.exe" run_all.R

To resume from a step:
"C:/Program Files/R/R-4.4.2/bin/x64/Rscript.exe" run_all.R --dry-run
"C:/Program Files/R/R-4.4.2/bin/x64/Rscript.exe" run_all.R --from N where N is the step number (program number)

## Study Design

- **Design**: Multiple head-to-head emulated trials using an active-comparator, new-user design
- **Data Source**: Komodo Healthcare Map (May 2022 – December 2025)
- **Population**: Adults aged ≥60 with type 2 diabetes and BMI ≥25
- **Comparisons**:
  - GLP-1 agonists (tirzepatide + semaglutide) vs. SGLT2 inhibitors
  - GLP-1 agonists (tirzepatide + semaglutide) vs. DPP-4 inhibitors
  - GLP-1 agonists (tirzepatide + semaglutide) vs. sulfonylureas
- **Outcomes**:
  - Primary: incident all-cause dementia
  - Negative controls: appendicitis, basal cell carcinoma, traumatic tooth fracture, Bell's palsy

## Software Requirements

| Software | Version |
|---|---|
| R | 4.4.2 (2024-10-31 ucrt, "Pile of Leaves") |
| Stata | StataNow 18.5 MP-Parallel Edition |

R package versions are pinned in `renv.lock` and can be restored with `renv::restore()` (see Setup below).

## Data Access

This study uses the **Komodo Healthcare Map**, accessed via Snowflake. These data are proprietary and must be licensed directly from Komodo Health; they are not included in this repository. Users with their own license can configure access by editing the `.Renviron` file (see Setup).

## Repository Setup

### 1. Clone the repository

```bash
git clone <repo-url>
cd <repo-name>
```

### 2. Restore the R environment and configure data access

Open `00-setup.R` and follow the instructions. This installs all R packages at the versions used for the original analysis, and creates a `.Renviron` file with your DSN and local paths. Restart R after running the file.

### 3. Configure paths

**Shell / Quarto users**: open `config.sh` at the project root, set `PROJECT_ROOT` to the absolute path of your local clone, and source it before running any script:

```bash
source config.sh
```

**RStudio / interactive R users**: the `.Renviron` created by `00-setup.R` already contains `PROJECT_ROOT`, `OUTPUT_DIR`, and `RESULTS_DIR` — just fill in your paths there. The `.Renviron` file is git-ignored so your local paths are never committed.

## Running the Analysis

### Main analysis

1. Run code files **in numerical order** (`01-...`, `02-...`, etc.).
2. Paths are read from environment variables — no per-script edits needed after configuring `config.sh`.
3. All output is written to a `results/` folder, which is created automatically. A folder called `output/` is also created to store intermediate files.

I also recommend clearing objects from the workspace in R before running the next script.

To change the study period, edit `STUDY_START` and/or `STUDY_END` in `config.R` (or `config.sh` for the bash flow). The three scripts that consume the window — `03-identify-new-users.qmd`, `05-extract-coverage-indicator.do`, and `18-run-survival-analyses.qmd` — read those values from the environment, so no per-script edits are needed.

### Sensitivity analyses

Sensitivity analyses are parameterized — no script edits needed. Pick a scenario, run the driver, results land in `<RESULTS_DIR>/<scenario_name>/`:

```bash
Rscript run_sensitivity.R --scenario sens2_trim    # one scenario
Rscript run_sensitivity.R --all                    # main + all 9 sensitivities, sequentially
Rscript run_sensitivity.R --list                   # show scenario names + labels
Rscript run_sensitivity.R --help
```

`run_sensitivity.R` reads scenario definitions from `sensitivity.R`, sets the appropriate environment variables (`SCENARIO_NAME`, `COVERAGE_MONTHS`, `RESULTS_DIR`), then invokes `run_all.R` as a subprocess. Per-scenario stdout/stderr is captured to `logs/sensitivity_<timestamp>/<scenario_name>.log`.

Each `--all` run executes scenarios sequentially. If one fails, the driver records it and continues with the next; the final summary lists pass/fail per scenario. Scenarios cannot be parallelized because of Stata licensing and intermediate-file contention in `output/`.

| Scenario name | Description |
|---|---|
| `main` | Main analysis (default settings) |
| `sens1_ebal` | Entropy balancing weights instead of IPTW |
| `sens2_trim` | 2.5% asymmetric trimming of IPTW weights |
| `sens3_pp` | Per-protocol: censor at switch/discontinuation (90-day grace period) — runs identically to `main` (the PP analysis is already part of the default pipeline) |
| `sens4_pp_ipcw` | Per-protocol with IPCW in addition to IPTW |
| `sens5_metformin` | Restrict to patients with prior metformin use at baseline |
| `sens6_6mo_coverage` | Require 6 months (instead of 12) of continuous insurance coverage |
| `sens7_index_followup` | Start follow-up at index date (include early events) |
| `sens8_6mo_followup` | Require 6 months of follow-up after index, excluding early events |
| `sens9_age_cap` | Exclude patients aged >85 at baseline |

Scenarios are defined in `sensitivity.R`. To add a new one, append an entry to `SENSITIVITY_SCENARIOS` that overrides only the relevant fields of `.main`.

## Repository Structure

```
.
├── README.md
├── config.R                               # edit once: paths + binaries (read by run_all.R)
├── config.sh                              # edit once: shell version of config.R
├── run_all.R                              # master pipeline runner (base R)
├── run_all.command                        # macOS double-click wrapper
├── run_all.bat                            # Windows double-click wrapper
├── .Renviron                              # created by 00-setup.R; git-ignored
├── LICENSE
├── .gitignore
└── code/
    ├── renv/                              # renv project library
    ├── renv.lock                          # pinned R package versions
    ├── 00-setup.R                         # R environment setup (run once)
    │
    │   # Cohort identification
    ├── 01-extract-drug-codes.qmd
    ├── 02-extract-dispensings.qmd
    ├── 03-identify-new-users.qmd
    │
    │   # Follow-up & eligibility
    ├── 04-extract-censoring-dates.do
    ├── 05-extract-coverage-indicator.do
    ├── 06-apply-eligibility-criteria.do
    ├── 07-describe-eligibility-flowchart.R
    │
    │   # Covariate construction
    ├── 08-extract-demographic-covs.do
    ├── 09-extract-comorbidity-covs.do
    ├── 10-extract-medication-covs.do
    ├── 11-extract-provider-zip-cov.do
    ├── 12-merge-covs.do
    ├── 13-extract-outcome-occurrences.do
    │
    │   # Analysis
    ├── 14-clean-data.qmd
    ├── 15a-compute-ipcw.qmd
    ├── 15b-describe-ipcw.R
    ├── 16-compute-iptw.qmd
    ├── 17-describe-sample.qmd
    ├── 18-run-survival-analyses.qmd
    ├── 19-save-plots.qmd
    │
    └── acs_zip3_edu_inc.csv               # ACS ZIP3-level education/income data
```

## Contact

For questions about this project, please contact:

**[gaubrac@bu.edu](mailto:gaubrac@bu.edu)**
