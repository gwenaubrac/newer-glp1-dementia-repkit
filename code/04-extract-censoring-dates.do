include "_globals.do"

* note: you have to run the entire script at once
* since using temporary files
* to change length of the grace period, change from '90' to whatever grace period you want

cd "$PROJECT_ROOT"
clear all
set more off

* ============================================================================
* Load and prepare dispensing data by drug class
* ============================================================================

* Load GLP1 dispensings
use "output/dispensings_glp1.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "GLP1"
tempfile disp_glp1
save `disp_glp1', replace

* Load SGLT2 dispensings
use "output/dispensings_sglt2.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "SGLT2"
tempfile disp_sglt2
save `disp_sglt2', replace

* Load DPP4 dispensings
use "output/dispensings_dpp4.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "DPP4"
tempfile disp_dpp4
save `disp_dpp4', replace

* Load SULFO dispensings
use "output/dispensings_sulfo.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "SULFO"
tempfile disp_sulfo
save `disp_sulfo', replace

* Combine all class-level dispensings
use `disp_glp1', clear
append using `disp_sglt2'
append using `disp_dpp4'
append using `disp_sulfo'
tempfile disp_class
save `disp_class', replace

* ============================================================================
* Load specific GLP1 drug dispensings
* ============================================================================

* Semaglutide
use "output/dispensings_semaglutide.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "semaglutide"
tempfile disp_sema
save `disp_sema', replace

* Tirzepatide
use "output/dispensings_tirzepatide.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "tirzepatide"
tempfile disp_tirze
save `disp_tirze', replace

* Liraglutide
use "output/dispensings_liraglutide.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "liraglutide"
tempfile disp_lira
save `disp_lira', replace

* Dulaglutide
use "output/dispensings_dulaglutide.dta", clear
keep PATIENT_ID DATE_OF_SERVICE
gen drug_class = "dulaglutide"
tempfile disp_dula
save `disp_dula', replace

* Combine for drug-specific analysis (includes SGLT2, DPP4, SULFO + specific GLP1s)
use `disp_sglt2', clear
append using `disp_dpp4'
append using `disp_sulfo'
append using `disp_sema'
append using `disp_tirze'
append using `disp_lira'
append using `disp_dula'
tempfile disp_drug
save `disp_drug', replace

* ============================================================================
* NOVEL COMPARISON: Discontinuation and Switch
* ============================================================================

* Note: calculating disc/switch dates for liraglutide and dulaglutide, although I don't think we'll be needing them

* Get discontinuation date
use "output/index_novel_comparisons.dta", clear
merge 1:m PATIENT_ID using `disp_drug', keep(master match) nogen

* Keep only fills after index date
keep if DATE_OF_SERVICE > index_date

* Keep semaglutide or tirzepatide fills for GLP1
* And same class fills for other index groups
gen keep_flag = 0

replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "semaglutide" & (drug_class == "semaglutide" | drug_class == "tirzepatide")
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "tirzepatide" & (drug_class == "tirzepatide" | drug_class == "semaglutide")
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "liraglutide" & drug_class == "liraglutide"
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "dulaglutide" & drug_class == "dulaglutide"

* For non-GLP1 index: keep same class
replace keep_flag = 1 if index_class != "GLP1" & drug_class == index_class

keep if keep_flag == 1
drop keep_flag

* Calculate discontinuation
sort PATIENT_ID DATE_OF_SERVICE
by PATIENT_ID: gen prev_fill = DATE_OF_SERVICE[_n-1]
by PATIENT_ID: replace prev_fill = index_date if _n == 1
gen gap_days = DATE_OF_SERVICE - prev_fill

keep if gap_days > 90
bysort PATIENT_ID (DATE_OF_SERVICE): keep if _n == 1
gen disc_date = prev_fill + 90
keep PATIENT_ID disc_date
format disc_date %td

save "output/disc_date_novel.dta", replace

* Get switch date
use "output/index_novel_comparisons.dta", clear
merge 1:m PATIENT_ID using `disp_drug', keep(master match) nogen

keep if DATE_OF_SERVICE > index_date

* For GLP1 index: keep fills of OTHER GLP1 drugs than sema or tirze, or other classes
gen keep_flag = 0
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "semaglutide" & (drug_class != "semaglutide" & drug_class != "tirzepatide")
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "tirzepatide" & (drug_class != "tirzepatide" & drug_class != "semaglutide")
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "liraglutide" & drug_class != "liraglutide"
replace keep_flag = 1 if index_class == "GLP1" & index_glp1 == "dulaglutide" & drug_class != "dulaglutide"

* For non-GLP1 index: keep different class
replace keep_flag = 1 if index_class != "GLP1" & index_class != drug_class

keep if keep_flag == 1
drop keep_flag

sort PATIENT_ID DATE_OF_SERVICE
by PATIENT_ID: keep if _n == 1
keep PATIENT_ID DATE_OF_SERVICE drug_class
rename DATE_OF_SERVICE switch_date
rename drug_class switch_type
format switch_date %td

save "output/switch_date_novel.dta", replace


* remove files we don't need anymore to free up space
erase "output/dispensings_glp1.dta"
erase "output/dispensings_sglt2.dta"
erase "output/dispensings_dpp4.dta"
erase "output/dispensings_sulfo.dta"
erase "output/dispensings_semaglutide.dta"
erase "output/dispensings_tirzepatide.dta"
erase "output/dispensings_liraglutide.dta"
erase "output/dispensings_dulaglutide.dta"
