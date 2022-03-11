/*

Purpose: Residualize regressions for covar (space) crossval RMSE exercise. Output saved 
in dta format to be used in `rmse_crossval_space.do`.


Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.


Outputs
-------

- `DB/y_diagnostics/covarcrossval`
    - `residualized_series.dta` -  dta file containing residualized series for each term
    in the interacted and uninteracted main models on the full sample. This file merges onto
    the final dataset on the observation level (adm2-agegroup-year)
- `ster_dir/age_spec_interacted/crossval'
	- `Agespec_interacted_residualized_full` - saved output of FW test for interacted model 
	regressing residualized	deathrate on residualized variables (but not controls/fixed effects
	used for demeaning)
	- `Agespec_interacted_residualized_full` - saved output of FW test for uninteracted model 
	regressing residualized	deathrate on residualized variables (but not controls/fixed effects
	used for demeaning)

Notes
-------

- Residualization is done for both the interacted (variable suffix = i) and uninteracted 
(variable suffix = un) models. (suffixes are kept short due to variable max character len).
Residualization has to be done seperately since the uninteracted model is estimated using 
population weights while the interacted model is not.
- Each interaction term has to be generated seperately by multiplying out variables since 
we cannot demean factorials
- In this case, the uninteracted models share the same sets of fixed effects. If for any reason 
that changes, user would have to define a seperate set of controls
- Log file saved in same directory as output
- global `fw_test' set to yes conducts Fisch Wolde test to ensure residualized coeeficients match regression 
ones. Returns error and kills code if test does not pass. 

*/


*****************************************************************************
* 						Please select specs for crossval!					*
*****************************************************************************

/* Enter the list of model names to be cross-validated and results put in a 
table. Current options are: 
unint 		: temp##agegroup
main_int : temp##agegroup, temp##agegroup##gdppdc, temp##agegroup##lrtemp
*/

loc specs 	 "unint main_int"

* test_code runs with 2% of data (for speed), fw_test runs a test to see if 
* residualized regression coefficients match normal regression coefficients
loc test_code "no"

*conduct Fisch Wolde test to make sure residualized regression is working properly
loc fw_test "yes"


*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

//set rmsg on
cap log close

* open output & log files
loc ster "$ster_dir/age_spec_interacted/crossval/"
loc output "$DB/1_estimation/2_crossval/covarcrossval"

log using "`output'/log_rmse_test.smcl", replace


* Prepare data for regressions.
do "$REPO/carleton_mortality_2022/1_estimation/1_utils/prep_data.do"



*****************************************************************************
* 						Generating  variables								*
*****************************************************************************
* Note: you cannot demean factorials so we have to create proper vars for 
* each interaction term 

if "`test_code'" == "yes" {
			sample 2
		}

* generating weights
bysort year agegroup: egen tot_pop = total(population)
gen weight = population / tot_pop

* convert age categories to set of dummies
tab agegroup, gen(agecat)

* interacting all the age groups
forval ag=1(1)3 {

	* with all the polynomial terms and the 2 interaction variables
	forval p=1(1)4 {

		g tavg_poly_`p'_GMFD_`ag' = 	tavg_poly_`p'_GMFD * agecat`ag'
		di "Command finished at $S_TIME"

		g tavg_poly_`p'_GMFD_`ag'_gdp = tavg_poly_`p'_GMFD * agecat`ag' * loggdppc_adm1_avg
		di "Command finished at $S_TIME"

		g tavg_poly_`p'_GMFD_`ag'_lrt = tavg_poly_`p'_GMFD * agecat`ag' * lr_tavg_GMFD_adm1_avg
		di "Command finished at $S_TIME"


		* collect into locals for the crossval regressions
		loc treatment 	"`treatment' 	tavg_poly_`p'_GMFD_`ag'"
		loc gdp_int		"`gdp_int' 		tavg_poly_`p'_GMFD_`ag'_gdp"
		loc lrt_int 	"`lrt_int'		tavg_poly_`p'_GMFD_`ag'_lrt"

	}
}


*****************************************************************************
* 						Setting parameters for regression					*
*****************************************************************************

loc controls 	"adm0_agegrp_code##c.prcp_poly_1_GMFD adm0_agegrp_code##c.prcp_poly_2_GMFD"

loc fe 			"adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup"

loc lhs			"deathrate_w99"


loc unint_reg	"`lhs' `treatment'"
loc main_int_reg 	"`lhs' `treatment' `gdp_int' `lrt_int'"
		

foreach spec in `specs' {

	* setting model weights
	if "`spec'" == "unint" {
		loc weights "[aweight = weight]"
		loc varsfx "un"
	}
	else {
		loc weights ""
		loc varsfx "i"
	}		
	* de-meaning regressions
	loc vars_rsd`varsfx' ""
	foreach var in ``spec'_reg' {

		di "reghdfe `var' `controls' `weights', absorb(`fe') residuals(`var'_rsd`varsfx')"
		qui reghdfe `var' `controls' `weights', absorb(`fe') residuals(`var'_rsd`varsfx')
		loc vars_rsd`varsfx' "`vars_rsd`varsfx'' `var'_rsd`varsfx'"
		di "Command finished at $S_TIME"

	}

*****************************************************************************
* 								Testing code	 							*
*****************************************************************************
* use to confirm coefficients from the full regression (fixed effects/controls)
* match those of residualized regression (according to Frisch Waugh)

	if "`fw_test'" == "yes" {

		di "TESTING TESTING 123"

		di "reg ``spec'_reg' `controls' `weights', absorb(`fe')"
		qui reghdfe ``spec'_reg' `controls' `weights', absorb(`fe')
		di "Command finished at $S_TIME"
		est store full_reg

		di "reg `vars_rsd`varsfx''"
		reg `vars_rsd`varsfx''
		di "Command finished at $S_TIME"
		est save "`ster'/Agespec_`varsfx'nteracted_residualized_full.ster", replace
		est store `varsfx'_residualized

		foreach var in ``spec'_reg' {
			if "`var'" ! = "deathrate_w99" {

				qui est rest full_reg
				scal def full_`var' = _b[`var']

				qui est rest `varsfx'_residualized
				scal def res_`var' = _b[`var'_rsd`varsfx']

				if round(full_`var', .001) == round(res_`var', .001) {
					di "test cleared for `var'."
				}
				else {
					di "test failed for `var'."
					break
				}
			}
		}
	}
}

ds *_rsdi
ds *_rsdun

keep adm2_code year agegroup *_rsdun *_rsdi

save "`output'/residualized_series.dta", replace

cap log close


