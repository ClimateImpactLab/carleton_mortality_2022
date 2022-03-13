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

local BRA_raw "$cntry_dir/BRA"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 						PART A. import population data	 					*
*****************************************************************************

* reintialize local to track temporary files
local tempfilenames = ""
forvalues year = 1996/2012 {

	import delimited "`BRA_raw'/Population/age_tot_`year'.csv", ///
		stringcols(_all)  delimit(";") rowrange(4:) varnames(4)  clear

		*drop extranious rows that don't begin with a municipality ID
		keep if regexm(município, "^[0-9][0-9][0-9][0-9][0-9][0-9]")

		* convert population count to numeric
		qui ds município, not
		foreach var in `r(varlist)' {
			replace `var' = "" if `var' == "-"
			destring `var', replace
		}

		* separate mortality numeric ids from municipality name
		gen adm2_source_id = substr(município,1,6)
		gen adm2 = substr(lower(município),8,.)

		* downscale 60 - 69 agegroup to 60-64 & 65-69 using a fixed 44%/55% ratio
		gen a64anos = a69anos * 0.55
		replace a69anos = a69anos * 0.45

		* generate population aggregates for reshape
		rename total population0 
		egen population1 = rowtotal(menor1ano a4anos)
		egen population2 = rowtotal(a9anos a14anos a19anos a29anos a39anos a49anos a59anos a64anos)
		egen population3 = rowtotal(a69anos a79anos anosemais)
		keep adm* population*

		reshape long population, i(adm*) j(agegroup)

		gen year = `year'

		* save files for later append
		local tempfilenames `tempfilenames' y`year'
		tempfile y`year'
		save "`y`year''"

}
 
* append temporary files
clear
foreach flname in `tempfilenames' {
	append using "``flname''"
}

* update county codes for merge w/ mortality data
replace adm2_source_id = "431454" if adm2_source_id == "431453" //affects 2001 & 2002 in Pinto Bandeira

* save for later merge with mortality data
tempfile BRA_population
save "`BRA_population'"


*****************************************************************************
* 						PART B. import mortality data	 					*
*****************************************************************************

/*
File name information (from web scraping script):
	file name format: 0_0_0_0_0_0_0_0.csv
	file name definitions:
		x_0_0_0_0_0_0_0.csv -> 	x=0 (for all files)
		0_x_0_0_0_0_0_0.csv -> 	x=0 (for all files)
		0_0_x_0_0_0_0_0.csv -> 	Location assignment of Death
									0 = Óbitos_p/Residênc (deaths assigned by place of residence)
									1 = Óbitos_p/Ocorrênc (deaths assigned by place of death)
		0_0_0_x_0_0_0_0.csv -> 	year: x = 2013 - year
		0_0_0_0_x_0_0_0.csv -> 	Cause of death:
									0 = Todas as categorias
		0_0_0_0_0_x_0_0.csv -> 	Age group:
									0 = Todas as categorias
									1 = 0 a 6 dias
									2 =	7 a 27 dias
									3 =	28 a 364 dias
									4 = Menor 1 ano (ign)
									5 = 1 a 4 anos
									6 = 5 a 9 anos
									7 = 10 a 14 anos
									8 = 15 a 19 anos
									9 = 20 a 24 anos
									10 = 25 a 29 anos
									11 = 30 a 34 anos
									12 = 35 a 39 anos
									13 = 40 a 44 anos
									14 = 45 a 49 anos
									15 = 50 a 54 anos
									16 = 55 a 59 anos
									17 = 60 a 64 anos
									18 = 65 a 69 anos
									19 = 70 a 74 anos
									20 = 75 a 79 anos
									21 = 80 anos e mais
									22 = Idade ignorada
		0_0_0_0_0_0_x_0.csv -> 	Gender
									0 = Todas as categorias
									1 = Masc
									2 = Fem
									3 = Ign
		0_0_0_0_0_0_0_x.csv -> 	Location of Death
									0 = Todas as categorias
									1 = Hospital
									2 = Outro estabelecimento de saúde
									3 = Domicílio
									4 = Via pública
									5 = Outros
									6 = Ignorado
*/

