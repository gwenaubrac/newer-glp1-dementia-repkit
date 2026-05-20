include "_globals.do"

* ============================================================================
* Race and Ethnicity
* ============================================================================
cd "$OUTPUT_DIR"
clear 

odbc load, exec("SELECT PATIENT_ID, PATIENT_RACE_ETHNICITY FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PATIENT_RACE_ETHNICITY_LATEST") dsn("$SNOWFLAKE_DSN")
merge 1:1 PATIENT_ID using final_novel, keep(2 3) nogen
keep PATIENT_ID PATIENT_RACE_ETHNICITY
rename PATIENT_RACE_ETHNICITY race

replace race="MISSING" if missing(race)
save cov_race_novel, replace


* ============================================================================
* Region and Plan
* ============================================================================
clear
odbc load, exec("SELECT PATIENT_ID, ELIGIBILITY_START_DATE, ELIGIBILITY_END_DATE, MEDICAL_COVERAGE_INDICATOR, PHARMACY_COVERAGE_INDICATOR, PATIENT_STATE, MX_KH_PLAN_ID, RX_KH_PLAN_ID FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PATIENT_ENROLLMENT_LATEST") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using final_novel, keep(2 3) nogen keepusing(PATIENT_ID index_date)

keep if ELIGIBILITY_START_DATE<=index_date & index_date<=ELIGIBILITY_END_DATE
keep if MEDICAL_COVERAGE_INDICATOR==1 & PHARMACY_COVERAGE_INDICATOR==1
keep PATIENT_ID PATIENT_STATE MX_KH_PLAN_ID RX_KH_PLAN_ID

rename MX_KH_PLAN_ID plan_medical
rename RX_KH_PLAN_ID plan_pharmacy

preserve
keep PATIENT_ID PATIENT_STATE plan_medical
rename plan_medical plan_id

save plan_medical_novel, replace
restore

keep PATIENT_ID PATIENT_STATE plan_pharmacy
rename plan_pharmacy plan_id
save plan_pharmacy_novel, replace

clear
odbc load, exec("SELECT KH_PLAN_ID, INSURANCE_GROUP FROM $SNOWFLAKE_CLIENT.$SNOWFLAKE_COHORT.PLANS_LATEST") dsn("$SNOWFLAKE_DSN")
rename KH_PLAN_ID plan_id
merge 1:m plan_id using plan_pharmacy_novel
drop if _merge==1
keep PATIENT_ID INSURANCE_GROUP PATIENT_STATE
duplicates drop 
order PATIENT_ID, before(INSURANCE_GROUP)
sort PATIENT_ID
rename INSURANCE_GROUP plan_type
rename PATIENT_STATE state

replace plan_type="MISSING" if missing(plan_type)
replace state="MISSING" if missing(state)

gen region =""
replace region = "NORTHEAST" if inlist(state, "ME","NH","VT","MA","RI","CT","NY","NJ","PA")
replace region = "MIDWEST" if inlist(state, "OH","IN","IL","MI","WI","MN","IA") | inlist(state,"MO","ND","SD","NE","KS")
replace region = "SOUTH" if inlist(state, "DE","MD","DC","VA","WV","NC","SC","GA") | inlist(state,"FL","KY","TN","AL","MS","AR","LA","OK","TX")
replace region = "WEST" if inlist(state, "MT","ID","WY","CO","NM","AZ","UT") | inlist(state,"NV","WA","OR","CA","AK","HI")
replace region = "MISSING" if state=="MISSING"

keep PATIENT_ID plan_type region
save cov_plan_novel, replace

count if missing(plan_type)
tab plan_type, missing

count if missing(region)
tab region, missing
