/*

Purpose: Plot the preferred age specific non interacted response functions
along with the age-pooled prefered model. This is Figure D3 in the Appendix

Inputs
------

- `data/1_estimation/1_ster/age_spec`
	- `Agespec_response_spec*.ster`

Outputs
-------

- `output/1_estimation/figures/10_age_spec_uninteracted_response"`
	- Figure_D3_age_spec_response_with_combined.pdf

*/


*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local ster "$ster_dir"
local output_dir "$OUTPUT/figures/Figure_D3_response_functions"
* Prepare data for regressions.
use "$data_dir/3_final/global_mortality_panel_covariates.dta", clear

*****************************************************************************************
* 						Set Params           		                *
*****************************************************************************************

local min = -5
local max = 40
local x_tick_min = -5
local x_tick_max = 35
local x_tick_size = 10



*************************************************************************************************************
* 						Plot with point estimate of the all age               		                *
*************************************************************************************************************



foreach temp in "GMFD" {
	foreach o of numlist 4/4 {
		// using preferred specification, see "Inputs" in header.
		foreach spe in spec2 {

			preserve 
			
			estimate use "`ster'/age_spec/Agespec_response_`spe'.ster"
			estimates		
			local ster "$ster_dir"
			*set parameters of the plot (min,max)
			local obs = `max' - `min' + 1
			local omit_1 = 20
			local omit_2 = 20
			local omit_3 = 20
			local omit = 20

			drop if _n > 0
			set obs `obs'
			replace tavg_poly_1_`temp' = _n + `min' - 1

			foreach grp in "1" "2" "3" {
				local line = "_b[`grp'.agegroup#c.tavg_poly_1_`temp'] * tavg_poly_1_`temp' - _b[`grp'.agegroup#c.tavg_poly_1_`temp'] * `omit_`grp''"
				foreach k of num 2/`o' {
					replace tavg_poly_`k'_`temp' = tavg_poly_1_`temp' ^ `k'
					local add = "+ _b[`grp'.agegroup#c.tavg_poly_`k'_`temp'] * tavg_poly_`k'_`temp' - _b[`grp'.agegroup#c.tavg_poly_`k'_`temp']  * `omit_`grp''^`k'"
					local line "`line' `add'"
				}
				predictnl yhat_`grp' = `line', se(se_`grp') ci(lowerci_`grp' upperci_`grp')
			}
			keep tavg_poly_1_`temp' yhat*
			tempfile agespe
			save `agespe'

			restore 

			preserve 
			
			estimate use "`ster'/age_combined/pooled_response_`spe'.ster"
			estimates		

			drop if _n > 0
			set obs `obs'
			replace tavg_poly_1_`temp' = _n + `min' - 1

			local line = "_b[tavg_poly_1_`temp'] * tavg_poly_1_`temp' - _b[tavg_poly_1_`temp'] * `omit'"
			foreach k of num 2/`o' {
				replace tavg_poly_`k'_`temp' = tavg_poly_1_`temp' ^ `k'
				local add = "+ _b[tavg_poly_`k'_`temp'] * tavg_poly_`k'_`temp' - _b[tavg_poly_`k'_`temp'] * `omit'^`k'"
				local line "`line' `add'"
			}
			predictnl yhat = `line', se(se) ci(lowerci upperci)
			sort tavg_poly_1_`temp'
			merge 1:1 tavg_poly_1_`temp' using `agespe'
			keep tavg_poly_1_`temp' yhat* upper* lower*
			
			*plot
			tw rarea upperci lowerci tavg_poly_1_`temp', col(gs13) ///
			|| line yhat_1 tavg_poly_1_`temp', lw(medthick) lc(dkgreen) ///
			|| line yhat_2 tavg_poly_1_`temp', lw(medthick) lc(navy) ///
			|| line yhat_3 tavg_poly_1_`temp', lw(medthick) lc(maroon) ///
			|| line yhat tavg_poly_1_`temp', lw(medthick) lc(black) ///
			yline(0, lcolor(red) lwidth(vthin)) ///
			legend(order(2 3 4 5) lab(2 "age <5") lab(3 "age 5-64") lab(4 "age >64") lab(5 "all age") rows(1) region(color(white))) ///
			ytitle("Deaths per 100,000") xlabel(`x_tick_min'(`x_tick_size')`x_tick_max') ylabel(-2(2)8, nogrid) ///
			xtitle("Temperature (°C)") ///
			plotregion(color(white)) graphregion(color(white))
			graph export "`output_dir'/Age_spec_response_with_combined.pdf", replace


			restore 
		}
	}
}