* reintialize local to track temporary files
local tempfilenames = ""
forvalues year = 1996/2012 {
	forvalues agegrp = 0/22 {

		* import mortality data
		import delimited "`BRA_raw'/Mortality/2_scraping_output/0_0_0_`=2013-`year''_0_`agegrp'_0_0.csv", ///
			stringcols(_all) encoding("utf-8") clear

			* drop extranious observations
			drop if inlist(municiacutepio, "&", "Total")
			
			* clean & standardize annual death measure
			rename total deaths
			replace deaths = "" if deaths == "-"
			destring deaths, replace

			* separate mortality numeric ids from municipality name
			gen adm2_source_id = substr(municiacutepio,1,6)
			
			gen year = `year'

			* generat age group, to be collapse later
			gen agegroup = .
			replace agegroup = 3 if `agegrp' <= 21 		// >= 65
			replace agegroup = 2 if `agegrp' <= 17 		// 5-64
			replace agegroup = 1 if `agegrp' <= 5		// <5
			replace agegroup = 0 if `agegrp' == 0

			*drop deaths where county or agegroup has not been identified
			drop if strmatch(lower(municiacutepio),"*munic&iacute;pio ignorado*")
			drop if mi(agegroup)

			keep adm2_source_id year agegroup deaths

			local tempfilenames `tempfilenames' `year'_`agegrp'
			tempfile `year'_`agegrp'
			save "``year'_`agegrp''"

	}
}

	
* append temporary files
clear 
foreach flname in `tempfilenames' {
	append using "``flname''"
}


* collapse on agegroup year county 
* NOTE: no county-year-agegroup has all missing values 
*	that would be converted to zeros by the collapse
collapse (sum) deaths, by(adm2_source_id year agegroup) 

* merge in population data
merge 1:1 adm2_source_id year agegroup using "`BRA_population'", nogen 

	* convert missing mortality observations to zeros
	* NOTE: there are no zeros in the mortality data, though there is 
	*	also no documentation indicating missing observations are zeros
	replace deaths = 0 if mi(deaths)

	* create deathrate 
	gen deathrate = (deaths / population) * 100000

	* drop 1996 due to incomplete coverage
	drop if year == 1996

	* gen iso code
	gen iso = "BRA"
	gen adm0 = "Brazil"

	* assign adm1 string from gadm shapefile based on adm2 code
	gen adm1 = ""
	replace adm1 = "acre" if substr(adm2_source_id,1,2) == "12"
	replace adm1 = "alagoas" if substr(adm2_source_id,1,2) == "27"
	replace adm1 = "amapá" if substr(adm2_source_id,1,2) == "16"
	replace adm1 = "amazonas" if substr(adm2_source_id,1,2) == "13"
	replace adm1 = "bahia" if substr(adm2_source_id,1,2) == "29"
	replace adm1 = "ceará" if substr(adm2_source_id,1,2) == "23"
	replace adm1 = "distrito federal" if substr(adm2_source_id,1,2) == "53"
	replace adm1 = "espírito santo" if substr(adm2_source_id,1,2) == "32"
	replace adm1 = "goiás" if substr(adm2_source_id,1,2) == "52"
	replace adm1 = "maranhão" if substr(adm2_source_id,1,2) == "21"
	replace adm1 = "mato grosso" if substr(adm2_source_id,1,2) == "51"
	replace adm1 = "mato grosso do sul" if substr(adm2_source_id,1,2) == "50"
	replace adm1 = "minas gerais" if substr(adm2_source_id,1,2) == "31"
	replace adm1 = "paraná" if substr(adm2_source_id,1,2) == "41"
	replace adm1 = "paraíba" if substr(adm2_source_id,1,2) == "25"
	replace adm1 = "pará" if substr(adm2_source_id,1,2) == "15"
	replace adm1 = "pernambuco" if substr(adm2_source_id,1,2) == "26"
	replace adm1 = "piauí" if substr(adm2_source_id,1,2) == "22"
	replace adm1 = "rio de janeiro" if substr(adm2_source_id,1,2) == "33"
	replace adm1 = "rio grande do norte" if substr(adm2_source_id,1,2) == "24"
	replace adm1 = "rio grande do sul" if substr(adm2_source_id,1,2) == "43"
	replace adm1 = "rondônia" if substr(adm2_source_id,1,2) == "11"
	replace adm1 = "roraima" if substr(adm2_source_id,1,2) == "14"
	replace adm1 = "santa catarina" if substr(adm2_source_id,1,2) == "42"
	replace adm1 = "sergipe" if substr(adm2_source_id,1,2) == "28"
	replace adm1 = "são paulo" if substr(adm2_source_id,1,2) == "35"
	replace adm1 = "tocantins" if substr(adm2_source_id,1,2) == "17"


