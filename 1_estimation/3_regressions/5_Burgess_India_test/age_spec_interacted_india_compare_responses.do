/*

Purpose: build 'response functions' that are made up of two vectors : a vector of temperature values, and a vector of values indicating death rate changes. Additionally the code will produce 
the confidence interval of the latter vector -- so two additional vectors. 


Inputs
------ 

- regression estimates produced in age_combined_india-response_regressions.do -- that is,
the regression estimates from the India-data only models. In addition, the main model (age specific, covariates-interacted) regression estimates. 

- 'historical average' of the population share of each age category in India. See compute_average_age_share_IND.R

- parameters determining the temperature vector range and resolution, to apply to the response function. 


Outputs
-------

A variety of responses will be computed, identifying a variety of models. The output is in the format of a .dta file that contains an 'x' variable (the temperature values) and a bunch of 'y' variables along with their confidence intervals. Each 'y' variable
identifies a regression model (alternative binned temperature regressions, polynomial temperature regressions, etc).


Important notes
---------------

Two important things need to be mentioned : 1/ the age shares averaging and 2/ the reference temperature chosen. 


1. In order to obtain a unique India-response function from our main model that has three different responses for each age group, we 
average the three latter using age-group-population-share weights. See compute_average_age_share_IND.R for how shares are computed. 

The approach in this code is to build a full expression that is the weighted sum of the age-specific response functions. This expression is then passed to 
'predictnl', which allows you to effectively obtain an averaged response. It is necessary to do that rather than averaging after the prediction, because the latter way doesn't allow us 
to obtain confidence intervals for the average response, while the former way does. 


2. we compute the response to a given temperature as relative to a 'reference' temperature response. For example, the response to a 30C day relative to a 20C day. Here the approach is to use as a 
reference temperature the minimum-mortality-temperature (MMT). Our approach involves two steps : 

	1. The MMT value is the solution to the minimization problem : 

				MMT = argmin(response(T)) for T in [10,30]

	where response(T) is implicitely the response to a {T}C day, relative to a 0C day. 


	2. Then we compute the final response (denoted response*) relative to the MMT : 

				response*(T) = response(T) - response(MMT)


The 'y' value that appears in the final output, the .dta file, is the response function relative to the MMT. 
*/

*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

clear all
set trace off
set more off
set matsize 10000
set maxvar 32700
set processors 24
set scheme s1color


global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local OUTPUT "$output_dir/figures/Figure_D11"

*****************************************************************************
* 						PART 1. Prepare data

* Usually done in prep_data.do but that one drops IND	
*****************************************************************************

use "$DB/0_data_cleaning/3_final/global_mortality_panel", clear

drop if year > 2010

* 1. create winsorized deathrate with-in country-agegroup
bysort iso agegroup: egen deathrate_p99 = pctile(deathrate), p(99)
gen deathrate_w99 = deathrate
replace deathrate_w99 = deathrate_p99 if deathrate > deathrate_p99 & !mi(deathrate)
drop deathrate_p99

* 2. set up sample 
gen sample = 0
replace sample = 1 if iso=="IND"
replace sample = 0 if mi(deathrate_w99)
replace sample = 0 if mi(tavg_poly_1_GMFD)
replace sample = 0 if mi(prcp_poly_1_GMFD)
replace sample = 0 if mi(loggdppc_adm1_avg)
replace sample = 0 if mi(lr_tavg_GMFD_adm1_avg)

keep if sample == 1

* 3. clean up ids
egen adm0_code 			= group(iso)
egen adm1_code 			= group(iso adm1_id)
replace adm2_id 		= adm1_id if iso == "JPN"
egen adm2_code 			= group(iso adm1_id adm2_id)

egen adm0_agegrp_code 	= group(iso agegroup)
egen adm1_agegrp_code	= group(iso adm1_id agegroup)


*************************************************************************
* 							PART 2. numerical parameters				*			
*************************************************************************

* polynomial order of the temperature function
local o = 4

