/*

Purpose: Merge in WDI Self Employment % of workforce data
to be used in model robustness checks as described in Appendix D6

Data is from World Bank WDI 2020 panel which can be found here:
https://datacatalog.worldbank.org/dataset/world-development-indicators
The variable is: SL_EMP_SELF_ZS and label is: "Self-employed, total (% of total employment) (modeled ILO estimate)"

Call this code for any informality model regressions or plotting, right after running prep_data.do


Inputs
------

- `0_data_cleaning/2_cleaned/institutional_covariates/WDI_selfemp.dta` - file containing ADM0 level
WDI Self Employement % (selfemp) variable for countries in the sample 


Notes
-------

- data was merged onto adm0-year list in cleaning process so _merge==2 should be 0
- data is only available for 1991 onward, so we will drop those years from full sample

*/

* merge with WDI data
merge m:1 iso year using "$DB/0_data_cleaning/2_cleaned/institutional_covariates/WDI_selfemp.dta"

* dropping unmatched observations from the WDI data. should be 0
drop if _merge == 2

* summarize missing values
tab adm0 if _merge == 1

* drop missing observations
drop if year < 1991

* sort by iso then create 1 year - 1 vote avg of series by iso
gsort iso year
by iso: egen avg_adm0_selfemp = mean(selfemp)


* set global macros for variable names and title names
global covar "selfemp"

global ctit "Self Employed % of Labor Force (informality)"
