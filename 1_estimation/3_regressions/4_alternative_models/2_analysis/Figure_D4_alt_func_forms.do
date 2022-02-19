
/*

Purpose: plot the responses coming from age_spec_uninteracted_alternative_model_climate_regressions.do, 
which is shown in Appendix figure D4. 

*/


clear all
set more off
set matsize 10000
set maxvar 32700
set varabbrev on


*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local model "pooled_age_spec_no_interaction"
local OUTPUT "$output_dir/figures/Figure_D4"
local STER "$ster_dir/diagnostic_specs"
* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"


set processors 20

local age = 3 
*****************************************************************************
* 						PART 1. plotting     		 					    *
*****************************************************************************

//sort the panel
sort adm2_code agegroup year
egen id_lag = group(adm2_code agegroup)
tset id_lag year

tempfile MORTALITY_TEMP
save "`MORTALITY_TEMP'", replace

//locals to match Jingyuan spec names
local CY_NewPW "spec1"
local CYA_NewPW "spec2"
local CYA_A1LT_NewPW "spec3"
local FGLS_CYA_NewPW "spec4"
local CYA_13mth_NewPW "spec5"

local min = -5
local max = 40
local x_ticks_min = -5 
local x_ticks_max = 35
local x_ticks_size = 10


*Poly
local o 4
foreach temp in "GMFD" "BEST" {

	estimate use "`STER'/`model'_poly4_`temp'"
	estimates
	mat list e(b)
	mat list e(V)

	*set parameters of the plot (min,max,"ommited temp")		
	local obs = `max' - `min' + 1
	local omit = 20

	preserve
	drop if _n > 0
	set obs `obs'
	replace tavg_poly_1_`temp' = _n + `min' - 1

	local line = "_b[`age'.agegroup#c.tavg_poly_1_`temp'] * tavg_poly_1_`temp' - _b[`age'.agegroup#c.tavg_poly_1_`temp'] * `omit'"
	foreach k of numlist 2/`o' {
		replace tavg_poly_`k'_`temp' = tavg_poly_1_`temp' ^ `k'
		local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_`temp'] * tavg_poly_`k'_`temp' - _b[`age'.agegroup#c.tavg_poly_`k'_`temp'] * `omit'^`k'"
		local line "`line' `add'"
	}
	di "`line'"

	*predict
	predictnl yhat = `line', se(se) ci(lowerci upperci)
	sort tavg_poly_1_`temp'

	*plot with ci
	tw rarea upperci lowerci tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', col(gs12) ///
	|| line yhat tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dknavy) lwidth(medthick) yline(0) ///
	name(g_poly_`o'_`temp', replace) graphregion(color(white)) plotregion(color(white)) ///
	subtitle("Polynomial") legend(off) xlabel(`x_ticks_min'(`x_ticks_size')`x_ticks_max') ytitle("Deaths per 100,000") xtitle("Daily Temperature [C]") ylabel(,nogrid)

	*keeping estiamtes for plotting poly line in other plots
	keep yhat tavg_poly_1_`temp'
	tempfile POLY4_`temp'
	save "`POLY4_`temp''", replace 
	drop yhat
	restore
}

