include "_globals.do"

* We will identify whether patients had continuous coverage in N-month lookback from index date
* And when their continous coverage ended after index date
* These dates are saved in "cov_lookback_novel" and "cov_end_novel"

* ============================================================================
* Sensitivity parameter — coverage lookback period
* ============================================================================
* COVERAGE_MONTHS is set by run_sensitivity.R; defaults to 12 (main analysis).


local cov_months = ${COVERAGE_MONTHS}
if `cov_months' == 12 {
    local lookback_days = 365
}
else if `cov_months' == 6 {
    local lookback_days = 182
}
else {
    display as error "COVERAGE_MONTHS must be 6 or 12 (got: `cov_months')"
    exit 198
}

* ============================================================================
* Novel GLP1s comparison
* ============================================================================

clear
cd "$PROJECT_ROOT"

odbc load, exec("SELECT PATIENT_ID, ELIGIBILITY_START_DATE, ELIGIBILITY_END_DATE, MEDICAL_COVERAGE_INDICATOR, PHARMACY_COVERAGE_INDICATOR FROM DSVC_RWJF_BU_AA_RE_ENCOUNTERS_PROD.COHORT_1302462.PATIENT_ENROLLMENT_LATEST") dsn("$SNOWFLAKE_DSN")

keep if MEDICAL_COVERAGE_INDICATOR==1 & PHARMACY_COVERAGE_INDICATOR==1

sort PATIENT_ID ELIGIBILITY_START_DATE
merge m:1 PATIENT_ID using "output\index_novel_comparisons" ,keep(match) nogen

gen lookback_date = index_date - `lookback_days'

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

gen study_end = date("$STUDY_END", "YMD")
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