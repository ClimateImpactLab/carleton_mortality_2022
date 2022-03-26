## Run instructions


### 1. Set directory paths and Python environment.

Please ensure that your `~/.bash_profile` defines the ` REPO`, `DB`, and `OUTPUT` environment variables as instructed in the main README file.  

A number of external packages are required to run the code. We provide a `mortalityverse.yml` file that will allow users to create a `conda` environment with the requisite packages. To do so, install the [latest version](https://docs.conda.io/en/latest/miniconda.html) of `conda` and run the following:

```bash
cd /path/to/carleton_mortality_2022/
conda env create -f mortalityverse.yml
conda activate mortalityverse
```

### 2. Calculate SCC point estimates and damage function uncertainty based upon estimated damage functions.

Carleton et al. (2022) reports several types of uncertainty in mortality partial SCCs (see Section VII of the main text for details):

1. **Point estimates**: SCC estimates based on the median FAIR parameters and mean damage functions.
2. **Damage function uncertainty**: SCC estimates based on median FAIR parameters and a set of quantile damage functions.
3. **Climate-only uncertainty**: SCC estimates based on Monte Carlo draws from FAIR uncertainty and mean damage functions.
4. **Full uncertainty**: SCC estimates based on Monte Carlo draws from FAIR uncertainty and a set of quantile damage functions.



`FAIR_pulse.ipynb` is ther Jupyter notebook that estimates the mortality-only partial social cost of carbon using the simple climate model FAIR and the damage functions computed in `4_damage_function/`. Specifically, the code does the following:

- Calculates GMST under the "baseline" RCP scenarios as defined by the default FAIR model
- Adds an additional CO2 impulse (1 Gt C) to each trajectory in 2020 to create a "baseline+pulse" trajectory
- Computes damages under both "baseline" and "baseline+pulse" using the resulting GMST trajectories and the damage functions computed in `4_damage_function/`
- Subtracts the damages in each "baseline" scenario from the damages in each corresponding "baseline+pulse" scenario 
- Divides this value by the quantity of added CO2 (1 Gt C * 44.0098 / 12.011 = 3.66 Gt CO2) to convert to \$/ton CO2
- Computes the NPV of this time series of marginal damages using various discount rates

`FAIR_pulse.ipynb` can be run to calculate both the point estimates of the SCCs as well as the damage function (ie econometric) uncertainty. 

To operate the code, first ensure that you are in the `mortalityverse` conda environment. 

Then, it is recommended you run the notebook cell by cell. There are a few toggles explained in the notebook which allow users to: calculate the point estimate of SCCs or to compute damage function uncertatinty leading to a range of SCCs, produce SCCs including or excluding adaptation costs, and other functionality. The toggles are currently configured to calculate the point estimate SCCs for SSP3 including the costs of adaptation. 

Given the large computational and storage requirements needed to calculate climate uncertainty using FAIR, the climate uncertainty SCCs and full uncertainty SCCs are computed in the second notebook, `full_uncertainty_ensemble.ipynb`. This notebook is set up to deploy server clusters  in ordrer to run the 100,000 climate simulations within the FAIR model. This uses an extraordinary amount of memmory, so it is not recommended users attempt to replicate this step without significant computational and data storage resources.

`full_uncertainty_ensemble.ipynb` operates in a similar manner to the `FAIR_pulse.ipynb`, but with the added complexity of the inclusion of the climate simulations. 

The outputs of these notebooks are CSV files saved in `DB/5_scc/global_scc/quadratic/`, which store SCCs by valuation type, heterogeneity SSP, RCP, discount rate, and quantile (if running damage function uncertainty). The values that appear in Table III are contained within these files.

Alongside the main SCC table in the paper, which displays SCC estimates under each emissions scenario for a globally varying value of a statistical life that is age-adjusted (i.e., the `vly`, `epa`, `scaled` terminology below), Appendix tables H2, H3, H4 present SCCs based upon a range of alternative valuation assumptions, and show IQRs of the types of uncertainty descriped above. The following provides a summary of all valuation assumptions presented in Carleton et al. (2022):

Age adjustment assumption:

- Value of a statistical life (`vsl`) consists of a single value associated with every death due to climate change (regardless of age at death).
- Age-adjusted value of a statistical life (`vly`) values climate change deaths based upon expected life-years lost. This assigns the same value to an additional year of life regardless of age.
- Heterogeneous valuation of life years (`mt`) based upon Murphy and Topel (2006). This uses a life-years lost approach as in `vly`, but assigns a heterogeneous value to an additional year of life based on age, following the age profile in Murphy and Topel (2006). 

VSL source assumption:

- Underlying VSL based upon the EPA's latest value in the 2012 U.S. EPA Regulatory Impact Analysis for the Clean Power Plan Final Rule (`epa`).
- Underlying VSL based upon Ashenfelter and Greenstone (2004) (`ag`).

Income-scaling assumption:

- Globally varying VSL based on the ratio of projected income per capita at impact region level to USA GDP per capita in the year consistent with the VSL used (e.g., 2019 incomes consistent with the EPA value) (`scaled`). This is equivalent to an income elasticity of one for the VSL.
- Globally uniform VSL based upon the population-weighted average of the income-scaled values (`popavg`). This is equivalent to an income elasticity of one for the VSL over time, but no income elasticity is applied over space.

There are also several robustness SCC results provided in the appendix:

1. Estimates of SCC under various socioeconomic projections (Table H4);
2. Estimates of SCC including or excluding adaptation costs (Panel B of Table III);
3. Estimates of SCC in which the estimated 2100 damage function is applied to all years from 2100-2300 (rather than extrapolating damage functions beyond 2100; Table H6); and,
4. Estimates of SCC using a cubic polynomial damage function (Table H7).

### 3. Calculate SCCs based upon Ashenfelter and Greenstone (2004) VSL by scaling EPA-based SCCs.

The analysis uses an income elasticity of 1 when income-scaling the VSLs, allowing us to cut down on the computational complexity of the SCC step by scaling our `epa` SCC by the ratios of VSLs and GDP per capita associated with the EPA and Ashenfelter and Greenstone (2004) analyses. This scaling is performed by the `Ashenfelter_Greenstone` function contained within the `FAIR_pulse.ipynb` notebook. This function is called at the very end as it inputs the SCC `.csv` file generated in a given run, applies the conversion to an appended set of variables, and saves a new output `.csv` file with a `_ag02` suffix.

The function is stored in `functions/scale_ag02_scc.py`, where further documentation outlines the process of the conversion.

While it is most convenient to run this as a part of the workflow mentioned in step 2, the function can also be run alone as long as a relevant input file exists.

## Description of relevant directories

`data/5_scc/global_scc/` - location in which output is saved from the SCC calculation notebooks.

- `quadratic/` contains folders for the main specification (including uncertainty) and all the robustness checks except for the cubic damage function robustness check.
  - `wo_costs/` contains SCCs calculated without adaptation costs (Panel B in Table III in Carleton et al., 2022). The default is with costs (Panel A in Table III).
  - `uncertainty/` contains quantiles of SCCs using damage function, climate, and full uncertainty. While users can only calculate the first, the output of all 3 are stored in this colder
- `cubic/` contains output from the cubic damage function robustness check. 

`output/5_scc/` - location of tables and figures in Carleton et al (2022).

- `tables/` contains Latex files for each SCC table in the paper. These are generated manually from the output in `data/5_scc/global_scc/`.
- `figures/` contains SCC-related figures that appear in the appendix of the paper. These are output by the SCC notebooks in this repo. 
