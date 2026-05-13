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
readonly CHECKOUT="WPRRMxx_251103_ctp_qmr"
readonly BRANCH="jzhang/WPRRMxx_251103_ctp_qmr"
readonly CHERRY=( )
readonly COMPILER="intel"
readonly DEBUG_COMPILE=FALSE
readonly Q=regular

# Simulation
readonly COMPSET="F2010-SCREAMv1"
readonly RRMgrid="WP10ne32x32v1"
readonly RESOLUTION="${RRMgrid}pg2_${RRMgrid}pg2"

# Directory to where your YAML (output) files are located. Do a search for "YAML_ROOT"
#   to find the location in this script where you will specify the individual files.
#readonly YAML_ROOT="/global/homes/b/bogensch/scream_v1_scripts/yaml_output_files"
readonly YAML_ROOT="/p/lustre2/zhang73/GitTmp/scmlib/DPxx_SCREAM_SCRIPTS/yaml_file_example/reformat_250723"

# Directory where your nudging data is located
#readonly NUDGING_ROOT="/p/lustre2/zhang73/nudging.UVTQ/L128.mono_${RRMgrid}pg2.UVTQ.pres.cdsnew.240929/" #hindcast
readonly NUDGING_ROOT="/p/lustre2/zhang73/12212023/data/3hI-UVTQ-s2015_2.20190807.DECKv1b_P1_SSP5-8.5.ne30_oEC.ruby.1344/v1" #climate-length E3SMv1 SSP585

# Directory where your code is
readonly CODE_ROOT="/p/lustre2/zhang73/GitTmp/wprrmxx/${CHECKOUT}"
readonly PROJECT="meteors"
    
githash_eamxx=`git --git-dir ${CODE_ROOT}/.git rev-parse HEAD`

#readonly CASE_NAME=screamv1_RRM_nudging.${RESOLUTION}.${COMPSET}.${CHECKOUT}.test.001a
#readonly CASE_ROOT="${SCRATCH}/e3sm_scratch/${MACHINE}/${CASE_NAME}"
readonly CASE_NAME=${CHECKOUT}.${RESOLUTION}.${COMPSET}.${MACHINE}
readonly CASE_ROOT="/p/lustre1/zhang73/E3SM_simulations/wprrmxx_p3/${CASE_NAME}"

readonly CASE_GROUP=""

# History file frequency (if using default above)
readonly HIST_OPTION="nmonths"
readonly HIST_N="1"

# Run options
readonly MODEL_START_TYPE="initial"  # "initial", "continue", "branch", "hybrid"
readonly START_DATE="2015-10-01"     # "" for default, or explicit "0001-01-01"

# Additional options for 'branch' and 'hybrid'
readonly GET_REFCASE=false
readonly RUN_REFDIR=""
readonly RUN_REFCASE=""
readonly RUN_REFDATE=""   # same as MODEL_START_DATE for 'branch', can be different for 'hybrid'


# Sub-directories
readonly CASE_BUILD_DIR=${CASE_ROOT}/build
readonly CASE_ARCHIVE_DIR=${CASE_ROOT}/archive