*****************************************************************************
* 			PART C. create ID crosswalk	for climate data merge				*
*****************************************************************************

preserve

	* save list of regions for fuzzy merge
	bysort adm1 adm2_source_id: keep if _n == 1
	keep adm* 

	* create unique id for fuzzy merge
	sort adm1 adm2_source_id
	gen id_using = _n

	tempfile mort_region
	save "`mort_region'"

* import GADM shapefile region names and ids
import delimited "`BRA_raw'/Shapefile/BRA_adm2.csv", clear encoding("utf-8")

	* standardize variable names
	rename id_* adm*_id 
	rename name_* adm*
	keep adm*

	* convert numeric ids to strings
	foreach var of varlist *_id {
		tostring `var', replace
	}

	* convert to lower case
	foreach var of varlist adm? {
		replace `var' = lower(`var')
	}

	* create unique id for fuzzy merge
	sort adm1_id adm2_id
	gen id_master = _n

tempfile gadm_region
save "`gadm_region'"

	* fuzzy merge conditioning on adm1 match 
	reclink adm1 adm2 using "`mort_region'", idmaster(id_master) idusing(id_using) ///
		gen(score) required(adm1) minscore(0) wmatch(1 20)

	* indicator for succesful match
	gen matched = score > 0.89

	* false negative matches (based on reclink score)
	replace matched = 1 if ///					  shp file 					mortality data
		adm1_id	== "27" & adm2_id == "5434" | /// "lajedão" 		vs 		"lajeado"
		adm1_id	== "25" & adm2_id == "4961" | /// "luisiania" 		vs 		"luiziânia"
		adm1_id	== "25" & adm2_id == "4738" | /// "brodosqui" 		vs 		"brodowski"
		adm1_id	== "25" & adm2_id == "4736" | /// "brauna" 			vs 		"braúna"
		adm1_id	== "25" & adm2_id == "4996" | /// "mombaça" 		vs 		"mombuca"
		adm1_id	== "25" & adm2_id == "4809" | /// "dulcinopolis" 	vs 		"dolcinópolis"
		adm1_id	== "25" & adm2_id == "4817" | /// "embu" 			vs 		"embu das artes" see: https://pt.wikipedia.org/wiki/Embu_das_Artes
		adm1_id	== "26" & adm2_id == "5300" | /// "buquim" 			vs 		"boquim"
		adm1_id	== "26" & adm2_id == "5327" | /// "maçambara" 		vs 		"macambira"
		adm1_id	== "24" & adm2_id == "4553" | /// "piçarras" 		vs 		"balneário piçarras" see: https://pt.wikipedia.org/wiki/Balne%C3%A1rio_Pi%C3%A7arras
		adm1_id	== "21" & adm2_id == "3886" | /// "camagua" 		vs 		"camaquã"
		adm1_id	== "21" & adm2_id == "4045" | /// "lajedão" 		vs 		"lajeado"	
		adm1_id	== "21" & adm2_id == "3856" | /// "baro" 			vs 		"barão"
		adm1_id	== "19" & adm2_id == "3582" | /// "campos" 			vs 		"campos dos goytacazes"
		adm1_id	== "17" & adm2_id == "3301" | /// "salidao" 		vs 		"solidão"
		adm1_id	== "14" & adm2_id == "2414" | /// "bagé" 			vs 		"bagre"
		adm1_id	== "17" & adm2_id == "3196" | /// "cabo" 			vs 		"cabo de santo agostinho"
		adm1_id	== "15" & adm2_id == "2741" | /// "seridó" 			vs 		"são vicente do seridó"
		adm1_id	== "13" & adm2_id == "1580" & adm2_source_id == "310320" | /// "aracai" vs "araçaí"
		adm1_id	== "6" & adm2_id == "709"	| /// "itarumã" 		vs 		"itarema"
		adm1_id	== "6" & adm2_id == "700" 	| /// "ipú" 			vs 		"ipu"
		adm1_id	== "13" & adm2_id == "1880" | /// "iaçu" 			vs 		"iapu" 
		adm1_id	== "21" & adm2_id == "3852" // see below

	* manually match a mis-matched municipality
	replace adm2_source_id = "430160" if adm1_id == "21" & adm2_id == "3852"  // "baje" 	vs 	"bagé" 

	* false positive matches
	replace matched = 0 if ///
		adm1_id	== "6" & adm2_id == "781" | ///
		adm1_id	== "24" & adm2_id == "4448" | /// "floriniapolis" vs "florianópolis"
		adm1_id == "15" & adm2_id == "2731" | /// "são josé do belmonte" vs "são josé do brejo do cruz" 
		adm1_id == "12" & adm2_id == "1528" | /// "são félix xingu" vs "são félix do araguaia" 
		adm1_id == "20" & adm2_id == "3794" | /// "são miguel de touros" vs "são miguel do gostoso" 
		adm1_id == "27" & adm2_id == "5468" | /// "ponte alta do norte" vs "ponte alta do tocantins"
		adm1_id == "13" & adm2_id == "2261" // 	  "são francisco de oliveira" vs "são francisco de paula"

	keep if matched
	keep adm1_id adm2_id adm2_source_id

	tempfile gadm_crosswalk
	save "`gadm_crosswalk'"

