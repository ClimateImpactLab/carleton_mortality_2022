#!/bin/bash

outputdir="$REPO/montecarlo/"
csvv="$DB/1_estimation/3_csvv/Agespec_interaction_response.csvv"

if [[ "$CONDA_DEFAULT_ENV" != "impact-env" ]] ; then
    { 
        conda activate impact-env
    } || { 
        echo "CONDA AUTO-ACTIVATE FAILED"
    }
    echo "WARNING: It looks like the impact-env environment is not activated.
    Ensure that conda is installed and the correct environment is activated
    before running projections. Refer to impact-calculations documentation for
    more information."
fi

if [[ ! -d "$REPO/impact-calculations" ]] ; then
    echo "WARNING: Cannot find impact-calculations in $REPO"
fi

if [[ ! -d "$REPO/open-estimate" ]] ; then
    echo "WARNING: Cannot find open-estimate in $REPO"
fi

if [[ ! -d "$REPO/impact-common" ]] ; then
    echo "WARNING: Cannot find impact-common in $REPO"
fi

if [[ "$1" == "generate" ]] ; then

    config="$REPO/mortality/2_projection/2_run_projections/main_specification/configs/mortality-generate-montecarlo.yml"

    cd "$REPO/impact-calculations"

    if [ "$#" -ne 1 ]; then
        for i in $(seq 1 $2); do
            nohup python -m generate.generate $config --outputdir=$outputdir --csvvfile=$csvv > /dev/null 2>&1 &
            sleep 5
        done
    else
        echo "running..."
        python -m generate.generate $config --outputdir=$outputdir --csvvfile=$csvv
    fi
	cd -

elif [[ "$1" == "aggregate" ]] ; then

    config="$REPO/mortality/2_projection/2_run_projections/main_specification/configs/mortality-aggregate-montecarlo.yml"

    cd "$REPO/impact-calculations"

    if [ "$#" -ne 1 ]; then
        for i in $(seq 1 $2); do
        nohup python -m generate.aggregate --outputdir=$outputdir > /dev/null 2>&1 &
        sleep 5
        done
    else
        python -m generate.aggregate --outputdir=$outputdir
    fi
	cd -

else

    echo "Specify generate or aggregate as first argument to script. You can pass the number of cores you wish
    to parallelize over as the second argument, e.g., \`bash mortality_montecarlo.sh generate 20\`"

    echo "Output: $outputdir"
    echo "CSVV: $csvv"


fi
