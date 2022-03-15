## User suitability 

**Please note - the code in `3_valuation` does not need to be run in order for a user to work with codes later in the process, given we have included the outputs of this step as csv files in the data repository associated with this repo**

- Coverting the mortality impacts (in deaths/100k) to dollars in the `run_damages.py` valuation script as described below needs to occur at the level of each impact region within each year and each Monte Carlo simulation. However, the full raw Monte Carlo output takes ~30TB of space. We are therefore only releasing moments of this distribution and spatial aggregations which enable the user to fully replicate all tables and figures in the paper. A full release of raw data will be made publicly available at a later date when storage and querying solutions have been developed.
- Given these storage constraints, users will be able to generate monetized valuations of death risk for each impact region, but they will not be able to run the `run_damages.py` script, which values and then aggregates damages at various levels using the full set of raw Monte Carlo output used to generate the paper results. 
- However, we have included key outputs from the `run_damages.py` step, including damages for the main valuation scenario at the impact region level, as well as a file containing global damages from each individual Monte Carlo draw, which serves as the input for the damage function step as described in `4_damage_function/`.
- To interact witht the full functionality of `run_damages.py`, users may also choose to run this script using a single projection simulation as an input, instead of the full Monte Carlo set. 

## Run instructions

### 1. Set directory paths and Python environment.

Please ensure that your `~/.bash_profile` defines the ` REPO`, `DB`, and `OUTPUT` environment variables as instructed in the main README file.  

A number of external packages are required to run the code. We provide a `mortalityverse.yml` file that will allow users to create a `conda` environment with the requisite packages. To do so, install the [latest version](https://docs.conda.io/en/latest/miniconda.html) of `conda` and run the following:

```bash
cd /path/to/carleton_mortality_20223_valuation
conda env create -f mortalityverse.yml
conda activate mortalityverse
```

### 2. Run projections or download Monte Carlo simulation output.
The valuation code in this repository relies upon raw netCDF4 output from the projection system outlined in `2_projection/`. For those attempting to fully replicate this step of the analysis, the raw Monte Carlo simulations must exist in `data`. However, since generating the full set of simulations is far too computationally intensive for the average user, we provide functionality for valuing a single climate model (see below). 

### 3. Calculate Value of Statistical Life (VSL) and related values.
`run_vsl.py` is a "master" script that generates inputs to the valuation of impacts. In particular, it generates (1) the time-varying and spatially-varying monetary VSLs that are multiplied by the mortality risk impacts to achieve monetized damages and, (2) the age-adjustment factors that are required for valuation assumptions which heterogeneously value the three age groups.

### 4. Generate monetized damages by applying the VSL assumptions to projected impacts.

`run_damages.py` is the "master" script which uses the inputs from Step 3 to value projected mortality impacts. This script outputs data at two geographic resolutions:

1. Global damages, which are used to estimate damage functions in `4_damage_functions/`;
2. Impact region level damages, which do not appear directly in the paper, but are used for diagnostic and communication purposes.


## Folder Structure

`1_utils`- Contains functions for initializing the `R` environment and generating the figures and in-text summary stats in Carleton et al. (2022). See the `README` in this folder for details on the functions written for this stage of the analysis.

`2_run_projections` - Configuration files and helpful bash scripts for generating, aggregating, and extracting projected mortality impacts based upon the model inputs generated in `1_estimation`. See the [`impact-calculations`](https://github.com/ClimateImpactLab/impact-calculations) repository for detailed documentation and run instructions for the Climate Impact Lab projection system.

`3_generate_figures` - Contains documented master script for generating figures reflecting monetized mortality risk in Carleton et al. (2022).

`4_in-text_stats` - Contains master script for generating in-text statistics based upon projection and valuation results.
