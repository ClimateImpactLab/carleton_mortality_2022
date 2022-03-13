# Valuing the Global Mortality Consequences of Climate Change Accounting for Adaptation Costs and Benefits

Supporting material for Carleton, Tamma, Amir Jina, Michael T. Delgado, Michael Greenstone, Trevor Houser, Solomon M. Hsiang, Andrew Hultgren, Robert E. Kopp, Kelly E. McCusker, Ishan Nath, James Rising, Ashwin Rode, Hee Kwon Seo, Arvid Viaene, Jiacan Yuan, and Alice Tianbo Zhang, “Valuing the Global Mortality Consequences of Climate Change Accounting for Adaptation Costs and Benefits.” Quarterly Journal of Economics, (forthcoming).

# Description

This repository provides code required to reproduce the tables, figures, and in-text summary statistics in Carleton et al. (2022). This repository's structure mirrors the analysis in the paper, which proceeds in the following **six steps**. 

1. **Data Collection** - Historical data on all-cause mortality and climate are cleaned and merged, along with other covariates needed in our analysis (population and income). 
2. **Estimation** - Econometric analysis is conducted to estimate empirical mortality-temperature relationships for three age groups (<5, 5-64, >64). 
3. **Projection** - The age-specific empirical mortality-temperature relationships are used to project the impacts of climate change on mortality for 24,378 regions through 2100, accounting for both uncertainty in future climate (through the use of the surrogate mixed model ensemble, or SMME) and statistical uncertainty in the econometric model through Monte Carlo simulation.  
    * Note: this step is exceptionally computationally intensive and relies upon Climate Impact Lab's projection system, which is composed of a set of public external repositories. Details on how to link code and data in this repository to the projection system to reproduce all projection results in Carleton et al. (2022) are detailed in the `2_projection/` folder READMEs. 
4. **Valuation** - Various assumptions regarding the Value of Statistical Life (VSL) are applied to projected impacts on mortality risk, yielding a set of economic damage estimates for all years 2020-2100 in constant 2019 dollars purchasing power parity (PPP). Valuation is performed for all Monte Carlo simulation estimates constructed in Step 3.
5. **Damage Function** - Empirical “damage functions” are estimated by relating monetized damages from all Monte Carlo simulations to corresponding Global Mean Surface Temperature (GMST) anomalies from the surrogate mixed model ensemble (SMME).
6. **SCC** - Damage functions are used in combination with the simple climate model FAIR to calculate the net present value of future damages associated with an additional ton of carbon dioxide in 2020, which represents a mortality-only partial social cost of carbon under various Representative Concentration Pathways (RCPs) and Shared Socioeconomic Pathways (SSPs).
    * Note: as in Step 3, estimating uncertainty in the mortality partial SCC (driven both by uncertainty in the damage function and climate uncertainty) is highly computationally intensive and relies on an external repository. However, constructing point estimates of the mortality partial SCC is relatively simple and can be completed fully using code and data contained within this repository. Deatils are provided in the `5_scc/` folder README. 

## Folders

The folders in this repository are broadly consistent with the steps outlined above:

`0_data_cleaning/` - Code for cleaning and constructing the dataset used to estimate the mortality-temperature relationship.

`1_estimation/` - Code for estimating and plotting all mortality-temperature regression models present in the paper.

`2_projection/` - Code for running future projections using Climate Impact Lab projection tools, and extracting, summarizing, and plotting the projection output.

`3_valuation/` - Code for calculating the VSL based on various assumptions and applying those values to our projected impacts of climate change on mortality risk.

`4_damage_function/` - Code for estimating empirical damage functions based upon monetized damages and GMST anomalies.

`5_scc/` - Code for applying a CO2 pulse from the FAIR simple climate model to global damage functions, and summing damages over time to calculate mortality partial SCCs.

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
conda env create -f mortalityverse.yml
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

3. Download data from the [QJE Dataverse](https://dataverse.harvard.edu/dataverse/qje) and unzip it somewhere on your machine with at least 45 GB of space. Let's call this location `yourDATA`.

4. Set up a few environment variables so that all the code runs smoothly.

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

5. Setup for the whole repo is complete! Please follow the `README`s in each subdirectory to run each part of the analysis. In general, each directory will contain one or more staging files where individual analysis or output producing scripts can be run from in one go. Before running, it is recommended that users review and set the TRUE/FALSE toggles to produce the desired set of outputs. More detail is available in the section READMEs. 
