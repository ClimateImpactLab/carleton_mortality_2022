## Run instructions

### 1. Set directory paths.

Please ensure that your ~/.bash_profile defines the `REPO`, `DB`, and `OUTPUT` environment variables as instructed in the main README file.

### 2. Run global valuation or download damages.

The damage function code in this repository relies upon globally aggregated monetized mortality damages from climate change. These CSV files are the outputs from the valuation of the projected impact Monte Carlo draws as described in `3_valuation`. These files can be found in the following directory where `DB` is the user defined directory containing the data repository: `DB/3_valuation/global/`. The default file used in the paper is `mortality_global_damages_MC_poly4_uclip_sharecombo_SSP3.csv`.

### 3. Estimate quadratic damage functions under various valuation scenarios.

`estimate_damage_functions.do` generates damage function coefficients by relating global monetized climate change damages to GMST anomalies from the surrogate mixed model ensemble (SMME). It also produces the 2 panels that compose Figure VII of Carleton et al. (2022). See the script header for more information regarding the damage function estimation procedure, running the code, and the locations of relevant inputs and outputs.

## Folder Structure

`estimate_damage_functions.do` - master script for estimating damage functions, as described above.
