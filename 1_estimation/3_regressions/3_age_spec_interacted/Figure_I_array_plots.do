/*

Purpose: Generates 3x3 array of response function plots, with each cell
representing a different quantile of the joint climate and income distribution 
(Figure I in main text and Figures D1 and D2 in Appendix).

These plots are produce by dividing the estimating sample into terciles of
income and climate and creating nine discrete bins which describe the log(GDP) x
TMEAN space. Predicted response functions at the mean of covariates within each
bin are plotted using the regression coefficients estimated in
`age_spec_interacted_regressions.do`.

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

- `data/1_estimation/1_ster/age_spec_interacted`
	- `Agespec_interaction_response.ster` - Ster file containing results from
	an age-stacked regression interacted with ADM1 average income and climate. 

Outputs
-------

- `output/1_estimation/figures/`
	- `Age*_interacted_response_array_GMFD.pdf` - Array plot for each age group
	with 1, 2, 3 representing the <4, 5-64, >65 age groups.

*/

*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

clear all
set more off
set matsize 10000
set maxvar 32700

set scheme s1color

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local STER "$ster_dir/age_spec_interacted"
local OUTPUT "$output_dir/figures"
local DATA "$data_dir"

*************************************************************************
* 							PART B. Toggles							*			
*************************************************************************

* Allow y-axis to change across cells in the array?
* (Typically for diagnostic purposes.)
local ycommon = 1

* Locals for placing population numbers on graphs
local a1_y = 7
local a2_y = 2.5
local a3_y = 35
local a_x = -8


local x_min = -5
local x_max = 40
local x_int = 10

* are we clipping data to fit on certain y-axis?
local yclip = 1

local yclipmin_a1 = -2
local yclipmin_a2 = -2
local yclipmin_a3 = -20

local yclipmax_a1 = 8
local yclipmax_a2 = 3
local yclipmax_a3 = 40

local o = 4 

local o = 4 

* file name suffix
local suffix ""


*************************************************************************
* 							PART C. Prepare Dataset						*			
*************************************************************************

use "$data_dir/3_final/global_mortality_panel_covariates.dta", clear


tempfile MORTALITY_TEMP
save "`MORTALITY_TEMP'", replace


*generating terciles of income and tmean
preserve
	use `MORTALITY_TEMP', clear
	collapse (mean) loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg, by(adm1_code)

	xtile ytile = loggdppc_adm1_avg, nq(3)
	forval terc = 1/2{
        sum loggdppc_adm1_avg if ytile == `terc'
        loc yc`terc' = r(max)
    }
	xtile ttile = lr_tavg_GMFD_adm1_avg, nq(3)
	    forval terc = 1/2{
        sum lr_tavg_GMFD_adm1_avg if ttile == `terc'
        loc tc`terc' = r(max)
    }
	keep adm1_code ytile ttile
	tempfile tercile
	save "`tercile'", replace
restore

*generating tercile cutoff values
use `MORTALITY_TEMP', clear
merge m:1 adm1_code using "`tercile'"
drop if ytile==.
collapse (mean) loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg, by(ytile ttile)

sort ttile
by ttile: egen max_lr_tavg_GMFD_adm1_avg = max(lr_tavg_GMFD_adm1_avg)
local T1 = max_lr_tavg_GMFD_adm1_avg[1]
local T2 = max_lr_tavg_GMFD_adm1_avg[4]
local T3 = max_lr_tavg_GMFD_adm1_avg[7]

sort ytile
by ytile: egen max_loggdppc_adm1_avg = max(loggdppc_adm1_avg)
local Y1 = max_loggdppc_adm1_avg[1]
local Y2 = max_loggdppc_adm1_avg[4]
local Y3 = max_loggdppc_adm1_avg[7]

tempfile tmean_lgdppc_terc
save "`tmean_lgdppc_terc'", replace




*************************************************************************
*                   PART D. Construct Pop Figures                       *           
*************************************************************************


