* ============================================================================
* Path configuration — source config.sh before running this script
* ============================================================================
global PROJECT_ROOT : environment PROJECT_ROOT
global OUTPUT_DIR   : environment OUTPUT_DIR
global RESULTS_DIR  : environment RESULTS_DIR

capture confirm string macro $PROJECT_ROOT
if _rc {
    display as error "ERROR: PROJECT_ROOT is not set. Run: source config.sh"
    exit 1
}

* ============================================================================
* Merge covariate into
* ============================================================================

* We are now combining all of the covariate data from previous steps to add it to the final cohort dataframe. 

clear
cd "$OUTPUT_DIR"
use final_novel, clear

count
codebook PATIENT_ID

merge 1:1 PATIENT_ID using cov_plan_novel, keep(1 3) nogen
merge 1:1 PATIENT_ID using cov_zip_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using cov_race_novel, keep (1 3) nogen

local covariates "dyslipid1 dyslipid2 dyslipid3 dyslipid4 dyslipid5 hyper1 hyper2 hyper3 hyper4 hyper5 hyper6 hyper7 hosp emerg statin betablocker arb thiazide ccb aceinhibitor metformin insulin alcohol cancer cvd ckd revas ampu retino diab_neuro hypoglyc eskd hf hepa ihd nafld pace pvd vhd edema copd apnea thyroid depression anxiety"

foreach cov of local covariates {
    merge 1:1 PATIENT_ID using cov_`cov'_novel, keep(1 3) nogen
}

save covs_novel, replace

* to free up disc spaces, you can now delete intermediate steps
* clean all cov files
erase cov_zip_novel.dta
erase cov_plan_novel.dta
erase cov_race_novel.dta

* make sure you run the following lines together
local covariates "dyslipid1 dyslipid2 dyslipid3 dyslipid4 dyslipid5 hyper1 hyper2 hyper3 hyper4 hyper5 hyper6 hyper7 hosp emerg statin betablocker arb thiazide ccb aceinhibitor metformin insulin alcohol cancer cvd ckd revas ampu retino diab_neuro hypoglyc eskd hf hepa ihd nafld pace pvd vhd edema copd apnea thyroid depression anxiety"

foreach cov of local covariates {
    erase cov_`cov'_novel.dta
}