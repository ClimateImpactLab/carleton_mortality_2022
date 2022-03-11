/*

Purpose: Processes ADM2-level monthly climate data for each country in the
mortality estimation panel. 

Note that LR temp (Tbar) is calculated at the ADM1 level

1) Imports country-specific datasets containing ADM2-level transformations
of GMFD, BEST, or UDEL gridded climate data.

2) Merges together various climate variables, including 1-degree bins,
polynomial transformations, and restricted cublic spline terms.

3) Generates moving 30 year bartlett kernel averages of climate data for model
covariates.

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
* 			PART B. Import climate data, reshape, and merge				*			
*************************************************************************

// Set climate datasets to clean
local clim_data "BEST" "GMFD" "UDEL"

*set climate transformations to load
*create 1C bin list
local mybins = ""
forvalues ii = -40(1)34 {
	local jj = `ii' + 1
	local mybins `mybins' bins_`ii'C_`jj'C
}
local mybins = subinstr("`mybins'","-","n",.)

#delimit ;
local prcp_trans 	poly_1 poly_2 poly_3 poly_4 poly_5 ;
local tmax_trans	cdd_0C hdd_25C ;
local tavg_trans 	poly_1 			poly_2 			poly_3 				poly_4 				poly_5 
					bins_nInf_n40C 	`mybins' 		bins_35C_Inf		rcspline_term0 		rcspline_term1	
					rcspline_term2	rcspline_term3	rcspline_term4		rcspline_term5 		rcspline_term6 ;
#delimit cr

* loop through countries
foreach iso in $ISO {	 
	local climdir "$cntry_dir/`iso'/Climate"
	local baseyear = 1965

	*set identifiers
	local id_cols "ID_0 ID_1 ID_2"
	if "`iso'" == "CHN" {
		local id_cols "CITYGB CNTYGB"
	}
	else if "`iso'" == "EU" {
		local id_cols "NUTS_ID"
	}
	else if "`iso'" == "CHL" {
		local id_cols "adm1_id adm2_id"
	}
	else if "`iso'" == "JPN" {
		local id_cols "ID_0 ID_1"
	}
	else if "`iso'" == "MEX" {
		local id_cols "GEOID"
	}
	else if "`iso'" == "IND" {
		local id_cols "UNID"
		local baseyear = 1955
	}
  	
 	*reshape transformations 
	local ii = 0
	foreach param in tavg tmax prcp {	
		foreach trans in ``param'_trans' {
			foreach clim in `clim_data' {				
				* BEST does not have prcp
				if ("`param'" == "prcp" & "`clim'" == "BEST") | (inlist("`param'","tmax","tavg") & "`clim'" == "UDEL") {
					continue
				}

				* import climate variable
				import delimited using "`climdir'/adm2/weather_data/csv_monthly/`clim'_`param'_`trans'_v2_`baseyear'_2010_monthly_popwt.csv", ///
					case(preserve) encoding("utf-8") clear

				* reshape to region-year observation unit
				qui reshape long y@_m01 y@_m02 y@_m03 y@_m04 y@_m05 y@_m06 y@_m07 y@_m08 y@_m09 y@_m10 y@_m11 y@_m12, ///
					i(`id_cols') j(year)

				* merge previous year's december to current year for 13 month specification 
				preserve 
					keep `id_cols' year y_m12
					replace year = year + 1
					rename y_m12 y_m12_prev
					drop if year == 2011
					tempfile `iso'_`ii'_dec
					save ``iso'_`ii'_dec'
				restore 

				* drop unmatched year (prior to all mortality observations) & merge
				drop if year == `baseyear'
				qui merge 1:1 `id_cols' year using "``iso'_`ii'_dec'", assert(3) nogen

				* calculate year totals
				egen `param'_`trans'_`clim' = rowtotal(y_m??), missing
				egen `param'_`trans'_`clim'_13m = rowtotal(y_m*), missing


				* set year totals to missing if any month is missing 
				egen monthmis = rowmiss(y_m??)
				egen monthmis_13m = rowmiss(y_m*)
				replace `param'_`trans'_`clim' = . if monthmis > 0
				replace `param'_`trans'_`clim'_13m = . if monthmis_13m > 0

				* drop month variables 
				drop y_m* monthmis* 

				* save for later merge
				tempfile `iso'_`ii'
				save ``iso'_`ii''

				local ++ii
			}
		}
	}

	*merge all tempary files together and save
	use ``iso'_0', clear
	local --ii
	forvalues jj = 1/`ii' {
		merge 1:1 `id_cols' year using ``iso'_`jj'', nogen 
	}

	* standardize id format
	foreach var of varlist `id_cols' {
		tostring `var', replace
	}
	cap rename ID_* adm*_id
	cap drop adm0_id

	local yr = `baseyear' + 1
	* ouput one file per country
	save "`climdir'/climate_`iso'_`yr'_2010_adm2.dta", replace
}

*************************************************************************
* 					PART C. Import adm1-level Tbar						*			
*************************************************************************
*set climate transformations to load
local tavg_trans 	poly_1 
local tmax_trans	cdd_20C hdd_20C

* loop through countries
foreach iso in $ISO { 
	local climdir "$cntry_dir/`iso'/Climate"
	local baseyear = 1965

	*set identifiers
	local id_cols "ID_0 ID_1"
	if "`iso'" == "CHN" {
		local id_cols "PROVGB"
	}
	else if "`iso'" == "EU" {
		local id_cols "NUTS_ID"
	}
	else if "`iso'" == "CHL" {
		local id_cols "adm1_id"
	}
	else if "`iso'" == "JPN" {
		local id_cols "ID_0 ID_1"
	}
	else if "`iso'" == "MEX" {
		local id_cols "adm1_id"
	}
	else if "`iso'" == "IND" {
		local id_cols "adm1_id"
		local baseyear = 1955
	}
  	
 	* reshape transformations 
	local ii = 0
	foreach param in tavg tmax {	
		foreach trans in ``param'_trans' {
			foreach clim in BEST GMFD UDEL {				
				* BEST does not have prcp
				if ("`param'" == "prcp" & "`clim'" == "BEST") | (inlist("`param'","tmax","tavg") & "`clim'" == "UDEL") {
					continue
				}

				import delimited using "`climdir'/adm1/weather_data/csv_yearly/`clim'_`param'_`trans'_v2_`baseyear'_2010_yearly_popwt.csv", ///
					case(preserve) encoding("utf-8") clear

				rename y* `param'_`trans'_`clim'*
				qui reshape long `param'_`trans'_`clim', i(`id_cols') j(year)

				tempfile `iso'_`ii'
				save ``iso'_`ii''

				local ++ii
			}
		}
	}

	* merge all tempary files together and save
	use ``iso'_0', clear
	local --ii
	forvalues jj = 1/`ii' {
		merge 1:1 `id_cols' year using ``iso'_`jj'', nogen 
	}


	* generate moving 30 year bartlett kernel averages
	bkern "`id_cols'" year y 1 "tavg_poly_1_BEST tavg_poly_1_GMFD" 30
	
	* standardize variable names
	rename tavg_poly_1_*_30br lr_tavg_*_adm1_30br
	rename tavg_poly_1_* tavg_*_adm1
	rename tmax_* tmax_*_adm1

	* get daily averages
	foreach var of varlist lr_tavg_*_30br tavg_* {
		replace `var' = `var' / 365
	}
	
	* standardize id format
	foreach var of varlist `id_cols' {
		tostring `var', replace
	}
	cap rename ID_* adm*_id
	cap drop adm0_id

	* drop year to match adm2 level climate 
	drop if year == `baseyear'

	* ouput one file per country
	local yr = `baseyear' + 1
	save "`climdir'/climate_`iso'_`yr'_2010_adm1.dta", replace
}
