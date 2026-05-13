#!/bin/bash -fe

# EAMxx template run script for California RRM
# Includes example how to nudge T,Q,U,V from ERA5.
# Also sets appropriate SSTs for time period being simulated.

# See the runtime_options() section to set options related to nudging.
# See the runtime_options() section to set your output streams.
# See the user_nl() section to set the appropriate SST file.

# In this example we nudge only the coarse outer domain (100 km res) while allowing a 
# freerunning simulation of the 3 km refined domain (CA).  To allow this, a weighting map
# needs to be generated.  To generate this file please see the companion script:
# SCREAMv1_create_nudging_weights.py

# Script authors:
#  - Jishi Zhang (zhang73@llnl.gov)
#  - Peter Bogenschutz (bogenschutz1@llnl.gov)

main() {

do_fetch_code=false
do_create_newcase=true
do_case_setup=true
do_case_build=false
do_case_submit=true

readonly MACHINE="dane"
readonly CHECKOUT="ChileRRMxx"
readonly BRANCH="jzhang/ChileRRMxx"
readonly CHERRY=( )
readonly COMPILER="oneapi-ifx"
readonly DEBUG_COMPILE=FALSE
readonly Q=regular

# Simulation
readonly COMPSET="ICRUELM"
readonly RRMgrid="Chilene32x32v1"
readonly RESOLUTION="${RRMgrid}pg2_${RRMgrid}pg2"

# Directory to where your YAML (output) files are located. Do a search for "YAML_ROOT"
#   to find the location in this script where you will specify the individual files.
#readonly YAML_ROOT="/global/homes/b/bogensch/scream_v1_scripts/yaml_output_files"
readonly YAML_ROOT="/p/lustre2/zhang73/GitTmp/scmlib/DPxx_SCREAM_SCRIPTS/yaml_file_example/reformat_250723"

# Directory where your nudging data is located
readonly NUDGING_ROOT="/p/lustre2/zhang73/nudging.UVTQ/L128.TRaave_Chilene32x32v1pg2.UVTQ.0.25plev.v1" #ERA5pres_NERSC m3522

# Directory where your code is
readonly CODE_ROOT="/p/lustre2/zhang73/GitTmp/${CHECKOUT}"
readonly PROJECT="focus"
    
githash_eamxx=`git --git-dir ${CODE_ROOT}/.git rev-parse HEAD`

#readonly CASE_NAME=screamv1_RRM_nudging.${RESOLUTION}.${COMPSET}.${CHECKOUT}.test.001a
#readonly CASE_ROOT="${SCRATCH}/e3sm_scratch/${MACHINE}/${CASE_NAME}"
readonly CASE_NAME=IELM.${CHECKOUT}.${RESOLUTION}.${COMPSET}.${MACHINE}
readonly CASE_ROOT="/p/lustre1/zhang73/E3SM_simulations/ChileRRMxx/${CASE_NAME}"

readonly CASE_GROUP=""

# History file frequency (if using default above)
readonly HIST_OPTION="nmonths"
readonly HIST_N="1"

# Run options
readonly MODEL_START_TYPE="initial"  # "initial", "continue", "branch", "hybrid"
#readonly START_DATE="2025-01-01"     # "" for default, or explicit "0001-01-01"

FORECASTDATE=20250101
NMONTHSSPIN=12
NCYCLES=5
NMONTHSSPIN=$((NMONTHSSPIN*NCYCLES))
START_DATE=`date -d "${FORECASTDATE} - ${NMONTHSSPIN} months" "+%Y-%m-%d"`
echo "Starting at: "${START_DATE}
#exit 1

# Additional options for 'branch' and 'hybrid'
readonly GET_REFCASE=false
readonly RUN_REFDIR=""
readonly RUN_REFCASE=""
readonly RUN_REFDATE=""   # same as MODEL_START_DATE for 'branch', can be different for 'hybrid'


# Sub-directories
readonly CASE_BUILD_DIR=${CASE_ROOT}/build
readonly CASE_ARCHIVE_DIR=${CASE_ROOT}/archive

tfreq_datm="3h"
#readonly run="2240x1_nmonthsx1_E3SMv1SSP585-UVTQ6h-s20250101-O3"
readonly run="1120x1_nyearsx5_e20250101_interpinic_datm${tfreq_datm}"
  # Short test simulations
  tmp=($(echo $run | tr "_" " "))
  layout=${tmp[0]}
  npes=${layout%%x*}
  units=${tmp[1]%%x*}
  length=${tmp[1]##*x}
  walltime="05:20:00"
  #walltime="01:30:00"
  if [ "$units" == "nhours" ]; then
    #walltime="00:04:00" #O3
    walltime="00:15:00" #O31
  fi

  readonly CASE_SCRIPTS_DIR=${CASE_ROOT}/tests/${run}/case_scripts
  readonly CASE_RUN_DIR=${CASE_ROOT}/tests/${run}/run
  readonly PELAYOUT=${layout} #32x1
  readonly WALLTIME=${walltime}
  readonly STOP_OPTION=${units}
  readonly STOP_N=${length}
  readonly REST_OPTION=${units}
  readonly REST_N=${STOP_N}
  readonly RESUBMIT=0
echo 'units='${units} 'layout='${layout} 'RESUBMIT='${RESUBMIT} 'length='${length} 'walltime='${walltime}
#exit 1

readonly DO_SHORT_TERM_ARCHIVING=false

# Leave empty (unless you understand what it does)
readonly OLD_EXECUTABLE=""

# Make directories created by this script world-readable
umask 022

# Fetch code from Github
#fetch_code

# Create case
create_newcase

# Setup
case_setup

# Build
case_build

# Configure runtime options
runtime_options

# Copy script into case_script directory for provenance
copy_script

# Submit
case_submit

# All done
echo $'\n----- All done -----\n'

}


# =======================
# Custom user_nl settings
# =======================

user_nl() {

# let's put all user namelist setup here

cat << EOF >> user_nl_cpl
 ocn_surface_flux_scheme = 2
EOF


cat <<EOF >> user_nl_elm
 check_finidat_year_consistency = .false.
 check_dynpft_consistency = .false.
 check_finidat_fsurdat_consistency = .false.
 check_finidat_pct_consistency = .false.
 !finidat = ' '
 finidat = '/p/lustre2/zhang73/grids2/finidat_interpinic/${RRMgrid}pg2.elm.r.2015-01-01.nc'
 flanduse_timeseries = '/p/vast1/e3sm/ccsm3data/inputdata/lnd/clm2/surfdata_map/landuse.timeseries_Chilene32x32v1pg2_rcp3.0_simyr2015-2100_c260502.LC.nc'
 fsurdat = '/p/vast1/e3sm/ccsm3data/inputdata/lnd/clm2/surfdata_map/surfdata_Chilene32x32v1pg2_rcp3.0_simyr2015_c260502.nc'

hist_avgflag_pertape='A','A'
hist_nhtfrq = 0,24
hist_mfilt = 1,30
hist_fincl1 = 'TSA','TBOT','RAIN','SNOW'
EOF


cat <<EOF >> user_nl_datm
!anomaly_forcing = 'Anomaly.Forcing.Precip','Anomaly.Forcing.Temperature','Anomaly.Forcing.Humidity','Anomaly.Forcing.Longwave'

tintalgo = "coszen", "nearest", "linear", "linear", "lower"

streams = "datm.streams.txt.CLMCRUNCEP.Solar 2019 2019 2025",
    	  "datm.streams.txt.CLMCRUNCEP.Precip 2019 2019 2025",
    	  "datm.streams.txt.CLMCRUNCEP.TPQW 2019 2019 2025",
    	  "datm.streams.txt.presaero.clim_2000 1 1 1", 
    	  "datm.streams.txt.topo.observed 1 1 1", 
EOF

cp /p/vast1/zhang73/datm7src_nersc/atm_forcing.datm7.${tfreq_datm}.ERA5.c260429/user_datm.streams.txt.LC.elmforc_nersc.Solar ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.Solar
cp /p/vast1/zhang73/datm7src_nersc/atm_forcing.datm7.${tfreq_datm}.ERA5.c260429/user_datm.streams.txt.LC.elmforc_nersc.TPQW ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.TPQW
cp /p/vast1/zhang73/datm7src_nersc/atm_forcing.datm7.${tfreq_datm}.ERA5.c260429/user_datm.streams.txt.LC.elmforc_nersc.Precip ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.Precip
cp /p/vast1/zhang73/datm7src_nersc/atm_forcing.datm7.${tfreq_datm}.ERA5.c260429/datm.streams.txt.LC.topo.observed ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.topo.observed
#./preview_namelists


cat <<EOF >> user_nl_mosart
 do_rtm = .false.
 rtmhist_nhtfrq =   0,-24,-3
 rtmhist_mfilt  = 1,30,240
 rtmhist_fincl2 = 'RIVER_DISCHARGE_OVER_LAND_LIQ'
 !rtmhist_fincl3 = 'RIVER_DISCHARGE_OVER_LAND_LIQ'
EOF


# cice && docn nl is needed if you want to set the realistic SST and ice_cov forcing in hindcasts
cat > user_nl_cice << 'eof'
 stream_fldfilename = '/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.2020_2025_noleap.fillmsg.aave_1x1.fmt-c260502.nc'
 model_year_align               = 2020
 stream_fldvarname              = 'ice_cov'
 stream_year_first              = 2020
 stream_year_last               = 2025
eof

cat > user_nl_docn << 'eof'
 streams = 'docn.streams.txt.prescribed 2020 2020 2025'
eof

}

######################################################
### Most users won't need to change anything below ###
######################################################

#-----------------------------------------------------
fetch_code() {

    if [ "${do_fetch_code,,}" != "true" ]; then
	echo $'\n----- Skipping fetch_code -----\n'
	return
    fi

    echo $'\n----- Starting fetch_code -----\n'
    local path=${CODE_ROOT}
    local repo=scream

    echo "Cloning $repo repository branch $BRANCH under $path"
    if [ -d "${path}" ]; then
	echo "ERROR: Directory already exists. Not overwriting"
	exit 20
    fi
    mkdir -p ${path}
    pushd ${path}

    # This will put repository, with all code
    git clone git@github.com:E3SM-Project/${repo}.git .

    # Q: DO WE NEED THIS FOR EAMXX?
    # Setup git hooks
    rm -rf .git/hooks
    git clone git@github.com:E3SM-Project/E3SM-Hooks.git .git/hooks
    git config commit.template .git/hooks/commit.template

    # Check out desired branch
    git checkout ${BRANCH}

    # Custom addition
    if [ "${CHERRY}" != "" ]; then
	echo ----- WARNING: adding git cherry-pick -----
	for commit in "${CHERRY[@]}"
	do
	    echo ${commit}
	    git cherry-pick ${commit}
	done
	echo -------------------------------------------
    fi

    # Bring in all submodule components
    git submodule update --init --recursive

    popd
}

#-----------------------------------------------------
create_newcase() {

    if [ "${do_create_newcase,,}" != "true" ]; then
	echo $'\n----- Skipping create_newcase -----\n'
	return
    fi

    echo $'\n----- Starting create_newcase -----\n'

    # Base arguments
    args=" --case ${CASE_NAME} \
	--output-root ${CASE_ROOT} \
	--script-root ${CASE_SCRIPTS_DIR} \
	--handle-preexisting-dirs u \
	--compset ${COMPSET} \
	--res ${RESOLUTION} \
	--machine ${MACHINE} \
	--compiler ${COMPILER} \
	--walltime ${WALLTIME} \
	--pecount ${PELAYOUT}"

    # Oprional arguments
    if [ ! -z "${PROJECT}" ]; then
      args="${args} --project ${PROJECT}"
    fi
    if [ ! -z "${CASE_GROUP}" ]; then
      args="${args} --case-group ${CASE_GROUP}"
    fi
    if [ ! -z "${QUEUE}" ]; then
      args="${args} --queue ${QUEUE}"
    fi

    ${CODE_ROOT}/cime/scripts/create_newcase ${args}

    if [ $? != 0 ]; then
      echo $'\nNote: if create_newcase failed because sub-directory already exists:'
      echo $'  * delete old case_script sub-directory'
      echo $'  * or set do_newcase=false\n'
      exit 35
    fi

}

#-----------------------------------------------------
case_setup() {

    if [ "${do_case_setup,,}" != "true" ]; then
	echo $'\n----- Skipping case_setup -----\n'
	return
    fi

    echo $'\n----- Starting case_setup -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Setup some CIME directories
    ./xmlchange EXEROOT=${CASE_BUILD_DIR}
    ./xmlchange RUNDIR=${CASE_RUN_DIR}

    # Short term archiving
    ./xmlchange DOUT_S=${DO_SHORT_TERM_ARCHIVING}
    ./xmlchange DOUT_S_ROOT=${CASE_ARCHIVE_DIR}

    # Extracts input_data_dir in case it is needed for user edits to the namelist later
    local input_data_dir=`./xmlquery DIN_LOC_ROOT --value`

    # Custom user_nl
    ./xmlchange ATM_NCPL=48
    
    user_nl 

    if [ "${MACHINE}" == "ruby" ]; then
      ncore=56
    elif [ "${MACHINE}" == "dane" ]; then
      ncore=112
    fi 

    if [ -n "$ncore" ] && [ -n "$npes" ]; then
      nnodes=$(( (npes + ncore - 1) / ncore ))
      echo "→ nnodes = $nnodes"
    else
      echo "ERROR: Missing ncore or npes"
    fi

    #if [ $nnodes -le 12 ]; then
    #    ./xmlchange JOB_QUEUE="pdebug"
    #else
    #    ./xmlchange JOB_QUEUE="pbatch"
    #fi  

    echo "+++ Configuring SCREAM for 128 vertical levels +++"
    #./xmlchange SCREAM_CMAKE_OPTIONS="SCREAM_NP 4 SCREAM_NUM_VERTICAL_LEV 128 SCREAM_NUM_TRACERS 11"

    ./xmlchange --file env_mach_pes.xml NTHRDS="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_ATM="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_LND="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_ICE="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_OCN="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_ROF="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_CPL="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_GLC="1"
    ./xmlchange --file env_mach_pes.xml NTHRDS_WAV="1"
    
    ./xmlchange EPS_AGRID=1e-9

    ./xmlchange PIO_NETCDF_FORMAT="64bit_data"

    # Finally, run CIME case.setup
    ./case.setup --reset

    # Save provenance invfo
    echo "branch hash for EAMxx: $githash_eamxx" > GIT_INFO.txt

    popd
}

#-----------------------------------------------------
case_build() {

    pushd ${CASE_SCRIPTS_DIR}

    # do_case_build = false
    if [ "${do_case_build,,}" != "true" ]; then

	echo $'\n----- case_build -----\n'

	if [ "${OLD_EXECUTABLE}" == "" ]; then
	    # Ues previously built executable, make sure it exists
	    if [ -x ${CASE_BUILD_DIR}/e3sm.exe ]; then
		echo 'Skipping build because $do_case_build = '${do_case_build}
	    else
		echo 'ERROR: $do_case_build = '${do_case_build}' but no executable exists for this case.'
		exit 297
	    fi
	else
	    # If absolute pathname exists and is executable, reuse pre-exiting executable
	    if [ -x ${OLD_EXECUTABLE} ]; then
		echo 'Using $OLD_EXECUTABLE = '${OLD_EXECUTABLE}
		cp -fp ${OLD_EXECUTABLE} ${CASE_BUILD_DIR}/
	    else
		echo 'ERROR: $OLD_EXECUTABLE = '$OLD_EXECUTABLE' does not exist or is not an executable file.'
		exit 297
	    fi
	fi
	echo 'WARNING: Setting BUILD_COMPLETE = TRUE.  This is a little risky, but trusting the user.'
	./xmlchange BUILD_COMPLETE=TRUE

    # do_case_build = true
    else

	echo $'\n----- Starting case_build -----\n'

	# Turn on debug compilation option if requested
	if [ "${DEBUG_COMPILE}" == "TRUE" ]; then
	    ./xmlchange DEBUG=${DEBUG_COMPILE}
	fi

	# Run CIME case.build
	./case.build

	# Some user_nl settings won't be updated to *_in files under the run directory
	# Call preview_namelists to make sure *_in and user_nl files are consistent.
	./preview_namelists

    fi

    popd
}

#-----------------------------------------------------
runtime_options() {

    echo $'\n----- Starting runtime_options -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Set simulation start date
    if [ ! -z "${START_DATE}" ]; then
	./xmlchange RUN_STARTDATE=${START_DATE}
    fi

    #---comment all atmchange/SST settings for eamxx in IELM runs---
    ##user_nl #if you set user_docn.streams instead, must activate it here
    #./xmlchange SSTICE_DATA_FILENAME="/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.2020_2025_noleap.fillmsg.aave_1x1.fmt-c260502.nc"
    #./xmlchange SSTICE_YEAR_ALIGN="2020"
    #./xmlchange SSTICE_YEAR_START="2020"
    #./xmlchange SSTICE_YEAR_END="2025"

    # Set simulation start date
    ./xmlchange RUN_STARTDATE=${START_DATE}
    ./xmlchange DATM_CLMNCEP_YR_ALIGN=2019
    ./xmlchange DATM_CLMNCEP_YR_START=2019
    ./xmlchange DATM_CLMNCEP_YR_END=2025
    
    # Segment length
    ./xmlchange STOP_OPTION=${STOP_OPTION,,},STOP_N=${STOP_N}

    # Restart frequency
    ./xmlchange REST_OPTION=${REST_OPTION,,},REST_N=${REST_N}

    # Coupler history
    ./xmlchange HIST_OPTION=${HIST_OPTION,,},HIST_N=${HIST_N}

    # Coupler budgets (always on)
    ./xmlchange BUDGETS=TRUE

    # Set resubmissions
    if (( RESUBMIT > 0 )); then
	./xmlchange RESUBMIT=${RESUBMIT}
    fi

    # Run type
    # Start from default of user-specified initial conditions
    if [ "${MODEL_START_TYPE,,}" == "initial" ]; then
	./xmlchange RUN_TYPE="startup"
	./xmlchange CONTINUE_RUN="FALSE"

    # Continue existing run
    elif [ "${MODEL_START_TYPE,,}" == "continue" ]; then
	./xmlchange CONTINUE_RUN="TRUE"

    elif [ "${MODEL_START_TYPE,,}" == "branch" ] || [ "${MODEL_START_TYPE,,}" == "hybrid" ]; then
	./xmlchange RUN_TYPE=${MODEL_START_TYPE,,}
	./xmlchange GET_REFCASE=${GET_REFCASE}
	./xmlchange RUN_REFDIR=${RUN_REFDIR}
	./xmlchange RUN_REFCASE=${RUN_REFCASE}
	./xmlchange RUN_REFDATE=${RUN_REFDATE}
	echo 'Warning: $MODEL_START_TYPE = '${MODEL_START_TYPE}
	echo '$RUN_REFDIR = '${RUN_REFDIR}
	echo '$RUN_REFCASE = '${RUN_REFCASE}
	echo '$RUN_REFDATE = '${START_DATE}

    else
	echo 'ERROR: $MODEL_START_TYPE = '${MODEL_START_TYPE}' is unrecognized. Exiting.'
	exit 380
    fi

    popd
}

#-----------------------------------------------------
case_submit() {

    if [ "${do_case_submit,,}" != "true" ]; then
	echo $'\n----- Skipping case_submit -----\n'
	return
    fi

    echo $'\n----- Starting case_submit -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Run CIME case.submit
    #./case.submit -a="-t ${WALLTIME} --mail-type=ALL --mail-user=bogenschutz1@llnl.gov" >& submitout.txt
    ./case.submit -a="-t ${WALLTIME}" >& submitout.txt

    popd
}

#-----------------------------------------------------
copy_script() {

    echo $'\n----- Saving run script for provenance -----\n'

    local script_provenance_dir=${CASE_SCRIPTS_DIR}/run_script_provenance
    mkdir -p ${script_provenance_dir}
    local this_script_name=`basename $0`
    local script_provenance_name=${this_script_name}.`date +%Y%m%d-%H%M%S`
    cp -vp ${this_script_name} ${script_provenance_dir}/${script_provenance_name}

}

#-----------------------------------------------------
# Silent versions of popd and pushd
pushd() {
    command pushd "$@" > /dev/null
}
popd() {
    command popd "$@" > /dev/null
}

# Now, actually run the script
#-----------------------------------------------------
main
