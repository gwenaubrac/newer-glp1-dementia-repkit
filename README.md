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
2. Prompt you once for your **Snowflake DSN** (the name configured in your Windows ODBC Data Source Administrator). You do not need to put quotations around it. 
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

The runner executes the 21 scripts in `code/` in order. Intermediate files go to `output/`, final results to `results/`, manuscript-ready figures/tables to `manuscript/figures/` and `manuscript/tables/`, per-step logs to `logs/<YYYYMMDD>/`.

If you want to run a specific program directly in Rstudio, just source 00-setup.R first to load the environment.

> **Note on the manuscript folder.** Figures are saved as PDF + TIFF in `manuscript/figures/` and tables as `.xlsx` in `manuscript/tables/`. Items marked *authors* were added by hand and are not produced by the pipeline.
>
> | Item | File | Written by |
> |---|---|---|
> | Figure 1: flowchart | `figure-1-flowchart` | `19-create-plots` |
> | Figure 2: forest plot | `figure-2-forest-plot` | `19-create-plots` |
> | Figure 3: KM curves | `figure-3-km-curves` | `19-create-plots` |
> | Table 1: patient characteristics | `table-1-patient-char.xlsx` | `17-describe-study-sample` |
> | Table 2: results | `table-2-results.xlsx` | `18-run-survival-analyses` |
> | e-Figure 1: propensity score distribution before/after overlap weighting | `e-figure-1-ps-distribution` | `19-create-plots` |
> | e-Figure 2: Aalen-Johansen curves | `e-figure-2-aj-curves` | `20-competing-events` (`sens10_competing_risk` only) |
> | e-Table 1: target trial emulation | `e-table-1-tte.xlsx` | *authors* |
> | e-Table 2: codes for key variables | `e-table-2-key-variables.xlsx` | *authors* |
> | e-Table 3: medications | `e-table-3-medications.xlsx` | *authors* |
> | e-Table 4: analytic weights | `e-table-4-weights.csv` | `17-describe-study-sample` |
> | e-Table 5: Schoenfeld residual tests | `e-table-5-ph-test.xlsx` | `18-run-survival-analyses` |
> | e-Table 6: negative control outcomes | `e-table-6-nco.xlsx` | `18-run-survival-analyses` |
> | e-Table 7: switching and discontinuation within the first year | not yet written to `manuscript/` (see `results/main/switch_first_year_*.csv`, `disc_first_year_*.csv`) | `15b-describe-ipcw` |
> | e-Table 8: competing-risk (Aalen-Johansen) results | `e-table-8-competing-risk.xlsx` | `20-competing-events` (`sens10_competing_risk` only) |

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
Rscript run_sensitivity.R --scenario sens3_trim    # one scenario (that you specify)
Rscript run_sensitivity.R --all                    # every sensitivity analysis, sequentially
Rscript run_sensitivity.R --list                   # show scenario names + labels
Rscript run_sensitivity.R --help
```

Per-scenario results land in `results/<scenario_name>/` (main's live in `results/main/`). After all scenarios complete, the driver automatically re-runs step 18 on the main scenario to refresh `manuscript/tables/table-2-results.xlsx` with the new sensitivity rows.

**How the isolation works.** Each scenario has its own intermediate-file folder at `output_sensitivity/<scenario_name>/`. Analysis scripts try the scenario folder first when reading any upstream file and fall back to main's `output/` if the file isn't there, so scenarios reuse main's intermediates without copying them up front and without overwriting main's `output/` when they recompute. Per-scenario results (`all_cox_results_novel.rds`, balance plots, patient-characteristics tables, etc.) all land in `results/<scenario_name>/`, fully isolated from `results/main/`. Manuscript figures and tables in `manuscript/figures/` and `manuscript/tables/` are only written on the main run, so sensitivity scenarios never overwrite them.

| Scenario | Description | First step that reruns |
|---|---|---|
| `sens1_iptw` | Inverse probability of treatment weighting (IPTW) instead of overlap weights | `16-compute-ow` |
| `sens2_ebal` | Entropy balancing weights instead of overlap weights | `16-compute-ow` |
| `sens3_trim` | 2.5% asymmetric trimming of IPTW weights | `16-compute-ow` |
| `sens4_pp_ipcw` | Per-protocol with IPCW in addition to overlap weights | `15a-compute-ipcw` |
| `sens5_metformin` | Restrict to patients with prior metformin use at baseline | `14-clean-data` |
| `sens6_6mo_coverage` | Require 6 months (instead of 12) of continuous insurance coverage | `05-extract-coverage-indicator` |
| `sens7_index_followup` | Start follow-up at index date (include early events) | `14-clean-data` |
| `sens8_6mo_followup` | Require 6 months of follow-up after index, excluding early events | `14-clean-data` |
| `sens9_age_cap` | Exclude patients aged >85 at baseline | `14-clean-data` |
| `sens10_competing_risk` | Death as a competing event: overlap-weighted Aalen-Johansen cumulative incidence of dementia and death, 2-year risks, risk difference and risk ratio with bootstrap CIs (primary ITT analysis only); reported in e-table 8 and e-figure 2 rather than Table 2 | `20-competing-events` |

To add a new scenario, append an entry to `SENSITIVITY_SCENARIOS` in `sensitivity.R` overriding only the relevant fields of `.main`. The analysis scripts that read scenario parameters are `05`, `14`, `16`, `17`, `18`, `19`, and `20`. Step `20-competing-events.R` only does work for `sens10_competing_risk` and is skipped on every other run.

## Study design

- **Design**: multiple head-to-head emulated trials, active-comparator new-user design
- **Data source**: Komodo Healthcare Map, May 2022 - December 2025 (proprietary; license required from Komodo Health)
- **Population**: adults aged ≥60 with type 2 diabetes and BMI ≥25
- **Comparisons**: GLP-1 agonists (tirzepatide + semaglutide) vs. SGLT-2 inhibitors, DPP-4 inhibitors, and sulfonylureas
- **Outcomes**: primary - incident all-cause dementia; negative controls - basal cell carcinoma, traumatic tooth fracture, Bell's palsy, herpes zoster, transport accident, chronic lower respiratory diseases, hearing loss, and lens disorders.

## Contact

[gaubrac@bu.edu](mailto:gaubrac@bu.edu)