*generating age-specific population figures for globe in 2010 and 2100
preserve

    use "`DATA'/2_cleaned/covar_pop_count.dta", clear
    rename (loggdppc tmean) (lgdppc Tmean)

    gen ytile = .
    gen ttile = .
    replace ytile = 1 if lgdppc<=`yc1'
    replace ytile = 2 if lgdppc>`yc1' & lgdppc<=`yc2'
    replace ytile = 3 if lgdppc>`yc2'
    replace ttile = 1 if Tmean<=`tc1'
    replace ttile = 2 if Tmean>`tc1' & Tmean<=`tc2'
    replace ttile = 3 if Tmean>`tc2'

gen popshare2 = 1 - popshare1 - popshare3
gen pop1 = popshare1*pop
gen pop2 = popshare2*pop
gen pop3 = popshare3*pop
drop if popshare2<0

collapse (sum) pop pop1 pop2 pop3, by(ytile ttile year)
bysort year: egen pop_tot = total(pop)
bysort year: egen pop1_tot = total(pop1)
bysort year: egen pop2_tot = total(pop2)
bysort year: egen pop3_tot = total(pop3)
bysort year: gen pop_per = (pop/pop_tot)*100
bysort year: gen pop1_per = (pop1/pop1_tot)*100
bysort year: gen pop2_per = (pop2/pop2_tot)*100
bysort year: gen pop3_per = (pop3/pop3_tot)*100


* gen age spec pop shares
sort year ytile ttile
foreach age of numlist 1/3 {
	local i = 1
	foreach y of numlist 1/3 {
		foreach t of numlist 1/3 {
			local a`age'_Y`y'T`t'_g_2010 `=round(pop`age'_per[`i'],.50)'
			local a`age'_Y`y'T`t'_g_2100 `=round(pop`age'_per[`=`i'+9'],.50)'
			local i = `i' + 1
		}
	}
}

* gen total age shares
local i = 1
sort year ytile ttile
foreach y of numlist 1/3 {
    foreach t of numlist 1/3 {
        local a_Y`y'T`t'_g_2010 = round(pop_per[`i'],.50)
        local a_Y`y'T`t'_g_2100 = round(pop_per[`=`i'+9'],.50)
        local i = `i' + 1
    }
}

restore


*************************************************************************
* 						PART E. Generate Plots							*			
*************************************************************************

*----------------------------------
*generating age-specific plots
*----------------------------------

foreach age of numlist 1/3 {

	use `MORTALITY_TEMP', clear
	merge m:1 adm1_code using "`tercile'"
	drop if ytile==.

	foreach y of numlist 1/3 {
		foreach T of numlist 1/3 {
			count if ytile == `y' & ttile == `T' & agegroup==`age'
			local obs_`y'_`T'_`age' = r(N)
		}
	}

	collapse (mean) loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg, by(ytile ttile)
	

	*initialize
	gen tavg_poly_1_GMFD =.
	gen deathrate_w99 =.
			

	local ii = 1

	*loop through quintiles
	foreach y of numlist 1/3 {
		foreach T of numlist 1/3 {
			

			preserve
			keep if ytile == `y' & ttile == `T'

			foreach var in "loggdppc_adm1_avg" "lr_tavg_GMFD_adm1_avg" {
				loc zvalue_`var' = `var'[1]
			}

			*obs	
			local min = `x_min'
			local max = `x_max'
			local obs = `max' - `min' + 1
			local omit = 20

			drop if _n > 0
			set obs `obs'
			replace tavg_poly_1_GMFD = _n + `min' - 1

			*----------------------------------
			*Polynomial (4) 
			*----------------------------------

			estimate use "`STER'/Agespec_interaction_response.ster"
			estimates

			*uninteracted terms
			local line = "_b[`age'.agegroup#c.tavg_poly_1_GMFD]*(tavg_poly_1_GMFD-`omit')"
			foreach k of numlist 2/`o' {
				*replace tavg_poly_`k'_GMFD = tavg_poly_1_GMFD ^ `k'
				local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
				local line "`line' `add'"
				}

			*lgdppc and Tmean at the tercile mean
			foreach var in "loggdppc_adm1_avg" "lr_tavg_GMFD_adm1_avg" {
				loc z = `zvalue_`var''
				foreach k of numlist 1/`o' {
					*replace tavg_poly_`k'_GMFD = tavg_poly_1_GMFD ^ `k'
					local add = "+ _b[`age'.agegroup#c.`var'#c.tavg_poly_`k'_GMFD] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
					local line "`line' `add'"
					}
				}

			di "`line'"
			predictnl yhat_poly`o'_pop = `line', se(se_poly`o'_pop) ci(lowerci_poly`o'_pop upperci_poly`o'_pop)



			*----------------------------------
			* Clipping
			*----------------------------------

			if `yclip' == 1 {
				foreach var of varlist yhat_poly`o'_pop lowerci_poly`o'_pop upperci_poly`o'_pop {
					replace `var' = `yclipmax_a`age'' if `var' > `yclipmax_a`age''
					replace `var' = `yclipmin_a`age'' if `var' < `yclipmin_a`age''
				}
			}


			* graph
			local graph_`ii' "(line yhat_poly4_pop tavg_poly_1_GMFD, lc(black) lwidth(medthick)) (rarea lowerci_poly4_pop upperci_poly4_pop tavg_poly_1_GMFD, col(gray%25) lwidth(none))"
			display("saved `graph_`ii'' `ii'")

				

			display("1 = `graph_1'")
			local graph_conc = "`graph_1'"


			*----------------------------------
			* Set axes and titles
			*----------------------------------

			loc ytit "Deaths per 100k"
			loc xtit "Temperature (°C)"
			loc empty ""
			loc space "" ""

			if `ii' == 7 | `ii' == 4 {
				loc ylab "ytitle(`ytit') ylabel(, labsize(small))"
				loc xlab "xtitle(`space') xlabel(none) xscale(off) fysize(25.2)"
			} 

			if `ii' == 8 | `ii' == 5 {
				loc ylab "ytitle(`space') ylabel(none) yscale(off) fxsize(38)"
				loc xlab "xtitle(`space') xlabel(none) xscale(off) fysize(25.2)"
			} 

			if `ii' == 9 | `ii' == 6 {
				loc ylab "ytitle(`ytit') ylabel(, labsize(small)) yscale(alt)"
				loc xlab "xtitle(`space') xlabel(none) xscale(off) fysize(25.2)"
			} 

			if `ii' == 1 {
				loc ylab "ytitle(`ytit') ylabel(, labsize(small))"
				loc xlab "xtitle(`xtit') xlabel(`x_min'(`x_int')35, labsize(small))"
			}

			if `ii' == 2 {
				loc ylab "ytitle(`space') ylabel(none) yscale(off) fxsize(38)"
				loc xlab "xtitle(`xtit') xlabel(`x_min'(`x_int')35, labsize(small))"
			}

			if `ii' == 3 {
				loc ylab "ytitle(`ytit') ylabel(, labsize(small)) yscale(alt)"
				loc xlab "xtitle(`xtit') xlabel(`x_min'(`x_int')35, labsize(small))"
			}


			*----------------------------------
			* Plot charts
			*----------------------------------

			if `ycommon' == 1 {
				twoway `graph_conc' ///
				, yline(0, lcolor(red%50) lwidth(vvthin)) name(matrix_Y`y'_T`T'_noSE, replace) ///
				`xlab' `ylab' plotregion(icolor(white) lcolor(black)) ///
				graphregion(color(white)) legend(off) ///						
				text(`a`age'_y' `a_x' "{bf:%POP 2010: `a`age'_Y`y'T`T'_g_2010'}", place(ne) size(small)) ///
				text(`a`age'_y' `a_x' "{bf:%POP 2100: `a`age'_Y`y'T`T'_g_2100'}", place(se) color(gray) size(small))
			}
			else {
				twoway `graph_conc' ///
				, yline(0, lcolor(gs5) lwidth(vthin)) name(matrix_Y`y'_T`T'_noSE, replace) ///
				`xlab' `ylab' plotregion(icolor(white) lcolor(black)) ///
				graphregion(color(white)) legend(off) 
			}

			restore

			loc ii = `ii' + 1
		}		
	}

	* label chart titles
    if `age' == 1 {
    	loc agetit "< 5"
    	loc fig "D1"
    }
     
    if `age' == 2 {
    	loc agetit "5 - 64"
    	loc fig "D2"
    } 
    if `age' == 3 {
    	loc agetit "> 64"
    	loc fig "1"
    }

	
	if `ycommon' == 1 {
		graph combine matrix_Y3_T1_noSE matrix_Y3_T2_noSE matrix_Y3_T3_noSE ///
		matrix_Y2_T1_noSE matrix_Y2_T2_noSE matrix_Y2_T3_noSE ///
		matrix_Y1_T1_noSE matrix_Y1_T2_noSE matrix_Y1_T3_noSE, ///
		plotregion(color(white)) graphregion(color(white)) cols(3) ycommon ///
		l2title("Poor {&rarr} Rich") b2title("Cold {&rarr} Hot") imargin(vsmall) ///
		title("Age `agetit' Adaptation Model Response Functions", size(medsmall)) 
		graph export "`OUTPUT'/Figure_`fig'_array_plots/Age`age'_interacted_response_array_GMFD`suffix'.pdf", replace
	}
	else {
		graph combine matrix_Y3_T1_noSE matrix_Y3_T2_noSE matrix_Y3_T3_noSE ///
		matrix_Y2_T1_noSE matrix_Y2_T2_noSE matrix_Y2_T3_noSE ///
		matrix_Y1_T1_noSE matrix_Y1_T2_noSE matrix_Y1_T3_noSE, ///
		plotregion(color(white)) graphregion(color(white)) cols(3) rows(3) xcommon ///
		l2title("Poor {&rarr} Rich") b2title("Cold {&rarr} Hot") ///
		title("Age `agetit' Adaptation Model Response Functions", size(medsmall)) 
		graph export "`OUTPUT'/Figure_`fig'_array_plots/Age`age'_interacted_response_array_GMFD`suffix'_ydiff.pdf", replace
	}
	
	graph drop _all
	
}