restore


* merge gadm shp file ids to mortality & population data using crosswalk
* Note: keeping all mortality/population observations, dropping unmatched shp ids
merge m:1 adm2_source_id using "`gadm_crosswalk'", keep(1 3) nogen

* drop unmatched observations
drop if mi(adm2_id)

*************************************************************************
* 				PART D. Import & Merge Income Data 						*			
*************************************************************************

preserve 

	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
		* rename variables to match mortality data
		rename region adm1_income
		rename *gdppc_adm0_PWT* *gdppc_adm0*
		rename *gdppc_adm1_rescaled* *gdppc_adm1*
		
		*standardize string format for merge
		replace adm1_income = lower(adm1_income)

		* only keep rescaled & interpolated income data
		keep if countrycode == "BRA"
		keep adm1_income year *gdppc_adm*
		
		* rename adm1 to match mortality data
		replace adm1_income = "ceará" if adm1_income == "cear"
		replace adm1_income = "espírito santo" if adm1_income == "esprito santo"
		replace adm1_income = "maranhão" if adm1_income == "maranho"
		replace adm1_income = "paraná" if adm1_income == "paran"
		replace adm1_income = "paraíba" if adm1_income == "paraba"
		replace adm1_income = "piauí" if adm1_income == "piau"
		replace adm1_income = "são paulo" if adm1_income == "so paulo"
		
	tempfile income
	save "`income'"	

restore


	* combine adm1 regions to match income data
	gen adm1_income = adm1
	replace adm1_income = "amazonas, mg, mg do sul, rondnia, roraima" if inlist(adm1,"roraima","rondônia","amazonas","mato grosso","mato grosso do sul")
	replace adm1_income = "gois, df, tocantins" if inlist(adm1,"goiás","distrito federal","tocantins")
	replace adm1_income = "par and amap" if inlist(adm1,"pará","amapá")

	* merge in income data
	merge m:1 adm1_income year using "`income'", keep(1 3) assert(2 3) nogen 
	drop adm1_income

*************************************************************************
* 				PART E. Merge Climate Data & save output				*			
*************************************************************************

*merge climate data
merge m:1 adm1_id adm2_id year using "`BRA_raw'/Climate/climate_BRA_1966_2010_adm2.dta", keep(1 3) nogen
merge m:1 adm1_id year using "`BRA_raw'/Climate/climate_BRA_1966_2010_adm1.dta", keep(1 3) nogen

save "`outdir'/BRA_cleaned_merged.dta", replace
