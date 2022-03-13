/*=======================================================================

Purpose: 
	1) Imports and cleans USA mortality data
	2) Merges income data
	3) Merges climate data

Note: This file is not run in the clean.do public release version due to 
the mortality data not being publically available

==========================================================================*/


*****************************************************************************
* 						PART A. Initializing		 					*
*****************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local USA_raw "$cntry_dir/USA"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 			PART A. import FIPs code state/county name crosswalk	 		*
*****************************************************************************

* import 2016 fips version 
import excel "`USA_raw'/Shapefile/all-geocodes-v2016.xlsx", cellrange(A5) firstrow allstring clear

* clean up
rename StateCodeFIPS adm1_id 
rename CountyCodeFIPS adm2_id

* save state names 
preserve
	* extract adm1 level crosswalk 
	keep if SummaryLevel == "040"
	rename AreaNameincludinglegalstati adm1 
	keep adm1* 
	tempfile adm1xwalk
	save `adm1xwalk'
restore 

* extract adm2 level crosswalk
keep if SummaryLevel == "050" 
rename AreaNameincludinglegalstati adm2 
keep adm* 

* update id changes and re-merge split regions:
replace adm2 = "Wrangell-Petersburg Census Area" if adm1_id == "02" & inlist(adm2_id,"275","195")
replace adm2_id = "280" if adm1_id == "02" & inlist(adm2_id,"275","195")
replace adm2 = "Skagway-Yakutat-Angoon Census Area" if adm1_id == "02" & inlist(adm2_id,"105","230","282")
replace adm2_id = "231" if adm1_id == "02" & inlist(adm2_id,"105","230","282")
replace adm2_id = "113" if adm1_id == "46" & inlist(adm2_id,"102")
replace adm2 = "Aleutian Islands Census Area" if adm1_id == "02" & inlist(adm2_id,"013","016")
replace adm2_id = "010" if adm1_id == "02" & inlist(adm2_id,"013","016")
replace adm2 = "Yuma County" if adm1_id == "04" & inlist(adm2_id,"012")
replace adm2_id = "027" if adm1_id == "04" & inlist(adm2_id,"012")
replace adm2_id = "270" if adm1_id == "02" & inlist(adm2_id,"158")
replace adm2_id = "201" if adm1_id == "02" & inlist(adm2_id,"198")

* drop duplicates created by mearged regions
duplicates drop 

tempfile adm2xwalk
save `adm2xwalk' 

*****************************************************************************
* 						PART B. import mortality	 						*
*****************************************************************************

* set agegroups for 1968-1998 mortality data:
local agegrp0 NA
local agegrp1 under1 1-4 
local agegrp2 5-9 10-14 15-19 20-24 25-34 35-44 45-54 55-64 
local agegrp3 65-74 75-84 over85

* import year 1968 - 1978:
local jj = 0
foreach yrset in 1968-78 1979-98 { // loop through yearsets
	forvalues ii = 0/3 { // loop through our age groups
		foreach grp in `agegrp`ii'' { // loop through their age groups
			
			* load data (unloaded first column are data notes)
			import delimited "`USA_raw'/Mortality/mortality_1968-1998/cm_`yrset'_`grp'.txt", ///
				delim("\t") colrange(2:) clear

			* drop empty observations
			drop if mi(year)

			* clean-up 
			keep county* year deaths population
			gen agegroup = `ii'

			* convert death & pop to numeric
			foreach var in deaths population {
				cap replace `var' = "" if `var' == "Missing"
				cap replace `var' = "" if `var' == "Not Applicable"
				cap replace `var' = "" if `var' == "Suppressed" //in low population areas
				cap destring `var', replace
			}		

			* save for later append
			tempfile mortfile`jj'
			save `mortfile`jj''

			local ++jj
		}
	}
}

* append datasets
local jj = `jj' - 2
forvalues kk = `jj'(-1)0 {
	append using `mortfile`kk''
}