* x values range to compute.
local x_min = -10
local x_max = 45
local precision=1000

*************************************************************************
* 						PART 3. Compute responses						*			
*************************************************************************


local cnt IND
*storing country specific values 
preserve 
*country mean of covariates
bysort year agegroup: egen pop_tot = total(population)
bysort year agegroup: gen weight = population/pop_tot
foreach covariate in lr_tavg_GMFD_adm1_avg loggdppc_adm1_avg {
	sum `covariate' [aw=weight]
	local mean_`covariate'_`cnt' = `r(mean)'			
}
restore 

*load main estimates
local STER "$ster_dir/age_spec_interacted"


*age shares for India. See compute_average_age_share_IND.R
local age_share1 11.828051/100
local age_share2 84.528662/100 
local age_share3 3.643287/100

preserve 

*************************************************************************
* 						PART 3.1 main model								*			
*************************************************************************

* the main model is a polynomial 
* first main model then, no income in one hand, no tbar in the other hand.

foreach model in full no_income no_tbar {

	if "`model'"=="no_income"{
		local mycovariates lr_tavg_GMFD_adm1_avg
		local ster_file_to_use "`STER'/Agespec_interaction_response_`model'.ster"
	}
	else if "`model'"=="no_tbar"{
		local mycovariates loggdppc_adm1_avg	
		local ster_file_to_use "`STER'/Agespec_interaction_response_`model'.ster"	
	} 
	else {
		local mycovariates lr_tavg_GMFD_adm1_avg loggdppc_adm1_avg
		local ster_file_to_use "`STER'/Agespec_interaction_response.ster"
	}

	*erase what's in the data, create a country specific x-variable range
	drop if _n>0
	local myrange = `x_max' - `x_min' + 1
	local points=`myrange'*`precision'
	set obs `points'
	keep tavg_poly_1_GMFD
	replace tavg_poly_1_GMFD =  `x_min' + (_n-1)/`precision'
	gen deathrate_w99=.
	*compute response confidence intervals
	*first, uninteracted terms
	est use "`ster_file_to_use'"
	est replay 

	* a loop that handles finding the minimum mortality temperature and apply it! 
	* first, we set the 'omit' parameter to 0 (this means we compute the MMT for a response relative to a 0C day)
	local omit=0
	* second, the code computes the response with that when the 'reference' iterator is equal to 'noref'. 
	* third, the code finds the minimand of that 0C reference response functino, and it resets 'omit' to be equal to that value. This is the MMT. 
	* fourth, the response is recomputed but with the MMT as a reference temperature, and then the code stores these response values.  

	foreach reference in noref MMT {
		*initializing the model expression
		local line "0"

		foreach age of numlist 1/3 {

			*initializing the age-specific expression to add to the model expression. Will be multiplied by this age's share

			local add_to_line 

			local this_age_share=`age_share`age''

			local add_to_line "_b[`age'.agegroup#c.tavg_poly_1_GMFD]*(tavg_poly_1_GMFD-`omit')"
			foreach k of num 2/`o' {
				local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
				local add_to_line "`add_to_line' `add'"
			}
			*then, interaction with lgdppc and Tmean evaluated at their mean
			foreach covariate in `mycovariates' {
				foreach k of num 1/`o' {
					local add = "+ _b[`age'.agegroup#c.`covariate'#c.tavg_poly_`k'_GMFD] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `mean_`covariate'_`cnt''"
					local add_to_line "`add_to_line' `add'"
				}
			}


			local line "`line' + (`add_to_line')*`this_age_share'"

		}

		*compute prediction
		di "`line'"
		cap drop y_main_av_`cnt'_`model' se_main_av_`cnt'_`model' lowerci_main_av_`cnt'_`model' upperci_main_av_`cnt'_`model'
		predictnl y_main_av_`cnt'_`model' = `line', se(se_main_av_`cnt'_`model') ci(lowerci_main_av_`cnt'_`model' upperci_main_av_`cnt'_`model')

		if "`reference'"=="noref"{
			tempfile to_preserve
			save "`to_preserve'", replace
			keep if tavg_poly_1_GMFD>=10 & tavg_poly_1_GMFD<=30  // we want to find the MMT only withing the [10,30] degree celcius range.
			sort y_main_av_`cnt'_`model'
			list y_main_av_`cnt'_`model' tavg_poly_1_GMFD in 1/50
			sum tavg_poly_1_GMFD if _n==1
			local omit = `r(mean)'
			di "`omit'"
			use "`to_preserve'", clear
			gen ref_main_av_`cnt'_`model'_MMT=`omit'				
		}
	}

	*keep relevant vars
	keep tavg_poly_1_GMFD ref_main_av_`cnt'_`model'_MMT y_main_av_`cnt'_`model' se_main_av_`cnt'_`model' lowerci_main_av_`cnt'_`model' upperci_main_av_`cnt'_`model'
	*save in temporary file
	tempfile tempfile_main_av_`cnt'_`model'
	save "`tempfile_main_av_`cnt'_`model''", replace

}

