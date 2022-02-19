/*

Purpose: Estimates the temperature-mortality response function with
demographic heterogeneity estimated using pooled subnational data (Appendix Table D2).

Inputs
------

- `data/1_estimation/1_ster/age_spec`
	- `Agespec_response_spec*.ster` where * is model 1 through 5. Ster files
	containing uninteracted, age-stacked regressuion results under various
	fixed effects, estimation, and data construction assumptions.

Outputs
-------

- `output/1_estimation/tables/3_agespec_uninteracted`
	- `Table_D2_mortality_agespec_uninteracted.xlsx` - File containing latex output
	for Appendix Table D2 of Carleton et al, 2022 in xlsx format.

Notes
------

Summary of models:
    1. 4th-order polynomial OLS (Age x ADM2) & (Age x ADM2) FE
   *2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) (Age x ADM1 linear trend)
	4. 4th-order polynomial FGLS (Age x ADM2) & (AGE x Country x Year) FE
	5. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE with 13-month climate exposure
* indicates preferred model.

*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

* Script paths.
local ster "$ster_dir/age_spec"
local output "$output_dir/tables/Table_D2"

* set up number of decimal digits in the table
local precision 3
* number of specifications in the table
local num_spec = 5

*****************************************************************************
* 						PART 1. Calculate Marginal Effect     			    *
*****************************************************************************

* I. calculate margianl effect of the 1st-5th specification (with consistent variable names)
local max = min(4, `num_spec')
forvalues j = 1(1)`max' {

	* 1. import estimation results for column j
	estimates use "`ster'/Agespec_response_spec`j'.ster"

	* 2. loop over the 4 temperature points and get marginal effect at 4 temperature points
	local i = 1
	forvalues age = 1(1)3 {
	foreach t in 35 30 0 -5 {
	
		* estimate the effect
		lincom (_b[`age'.agegroup#c.tavg_poly_1_GMFD] * `t'  + _b[`age'.agegroup#c.tavg_poly_2_GMFD] * `t' * `t' + ///
			_b[`age'.agegroup#c.tavg_poly_3_GMFD] * `t' * `t' * `t' + _b[`age'.agegroup#c.tavg_poly_4_GMFD] * `t' * `t' * `t' * `t') ///
		-  (_b[`age'.agegroup#c.tavg_poly_1_GMFD] * 20  + _b[`age'.agegroup#c.tavg_poly_2_GMFD] * 20*20 + ///
			_b[`age'.agegroup#c.tavg_poly_3_GMFD] * 20*20*20 + _b[`age'.agegroup#c.tavg_poly_4_GMFD] * 20*20*20*20 )
	
		* store the 2 parameters into macro
		local point_est_`i'_`j' 	= `r(estimate)'
		local se_`i'_`j'  			= `r(se)'
	
		local i = `i'+1
	}
	*
	}
	*
	* 3. get parameters of the regression
	local N_`j'  = `e(N)'
	local r2_`j' = `e(r2_a)'

}
*
* II. calculate margianl effect of the 5th specification (with different variable names)
if `num_spec' == 5 {
	local j = 5
	
	* 1. import estimation results for column j
	estimates use "`ster'/Agespec_response_spec`j'.ster"

	* 2. loop over the 4 temperature points and get marginal effect at 4 temperature points
	local i = 1
	forvalues age = 1(1)3 {
	foreach t in 35 30 0 -5 {
	
		* estimate the marginal effects
		lincom (_b[`age'.agegroup#c.tavg_poly_1_GMFD_13m] * `t'  + _b[`age'.agegroup#c.tavg_poly_2_GMFD_13m] * `t' * `t' + ///
			_b[`age'.agegroup#c.tavg_poly_3_GMFD_13m] * `t' * `t' * `t' + _b[`age'.agegroup#c.tavg_poly_4_GMFD_13m] * `t' * `t' * `t' * `t') ///
		-  (_b[`age'.agegroup#c.tavg_poly_1_GMFD_13m] * 20  + _b[`age'.agegroup#c.tavg_poly_2_GMFD_13m] * 20*20 + ///
			_b[`age'.agegroup#c.tavg_poly_3_GMFD_13m] * 20*20*20 + _b[`age'.agegroup#c.tavg_poly_4_GMFD_13m] * 20*20*20*20 )
	
		* store the 2 parameters into macro
		local point_est_`i'_`j' 	= `r(estimate)'
		local se_`i'_`j'  			= `r(se)'
	
		local i = `i'+1
	}
	*
	}
	*
	* 3. get parameters of the regression
	local N_`j'  = `e(N)'
	local r2_`j' = `e(r2_a)'

}
*
*****************************************************************************
* 						PART 2. Export to a table		     			    *
*****************************************************************************

* 1. set up the table
clear 
local N = (`i' - 1)/3
set obs `N'
gen T = .
replace T = 35 in 1
replace T = 30 in 2
replace T =  0 in 3
replace T = -5 in 4

* expand to 3 age groups
gen var1 = .
gen var2 = .
gen var3 = .
reshape long var, i(T) j(agegroup)
drop var

* keep the order of T
gen order = -T
sort agegroup order
drop order
local N = _N

* 2. fill in the estimations
forvalues j = 1(1)`num_spec' {
	gen point_est`j' = .
	gen se`j' = .
	forvalues n = 1(1)`N' {
		replace point_est`j' 	= `point_est_`n'_`j'' in `n'
		replace se`j' 			= `se_`n'_`j'' in `n'
	}
	*
}
*

* 3. calculate significance level
forvalues j = 1(1)`num_spec' {
	gen t_stats`j' 	= abs(point_est`j'/se`j')
	gen p`j' 		= 0
	replace p`j' 	= 1 if t_stats`j' > 1.645
	replace p`j' 	= 2 if t_stats`j' > 1.960
	replace p`j' 	= 3 if t_stats`j' > 2.576
	drop t_stats`j' 
}
*
order agegroup T *1 *2 *3


* 4. export to LaTex table
* 4.1 reshape to long (with point estimates in row1 and se in row2)
rename point_est* col*_par1
rename se* col*_par2
rename p* col*_star1
forvalues j = 1(1)`num_spec' {
	gen col`j'_star2 = .
}
*

local command_reshape "reshape long"
local command_order   "order agegroup T"
forvalues  j = 1(1)`num_spec' {
	local add "col`j'_par col`j'_star"
	local command_reshape "`command_reshape' `add'"
	local command_order   "`command_order' `add'"
}
*
local command_reshape "`command_reshape' , i(T agegroup) j(row)"

`command_reshape'
`command_order'

* keep the order of T
gen order = -T
sort agegroup order row
drop order


* 4.2 add N and R2 for each regression
local new = `N'*2 + 3
set obs `new'
local a = `N'*2 + 3
local b = `N'*2 + 2
forvalues j = 1(1)`num_spec'{
	replace col`j'_par = `N_`j'' in `a'
	replace col`j'_par = `r2_`j'' in `b'
}
*

* 4.3 change p value to stars
forvalues j = 1(1)`num_spec' {
	tostring col`j'_star, replace
	replace col`j'_star = "" if col`j'_star == "."
	replace col`j'_star = "" if col`j'_star == "0"
	replace col`j'_star = "*" if col`j'_star == "1"
	replace col`j'_star = "**" if col`j'_star == "2"
	replace col`j'_star = "***" if col`j'_star == "3"
}
*

* 4.4 clean
* (1) keep 3 decimal digit
replace T = . if row== 2
format col*_par %10.`precision'f
* (2) add brackets for SEs
tostring col*_par, replace usedisplayformat force
forvalues j = 1(1)`num_spec' {
	replace col`j'_par = "(" + col`j'_par + ")" if row == 2
	
	* also correct the N row: not 3 decimal digit
	replace col`j'_par = substr(col`j'_par,1,6) if _n == `a'
}
*
* (3) correct the first column
tostring T, replace force
replace T = "\hspace{4mm} " + T + "$^{\circ}$ C" if row == 1
replace T = "" if row != 1
replace T = "N" if _n == `a'
replace T = "Adj R-squared" if _n == `b'

* 4.6 add in notes on fixed effect
local new = `N'*2 + 3 + 6
set obs `new'
replace T = "Age $\times$ ADM2 FE" 			if _n == `N'*2 + 3 + 1
forvalues j = 1(1)`num_spec' {
	replace col`j'_par = "Yes "		if _n == `N'*2 + 3 + 1
}
replace T = "Country $\times$ Year FE" 			if _n == `N'*2 + 3 + 2
	replace col1_par = "Yes "		if _n == `N'*2 + 3 + 2
replace T = "AGE $\times$ Country $\times$ Year FE" 		if _n == `N'*2 + 3 + 3
forvalues j = 2(1)`num_spec' {
	replace col`j'_par = "Yes "		if _n == `N'*2 + 3 + 3
}
replace T = "Age $\times$ ADM1 linear trend" 	if _n == `N'*2 + 3 + 4
	replace col3_par = "Yes "		if _n == `N'*2 + 3 + 4
replace T = "Precision weighting (FGLS)" 		if _n == `N'*2 + 3 + 5
if `num_spec' >= 4 {
	replace col4_par = "Yes "		if _n == `N'*2 + 3 + 5
}
replace T = "13-month exposure" 			if _n == `N'*2 + 3 + 6
if `num_spec' >= 5 {
	replace col5_par = "Yes "		if _n == `N'*2 + 3 + 6
}
*
* 4.7 add & and \\ 
forvalues j = 1(1)`num_spec' {
	gen bar`j' = "&"
}
*
gen endcol = "\\"
local command_order   "order agegroup T"
forvalues  j = 1(1)`num_spec' {
	local add "bar`j' col`j'_par col`j'_star"
	local command_order   "`command_order' `add'"
}
*
`command_order'
drop row
* add hline
replace T = "\hline" if _n == `N'*2 + 1
replace endcol = " " if _n == `N'*2 + 1
forvalues j = 1(1)`num_spec'{
	replace bar`j' = " " if _n == `N'*2 + 1
	replace col`j'_par = " " if _n == `N'*2 + 1
	replace col`j'_star = " " if _n == `N'*2 + 1
}
*

* 4.8 add subtitles
gen order = _n 
local new = `N'*2 + 3 + 6 + 6
set obs `new'
replace order = 0 if order == .
replace agegroup = 1   if _n == `N'*2 + 3 + 6 + 1 
replace agegroup = 1   if _n == `N'*2 + 3 + 6 + 2
replace agegroup = 2   if _n == `N'*2 + 3 + 6 + 3 
replace agegroup = 2   if _n == `N'*2 + 3 + 6 + 4
replace agegroup = 3   if _n == `N'*2 + 3 + 6 + 5 
replace agegroup = 3   if _n == `N'*2 + 3 + 6 + 6
gen order2 = .
replace T = "\hline" if _n == `N'*2 + 3 + 6 + 1 | _n == `N'*2 + 3 + 6 + 3 | _n == `N'*2 + 3 + 6 + 5
replace order2 = 1 if _n == `N'*2 + 3 + 6 + 1 | _n == `N'*2 + 3 + 6 + 3 | _n == `N'*2 + 3 + 6 + 5
sort agegroup order order2
replace T = "\multicolumn{`num_spec'}{l}{Panel A: $<$5 years of age} \\" if agegroup == 1 & order == 0 & order2 == .
replace T = "\multicolumn{`num_spec'}{l}{Panel B: 5-64 years of age} \\" if agegroup == 2 & order == 0  & order2 == .
replace T = "\multicolumn{`num_spec'}{l}{Panel C: $\geq$65 years of age} \\" if agegroup == 3 & order == 0   & order2 == .
drop order* 
* 4.9 drop star columns
forvalues j = 1(1)`num_spec' {
	replace col`j'_par = col`j'_par + col`j'_star
	drop col`j'_star
}
*
*****************************************************************************
* 						PART 3. save					     			    *
*****************************************************************************

export excel using "`output'/Mortality_agespec_uninteracted.xlsx", replace firstrow(var)



