/*

Purpose: Converts ster file into response function configuration file for the
Climate Impact Lab projection system. Commonly referred to in documentation as a
"CSVV".

Inputs
------

- `data/1_estimation/1_ster/age_spec_interacted`
	- `Agespec_interaction_response.ster` - Ster file containing results from
	an age-stacked regression interacted with ADM1 average income and climate. 

Outputs
-------

- `output/1_estimation/2_csvv`
	- `Agespec_interaction_response.csvv` - File containing latex output in xlsx format.

Notes
------

Summary of models:
    1. 4th-order polynomial OLS (Age x ADM2) & (Age x ADM2) FE
   *2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) (Age x ADM1 linear trend)
	4. 4th-order polynomial FGLS (Age x ADM2) & (AGE x Country x Year) FE
	5. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE with 13-month climate exposure
* indicates preferred model.

NOTE: As we only carry forward the perferred model (Spec. 2) through the rest of
the analysis, this code generates a CSVV file only for that model. To produce
CSVVs for the other specifications, specify the ster file in Part 1 below.

*/


*****************************************************************************
* 						PART 0. Initializing		 						*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/age_spec_interacted"
local output "$csvv_dir"

*****************************************************************************
* 						PART 1. Generate CSVV files			   			    *
*****************************************************************************

local ster_file "Agespec_interaction_response.ster"

* 1. import estimation results
estimates use "`ster'/`ster_file'"
ereturn display
estimates describe using "`ster'/`ster_file'"


* 2. generate a CSV file
file open csvv using "`output'/Agespec_interaction_response.csvv", write replace

* set up model name used in the CSVV description
local model "Tmean-POLY-4-AgeSpec"

* 3. initialize the file and write descriptions
* titles
file write csvv "---" _n
file write csvv "oneline: Mortality global interaction `model' GMFD results" _n
file write csvv "version: MORTALITY-GLOBAL-INTERACTION-`model'-GMFD-2018replication" _n
file write csvv "dependencies: AAgespec_interaction_response.ster" _n
file write csvv "description: SUR regression. There are 36 gammas reported in this CSVV in total. the first 12 gammas are for age group 1. the second 12 gamms are for age group 2. The last 12 gammas are for age group 3" _n
file write csvv "csvv-version: girdin-2017-01-10" _n

* description on variables
file write csvv "variables:" _n

	file write csvv "  tas: Daily average temperature [C]"_n
	file write csvv "  tas2: square daily average temperature [C^2]"_n
	file write csvv "  tas3: cubic daily average temperature [C^3]"_n
	file write csvv "  tas4: 4th order polynomial daily average temperature [C^4]"_n
	file write csvv "  loggdppc: GDP per capita [log USD2000]"_n
	file write csvv "  climtas: Yearly average temperature [C]"_n         
	file write csvv "  outcome: Death Per 100,000 [100,000 * death/population]"_n          
	file write csvv "..." _n

* 4. fill in information on variable names and the regression
* 4.1 number of observations
file write csvv "observations"_n
file write csvv " `e(N)'" _n

* 4.2 independent variables
file write csvv "prednames"_n

	file write csvv "tas, tas, tas, "
	file write csvv "tas2, tas2, tas2, "
	file write csvv "tas3, tas3, tas3, "
	file write csvv "tas4, tas4, tas4, "

	file write csvv "tas, tas, tas, "
	file write csvv "tas2, tas2, tas2, "
	file write csvv "tas3, tas3, tas3, "
	file write csvv "tas4, tas4, tas4, "

	file write csvv "tas, tas, tas, "
	file write csvv "tas2, tas2, tas2, "
	file write csvv "tas3, tas3, tas3, "
	file write csvv "tas4, tas4, tas4"_n

* 4.3 covariates
file write csvv "covarnames"_n

	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "

	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "

	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc, "
	file write csvv "1, climtas, loggdppc"_n

* 5. fill in results from the .ster file
* 5.1 coefficients:

file write csvv "gamma" _n
local max = 36
matrix b = e(b)

foreach agegrp of numlist 1 2 3 {
	local poly1 = 0 + `agegrp'
	local poly2 = 3 + `agegrp'
	local poly3 = 6 + `agegrp'
	local poly4 = 9 + `agegrp'

	foreach j of numlist `poly1' `poly2' `poly3' `poly4' {
		* uninteracted
		local a = `j'
		* income
		local b = `j' + 24
		* tmean
		local c = `j' + 12
		
			foreach i of numlist `a', `b', `c' {

			if (`i' == 1) {
				local beta = el(b, 1, `i')
				file write csvv "`beta'"
			}
			else {
				local beta = el(b, 1, `i')
				file write csvv ", "
				file write csvv "`beta'"
			}
		}				
	}
}

file write csvv "" _n

* 5.2 variance-covariance matrix:
file write csvv "gammavcv" _n
matrix vcv = e(V)

foreach agegrp of numlist 1 2 3 {
	local poly1 = 0 + `agegrp'
	local poly2 = 3 + `agegrp'
	local poly3 = 6 + `agegrp'
	local poly4 = 9 + `agegrp'

	foreach j of numlist `poly1' `poly2' `poly3' `poly4' {
		local a = `j'
		local b = `j' + 24
		local c = `j' + 12
					
		foreach row of numlist `a', `b', `c' {
					
			foreach agegrp_col of numlist 1 2 3 {
				local poly1_col = 0 + `agegrp_col'
				local poly2_col = 3 + `agegrp_col'
				local poly3_col = 6 + `agegrp_col'
				local poly4_col = 9 + `agegrp_col'

				foreach i of numlist `poly1_col' `poly2_col' `poly3_col' `poly4_col' {
					local d = `i'
					local e = `i' + 24
					local f = `i' + 12
					
					foreach col of numlist `d', `e', `f' {
						if (`col' == 1) {
							local varcov = el(vcv, `row', `col')
							file write csvv "`varcov'"
						}
						else {
							local varcov = el(vcv, `row', `col')
							file write csvv ", "
							file write csvv "`varcov'"
						}
					}
				}
			}
			file write csvv "" _n
		}
	}
}
*
			
* 5.3 residual vcv
file write csvv "residvcv" _n
local residualvcv = `e(rmse)' * `e(rmse)' 
file write csvv "`residualvcv'" _n

* 6. clost the file
file close csvv
