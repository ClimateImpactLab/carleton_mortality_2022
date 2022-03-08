##  Running, Aggregating, and Extracting Mortality projections.

This README provides details how projection output is generated in Carleton et. al, 2022. For reasons detailed in the `2_projection` README, we do not provide raw Monte Carlo projection output nor do we advise users to attempt to replicate without significant memory and computing resources. However, by following the workflow and viewing the code in this section provides detail into how the extracted projection files provided in the data repository were created. 

### 1. Required branches and conda environment.

To access all of the scripts used to generate projections, you must clone the following repos in your `REPO` directory: `imapct_calculations`[https://gitlab.com/ClimateImpactLab/Impacts/impact-calculations], `prospectur_tools`[https://github.com/jrising/prospectus-tools], and `impact-commons`[XX]. To run the projections, you will need to install the `impact-env` conda environment by running the `environment.yml` file as described in the `impact-calculations` REAMDE file.  

### 2. Running projections

The `main_specification` folder contains configuration files (with a `.yml` suffix) for generating and aggregating both Monte Carlo and single projections. It also contains `mortality_montecarlo.sh` which is a convenience script for running MC projections. This script primarily wraps the `generate.sh` and `aggregate.sh` scripts in `impact-calculations`, adding checks for the correct repositories and conda environment. 

The relevant input from this repo is the regression output CSVV files, which are generated in the `1_estimation` branch and stored in the data repository. Please see section [XX] of the paper for more information of how the main age-specific interation model results feed into the gneration of projections.


The default single run projects impacts under RCP8.5, low (IIASA), CCSM4, SSP3, while the Monte Carlo is composed of 990 singles within a RCP-SSP combination, including 15 batches for 33 climate models for 2 IAMs.

### 3. Extracting projections

The `extract` folder contains a script and config file for interfacing with `quantiles.py`. `quantiles` runs on Python 2.7, so you should activate`risingverse-py27` environment contained in the [XX repo] when using it. `extract_mortality_impacts.sh` has variables at the top of the script for the various input parameters to `quantiles.py`. Iterables, over which this code will run instances of `quantiles.py`, include SSP, RCP, IAM, age groups, and adaptation scenarios. Other `quantiles.py` specifications include the output "format" (i.e., GCM-batch specific output or a mean/quantile over this distribution), spatial resolution (IR-level or aggregated), units (rates or levels), basename (corresponding to the name of the raw nc4 name without suffixes for the various output variables), default configuration file, and a toggle for whether the `quantiles.py` output should be shown in console or suppressed. Most of these specifications are discussed in more detail in the `prospectus-tools` repo. After specifying the desired options, run with the following:

```bash
bash extract_mortality_impacts.sh extract_mortality.yml
```

The output CSVs are located in `data/2_projection/3_impacts/main_specification/extracted/montecarlo`. Note that most of the R code is set up to read raw netcdf output for single runs, so extracting is mostly only necessary for MCs.

