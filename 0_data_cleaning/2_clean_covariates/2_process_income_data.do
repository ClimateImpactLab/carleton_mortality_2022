/*

Purpose: Generates income covariates for regression models.

1) Downscales Penn World Tables country-level income data to the ADM1-level
using subnational incomes from Eurostat and Gennaioli et al (2014). (See
Appendix B.3.1).

2) Generates moving 13-year bartlett kernal averages for model covariates.

Note: Income values output by this script are in constant 2005$ PPP.

*/


*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

*************************************************************************
* 				PART B. Import Pen World Tables Data					*			
*************************************************************************

* import Penn World Tables Country-level data 
use "$data_dir/1_raw/Income/PennWorldTables/pwt90.dta", clear

* get the inflation factor
preserve
	keep if countrycode == "USA" & year == 2005
	local price_level = pl_gdpo
restore

* cleanup
gen gdppc_adm0_PWT = `price_level' * rgdpna/pop 
keep countrycode country year gdppc_adm0_PWT 
drop if gdppc_adm0_PWT  == .

tempfile pwt 
save `pwt'


*************************************************************************
* 			PART C. Import La Porta Data & interpolate					*			
*************************************************************************

* import
import delimited "$data_dir/1_raw/Income/LaPorta/Gennaioli2014_full.csv", clear

* housekeeping
rename code countrycode 
keep countrycode country region year gdppc*

* set max year as 2014
local new = _N + 1
set obs `new'
replace year = 2014 if year == .
replace countrycode = "ALB" if year == 2014
replace region = "Berat" if year == 2014
replace country = "Albania" if year == 2014

* fill in the panel
egen pid = group(countrycode country region) 
preserve 
	bysort pid: keep if _n == 1
	keep pid country* region 
	tempfile identifier_xwalk
	save `identifier_xwalk'
restore 
xtset pid year
tsfill, full 
merge m:1 pid using `identifier_xwalk', update assert(3 4) nogen 

* binary for having existing data 
gen insample = !mi(gdppccountry)

* flat interpolation of state income 
sort pid year 
by pid: gen yearset = sum(insample)
bysort pid yearset: gen gdppc_adm0_LaPorta_infill = gdppccountry[1]
bysort pid yearset: gen gdppc_adm1_LaPorta_infill = gdppcstate[1]

* merge "Germany" WDI data to "Germany, east" & "Germany, west"
replace countrycode = "DEU" if countrycode == "BRD" | countrycode == "DDR"

* clean-up 
rename gdppccountry gdppc_adm0_LaPorta
rename gdppcstate gdppc_adm1_LaPorta
keep countrycode country region year *LaPorta*

* save 
tempfile laporta 
save `laporta'


*************************************************************************
* 			PART C. Import EU data to get rescale factors				*			
*************************************************************************

* import iso-2 to iso-3 crosswalk
import delimited "$data_dir/1_raw/Income/EU/countries_codes_and_coordinates.csv", clear varnames(1)
foreach var in alpha2code alpha3code {
	replace `var' = subinstr(`var',`"""',"",.)
	replace `var' = subinstr(`var'," ","",.)
}
rename alpha2code iso2 
rename alpha3code iso3 
keep country iso2 iso3

*update codes to match EU data 
replace iso2 = "UK" if iso2 == "GB"
replace iso2 = "EL" if iso2 == "GR"

duplicates drop iso2 iso3, force // duplicates indicate multiple spellings of a country 

tempfile iso_xwalk 
save `iso_xwalk'

* import NUTS_2 gdppd and create downscaling factor to 
* 	apply to Penn world tables national figures
import delimited "$data_dir/1_raw/Income/EU/nama_10r_2gdp.tsv", delimit(tab) clear

* rename year columns
forvalues ii = 2/18 {
	local yr = 2018 - `ii'
	rename v`ii' gdppc`yr'
}

* drop column names imported in the first rownumb
drop if v1 == "unit,geo\time"

* split identifier string variable & clean up var names
split v1, parse(",")
rename v11 unit 
rename v12 NUTS_ID

* keep purchasing power parity units (to enable comparison w/in year)
keep if unit == "PPS_HAB" // "PPS_HAB" = Purchasing power standard (PPS) per inhabitant
drop unit v1 

* reshape into a standard format
reshape long gdppc, i(NUTS_ID) j(year)

* convert gdppc to numeric 
replace gdppc = subinstr(gdppc," ","",.)
replace gdppc = subinstr(gdppc,":","",.)
replace gdppc = subinstr(gdppc,"e","",.) //ie. use estimate figures
destring gdppc, replace

* merge national figures with subnational
preserve 
	keep if strlen(NUTS_ID) == 2
	rename NUTS_ID iso2
	rename gdppc national_gdppc 
	tempfile NUTS0
	save `NUTS0'
restore 

keep if strlen(NUTS_ID) == 3
gen iso2 = substr(NUTS_ID,1,2)
merge m:1 iso2 year using `NUTS0', assert(3) nogen 

* create anual ratio of nuts1 to nuts0 gdppc
gen gdppc_ratio_year = gdppc / national_gdppc

* average across years (while preserving missing values) 
egen scalefactor = mean(gdppc_ratio_year), by(NUTS_ID) 

* merge in alpha-3 iso codes 
merge m:1 iso2 using "`iso_xwalk'", assert(2 3) keep(3) nogen

* keep only the mean ratio 
keep iso3 NUTS_ID country scalefactor
duplicates drop 
rename iso3 countrycode 

* expand to match pwt years
expand = 55
bysort NUTS_ID: gen year = 1959 + _n 


*************************************************************************
* 						PART D. Merge & rescale							*			
*************************************************************************

* append la_porta data
* NOTE: we keep overlapping observations between Eurostat and LaPorta,
* 	as indicated by the separete identifiers 
append using `laporta'

* merge in PWT data 
merge m:1 countrycode year using `pwt', nogen 

* rescale 
replace scalefactor = gdppc_adm1_LaPorta_infill / gdppc_adm0_LaPorta_infill if mi(scalefactor)
gen gdppc_adm1_rescaled = gdppc_adm0_PWT * scalefactor

* clean up 
label var gdppc_adm0_LaPorta "raw ADM0 level income data from la porta"
label var gdppc_adm1_LaPorta "raw ADM1 level income data from la porta"
label var gdppc_adm0_LaPorta_infill "interpolated ADM0 level income data from la porta"
label var gdppc_adm1_LaPorta_infill "interpolated ADM0 level income data from la porta"
label var gdppc_adm0_PWT "ADM0 level income data from PWT"
label var gdppc_adm1_rescaled "PWT downscaled to from la porta subnational income"
label var region "La Porta region name"
label var NUTS_ID "NUTS1 identifier"
label var countrycode "alpha-3 iso code"

drop scalefactor 
drop *LaPorta* 


*************************************************************************
* 					PART E. Calculate Moving averages					*			
*************************************************************************

* create log income
gen loggdppc_adm0_PWT = ln(gdppc_adm0_PWT)
gen loggdppc_adm1_rescaled = ln(gdppc_adm1_rescaled)

* generate moving 13 year bartlett kernal averages
bkern "countrycode region NUTS_ID" year y 1 "gdppc_adm0_PWT loggdppc_adm0_PWT gdppc_adm1_rescaled loggdppc_adm1_rescaled" 13
 
* drop empty observations
drop if mi(gdppc_adm0_PWT) & mi(gdppc_adm1_rescaled)

* save output
save "$data_dir/1_raw/Income/pwt_income_adm1.dta", replace

