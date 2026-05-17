* ============================================================================
* Path configuration — globals set by run_all.R via the _run_step.do wrapper
* ============================================================================
if "$PROJECT_ROOT" == "" {
    display as error "ERROR: PROJECT_ROOT is not set. Launch the pipeline via run_all.R."
    exit 1
}

* this program gets all claims for medication use for patients in the sample
* and finally an indicator for whether one of those claims occurred during the
* 1-year prior to baseline which is saved as "cov_med"

ssc install gtools

clear
cd "$OUTPUT_DIR"

* first we will get the NDC codes for the medications


* ============================================================================
* NDC Codes for statins
* ============================================================================


odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY

keep if strpos(PRECISE_GENERIC_NAME, "STATIN")

drop if PRECISE_GENERIC_NAME == "IMIPENEM/CILASTATIN SODIUM"
drop if PRECISE_GENERIC_NAME == "NYSTATIN"
drop if PRECISE_GENERIC_NAME == "NYSTATIN/TRIAMCINOLONE ACETONIDE"
drop if PRECISE_GENERIC_NAME == "PENTOSTATIN"
drop if strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Carbapenem")
drop if strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Dermatological")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen statin=1

duplicates drop

save ndc_statin_code, replace


* ============================================================================
* NDC Codes for beta-blockers
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY

keep if (strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Beta Blocker") | strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Antiarrhythmic") | strmatch(PRECISE_GENERIC_NAME,"*OLOL*") | strmatch(PRECISE_GENERIC_NAME,"*ALOL*") | strmatch(PRECISE_GENERIC_NAME,"*ILOL*"))

drop if strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Eye") | strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Dermatological") 

drop if strpos(PRECISE_GENERIC_NAME, "ADENOSINE") | strpos(PRECISE_GENERIC_NAME, "AMIODARONE") | strpos(PRECISE_GENERIC_NAME, "AXICABTAGENE") | strpos(PRECISE_GENERIC_NAME, "BRETYLIUM") | strpos(PRECISE_GENERIC_NAME, "DILTIAZEM") | strpos(PRECISE_GENERIC_NAME, "DISOPYRAMIDE") | strpos(PRECISE_GENERIC_NAME, "DOFETILIDE") | strpos(PRECISE_GENERIC_NAME, "DRONEDARONE") | strpos(PRECISE_GENERIC_NAME, "FLECAINIDE") | strpos(PRECISE_GENERIC_NAME, "LIDOCAINE") | strpos(PRECISE_GENERIC_NAME, "MEXILETINE") | strpos(PRECISE_GENERIC_NAME, "MORICIZINE") | strpos(PRECISE_GENERIC_NAME, "PHENYTOIN") | strpos(PRECISE_GENERIC_NAME, "PROCAINAMIDE") | strpos(PRECISE_GENERIC_NAME, "PROPAFENONE") | strpos(PRECISE_GENERIC_NAME, "QUINIDINE") | strpos(PRECISE_GENERIC_NAME, "STANOZOLOL") | strpos(PRECISE_GENERIC_NAME, "TOCAINIDE") | strpos(PRECISE_GENERIC_NAME, "VERAPAMIL")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen betablocker=1

duplicates drop

save ndc_betablocker_code, replace


* ============================================================================
* NDC Codes for ARBs
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Angiotensin II Receptor Blocker") | strpos(KH_THERAPEUTIC_CLASS_ARRAY, "ARB") | strmatch(PRECISE_GENERIC_NAME,"*SARTAN*")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen arb=1

duplicates drop

save ndc_arb_code, replace



* ============================================================================
* NDC Codes for thiazides
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if strpos(PRECISE_GENERIC_NAME, "THIAZIDE") | strpos(PRODUCT_NAME, "THIAZIDE")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen thiazide=1

duplicates drop

save ndc_thiazide_code, replace


* ============================================================================
* NDC Codes for CCBs
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY

keep if strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Calcium Channel Blocker") | strpos(KH_THERAPEUTIC_CLASS_ARRAY, "CCB") | strmatch(PRECISE_GENERIC_NAME,"*DIPINE*") | strmatch(PRECISE_GENERIC_NAME,"*BEPRIDIL*") | strmatch(PRECISE_GENERIC_NAME,"*DILTIAZEM*") | strmatch(PRECISE_GENERIC_NAME,"*MIBEFRADIL*") | strmatch(PRECISE_GENERIC_NAME,"*VERAPAMIL*")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen ccb=1

duplicates drop

save ndc_ccb_code, replace


* ============================================================================
* NDC Codes for ACEis
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if (strpos(KH_THERAPEUTIC_CLASS_ARRAY, "Angiotensin-Converting Enzyme (ACE) Inhibitor") | strmatch(PRECISE_GENERIC_NAME,"*PRIL*"))

