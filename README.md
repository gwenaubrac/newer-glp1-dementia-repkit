# GLP-1 Agonists and Risk of Incident Dementia: Reproducibility Kit

A reproducibility kit for a pharmacoepidemiology study comparing the risk of incident all-cause dementia among new users of GLP-1 receptor agonists (semaglutide or tirzepatide) versus active comparators (SGLT2 inhibitors, DPP-4 inhibitors, and sulfonylureas) in older adults with type 2 diabetes and overweight or obesity.

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

Open 0-r-setup.R and follow the instructions. This installs all R packages at the versions used for the original analysis.
Restart R after editing the file.

### 3. Update folder paths

Several scripts reference local folder paths that must be updated to match your environment before running. You will see a placeholder path for these at the top of each code file.

## Running the Analysis

### Main analysis

1. Run code files **in numerical order** (`1-...`, `2-...`, etc.).
2. Update folder paths at the top of each script as needed.
3. All output is written to a `/novel_res/` folder, which is created automatically when you run the code. A folder called `/output/` is also created to store intermediate files. 

I also recommend clearing objects from the workspace in R before running the next script. 

To change the study period and include more recent data, change the following:
- 3-identify-new-users.qmd: change end in study_period_novel (line 32)
- 5-continuous-coverage.do: change gen study_end (line 70)
- 17-survival-analyses.qmd: change end_date (line 45)

### Sensitivity analyses

> **Recommendation**: For each sensitivity analysis, copy the project folder and run the modified version in the copy. This avoids overwriting results from the main analysis.

The table below summarizes each sensitivity analysis and the change required.

| # | Sensitivity Analysis | File | Change |
|---|---|---|---|
| 1 | Entropy balancing weights instead of IPTW | `17-survival-analyses.qmd` | Lines 235 and 366: change `iptw` → `ebal` and `swfinal` → `ebalfinal` |
| 2 | 2.5% asymmetric trimming of IPTW weights | `15-iptw.qmd` | Enable trimming at lines 66–85, 227–246, and 378–396 |
| 3 | Per-protocol: censor at treatment switch/discontinuation (90-day grace period) | — | No change; runs automatically |
| 4 | Per-protocol with IPCW in addition to IPTW | `17-survival-analyses.qmd` | Line 366: change `siptw` → `swfinal` |
| 5 | Restrict to patients with prior metformin use at baseline | `13-data-prep.qmd` | Lines 194-195: exclude patients without metformin indicator |
| 6 | Require 6 months (instead of 12) of continuous insurance coverage | `5-continuous-coverage.do` | Line 26: change continuous-coverage requirement |
| 7 | Start follow-up at index date (include early events) | `17-survival-analyses.qmd` | Line 147: change follow-up start to index date |
| 8 | Require 6 months of follow-up after index, excluding early events | `17-survival-analyses.qmd` | Lines 170 and 304: require an additional 90 days of follow-up |
| 9 | Exclude patients aged >85 at baseline | `13-data-prep.qmd` | Line 198: exclude patients with baseline age >85 |

## Repository Structure

```
.
├── README.md
├── LICENSE
├── .gitignore
└── code/
    ├── renv/                          # renv project library
    ├── renv.lock                      # pinned R package versions
    ├── 0-r-setup.R                    # R environment setup
    │
    │   # Cohort identification
    ├── 1-identify-index-medications.qmd
    ├── 2-extract-dispensings.qmd
    ├── 3-identify-new-users.qmd
    │
    │   # Eligibility & follow-up
    ├── 4-get-censoring-dates.do
    ├── 5-continuous-coverage.do
    ├── 6a-apply-eligibility-criteria.do
    ├── 6b-eligibility-flowchart.R
    │
    │   # Covariate construction
    ├── 7-demographic-covs.do
    ├── 8-comorbidity-covs.do
    ├── 9-medication-covs.do
    ├── 10-provider-zip-cov.do
    ├── 11-merge-covs.do
    ├── 12-outcomes.do
    │
    │   # Analysis
    ├── 13-data-prep.qmd
    ├── 14-ipcw.qmd
    ├── 15-iptw.qmd
    ├── 16-describe-sample.qmd
    ├── 17-survival-analyses.qmd
    ├── 18-save-plots.qmd
    │
    └── acs_zip3_edu_inc.csv           # ACS ZIP3-level education/income data used for 7-demographic-covs.do
```

## Contact

For questions about this project, please contact:

**[gaubrac@bu.edu](mailto:gaubrac@bu.edu)**