/*

Purpose: Merge in WDI Doctors per Capita data
to be used in model robustness checks as described in Appendix D6.

Data is from World Bank WDI 2020 panel which can be found here:
https://datacatalog.worldbank.org/dataset/world-development-indicators
The variable is: SH_MED_PHYS_ZS and label is: Physicians (per 1,000 people)

Call this code for any health model regressions or plotting, right after running prep_data.do


Inputs
-------

- `0_data_cleaning/2_cleaned/institutional_covariates/wdi_docs_pc.dta` - file containing ADM0 level
WDI Doctors per Capita (docpc) variable for countries in the sample 

*/


* merge with WDI data
merge m:1 iso year using "$DB/0_data_cleaning/2_cleaned/institutional_covariates/wdi_docs_pc.dta"

* dropping unmatched observations from the WDI data. they are out of sample years, so no data loss
drop if _merge == 2

* summarize missing values
tab adm0 if _merge == 1

* drop first 3 years of Slovakia sample as there are no WDI values
drop if iso == "SVK" & year < 1999

* drop first 5 years of Chile, as there is only 1 WDI value
drop if iso == "CHL" & year < 2002

* drop years for US prior to 1975, where WDI data is extremely spotty
drop if iso == "USA" & year < 1975

* generate log of doctors per capita
gen l_SH_MED_PHYS_ZS = log(SH_MED_PHYS_ZS)

* sort by iso then create variable for LR average of WDI Doctors Per Capita variable
gsort iso year
by iso: egen avg_adm0_docpc = mean(SH_MED_PHYS_ZS)
by iso: egen avg_adm0_logdocpc = mean(l_SH_MED_PHYS_ZS)

* set global macros for variable names and title names

global covar "docpc"

global ctit "Doctors per Capita (health)"