/*
browse if (!strpos(KH_THERAPEUTIC_CLASS_ARRAY, "ACE")) /*no obsevation*/
*/

drop if strmatch(PRECISE_GENERIC_NAME, "*PRILOCAINE*")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen aceinhibitor=1

duplicates drop

save ndc_aceinhibitor_code, replace



* ============================================================================
* NDC Codes for metformin
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if strpos(PRECISE_GENERIC_NAME, "METFORMIN") | strpos(PRODUCT_NAME, "METFORMIN")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen metformin=1

duplicates drop

save ndc_metformin_code, replace



* ============================================================================
* NDC Codes for insulin
* ============================================================================

clear
odbc load, exec("SELECT * FROM SENTINEL_COMMON.SENTINEL_REFERENCE.DRUG_REFERENCE")

sort PRECISE_GENERIC_NAME PRODUCT_NAME KH_THERAPEUTIC_CLASS_ARRAY
keep if strpos(PRECISE_GENERIC_NAME, "INSULIN") | strpos(PRODUCT_NAME, "INSULIN")

drop CODE_TYPE PRODUCT_NAME KH_ROUTE_ARRAY KH_THERAPEUTIC_CLASS_ARRAY PRECISE_GENERIC_NAME

gen insulin=1

duplicates drop

save ndc_insulin_code, replace


* now we can identify prior use of these medications

* ============================================================================
* Identify statin use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of statin NDC codes ---
use ndc_statin_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total statin codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_statin_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_statin_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_statin_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only 
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_statin_prescriptions'
    save `all_statin_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_statin_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen statin = 1

local n_total = _N
display "Total statin prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
keep PATIENT_ID statin
gduplicates drop PATIENT_ID, force

tempfile statin_flag
save `statin_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `statin_flag', keep(master match) nogen
replace statin = 0 if missing(statin)

save cov_statin_novel, replace

local n_flag = _N
display "Patients with statin in study window: `n_flag'"


* repeat for: ndc_betablocker_code, ndc_arb_code, ndc_thiazide_code, ndc_aceinhibitor_code



* ============================================================================
* Identify betablocker use
* ============================================================================


* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of betablocker NDC codes ---
use ndc_betablocker_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total betablocker codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_betablocker_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_betablocker_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_betablocker_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_betablocker_prescriptions'
    save `all_betablocker_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_betablocker_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force


gen cov_betablocker = 1

local n_total = _N
display "Total betablocker prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not

keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen betablocker = 1
keep PATIENT_ID betablocker
gduplicates drop PATIENT_ID, force

tempfile betablocker_flag
save `betablocker_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `betablocker_flag', keep(master match) nogen
replace betablocker = 0 if missing(betablocker)

save cov_betablocker_novel, replace

local n_flag = _N
display "Patients with betablocker in study window: `n_flag'"




* ============================================================================
* Identify ARB use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of arb NDC codes ---
use ndc_arb_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total arb codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_arb_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_arb_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_arb_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_arb_prescriptions'
    save `all_arb_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_arb_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_arb = 1

local n_total = _N
display "Total arb prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen arb = 1
keep PATIENT_ID arb
gduplicates drop PATIENT_ID, force

tempfile arb_flag
save `arb_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `arb_flag', keep(master match) nogen
replace arb = 0 if missing(arb)

save cov_arb_novel, replace

local n_flag = _N
display "Patients with arb in study window: `n_flag'"



* ============================================================================
* Identify thiazide use
* ============================================================================


* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of thiazide NDC codes ---
use ndc_thiazide_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total thiazide codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_thiazide_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_thiazide_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_thiazide_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_thiazide_prescriptions'
    save `all_thiazide_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_thiazide_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_thiazide = 1

local n_total = _N
display "Total thiazide prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen thiazide = 1
keep PATIENT_ID thiazide
gduplicates drop PATIENT_ID, force

tempfile thiazide_flag
save `thiazide_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `thiazide_flag', keep(master match) nogen
replace thiazide = 0 if missing(thiazide)

save cov_thiazide_novel, replace

local n_flag = _N
display "Patients with thiazide in study window: `n_flag'"




* ============================================================================
* Identify ACEi use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of aceinhibitor NDC codes ---
use ndc_aceinhibitor_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total aceinhibitor codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_aceinhibitor_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_aceinhibitor_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_aceinhibitor_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_aceinhibitor_prescriptions'
    save `all_aceinhibitor_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_aceinhibitor_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_aceinhibitor = 1

local n_total = _N
display "Total aceinhibitor prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen aceinhibitor = 1
keep PATIENT_ID aceinhibitor
gduplicates drop PATIENT_ID, force

tempfile aceinhibitor_flag
save `aceinhibitor_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `aceinhibitor_flag', keep(master match) nogen
replace aceinhibitor = 0 if missing(aceinhibitor)

save cov_aceinhibitor_novel, replace

local n_flag = _N
display "Patients with aceinhibitor in study window: `n_flag'"



