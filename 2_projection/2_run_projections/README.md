##  Running, Aggregating, and Extracting Mortality projections.

This README provides details how projection output is generated in Carleton et. al, 2022. For reasons detailed in the `2_projection` README, we do not provide raw Monte Carlo projection output nor do we advise users to attempt to replicate without significant memory and computing resources. However, the workflow and code in this section describes the process for generating projections, pointing to external repositories when necessary, and details how the extracted projection files provided in the data repository were created. 

### 1. Required branches and conda environment.

To access all of the scripts used to generate projections, you must clone the following repos in your `REPO` directory: [`impact-calculations`](https://github.com/ClimateImpactLab/impact-calculations), [`prospectus-tools`](https://github.com/jrising/prospectus-tools), and [`impact-commons`](https://github.com/ClimateImpactLab/impact-common). To run the projections, you will need to install the `impact-env` conda environment by running the `environment.yml` file as described in the `impact-calculations` REAMDE file.  

### 2. Projection overview

In the previous `1_estimation` step, we generated a `CSVV` file, which stores the coefficients and standard errors of our main Age-specific interaction model (`{DB}/1_estimation/2_csvv/Agespec_interaction_response.csvv`), allowing us estimate a mortality-temperature response function for a given region based on the values of it's covariates, GDP per capita (`loggdppc`) and long run climate (`climtas`).

In the projection step, we pair these reponse functions with future climate, income, and population growth pathways (RCP, SSP, IAM) under historical climate and various adaptation scenarios to estimate the mortality impacts of climate change. We account for uncertainty through the deployment of a Monte Carlo method - accounting for both climate uncertainty through the use of various climate models and econometric uncertatinty by drawing model coefficients based on theie point estimates and standard errors. 

All together, a Monte Carlo (MC) projection run generates 495 single projections for a given RCP-SSP-IAM scenario: 15 random "batches" of 33 climate models, however the 990 single projections from both IAMs feed into the global `4_damage_function` estimation. The standard combination used to generate charts and tables displaying higher resolution and time series impacts in Carleton et al. 2022 is RCP 8.5 - SSP3 - IIASA economic model. Projection results are generally stored in the deaths/100k unit.

In the steps following the Monte Carlo generation, impact-region impacts are aggregated to global, country-level, and regional levels, then GCM weighted means and qunatile values are extracted from the MC output files. These "extrated" files are the ones provided in the data repository for this paper, stored in the `{DB}/2_projection/3_impacts/main_specification/extracted/montecarlo` folder. Additionally, extracted files of other model specifications used to make various appendix charts and a single projection's output files (RCP8.5-CCSM4-SSP3-IIASA) used to plot the individual response functions are provided.

### 3. Running projections

The scripts to generate projections mostly exist in the `impact-calculations` repo. The `main_specification` folder contains the configuration files (in the `configs` folder) for that feed inputs into the scripts generating and aggregating both Monte Carlo simulations and single-run projections. They are currently configured to generate projection output with the main specifications described above. 

`mortality_montecarlo.sh` is a convenience script that allows the user to populate arguments and run Monte Carlo projections from this repository. The script primarily wraps the `generate.sh` and `aggregate.sh` scripts in the `impact-calculations` repository, adding checks for the correct repositories and conda environment. To execute the script, you would run the following from your terminal:

```bash
bash mortality_montecarlo.sh
```

### 4. Extracting projections

The `extract` folder contains a script and config file for interfacing with `quantiles.py` script in the `prospectus-tools` repo. `extract_mortality_impacts.sh` has variables at the top of the script for the various input parameters to `quantiles.py`. Iterables, over which this code will run instances of `quantiles.py`, include SSP, RCP, IAM, age groups, and adaptation scenarios. Other `quantiles.py` specifications include the output "format" (i.e., GCM-batch specific output or a mean/quantile over this distribution), spatial resolution (impact region-level or aggregated), units (rates or levels), basename (corresponding to the name of the raw nc4 name without suffixes for the various output variables), default configuration file, and a toggle for whether the `quantiles.py` output should be shown in console or suppressed. Most of these specifications are discussed in more detail in the `prospectus-tools` repo. After specifying the desired options, run with the following:

```bash
bash extract_mortality_impacts.sh extract_mortality.yml
```

The output CSVs are located in `{DB}/2_projection/3_impacts/main_specification/extracted/montecarlo`.

