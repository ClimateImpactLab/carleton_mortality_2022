/*

Purpose: Generate table calculating RMSE and other measures of model predictive performance
of an institutional covariate model, institutional covariate model omitting the relevant covariate
(to simulate not being able to project it going forward), and for the main model trimmed to match the
sample available in for the covariate model in question. 

In order to negate the impact of the fixed effects, the code residualizes each variable and runs a 
regression of residualized deathrate on the residualized other variables. 

Together, these generate Appendix Table D4 

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.
- `0_data_cleaning/2_cleaned/institutional_covariates/~.dta` - Cleaned institutional covariate data.


Outputs
-------

- `output/1_estimation/tables/5_diagnostic_specs/rmse_test`
    - ``mod'_rmse_table.csv` -  csv with predictive summary statistics for main model (model speific sample),
    institution model, and institution model with 0s for that covariate.

Notes
-------

- Log file saved in same directory as output
- global `fw_test' set to yes conducts Frisch Waugh test to ensure residualized coeeficients match regression 
ones. Returns error and kills code if test does not pass. 

*/


*****************************************************************************
* 						Please select specs for crossval!					*
*****************************************************************************

* which model will you be running this for (health, edu, or institutions)?
local mod "institutions"


* do you want to use the log of the covariate value (ie logdocpc rather than docpc)? (1 = yes)
loc logvar = 0


* test_code runs with 2% of data (for speed), fw_test runs a test to see if 
* residualized regression coefficients match normal regression coefficients
loc test_code 	"no"

*conduct Fisch Wolde test to make sure residualized regression is working properly
loc fw_test 	"yes"

/* List of model names to be cross-validated and results put in a 
table. Current options are: 

main : temp##agegroup, temp##agegroup##gdppdc, temp##agegroup##lrtemp
mod: temp##agegroup, temp##agegroup##gdppdc, temp##agegroup##lrtemp, temp##agegroup##covar
*/
loc specs 	 "main cov"

*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"


set rmsg on
cap log close

* open output & log files
loc output "$output_dir/tables/Table_D4"

//log using "`output'/logs/log_rmse_test_`mod'.smcl", replace

file open resultcsv using "`output'/`mod'_rmse_table_mean.csv", write replace
file write resultcsv "MODEL, OBS, RMSE, MAE, RHO2, R2" _n


* Merge covariate data and perform model-specific trimming of sample.  
do "$REPO/mortality/1_estimation/1_utils/`mod'_merge.do"

* assigns the covariate name from the merge file
local covar $covar

if `logvar' == 1 {
    loc covar = "log`covar'"
}

* assigns the full model name from the merge file
local ctit $ctit

if `logvar' == 1 {
    loc ctit = "Log `ctit'"
}

local covar "avg_adm0_${covar}"

sum `covar'
loc cov_avg = r(mean)

di "`specs'"



*****************************************************************************
* 						Generating  variables								*
*****************************************************************************
* Note: you cannot demean factorials so we have to create proper vars for 
* each interaction term 

if "`test_code'"=="yes" {
	sample 2
	}

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

		g tavg_poly_`p'_GMFD_`ag'_cov = tavg_poly_`p'_GMFD * agecat`ag' * `covar'
		di "Command finished at $S_TIME"

		* generate covariate interaction terms using a covariate average scalar
		g tavg_poly_`p'_GMFD_`ag'_cov_avg = tavg_poly_`p'_GMFD * agecat`ag' * `cov_avg'


		* collect into locals for the crossval regressions
		loc treatment 		"`treatment' 	tavg_poly_`p'_GMFD_`ag'"
		loc gdp_int			"`gdp_int' 		tavg_poly_`p'_GMFD_`ag'_gdp"
		loc lrt_int 		"`lrt_int'		tavg_poly_`p'_GMFD_`ag'_lrt"
		loc cov_int 		"`cov_int'		tavg_poly_`p'_GMFD_`ag'_cov"
		loc cov_avgs		"`cov_avgs'		tavg_poly_`p'_GMFD_`ag'_cov_avg"	

	}
}


*****************************************************************************
* 						Setting parameters for regression					*
*****************************************************************************

loc controls 	"adm0_agegrp_code##c.prcp_poly_1_GMFD adm0_agegrp_code##c.prcp_poly_2_GMFD"

loc fe 			"adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup"

loc lhs			"deathrate_w99"

* setting model specs

loc main_reg 	"`lhs' `treatment' `gdp_int' `lrt_int'"
di "`main_reg'"

loc cov_reg		"`lhs' `treatment' `gdp_int' `lrt_int' `cov_int'"
di  "`cov_reg'"

