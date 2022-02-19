/*

Purpose: Merges in cleaned Secondary School Completion rate data from OECD/WDI combined file.


Call this code for any edu model regressions or plotting, right after running prep_data.do


Inputs
-------

- `0_data_cleaning/2_cleaned/institutional_covariates/hsgrad_data_trimmed.dta` - file containing ADM0 level
hsgrad variable for countries in the mortality sample. 

Data from World Bank WDI 2020 panel can be found here:
https://datacatalog.worldbank.org/dataset/world-development-indicators
The variable is: SE_SEC_CUAT_UP_ZS and label is: "Educational attainment, at least completed upper secondary, population 25+, total"

Data from OECD "Education at a Glance 2020 Report" can be found here:
https://data.oecd.org/eduatt/adult-education-level.htm
The indicator-subject-measure combination is: EDUADULT - BUPPSRY - PC_25_64
and the label is: "Adult education level, Upper secondary, % of 25-64 year-olds"


Notes
-------

- In combining the 2 variables into 1, we take the average of the two in every iso-year (so that in iso-years where
  only one of the datasets has a value, that becomes the comnbined value), then groupby iso over the first and last
  years available the same way we do with the other covariate averages. Given the variables are not defined in the
  same exact way, but are very highly correlated, we add a factor onto the WDI variable equal to the intercept of
  regressing the WDI variable on the OECD variable. 
- file also contains var min_year, which gives the first year for which either OECD or WDI is made available.

*/



* merge with WDI data
merge m:1 iso year using "$DB/0_data_cleaning/2_cleaned/institutional_covariates/hsgrad_data_trimmed.dta"

* dropping unmatched observations from the edu data. should already be 0 due to prior cleaning
drop if _merge == 2

* summarize missing values
tab adm0 if _merge == 1

* MKD and MNE are the 2 countries without any edu data. drop them
drop if iso == "MKD"
drop if iso == "MNE"

* drop all observartions before edu data starts 
drop if avg_adm0_hsgrad == .

* generate log of secondary completion rate
gen avg_adm0_loghsgrad = log(avg_adm0_hsgrad)


* set global macros for variable names and title names

global covar "hsgrad"

global ctit "Secondary School Completion Rate (edu)"