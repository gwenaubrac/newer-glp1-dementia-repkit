include "_globals.do"


cd "$OUTPUT_DIR"
clear

* Upstream file produced by step 03 (not re-run by sensitivity scenarios);
* read explicitly from main's output so sens6 works with cwd = scenario.
use "$MAIN_OUTPUT_DIR/index_novel_comparisons.dta", clear
count
local before_merge = r(N)
merge m:1 PATIENT_ID using cov_lookback_novel, keep(match) nogen
gen lookback_date = index_date - 365
count
local after_merge = r(N)
save continuous_novel, replace

* Lines 2 and 3 below are consumed by 19-create-plots.qmd to populate the first
* two boxes of figure-1-flowchart. Keep the "BOX 1" / "BOX 2" labels and the
* "N=<value>" trailing format so the parser stays simple. We use `replace`
* (not `append`) so reruns of the pipeline overwrite cleanly.
file open log using "merge_counts.txt", write replace
file write log "Merge: index_novel_level with cov_lookback_novel" _n
file write log "BOX 1 - Before requiring continuous coverage: N=`before_merge'" _n
file write log "BOX 2 - After requiring continuous coverage: N=`after_merge'" _n
file close log

use continuous_novel, clear
keep PATIENT_ID index_date

* Split dataset into smaller chunks otherwise Stata crashes on merges below
set seed 12345  // for reproducibility
gen split = ceil(runiform() * 4)

forvalues i = 1/4 {
    preserve
    keep if split == `i'
    drop split
    save continuous_novel`i', replace
    restore
}

* ============================================================================
* Diabetes in lookback
* ============================================================================

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'E11%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel1, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= index_date-365
keep PATIENT_ID
gen lookback_diabetes=1
save lookback_diabetes_novel1, replace


clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'E11%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel2, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= index_date-365
keep PATIENT_ID
gen lookback_diabetes=1
save lookback_diabetes_novel2, replace


clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'E11%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel3, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= index_date-365
keep PATIENT_ID
gen lookback_diabetes=1
save lookback_diabetes_novel3, replace


clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'E11%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel4, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= index_date-365
keep PATIENT_ID
gen lookback_diabetes=1
save lookback_diabetes_novel4, replace

clear
use lookback_diabetes_novel1, clear
append using lookback_diabetes_novel2
append using lookback_diabetes_novel3
append using lookback_diabetes_novel4
duplicates drop PATIENT_ID, force
save lookback_diabetes_novel, replace

erase "lookback_diabetes_novel1.dta"
erase "lookback_diabetes_novel2.dta"
erase "lookback_diabetes_novel3.dta"
erase "lookback_diabetes_novel4.dta"

* apply the exclusion
clear
use continuous_novel, clear

count
local n_start = r(N)
file open log using "eligibility_log.txt", write append
file write log "Start: `n_start' patients in novel GLP1s comparisons cohort" _n

merge 1:1 PATIENT_ID using lookback_diabetes_novel, keep (1 3) nogen
drop if lookback_diabetes!=1

count
local n_after = r(N)
file write log "After exclude no type 2 diabetes: `n_after' patients" _n
file close log

save continuous_novel, replace 


* ============================================================================
* Dementia in lookback
* ============================================================================

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'F01%' OR code LIKE 'F02%' OR code LIKE 'F03%' OR code LIKE 'G30%' OR code LIKE 'F1027%' OR code LIKE 'F1097%' OR code LIKE 'G310%' OR code LIKE 'G3183%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= index_date-365
keep PATIENT_ID
gen lookback_dementia=1
duplicates drop
save lookback_dementia_novel, replace


* apply the exclusion
clear
use continuous_novel, clear

merge 1:1 PATIENT_ID using lookback_dementia_novel, keep (1 3) nogen
drop if lookback_dementia == 1

count
local n_after = r(N)
file open log using "eligibility_log.txt", write append
file write log "After exclude dementia: `n_after' patients" _n
file close log

save continuous_novel, replace 


* ============================================================================
* Date of death 
* ============================================================================

clear
odbc load, exec("SELECT PATIENT_ID, PATIENT_DEATH_DATE FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PATIENT_MORTALITY_LATEST") dsn("$SNOWFLAKE_DSN")
merge 1:1 PATIENT_ID using continuous_novel, keep(2 3) nogen

keep PATIENT_ID PATIENT_DEATH_DATE
format %td PATIENT_DEATH_DATE
rename PATIENT_DEATH_DATE dod

save dod_novel, replace



* ============================================================================
* Age + gender
* ============================================================================

