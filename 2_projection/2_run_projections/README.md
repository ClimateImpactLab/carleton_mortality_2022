## Quick notes on running Mortality projections.

This README provides notes for RAs generating, aggregating, or extracting Mortality projections.

### 1. Required branches and conda environment.

To run the projection, you need to set up your environment according to the projection system requirements. You need both to have the [`risingverse`](https://github.com/ClimateImpactLab/risingverse) (python 3) conda environment installed and the [projection package installed](https://gitlab.com/ClimateImpactLab/Impacts/impact-calculations/-/tree/master#installation).

### 2. Running projections

The `main_specification` folder contains configuration files for generating and aggregating both Monte Carlo and single projections. It also contains `mortality_montecarlo.sh` which is a convenience script for running MC projections. Note that this script primarily wraps `generate.sh` and `aggregate.sh`, adding checks for the correct repositories and conda environment. 

The latest MC projections for mortality live in `/shares/gcp/outputs/mortality/impacts-darwin-u/brc/minpoly30mcs`, however, this directory is symlinked to `/shares/gcp/estimation/mortality/release_2020/data/2_projection/3_impacts/main_specification/raw/montecarlo`  because the original folder structure is not very clear and is pretty inconsistent with where the single projections are located.  Similarly, the various single projections live in `/shares/gcp/outputs/mortality/impacts-darwin` but are symlinked to `/shares/gcp/estimation/mortality/release_2020/data/2_projection/3_impacts/main_specification/raw/single`. Note that there are separate folders within `impacts-darwin` for the various rcp/iam/gcm/ssp combinations so the symlinks to single runs in `data/2_projection/3_impacts` are to several different locations.

Best practice for Mortality going forward is to generate projections in `/shares/gcp/outputs/mortality/impacts-darwin` (or `darwin-u`) because that's where James is used to finding them, and then symlinking them to `data/2_projection/3_impacts/.../raw`, which is a coherent folder structure that will be necessary for data release down the line.

### 3. Running single projections with alternative RCPs/IAMs/GCMs/SSPs

The default single run projects impacts under RCP8.5, high (OECD Econ-growth), CCSM4, SSP3; however most of the single runs that appear in the paper are based up on RCP8.5, _low_ (IIASA), CCSM4, SSP3. 

Changing the single projection inputs isn't as simple as a config parameter as these parameters are hard coded in the projection system. To change them, open `impact-calculations/generate/loadmodels.py` and modify the variables in lines 9-12.

```python
single_clim_model = 'CCSM4'
single_clim_scenario = 'rcp85'
single_econ_model = 'low'
single_econ_scenario = 'SSP3'
```
### 4. Extracting projections

The `extract` folder contains a script and config file for interfacing with `quantiles.py`. `quantiles` runs on Python 2.7, so you should activate`risingverse-py27` when using it. `extract_mortality_impacts.sh` has variables at the top of the script for the various input parameters to `quantiles.py`. Iterables, over which this code will run instances of `quantiles.py`, include SSP, RCP, IAM, age groups, and adaptation scenarios. Other `quantiles.py` specifications include the output "format" (i.e., GCM-batch specific output or a mean/quantile over this distribution), spatial resolution (IR-level or aggregated), units (rates or levels), basename (corresponding to the name of the raw nc4 name without suffixes for the various output variables), default configuration file, and a toggle for whether the `quantiles.py` output should be shown in console or suppressed. Most of these specifications are discussed in more detail in the `prospectus-tools` repo. After specifying the desired options, run with the following:

```bash
bash extract_mortality_impacts.sh extract_mortality.yml
```

The output CSVs are located in `data/2_projection/3_impacts/main_specification/extracted/montecarlo`. Note that most of the R code is set up to read raw netcdf output for single runs, so extracting is mostly only necessary for MCs.

