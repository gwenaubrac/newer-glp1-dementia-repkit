# GLP-1 Agonists and Risk of Incident Dementia: Reproducibility Kit

A pharmacoepidemiology study comparing the risk of incident all-cause dementia among new users of GLP-1 receptor agonists (semaglutide or tirzepatide) versus active comparators (SGLT-2 inhibitors, DPP-4 inhibitors, sulfonylureas) in older adults with type 2 diabetes and overweight/obesity.

## How to run

### 1. Install the software

| Software | Version used |
|---|---|
| R | 4.4.2 |
| Quarto | any recent release |
| Stata | StataNow 18.5 MP |

R, Quarto, and Stata must each be on your system `PATH`, or you can point at them explicitly in `config.R` (see section 2 and 3 of that file).

### 2. Clone the repo and run setup once

```bash
git clone <repo-url>
cd <repo-name>
```

Then open `code/00-setup.R` in RStudio and click **Source**. It will:

1. Restore the pinned R package environment (`renv::restore`).
2. Prompt you once for your **Snowflake DSN** (the name configured in your Windows ODBC Data Source Administrator).
3. Write a `.Renviron` at the project root with your DSN and the project paths.

### 3. Run the pipeline

Do one of the following (whichever is easiest):

- **macOS**: double-click `run_all.command`
- **Windows**: double-click `run_all.bat`
- **Any terminal**: `Rscript run_all.R` after navigating to the repkit folder. You may need to specify where Rscript.exe is located (see below).

To run directly from terminal, I did:

```bash
cd Desktop/newer-glp1-dementia-repkit
"C:/Program Files/R/R-4.4.2/bin/x64/Rscript.exe" run_all.R
```

The runner executes the 20 scripts in `code/` in order. Intermediate files go to `output/`, final results to `results/`, manuscript-ready figures/tables to `manuscript/figures/` and `manuscript/tables/`, per-step logs to `logs/<YYYYMMDD>/`.

> **Note on the manuscript folder.** The pipeline auto-populates `manuscript/figures/` with `figure-1-flowchart`, `figure-2-forest-plot`, and `figure-3-km-curves` (each as PDF + TIFF), and `manuscript/tables/` with `table-1-patient-char.csv`, `table-2-results.csv`, and `e-table-4-nco.csv`. Any other tables or figures that appear in the manuscript folder (e.g., e-tables 1-3, table 3) were added by the authors directly and are not produced by the pipeline.

**Useful flags** (pass to `Rscript run_all.R …` or the wrapper):

| Flag | What it does |
|---|---|
| `--list` | print the pipeline steps and exit |
| `--dry-run` | resolve config and check binaries; does not run anything |
| `--from N` | start at step N and continue to the end |
| `--only N` | run only step N |
| `--only-file <basename>` | run only the step whose script is named `<basename>` |
| `--help` | full help text |

To change the study window, edit `STUDY_START` / `STUDY_END` in `config.R`. To change the R/Quarto/Stata binary or override the auto-detected Stata edition, edit the matching section of `config.R`. Nothing else in `config.R` should need changes.

## Sensitivity analyses

Run after the main analysis has completed. Each scenario reuses the main run's intermediate files and only re-executes from the first step that its parameter affects.

```bash
Rscript run_sensitivity.R --scenario sens2_trim    # one scenario (that you specify)
Rscript run_sensitivity.R --all                    # every sensitivity analysis, sequentially
Rscript run_sensitivity.R --list                   # show scenario names + labels
Rscript run_sensitivity.R --help
```