restore


*************************************************************************
* 						PART 3.2 Country model         					*			
*************************************************************************


*************************************************************************
* 						PART 3.2.1 polynomial model            	    	*			
*************************************************************************

*load country estimates
local STER "$ster_dir/diagnostic_specs"
est use "`STER'/IND_burgess_style_1961_poly_4.ster"
*est use "`STER'/`cnt'_no_interaction.ster"
est replay
*preserve data
preserve

*erase what's in the data, create a high resolution x-variable range
drop if _n>0
local myrange = `x_max' - `x_min' + 1
local points=`myrange'*`precision'
set obs `points'
keep tavg_poly_1_GMFD
replace tavg_poly_1_GMFD =  `x_min' + (_n-1)/`precision'
gen deathrate_w99=.

*compute response confidence intervals
*uninteracted terms only
local omit=0

* a loop that handles finding the minimum mortality temperature and apply it! 
* approach already explained in 3.1, see there. 
foreach reference in noref MMT{

	local line = "_b[c.tavg_poly_1_GMFD]*(tavg_poly_1_GMFD-`omit')"
	foreach k of num 2/`o' {
		local add = "+ _b[c.tavg_poly_`k'_GMFD]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
		local line "`line' `add'"
	}

	di "`line'"
	*compute prediction
	cap drop y_country_`cnt' se_country_`cnt' lowerci_country_`cnt' upperci_country_`cnt'
	predictnl y_country_`cnt' = `line', se(se_country_`cnt') ci(lowerci_country_`cnt' upperci_country_`cnt')

	if "`reference'"=="noref"{
		tempfile to_preserve
		save "`to_preserve'", replace
		keep if tavg_poly_1_GMFD>=10 & tavg_poly_1_GMFD<=30 // we want to find the MMT only withing the [10,30] degree celcius range.
		sort y_country_`cnt'
		list y_country_`cnt' tavg_poly_1_GMFD in 1/50
		sum tavg_poly_1_GMFD if _n==1
		local omit = `r(mean)'
		di "`omit'"
		use "`to_preserve'", clear
		gen ref_country_`cnt'_MMT=`omit'				
	}

}
*keep relevant vars
keep ref_country_`cnt'_MMT tavg_poly_1_GMFD y_country_`cnt' se_country_`cnt' lowerci_country_`cnt' upperci_country_`cnt'

