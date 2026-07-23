include "_globals.do"

* ============================================================================
* Hospitalization
* ============================================================================
clear
cd "$OUTPUT_DIR"

use final_novel, clear
gen lookback_date = index_date - 365
save final_novel, replace

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, ADMISSION_DATE, FROM MEDICAL_HEADERS_LATEST WHERE ADMISSION_DATE IS NOT NULL ;") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using final_novel, keep(2 3) nogen	
duplicates drop
keep PATIENT_ID ADMISSION_DATE
rename ADMISSION_DATE hosp_date
save cov_hosp_long, replace

clear
odbc load, exec("SELECT DISTINCT PATIENT_ID, SERVICE_FROM,  FROM MEDICAL_SERVICE_LINES_LATEST WHERE EMERGENCY_INDICATOR = 'Y' ;") dsn("$SNOWFLAKE_DSN")
merge m:1 PATIENT_ID using final_novel, keep(2 3)nogen		
keep PATIENT_ID SERVICE_FROM
duplicates drop
rename SERVICE_FROM emerg_date		
save cov_emerg_long, replace


use final_novel, clear
keep PATIENT_ID index_date lookback_date
merge 1:m PATIENT_ID using cov_hosp_long, keep(master match) nogen
keep if hosp_date >= lookback_date
keep if hosp_date <= index_date
bysort PATIENT_ID: egen hosp_count = count(hosp_date)
bysort PATIENT_ID: keep if _n == 1
keep PATIENT_ID index_date hosp_count
gen hosp_cat = 0 if hosp_count == 0
replace hosp_cat = 1 if hosp_count == 1
replace hosp_cat = 2 if hosp_count == 2
replace hosp_cat = 3 if hosp_count >= 3 & !missing(hosp_count)
label define hosp_lbl 0 "0 hosps" 1 "1 hosp" 2 "2 hosps" 3 "3+ hosps"
label values hosp_cat hosp_lbl
tab hosp_cat
keep PATIENT_ID hosp_cat
save cov_hosp_novel, replace


* for emergency service use
use final_novel, clear
keep PATIENT_ID index_date lookback_date
merge 1:m PATIENT_ID using cov_emerg_long, keep(master match) nogen
keep if emerg_date >= lookback_date
keep if emerg_date <= index_date
bysort PATIENT_ID: egen emerg_count = count(emerg_date)
bysort PATIENT_ID: keep if _n == 1
keep PATIENT_ID index_date emerg_count
gen emerg_cat = 0 if emerg_count == 0
replace emerg_cat = 1 if emerg_count == 1
replace emerg_cat = 2 if emerg_count == 2
replace emerg_cat = 3 if emerg_count >= 3 & !missing(emerg_count)
label define emerg_lbl 0 "0 emerg" 1 "1 emerg" 2 "2 emerg" 3 "3+ emerg"
label values emerg_cat emerg_lbl

tab emerg_cat

keep PATIENT_ID emerg_cat
save cov_emerg_novel, replace

* delete the long data files we don't need
erase cov_hosp_long.dta
erase cov_emerg_long.dta


* ============================================================================
* Comorbidities
* ============================================================================

* this code takes a while to run (several hours depending on size of the cohort)
* could work on improving the efficiency!

clear

global alcohol "F10"
global anxiety  "F41"
global cancer "C0 C1 C2 C3 C4 C5 C6 C7 C8 C9"
global cvd "I60 I61 I62 I63 I64 I65 I66 I67 I68 I69 G45"
global ckd "N18 I12 I13"
global depression "F32 F33"
global revas "Z951 Z952 Z953 Z954 Z955 I25810 33510 33511 33512 33513 33514 33515 33516 33517 33518 33519 33520 33521 33522 33523 33524 33525 33526 33527 33528 33529 33530 33531 33532 33533 33534 33535 33536 92920 92921 92924 92925 92928 92929 92933 92934 92937 92938 92941 92943 92944 92973 92974 92975 92978 92979 93571 93572 C9600 C9601 C9602 C9603 C9604 C9605 C9606 C9607 C9608"
global ampu "Z894 Z895"
global retino "E113"
global diab_neuro "E114"
global hypoglyc "E160 E161 E162"
global eskd "N185 N186 Z992 Z49 T85611 T85621 T85631 T85691 I953 90935 90936 90937 90938 90939 90940 90941 90942 90943 90944 90945 90946 90947 90948 90949 90950 90951 90952 90953 90954 90955 90956 90957 90958 90959 90960 90961 90962 90963 90964 90965 90966 90967 90968 90969 90970 90971 90972 90973 90974 90975 90976 90977 90978 90979 90980 90981 90982 90983 90984 90985 90986 90987 90988 90989 90990 90991 90992 90993 90994 90995 90996 90997 90998 90999 99512 49420 49421 36145 36800 36810 36815 36831 36832 36833 36838 93990 A4653 A4671 A4672 A4673 A4719 A4720 A4721 A4722 A4723 A4724 A4725 A4726 A4728 A4760 A4765 A4766 A4860 A4880 A4900 A4901 A4905 E1632 E1592 E1594 E1630 E1634 E1638 E1640"
global hepa "K70 K71 K72 K73 K74 K75 K76 K77 B16 B17 B18 B19"
global ihd "I20 I21 I22 I23 I24 I25"
global nafld "K760"
global pace "Z950 Z95810 Z95811 Z95812 02H63JZ 02H73JZ 02HK3JZ 0JH604Z 0JPT0PZ 0JH60PZ 02HK3KZ 0JH608Z 0JPT0PZ 0JH60KZ 33262 33263 33264"
global pvd "I70 I71 I72 I73 I74 I75 I76 I77 I78 I79"
global vhd "I42 I43 I514"
global edema "R60"
global copd "J41 J42 J43 J44"
global apnea "G473"
global thyroid "E00 E01 E02 E03 E04 E05 E06 E07"
global falls "W00 W01 W03 W04 W05 W06 W07 W08 W09 W10 W11 W12 W13 W14 W15 W16 W17 W18 W19"
global fractures "M484 M495 M80 M843 M844 M907 M966 S02 S12 S22 S32 S42 S52 S62 S72 S82 S92 T02 T08 T10 T12 T142"
global care_dependency "Z74.0 Z74.1 Z74.2 Z74.3 Z74.8 Z74.9 Z99"
global malnutrition "E40 E41 E42 E43 E44 E45 E46"
global aki "N17"
global proteinuria "R80"
global hf_hosp "I50 I0981 I110 I130 I132"