Per-scenario results land in `results/<scenario_name>/` (main's live in `results/main/`). After all scenarios complete, the driver automatically re-runs step 18 on the main scenario to refresh `manuscript/tables/table-2-results.csv` with the new sensitivity rows.

**How the isolation works.** Each scenario has its own intermediate-file folder at `output_sensitivity/<scenario_name>/`. Analysis scripts try the scenario folder first when reading any upstream file and fall back to main's `output/` if the file isn't there, so scenarios reuse main's intermediates without copying them up front and without overwriting main's `output/` when they recompute. Per-scenario results (`all_cox_results_novel.rds`, balance plots, patient-characteristics tables, etc.) all land in `results/<scenario_name>/`, fully isolated from `results/main/`. Manuscript figures and tables in `manuscript/figures/` and `manuscript/tables/` are only written on the main run, so sensitivity scenarios never overwrite them.

| Scenario | Description | First step that reruns |
|---|---|---|
| `sens1_ebal` | Entropy balancing weights instead of IPTW | `16-compute-iptw` |
| `sens2_trim` | 2.5% asymmetric trimming of IPTW weights | `16-compute-iptw` |
| `sens4_pp_ipcw` | Per-protocol with IPCW in addition to IPTW | `15a-compute-ipcw` |
| `sens5_metformin` | Restrict to patients with prior metformin use at baseline | `14-clean-data` |
| `sens6_6mo_coverage` | Require 6 months (instead of 12) of continuous insurance coverage | `05-extract-coverage-indicator` |
| `sens7_index_followup` | Start follow-up at index date (include early events) | `14-clean-data` |
| `sens8_6mo_followup` | Require 6 months of follow-up after index, excluding early events | `14-clean-data` |
| `sens9_age_cap` | Exclude patients aged >85 at baseline | `14-clean-data` |

To add a new scenario, append an entry to `SENSITIVITY_SCENARIOS` in `sensitivity.R` overriding only the relevant fields of `.main`. The four analysis scripts that read scenario parameters are `05`, `14`, `16`, and `18`.

## Study design

- **Design**: multiple head-to-head emulated trials, active-comparator new-user design
- **Data source**: Komodo Healthcare Map, May 2022 - December 2025 (proprietary; license required from Komodo Health)
- **Population**: adults aged ≥60 with type 2 diabetes and BMI ≥25
- **Comparisons**: GLP-1 agonists (tirzepatide + semaglutide) vs. SGLT-2 inhibitors, DPP-4 inhibitors, and sulfonylureas
- **Outcomes**: primary - incident all-cause dementia; negative controls - appendicitis, basal cell carcinoma, traumatic tooth fracture, Bell's palsy

## Repository structure

```
.
├-- README.md
├-- AGENTS.md
├-- config.R                # binaries + study window (most users edit nothing)
├-- sensitivity.R           # sensitivity scenario definitions
├-- run_all.R               # main pipeline runner
├-- run_sensitivity.R       # sensitivity-scenario driver
├-- run_all.command         # macOS double-click wrapper
├-- run_all.bat             # Windows double-click wrapper
├-- .Renviron               # created by 00-setup.R; git-ignored
├-- docs/                   # supplementary documentation
├-- manuscript/             # pipeline-generated + author-added artefacts
|   ├-- figures/            # auto: figure-1-flowchart, figure-2-forest-plot, figure-3-km-curves (PDF + TIFF)
|   +-- tables/             # auto: table-1-patient-char.csv, table-2-results.csv, e-table-4-nco.csv
|                           # Other files in this folder were added by the authors.
+-- code/
    ├-- 00-setup.R          # run-once R environment + .Renviron setup
    ├-- 01-extract-drug-codes.qmd
    ├-- 02-extract-dispensings.qmd
    ├-- 03-identify-new-users.qmd
    ├-- 04-extract-censoring-dates.do
    ├-- 05-extract-coverage-indicator.do
    ├-- 06-apply-eligibility-criteria.do
    ├-- 07-create-eligibility-flowchart.R
    ├-- 08-extract-demographic-covs.do
    ├-- 09-extract-comorbidity-covs.do
    ├-- 10-extract-medication-covs.do
    ├-- 11-extract-provider-zip-cov.do
    ├-- 12-merge-covariates.do
    ├-- 13-extract-outcome-occurrences.do
    ├-- 14-clean-data.qmd
    ├-- 15a-compute-ipcw.qmd
    ├-- 15b-describe-ipcw.R
    ├-- 16-compute-iptw.qmd
    ├-- 17-describe-study-sample.qmd
    ├-- 18-run-survival-analyses.qmd
    ├-- 19-create-plots.qmd
    ├-- renv/               # renv project library
    ├-- renv.lock           # pinned R package versions
    +-- acs_zip_edu_inc.csv # ACS ZIP-level education/income data
```

## Contact

[gaubrac@bu.edu](mailto:gaubrac@bu.edu)