*Bin
local cutoff 32
foreach temp in "GMFD" "BEST" {

	preserve 			

	*load estimates
	estimate use "`STER'/`model'_bins_`temp'"
	estimates
	mat list e(b)
	mat list e(V)

	mat coefs = e(b)
	mat variances = e(V)

	local numbins = 10
	local numbinsplusomitted = `numbins' + 1
	local omittedbin = 8
	local DEPVAR deathrate
	drop *

	*import betas
	svmat coefs
	keep if _n == 1
	keep coefs1-coefs30
	forvalues i = 1/`numbins'{
		*trick : age group `age' is always the `age'th element for each of the ten bins
		local targetvar = `i'*`age'
		gen betas`i'=coefs`targetvar'
	}
	keep betas1-betas`numbins'
	xpose, clear	
	rename v1 betas

	*create blank obs for omitted bin
	set obs `=`numbinsplusomitted''
	replace betas = 0 if _n == _N
	
	*import SEs
	gen se = 0
	forvalues i = 1/`=`numbins'' {
		*same trick as for the betas
		local targetvar = `i'*`age'
		replace se = sqrt(variances[`targetvar',`targetvar']) if _n == `i'
	}
	gen ci_low = betas - se * 1.96
	gen ci_high = betas + se * 1.96

	*ordering bins
	gen bin = `omittedbin' if se==0
	replace bin = 1 in 1
	replace bin = 2 in 2
	replace bin = 3 in 3
	replace bin = 4 in 4
	replace bin = 5 in 5
	replace bin = 6 in 6
	replace bin = 7 in 7
	replace bin = 9 in 8
	replace bin = 10 in 9
	replace bin = 11 in 10
	sort bin

	gen temp = -20  + bin * 5	
	rename temp tavg_poly_1_`temp'
	merge 1:1 tavg_poly_1_`temp' using `POLY4_`temp'', nogen
	sort tavg_poly_1_`temp'
	
	*plot with ci
	tw rarea ci_high ci_low tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', col(gs12) ///
	|| line betas tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dknavy) || ///
	scatter betas tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dknavy) mc(dknavy) ///
	|| line yhat tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dkgreen) lwidth(vthin) yline(0) ///
	name(g_bin_`cutoff'_`temp', replace) graphregion(color(white)) plotregion(color(white)) ylab(, nogrid) ///
	subtitle("Bins") xtitle("Daily Temperature [C]") legend(off) xlabel(`x_ticks_min'(`x_ticks_size')`x_ticks_max') ytitle("")
	restore
}

*Cubic Spline
local set "NS"
foreach temp in "GMFD" "BEST" {

	estimate use "`STER'/`model'_cspline_`temp'"
	estimates
	mat list e(b)
	mat list e(V)
	
	*set parameters of the plot (min,max,"ommited temp")
	local datamin = -15
	local datamax = 40
	local obs = `datamax' - `datamin' + 1
	local omit = 20
	*omit_n is the specific row when temp1 = 20C (or w/a the omit is)
	local omit_n = `omit' - `datamin' + 1

	local k = 8
	local t1 = -12
	local t2 = -7
	local t3 = 0
	local t4 = 10
	local t5 = 18
	local t6 = 23
	local t7 = 28
	local t8 = 33

	*preserve and predict value for the specified range of temperature
	preserve
	drop if _n > 0
	set obs `obs'
	replace tavg_rcspline_term0_`temp' = _n + `datamin' - 1
	local n = `k' - 2

	*Re-generate splines term for the chosen temperatures.
	*The formula of each term is split in 3 (! each part has to be either positive or 0)
	foreach i of num 1/`n' {
		g term`i'_A = tavg_rcspline_term0_`temp' - `t`i''
		replace term`i'_A = 0 if term`i'_A < 0 
		replace term`i'_A = term`i'_A ^ 3				
		local j = `k' - 1
				
		g term`i'_B = tavg_rcspline_term0_`temp' - `t`j''
		replace term`i'_B = 0 if term`i'_B < 0 
		replace term`i'_B = term`i'_B ^ 3	
		replace term`i'_B = term`i'_B * ((`t`k'' - `t`i'') / (`t`k'' -`t`j''))
			
		g term`i'_C = tavg_rcspline_term0_`temp' - `t`k''
		replace term`i'_C = 0 if term`i'_C < 0 
		replace term`i'_C = term`i'_C ^ 3	
		replace term`i'_C = term`i'_C * ((`t`j'' - `t`i'') / (`t`k'' -`t`j''))	
		drop tavg_rcspline_term`i'_`temp'

		*add the 3 pieces
		g tavg_rcspline_term`i'_`temp' = term`i'_A - term`i'_B + term`i'_C
	}

	*loop over the term and save the predict command in a local `line'

	local line = "_b[`age'.agegroup#c.tavg_rcspline_term0_`temp'] * tavg_rcspline_term0_`temp' - _b[`age'.agegroup#c.tavg_rcspline_term0_`temp'] * tavg_rcspline_term0_`temp'[`omit_n']"
	foreach k of num 1/`n' {
		local add = "+ _b[`age'.agegroup#c.tavg_rcspline_term`k'_`temp'] * tavg_rcspline_term`k'_`temp' - _b[`age'.agegroup#c.tavg_rcspline_term`k'_`temp'] * tavg_rcspline_term`k'_`temp'[`omit_n'] "
		local line "`line' `add'"
	}
	di "`line'"

	*predict
	predictnl yhat_csp = `line', se(se_csp) ci(lowerci_csp upperci_csp)
	cap drop tavg_poly_1_`temp'
	rename tavg_rcspline_term0_`temp' tavg_poly_1_`temp'
	sort tavg_poly_1_`temp'
	keep tavg_poly_1_`temp' yhat_csp se_csp lowerci_csp upperci_csp
	merge 1:1 tavg_poly_1_`temp' using `POLY4_`temp'', nogen

	*plot with ci
	tw rarea upperci_csp lowerci_csp tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', col(gs12) ///
	|| line yhat_csp tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc (dknavy) lwidth(medthick) ///
	|| line yhat tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dkgreen) lwidth(vthin) yline(0) ///
	name(g_csp_`set'_`temp', replace) subtitle("Cubic spline") legend(off) xlabel(`x_ticks_min'(`x_ticks_size')`x_ticks_max') ///
	graphregion(color(white)) ytitle("") plotregion(color(white)) xtitle("Daily Temperature [C]") ylabel(,nogrid)

	restore
}

