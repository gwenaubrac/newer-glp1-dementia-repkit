include "_globals.do"

* ============================================================================
* Identify dementia outcome in follow-up
* ============================================================================

* We will now identify occurrence of the outcome (and control outcomes) over the study period.

local end_date = date("$STUDY_END", "YMD")
cd "$OUTPUT_DIR"

* Memory-safe extraction for outcomes defined by very common codes (e.g., GI
* symptoms, COPD/asthma), where pulling all codes at once exhausts memory.
* Pulls one code prefix at a time, only claims after the study start (index
* dates are >= study start), without the code column, and merges only
* index_date from the cohort. Each chunk is immediately reduced to the first
* post-index date per patient, so memory stays bounded.
capture program drop get_first_outcome
program define get_first_outcome
    syntax, name(string) codes(string)

    local end_date = date("$STUDY_END", "YMD")
    tempfile results
    local any = 0

    foreach c of local codes {
        display as text "`name': pulling codes LIKE '`c'%'"
        clear
        odbc load, exec(`"SELECT DISTINCT PATIENT_ID, CLAIM_DATE FROM (SELECT PATIENT_ID, CLAIM_DATE, D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST WHERE CLAIM_DATE > '$STUDY_START') UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26)) WHERE code LIKE '`c'%';"') dsn("$SNOWFLAKE_DSN")
        if _N == 0 continue

        merge m:1 PATIENT_ID using covs_novel, keep(match) nogen keepusing(index_date)
        keep if CLAIM_DATE > index_date
        drop index_date
        if `any' append using `results'
        collapse (min) CLAIM_DATE, by(PATIENT_ID)
        save `results', replace
        local any = 1
    }

    use covs_novel, clear
    if `any' {
        merge 1:1 PATIENT_ID using `results', keep(master match) nogen
        rename CLAIM_DATE outcome_`name'_date
    }
    else {
        gen outcome_`name'_date = .
    }
    format outcome_`name'_date %td

    gen outcome_`name' = (outcome_`name'_date <= `end_date') if !missing(outcome_`name'_date)
    replace outcome_`name' = 0 if missing(outcome_`name'_date)
    save covs_novel, replace
end

***all-cause dementia
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'F01%' OR code LIKE 'F02%' OR code LIKE 'F03%' OR code LIKE 'G30%' OR code LIKE 'F1027%' OR code LIKE 'F1097%' OR code LIKE 'G310%' OR code LIKE 'G3183%');") dsn("$SNOWFLAKE_DSN")

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


* traumatic tooth fracture
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'S025%');") dsn("$SNOWFLAKE_DSN")
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
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'G510%');") dsn("$SNOWFLAKE_DSN")
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
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'C4411%' OR code LIKE 'C4401%' OR code LIKE 'C4421%' OR code LIKE 'C4431%' OR code LIKE 'C4441%' OR code LIKE 'C4451%' OR code LIKE 'C4461%' OR code LIKE 'C4471%' OR code LIKE 'C4481%' OR code LIKE 'C4491%');") dsn("$SNOWFLAKE_DSN")
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

* herpes zoster
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'B020%' OR code LIKE 'B021%' OR code LIKE 'B022%' OR code LIKE 'B023%' OR code LIKE 'B027%' OR code LIKE 'B028%' OR code LIKE 'B029%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_herpes_date
tempfile herpes_outcomes
save `herpes_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `herpes_outcomes', keep(master match) nogen