clear
odbc load, exec("SELECT PATIENT_ID, PATIENT_DOB, PATIENT_GENDER FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PATIENT_SUMMARIES_LATEST") dsn("$SNOWFLAKE_DSN")
merge 1:1 PATIENT_ID using continuous_novel, keep(match) nogen
gen age = year(index_date)-year(PATIENT_DOB)
rename PATIENT_GENDER gender
drop PATIENT_DOB
keep PATIENT_ID age gender
save age_novel, replace




* ============================================================================
* Contraindications
* ============================================================================

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'E10%' OR code LIKE 'K85%' OR code LIKE 'K860%' OR code LIKE 'K861%' OR code LIKE 'B252%' OR code LIKE 'E312%' OR code LIKE 'C73%' OR code LIKE 'Z85850%' OR code LIKE 'K3184%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= lookback_date

gen lookback_diabetesT1 = 0
gen lookback_pancreatitis = 0
gen lookback_gastroparesis = 0
gen lookback_thy_can = 0

gen code_1 = substr(CODE,1,1)
gen code_3 = substr(CODE,1,3)
gen code_4 = substr(CODE,1,4)
gen code_5 = substr(CODE,1,5)
gen code_6 = substr(CODE,1,6)	
	
replace lookback_diabetesT1 = 1 if code_3 == "E10" 
replace lookback_pancreatitis = 1 if code_3 == "K85" | code_4 == "K860" | code_4 == "K861" | code_4 == "B252" 
replace lookback_thy_can = 1 if code_5=="E312" | code_3 == "C73" | code_5=="Z85850"
replace lookback_gastroparesis = 1 if code_5 == "K3184"

keep if lookback_diabetesT1==1 | lookback_pancreatitis==1 | lookback_thy_can==1 | lookback_gastroparesis==1 
collapse (max) lookback_diabetesT1 lookback_pancreatitis lookback_thy_can lookback_gastroparesis, by(PATIENT_ID)

save contra_novel, replace


* ============================================================================
* Evidence of MCI
* ============================================================================

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE (code LIKE 'G3184%');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= lookback_date

gen lookback_mci = 0

gen code_5 = substr(CODE,1,5)

replace lookback_mci = 1 if code_5 == "G3184"

keep if lookback_mci==1
collapse (max) lookback_mci, by(PATIENT_ID)

save mci_novel, replace



* ============================================================================
* Prior neuroimaging order
* ============================================================================

* search in medical headers
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE code IN ('B030ZZZ', 'B020ZZZ');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= lookback_date

gen lookback_neuro_mh = 0

replace lookback_neuro_mh = 1 if inlist(code, "B030ZZZ", "B020ZZZ")

keep if lookback_neuro_mh==1
collapse (max) lookback_neuro_mh, by(PATIENT_ID)

save neuro_mh_novel, replace

* search in service lines
clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, PROCEDURE, SERVICE_FROM FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.MEDICAL_SERVICE_LINES_LATEST  WHERE PROCEDURE IN ('70551', '70552', '70553', '70555', '70450', '70460', '70470', '0865T', '0866T');") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
keep if CLAIM_DATE <= index_date
keep if CLAIM_DATE >= lookback_date

gen lookback_neuro_sl = 0

replace lookback_neuro_sl = 1 if inlist(PROCEDURE, '70551', '70552', '70553', '70555', '70450', '70460', '70470', '0865T', '0866T')

keep if lookback_neuro_sl==1
collapse (max) lookback_neuro_sl, by(PATIENT_ID)

save neuro_sl_novel, replace



* ============================================================================
* BMI in lookback 
* ============================================================================

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26 )) WHERE code LIKE 'Z68%';") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen
duplicates drop

rename CLAIM_DATE bmi_date
gen bmi = substr(CODE,4,2)
destring bmi, replace
keep if bmi_date < index_date
keep if bmi_date > lookback_date
gen days_to_index = index_date - bmi_date
bysort PATIENT_ID (days_to_index): keep if _n == 1
save lookback_bmi_novel, replace




* ============================================================================
* No prior drug use
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE") dsn("$SNOWFLAKE_DSN")
sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if strpos(PRECISE_GENERIC_NAME, "ABLAGLUTIDE") | strpos(PRECISE_GENERIC_NAME, "EXENATIDE") | strpos(PRECISE_GENERIC_NAME, "LIXISENATIDE")
drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME
duplicates drop
save ndc_other_glp, replace

* run this entire code section at the same time since uses temporary files
clear
use ndc_other_glp, clear
keep CODE
local total_codes = _N
display "Total codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 2000

