include "_globals.do"

* We will identify whether patients had continuous coverage in N-month lookback from index date
* And when their continous coverage ended after index date
* These dates are saved in "cov_lookback_novel" and "cov_end_novel"

* ============================================================================
* Sensitivity parameter - coverage lookback period
* ============================================================================
* COVERAGE_MONTHS is set by run_sensitivity.R and defaults to 12 (main
* analysis). $LOOKBACK_DAYS is derived from it in config.R (365 for 12 months,
* 182 for 6) so that this script, 06 and 09 all use the same window; config.R
* rejects any other value. Do not hardcode the number here.
local lookback_days = $LOOKBACK_DAYS
display as text "coverage/covariate lookback: `lookback_days' days (${COVERAGE_MONTHS} months)"

* ============================================================================
* Novel GLP1s comparison
* ============================================================================

clear
* Writes go to $OUTPUT_DIR (= main's output for main runs, scenario's output
* for sensitivity). Upstream reads (index_novel_comparisons was produced by
* step 03, which sensitivity scenarios don't re-run) use $MAIN_OUTPUT_DIR.
cd "$OUTPUT_DIR"

* ============================================================================
* Load enrollment ONCE, filtered server-side
* ============================================================================
* PATIENT_ENROLLMENT_LATEST holds every enrollment segment for every patient in
* the database. The dual-coverage filter and the column selection run in SQL,
* so rows that would be dropped never reach Stata.
*
* The two blocks below (lookback coverage, post-index coverage end) need the
* exact same rows, so this loads them once into a tempfile that both blocks
* read, instead of running the identical query twice.
* NOTE: this makes it mandatory to run the do-file in one go - the tempfile does
* not survive between piecemeal runs.

odbc load, exec("SELECT PATIENT_ID, ELIGIBILITY_START_DATE, ELIGIBILITY_END_DATE FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PATIENT_ENROLLMENT_LATEST WHERE MEDICAL_COVERAGE_INDICATOR = 1 AND PHARMACY_COVERAGE_INDICATOR = 1") dsn("$SNOWFLAKE_DSN")
compress
display as text "enrollment rows loaded: " _N

tempfile enroll
save "`enroll'"

* ---- cov_lookback_novel: continuous coverage across the lookback window -----
sort PATIENT_ID ELIGIBILITY_START_DATE
merge m:1 PATIENT_ID using "$MAIN_OUTPUT_DIR/index_novel_comparisons" ,keep(match) nogen

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

save "cov_lookback_novel", replace


* ---- cov_end_novel: first date continuous coverage ends after index ---------
* Same rows as above, read from the tempfile instead of re-querying Snowflake.
use "`enroll'", clear

sort PATIENT_ID ELIGIBILITY_START_DATE
merge m:1 PATIENT_ID using "$MAIN_OUTPUT_DIR/index_novel_comparisons"
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

save "cov_end_novel", replace