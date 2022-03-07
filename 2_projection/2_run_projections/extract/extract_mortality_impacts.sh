#!/bin/bash

# Iterables
ssplist=( SSP3 ) # SSP1, SSP2, SSP3, SSP4, SSP5
rcplist=( rcp85 ) # rcp45, rcp85
iamlist=( low ) # low, high
agelist=( combined )  # young, older, oldest, combined
scnlist=( fulladaptcosts ) # noadapt incadapt fulladapt costs fulladaptcosts

# Specifications
format="edfcsv" # edfcsv, valuescsv
spatial="aggregated" # aggregated, ir_level
unit="levels" # rates, levels
basename=Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1
default_config=extract_mortality
show_output='TRUE'


DATA="${DB}/2_projection/3_impacts/main_specification" 
results_root="$DATA/raw/montecarlo"

CONFIG=${REPO}/mortality/2_projection/2_run_projections/extract/extract_mortality.yml
echo $CONFIG

cd ${REPO}/prospectus-tools/gcp/extract
# conda activate risingverse-py27

for ssp in ${ssplist[@]}; do
	for rcp in ${rcplist[@]}; do
		for iam in ${iamlist[@]}; do
			for age in ${agelist[@]}; do
				for scn in ${scnlist[@]}; do

					output=${DATA}/extracted/montecarlo/${rcp}/${iam}/${ssp}
					mkdir -p ${output}
					insuffix="-${age}"
					outsuffix="-${age}-${scn}-${iam}"

					case $scn in
						noadapt)
							insuffix+="-${scn}"
							valcol="--column=rebased"
							post="none"
							;;
						incadapt)
							insuffix+="-${scn}"
							valcol="--column=rebased"
							post=histclim
							;;
						fulladapt)
							valcol="--column=rebased"
							post=histclim
							;;
						costs)
							insuffix+="-${scn}"
							valcol="--column=costs_ub"
							post="none"
							;;
						fulladaptcosts)
							valcol=""
							post=costs
							;;
					esac

					endtag=""
					if [ "$spatial" = "aggregated" ]; then
						endtag+="-aggregated"
						outsuffix+="-aggregated"
					elif [ "$spatial" = "ir_level" ]; then
						endtag+=""
						outsuffix+="-ir_level"
					fi

					if [ "$unit" = "rates" ]; then
						endtag+=""
						outsuffix+="-rates-$format"
					elif [ "$unit" = "levels" ]; then
						endtag+="-levels"
						outsuffix+="-levels-$format"
					fi

					srcfile="${basename}${insuffix}${endtag}"
					if [ "$post" = "histclim" ]; then
						srcfile+=" -${basename}-${age}-histclim${endtag}"
					elif [ "$post" = "costs" ]; then
						srcfile+=" -${basename}-${age}-histclim${endtag} ${basename}-${age}-costs${endtag}"
					fi

					if [ "$show_output" = "TRUE" ]; then
						python quantiles.py ${CONFIG} --results_root=${results_root} --output-format=${format} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --suffix=${outsuffix} ${valcol} --output-dir=${output} ${srcfile}
						echo "Extracting ${rcp}-${ssp}${outsuffix}.csv..."
					elif [ "$show_output" = "FALSE" ]; then
						nohup python quantiles.py ${CONFIG} --results_root=${results_root} --output-format=${format} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --suffix=${outsuffix} ${valcol} --output-dir=${output} ${srcfile} > /dev/null &
						echo "Extracting ${rcp}-${ssp}${outsuffix}.csv..."
					else
						echo "Specify TRUE or FALSE for show_output."
					fi

				done
			done
		done
	done
done