loc allvars 	"`lhs' `treatment' `gdp_int' `lrt_int' `cov_int' `cov_avgs'"


*****************************************************************************
* 						De-meaning terms								*
*****************************************************************************

* residualize each variable
foreach var in `allvars' {
	di "reghdfe `var' `controls', absorb(`fe') residuals(`var'_rsd)"
	qui reghdfe `var' `controls', absorb(`fe') residuals(`var'_rsd)
	di "Command finished at $S_TIME"
}



foreach spec in `specs' {

	di "`spec'"

	* rebuild specs

	local `spec'_reg_rsd ""

	foreach var in ``spec'_reg' {
		loc `spec'_reg_rsd 	"``spec'_reg_rsd'	`var'_rsd"
	} 

	di "``spec'_reg_rsd'"


	*****************************************************************************
	* 								Testing code	 							*
	*****************************************************************************
	* use to confirm coefficients from the full regression (fixed effects/controls)
	* match those of residualized regression (according to Frisch Waugh)


	if "`fw_test'" == "yes" {

		di "TESTING TESTING 123: SPEC IS `spec'"

		di "reg ``spec'_reg' `controls', absorb(`fe')"
		reghdfe ``spec'_reg' `controls', absorb(`fe')
		di "Command finished at $S_TIME"
		est store full_reg

		di "reg ``spec'_reg_rsd'"
		reg ``spec'_reg_rsd'
		di "Command finished at $S_TIME"
		est store residualized

		foreach var in ``spec'_reg' {
			if "`var'" ! = "deathrate_w99" {

				qui est rest full_reg
				scal def full_`var' = _b[`var']

				qui est rest residualized
				scal def res_`var' = _b[`var'_rsd]

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



	*****************************************************************************
	* 							Summarize and compare models 					*
	*****************************************************************************

	* use residualized regression
	qui est rest residualized
	
	

	loc len_`spec' = e(N)

	* Gen yhat and resid
	predict yhat_`spec'
	di "Yhat generated"
	predict resid_`spec', res
	di "resids calculated"


	* RMSE 

	gen resid2_`spec' = resid_`spec'^2
	sum resid2_`spec'
	loc rmse_`spec' = sqrt(r(mean))


	* MAE

	gen abs_resid_`spec' = abs(resid_`spec')
	sum abs_resid_`spec'
	loc rmae_`spec' = r(mean)


	* Rho^2 (Squared correlation coefficient)

	qui corr yhat_`spec' deathrate_w99_rsd
	loc rho2_`spec' = r(rho)^2


	* Pseudo R^2 (1-SSR/SST)
	sum deathrate_w99_rsd
	loc den = r(Var)
	sum resid2_`spec'
	loc nummse = r(mean)
	loc r2_`spec' = 1 - `nummse'/`den'

	* write out results
	file write resultcsv "`spec', `len_`spec'', `rmse_`spec'', `rmae_`spec'', `rho2_`spec'', `r2_`spec''" _n


	* set covariate data to 0 so that we can eliminate effects of it's coefficient in prediction
	
	di "replacing var..."

	if "`spec'" == "cov" {

		* set all covar interraction terms equal to 0 to negate effects
		forval ag=1(1)3 {
			forval p=1(1)4 {
				replace tavg_poly_`p'_GMFD_`ag'_cov_rsd = tavg_poly_`p'_GMFD_`ag'_cov_avg_rsd
			}
		}

		di "`covar' set to mean"

		loc spec = "`spec'_0"

		loc len_`spec' = e(N)

		* Gen yhat and resid
		predict yhat_`spec'
		di "Yhat generated"
		predict resid_`spec', res
		di "resids calculated"


		* RMSE 

		gen resid2_`spec' = resid_`spec'^2
		sum resid2_`spec'
		loc rmse_`spec' = sqrt(r(mean))


		* MAE

		gen abs_resid_`spec' = abs(resid_`spec')
		sum abs_resid_`spec'
		loc rmae_`spec' = r(mean)


		* Rho^2 (Squared correlation coefficient)

		qui corr yhat_`spec' deathrate_w99_rsd
		loc rho2_`spec' = r(rho)^2


		* Pseudo R^2 (1-SSR/SST)
		sum deathrate_w99_rsd
		loc den = r(Var)
		sum resid2_`spec'
		loc nummse = r(mean)
		loc r2_`spec' = 1 - `nummse'/`den'

		* write out results
		file write resultcsv "`spec', `len_`spec'', `rmse_`spec'', `rmae_`spec'', `rho2_`spec'', `r2_`spec''" _n


	}

	di "Made it to end of analysis"
}


file close resultcsv
cap log close