#readonly CASE_SCRIPTS_DIR=${CASE_ROOT}/case_scripts
#readonly CASE_RUN_DIR=${CASE_ROOT}/run
#readonly PELAYOUT="32x1" # 8 nodes
#readonly WALLTIME="00:30:00"
#readonly STOP_OPTION="ndays"
#readonly STOP_N="1"
#readonly REST_OPTION="ndays"
#readonly REST_N="1"
#readonly RESUBMIT="0"
readonly run="2240x1_nmonthsx1_E3SMv1SSP585-UVTQ2d-s20151001-O40-5minAsite-rad3"
#readonly run="1120x1_nhoursx1_E3SMv1SSP585-UVTQ3h-s20151001-O40-5minAsite-rad3"
  # Short test simulations
  tmp=($(echo $run | tr "_" " "))
  layout=${tmp[0]}
  npes=${layout%%x*}
  units=${tmp[1]%%x*}
  length=${tmp[1]##*x}
  walltime="12:20:00"
  if [ "$units" == "nhours" ]; then
    walltime="00:05:00"
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
 !check_finidat_year_consistency = .false.
 !check_dynpft_consistency = .false.
 !check_finidat_fsurdat_consistency = .false.
 !check_finidat_pct_consistency = .false.
 finidat = '/p/lustre2/zhang73/grids2/finidat_interpinic/${RRMgrid}pg2.elm.r.2015-01-01.nc'
EOF

# cice && docn nl is needed if you want to set the realistic SST and ice_cov forcing in hindcasts
cat > user_nl_cice << 'eof'
 stream_fldfilename = '/p/lustre2/zhang73/DATA/data_streamfile/sst_E3SM-1-0_ssp585_r1i1p1f1_12212023_gr_2015-2100_c240422.nc'
 model_year_align               = 2015
 stream_fldvarname              = 'ice_cov'
 stream_year_first              = 2015
 stream_year_last               = 2100
eof

cat > user_nl_docn << 'eof'
 streams = 'docn.streams.txt.prescribed 2015 2015 2100'
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

    if [ $nnodes -le 12 ]; then
        ./xmlchange JOB_QUEUE="pdebug"
    else
        ./xmlchange JOB_QUEUE="pbatch"
    fi  

    echo "+++ Configuring SCREAM for 128 vertical levels +++"
    ./xmlchange SCREAM_CMAKE_OPTIONS="SCREAM_NP 4 SCREAM_NUM_VERTICAL_LEV 128 SCREAM_NUM_TRACERS 11"

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
    # Set temperature cut off in dycore threshold to 180K
    ./atmchange vtheta_thresh=180
    
    # Set nudging
    ./case.setup
    ./atmchange mac_aero_mic::atm_procs_list=tms,shoc,cld_fraction,spa,p3,nudging
    #./atmchange mac_aero_mic::atm_procs_list=tms,shoc,cld_fraction,spa,p3
    ./atmchange physics::atm_procs_list="mac_aero_mic,rrtmgp,cosp"
    ./atmchange physics::cosp::cosp_frequency_units="steps"
    ./atmchange physics::cosp::cosp_frequency=3 #3
    ./atmchange physics::cosp::cosp_subcolumns=1
    ./atmchange physics::rrtmgp::rad_frequency=3 #3
    ./atmchange set_cld_frac_r_to_one=true

    ./case.setup 
    # make sure that ``time'' is set to unlimited o/w we'll receive SIGSEGV: "invalid memory reference without other clues"
    ./atmchange physics::mac_aero_mic::nudging::nudging_filenames_patterns=${NUDGING_ROOT}/h4.TQUV.20??-??-??.128levs.highorder_se2fv_${RRMgrid}pg2.ncpdq_FillValue.nc
    ./atmchange physics::mac_aero_mic::nudging::nudging_fields=U,V,T_mid,qv
    ./atmchange mac_aero_mic::nudging::source_pressure_type="TIME_DEPENDENT_3D_PROFILE"
    # we do can activate online horiz_remap + weighted nudging at the same time
    # 	<< if you want that, comment the EKAT MSG with ``coarse'' and ``weighted'' in eamxx_nudging_process_interface.cpp in the source code
    ./atmchange mac_aero_mic::nudging::nudging_refine_remap_mapfile="no-file-given"
    ./atmchange physics::mac_aero_mic::nudging::skip_vert_interpolation=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_timescale=172800 #10800
    # need to generate a netcdf file of nudging_weights.  Please see the script
    #  SCREAMv1_create_nudging_weights.py to do this.
    ./atmchange physics::mac_aero_mic::nudging::use_nudging_weights=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_weights_file=/p/lustre2/zhang73/grids2/${RRMgrid}/${RRMgrid}pg2_weighting_file.nc
    # dont know why now we cannot ask for compute_tendencies for nudging. error: "The key 'nudging_T_mid_tend' is not associated to any registered product"
    #./atmchange physics::mac_aero_mic::nudging::compute_tendencies=T_mid,qv

    # Set atmos IC file
    # Allow for tendency outputs
    ./atmchange physics::mac_aero_mic::shoc::compute_tendencies=T_mid,qv
    ./atmchange physics::mac_aero_mic::p3::compute_tendencies=T_mid,qv
    ./atmchange physics::rrtmgp::compute_tendencies=T_mid
    ./atmchange homme::compute_tendencies=T_mid,qv

    ./atmchange physics::mac_aero_mic::p3::extra_p3_diags=true
    ./atmchange physics::mac_aero_mic::shoc::extra_shoc_diags=true

    # use GHG levels more appropriate for 2019
    ./atmchange co2vmr=410.5e-6
    ./atmchange ch4vmr=1877.0e-9
    ./atmchange n2ovmr=332.0e-9
    ./atmchange orbital_year=2019
    # use CO2 the same in land model
    ./xmlchange CCSM_CO2_PPMV=410.5

    #user_nl #if you set user_docn.streams instead, must activate it here
    ./xmlchange SSTICE_DATA_FILENAME="/p/lustre2/zhang73/DATA/data_streamfile/sst_E3SM-1-0_ssp585_r1i1p1f1_12212023_gr_2015-2100_c240422.nc"
    ./xmlchange SSTICE_YEAR_ALIGN="2015"
    ./xmlchange SSTICE_YEAR_START="2015"
    ./xmlchange SSTICE_YEAR_END="2100"
    
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

    #cp ${YAML_ROOT}"/eamxx_wprrm.1dailyMIN_native.yaml" . #T_2m
    #cp ${YAML_ROOT}"/eamxx_wprrm.1dailyMAX_native.yaml" . #T_2m, precip_total_surf_mass_flux
    #cp ${YAML_ROOT}"/eamxx_wprrm.1dailyAVG_native.yaml" . #snow_depth_land
    cp ${YAML_ROOT}"/eamxx_wprrm.1dailyAVG_coarse.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.6hourlyAVG_coarse.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.6hourlyINST_coarse.yaml" . #3D fields on model levels, 2D fields
    #cp ${YAML_ROOT}"/eamxx_wprrm.3hourlyAVG_coarse.yaml" . #3D fields, Surface, Lowest Level
    #cp ${YAML_ROOT}"/eamxx_wprrm.3hourlyINST_coarse.yaml" . #2D vars for storm/ACI analysis, 3D vars for nudging
    #cp ${YAML_ROOT}"/eamxx_wprrm.3hourlyINST_native.yaml" . #For storm analysis, For wind turbine study, For atmospheric rivers,
    #cp ${YAML_ROOT}"/eamxx_wprrm.1hourlyINST_native.yaml" . #LW,SW_flux_up_at_model_top, precip_total_surf_mass_flux 
    #cp ${YAML_ROOT}"/eamxx_wprrm.1hourlyAVG_native.yaml" . #(zhang73) CF eval
    #cp ${YAML_ROOT}"/eamxx_wprrm.1hI_site_native_debug.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_debug.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_site_box_all.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_site_box_weighted.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_site_ocean_weighted.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_site_land_weighted.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_site_nearest.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.5minA_site_box_weighted.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.5minA_site_ocean_weighted.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.5minA_site_land_weighted.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.5minA_site_nearest.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.5minI_1x1_160E170E2.5N12.5N.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.25hI_pg2.yaml" .
    cp ${YAML_ROOT}"/eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_Betts.yaml" .
    #cp ${YAML_ROOT}"/eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_more.yaml" .
    #./atmchange output_yaml_files+="./eamxx_wprrm.1dailyMIN_native.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1dailyMAX_native.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1dailyAVG_native.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.1dailyAVG_coarse.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.6hourlyAVG_coarse.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.6hourlyINST_coarse.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.3hourlyAVG_coarse.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.3hourlyINST_coarse.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.3hourlyINST_native.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1hourlyINST_native.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1hourlyAVG_native.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1hI_site_native_debug.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_debug.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_site_box_all.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_site_box_weighted.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_site_ocean_weighted.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_site_land_weighted.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_site_nearest.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.5minA_site_box_weighted.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.5minA_site_ocean_weighted.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.5minA_site_land_weighted.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.5minA_site_nearest.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.5minI_1x1_160E170E2.5N12.5N.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.25hI_pg2.yaml"
    ./atmchange output_yaml_files+="./eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_Betts.yaml"
    #./atmchange output_yaml_files+="./eamxx_wprrm.1hI_1x1_160E170E2.5N12.5N_more.yaml"
    if [ "$units" == "nhours" ]; then
    	cp ${YAML_ROOT}"/eamxx_wprrm.5minI_pg2_debug.yaml" .
    	./atmchange output_yaml_files+="./eamxx_wprrm.5minI_pg2_debug.yaml"
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
