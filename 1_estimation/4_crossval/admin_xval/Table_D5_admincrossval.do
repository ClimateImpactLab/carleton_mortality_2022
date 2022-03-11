*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

* Prepare data for regressions.
do "$REPO/carleton_mortality_2022/1_estimation/1_utils/prep_data.do"

* Get crossval function.
do "$REPO/carleton_mortality_2022/1_estimation/1_utils/crossval_function.do"

set rmsg on
cap log close

* open output & log files
loc data "$base_dir/2_crossval/admincrossval"
loc output "$output_dir/tables/Table_D5_crossval"

//log using "`output'/logs/log_admincrossval.smcl", replace

file open resultcsv using "`output'/admincrossval_table.csv", write replace
file write resultcsv "MODEL, RMSE, MAE, RHO2, R2" _n

*****************************************************************************
* 						Please select specs for crossval!					*
*****************************************************************************

/* Enter the list of model names to be cross-validated and results put in a 
table. Current options are: 
unint 		: temp##agegroup
gdp_int 	: temp##agegroup, temp##agegroup##gdppdc
lrt_int 	: temp##agegroup, temp##agegroup##lrtemp
gdp_lrt_int : temp##agegroup, temp##agegroup##gdppdc, temp##agegroup##lrtemp
*/
gl specs 	 "unint gdp_int lrt_int gdp_lrt_int"

* test_code runs with 1% of data (for speed), fw_test runs a test to see if 
* residualized regression coefficients match normal regression coefficients
gl test_code "no"
gl fw_test 	 "yes"

*****************************************************************************
* 						Generating  variables								*
*****************************************************************************
* Note: you cannot demean factorials so we have to create proper vars for 
* each interaction term 

if "${test_code}"=="yes" {
			sample 1
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

* setting model specs
loc unint_reg	 	"`lhs' `treatment'"
loc gdp_int_reg	 	"`lhs' `treatment' `gdp_int'"
loc lrt_int_reg 	"`lhs' `treatment' `lrt_int'"
loc gdp_lrt_int_reg "`lhs' `treatment' `gdp_int' `lrt_int'"

foreach spec in $specs {

	*****************************************************************************
	* 						De-meaning regressions								*
	*****************************************************************************

	* setting model weights
	if "`spec'" == "unint"	loc weights "[aweight = weight]"
	else					loc weights ""

	* de-meaning regressions
	cap drop *_rsd
	loc vars_rsd ""
	foreach var in ``spec'_reg' {

		di "reghdfe `var' `controls' `weights', absorb(`fe') residuals(`var'_rsd)"
		qui reghdfe `var' `controls' `weights', absorb(`fe') residuals(`var'_rsd)
		loc vars_rsd "`vars_rsd' `var'_rsd"
		di "Command finished at $S_TIME"

	}


	*****************************************************************************
	* 								Testing code	 							*
	*****************************************************************************
	* use to confirm coefficients from the full regression (fixed effects/controls)
	* match those of residualized regression (according to Frisch Waugh)

	if "$fw_test" == "yes" {

		di "TESTING TESTING 123: SPEC IS `spec'"

		di "reg ``spec'_reg' `controls' `weights', absorb(`fe')"
		qui reghdfe ``spec'_reg' `controls' `weights', absorb(`fe')
		di "Command finished at $S_TIME"
		est store full_reg

		di "reg `vars_rsd' `weights'"
		qui reg `vars_rsd' `weights'
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
				}
			}
		}
		
	}

	*****************************************************************************
	* 							Run admin1 crossval	 							*
	*****************************************************************************

	* run leave-one-out admin1 crossval
	cap mkdir "`data'/`spec'/"
	di "RUNNING... admincrossval reg  `vars_rsd' `weights'"
	adminfoldcrossval reg `vars_rsd' `weights' using "`data'/`spec'/`spec'_admincrossval", cc(adm1_code)
	di "Command finished at $S_TIME"

	* write out results
	loc rmse = `r(rmse)'
	loc mae = `r(mae)'
	loc rho2 = `r(rho2)'
	loc r2 = `r(r2)'
	file write resultcsv "`spec', `r(rmse)',`r(mae)',`r(rho2)',`r(r2)'" _n

}


file close resultcsv
cap log close
