* ============================================================================
* Path configuration — globals set by run_all.R via the _run_step.do wrapper
* ============================================================================
if "$PROJECT_ROOT" == "" {
    display as error "ERROR: PROJECT_ROOT is not set. Launch the pipeline via run_all.R."
    exit 1
}

cd "$OUTPUT_DIR"

* getting ZIP of provider for patient where date of service and index date match
*(provider that saw that patient on day they initiated GLP1)
* and then merging with zip-level data

* ============================================================================
* Import ACS ZIP data
* ============================================================================

clear

import delimited "$PROJECT_ROOT/code/acs_zip3_edu_inc.csv"
drop v1

destring prop_hs, replace force
destring prop_sc, replace force
destring prop_b, replace force
destring prop_grad, replace force
destring hh_inc, replace force
destring f_inc, replace force
destring pc_inc, replace force

xtile pop_tot_p = pop_total, nq(100)

bysort pop_tot_p: summarize pop_total
drop if pop_tot_p <=10

xtile prop_hs_d = prop_hs, nq(10)
xtile prop_sc_d = prop_sc, nq(10)
xtile prop_b_d = prop_b, nq(10)
xtile prop_grad_d = prop_grad, nq(10)
xtile hh_inc_d = hh_inc, nq(10)
xtile f_inc_d = f_inc, nq(10)
xtile pc_inc_d = pc_inc, nq(10)

xtile prop_hs_q = prop_hs, nq(5)
xtile prop_sc_q = prop_sc, nq(5)
xtile prop_b_q = prop_b, nq(5)
xtile prop_grad_q = prop_grad, nq(5)
xtile hh_inc_q = hh_inc, nq(5)
xtile f_inc_q = f_inc, nq(5)
xtile pc_inc_q = pc_inc, nq(5)

xtile prop_hs_p = prop_hs, nq(100)
xtile prop_sc_p = prop_sc, nq(100)
xtile prop_b_p = prop_b, nq(100)
xtile prop_grad_p = prop_grad, nq(100)
xtile hh_inc_p = hh_inc, nq(100)
xtile f_inc_p = f_inc, nq(100)
xtile pc_inc_p = pc_inc, nq(100)

save "acs_zip_percentiles.dta", replace


* ============================================================================
* Get provider ZIP
* ============================================================================

clear
use final_novel
rename PRESCRIBER_NPI PROVIDER_ID
save final_novel, replace

clear
odbc load, exec("SELECT PROVIDER_ID, PROVIDER_ZIPCODE FROM PROVIDER_SUMMARIES_LATEST")
merge m:m PROVIDER_ID using final_novel, keep(match) nogen /*match on PROVIDER_ID*/
keep PATIENT_ID PROVIDER_ID PROVIDER_ZIPCODE
rename PROVIDER_ZIPCODE zip
destring zip, replace

merge m:1 zip using "acs_zip_percentiles.dta", keep(master match) nogen
merge m:1 PATIENT_ID using final_novel, keep(2 3) nogen

keep PATIENT_ID prop_hs_q prop_sc_q prop_b_q prop_grad_q hh_inc_q f_inc_q pc_inc_q
count
codebook PATIENT_ID
duplicates drop
duplicates drop PATIENT_ID, force
save cov_zip_novel, replace