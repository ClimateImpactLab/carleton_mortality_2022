/*=======================================================================

Purpose: 
	1) Imports and cleans Chile mortality data
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

local CHL_raw "$cntry_dir/CHL"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 					PART A. import comuna ID crosswalk	 					*
*****************************************************************************

* comuna ids changed in 2000, importing id crosswalk
import excel "`CHL_raw'/Mortality/Historico.xls", sheet("DPA2011") firstrow allstring clear 

* clean up 
rename CódigoComunahasta1999 comuna_1999
rename CódigoComunadesde2000 comuna_2000
rename CódigoComunadesde2008 comuna_2008
rename CódigoComunadesde2010 comuna_2010
rename NombreComuna adm2
rename CódigoRegióndesde2000 adm1_id
rename NombreRegióndesde2000 adm1

keep comuna* adm*

tempfile comuna_ids
save "`comuna_ids'"

* more cleaning 
keep comuna_1999 adm2 adm1_id adm1 
rename comuna_1999 adm2_id 

* 4 comuna's divided over the timespan, we collapse to the original comuna extent
replace adm2 = "Santa Bárbara" if adm2 == "Alto Biobío" & adm1 == "Del Bíobío" //https://es.wikipedia.org/wiki/Alto_Biob%C3%ADo
replace adm2 = "Nueva Imperial" if adm2 == "Cholchol" & adm1 == "De La Araucanía" //https://es.wikipedia.org/wiki/Cholchol
replace adm2 = "Talcahuano" if adm2 == "Hualpén" & adm1 == "Del Bíobío" //https://es.wikipedia.org/wiki/Hualp%C3%A9n
replace adm2 = "Iquique" if adm2 == "Alto Hospicio" & adm1 == "De Tarapacá" //https://es.wikipedia.org/wiki/Iquique
duplicates drop

tempfile region_ids
save "`region_ids'"

*****************************************************************************
* 						PART A. import population data	 					*
*****************************************************************************

* import years 1991-2001
import delimited "`CHL_raw'/Population/scrape_1997a2001.csv", clear

* clean up 
rename edad age
keep population age comuna year 
drop if mi(year) 

tempfile pop_97_01
save "`pop_97_01'"

* import years 2002-2020
* NOTE: years 2013-2020 are projections
import excel "`CHL_raw'/Population/Base_2002a2020.xls", sheet("Base_2002a2020_v2") firstrow clear

* clean up 
rename Comuna comuna  
rename Sexo1hombres2mujeres gender 
rename edad age
drop Region nombre_region provincia Nombre_provincia nombre_comuna

* reshape long
reshape long a, i(comuna gender age) j(year)
rename a population
drop if year >= 2013 // death data runs 1997-2013 & 2013+ populations are projected

* append 1997-2001 population
append using "`pop_97_01'"

* standardize ids as strings
tostring comuna, replace

* merge in 1999 comuna IDs 
rename comuna comuna_2010
merge m:1 comuna_2010 using "`comuna_ids'", keep(1 3) nogen
rename comuna_1999 comuna  

* collapse all ages, then append  
preserve 
	gen agegroup = 0 
	collapse (sum) population, by(comuna year agegroup)
	tempfile allage_pop
	save `allage_pop'
restore 

* calculate age group
gen agegroup = 3
replace agegroup = 2 if age < 65
replace agegroup = 1 if age < 5

* collapse to comuna-year-agegroup  
collapse (sum) population, by(comuna year agegroup)

* append all age agegroup 
append using `allage_pop'

tempfile population 
save "`population'"

*****************************************************************************
* 						PART A. import mortality data	 					*
*****************************************************************************

* load mortality data
use "`CHL_raw'/Mortality/defunciones_1997_2013.dta", clear

* convert ids to strings 
tostring comuna, replace

* calculate age
gen age = int((mdy(death_month, death_day, death_year)-mdy(born_month, born_day, born_year))/365.25)
replace age = int((ym(death_year,death_month) - ym(born_year, born_month))/12) if mi(age)
replace age = death_year - born_year if mi(age)
gen year = death_year

* standardize comuna ids using crosswalk
gen comuna_1999 = comuna if year < 2000 
gen comuna_2000 = comuna if year >= 2000 & year < 2008
gen comuna_2008 = comuna if year >= 2008 & year < 2010
gen comuna_2010 = comuna if year >= 2010
merge m:1 comuna_2000 using "`comuna_ids'", update keep(1 3 4 5) nogen keepusing(comuna_1999)
merge m:1 comuna_2008 using "`comuna_ids'", update keep(1 3 4 5) nogen keepusing(comuna_1999)
merge m:1 comuna_2010 using "`comuna_ids'", update keep(1 3 4 5) nogen keepusing(comuna_1999)

* collapse all ages, then append 
gen deaths = 1  
preserve 
	gen agegroup = 0 
	collapse (sum) deaths, by(comuna_1999 year agegroup)
	tempfile allage_mort
	save `allage_mort'
restore 

* calculate age group
drop if mi(age)
gen agegroup = 3
replace agegroup = 2 if age < 65
replace agegroup = 1 if age < 5

* collapse to comuna-year-agegroup
collapse (sum) deaths, by(comuna_1999 year agegroup)

* append all age data 
append using `allage_mort'  

* merge in population data
rename comuna_1999 comuna
merge 1:1 comuna year agegroup using "`population'", nogen 

* drop missing population, only happens in two observation in the artic, where population < ~200 for age group 2
drop if mi(population)

* set missing death data to zero, assuming we infact have the universe of deaths 
replace deaths = 0 if mi(deaths)

* create deathrate 
gen deathrate = (deaths / population) * 100000

* drop if year 2013 since populations are projected
drop if year == 2013

* merge in region name for income merge
rename comuna adm2_id 
merge m:1 adm2_id using "`region_ids'", keep(1 3) nogen 


*************************************************************************
* 				PART D. Import & Merge Income Data 						*			
*************************************************************************

preserve 

	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
	* rename variables to match mortality data
	rename region adm1
	rename *gdppc_adm0_PWT* *gdppc_adm0*
	rename *gdppc_adm1_rescaled* *gdppc_adm1*
	
	*standardize string names for merge
	replace adm1 = "De Aisén del Gral. C. Ibáñez del Campo" if adm1 == "Aisn del General Carlos Ibez del Campo"
	replace adm1 = "De Antofagasta" if adm1 == "Antofagasta"
	replace adm1 = "De Atacama" if adm1 == "Atacama"
	replace adm1 = "De Coquimbo" if adm1 == "Coquimbo"
	replace adm1 = "De La Araucanía" if adm1 == "Araucana"
	replace adm1 = "De Los Lagos" if adm1 == "Los Lagos"
	replace adm1 = "De Magallanes y de La Antártica Chilena" if adm1 == "Magallanes y Antrtica Chilena"
	replace adm1 = "De Tarapacá" if adm1 == "Tarapac"
	replace adm1 = "De Valparaíso" if adm1 == "Valparaso"
	replace adm1 = "Del Bíobío" if adm1 == "Biobo"
	replace adm1 = "Del Libertador B. O'Higgins" if adm1 == "Libertador General Bernardo O'Higgins"
	replace adm1 = "Del Maule" if adm1 == "Maule"
	replace adm1 = "Metropolitana de Santiago" if adm1 == "Regin Metropolitana de Santiago"


	* only keep rescaled & interpolated income data
	keep if countrycode == "CHL"
	keep adm1 year *gdppc_adm*
		
	tempfile income
	save "`income'"	

restore

	* merge in income data
	merge m:1 adm1 year using "`income'", keep(1 3) assert(2 3) nogen 

*************************************************************************
* 				PART E. Merge Climate Data & save output				*			
*************************************************************************

* remove leading zeros from adm1 ids 
replace adm1_id = substr(adm1_id, 2, .) if substr(adm1_id,1,1) == "0"

*merge climate data
merge m:1 adm1_id adm2_id year using "`CHL_raw'/Climate/climate_CHL_1966_2010_adm2.dta", keep(1 3) nogen
merge m:1 adm1_id year using "`CHL_raw'/Climate/climate_CHL_1966_2010_adm1.dta", keep(1 3) nogen

* clean up 
gen iso = "CHL" 
gen adm0 = "Chile"

* save output 
save "`outdir'/CHL_cleaned_merged.dta", replace
