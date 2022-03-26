/* 

Purpose: estimates damage fuctions from global monetized climate change damages
and GMST anomalies from SMME. 

This script does the following:

1. Pulls in a .csv containing damages at global level. The .csv should be
	SSP-specific, and contain damages in 2019 USD for every Monte Carlo
	batch-RCP-GCM-IAM-year combination. 
2. Runs a regression in which the quadratic damage function is estimated
	for each year 't' using data only from the 5 years around 't'.
3. Runs a second regression in which GMST is interacted linearly with time. This
	regression uses only data after 2085.
4. Estimates damage function coefficients for all years 2015-2300, with
	post-2100 extrapolation conducted using the linear temporal interaction
	model from step 3 and pre-2100 using the quadratic model from step 2.
5. Saves a .csv of damage function coefficients to be used by the SCC calculation
	derived from the FAIR simple climate model
6. Produces plots of (1) the end of century damage function overlaying global
	damages, (2) the damage function extrapolation in years beyond 2100 (grey)
	alongside pre-2100 damage function plots (black & blue) subset to the max
	and min of their GMST anomaly distributions, and (3) a kernel density plot
	of GMST anomalies at end of century. These plots together make up Figure VII
	of Carleton et al. 2022
7. Plots several diagnostic figures which are useful for understanding how
	damage functions translate to the SCC. 

Note that the list above covers the functionality for mean damage
function estimation. This script also has functionality for producing quantile
damage function coefficients and a diagnostic plot for the quantile damage
functions. The quantile regression process generally repeats the above process
for 19 quantiles between 0.5 and .95, outputting one .csv file containing all 
quantile regression coefficients.

Toggles
-------

1. Damage function specifications

- ff: functional form of the underlying response functions. 
- ssp: SSP for which to load damages and estimate functions, 2-4
- mc: internal toggle for point estimate (i.e., median) or monte carlo
	simulations.
- value: type of damage function to run. For most cases this is damages, but
	we've experimented with running "damage functions" in deaths impacts and other
	left hand side variables. Other options includeL
		- costs - adaptation costs
		- wo_costs - monetized deaths due to climate change without costs
		- deaths - unmonetized deaths, i.e., number of deaths.

- suffix: Opens damages file with a suffix, and exports coefficients/plots with
the same suffix.

2. Code controls

- run_regs: estimate damage functions and store coefficients
- quantilereg: determines whether quantile regression or mean regression is
	estimated
- paper_plots: generates final presentation-ready plots that appear in Carleton
	et al. (2022), i.e., Figure 11.
- m_time_plots: diagnostic plots showing mean damage functions over time.
- q_time_plots: diagnostic plots showing quantile regression damage functions
	over time.
- gmst_hist: kernel density plots of end of century SMME GMST anomalies.

3. Plot variables

- yearlist: years in which to generate diagnostic plots, i.e., `m_time_plots' for
	mean DFs and `q_time_plots' for quantile DFs.
- plot_obj: the variable in the cleaned damages dataset to include in plots.
	- the default here is 'cil_vsl_epa_scaled', which is consistent with the
	"preferred" valuation scenario in the paper.
- ymin, ymax, int: control minimum, maximum, and interval between labels of the
	y-axis of the paper plots.


Relevant directories
--------------------

Inputs (with default file names):
- File containing global damages, e.g.,
	data/3_valuation/global/mortality_global_damages_MC_poly4_uclip_sharecombo_SSP3.csv
- File containing smoothed GMST anomalies from SMME, e.g.,
	data/4_damage_function/GMST/GMTanom_all_temp_2001_2010_smooth

Outputs:
- csv file containing damage function coefficients, e.g., 
	data/4_damage_function/damages/
	mortality_damage_coefficients_quadratic_IGIA_MC_global_poly4_uclip_sharecombo_SSP3.csv
- pdf file containing presentation-ready plot output, e.g., 
	output/4_damage_function/figures
- pdf file containing diagnostic plot output
	output/4_damage_functions/diagnostics

*/

*****************************************************************
* SET UP -- Change paths and input choices to fit desired output
*****************************************************************

clear all
set more off, perm
pause off
set scheme s1mono

* Directories
global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

