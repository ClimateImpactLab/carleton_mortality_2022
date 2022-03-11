/*

Purpose: Merge in World Inequality Database (WID) pre-tax income GINI coefficient data
to be used in model robustness checks as described in Appendix D6

Data from WID can be downloaded here: https://wid.world/data/
The Variable is: gptinc_992_j_*iso*
and the description is: Total population | Gini coefficient | adults | equal split | Pre-tax national income

Call this code for any informality model regressions or plotting, right after running prep_data.do


Inputs
------

- `0_data_cleaning/2_cleaned/institutional_covariates/WDI_selfemp.dta` - file containing ADM0 level
Gini Coefficient (gini) variable for countries in the sample 


Notes
-------

- data was merged onto adm0-year list in cleaning process so _merge==2 should be 0

*/

* merge with WDI data
merge m:1 iso year using "$DB/0_data_cleaning/2_cleaned/institutional_covariates/wid_gini.dta"

* dropping unmatched observations from the WDI data. should be 0
drop if _merge == 2

* summarize missing values
tab adm0 if _merge == 1

* drop missing data (Bulgaria, Montenegro, Malta, Japan pre 1990)
drop if iso == "BGR"
drop if iso == "MLT"
drop if iso == "MNE"
drop if iso == "JPN" & year < 1990

* sort by iso then create 1 year - 1 vote avg of series by iso
gsort iso year
by iso: egen avg_adm0_gini = mean(gini)

* set global macros for variable names and title names
global covar "gini"

global ctit "Pre-tax income GINI Coefficient (inequality)"