/*

Purpose: Initializes relative paths for carrying out dataset construction
and econometric model estimation.

By default, codes in this directory rely on `cilpath` installation for Stata. 
(See master README for installation instructions.) However, users can alternatively  
specify paths in this script if cilpath is not installed.

cilpath creates three global variables in your Stata session:
`DB` - Directory of all input data to the analysis.
`REPO` - Directory containing this repository (e.g., /User/MGreenstone/repositories).
`OUTPUT` - Directory of all output from the analysis.

This script automatically installs user-created Stata packages if needed, including
any packages written by the Climate Impact Lab team and contained within this repo.

Finally, this script sets the `ISO` global, which controls which countries are included in
dataset construction and model estimation. Note that for data privacy reasons, the 
released versions of code and data do not include USA and China.

*/

quietly {

	clear all
	set more off
	set varabbrev off
	macro drop _all
	cap set processors 8


	*** SET USER PATHS ***
	// Users should specify the locations of the repository, data, and output folders in the
	// following global variables.
	// The folder structures at the data directory must be consistent with that downloaded
	// from the online data repository (see "Downloading the Data" in the master README).

    noisily di "Initializing Mortality Sector..."

	// Base data directory and repo root.
	global base_dir "$DB"
	global code_dir "$REPO/mortality"

	// Sub-directories containing inputs to data cleaning and model estimation.
	global data_dir "$base_dir/0_data_cleaning"
	global cntry_dir "$data_dir/1_raw/Countries"
	global ster_dir "$base_dir/1_estimation/1_ster"
	global csvv_dir "$base_dir/1_estimation/2_csvv"

	// Output directory for regression tables and pre-projection figures.
	global output_dir "$OUTPUT/1_estimation"

	// Download ssc packages.
	local ssc_get reclink estout reghdfe 
	foreach command in `ssc_get' {
		cap which `command'
		if _rc!=0 {
			ssc install `command'
		}
	}

	// Install internal functions.
	local files : dir "$REPO/mortality/0_data_cleaning/1_utils" files "*.ado"
	foreach file in `files' {		
		di "`file'"
		cap do "$REPO/agriculture/1_code/0_programs/`file'"
	}

	// Note: for release repo, remove USA and CHN from this list.
	//global ISO BRA CHL EU JPN USA CHN FRA MEX IND
	global ISO BRA CHL EU JPN FRA MEX IND

	// consistency with prep_data.do and drop IND
	//global ISO_post BRA CHL EUR JPN USA CHN FRA MEX
	global ISO_post BRA CHL EUR JPN FRA MEX

	// country specific ranges of temperatures for response figures. Follows ISO_post. 
 	global x_min_ISO_post 25 -10 -10 -10 -10 -10 -10 -10      
	global x_max_ISO_post 35 30 30 30 30 35 35 30
 
	// age labels for plots, typically. 
	global age_label_1 "age <5" 
	global age_label_2 "age 5-64"
	global age_label_3"age >65"

}