*Linear Spline
local cut 25
foreach temp in "GMFD" "BEST" {
		
	estimate use "`STER'/`model'_lspline_`temp'"
	estimates
		
	*set parameters of the plot (min,max,"ommited temp")
	local datamin = -15
	local datamax = 40
	local obs = `datamax' - `datamin' + 1
	local omit = 20

	preserve
	drop if _n > 0
	set obs `obs'
	replace tavg_poly_1_`temp' = _n + `datamin' - 1
	replace tavg_hdd_0C_`temp' = abs(tavg_poly_1_`temp') if tavg_poly_1_`temp' < 0
	replace tavg_hdd_0C_`temp' = 0 if tavg_poly_1_`temp' >= 0
	replace tavg_cdd_`cut'C_`temp' = tavg_poly_1_`temp' - `cut' if tavg_poly_1_`temp' > `cut'
	replace tavg_cdd_`cut'C_`temp' = 0 if tavg_poly_1_`temp' <= `cut'			

	*predict
	predictnl yhat_lsp = _b[`age'.agegroup#c.tavg_hdd_0C_`temp'] * tavg_hdd_0C_`temp' + _b[`age'.agegroup#c.tavg_cdd_`cut'C_`temp'] * tavg_cdd_`cut'C_`temp', se(se_lsp) ci(lowerci_lsp upperci_lsp)
	sort tavg_poly_1_`temp'
	keep tavg_poly_1_`temp' yhat_lsp se_lsp lowerci_lsp upperci_lsp
	merge 1:1 tavg_poly_1_`temp' using `POLY4_`temp'', nogen

	*plot with ci
	tw rarea upperci_lsp lowerci_lsp tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', col(gs12) ///
	|| line yhat_lsp tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dknavy) lwidth(medthick) ///
	|| line yhat tavg_poly_1_`temp' if tavg_poly_1_`temp'<=`max' & tavg_poly_1_`temp'>=`min', lc(dkgreen) lwidth(vthin) yline(0) ///
	name(g_lsp_`cut'_`temp', replace) subtitle("Linear spline") legend(off) xlabel(`x_ticks_min'(`x_ticks_size')`x_ticks_max') ///
	graphregion(color(white)) plotregion(color(white)) ytitle("") xtitle("Daily Temperature [C]") ylabel(,nogrid)

	restore
}

*graph combine
foreach cat in "g" {
	graph combine `cat'_poly_4_GMFD `cat'_bin_32_GMFD `cat'_csp_NS_GMFD `cat'_lsp_25_GMFD ///
	`cat'_poly_4_BEST `cat'_bin_32_BEST `cat'_csp_NS_BEST `cat'_lsp_25_BEST, ycommon ///
	xsize(20) ysize(10) cols(4) rows(2) graphregion(color(white)) plotregion(color(white))
	graph export "`OUTPUT'/`model'_compare_func_form.pdf", replace
}

set varabbrev off
graph drop _all