gen outcome_herpes = (outcome_herpes_date <= `end_date') if !missing(outcome_herpes_date)
replace outcome_herpes = 0 if missing(outcome_herpes_date)
save covs_novel, replace

* transport accident (inpatient admissions and emergency department visits)
*
* Captured from two sources, then combined by taking the earliest qualifying
* event per patient:
*   1. Inpatient - transport-accident diagnosis on a hospital claim
*      (ADMISSION_DATE not null) in MEDICAL_HEADERS_LATEST, dated by admission.
*   2. Emergency department - transport-accident diagnosis on an ED service
*      line in MEDICAL_SERVICE_LINES_LATEST, dated by SERVICE_FROM.
*
* The ICD-10 predicate (V00-V99) is built once into the vlike local below and
* reused by both queries so the two definitions cannot drift apart.
local vlike ""
forvalues i = 0/99 {
    local v = string(`i', "%02.0f")
    local vlike `"`vlike' OR code LIKE 'V`v'%'"'
}
* strip the leading " OR " left by the first pass
local vlike = substr(`"`vlike'"', 5, .)

* --- source 1: inpatient admissions ---
clear
odbc load, exec(`"SELECT DISTINCT PATIENT_ID, ADMISSION_DATE, code FROM (SELECT PATIENT_ID, ADMISSION_DATE, D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST WHERE ADMISSION_DATE IS NOT NULL) UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26)) WHERE (`vlike');"') dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if ADMISSION_DATE > index_date
rename ADMISSION_DATE event_date
gen byte transport_source = 1
keep PATIENT_ID event_date transport_source
tempfile transport_ip
save `transport_ip', replace

* --- source 2: emergency department visits ---
* ED service line, any of:
*   POS 23 = emergency room, hospital
*   payer-supplied emergency indicator
*   revenue codes 045x (ER) or 0981 (ER professional fees),
*     listed with and without the leading zero
*   CPT 99281-99285 = ED evaluation & management visits
clear
odbc load, exec(`"SELECT DISTINCT PATIENT_ID, SERVICE_FROM, code FROM (SELECT PATIENT_ID, SERVICE_FROM, DIAGNOSIS_CODE_1, DIAGNOSIS_CODE_2, DIAGNOSIS_CODE_3, DIAGNOSIS_CODE_4 FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_SERVICE_LINES_LATEST WHERE (PLACE_OF_SERVICE = '23' OR EMERGENCY_INDICATOR = 'Y' OR REVENUE_CODE IN ('0450','0451','0452','0456','0459','0981','450','451','452','456','459','981') OR PROCEDURE IN ('99281','99282','99283','99284','99285'))) UNPIVOT (code FOR col IN (DIAGNOSIS_CODE_1, DIAGNOSIS_CODE_2, DIAGNOSIS_CODE_3, DIAGNOSIS_CODE_4)) WHERE (`vlike');"') dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if SERVICE_FROM > index_date
rename SERVICE_FROM event_date
gen byte transport_source = 2
keep PATIENT_ID event_date transport_source

* --- combine: earliest qualifying event per patient ---
append using `transport_ip'
label define transport_src 1 "Inpatient" 2 "Emergency department"
label values transport_source transport_src
tab transport_source

sort PATIENT_ID event_date transport_source
by PATIENT_ID: keep if _n == 1
keep PATIENT_ID event_date
rename event_date outcome_transport_date
tempfile transport_outcomes
save `transport_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `transport_outcomes', keep(master match) nogen

gen outcome_transport = (outcome_transport_date <= `end_date') if !missing(outcome_transport_date)
replace outcome_transport = 0 if missing(outcome_transport_date)
save covs_novel, replace

* chronic lower respiratory diseases
get_first_outcome, name(resp) codes("J40 J41 J42 J43 J44 J45 J47")

* hearing loss
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'H90%' OR code LIKE 'H91%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_hearing_date
tempfile hearing_outcomes
save `hearing_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `hearing_outcomes', keep(master match) nogen

gen outcome_hearing = (outcome_hearing_date <= `end_date') if !missing(outcome_hearing_date)
replace outcome_hearing = 0 if missing(outcome_hearing_date)
save covs_novel, replace

* lens disorders
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'H25%' OR code LIKE 'H26%' OR code LIKE 'H27%' OR code LIKE 'H28%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using covs_novel, keep(match) nogen
keep if CLAIM_DATE > index_date
sort PATIENT_ID CLAIM_DATE

by PATIENT_ID: keep if _n == 1
keep PATIENT_ID CLAIM_DATE
rename CLAIM_DATE outcome_lens_date
tempfile lens_outcomes
save `lens_outcomes', replace
use covs_novel, clear
merge 1:1 PATIENT_ID using `lens_outcomes', keep(master match) nogen

gen outcome_lens = (outcome_lens_date <= `end_date') if !missing(outcome_lens_date)
replace outcome_lens = 0 if missing(outcome_lens_date)
save covs_novel, replace

* gastrointestinal events (positive control outcome)
get_first_outcome, name(gastro) codes("R11 R12 R14 K590 K30 K3184 K21 K85 K861 K197 K5289 K529")

* ============================================================================
* Table with crude outcome rates
* ============================================================================

log using "crude_outcomes_novel.txt", text replace

clear 
use covs_novel, clear
tab outcome_dementia_allcause
tab outcome_tooth
tab outcome_bell
tab outcome_basal
tab outcome_herpes
tab outcome_transport
tab outcome_resp
tab outcome_hearing
tab outcome_lens
tab outcome_gastro

clear 
use covs_novel, clear
tab index_class outcome_dementia_allcause, row
tab index_class outcome_tooth, row
tab index_class outcome_bell, row
tab index_class outcome_basal, row
tab index_class outcome_herpes, row
tab index_class outcome_transport, row
tab index_class outcome_resp, row
tab index_class outcome_hearing, row
tab index_class outcome_lens, row
tab index_class outcome_gastro, row

log close