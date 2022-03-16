##  Running, Aggregating, and Extracting Mortality projections.

This README provides details how projection output is generated in Carleton et. al, 2022. For reasons detailed in the `2_projection` README, we do not provide raw Monte Carlo projection output nor do we advise users to attempt to replicate without significant memory and computing resources. However, the workflow and code in this section describes the process for generating projections, pointing to external repositories when necessary, and details how the extracted projection files provided in the data repository were created. 

### 1. Required branches and conda environment.

To access all of the scripts used to generate projections, you must clone the following repos in your `REPO` directory: [`impact-calculations`](https://github.com/ClimateImpactLab/impact-calculations), [`prospectus-tools`](https://github.com/jrising/prospectus-tools), and [`impact-commons`](https://github.com/ClimateImpactLab/impact-common). To run the projections, you will need to install the `impact-env` conda environment by running the `environment.yml` file as described in the `impact-calculations` REAMDE file.  

### 2. Running projections

The `main_specification` folder contains configuration files (with a `.yml` suffix) for generating and aggregating both Monte Carlo simulations and single-run projections. It also contains `mortality_montecarlo.sh`, which is a convenience script for running Monte Carlo projections. This script primarily wraps the `generate.sh` and `aggregate.sh` scripts in the `impact-calculations` repository, adding checks for the correct repositories and conda environment. 

The relevant input data for this step of the analysis is the regression output stored in CSVV file format, which is generated in the `1_estimation` directory in this repository and is stored in the data release. Please see section V of the paper for more information of how the main age-specific interation model results feed into the gneration of projections.

The default single-run projection generates mortality impacts of climate change under RCP8.5 emissions using the CCSM4 climate model and under the SSP3 socioeconomic scenario using the IIASA model. The Monte Carlo projections are composed of 990 single-runs for each RCP-SSP combination, including 15 random "batches" sampled for 33 climate models for both IIASA and OECD socioeconomic models (sometimes called "IAMs" throughout).

### 3. Extracting projections

The `extract` folder contains a script and config file for interfacing with `quantiles.py`. `quantiles` runs on Python 2.7, so you should activate `risingverse-py27` environment contained in the [`impact-calculations`](https://github.com/ClimateImpactLab/impact-calculations) repo when using it. `extract_mortality_impacts.sh` has variables at the top of the script for the various input parameters to `quantiles.py`. Iterables, over which this code will run instances of `quantiles.py`, include SSP, RCP, IAM, age groups, and adaptation scenarios. Other `quantiles.py` specifications include the output "format" (i.e., GCM-batch specific output or a mean/quantile over this distribution), spatial resolution (impact region-level or aggregated), units (rates or levels), basename (corresponding to the name of the raw nc4 name without suffixes for the various output variables), default configuration file, and a toggle for whether the `quantiles.py` output should be shown in console or suppressed. Most of these specifications are discussed in more detail in the `prospectus-tools` repo. After specifying the desired options, run with the following:

```bash
bash extract_mortality_impacts.sh extract_mortality.yml
```

The output CSVs are located in `data/2_projection/3_impacts/main_specification/extracted/montecarlo`. Note that most of the R code is set up to read raw netcdf output for single runs, so extracting is mostly only necessary for Monte Carlo simulations.

