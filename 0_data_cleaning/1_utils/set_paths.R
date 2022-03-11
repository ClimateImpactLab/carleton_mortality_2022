library(glue)

#  SET USER PATHS 

#  If cilpath is not installed, users can specify the locations of the
#  repository, data, and output folders in the following local variables. Note that
#  the folder structures at the data directory must be consistent with that downloaded
#  from the online data repository (see "Downloading the Data" in the master README).

REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

message("Initializing Mortality Sector...")

# Base data directory and repo root.
base_dir 	<- glue("{DB}")
code_dir 	<- glue("{REPO}/mortality")

# Sub-directories containing inputs to data cleaning and model estimation.
data_dir 	<- glue("{base_dir}/0_data_cleaning")
cntry_dir 	<- glue("{data_dir}/1_raw/Countries")
ster_dir 	<- glue("{base_dir}/1_estimation/1_ster")
csvv_dir 	<- glue("{base_dir}/1_estimation/2_csvv")

# Output directory for regression tables and pre-projection figures.
output_dir 	<- glue("{OUTPUT}/1_estimation")

# Note: for release repo, remove USA and CHN from this list.
ISO <- "BRA CHL EU JPN USA CHN FRA MEX IND"