global datadir = "$DB/3_valuation/global"
global dfdir = "$DB/4_damage_function"
global plot_outputdir = "$OUTPUT/figures/Figure_7_damage_func"
capture mkdir "$OUTPUT/figures"
capture mkdir "$plot_outputdir"

* Functional form
loc ff = "poly4_uclip_sharecombo"

* SSP
loc ssp = "3" 

* How many years to include in the parametric regression?
loc subset = 2085

* Monte carlo = "_MC" or Median = ""
loc mc = "_MC"

* damages, wo_costs, lifeyears, costs or deaths (for mortality only)
* Note non-damages values may be buggy. Proceed with caution.
loc value = "damages"

* Opens damages file with the following suffix, and exports 
* coefficients/plots with the same suffix.
loc suffix ""

* Code controls (defined above).
loc run_regs = "true"
loc quantilereg = "true"
* Figure 7 in paper
loc paper_plots = "true" 
* Diagnostic charts not used in paper
loc ssp_comparison = "false" 
loc m_time_plots = "false"
loc q_time_plots = "false"
loc gmst_hist = "false"

* Plot variables
loc yearlist 2020 2050 2070 2097
loc plot_obj "cil_vly_epa_scaled"

* Main text figure y-axis
loc ymin -100
loc ymax 400
loc int 100

* Appendix SSP-comparison figure y-axis
loc a_ymin -300
loc a_ymax 800
loc a_int 200

**********************************************
* STEP 1: Pull in and format .csv
**********************************************

clear

if "`value'" == "damages" | "`value'" == "costs" | "`value'" == "wo_costs" | "`value'" == "deaths" {
	di "$datadir"
	import delimited "$datadir/mortality_global_damages`mc'_`ff'_SSP`ssp'`suffix'", varnames(1) 
	merge m:1 year rcp gcm using "$dfdir/GMST/GMTanom_all_temp_2001_2010_smooth", nogen
	gen mod = "high"
	replace mod= "low" if model == "IIASA GDP"
}
else {
	import delimited "$datadir/`value'/global/morality_global_`value'`mc'_`ff'_SSP`ssp'`suffix'", varnames(1) 		
}

* clean input files -- by sector
drop if year < 2010
ren temp anomaly



**********************************************
* STEP 2: Generate damages in Bn 2019 USD
**********************************************

local billion_scale = 1/1000000000
if "`value'" == "damages" | "`value'" == "costs" | "`value'" == "wo_costs" {
	loc vvlist = "vsl vly mt"
	loc aalist = "epa"
	loc sslist = "scaled popavg" 
	foreach vv in `vvlist' {
		foreach aa in `aalist' {
			foreach ss in `sslist' {
			
				* Total impacts (full adapt plus costs), full adapt, costs, share of gdp FA+C
				gen cil_`vv'_`aa'_`ss' = (monetized_deaths_`vv'_`aa'_`ss' + monetized_costs_`vv'_`aa'_`ss')*`billion_scale'
				gen cil_`vv'_`aa'_`ss'_wo = (monetized_deaths_`vv'_`aa'_`ss')*`billion_scale'
				gen cil_`vv'_`aa'_`ss'_costs = (monetized_costs_`vv'_`aa'_`ss')*`billion_scale'

			}
		}
	}
}
replace gdp = gdp*`billion_scale' 
sort rcp mod gcm batch year
tempfile clean_damages
save "`clean_damages'", replace

