## Run instructions

### 1. Calculate SCC based upon estimated damage functions.

Due to the computational complexity and relative generalizability of this last step of the analysis, the codes used to produce estimates of the mortality-only partial social cost of carbon are located in the [pFAIR](https://gitlab.com/ClimateImpactLab/Climate/pFAIR) repository.

`pFAIR` contains Jupyter Notebooks that estimate the mortality-only partial social cost of carbon using the simple climate model FAIR and the damage functions computed in `4_damage_functions`. Specifically, the code does the following:

- Calculates GMST under the RCP scenarios as defined by the default FAIR model
- Adds an additional CO2 impulse (1 Gt C) to each trajectory in 2020
- Computes damages using the resulting GMST trajectories
- Subtracts the damages in the standard RCPs from the damages in the pulse scenario runs
- Divides this value by the quantity of added CO2 (1 Gt C * 44.0098 / 12.011 = 3.66 Gt CO2) to achieve \$/ton CO2
- Computes the NPV of this time series of marginal damages using various discount rates

To operate the code, navigate to the latest mortality notebook in `pFAIR/damages` (currently `v.0.5`) and follow the steps outlined in the documentation. The crucial link between the `pFAIR` notebooks and this repository is the output directory of the damage functions generated in `4_damage_function` . Be sure that the paths specified in the notebook correspond to the correct damage function coefficient output (i.e., the intended csv file in `data/4_damage_function/damages`). The corresponding output path should be `data/5_scc/global`.

`pFAIR` estimates SCCs under several types of uncertainty, following Carleton et al. (2019):

1.  **Point estimates**: SCC estimates based on the median fair parameters and mean damage functions.
2. **Climate-only uncertainty**: SCC estimates based on Monte Carlo draws from FAIR uncertainty and mean damage functions.
3. **Damage function uncertainty**: SCC estimates based on median fair parameters and quantile damage functions.
4. **Full uncertainty**: SCC estimates based on Monte Carlo draws from the FAIR uncertainty and quantile damage functions.

See the `pFAIR` documentation for instructions on running the various types of uncertainty presented in Carleton et al. Note that the tables showing SCC uncertainty in the main text and appendix of Carleton et al (2020) provide the IQR from these runs.

Alongside the main SCC table in the paper, which displays SCC estimates under each emissions scenario for a globally varying value of a statistical life (i.e., `vsl`, `epa`, `scaled`below) and an age-adjusted globally varying value of a statistical life i.e., `vly, `epa`, `scaled` below) , the appendix presents SCCs based upon a range of alternative valuation assumptions. The following provides a summary of all valuation assumptions presented in Carleton et al. (2019):

Age adjustment assumption:

- Value of a statistical life (`vsl`) consists of a single value associated with every death due to climate change
- Age-adjusted value of a statistical life (`vly`) values climate change deaths based upon expected life-years lost.
- Heterogeneous valuation of life years (`mt`) based upon Murphy and Topel (2006).

VSL source assumption:

- Underlying VSL based upon the EPA's latest value in the 2012 U.S. EPA Regulatory Impact Analysis for the Clean Power Plan Final Rule (`epa`)
- Underlying VSL based upon Ashenfelter and Greenstone (2004) (`ag`)

Income-scaling assumption:

- Globally varying VSL based on the ratio of projected incomes to USA GDP per capita in the year consistent with the VSL used (e.g., 2019 incomes consistent with the EPA value) (`scaled`)
- Globally uniform VSL based upon the population-weighted average of the income-scaled values (`popavg`)

There are also several robustness SCC results provided in the appendix:

1. Estimates of SCC under various socioeconomic projections;
2. Estimates of SCC using a 1.5% discount rate;
3. Estimates of SCC in which the estimated 2100 damage function is applied to all years from 2100-2300 (rather than extrapolating damage functions beyond 2100); and,
4. Estimates of SCC using a cubic polynomial damage function.

### 2. Calculate SCCs based upon Ashenfelter and Greenstone (2004) VSL by scaling EPA-based SCCs.

The analysis uses an income elasticity of 1 when income-scaling the VSLs, allowing us to cut down on the computational complexity of the SCC step by scaling our `epa` SCC by the ratios of VSLs and GDP per capita associated with the EPA and Ashenfelter and Greenstone (2004) analyses. This scaling is performed by the helper function in this folder of the repository `scale_ag02_scc.py`

## Description of relevant directories

`data/5_scc/global_scc` - location in which output is saved from the SCC calculation notebooks.

- `quadratic` contains folders for the main specification (including uncertainty) and all the robustness checks except for the cubic damage function robustness check.
- `cubic` contains output from the cubic damage function robustness check.

`output/5_scc` - location of tables and figures in Carleton et al (2019).

- `tables` contains Latex files for each SCC presentation table in the paper. These are generated manually from the output in `data/5_scc/global_scc`.
- `figures` contains SCC-related figures that appear in the appendix of the paper. These are output by the SCC notebooks in `pfair`. 