*save in temporary file
tempfile tempfile_country_`cnt'
save "`tempfile_country_`cnt''", replace

restore 



*************************************************************************
* 						PART 3.2.2 binned model            	        	*			
*************************************************************************


foreach binned_version in "burgess" "binnedhd" "binned" {


	* defining the binning and regression schemes. This all depends on what the RHS of the regression is in the ster file ! 

	* starts = vector of bin lowerbounds 
	* ends = vector of bin upperbounds
	* omit = the {omit}-th element of the bin vector will be omitted in the regression and response will be relative to that bin
	* dependentvar = which dependent variable to use in the regression 

	if ("`binned_version'"=="binnedhd"){
		est use "`STER'/`cnt'_no_interaction_bin_33_34_35C.ster"
		local starts -100 -13 -8 -3 2 7 12 17 22 27 32 33 34 35 
		local ends -13 -8 -3 2 7 12 17 22 27 32 33 34 35 100
		local omit=8 
		local dependentvar deathrate_w99	
	} 
	else if ("`binned_version'"=="binned"){
		est use "`STER'/`cnt'_no_interaction_bin_32C.ster"
		local starts -100 -13 -8 -3 2 7 12 17 22 27 32
		local ends -13 -8 -3 2 7 12 17 22 27 32 100
		local omit=8
		local dependentvar deathrate_w99					
	}
	else if ("`binned_version'"=="burgess"){
		est use "`STER'/`cnt'_burgess_style_1961.ster"
		local starts -100 18 21 24 27 30 33 35
		local ends 18 21 24 27 30 33 35 100
		local omit=2
		local dependentvar deathrate_w99
	}
	est replay
	preserve

	*erase what's in the data, create an x-variable range
	drop if _n>0
	local myrange = `x_max' - `x_min' + 1
	local points=`myrange'*`precision'
	set obs `points'
	keep tavg_poly_1_GMFD
	replace tavg_poly_1_GMFD =  `x_min' + (_n-1)/`precision'
	gen `dependentvar'=.
	*create bins and y expression
	local nbins : list sizeof local(starts)
	local y_expression "0"

	forval i=1/`nbins'{
		*i counts the bins, j counts the matrix bin coefficients (that has bins-1 elements!)
		local j = `i'
		if `i'==`omit'{
			*coef of omitted bin set to 0
			local coef`i' = 0
		}
		else {
			*after the omitted bin, matrix counter is bin counter less one
			if `j'>`omit'{
				local j=`j'-1
			}
			local coef`i' = e(b)[1,`j']
		}
		local start`i' : word `i' of `starts'
		local end`i' : word `i' of `ends'			
	}

	forval i=1/`nbins'{
	di "`start`i'' and `end`i''"
	gen bin_`i' = cond(tavg_poly_1_GMFD>=`start`i'' & tavg_poly_1_GMFD < `end`i'', 1, 0)
	local y_expression "`y_expression' + bin_`i'*(`coef`i'')"
	}
	di "`y_expression'"
	*compute prediction
	predictnl y_country_`cnt'_`binned_version' = `y_expression', se(se_country_`cnt'_`binned_version') ci(lowerci_country_`cnt'_`binned_version' upperci_country_`cnt'_`binned_version')


	*keep relevant vars
	keep y_country_`cnt'_`binned_version' se_country_`cnt'_`binned_version' lowerci_country_`cnt'_`binned_version' upperci_country_`cnt'_`binned_version' tavg_poly_1_GMFD

	*save in temporary file
	tempfile tempfile_country_`cnt'_`binned_version'
	save "`tempfile_country_`cnt'_`binned_version''", replace

	restore 		
}



*********************************************************************************************
* 						PART 4. Merge into a single file and save							*			
*********************************************************************************************


*merge into a single dataset. counter is to get the first file.
use "`tempfile_main_av_`cnt'_full'", clear

foreach myfile in "tempfile_main_av_`cnt'_no_income" "tempfile_main_av_`cnt'_no_tbar" "tempfile_country_`cnt'" {
	
	di "`myfile'"
	merge m:1 tavg_poly_1_GMFD using ``myfile''
	drop _merge
}

foreach binned_version in "binnedhd" "binned" "burgess"{
	merge m:1 tavg_poly_1_GMFD using "`tempfile_country_`cnt'_`binned_version''"
	drop _merge
}

save "`OUTPUT'/Agespec_interaction_nointeraction_IND_responses.dta", replace