* store results in temporary file
clear
tempfile all_rx
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
save `all_rx', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_other_glp, clear
    keep in `start_row'/`end_row'
    keep CODE
    
    // Create comma-separated list with quotes around each code
    local code_list ""
    qui count
    local n_codes = r(N)
    forvalues i = 1/`n_codes' {
        local code = CODE[`i']
        if `i' == 1 {
            local code_list "'`code''"
        }
        else {
            local code_list "`code_list', '`code''"
        }
    }
    
    display "Code list sample: " substr("`code_list'", 1, 100) "..."
    
    clear
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("$SNOWFLAKE_DSN")
    append using `all_rx'
    save `all_rx', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' prescriptions so far"
}

* load final result for all chunks
use `all_rx', clear
duplicates drop 

merge m:1 PATIENT_ID using continuous_novel, keep(match) nogen keepusing(PATIENT_ID index_date lookback_date)
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
keep PATIENT_ID
duplicates drop PATIENT_ID, force
gen lookback_glp=1

tempfile lookback_glp_novel
save `lookback_glp_novel'

use continuous_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `lookback_glp_novel', keep(master match) nogen
replace lookback_glp = 0 if missing(lookback_glp)
save lookback_glp_novel, replace



* ============================================================================
* Apply all exclusions 
* ============================================================================

clear
use continuous_novel, clear
merge 1:1 PATIENT_ID using dod_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using lookback_bmi_novel, keep(1 3)
merge 1:1 PATIENT_ID using age_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using contra_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using mci_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using neuro_mh_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using neuro_sl_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using cov_end_novel, keep (1 3) nogen
merge 1:1 PATIENT_ID using lookback_glp_novel, keep (1 3) nogen

file open log using "eligibility_log.txt", write append

drop if age <60
count
local n_after = r(N)
file write log "After exclude age<60: `n_after' patients" _n

*drop if age >=85
*count
*local n_after = r(N)
*file write log "After exclude age>=85: `n_after' patients" _n


drop if missing(age)
count
local n_after = r(N)
file write log "After exclude missing age: `n_after' patients" _n


drop if dod < index_date
count
local n_after = r(N)
file write log "After exclude date of death<index date: `n_after' patients" _n


drop if gender=="U"
count
local n_after = r(N)
file write log "After exclude gender U: `n_after' patients" _n


* Patients with no Z68 code in the lookback (merge _merge==1 above) have no
* recorded BMI and cannot meet the BMI>=25 indication, so they are excluded.
drop if _merge==1
count
local n_after = r(N)
file write log "After exclude no BMI/Z68 code in lookback: `n_after' patients" _n


drop if bmi<25
count
local n_after = r(N)
file write log "After exclude BMI<25 kg/m2: `n_after' patients" _n


drop if lookback_diabetesT1==1
count
local n_after = r(N)
file write log "After exclude type 1 diabetes: `n_after' patients" _n


drop if lookback_pancreatitis==1
count
local n_after = r(N)
file write log "After exclude pancreatitis: `n_after' patients" _n


drop if lookback_thy_can==1
count
local n_after = r(N)
file write log "After exclude thyroid cancer: `n_after' patients" _n


drop if lookback_gastroparesis==1
count
local n_after = r(N)
file write log "After exclude gastroparesis: `n_after' patients" _n


drop if lookback_mci==1
count
local n_after = r(N)
file write log "After exclude MCI: `n_after' patients" _n


drop if lookback_neuro_mh==1
count
local n_after = r(N)
file write log "After exclude prior neuroimaging (medical headers): `n_after' patients" _n


drop if lookback_neuro_sl==1
count
local n_after = r(N)
file write log "After exclude prior neuroimaging (service lines): `n_after' patients" _n


drop if cov_end < index_date + 90
count
local n_after = r(N)
file write log "After exclude <90 days of continuous coverage after index date: `n_after' patients" _n


drop if lookback_glp==1
count
local n_after = r(N)
file write log "After exclude use of ablaglutide, exenatide, or lixisenatide in lookback: `n_after' patients" _n


file close log

drop lookback_date lookback_diabetes lookback_dementia CODE bmi_date _merge lookback_diabetesT1 lookback_pancreatitis lookback_thy_can lookback_gastroparesis lookback_glp

log using summary_stats_novel.log

di "=========================================="
di "Novel GLP1-level cohort final sample size"
di "=========================================="
di ""

tab index_class
tab index_glp1
tab index_class index_glp1

log close

save final_novel, replace

* clean up files we don't need anymore
erase continuous_novel.dta
erase continuous_novel1.dta
erase continuous_novel2.dta
erase continuous_novel3.dta
erase continuous_novel4.dta
erase dod_novel.dta
erase lookback_bmi_novel.dta
erase age_novel.dta
erase contra_novel.dta
erase mci_novel.dta
erase lookback_diabetes_novel.dta
erase lookback_glp_novel.dta
erase lookback_dementia_novel.dta
erase ndc_other_glp.dta