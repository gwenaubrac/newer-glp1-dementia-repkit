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


* Identify whether patients had continuous coverage in 1-year lookback from index date
* And when their continous coverage ended after index date
* These dates are saved in "cov_lookback_novel" and "cov_end_novel"

* For sensitivity analysis using 6-months of lookback instead of 1-year:
* use "gen lookback_date = index_date - 182" in line 26


* ============================================================================
* Novel GLP1s comparison
* ============================================================================

clear
* make sure to update the path and specify dsn/password as needed with odbc load
cd "$OUTPUT_DIR"

odbc load, exec("SELECT PATIENT_ID, ELIGIBILITY_START_DATE, ELIGIBILITY_END_DATE, MEDICAL_COVERAGE_INDICATOR, PHARMACY_COVERAGE_INDICATOR FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.PATIENT_ENROLLMENT_LATEST") 

keep if MEDICAL_COVERAGE_INDICATOR==1 & PHARMACY_COVERAGE_INDICATOR==1

sort PATIENT_ID ELIGIBILITY_START_DATE
merge m:1 PATIENT_ID using "output\index_novel_comparisons" ,keep(match) nogen
*browse if ELIGIBILITY_END_DATE < ELIGIBILITY_START_DATE

gen lookback_date = index_date - 365 /* change to 182 for 6 months coverage requirement instead */

drop if ELIGIBILITY_END_DATE < lookback_date
drop if ELIGIBILITY_START_DATE > index_date

gen seg_start = max(ELIGIBILITY_START_DATE, lookback_date)
gen seg_end   = min(ELIGIBILITY_END_DATE, index_date)
format %td seg_start seg_end
sort PATIENT_ID seg_start seg_end

* Calculate gap (gap < 0 means overlap, gap = 0 means adjacent, gap > 0 means gap)
by PATIENT_ID (seg_start seg_end): gen gap = seg_start - seg_end[_n-1] - 1

* Set first observation gap to 0
by PATIENT_ID (seg_start seg_end): replace gap = 0 if _n == 1

* Check for any actual gaps (not overlaps or adjacent)
by PATIENT_ID: egen any_gap = max(gap > 0)

by PATIENT_ID: egen first_cov = min(seg_start)
by PATIENT_ID: egen last_cov  = max(seg_end)
format %td first_cov last_cov

gen keep_patient = (any_gap==0 & first_cov==lookback_date & last_cov==index_date)

keep if keep_patient==1
keep PATIENT_ID

duplicates drop

save "output\cov_lookback_novel", replace


clear
odbc load, exec("SELECT PATIENT_ID, ELIGIBILITY_START_DATE, ELIGIBILITY_END_DATE, MEDICAL_COVERAGE_INDICATOR, PHARMACY_COVERAGE_INDICATOR FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.PATIENT_ENROLLMENT_LATEST") 

keep if MEDICAL_COVERAGE_INDICATOR==1
keep if PHARMACY_COVERAGE_INDICATOR==1

sort PATIENT_ID ELIGIBILITY_START_DATE
merge m:1 PATIENT_ID using "output\index_novel_comparisons"
keep if _merge==3
drop _merge

gen study_end = mdy(1,1,2026)
format study_end %td
drop if ELIGIBILITY_END_DATE < index_date
drop if ELIGIBILITY_START_DATE > study_end

keep PATIENT_ID ELIGIBILITY_START_DATE ELIGIBILITY_END_DATE index_date study_end

gen seg_start = max(ELIGIBILITY_START_DATE, index_date)
gen seg_end   = min(ELIGIBILITY_END_DATE, study_end)
format %td seg_start seg_end
sort PATIENT_ID seg_start seg_end

* gap to the NEXT segment for this patient
by PATIENT_ID (seg_start seg_end): gen gap_next = seg_start[_n+1] - seg_end - 1
by PATIENT_ID (seg_start seg_end): replace gap_next = 0 if _n==_N 
keep if gap_next > 0

* the stop-coverage time is the end of THIS segment (the one before the gap)
gen cov_end = ELIGIBILITY_END_DATE 
format cov_end %td

keep PATIENT_ID cov_end
collapse (min) cov_end, by(PATIENT_ID)

save "output\cov_end_novel", replace