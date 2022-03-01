/*=======================================================================
Creator: Jingyuan Wang, jingyuanwang@uchicago.edu
Date last modified: 
Last modified by: First Last, my@email.com
Purpose: 

==========================================================================*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************
* 1. set up 
* number of decimal digits in the table
local precision 5

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/diagnostic_specs"
local output "$output_dir/tables/Table_D3"

*****************************************************************************
* 						PART 1. Calculate Marginal Effect     			    *
*****************************************************************************


* 1. import estimation results
estimates use "`ster'/Agespec_interaction_HDDCDD_response.ster"


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
		local se_`age'_`i'_inc  		= `r(se)'
	
	* 2.2 estimate the marginal effects of HDD
	lincom (  _b[`age'.agegroup#c.tavg_poly_1_GMFD#c.lr_hdd_20C_GMFD_adm1_avg] * (`t' - 20) ///
			+ _b[`age'.agegroup#c.tavg_poly_2_GMFD#c.lr_hdd_20C_GMFD_adm1_avg] * (`t'*`t' - 20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_3_GMFD#c.lr_hdd_20C_GMFD_adm1_avg] * (`t'*`t'*`t' - 20*20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_4_GMFD#c.lr_hdd_20C_GMFD_adm1_avg] * (`t'*`t'*`t'*`t' - 20*20*20*20))
			
		* store the 2 parameters into macro
		local point_est_`age'_`i'_hdd 	= `r(estimate)'
		local se_`age'_`i'_hdd  		= `r(se)'
	
	* 2.3 estimate the marginal effects of CDD
	lincom (  _b[`age'.agegroup#c.tavg_poly_1_GMFD#c.lr_cdd_20C_GMFD_adm1_avg] * (`t' - 20) ///
			+ _b[`age'.agegroup#c.tavg_poly_2_GMFD#c.lr_cdd_20C_GMFD_adm1_avg] * (`t'*`t' - 20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_3_GMFD#c.lr_cdd_20C_GMFD_adm1_avg] * (`t'*`t'*`t' - 20*20*20) ///
			+ _b[`age'.agegroup#c.tavg_poly_4_GMFD#c.lr_cdd_20C_GMFD_adm1_avg] * (`t'*`t'*`t'*`t' - 20*20*20*20))

		* store the 2 parameters into macro
		local point_est_`age'_`i'_cdd 	= `r(estimate)'
		local se_`age'_`i'_cdd  		= `r(se)'
	
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
	gen point_est_`age'_hdd = .
	gen se_`age'_hdd = .
	gen point_est_`age'_cdd = .
	gen se_`age'_cdd = .
	forvalues n = 1(1)`N' {
		replace point_est_`age'_inc 	= `point_est_`age'_`n'_inc' in `n'
		replace se_`age'_inc 			= `se_`age'_`n'_inc' in `n'
		replace point_est_`age'_hdd 	= `point_est_`age'_`n'_hdd' in `n'
		replace se_`age'_hdd 			= `se_`age'_`n'_hdd' in `n'
		replace point_est_`age'_cdd 	= `point_est_`age'_`n'_cdd' in `n'
		replace se_`age'_cdd 			= `se_`age'_`n'_cdd' in `n'
	}
	*
}
*

* 3. calculate significance level
forvalues age = 1(1)3 {
	foreach covariate in "inc" "hdd" "cdd" {
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
order T *1*inc *1*hdd *1*cdd *2*inc *2*hdd *2*cdd *3*inc *3*hdd *3*cdd


* 4. export to table
* 4.1 change p value to stars
forvalues age = 1(1)3 {
	foreach covariate in "inc" "hdd" "cdd" {
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
	foreach covariate in "inc" "hdd" "cdd" {
		rename point_est_`age'_`covariate' 	age`age'_`covariate'_par1
		rename se_`age'_`covariate' 		age`age'_`covariate'_par2
		rename p_`age'_`covariate' 			age`age'_`covariate'_star1
		gen age`age'_`covariate'_star2 = ""
	}
}
*
reshape long age1_inc_par age1_inc_star age1_hdd_par age1_hdd_star age1_cdd_par age1_cdd_star ///
			 age2_inc_par age2_inc_star age2_hdd_par age2_hdd_star age2_cdd_par age2_cdd_star ///
			 age3_inc_par age3_inc_star age3_hdd_par age3_hdd_star age3_cdd_par age3_cdd_star ///
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
* (1) keep certain decimal digit
replace T = . if row== 2
format age*_par %10.`precision'f
* (2) add brackets for SEs
tostring age*_par, replace usedisplayformat force
forvalues age = 1(1)3 {
	foreach covariate in "inc" "hdd" "cdd" {
		replace age`age'_`covariate'_par = "(" + age`age'_`covariate'_par + ")" if row == 2
		* correct the N and r2 row
		replace age`age'_`covariate'_par = "" if _n > `N'*2 & age`age'_`covariate'_par == "."
}
}
* correct the N row: not 3 decimal digit
if `precision' <= 3 {
	replace age1_inc_par = substr(age1_inc_par,1,6) if _n == `a'
}
else {
	replace age1_inc_par = "820237" if _n == `a'
}
*
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
replace age1_inc_par = "\multicolumn{9}{c}{" + age1_inc_par + "}" if _n > `N'*2 + 1


* 4.6 add & and \\ and hline
forvalues age = 1(1)3 {
	local j = 1
	foreach covariate in "inc" "hdd" "cdd" {
		gen bar_`age'_`j' = "&"
		local j = `j' + 1
}
}
*
gen endrow = "\\"
order T bar_1_1 *1*inc* bar_1_2 *1*hdd* bar_1_3 *1*cdd* ///
		bar_2_1 *2*inc* bar_2_2 *2*hdd* bar_2_3 *2*cdd* ///
		bar_3_1 *3*inc* bar_3_2 *3*hdd* bar_3_3 *3*cdd* endrow
drop row
forvalues age = 1(1)3 {
	forvalues i = 1(1)3 {
		if `age' != 1 | `i' != 1 {
			replace bar_`age'_`i' = "" if _n >= `N'*2 + 1 
		}
	}
}
format *star %3s
* add hline
replace T = "\hline" if _n == `N'*2 + 1
replace endrow = " " if _n == `N'*2 + 1
replace bar_1_1 = " " if _n == `N'*2 + 1

* 4.9 drop star columns
forvalues age = 1(1)3 {
	foreach covariate in "inc" "hdd" "cdd" {
		replace age`age'_`covariate'_par = age`age'_`covariate'_par + age`age'_`covariate'_star
		drop age`age'_`covariate'_star
	}
}
*

*****************************************************************************
* 						PART 3. save					     			    *
*****************************************************************************

export excel using "`output'/HDDCDD_Table.xlsx", replace firstrow(var)