* ============================================================================
* Identify CCB use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of ccb NDC codes ---
use ndc_ccb_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total ccb codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_ccb_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_ccb_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_ccb_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only 
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_ccb_prescriptions'
    save `all_ccb_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_ccb_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_ccb = 1

local n_total = _N
display "Total ccb prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen ccb = 1
keep PATIENT_ID ccb
gduplicates drop PATIENT_ID, force

tempfile ccb_flag
save `ccb_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `ccb_flag', keep(master match) nogen
replace ccb = 0 if missing(ccb)

save cov_ccb_novel, replace

local n_flag = _N
display "Patients with ccb in study window: `n_flag'"


* ============================================================================
* Identify insulin use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of insulin NDC codes ---
use ndc_insulin_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total insulin codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_insulin_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_insulin_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_insulin_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_insulin_prescriptions'
    save `all_insulin_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_insulin_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_insulin = 1

local n_total = _N
display "Total insulin prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen insulin = 1
keep PATIENT_ID insulin
gduplicates drop PATIENT_ID, force

tempfile insulin_flag
save `insulin_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `insulin_flag', keep(master match) nogen
replace insulin = 0 if missing(insulin)

save cov_insulin_novel, replace

local n_flag = _N
display "Patients with insulin in study window: `n_flag'"



* ============================================================================
* Identify metformin use
* ============================================================================

* run this entire code section at the same time since uses temporary files

* --- prep cohort lookup (used inside the chunk loop) ---
use final_novel, clear
keep PATIENT_ID index_date lookback_date
duplicates drop PATIENT_ID, force   // ensure m:1 will work
tempfile cohort
save `cohort'

* --- get list of metformin NDC codes ---
use ndc_metformin_code, clear
keep CODE
duplicates drop

local total_codes = _N
display "Total metformin codes: `total_codes'"

* we will split up query into chunks to deal with memory limitations
local chunk_size 1000

* store results in temporary file
clear
tempfile all_metformin_prescriptions
gen PATIENT_ID = ""
gen DATE_OF_SERVICE = .
gen NDC11 = ""
gen index_date = .
gen lookback_date = .
save `all_metformin_prescriptions', replace emptyok

local n_chunks = ceil(`total_codes' / `chunk_size')
display "Will process `n_chunks' chunks"

* process each chunk
forvalues chunk = 1/`n_chunks' {
    
    display "Processing chunk `chunk' of `n_chunks'..."
    
    local start_row = (`chunk' - 1) * `chunk_size' + 1
    local end_row = min(`chunk' * `chunk_size', `total_codes')
    
    use ndc_metformin_code, clear
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
    odbc load, exec(`"SELECT PATIENT_ID, DATE_OF_SERVICE, NDC11 FROM PHARMACY_LATEST WHERE NDC11 IN (`code_list')"') dsn("Snowflake Data 2")
    
    * dedup within chunk
    gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force
    
    * filter to cohort patients only
    merge m:1 PATIENT_ID using `cohort', keep(match) nogen ///
        keepusing(index_date lookback_date)
    
    * shrink storage before saving
    compress
    
    * accumulate
    append using `all_metformin_prescriptions'
    save `all_metformin_prescriptions', replace
    
    local n_so_far = _N
    display "Chunk `chunk' complete: `n_so_far' cohort prescriptions so far"
}

* --- final result ---
use `all_metformin_prescriptions', clear
compress

* optional safety dedup
gduplicates drop PATIENT_ID DATE_OF_SERVICE NDC11, force

gen cov_metformin = 1

local n_total = _N
display "Total metformin prescriptions found: `n_total'"

* create filter for only rx occurring during 1 year baseline
* with only 1 row per patient ID and flag for whether had rx or not
keep if DATE_OF_SERVICE <= index_date & DATE_OF_SERVICE >= lookback_date
gen metformin = 1
keep PATIENT_ID metformin
gduplicates drop PATIENT_ID, force

tempfile metformin_flag
save `metformin_flag'

use final_novel, clear
keep PATIENT_ID
merge 1:1 PATIENT_ID using `metformin_flag', keep(master match) nogen
replace metformin = 0 if missing(metformin)

save cov_metformin_novel, replace

local n_flag = _N
display "Patients with metformin in study window: `n_flag'"