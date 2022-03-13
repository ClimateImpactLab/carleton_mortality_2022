********************************************************************************
*** LEAVE-ONE-OUT CROSS VALIDATION v.1.0.2
********************************************************************************

/* Function that randomly divides sample into 10 nearly equally sized ADM1 groups,
   and randomly leaves one out to run a regression with the other 9. Then, it predicts
   Y for that group out of sample. 

   In order to interpret the RMSE, the data must be residualized
 */ 

cap prog drop adminfoldcrossval
prog def adminfoldcrossval, rclass
version 11.0
syntax anything [aweight fweight iweight pweight/] [if] [in] using/, [cc(varname)] [EWeight(varname)] *

	if "`using'" == "" {
		di in red "Must specify saving file."
	}

	if "`weight'" != "" {
		local weight = "[weight=`exp']"
	}
	
	if "`eweight'" != "" {
		local eweight = "[weight=`eweight']"
	}
	
	tempvar yhat ehat sqdiff absdiff results group rand adminfact

	*quietly {	

		preserve

			*run regression
			`anything' `if' `in' `weight' 
			keep if e(sample)
			
			g diff=.
			g Yhat=.

			*generate list of groups to loop over
			if "`cc'"=="adm1_code"{

				*adm1 fold is implemented by grouping observations into 10 folds under adm1 unity constraint. 
				g `rand' = uniform()
				bysort `cc' : replace `rand'=`rand'[1]
				xtile kfold = `rand', n(10)
				tostring kfold, replace

			}
			else if "`cc'"=="iso"{
				gen kfold = `cc' 
				replace kfold = "EU" if eu_country
			} 
			else {
				di "please correctly specify the admin group"
				BREAK
			}

			egen `adminfact' = group(kfold)
			levelsof kfold, local(adminlist)

			gunique `adminfact'
			local admincount = `r(unique)'
			* add a row for the 'total' stats
			local totalcount = `admincount' + 1
			// set up matrix to output results
			mat `results' = J(`totalcount',4,.)

			mat rownames `results' = "Total" `adminlist'

			mat colnames `results' = "RMSE" 
			// loop over countries, regress without that country, store in that country.
			di " "
			di "################## STARTING TO CROSS VALIDATE #####################"
			di " "
			foreach admin in `adminlist' {

				di " "
				di " ESTIMATING WITHOUT `admin' AND PREDICTING WITH `admin' only"
				
				`anything' if kfold!="`admin'" `weight'
				est save "`using'_`admin'.ster", replace
				di "SAVED .STER FILE using `using'_`admin'"
				di "Command finished at $S_TIME"

				local depvar = e(depvar)

				predict `yhat' if kfold=="`admin'" `eif' `ein'
				
				g `ehat' =  `depvar' - `yhat'

				replace diff = `ehat' if kfold=="`admin'"
				replace Yhat = `yhat' if kfold=="`admin'"

				drop `ehat' `yhat'
			}

			save "`using'.dta", replace
			di "SAVED .DTA FILE using `using'"

			* RMSE:
			g `sqdiff' = diff^2

			sum `sqdiff' `eweight'
			scalar cv1 = sqrt(r(mean))
			return scalar rmse = cv1
			mat `results'[1,1]  = cv1

			foreach admin in `adminlist' {
				di "`admin'"
				loc ii = rownumb(`results',"`admin'")
				sum `sqdiff' `eweight' if kfold == "`admin'"
				scalar cv1`admin' = sqrt(r(mean))
				mat `results'[`ii',1]  = cv1`admin'

			}

			
		restore
	*}

	display _newline
	display as text "admin-fold Cross-Validation Results "
	di as text "{hline 25}{c TT}{hline 15}"		
	di as text "         Method          {c |}" _col(30) " Value"
	di as text "{hline 25}{c +}{hline 15}"	
	display as text "Root Mean Squared Errors {c |}" _col(30) as result cv1
	di as text "{hline 25}{c BT}{hline 15}"	
		
	
end
