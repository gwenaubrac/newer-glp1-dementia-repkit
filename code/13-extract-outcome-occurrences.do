include "_globals.do"


* ============================================================================
* Identify dementia outcome in follow-up
* ============================================================================

* We will now identify occurrence of the outcome (and negative control outcomes) over the study period.

local end_date = date("$STUDY_END", "YMD")
cd "$OUTPUT_DIR"

***all-cause dementia
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'F01%' OR code LIKE 'F02%' OR code LIKE 'F03%' OR code LIKE 'G30%' OR code LIKE 'F1027%' OR code LIKE 'F1097%' OR code LIKE 'G310%' OR code LIKE 'G3183%');") dsn("$SNOWFLAKE_DSN")

merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1  // Keep first occurrence only
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_dementia_allcause_date
tempfile dementia_outcomes
save `dementia_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `dementia_outcomes', keep(master match) nogen

gen outcome_dementia_allcause = (outcome_dementia_allcause_date <= `end_date') if !missing(outcome_dementia_allcause_date)
replace outcome_dementia_allcause = 0 if missing(outcome_dementia_allcause_date)
save covs_novel, replace


* appendicitis
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'K35%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1 
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_appendicitis_date
tempfile appendix_outcomes
save `appendix_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `appendix_outcomes', keep(master match) nogen

gen outcome_appendicitis = (outcome_appendicitis_date <= `end_date') if !missing(outcome_appendicitis_date)
replace outcome_appendicitis = 0 if missing(outcome_appendicitis_date)
save covs_novel, replace


* traumatic tooth fracture
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'S025%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1 
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_tooth_date
tempfile tooth_outcomes
save `tooth_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `tooth_outcomes', keep(master match) nogen

gen outcome_tooth = (outcome_tooth_date <= `end_date') if !missing(outcome_tooth_date)
replace outcome_tooth = 0 if missing(outcome_tooth_date)
save covs_novel, replace


* bell's palsy
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'G510%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_bell_date
tempfile bell_outcomes
save `bell_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `bell_outcomes', keep(master match) nogen

gen outcome_bell = (outcome_bell_date <= `end_date') if !missing(outcome_bell_date)
replace outcome_bell = 0 if missing(outcome_bell_date)
save covs_novel, replace


* basal cell carcinoma
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'C4411%' OR code LIKE 'C4401%' OR code LIKE 'C4421%' OR code LIKE 'C4431%' OR code LIKE 'C4441%' OR code LIKE 'C4451%' OR code LIKE 'C4461%' OR code LIKE 'C4471%' OR code LIKE 'C4481%' OR code LIKE 'C4491%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_basal_date
tempfile basal_outcomes
save `basal_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `basal_outcomes', keep(master match) nogen

gen outcome_basal = (outcome_basal_date <= `end_date') if !missing(outcome_basal_date)
replace outcome_basal = 0 if missing(outcome_basal_date)
save covs_novel, replace


* ============================================================================
* Table with crude outcome rates
* ============================================================================

log using "crude_outcomes_novel.txt", text replace

clear 
use covs_novel, clear
tab outcome_dementia_allcause
tab outcome_appendicitis
tab outcome_tooth
tab outcome_bell
tab outcome_basal

clear 
use covs_novel, clear
tab index_class outcome_dementia_allcause, row
tab index_class outcome_appendicitis, row
tab index_class outcome_tooth, row
tab index_class outcome_bell, row
tab index_class outcome_basal, row

log close