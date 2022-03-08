# *** SET USER PATHS ***
# Please create your REPO, DB, and OUTPUT variables as outlined in 
# the README doc
#
# Note also that the folder structure within the data directory must be
# consistent with that downloaded from the online data repository  
# (see "Downloading the Data" in the master README). 

REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))


# Import list of required packages.
packages = scan(
	paste0(REPO, "/mortality/2_projection/1_utils/packages.txt"),
	character())

# Load in the required packages, installing them if necessary 
if(!require("pacman")){install.packages(("pacman"))}
pacman::p_load(char=packages)

# Source mortality utils/functions.
Rfiles = Sys.glob(paste0(REPO, "/mortality/2_projection/1_utils/*.R"))
Rfiles = Rfiles[!mapply(x=Rfiles, grepl, MoreArgs=list(pattern='load_utils'))]
null = lapply(Rfiles, source)

# Source CIL-wide utils/functions.
Rfiles = Sys.glob(paste0(REPO, "/mortality/utils/*.R"))
null = lapply(Rfiles, source)
