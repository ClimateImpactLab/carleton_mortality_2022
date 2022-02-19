/*=======================================================================

Purpose: 
	1) Imports and cleans mortality data
	2) Merges income data
	3) Merges climate data

==========================================================================*/


*****************************************************************************
* 						PART A. Initializing		 					*
*****************************************************************************

/* global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do" */

local IND_raw "$cntry_dir/IND"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 				PART A. import mortality & population data	 				*
*****************************************************************************

* load cleaned mortality data from source paper
use "`IND_raw'/Mortality/vsi_final_1961.dta", clear

* generate total deaths (original deathrate_total is per 1000 people)
gen deaths = deathrate_total * pop_1961_lvl / 1000

* drop observations missing deaths. Following original paper, this treats
* 	missing observations as truely missing prior to urban/rural collapse 
drop if mi(deaths)

* identify places with both rural and urban & drop region years w/ only one 
bysort state district year id_unique: gen numobs = _N 
bysort state district id_unique: egen maxobs = max(numobs)
drop if numobs == 1 & maxobs == 2
drop numobs maxobs 

* collapse urban and rural observations 
collapse (sum) population=pop_1961_lvl deaths, by(state district year id_unique)

* create mortality rate
gen deathrate = deaths / population * 100000 

* clean up
rename state adm1 
rename district adm2 


*****************************************************************************
* 						PART B. merge income data 		 				*
*****************************************************************************

preserve 
	* import income data 
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
	* rename variables to match mortality data
	rename region adm1
	rename *gdppc_adm0_PWT* *gdppc_adm0*
	rename *gdppc_adm1_rescaled* *gdppc_adm1*

	* only keep rescaled & interpolated income data
	keep if countrycode == "IND"
	keep adm1 year *gdppc_adm*

	* update state names to match 1961 names
	replace adm1 = subinstr(strlower(adm1),"&","and",.)
	replace adm1 = "assam" if adm1 == "assam w/ mizoram"
	replace adm1 = "madras" if adm1 == "tamil nadu" 
	replace adm1 = "mysore" if adm1 == "karnataka"
	replace adm1 = "naga hills-tuensang area" if adm1 == "nagaland"
	replace adm1 = "north east frontier agency" if adm1 == "arunachal pradesh"

	tempfile income
	save "`income'"	

restore

	* merge in income data
	merge m:1 adm1 year using "`income'", keep(1 3) nogen 


*****************************************************************************
* 						PART C. merge in climate data 		 				*
*****************************************************************************

* merge in crosswalk 
merge m:1 id_unique using "`IND_raw'/Shapefile/1961_districts/districts_1961_final_w_iaa_codes.dta", ///
	assert(3) keepusing(statecode_iaa61 districtcode_iaa61 unid) nogen 

* format id 
rename unid UNID 
tostring UNID, replace 

rename statecode_iaa61 adm1_id 
tostring adm1_id, replace 

rename districtcode_iaa61 adm2_id 
tostring adm2_id, replace

* merge
merge m:1 UNID year using "`IND_raw'/Climate/climate_IND_1956_2010_adm2.dta", keep(1 3) nogen
merge m:1 adm1_id year using "`IND_raw'/Climate/climate_IND_1956_2010_adm1.dta", keep(1 3) nogen


*****************************************************************************
* 						PART D. clean-up and save	 		 				*
*****************************************************************************

* gen India specific variables
gen iso = "IND"
gen country = "india" 
gen agegroup = 0

* drop unused variables
drop UNID id_unique

* save output 
save "`outdir'/IND_cleaned_merged.dta", replace

