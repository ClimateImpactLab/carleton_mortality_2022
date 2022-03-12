## Summary of mortality-temperature regression models

This section summarizes the mortality-temperature regression models in Carleton et al. (2022), which are estimated under five robustness specifications with the following assumptions regarding fixed effects, regression method, and data construction:

|                           |               Spec. 1               |                Spec. 2                 |                Spec. 3                 |                Spec. 4                 |                Spec. 5                 |
| :------------------------ | :---------------------------------: | :------------------------------------: | :------------------------------------: | :------------------------------------: | :------------------------------------: |
| Functional form           |        4th order polynomial         |          4th order polynomial          |          4th order polynomial          |          4th order polynomial          |          4th order polynomial          |
| Fixed effects             | (Age x ADM2)  & (Country x Year) FE | (Age x ADM2)  & (Age x Country x Year) | (Age x ADM2)  & (Age x Country x Year) | (Age x ADM2)  & (Age x Country x Year) | (Age x ADM2)  & (Age x Country x Year) |
| Time trend                |                  -                  |                   -                    |        Age x ADM1 linear trend         |                   -                    |                   -                    |
| Regression method         |                 OLS                 |                  OLS                   |                  OLS                   |                  FGLS                  |                  OLS                   |
| Weather data construction |          12-month exposure          |           12-month exposure            |           12-month exposure            |           12-month exposure            |           13-month exposure            |

Note that Specification 2 is the "preferred" model in the analysis. ADM0, ADM1, and ADM2 correspond roughly to country, state, and county administrative units.

The following list provides details on the models in the order in which they appear in the paper. Note that additional detail on the specific inputs and outputs of each script can be found in script headers.

#### 1. All-age mortality-temperature response function estimated using pooled subnational data.

- Location in Carleton et al. (2022): Table D2

* Folder: `1_age_combined`
  * `age_combined_regressions.do` - estimates the model.
  * `age_combined_displayresults.do` - generates Table D2.

- Description: 
  - 4th order polynomial in daily average temperature (GMFD) for the five specifications summarized above.
  - All specs are population weighted regressions with ADM1 unit standard error clustering and AGE x ADM0 precipitation controls.

#### 2. Mortality-temperature response functions for <5, 5-64, and >64 age groups estimated using pooled subnational data.

- Location in Carleton et al. (2022): Table D3

* Folder: `2_age_spec`
    * `age_spec_regressions.do` - estimates the model.
    * `age_spec_displayresults.do` - generates Table D3.

- Description: 
    - 4th order polynomial in daily average temperature (GMFD) for the five specifications summarized above.
    - All specs are population weighted regressions with ADM1 unit standard error clustering and AGE x ADM0 precipitation controls.

#### 3. Mortality-temperature response functions for <5, 5-64, and >64 age groups accounting for spatial heterogeneity in average income and climate.

- Locations in Carleton et al. (2022): 
    - Figures I, D1, D2 and Table D3
    - In-text discussion of the reduction in temperature sensitivity associated with moving between terciles of the interaction space.
    - All projection output is based upon the interaction model estimated here.

* Folder: `3_age_spec_interacted`
    * `age_spec_interacted_regressions.do` - estimates the model.
    * `age_spec_interacted_array_plots_presentation.do`- generates array plots in Figures I, D1, and D2.
    * `age_spec_interacted_displayresults.do` - generates Table D3.
    * `array_output_in-text.do` - generates in-text summary statistics on the changes in temperature-sensitivity associated with changes in income and long-run average temperature.
    * `age_spec_interacted_genCSVV.do` - generates configuration file (or "CSVV") of the main specification for the Climate Impact Lab projection system.
        * See the next step, `2_projection` for a more detailed discussion of this input and how it's implemented in the projection system.