* collapse all age agegroup (including unknowns) and save for append 
preserve 
	replace agegroup = 0
	egen totaldeaths = total(deaths), by(county* year agegroup) missing
	egen totalpopulation = total(population), by(county* year agegroup) missing
	drop deaths population
	bysort county* year agegroup: keep if _n == 1
	rename total* *
	tempfile old_mort
	save `old_mort'
restore 
 
* drop observations w/ unknow age 
drop if agegroup == 0 

* collapse age catagories to gcp age groups 
* NOTE: observations are uniformly missing withing gcp agegroup 
* so we collapse preserving missing agegroup figures
egen totaldeaths = total(deaths), by(county* year agegroup) missing
egen totalpopulation = total(population), by(county* year agegroup) missing
drop deaths population
bysort county* year agegroup: keep if _n == 1
rename total* *

* append all age agegroup
append using `old_mort'

* more cleaning
drop if county == "Alaska (all counties, 1979-1988)"
drop county 

* add leading zeros to fips code
tostring countycode, replace
replace countycode = "0" + countycode if strlen(countycode) == 4

* split state & county
gen adm2_id = substr(countycode,3,.)
gen adm1_id = substr(countycode,1,2)
drop countycode

* only keep year not covered by more recent data
keep if year <= 1988

tempfile mortpop6888
save `mortpop6888'


* import year 1989-2013 (restricted data, local copy only)
foreach dtrange in 8998 9913 {
	* set directory
	if `dtrange' == 8998 {
		local disk disk1
	}
	else {
		local disk disk2
	} 

	* import population
	import delimited "`restricteddir'/US/DATA/RAW/mortality/`disk'/POP`dtrange'.txt", clear

		* drop national & state totals, keeping only county totals
		drop if substr(v1,-1,1) != "3"

		* extract & format information from file (according to associated data documentation)
		gen adm1_id = substr(v1,1,2)
		gen adm2_id = substr(v1,3,3)
		gen year = substr(v1,6,4)
		destring year, replace

		* set start index by file 
		if `dtrange' == 8998 {
			local kk = 19
		}
		else {
			local kk = 20
		}

		forvalues ii = `kk'(8)116 {
			local groupnum = (`ii'-`kk')/8 + 1
			gen population`groupnum' = substr(v1,`ii',8)
			destring population`groupnum', replace
		}

		* collapse race catagories
		collapse (sum) population* , by(adm1_id adm2_id year)
		 
		* reshape long by age set
		reshape long population, i(adm1_id adm2_id year) j(agecode)

		* collapse all ages & append 
		preserve 
			gen agegroup = 0 
			collapse (sum) population, by(adm1_id adm2_id year agegroup)
			tempfile `disk'_pop
			save ``disk'_pop' 
		restore 

		* covert age sets to gcp age groups
		gen agegroup = 3
		replace agegroup = 2 if agecode <= 10
		replace agegroup = 1 if agecode <= 2
 
		* collapse age sets by gcp age groups, (no missing observations to preserve)
		collapse (sum) population, by(adm1_id adm2_id year agegroup)

		* append all age agegroup 
		append using ``disk'_pop'

	*save or merge
	tempfile pop`dtrange'
	save `pop`dtrange''

	* import mortality 
	import delimited "`restricteddir'/US/DATA/RAW/mortality/`disk'/MORT`dtrange'.txt", clear

		* extract information from file (according to associated data documentation)
		gen adm1_id = substr(v1,1,2)
		gen adm2_id = substr(v1,3,3)
		gen year = substr(v1,6,4)
		* set indexs by file 
		if `dtrange' == 8998 {
			gen agecode = substr(v1,11,2)
			gen deaths = substr(v1,20,4)
		}
		else {
			gen agecode = substr(v1,12,2)
			gen deaths = substr(v1,21,4)
		}
		drop v1

		destring year, replace
		destring agecode, replace
		destring deaths, replace

		* collapse all ages (including unknowns) and save for append 
		preserve 
			gen agegroup = 0 
			collapse (sum) deaths, by(adm1_id adm2_id year agegroup)
			tempfile `disk'_mort 
			save ``disk'_mort'
		restore

		* covert source age sets to gcp age groups
		gen agegroup = . 
		replace agegroup = 3 if agecode <= 16
		replace agegroup = 2 if agecode <= 13
		replace agegroup = 1 if agecode <= 5

		* drop deaths missing age groups
		drop if mi(agegroup)

		* collapse age sets and race categories by gcp age group (no missing observations to preserve)
		collapse (sum) deaths, by(adm1_id adm2_id year agegroup)

		* append all age agegroup 
		append using ``disk'_mort'

		* merge in population 
		merge 1:1 adm1_id adm2_id agegroup year using `pop`dtrange'', assert(2 3) nogen

		* convert missing death deat to zeros (no zeros in raw data)
		replace deaths = 0 if mi(deaths)

	tempfile mortpop`dtrange'
	save `mortpop`dtrange''

}

