## Run instructions

### 1. Set directory paths.

Code in `0_data_cleaning` operates using `cilpath` for Stata.  If `cilpath` is not installed, users can manually specify the relevant base directories within `estimate_damage_functions.do`.  The folders necessary for running the code are the following:

- Repository path (global: `REPO` ) - specifies the directory on the user's machine which contains this repository, e.g., `/User/MGreenstone/repositories`
- Data path (global: `DB`) - specifies the location of the data folder downloaded from the online data repository. See "Downloading the data" in the master README for further instructions. 
- Output path (global: `OUTPUT`) - specifies the folder in which output from the analysis should be saved. This includes all tables and figures in the main text and appendix of Carleton et al. (2019). 

### 2. Run global valuation or download damages.

The damage function code in this repository relies upon globally aggregated monetized mortality damages from climate change.  See `3_valuation` for instructions on running the valuation portion of the analysis, or download the global ddata from the [online data repository](https://gitlab.com/ClimateImpactLab/Impacts/mortality/-/tree/dylan#downloading-the-data).


### 3. Estimate quadratic damage functions under various valuation scenarios.

`estimate_damage_functions.do` generates damage function coefficients by relating global monetized climate change damages to GMST anomalies from SMME. It also produces several plots for Figure 11 of Carleton et al. (2019). See the script header for more information regarding the damage function estimation procedure, running the code, and the locations of relevant inputs and outputs.

## Folder Structure

`estimate_damage_functions.do` - master script for estimating damage functions, as described above.

`extract_gmst`- folder containing code for extracting and smoothing GMST anomalies from the SMME data stored on CIL servers.

