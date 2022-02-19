/*

Purpose: plot the responses computed in age_spec_interacted_india_compare_responses.do : the India response functions for different models, including
their confidence intervals. This also plots the histogram that represents the historical temperature exposure in India. Prodeces Appendix Figure D11


Inputs
------


- user parameters (PART B.) that determine how the plots are made/which plots are made. 

- responses : Agespec_interaction_nointeraction_IND_responses.dta. Note these responses are computed in age_spec_interacted_india_compare_responses.do
based on estimates from age_combined_india-response_regressions.do. 

- temperature exposure in India : tavg_bins_collapsed_IND.dta

Outputs
------

pdf files with response functions and temperature exposure histogram

*/

*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

clear all
set trace off
set more off
set matsize 10000
set maxvar 32700
set processors 20
set scheme s1color


global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local OUTPUT "$output_dir/figures/Figure_D11"
local plot_dir `OUTPUT'


*************************************************************************
* 							PART B. parameters 							*			
*************************************************************************

*parameters determining plotting ?
local average_across_ages = 1 // should I use the average of age specific main models? 
local do_omitted_covariates = 0 //should I plot the 'omitted covariate robustness' main model responses? 
local add_binned =  0 // should I add the binned model?

*if I add the binned model... either "binnedhd" or "binned" or "burgess" (see age_spec_interacted_india_compare_responses.do to see what they mean)
local binned_version = "burgess" 

* some things are incompatible : 
if (!`average_across_ages' & `do_omitted_covariates' | !`average_across_ages' & `add_binned'){
	di "visually bad"
	BREAK
}

* polynomial order of the temperature function
local o = 4

* x-axis ticks
local x_int = 5
*helper counter
local j = 0 

local plot_name_root "Agespec_interaction_nointeraction_IND_plot"
local title_main_root "main"
if (`average_across_ages'){
	local plot_name_root "`plot_name_root'_ageaveraged"
	local title_main_root "`title_main_root' (averaged with age shares)"

}

if (`add_binned'){
	local plot_name_root "`plot_name_root'_`binned_version'"
}

if (`do_omitted_covariates'){
	local plot_name_root "`plot_name_root'_omittedcovar"
	local title_main_root "various `title_main_root'"

}
*******************************************************************************
* 						PART C. Response Plot 								  *			
*******************************************************************************


local cnt IND

use "`OUTPUT'/Agespec_interaction_nointeraction_`cnt'_responses.dta", clear

local j = `j'+1
*x axis range limited to exposure in-sample. 
local x_min_`cnt' = 0
local x_max_`cnt' = 40 

keep if tavg_poly_1_GMFD >= `x_min_`cnt'' & tavg_poly_1_GMFD <= `x_max_`cnt''

preserve 

*country model
*poly4 model
local mymainexpr "(line y_country_`cnt' tavg_poly_1_GMFD, lc(red) lwidth(medthin))"
sum ref_country_`cnt'_MMT
local MMT_country = round(`r(mean)',0.1)
if (`average_across_ages'){
	if (`do_omitted_covariates'){
		local patterns shortdash dash longdash
		foreach model in full no_income no_tbar{	
			local counter=`counter'+1
			local mypattern : word `counter' of `patterns'
			local myexpr "(line y_main_av_`cnt'_`model' tavg_poly_1_GMFD, lc(navy) lwidth(medthin) lpattern(`mypattern'))"
			local mymainexpr "`mymainexpr' `myexpr'"
			sum ref_main_av_`cnt'_`model'_MMT
			local MMT_`model'=round(`r(mean)', 0.1)
		}	
		local legendroot "1 "country model (MMT `MMT_country')" 2 "main model (MMT `MMT_full')" 3 "main w/o income (MMT `MMT_no_income')" 4 "main w/o tbar (MMT `MMT_no_tbar')""
		local legendcount=4
	}
	else {
		local myexpr "(line y_main_av_`cnt'_full tavg_poly_1_GMFD, lc(navy) lwidth(medthin))"
		local mymainexpr "`mymainexpr' `myexpr'"
		local legendroot "1 "country" 2 "main""
		local legendcount=2
	}
}
else {
	local age = 0
	foreach pattern in shortdash dash longdash {
		local age = `age' + 1
		local myexpr`age' "(line y_main_`age'_`cnt' tavg_poly_1_GMFD, lc(navy) lwidth(medthin) lpattern(`pattern'))"
		local mymainexpr "`mymainexpr' `myexpr`age''" 
	}
	local legendcount=4
	local legendroot "1 "country" 2 "0-4" 3 "5-64" 4 "65+""

}

if (`add_binned'){
	local mymainexpr "`mymainexpr' (line y_country_`cnt'_`binned_version' tavg_poly_1_GMFD, lc(red) lpattern(shortdash) lwidth(medthin))"
	local legendcount = `legendcount'+1
	local legendroot "`legendroot' `legendcount' "country model - binned""
}

*poly 4 model confidence intervals
local mymainexpr "`mymainexpr' (rarea lowerci_country_`cnt' upperci_country_`cnt' tavg_poly_1_GMFD, col(red%15))"


local aest1 "yline(0, lcolor(gs5) lwidth(vthin))"
local aest2 "xtitle("") xlabel(`x_min_`cnt''(`x_int')`x_max_`cnt'', labsize(small)) ylab(, nogrid) plotregion(icolor(white) lcolor(black))"
local aest3 "graphregion(color(white)) legend(order(`legendroot') size(*0.6) symxsize(*0.3)) ylabel(, labsize(small) angle(horizontal))"
local aest4 "ytitle("difference in mortality", size(vsmall))"

di "`mymainexpr'"
twoway `mymainexpr', xscale(range(0 40)) `aest1' `aest2' `aest3' `aest4' name("myresponse")


*****************************************************************
* 						PART D. Temperature Histogram							*			
*****************************************************************



di "`OUTPUT'/tavg_bins_collapsed_IND.dta"
use "`OUTPUT'/tavg_bins_collapsed_IND.dta", clear

keep if bin>=0 & bin<=40

list bin

graph twoway bar value bin if bin>=0 & bin<=40, xscale(range(0 40)) xlabel(0(5)40) color(navy) ytitle("number of days in a year", size(vsmall)) xtitle("temperature bin") name("myhist", replace)


*****************************************************************
* 						PART E. Combine + save    				*			
*****************************************************************

graph combine myresponse myhist, cols(1) xcommon title("India interacted model versus country model", size(small))
local plot_name "`plot_name_root'.pdf"
graph export "`plot_dir'/`plot_name'", replace 
