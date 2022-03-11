## Run instructions

### 1. Set directory paths.
As outlined in the main README, codes in this directory rely on the `REPO`, `DB`, and `OUTPUT` variables to be defined in your `~/.bash_profile`.

- Repository path (global: `REPO` ) - specifies the directory on the user's machine which contains this repository, e.g., `/User/username/repositories`
- Data path (global: `DB`) - specifies the location of the data folder downloaded from the online data repository. See "Downloading the data" in the master README for further instructions. 
- Output path (global: `OUTPUT`) - specifies the folder in which output from the analysis should be saved. This includes all tables and figures in the main text and appendix of Carleton et al. (2022).

### 2. Download the data. 
See [Downloading the Data](addlink) for instructions on accessing the online data repository.
 

### 3. (Optional) Run master do file, `clean.do`. 
`clean.do` is the master script for this step of the analysis, using code in the subfolders of `0_data_cleaning` to construct the final dataset from the raw inputs. `0_data_cleaning` proceeds in four steps. Note that mortality and population data from the United States and China are not publicly available. As such, they are not included in the public data repository and are not included in the scipt that compiles the final `global_mortality_panel.dta` file. 

This step is optional, since the output is saved in `DB/0_data_cleaning/3_final/`. The steps are as follows:

1. Generate ADM2 level climate data and ADM1 level income data.
2. Calculate 30-year bartlett kernel average measures of climate and 13-year bartlett kernel average measures of income, which are covariates in the interacted model.
3. Clean and merge mortality and population data from country-specific sources and construct death rate variables.
4. Merge/append cleaned country data into final dataset.


## Folder Structure

`clean.do` - Master script for running the data cleaning processes, merging together the intermediate country-level datasets, and generating the final dataset.

`1_utils` - Contains functions required for data set construction and `set_paths.do`, which initializes scripts by setting global macros.

`2_clean_covariates` - Cleans raw input data and constructs long-run averages of variables that make up model interaction surfaces, i.e., long-run average climate and income.

`3_clean_merge_countries` - Cleans country-specific input data on mortality and population and merges these data with the climate and income data constructed above.
