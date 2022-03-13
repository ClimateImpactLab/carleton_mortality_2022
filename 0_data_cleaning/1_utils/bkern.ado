/*

Purpose: 
	Create moving triangular kernel of n years for a panel dataset

Args:
	xtgrpvars 	- group of variables to identify unique timerseries w/in a panel
	xttimevar 	- timevar must be in xtset format (see 'help xtset##unitoptions')
	xttimeunit 	- time unit must match timevar format (eg: 'y':year, 'd':day)
	xtdel		- timeset for xtset (normally '1')
	kernvars 	- vars overwhich to calculate the kernal average
	kernlen 	- lengths of kernel
	
*/


program define bkern
version 14.2

args xtgrpvars xttimevar xttimeunit xtdel kernvars kernlen

* set data as a panel
tempvar uid
egen `uid' = group(`xtgrpvars'), missing
xtset `uid' `xttimevar', `xttimeunit' del(`xtdel')
tsfill

* generate bartlett kernel averages 
foreach var in `kernvars' { 
	gen `var'_`kernlen'br = .

	* use a smaller kernel at the beginning of a timeseries 
	forvalues kk = `kernlen'(-1)1 {   
		local exp `kk'*L0.`var'
		forvalues ii = 2/`kk' {
			local mm = `ii' - 1
			local jj = `kk' - `ii' + 1
			local exp `exp' + `jj'*L`mm'.`var'
		}
		local div = (1 + `kk')/2 * `kk'
		replace `var'_`kernlen'br = (`exp') / `div' if mi(`var'_`kernlen'br)
	}	

	order `var'_`kernlen'br, after(`var')
	local label : variable label `var'
    lab var `var'_`kernlen'br "`label' (`br' `xttimeunit' bartlett)"
}

xtset, clear

end 
