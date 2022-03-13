/*=======================================================================

Purpose: 
	1) Imports and cleans Brazil mortality data
	2) Merges income data
	3) Merges climate data

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

local EU_raw "$cntry_dir/EU/"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 						PART A. import population data	 					*
*****************************************************************************

* import population data
import delimited "`EU_raw'/Mortality/demo_r_d2jan.tsv", delimit(tab) clear

* rename year columns
forvalues ii = 2/29 {
	local yr = 2019 - `ii'
	rename v`ii' population`yr'
}
* drop column names imported in the first rownumb
drop if v1 == "unit,sex,age,geo\time"

* split identifier string variable & clean up var names
split v1, parse(",")
drop v1 v11 
rename v12 sex
rename v13 age
rename v14 NUTS_ID

* only keep population totals across sex
keep if sex == "T"
drop sex

* reshape long
reshape long population, i(NUTS_ID age) j(year)

* strip data issue tags and convert population to numberic
* 	"b" = break in series data 
* 	"p" = provisional data (28 of 693,203 observations in the data)
* 	"e" = estimated (only present in observations outside the timespan of climate data)
foreach ii in b p e c : { // ":" denotes missing in raw data; unclear what "c" denotes
	replace population = subinstr(population,"`ii'","",.)
}
replace population = strtrim(population)
destring population, replace

* drop non-relavent observations
drop if inlist(age,"UNK") // unknown age categories
drop if strmatch(NUTS_ID,"??XX") //unkown region categories
drop if strlen(NUTS_ID) <= 3 // NUTS0 & NUTS1 regions; NUTS formating: CCXY where CC=NUTS0, X=NUTS1, Y=NUTS2
drop if year > 2010 //climate data only runs until 2010


* note: missing values are uniform within region-year
replace age = subinstr(age,"Y","",.)
destring age, gen(agenumeric) force
gen agegroup = 3
replace agegroup = 2 if agenumeric < 65
replace agegroup = 1 if agenumeric < 5 | age == "_LT1" //"LT1" means less than 1
replace agegroup = 0 if age == "TOTAL"

* manually collapse to preserve missing
* 	if all agegroups are missing, then a missing value will 
* 	propogate to the collapsed value, as opposed to the 
* 	-collapse- command that propogates zeros
egen tot_population = total(population), by(NUTS_ID agegroup year) missing
keep NUTS_ID agegroup year tot_population
rename tot_population population 
duplicates drop

* save for merge
tempfile EU_population
save "`EU_population'"


*****************************************************************************
* 						PART B. import mortality data	 					*
*****************************************************************************

*import mortality data
import delimited "`EU_raw'/Mortality/demo_r_magec.tsv", delimit(tab) clear

*rename year columns
forvalues ii = 2/27 {
	local yr = 2017 - `ii'
	rename v`ii' deaths`yr'
}
* drop column names imported in the first rownumb
drop if v1 == "unit,sex,age,geo\time"

* split identifier string variable & clean up var names
split v1, parse(",")
drop v1 v11
rename v12 sex
rename v13 age
rename v14 NUTS_ID

* only keep population totals across sex
keep if sex == "T"
drop sex

* reshape long
reshape long deaths, i(NUTS_ID age) j(year)

* strip data issue tags and convert deaths to numberic
* 	"e" = esitmated (only in observations outside the timespan of climate data)
foreach ii in e : { 
	replace deaths = subinstr(deaths,"`ii'","",.)
}
replace deaths = strtrim(deaths)
destring deaths, replace

* drop non-relavent observations
drop if inlist(age,"UNK") // unknown age categories
drop if strmatch(NUTS_ID,"??XX") //unkown region categories
drop if strlen(NUTS_ID) <= 3 //drop NUTS0 & NUTS1 regions; NUTS formating: CCXY where CC=NUTS0, X=NUTS1, Y=NUTS2
drop if year > 2010 //climate data only runs until 2010

* collapse to age groups
* note: missing values are uniform within region-year
replace age = subinstr(age,"Y","",.)
destring age, gen(agenumeric) force
gen agegroup = 3
replace agegroup = 2 if agenumeric < 65
replace agegroup = 1 if agenumeric < 5 | age == "_LT1" //"LT1" stands for less than 1

replace agegroup = 0 if age == "TOTAL"
 
* manually collapse to preserve missing
* 	if all agegroups are missing, then a missing value will 
* 	propogate to the collapsed value, as opposed to the 
* 	-collapse- command that propogates zeros
egen tot_deaths = total(deaths), by(NUTS_ID agegroup year) missing
keep NUTS_ID agegroup year tot_deaths
rename tot_deaths deaths
duplicates drop 

* merge in population data 
merge 1:1 NUTS_ID year agegroup using "`EU_population'", assert(3) nogen

* drop observations with missing population data 
* NOTE: 370 of 4,128 such observations have non-missing death data
drop if mi(population)

* create deathrate 
gen deathrate = (deaths / population) * 100000

*drop aggregate regions
drop if inlist(NUTS_ID,"EU27","EU28","EFTA")

* drop region-year where all population is assigned to the "_OPEN" age category
drop if (strmatch(NUTS_ID , "EL5*") | strmatch(NUTS_ID, "EL6*")) & year == 1990

*************************************************************************
* 				PART C. Import & Merge Income Data 						*			
*************************************************************************
preserve 

	* import iso-2 to iso-3 crosswalk
	import delimited "$data_dir/1_raw/Income/EU/countries_codes_and_coordinates.csv", clear varnames(1)
	foreach var in alpha2code alpha3code {
		replace `var' = subinstr(`var',`"""',"",.)
		replace `var' = subinstr(`var'," ","",.)
	}
	rename alpha2code iso2 
	rename alpha3code iso 
	rename country adm0 
	keep adm0 iso2 iso

	*update codes to match EU data 
	replace iso2 = "UK" if iso2 == "GB"
	replace iso2 = "EL" if iso2 == "GR"

	duplicates drop iso2 iso, force // duplicates indicate multiple spellings of a country 

	tempfile iso_xwalk 
	save `iso_xwalk'

restore 

* create country string names & merge in country names and alpha-3 iso codes
gen iso2 = substr(NUTS_ID,1,2)
merge m:1 iso2 using "`iso_xwalk'", keep(1 3) nogen 
drop iso2 

gen adm1_id = substr(NUTS_ID,1,3)

*************************************************************************
* 				PART C. Import & Merge Income Data 						*			
*************************************************************************

preserve 
	* load NUTS 1 income data
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
		 * keep only EU data
		 keep if !mi(NUTS_ID)

		* rename variables to match mortality data
		rename NUTS_ID adm1_id
		rename *gdppc_adm0_PWT* *gdppc_adm0*
		rename *gdppc_adm1_rescaled* *gdppc_adm1*

		* only keep rescaled & interpolated income data
		keep adm1_id year *gdppc_adm*
		
	tempfile income_nuts1
	save "`income_nuts1'"	

	* load national level income data for EFTA & candidate countries 
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
		 * keep countries of interest
		 keep if inlist(countrycode,"CHE","ISL","LIE","MNE","TUR")

		* rename variables to match mortality data
		rename countrycode iso 
		rename *gdppc_adm0_PWT* *gdppc_adm0*
		
		* only keep rescaled & interpolated income data
		keep iso year *gdppc_adm0*
		duplicates drop 
		
	tempfile income_adm0
	save "`income_adm0'"	

restore

	* merge in income data
	merge m:1 adm1_id year using "`income_nuts1'", keep(1 3) nogen 
	merge m:1 iso year using "`income_adm0'", update keep(1 3 4) nogen 

*************************************************************************
* 				PART E. Merge Climate Data & save output				*			
*************************************************************************

*merge climate data
merge m:1 NUTS_ID year using "`EU_raw'/Climate/climate_EU_1966_2010_adm2.dta", keep(1 3) nogen
rename NUTS_ID adm2_id

gen NUTS_ID = adm1_id
merge m:1 NUTS_ID year using "`EU_raw'/Climate/climate_EU_1966_2010_adm1.dta", keep(1 3) nogen
drop NUTS_ID
	
save "`outdir'/EU_cleaned_merged.dta", replace