**********************************************************************************
* STEP 3: Regressions & construction of time-varying damage function coefficients 
**********************************************************************************
if "`run_regs'" == "true" {
	**  INITIALIZE FILE WE WILL POST RESULTS TO
	capture postutil clear
	tempfile coeffs

	if "`quantilereg'" == "false" {
		postfile damage_coeffs str05(age_adjustment) str05(vsl_value) str10(heterogeneity) year cons beta1 beta2 anomalymin anomalymax using "`coeffs'", replace
	}
	else if "`quantilereg'" == "true" {
		postfile damage_coeffs str05(age_adjustment) str05(vsl_value) str10(heterogeneity) year pctile cons beta1 beta2 anomalymin anomalymax using "`coeffs'", replace		
	}


	** Regress, and output coeffs	
	gen t = year-2010

	timer clear
	timer on 1

	if "`quantilereg'" == "false" {
		if "`value'" == "damages" | "`value'" == "costs" | "`value'" == "wo_costs" {
			if "`value'" == "costs" {
				loc suf = "_costs"
			}
			if "`value'" == "wo_costs" {
				loc suf = "_wo"
			}
			foreach vv in `vvlist' {
				foreach aa in `aalist' {
					foreach ss in `sslist' {

						* Nonparametric model for use pre-2100 
						foreach yr of numlist 2015/2099 {
							di "`vv' `aa' `ss' `yr'"
							qui reg cil_`vv'_`aa'_`ss'`suf' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 
							
							* Need to save the min and max temperature for each year for plotting
							qui summ anomaly if year == `yr', det 
							loc amin = `r(min)'
							loc amax =  `r(max)'
							
							* Save coefficients for all years prior to 2100
							post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (_b[_cons]) (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
						}
						
						if "`value'" == "damages" | "`value'" == "wo_costs" {
							* Linear extrapolation for years post-2100 (use only later years bc Sol things fit will be better)
							 qui reg cil_`vv'_`aa'_`ss'`suf' c.anomaly##c.anomaly##c.t  if year >= `subset'
							
							* Generate predicted coeffs for each year post 2100 with linear extrapolation
							
							foreach yr of numlist 2100/2300 {
								di "`vv' `aa' `ss' `yr'"
								loc cons = _b[_cons] + _b[t]*(`yr'-2010)
								loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-2010)
								loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-2010)
								
								* NOTE: we don't have future min and max, so assume they go through all GMST values 	
								post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (`cons') (`beta1') (`beta2') (0) (11)
							
							}
						}
					}				
				}
			}		
		}
		else if "`value'" == "lifeyears" | "`value'" == "deaths" {

			if "`value'" == "lifeyears" {
				loc obj = "lifeyears_fulladapt_combined"
			}
			else if "`value'" == "deaths" {
				loc obj = "deaths"
			}
			* Nonparametric model for use pre-2100 
			foreach yr of numlist 2015/2099 {
				di "`vv' `aa' `ss' `yr'"
				qui reg `obj' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2 
				
				* Need to save the min and max temperature for each year for plotting
				qui summ anomaly if year == `yr', det 
				loc amin = `r(min)'
				loc amax =  `r(max)'
				
				* Save coefficients for all years prior to 2100
				post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (_b[_cons]) (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
			}
			
			* Linear extrapolation for years post-2100 (use only later years bc Sol things fit will be better)
			 qui reg `obj' c.anomaly##c.anomaly##c.t  if year >= `subset'
			
			* Generate predicted coeffs for each year post 2100 with linear extrapolation
			
			foreach yr of numlist 2100/2300 {
				di "`vv' `aa' `ss' `yr'"
				loc cons = _b[_cons] + _b[t]*(`yr'-2010)
				loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-2010)
				loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-2010)
				
				* NOTE: we don't have future min and max, so assume they go through all GMST values 	
				post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (`cons') (`beta1') (`beta2') (0) (11)
			
			}		
		}
	}
	else if "`quantilereg'" == "true" {
		if "`value'" == "costs" {
			loc suf = "_costs"
		}
		if "`value'" == "wo_costs" {
			loc suf = "_wo"
		}
		foreach vv in `vvlist' {
			foreach aa in `aalist' {
				foreach ss in `sslist' {
					foreach pp of numlist 0.05(.05).95 {
						* Nonparametric model for use pre-2100 
						foreach yr of numlist 2015/2099 {	
							di "`vv' `aa' `ss' `yr' `pp'"		
							* Need to save the min and max temperature for each year for plotting
							qui summ anomaly if year == `yr', det 
							loc amin = `r(min)'
							loc amax =  `r(max)'
							
							qui qreg cil_`vv'_`aa'_`ss'`suf' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(`pp')
						
							* Save coefficients for all years prior to 2100
							post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (`pp') (_b[_cons]) (_b[anomaly]) (_b[c.anomaly#c.anomaly]) (`amin') (`amax')
						}
						
						* Linear extrapolation for years post-2100 (use only later years bc Sol things fit will be better)
						qui qreg cil_`vv'_`aa'_`ss'`suf' c.anomaly##c.anomaly##c.t if year >= `subset', quantile(`pp')

						foreach yr of numlist 2100/2300 {
							di "`vv' `aa' `ss' `yr' `pp'"
							loc cons = _b[_cons] + _b[t]*(`yr'-2010)
							loc beta1 = _b[anomaly] + _b[c.anomaly#c.t]*(`yr'-2010)
							loc beta2 = _b[c.anomaly#c.anomaly] + _b[c.anomaly#c.anomaly#c.t]*(`yr'-2010)
							
							* NOTE: we don't have future min and max, so assume they go through all GMST values 	
							post damage_coeffs ("`vv'") ("`aa'") ("`ss'") (`yr') (`pp') (`cons') (`beta1') (`beta2') (0) (11)		
						}
					}
				}
			}
		}
	}


	postclose damage_coeffs
	timer off 1
	timer list

	di "Time to completion = `r(t1)'"

	**********************************************
	* STEP 4: WRITE AND SAVE OUTPUT 
	**********************************************

	* save and write out results
	clear 
	use "`coeffs'" 

	if "`value'" == "lifeyears" | "`value'" == "deaths" {
		drop age_adjustment vsl_value heterogeneity
	}

	if "`value'" == "damages" {
		if "`quantilereg'" == "false" {
			outsheet using "$dfdir/`value'/mortality_damage_coefficients_quadratic_IGIA`mc'_global_`ff'`suffix'_SSP`ssp'.csv", comma replace
		}
		else if "`quantilereg'" == "true" {
			outsheet using "$dfdir/`value'/mortality_damage_coefficients_quadratic_IGIA`mc'_global_`ff'_quantilereg`suffix'_SSP`ssp'.csv", comma replace
		}
	}
	
	else {
		if "`quantilereg'" == "false" {
			outsheet using "$dfdir/`value'/mortality_`value'_coefficients_quadratic_IGIA`mc'_global_`ff'`suffix'_SSP`ssp'.csv", comma replace
		}
		else if "`quantilereg'" == "true" {
			outsheet using "$dfdir/`value'/mortality_damage_coefficients_quadratic_IGIA`mc'_global_`ff'_`value'_quantilereg`suffix'_SSP`ssp'.csv", comma replace
		}
	}
}

**********************************************
* STEP 5: GENERATE PLOTS FOR PAPER - Figure 7
**********************************************

if "`paper_plots'" == "true" {

	/*

	Figure 7 Panel A: End of century damage functions overlaying damages from all Monte
	Carlo batches, GCMs, IAMs, RCPs.

	Note that the raw output has two axes, which are rearranged in illustrator
	during post-processing. The left axis is in tn 2019 USD and the right axis
	is in share of GDP. Stata doesn't have flawless functionality for two axes 
	(in my opinion) so some fiddling with the `ylabel` arguments might be
	necessary to make this look right.

	*/


	use "`clean_damages'", clear
	loc yr = 2097
	keep if year>=`yr'-2 & year <= `yr'+2

	foreach var of varlist `plot_obj' {
		replace `var' = `var'/1000
	}
	* global GDP in 2100, average across two IAMs
	gen gdptn = gdp/(1000)
	summ gdptn if year==2099
	local denom = `r(mean)'
	di `denom'

	loc ymind = round(`ymin'/ `denom', .01)
	loc ymaxd = round(`ymax'/ `denom', .01)
	loc intd = round(`int'/ `denom',.01)

	tempfile fullfile
	save "`fullfile'", replace

	keep `plot_obj' anomaly rcp 
	tempfile datapoints
	save "`datapoints'", replace
	
	clear
	import delimited "$dfdir/damages/mortality_damage_coefficients_quadratic_IGIA`mc'_global_`ff'`suffix'_SSP`ssp'.csv", varnames(1) 

	* Expand to get obs every quarter degree
	expand 40, gen(newobs)


	egen model = group(age_adjustment vsl_value heterogeneity)
	gen model_str = age_adjustment + "_" + vsl_value + "_" + heterogeneity


	* Generate anomaly and prediction for every quarter degree
	bysort model year: gen anomaly = _n/4
	gen y = (cons + beta1*anomaly + beta2*anomaly^2)/1000
	
	gen y_share = y / `denom'

	local modstr = subinstr("`plot_obj'", "cil_", "", .)
	keep if model_str == "`modstr'"
	di model_str[1]
	append using "`datapoints'"

	tw 	(scatter `plot_obj' anomaly if rcp == "rcp45", yaxis(2) mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall) yscale(r(`ymin'(`int')`ymax') axis(2)) ylabel(0(`int')`ymax', axis(2) )  ) ///
		(scatter `plot_obj' anomaly if rcp == "rcp85", yaxis(2) mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) yscale(r(`ymin'(`int')`ymax') axis(2)) ylabel(0(`int')`ymax', axis(2) ) ) ///
		(line y_share anomaly if year == 2097, sort yaxis(1) lpattern("solid") lcolor(black)  ylabel(0 .2 .4 .6 .8 1 `ymaxd') yscale(r(`ymind'(`intd')`ymaxd') )  ) ///
		, yline(0, lcolor(black)) legend(off) xscale(r(0(1)10)) xlabel(0(1)10) ///
		  ytitle("Share of GDP", axis(1)) ytitle("tn USD (2019$)", axis(2)) xtitle("GMST Anomaly") title("Damage Function, End of Century", tstyle(size(medsmall))) 

	graph export "$plot_outputdir/end_of_century_df_`plot_obj'_quadratic`mc'_SSP`ssp'`suffix'.pdf" , replace
	
	/*

	Figure 7 Panel B: Extrapolated damage functions alongside pre-2100 functions plotted
	over GMST range.

	*/
	loc gr

	* Pre-2100 nonparametric lines
	foreach yr of numlist 2015(5)2099 {
		loc gr `gr' line y anomaly if year == `yr' & model_str == "`modstr'" & anomaly>anomalymin & anomaly<anomalymax, color(edkblue) ||
	}

	* 2100 line // & anomaly>anomalymin & anomaly<anomalymax
	loc gr `gr' line y anomaly if year == 2097 & model_str == "`modstr'"  , color(black) || 

	* Post-2100 extrapolation line
	foreach yr of numlist 2150 2200 2250 2300 {
		loc gr `gr' line y anomaly if year == `yr'  & model_str == "`modstr'" & anomaly>anomalymin & anomaly<anomalymax, color(gs5*.5) ||
	}
	sort anomaly
	local title = model_str[1]

	graph twoway `gr', ytitle("tn USD (2019$)") xtitle("GMST Anomaly") ///
		title("`title'", tstyle(size(medsmall))) ///
		yscale(r(`ymin'(`int')`ymax')) ylabel(0(`int')`ymax')  ///
		legend(off) name("`title'", replace) xscale(r(0(1)10)) xlabel(0(1)10) yline(0, lcolor(black)) //yscale(r(0(100000)`ymax')) ylabel(0(100000)`ymax')

	graph export "$plot_outputdir/post2100_df_`plot_obj'_quadratic`mc'_SSP`ssp'`suffix'.pdf", replace 
}

if "`ssp_comparison'" == "true" {

	/*

	This plot repeats Panel A of the figure 7 but with two changes:
		(1): No percent of gdp axis
		(2): Axes wide enough to fit all SSP scenarios

	*/


	use "`clean_damages'", clear
	loc yr = 2097
	keep if year>=`yr'-2 & year <= `yr'+2

	foreach var of varlist `plot_obj' {
		replace `var' = `var'/1000
	}

	tempfile fullfile
	save "`fullfile'", replace

	keep `plot_obj' anomaly rcp 
	tempfile datapoints
	save "`datapoints'", replace
	
	clear
	import delimited "$dfdir/damages/mortality_damage_coefficients_quadratic_IGIA`mc'_global_`ff'`suffix'_SSP`ssp'.csv", varnames(1) 

	* Expand to get obs every quarter degree
	expand 40, gen(newobs)

	egen model = group(age_adjustment vsl_value heterogeneity)
	gen model_str = age_adjustment + "_" + vsl_value + "_" + heterogeneity

	* Generate anomaly and prediction for every quarter degree
	bysort model year: gen anomaly = _n/4
	gen y = (cons + beta1*anomaly + beta2*anomaly^2)/1000

	local modstr = subinstr("`plot_obj'", "cil_", "", .)
	keep if model_str == "`modstr'"
	di model_str[1]
	append using "`datapoints'"

	tw 	(scatter `plot_obj' anomaly if rcp == "rcp45", mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall) ) ///
		(scatter `plot_obj' anomaly if rcp == "rcp85", mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) ) ///
		(line y anomaly if year == 2097, sort lpattern("solid") lcolor(black)) ///
		, ytitle("tn USD (2019$)") xtitle("GMST Anomaly") ///
		title("Damage Function, End of Century", tstyle(size(medsmall))) ///
		yscale(r(`a_ymin'(`a_int')`a_ymax')) ylabel(-200(`a_int')`a_ymax')  ///
		legend(off) name("`title'", replace) xscale(r(0(1)10)) xlabel(0(1)10) yline(0, lcolor(black))

	graph export "$plot_outputdir/diagnostics/end_of_century_df_appendix-compare-SSPs_`plot_obj'_quadratic`mc'_SSP`ssp'`suffix'.pdf" , replace


}

**********************************************
* STEP 6: GENERATE DIAGNOSTIC PLOTS.
**********************************************

if "`m_time_plots'" == "true" {

	/*

	These plots show damage functions overlaying damages for the years specified
	in the `yearlist' local in the header. These are usually used for diagnostic
	purposes only. They do not set a fixed y-axis (as usually comparing across
	years with a constant y-axis is difficult), though one may be added
	manually if needed. 

	*/


	if "`value'" != "deaths" {
		if "`value'" == "damages" {
			local obj "`plot_obj'"
		}
		else if "`value'" == "costs" {
			local obj "`plot_obj'_costs"
		}
		local ytitle "tn USD ($2019)"
		foreach yr in `yearlist' {
			preserve
				reg `obj' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2
				tempfile betas_2
				estimates save `betas_2'

				keep if year>=`yr'-2 & year <= `yr'+2
				keep `obj' anomaly rcp 
				foreach var of varlist `obj' {
					replace `var' = `var'/1000
				}

				tempfile datapoints
				save "`datapoints'", replace

				clear
				local min = 0
				local max = 10
				local obs = (`max' - `min')*10 + 1
				set obs `obs'
				gen anomaly = _n/10 + `min' - .1

				gen `obj' = .

				estimates use "`betas_2'"
				predictnl double hat2 = xb(), ci(hat2_l hat2_u)
				replace hat2 = hat2/1000
				append using "`datapoints'"

				sum anomaly if `obj' != .
				loc xmax = ceil(r(max))
				keep if anomaly <= `xmax'

				tw 	(scatter `obj' anomaly if rcp == "rcp45", mlcolor(ebblue%50) msymbol(O) mfcolor(ebblue%50) msize(vsmall) ) ///
					(scatter `obj' anomaly if rcp == "rcp85", mlcolor(red%50) msymbol(O) mfcolor(red%50)  msize(vsmall) ) /// 
					(line hat2 anomaly, sort lpattern("solid") lcolor(black) lwidth(medthick) ) ///
					, /// yscale(r(`ymin'(`int')`ymax')) ylabel(`ymin'(`int')`ymax')  ///
					  yline(0, lcolor(black)) legend(off) legend(size(small)) ///
					  ytitle("`ytitle'") xtitle("GMST Anomaly") title("`value'_`yr'", tstyle(size(medsmall))) 

				graph export "$plot_outputdir/diagnostics/SSP`ssp'/damage_function_`obj'_SSP`ssp'_`yr'`suffix'.pdf" , replace

			restore
		}
	}
	else {
		local obj deaths
		local ytitle "Deaths (Millions)"
		foreach yr in `yearlist' {
			preserve
				reg `obj' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2
				tempfile betas_2
				estimates save `betas_2'

				keep if year>=`yr'-2 & year <= `yr'+2
				keep `obj' anomaly rcp 
				foreach var of varlist `obj' {
					replace `var' = `var' / 1E6
				}

				tempfile datapoints
				save "`datapoints'", replace

				clear
				local min = 0
				local max = 10
				local obs = (`max' - `min')*10 + 1
				set obs `obs'
				gen anomaly = _n/10 + `min' - .1

				gen `obj' = .

				estimates use "`betas_2'"
				predictnl double hat2 = xb(), ci(hat2_l hat2_u)
				replace hat2 = hat2 / 1E6
				append using "`datapoints'"

				sum anomaly if `obj' != .
				loc xmax = ceil(r(max))
				keep if anomaly <= `xmax'

				tw 	(scatter `obj' anomaly if rcp == "rcp45", mlcolor(ebblue%50) msymbol(O) mfcolor(ebblue%50) msize(vsmall) ) ///
					(scatter `obj' anomaly if rcp == "rcp85", mlcolor(red%50) msymbol(O) mfcolor(red%50)  msize(vsmall) ) /// 
					(line hat2 anomaly, sort lpattern("solid") lcolor(black) lwidth(medthick) ) ///
					, yline(0, lcolor(black)) legend(off) legend(size(small)) ///
					  ytitle("`ytitle'") xtitle("GMST Anomaly") title("`value'_`yr'", tstyle(size(medsmall))) 

				graph export "$plot_outputdir/diagnostics/SSP`ssp'/damage_function_`obj'_SSP`ssp'_`yr'`suffix'.pdf" , replace

			restore
		}
	}

}

if "`q_time_plots'" == "true" {

	/*

	These plots show quantile damage functions overlaying damages for the years
	specified in the `yearlist' local in the header. These are usually used for
	diagnostic purposes only. They do not set a fixed y-axis (as usually
	comparing across years with a constant y-axis is difficult), though one may
	be added manually if needed. 

	*/


	foreach yr in `yearlist' {

		//capture drop yhat_* 
		local obj "`plot_obj'"

		foreach qq of numlist 0.05 0.25 0.50 0.75 0.95 {
			loc qq_tag = subinstr("`qq'", ".", "",.)
			qui qreg `obj' c.anomaly##c.anomaly if year>=`yr'-2 & year <= `yr'+2, quantile(`qq')
			predict yhat_`qq_tag'_`yr' // if e(sample)
			replace yhat_`qq_tag'_`yr'  = yhat_`qq_tag'_`yr' / 1000
			tempfile est_`qq_tag'_`yr'
			estimates save "est_`qq_tag'_`yr'", replace
		}

		foreach var of varlist `plot_obj' {
			replace `var' = `var'/1000
		}


		di `yr'
		qui summ anomaly if year == `yr', det 
		loc pmin = `r(min)'
		loc pmax =  `r(max)'

		sort anomaly
		preserve
			keep if year>=`yr'-2 & year <= `yr'+2
			twoway ///	
			 	(scatter `plot_obj' anomaly if rcp == "rcp45", mlcolor(ebblue%30) msymbol(O) mlw(vthin) mfcolor(ebblue%30) msize(vsmall) ) ///
				(scatter `plot_obj' anomaly if rcp == "rcp85", mlcolor(red%30) msymbol(O) mlw(vthin) mfcolor(red%30) msize(vsmall) ) ///
				line yhat_05_`yr' anomaly, lc("black")  || ///
				line yhat_25_`yr' anomaly, lc("black")  || ///
				line yhat_5_`yr' anomaly,  lc("black") || ///
				line yhat_75_`yr' anomaly, lc("black") || ///
				line yhat_95_`yr' anomaly, lc("black") ///	
				yline(0, lcolor(black)) title("Quantile regressions, `yr'", tstyle(size(medsmall))) name(g_`yr', replace) ///
				yscale(r(`ymin'(`int')`ymax')) ylabel(0(`int')`ymax')  ///
			ytitle("bn USD") xtitle("GMST Anomaly") legend(off)

			graph export "$plot_outputdir/diagnostics/quantilereg_`yr'_SSP`ssp'`suffix'.pdf", replace
		restore

	}
}

if "`gmst_hist'" == "true" {

	/*

	This section plots kdensity of GMST at end of century, which is used in the
	damage function figure in Carleton et al. (2022).

	*/
	use "`clean_damages'", clear
	* Histograms of GMST
	loc yr = 2097
	loc bw = 0.6
	tw (kdensity anomaly if rcp=="rcp45" & year>=`yr'-2 & year <= `yr'+2, color(edkblue) bw(`bw')) (kdensity anomaly if rcp=="rcp85" & year>=`yr'-2 & year <= `yr'+2, color(red%50) bw(`bw'))

	graph export "$plot_outputdir/anomaly_densities_GMST_2001-2010`mc'.pdf", replace 
}