* these are tests
display "alcohol macro contains: $alcohol"
display "ihd macro contains: $ihd"

* in case make edits to program, need to drop it before redefining it
* program drop get_codes

program define get_codes
    syntax, name(string) codes(string)
    
    local where ""
    foreach c of local codes {
        local where "`where' code LIKE '`c'%' OR"
    }
    local where = substr("`where'", 1, length("`where'") - 3)
    
    display "WHERE clause: `where'"

    * first search in medical headers and pull all occurrences of the code with corresponding date
    clear
    odbc load, exec(`"SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26)) WHERE `where'"') dsn("$SNOWFLAKE_DSN")
    
    tempfile headers_temp
    save `headers_temp'
    
    * now search in service line for procedures and pull all occurrences of codes with corresponding date
    clear
    odbc load, exec(`"SELECT DISTINCT PATIENT_ID, SERVICE_FROM, code FROM MEDICAL_SERVICE_LINES_LATEST UNPIVOT (code FOR col IN (PROCEDURE, DIAGNOSIS_CODE_1, DIAGNOSIS_CODE_2, DIAGNOSIS_CODE_3, DIAGNOSIS_CODE_4)) WHERE `where'"') dsn("$SNOWFLAKE_DSN")
    rename SERVICE_FROM CLAIM_DATE
         
    * combined medical headers and service line
    append using `headers_temp'
    duplicates drop

    * keep only patients in cohort
    merge m:1 PATIENT_ID using final_novel, keep(match) nogen keepusing(PATIENT_ID index_date lookback_date)
    
    keep PATIENT_ID CLAIM_DATE index_date lookback_date
    sort PATIENT_ID CLAIM_DATE
    duplicates drop
    
    local n_total = _N
    display "Total `name' claims: `n_total'"
    
    keep if CLAIM_DATE <= index_date & CLAIM_DATE >= lookback_date
    gen `name' = 1
    keep PATIENT_ID `name'
    duplicates drop PATIENT_ID, force
    
    tempfile flag_temp
    save `flag_temp'
    
    use final_novel, clear
    keep PATIENT_ID
    merge 1:1 PATIENT_ID using `flag_temp', keep(master match) nogen
    replace `name' = 0 if missing(`name')
    
    save cov_`name'_novel, replace
end



clear
get_codes, name(alcohol) codes($alcohol)

clear
get_codes, name(cancer) codes($cancer)

clear
get_codes, name(cvd) codes($cvd)

clear
get_codes, name(ckd) codes($ckd)

clear
get_codes, name(revas) codes($revas)

clear
get_codes, name(ampu) codes($ampu)

clear
get_codes, name(retino) codes($retino)

clear
get_codes, name(diab_neuro) codes($diab_neuro)

clear
get_codes, name(hypoglyc) codes($hypoglyc)

clear
get_codes, name(eskd) codes($eskd)

clear
get_codes, name(hepa) codes($hepa)

clear
get_codes, name(ihd) codes($ihd)

clear
get_codes, name(nafld) codes($nafld)

clear
get_codes, name(pace) codes($pace)

clear
get_codes, name(pvd) codes($pvd)

clear
get_codes, name(vhd) codes($vhd)

clear 
get_codes, name(edema) codes($edema)

clear
get_codes, name(copd) codes($copd)

clear
get_codes, name(apnea) codes($apnea)

clear
get_codes, name(thyroid) codes($thyroid)

clear
get_codes, name(depression) codes($depression)

clear
get_codes, name(anxiety) codes($anxiety)

clear
get_codes, name(falls) codes($falls)

clear
get_codes, name(fractures) codes($fractures)

clear
get_codes, name(care_dependency) codes($care_dependency)

clear
get_codes, name(malnutrition) codes($malnutrition)

clear
get_codes, name(aki) codes($aki)

clear
get_codes, name(proteinuria) codes($proteinuria)


* we will break hypertension into bits because run into crashes/memory issues (likely because this condition is so common)
* and we will not search service lines for it due to memory issues (only medical headers)
global hyper1 "I10"
global hyper2 "I11"
global hyper3 "I12"
global hyper4 "I13"
global hyper5 "I15"
global hyper6 "I16"
global hyper7 "I1A N262"

program define get_codes_2
    syntax, name(string) codes(string)
    
    local where ""
    foreach c of local codes {
        local where "`where' code LIKE '`c'%' OR"
    }
    local where = substr("`where'", 1, length("`where'") - 3)
    
    display "WHERE clause: `where'"

    * search in medical headers and pull all occurrences of the code with corresponding date
    clear
    odbc load, exec(`"SELECT DISTINCT PATIENT_ID, CLAIM_DATE, code FROM MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26)) WHERE `where'"') dsn("$SNOWFLAKE_DSN")

    * keep only patients in cohort
    merge m:1 PATIENT_ID using final_novel, keep(match) nogen keepusing(PATIENT_ID index_date lookback_date)
    
    keep PATIENT_ID CLAIM_DATE index_date lookback_date
    sort PATIENT_ID CLAIM_DATE
    duplicates drop
    
    local n_total = _N
    display "Total `name' claims: `n_total'"
    
    * keep only claims that occurred during lookback period
    keep if CLAIM_DATE <= index_date & CLAIM_DATE >= lookback_date
    gen `name' = 1
    keep PATIENT_ID `name'
    duplicates drop PATIENT_ID, force
    
    tempfile flag_temp
    save `flag_temp'
    
    use final_novel, clear
    keep PATIENT_ID
    merge 1:1 PATIENT_ID using `flag_temp', keep(master match) nogen
    replace `name' = 0 if missing(`name')
    
    save cov_`name'_novel, replace

end


clear
get_codes_2, name(hyper1) codes($hyper1)

clear
get_codes_2, name(hyper2) codes($hyper2)

clear
get_codes_2, name(hyper3) codes($hyper3)

clear
get_codes_2, name(hyper4) codes($hyper4)

clear
get_codes_2, name(hyper5) codes($hyper5)

clear
get_codes_2, name(hyper6) codes($hyper6)

clear
get_codes_2, name(hyper7) codes($hyper7)

* same for dyslipidemia

global dyslipid1 "E78"
global dyslipid2 "E881"
global dyslipid3 "E7521"
global dyslipid4 "E7522"
global dyslipid5 "E770 E771"

clear
get_codes_2, name(dyslipid1) codes($dyslipid1)

clear
get_codes_2, name(dyslipid2) codes($dyslipid2)

clear
get_codes_2, name(dyslipid3) codes($dyslipid3)

clear
get_codes_2, name(dyslipid4) codes($dyslipid4)

clear
get_codes_2, name(dyslipid5) codes($dyslipid5)


* finally for heart failure, we want to look at hospitalizations only

program define get_codes_3
    syntax, name(string) codes(string)
    
    local where ""
    foreach c of local codes {
        local where "`where' code LIKE '`c'%' OR"
    }
    local where = substr("`where'", 1, length("`where'") - 3)
    
    display "WHERE clause: `where'"

    * search in medical headers where admission date is not null and pull all occurrences of the code with corresponding date
    clear
    odbc load, exec(`"SELECT DISTINCT PATIENT_ID, ADMISSION_DATE, code FROM MEDICAL_HEADERS_LATEST UNPIVOT (code FOR col IN (D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19, D20, D21, D22, D23, D24, D25, D26)) WHERE ADMISSION_DATE IS NOT NULL AND `where'"') dsn("$SNOWFLAKE_DSN")

    * keep only patients in cohort
    merge m:1 PATIENT_ID using final_novel, keep(match) nogen keepusing(PATIENT_ID index_date lookback_date)
    
    keep PATIENT_ID CLAIM_DATE index_date lookback_date
    sort PATIENT_ID CLAIM_DATE
    duplicates drop
    
    local n_total = _N
    display "Total `name' claims: `n_total'"
    
    * keep only claims that occurred during lookback period
    keep if CLAIM_DATE <= index_date & CLAIM_DATE >= lookback_date
    gen `name' = 1
    keep PATIENT_ID `name'
    duplicates drop PATIENT_ID, force
    
    tempfile flag_temp
    save `flag_temp'
    
    use final_novel, clear
    keep PATIENT_ID
    merge 1:1 PATIENT_ID using `flag_temp', keep(master match) nogen
    replace `name' = 0 if missing(`name')
    
    save cov_`name'_novel, replace

end

clear
get_codes_3, name(hf_hosp) codes($hf_hosp)