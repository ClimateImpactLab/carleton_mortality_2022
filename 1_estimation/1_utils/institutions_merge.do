/*

Purpose: Merges in Polity2 and Democ data to be used in later regression scripts
to be used in model robustness checks as described in Appendix D6

Data from Polity 2 can be found here: https://www.systemicpeace.org/inscrdata.html

Data from Democ can be found here: https://ourworldindata.org/democracy

Call this code for any institutions model regressions or plotting, right after running prep_data.do

Inputs
------

- `0_data_cleaning/2_cleaned/institutional_covariates/inst_qlt.dta` - final institutional quality data


*/

*****************************************************************************
*                       PART 1. Initializing                                *
*****************************************************************************


di _N
* The insitutional quality data does not have observations for Iceland and Malta,
* removing these countries to run main mortality regressions again
drop if iso == "ISL"
drop if iso == "MLT"

* merge with polity data
merge m:1 iso year using "$DB/0_data_cleaning/2_cleaned/institutional_covariates/inst_qlt.dta"
* there are 33 unmatched matched observations from the master data in CZE, LVA, LTU, and MNE

* dropping unmatched observations from the polity data. they are out of sample years, so no data loss
drop if _merge == 2

tab adm0 if _merge == 1 // finding which countries have unmatched observations from mortality data
/*
country string |      Freq.     Percent        Cum.
------------------+-----------------------------------
Czech Republic |         24       72.73       72.73
       Estonia |          3        9.09       81.82
     Lithuania |          3        9.09       90.91
    Montenegro |          3        9.09      100.00
------------------+-----------------------------------
         Total |         33      100.00
*/

di _N

// Replacing the missing polity and democracy scores after merging with mortality in lines 107 to 114:

* REASON:
* Mortality data has one preceding year extra than polity2 data for CZE, LTU, EST, and MNE.
* They were peaceful transitions. Their graphs of polity and democracy scores are flat lines
* i.e the democracy and polity2 scores are stable for the years for which data is available.
* Using the polity and democracy scores from the data, the missing democ and polity2 values
* in the mortality sample are replaced with the value of the following year.

* sort in descending order to replace with [_n-1] observation
gsort iso -year

* replacing missing polity5 data values, i.e. 1992 in CZE with its 1993 value,
* 1990 in LTU and EST with their 1991 values, and 2005 in MLT with its 2006 value.
foreach var of varlist democ polity2{
    by iso: replace `var' =  `var'[_n-1] if _merge ==  1
}

* taking simple average at the country level
foreach var of varlist democ polity2{
    by iso: egen avg_adm0_`var' =  mean(`var')
}

* set global macros for variable names and title names

global covar "polity2"

global ctit "Polity 2 (institutions)"
