#!/bin/bash

export BETACAST=/global/cfs/cdirs/e3sm/zhang73/GitTmp/SourceCode/betacast_fork/

# source /global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.10.0_pm-cpu.sh

# BETACAST=/global/cfs/cdirs/e3sm/zhang73/GitTmp/SourceCode/betacast_fork/
timefreq=3 #the time frequency needed for IELM-DATM data
drc_in=/global/cfs/cdirs/e3sm/zhang73/datm7src_nersc/ERA5-DATM_3hourly/
drc_out=/global/cfs/cdirs/e3sm/zhang73/datm7src_nersc/atm_forcing.datm7.${timefreq}h.ERA5.c260429/
datafilename="elmforc.ERA5"

# Function to run Python test
run_python_test() {

    local YYYY=$1
    local MM=$2

    mkdir -pv $drc_out/

    python ${BETACAST}/land-spinup/gen_datm/gen-datm/grid_WL.gen_datm.02.betacast.gen-forcing.ERA5singlelev_NERSC.py \
        --era5_file="${drc_in}/${YYYY}/out.${YYYY}.${MM}.${timefreq}h.nc" \
        --year=${YYYY} \
        --month=${MM} \
        --outdirbase="${drc_out}/" \
        --datafilename=${datafilename} \
        --do_q \
        --do_flds \
        --greg_to_noleap \
        --convert_nc3

    return 0
}

#---driver
# echo "year: $1"
# year=$1
for year in `seq 1940 1 2002`;do #login13
# for year in `seq 2003 1 2010`;do
# for year in `seq 2011 1 2018`;do
  for im in `seq 1 1 12`;do
    im_fmt=`printf %02d $im`
  
    echo ">>> Running ${year}-${im_fmt}"
    run_python_test $year $im_fmt 
  
  done #im
done #year

