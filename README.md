# Valuing the Global Mortality Consequences of Climate Change Accounting for Adaptation Costs and Benefits

Supporting material for Carleton, Tamma, Amir Jina, Michael T. Delgado, Michael Greenstone, Trevor Houser, Solomon M. Hsiang, Andrew Hultgren, Robert E. Kopp, Kelly E. McCusker, Ishan Nath, James Rising, Ashwin Rode, Hee Kwon Seo, Arvid Viaene, Jiacan Yuan, and Alice Tianbo Zhang, “Valuing the Global Mortality Consequences of Climate Change Accounting for Adaptation Costs and Benefits.” Quarterly Journal of Economics, (forthcoming).

# Desciption

This repository provides code required to reproduce the tables, figures, and in-text summary statistics in Carleton et al. (2022). This repository's structure mirrors the analysis in the paper, which proceeds in the following **six steps**. 

1. **Data Collection** - Historical data on all-cause mortality and climate are cleaned and merged, along with other covariates needed in our analysis (population and income). 
2. **Estimation** - Econometric analysis is conducted to estimate empirical mortality-temperature relationships for three age groups (<5, 5-64, >64). 
3. **Projection** - The age-specific empirical mortality-temperature relationships are used to project the impacts of climate change on mortality for 24,378 regions through 2100, accounting for both uncertainty in future climate and statistical uncertainty in the econometric model.  
    * Note: this step is exceptionally computationally intensive and relies upon a separate repository for projecting climate change impacts. See `impact-calculations` **(add link to the projection system when public)** for documentation on Climate Impact Lab's projection system.
4. **Valuation** - Various assumptions regarding the Value of Statistical Life (VSL) are applied to projected impacts on mortality risk, yielding a set of economic damage estimates for all years 2020-2100 in constant 2019 dollars purchasing power parity (PPP).
5. **Damage Function** - Empirical “damage functions” are estimated by relating monetized damages to Global Mean Surface Temperature (GMST) anomalies from the surrogate mixed model ensemble (SMME).
6. **SCC** - Damage functions are used in combination with the simple climate model FAIR to calculate the net present value of future damages associated with an additional ton of carbon dioxide in 2020, which represents a morality-only partial social cost of carbon under various Representative Concentration Pathways (RCPs).
    * Note: as in Step 3, the code used to produce SCC output lives in a separate repository because it is a computationally complex process that is highly generalizable across Climate Impact Lab sectors. See `pFAIR` **(add link to pFAIR when public)** for more information.

## Folders

The folders in this repository are broadly consistent with the steps outlined above:

`0_data_cleaning` - Code for cleaning and constructing the dataset used to estimate the mortality-temperature relationship.

`1_estimation` - Code for estimating and plotting all mortality-temperature regression models present in the paper.

`2_projection` - Code for running future projections using Climate Impact Lab projection tools (see `link-to-impact-calc`) and extracting, summarizing, and plotting the projection output.

`3_valuation` - Code for calculating the VSL based on various assumptions and applying those values to our projected impacts of climate change on mortality risk.

`4_damage_function` - Code for estimating empirical damage functions based upon monetized damages and GMST anomalies.

`5_scc` - Code (or documentation) outlining the SCC calculation, which relies upon mortality damage functions.

`data` - Default directory for input data required to generate outputs.

`output` - Default directory for tables, figures, and other outputs produced by codes in this analysis.

For run instructions on each step of the analysis, refer to the README files located within the corresponding directories.

# Setup

## Requirements For Using Code In This Repo

1. You need to have `python`, `Stata`, and `R` programming capabilities, or at least environments to run code in these languages, on your computer. 

2. We use `conda` to manage `python` enrivonments, so we recommend installing `conda` if you haven't already done so following [these instructions](https://docs.conda.io/projects/conda/en/latest/user-guide/install/macos.html). 

## Setup Instructions

1. Clone the following repos to a chosen directory, which we'll call `yourREPO` from now onwards, with the following commands: 
```
cd <yourREPO>
git clone https://github.com/ClimateImpactLab/carleton_mortality_2022.git
```

2. Install the `conda` environment included in this repo by running the following commands under the root of this repo:

```
cd <yourREPO>/carleton_mortality_2022
conda env create -f mortalityverse.yaml
```

Try activating the environment:
```
conda activate mortalityverse
```
Please remember that you will need to activate this environment whenever you run python scripts in this repo, including the `pip install -e .` commands in the following section.

Also, you need to install Jupyter for the scc calculation code
```
conda install -c conda-forge jupyterlab
```

 **(do we need to tell users to clone impact `impact-calculations`, `open-estimate` and `impact-common` if they are only dealing with extracted files??)**


3. Download data from `add_link_here` and unzip it somewhere on your machine with ** XX GB+** space. Let's call this location `yourDATA`.


4. Set up a few environmental variables so that all the code runs smoothly.

On Mac, you can do this by appending the following lines to your `~/.bash_profile`.

First, run:
```
nano ~/.bash_profile

```

Then, point the variable `DB` in the `yourDATA` dierctory in the downloaded data, and do the same for `OUTPUT`. Point the `REPO` variable to `yourREPO` path used above containing this repo and other repos by adding the following lines to `.bash_profile`:

```
export REPO=<yourREPO>
export DB=<yourDATA>/data
export OUTPUT=<yourDATA>/output
export LOG=<yourDATA>/log

```
Save and exit. 
Then, run `source ~/.bash_profile` to load the changes we just made.

On Windows.....

**(do we any description of how to install/run stata)** 

5. Setup for the whole repo is complete! Please follow the `README`s in each subdirectory to run each part of the analysis. In general, each directory will come with a `.sh` bash script which you can use `./path_to_bash_script.sh` to run scripts in that subdirectory. If you encounter the permission denied error, use `chmod +x path_to_bash_script.sh` to make it runnable.