* append 1968-1988 and 1989-1998 data to 1999-2013 data
append using "`mortpop8998'"  "`mortpop6888'"

* drop non-county observations
drop if adm2_id == "999" //unknown county 
drop if adm2_id == "900" //entire state
drop if adm1_id == "30" & adm2_id == "113" // Yellowstone national park not in shapefile

* update FIPS IDs 
replace adm2_id = "086" if adm1_id == "12" & adm2_id == "025"
replace adm2_id = "019" if adm1_id == "51" & adm2_id == "515"
replace adm2_id = "005" if adm1_id == "51" & adm2_id == "560"
replace adm2_id = "083" if adm1_id == "51" & adm2_id == "780"

* set merged area IDs for collapse (see http://www.statoids.com/yus.html for merge history)
replace adm2_id = "231" if adm1_id == "02" & inlist(adm2_id,"232","282")
replace adm2_id = "070" if adm1_id == "02" & inlist(adm2_id,"164")
replace adm2_id = "010" if adm1_id == "02" & inlist(adm2_id,"013","016")
replace adm2_id = "290" if adm1_id == "02" & inlist(adm2_id,"068")
replace adm2_id = "027" if adm1_id == "04" & inlist(adm2_id,"012")

* collapse merged areas while preserving missing values
egen totaldeaths = total(deaths), by(adm1_id adm2_id year agegroup) missing
egen totalpopulation = total(population), by(adm1_id adm2_id year agegroup) missing
drop deaths population
bysort adm1_id adm2_id year agegroup: keep if _n == 1
rename total* *

* create deathrate 
gen deathrate = (deaths / population) * 100000

* drop regions missing both population (these regions are also missing deaths)
drop if mi(population)

* merge in state and county names
merge m:1 adm1_id using `adm1xwalk', keep(3) assert(2 3) nogen 
merge m:1 adm1_id adm2_id using `adm2xwalk', keep(3) assert(2 3) nogen 

*************************************************************************
* 				PART C. Import & Merge Income Data 						*			
*************************************************************************

preserve 
	* load income data
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
		* rename variables to match mortality data
		rename region adm1
		rename *gdppc_adm0_PWT* *gdppc_adm0*
		rename *gdppc_adm1_rescaled* *gdppc_adm1*

		* only keep rescaled & interpolated income data
		keep if countrycode == "USA"
		keep adm1 year *gdppc_adm*
		
	tempfile income
	save "`income'"	

restore

	* merge in income data
	merge m:1 adm1 year using "`income'", keep(1 3) assert(2 3) nogen 


*************************************************************************
* 				PART D. Merge Climate Data & save output				*			
*************************************************************************

preserve 
	use "`USA_raw'/Climate/climate_USA_1966_2010_adm2.dta", clear
	replace adm1_id = "0" + adm1_id if strlen(adm1_id) == 1
	replace adm2_id = "0" + adm2_id if strlen(adm2_id) == 1
	replace adm2_id = "0" + adm2_id if strlen(adm2_id) == 2
	tempfile USA_clim2
	save `USA_clim2'
restore

preserve 
	use "`USA_raw'/Climate/climate_USA_1966_2010_adm1.dta", clear
	replace adm1_id = "0" + adm1_id if strlen(adm1_id) == 1
	tempfile USA_clim1
	save `USA_clim1'
restore

*merge climate data
merge m:1 adm1_id adm2_id year using "`USA_clim2'", keep(1 3) nogen
merge m:1 adm1_id year using "`USA_clim1'", keep(1 3) nogen

* clean up 
gen iso = "USA"
gen adm0 = "United States"

save "`outdir'/USA_cleaned_merged.dta", replace
