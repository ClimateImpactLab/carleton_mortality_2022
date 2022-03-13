/*

Purpose: Residualize regressions for time crossval RMSE exercise. Output saved 
in dta format to be used in `rmse_crossval_time.do`.


Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.


Outputs
-------

- `DB/y_diagnostics/timecrossval`
    - `residualized_series_time.dta` -  dta file containing residualized series for each term
    in the interacted and uninteracted main models on the full sample. This file merges onto
    the final dataset on the observation level (adm2-agegroup-year)


Notes
-------

- Residualization is done for both the interacted (variable suffix = i) and uninteracted 
(variable suffix = un) models. (suffixes are kept short due to variable max character len).
- Due to the goal of the time crossval exercise (predicting post 2004 mortality using pre 2005 data),
we construct and demean interactions for income and climate pre and post cut-off averages 
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
loc output "$DB/1_estimation/2_crossval/timecrossval"

//log using "`output'/residualize_time.smcl", replace


* Prepare data for regressions.
do "$REPO/carleton_mortality_2022/1_estimation/1_utils/prep_data.do"


*************************************************************************
*                           PART C. Prepare Dataset                     *
*************************************************************************

* Prepare data for regressions.
do "$REPO/carleton_mortality_2022/1_estimation/1_utils/prep_data.do"


* generate dummy for if obs is pre or post 2005
gen pre_05 = year < 2005

unique adm1_code if pre_05 == 1
unique adm1_code if pre_05 == 0


* generate sample average Tbar, log gdppc for pre 2005 years
*   (one year one vote given unbalanced panel within adm1 unit)
preserve 
    keep if pre_05 == 1
    bysort iso adm1_id year: keep if _n == 1
    collapse (mean) loggdppc_adm1_avg_pre=loggdppc_adm1 lr_tavg_GMFD_adm1_avg_pre=tavg_GMFD_adm1, by(adm1_code) 
    tempfile avg_pre
    save `avg_pre', replace
restore 

* merge in pre05 data
merge m:1 adm1_code using "`avg_pre'", nogen



* generate sample average Tbar, log gdppc for post 2004 years
*   (one year one vote given unbalanced panel within adm1 unit)
preserve 
    keep if pre_05 == 0
    bysort iso adm1_id year: keep if _n == 1
    collapse (mean) loggdppc_adm1_avg_post=loggdppc_adm1 lr_tavg_GMFD_adm1_avg_post=tavg_GMFD_adm1, by(adm1_code)
    tempfile avg_post
    save `avg_post', replace
restore

* merge in pre05 data
merge m:1 adm1_code using "`avg_post'", nogen

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

		g tavg_poly_`p'_GMFD_`ag' = 		 tavg_poly_`p'_GMFD * agecat`ag'
		di "Command finished at $S_TIME"

		* have to residualize pre and post 2005 averages of covariates separately
		g tavg_poly_`p'_GMFD_`ag'_gdp_pre =  tavg_poly_`p'_GMFD * agecat`ag' * loggdppc_adm1_avg_pre
		di "Command finished at $S_TIME"

		g tavg_poly_`p'_GMFD_`ag'_lrt_pre =  tavg_poly_`p'_GMFD * agecat`ag' * lr_tavg_GMFD_adm1_avg_pre
		di "Command finished at $S_TIME"

		g tavg_poly_`p'_GMFD_`ag'_gdp_post = tavg_poly_`p'_GMFD * agecat`ag' * loggdppc_adm1_avg_post
		di "Command finished at $S_TIME"

		g tavg_poly_`p'_GMFD_`ag'_lrt_post = tavg_poly_`p'_GMFD * agecat`ag' * lr_tavg_GMFD_adm1_avg_post
		di "Command finished at $S_TIME"




		* collect into locals for the crossval regressions
		loc treatment 	"`treatment' 	tavg_poly_`p'_GMFD_`ag'"
		loc gdp_pre		"`gdp_pre' 		tavg_poly_`p'_GMFD_`ag'_gdp_pre"
		loc lrt_pre 	"`lrt_pre'		tavg_poly_`p'_GMFD_`ag'_lrt_pre"
		loc gdp_post	"`gdp_post' 	tavg_poly_`p'_GMFD_`ag'_gdp_post"
		loc lrt_post 	"`lrt_post'		tavg_poly_`p'_GMFD_`ag'_lrt_post"

	}
}

*****************************************************************************
* 						Setting parameters for regression					*
*****************************************************************************

loc controls 	"adm0_agegrp_code##c.prcp_poly_1_GMFD adm0_agegrp_code##c.prcp_poly_2_GMFD"

loc fe 			"adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup"

loc lhs			"deathrate_w99"


loc unint_reg		"`lhs' `treatment'"
loc main_int_reg 	"`lhs' `treatment' `gdp_pre' `lrt_pre' `gdp_post' `lrt_post'"

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
}


ds *_rsdi
ds *_rsdun

keep adm2_code year agegroup *_rsdun *_rsdi

save "`output'/residualized_series_time.dta", replace

cap log close

