/*

Purpose: Generate table providing the marginal effect of covariates on
temperature sensitivity of mortality rates. (Table D1)

Inputs
------

- `data/1_estimation/1_ster/age_spec_interacted`
	- `Agespec_interaction_response.ster` - Ster file containing results from
	an age-stacked regression interacted with ADM1 average income and climate. 

Outputs
-------

- `output/1_estimation/tables/4_agespec_interacted`
	- `agespec_interacted.xlsx` - File containing latex output in xlsx format.

Notes
------

Summary of models:
    1. 4th-order polynomial OLS (Age x ADM2) & (Age x ADM2) FE
   *2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) (Age x ADM1 linear trend)
	4. 4th-order polynomial FGLS (Age x ADM2) & (AGE x Country x Year) FE
	5. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE with 13-month climate exposure
* indicates preferred model.

NOTE: As we only carry the perferred model (Spec. 2) through the rest of
the analysis, this code generates a table only for that model. To produce tables
for the other specifications, specify the ster file in Part 1 below.

*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local ster "$ster_dir/age_spec_interacted"
local output "$output_dir/tables/Tables_D1_reg_output"

* set up number of decimal digits in the table
local precision 3
* number of specifications in the table
local num_spec = 5

*****************************************************************************
* 						PART 1. Calculate Marginal Effect     			    *
*****************************************************************************


* 1. import estimation results
estimates use "`ster'/Agespec_interaction_response.ster"


forvalues age = 1(1)3 {
* 2. loop over the 4 temperature points and get the marginal effect
	local i = 1
	foreach t in 35 30 0 -5 {
	
	* 2.1 estimate the marginal effects of income
	lincom (  _b[`age'.agegroup#c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg] * (`t' - 20) ///
			+ _b[`age'.agegroup#c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg] * (`t'*`t' - 20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg] * (`t'*`t'*`t' - 20*20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg] * (`t'*`t'*`t'*`t' - 20*20*20*20))

		* store the 2 parameters into macro
		local point_est_`age'_`i'_inc 	= `r(estimate)'
		local se_`age'_`i'_inc  			= `r(se)'
	
	* 2.2 estimate the marginal effects of Tbar
	lincom (  _b[`age'.agegroup#c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg] * (`t' - 20) ///
			+ _b[`age'.agegroup#c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg] * (`t'*`t' - 20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg] * (`t'*`t'*`t' - 20*20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg] * (`t'*`t'*`t'*`t' - 20*20*20*20))

		* store the 2 parameters into macro
		local point_est_`age'_`i'_tmean 	= `r(estimate)'
		local se_`age'_`i'_tmean  		= `r(se)'
	
	local i = `i' + 1
	}
	*
}
*

* 3. get parameters of the regression
local N_obs  = `e(N)'
local r2 = `e(r2_a)'


*****************************************************************************
* 						PART 2. Export to a table		     			    *
*****************************************************************************

* 1. set up the table
clear 
local N = 4
set obs `N'
gen T = .
replace T = 35 in 1
replace T = 30 in 2
replace T =  0 in 3
replace T = -5 in 4


* 2. fill in the estimations
forvalues age = 1(1)3 {
	gen point_est_`age'_inc = .
	gen se_`age'_inc = .
	gen point_est_`age'_tmean = .
	gen se_`age'_tmean = .
	forvalues n = 1(1)`N' {
		replace point_est_`age'_inc 	= `point_est_`age'_`n'_inc' in `n'
		replace se_`age'_inc 			= `se_`age'_`n'_inc' in `n'
		replace point_est_`age'_tmean 	= `point_est_`age'_`n'_tmean' in `n'
		replace se_`age'_tmean 			= `se_`age'_`n'_tmean' in `n'
	}
	*
}
*

* 3. calculate significance level
forvalues age = 1(1)3 {
	foreach covariate in "inc" "tmean" {
		gen t_stats_`age'_`covariate' 	= abs(point_est_`age'_`covariate'/se_`age'_`covariate')
		gen p_`age'_`covariate' 		= 0
		replace p_`age'_`covariate' 	= 1 if t_stats_`age'_`covariate' > 1.645
		replace p_`age'_`covariate' 	= 2 if t_stats_`age'_`covariate' > 1.960
		replace p_`age'_`covariate' 	= 3 if t_stats_`age'_`covariate' > 2.576
		drop t_stats_`age'_`covariate' 
	}
	*
}
*
order T *1*inc *1*tmean *2*inc *2*tmean *3*inc *3*tmean


* 4. export to table
* 4.1 change p value to stars
forvalues age = 1(1)3 {
	foreach covariate in "inc" "tmean" {
	tostring p_`age'_`covariate', replace
	replace p_`age'_`covariate' = "" if p_`age'_`covariate' == "0"
	replace p_`age'_`covariate' = "*" if p_`age'_`covariate' == "1"
	replace p_`age'_`covariate' = "**" if p_`age'_`covariate' == "2"
	replace p_`age'_`covariate' = "***" if p_`age'_`covariate' == "3"
}
}
*

* 4.2 reshape to long (with point estimates in row1 and se in row2)
forvalues age = 1(1)3 {
	foreach covariate in "inc" "tmean" {
		rename point_est_`age'_`covariate' 	age`age'_`covariate'_par1
		rename se_`age'_`covariate' 		age`age'_`covariate'_par2
		rename p_`age'_`covariate' 			age`age'_`covariate'_star1
		gen age`age'_`covariate'_star2 = ""
	}
}
*
reshape long age1_inc_par age1_inc_star age1_tmean_par age1_tmean_star ///
			 age2_inc_par age2_inc_star age2_tmean_par age2_tmean_star ///
			 age3_inc_par age3_inc_star age3_tmean_par age3_tmean_star ///
			 , i(T) j(row)


* keep the order of T
gen order = -T
sort order row
drop order


* 4.3 add N and R2 for each regression
local new = `N'*2 + 3
set obs `new'
local a = `N'*2 + 3
local b = `N'*2 + 2
forvalues j = 1(1)4{
	replace age1_inc_par = `N_obs' in `a'
	replace age1_inc_par = `r2' in `b'
}
*


* 4.4 clean
* (1) keep 3 decimal digit
replace T = . if row== 2
format age*_par %10.`precision'f
* (2) add brackets for SEs
tostring age*_par, replace usedisplayformat force
forvalues age = 1(1)3 {
	foreach covariate in "inc" "tmean" {
		replace age`age'_`covariate'_par = "(" + age`age'_`covariate'_par + ")" if row == 2
		* correct the N and r2 row
		replace age`age'_`covariate'_par = "" if _n > `N'*2 & age`age'_`covariate'_par == "."
}
}
* correct the N row: not 3 decimal digit
replace age1_inc_par = substr(age1_inc_par,1,6) if _n == `a'
* (3) correct the first column
tostring T, replace force
replace T = T + "$^{\circ}$" if row == 1
replace T = "" if row != 1
replace T = "N" if _n == `a'
replace T = "Adj R-squared" if _n == `b'


* 4.5 add in fixed effects
local new = `N'*2 + 3 + 2
set obs `new'
replace T = "Adm2-Age FE" 			if _n == `N'*2 + 3 + 1
replace age1_inc_par = "Yes"		if _n == `N'*2 + 3 + 1
replace T = "Cntry-Yr-Age FE" 		if _n == `N'*2 + 3 + 2
replace age1_inc_par = "Yes"		if _n == `N'*2 + 3 + 2
replace age1_inc_par = "\multicolumn{6}{c}{" + age1_inc_par + "}" if _n > `N'*2 + 1


* 4.6 add & and \\ and hline
forvalues age = 1(1)3 {
	local j = 1
	foreach covariate in "inc" "tmean" {
		gen bar_`age'_`j' = "&"
		local j = `j' + 1
}
}
*
gen endcol = "\\"
order T bar_1_1 *1*inc* bar_1_2 *1*tmean* bar_2_1 *2*inc* bar_2_2 *2*tmean* bar_3_1 *3*inc* bar_3_2 *3*tmean* endcol
drop row
forvalues age = 1(1)3 {
	forvalues i = 1(1)2 {
		if `age' != 1 | `i' != 1 {
			replace bar_`age'_`i' = "" if _n >= `N'*2 + 1 
		}
	}
}
format *star %3s
* add hline
replace T = "\hline" if _n == `N'*2 + 1
replace endcol = " " if _n == `N'*2 + 1
replace bar_1_1 = " " if _n == `N'*2 + 1

* 4.9 drop star columns
forvalues age = 1(1)3 {
	foreach covariate in "inc" "tmean" {
		replace age`age'_`covariate'_par = age`age'_`covariate'_par + age`age'_`covariate'_star
		drop age`age'_`covariate'_star
	}
}
*

*****************************************************************************
* 						PART 3. save					     			    *
*****************************************************************************
estimates
export excel using "`output'/Agespec_interacted_marginaleffects.xlsx", replace firstrow(var)
