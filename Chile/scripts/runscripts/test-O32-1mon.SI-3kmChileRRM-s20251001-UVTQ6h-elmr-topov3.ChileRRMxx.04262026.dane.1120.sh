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
readonly COMPSET="F2010-SCREAMv1"
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
readonly CASE_NAME=${CHECKOUT}.${RESOLUTION}.${COMPSET}.${MACHINE}
readonly CASE_ROOT="/p/lustre1/zhang73/E3SM_simulations/ChileRRMxx/${CASE_NAME}"

readonly CASE_GROUP=""

# History file frequency (if using default above)
readonly HIST_OPTION="nmonths"
readonly HIST_N="1"

# Run options
readonly MODEL_START_TYPE="initial"  # "initial", "continue", "branch", "hybrid"
readonly START_DATE="2025-01-01"     # "" for default, or explicit "0001-01-01"

# Additional options for 'branch' and 'hybrid'
readonly GET_REFCASE=false
readonly RUN_REFDIR=""
readonly RUN_REFCASE=""
readonly RUN_REFDATE=""   # same as MODEL_START_DATE for 'branch', can be different for 'hybrid'


# Sub-directories
readonly CASE_BUILD_DIR=${CASE_ROOT}/build
readonly CASE_ARCHIVE_DIR=${CASE_ROOT}/archive

readonly run="2240x1_nmonthsx1_UVTQ6h-elmr-s20250101-O32-topov3ic"
#readonly run="1120x1_nmonthsx1_UVTQ6h-elmr-s20250101-O32"
#readonly run="1120x1_nhoursx1_UVTQ6h-elmr-s20250101-O32-topov3ic"
  # Short test simulations
  tmp=($(echo $run | tr "_" " "))
  layout=${tmp[0]}
  npes=${layout%%x*}
  units=${tmp[1]%%x*}
  length=${tmp[1]##*x}
  walltime="23:59:00" #1120 1mon
  #walltime="00:59:00"
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
 !check_finidat_year_consistency = .false.
 check_dynpft_consistency = .false.
 !check_finidat_fsurdat_consistency = .false.
 !check_finidat_pct_consistency = .false.
 finidat = ' '
 !finidat = '/p/lustre2/zhang73/grids2/finidat_interpinic/${RRMgrid}pg2.elm.r.2015-01-01.nc'
 finidat = '/p/lustre2/zhang73/grids2/Chilene32x32v1/gridprocessing/elm.r.2025-01-01-00000.IELM.ChileRRMxx.dane.interpinic_datm3h.nc'
 flanduse_timeseries = '/p/vast1/e3sm/ccsm3data/inputdata/lnd/clm2/surfdata_map/landuse.timeseries_Chilene32x32v1pg2_rcp3.0_simyr2015-2100_c260502.LC.nc'
 fsurdat = '/p/vast1/e3sm/ccsm3data/inputdata/lnd/clm2/surfdata_map/surfdata_Chilene32x32v1pg2_rcp3.0_simyr2015_c260502.nc'
EOF


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
    ./atmchange physics::atm_procs_list="mac_aero_mic,rrtmgp" #remove cosp
    #./atmchange physics::cosp::cosp_frequency_units="steps"
    #./atmchange physics::cosp::cosp_frequency=3 #3
    #./atmchange physics::cosp::cosp_subcolumns=1
    ./atmchange physics::rrtmgp::rad_frequency=3 #3 300s -> 5 min
    ./atmchange set_cld_frac_r_to_one=true

    ./case.setup 
    # make sure that ``time'' is set to unlimited o/w we'll receive SIGSEGV: "invalid memory reference without other clues"
    ./atmchange physics::mac_aero_mic::nudging::nudging_filenames_patterns=${NUDGING_ROOT}/era5p_TRaave_L128.2025????.3h.ncpdq_FillValue.v1.nc
    ./atmchange physics::mac_aero_mic::nudging::nudging_fields=U,V,T_mid,qv
    ./atmchange mac_aero_mic::nudging::source_pressure_type="TIME_DEPENDENT_3D_PROFILE"
    # we do can activate online horiz_remap + weighted nudging at the same time
    # 	<< if you want that, comment the EKAT MSG with ``coarse'' and ``weighted'' in eamxx_nudging_process_interface.cpp in the source code
    ./atmchange mac_aero_mic::nudging::nudging_refine_remap_mapfile="no-file-given"
    ./atmchange physics::mac_aero_mic::nudging::skip_vert_interpolation=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_timescale=21600 #6h
    # need to generate a netcdf file of nudging_weights.  Please see the script
    #  SCREAMv1_create_nudging_weights.py to do this.
    ./atmchange physics::mac_aero_mic::nudging::use_nudging_weights=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_weights_file=/p/lustre2/zhang73/grids2/${RRMgrid}/gridprocessing/${RRMgrid}pg2_weighting_file.nc
    # dont know why now we cannot ask for compute_tendencies for nudging. error: "The key 'nudging_T_mid_tend' is not associated to any registered product"
    #./atmchange physics::mac_aero_mic::nudging::compute_tendencies=T_mid,qv

    ./atmchange initial_conditions::topography_filename=/p/vast1/e3sm/ccsm3data/inputdata/atm/cam/topo/GTOPO30_Chilene32x32v1np4pg2_x6t.nc
    ./atmchange initial_conditions::filename=/p/vast1/e3sm/ccsm3data/inputdata/atm/scream/init/HICCUP.atm_era5.2025-01-01.highorder_Chilene32x32v1.L128.dataphis.topov3.nc

    # Set atmos IC file
    # Allow for tendency outputs
    #./atmchange physics::mac_aero_mic::shoc::compute_tendencies=T_mid,qv
    #./atmchange physics::mac_aero_mic::p3::compute_tendencies=T_mid,qv
    #./atmchange physics::rrtmgp::compute_tendencies=T_mid
    #./atmchange homme::compute_tendencies=T_mid,qv

    #./atmchange physics::mac_aero_mic::p3::extra_p3_diags=true
    #./atmchange physics::mac_aero_mic::shoc::extra_shoc_diags=true

    ## use GHG levels more appropriate for 2019
    #./atmchange co2vmr=410.5e-6
    #./atmchange ch4vmr=1877.0e-9
    #./atmchange n2ovmr=332.0e-9
    #./atmchange orbital_year=2019
    ## use CO2 the same in land model
    #./xmlchange CCSM_CO2_PPMV=410.5

    # use GHG levels more appropriate for 2024 from NOAA GML websites
    ./atmchange co2vmr=424.6e-6
    ./atmchange ch4vmr=1929.5e-9
    ./atmchange n2ovmr=337.7e-9
    ./atmchange orbital_year=2024
    # use CO2 the same in land model
    ./xmlchange CCSM_CO2_PPMV=424.6

    #user_nl #if you set user_docn.streams instead, must activate it here
    ./xmlchange SSTICE_DATA_FILENAME="/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.2020_2025_noleap.fillmsg.aave_1x1.fmt-c260502.nc"
    ./xmlchange SSTICE_YEAR_ALIGN="2020"
    ./xmlchange SSTICE_YEAR_START="2020"
    ./xmlchange SSTICE_YEAR_END="2025"
    
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

cat <<EOF >> 1mA.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 12
filename_prefix: 1mA
fields:
  physics_pg2:
    field_names:
    - landfrac
    - ocnfrac
iotype: pnetcdf
output_control:
  frequency: 1
  frequency_units: nmonths
restart:
  force_new_file: true
EOF


cat <<EOF >> 6hI_ne30pg2.yaml
%YAML 1.1
---
averaging_type: instant
max_snapshots_per_file: 1460
filename_prefix: 6hI_ne30pg2
horiz_remap_file: \${DIN_LOC_ROOT}/atm/scream/maps/map_Chilene32x32v1pg2_to_ne30pg2_traave.20250426.nc
fields:
  physics_pg2:
    field_names:
    - ps
    - SeaLevelPressure
    - T_2m
    - RelativeHumidity_at_2m_above_surface
    - qv_2m
    - VapWaterPath
    - ZonalVapFlux
    - MeridionalVapFlux
    - z_mid_at_500hPa
    - T_mid_at_200hPa
    - T_mid_at_500hPa
    - U_at_850hPa
    - V_at_850hPa
iotype: pnetcdf
output_control:
  frequency: 6
  frequency_units: nhours
restart:
  force_new_file: true
EOF


cat <<EOF >> 1hA.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 8760
filename_prefix: 1hA
fields:
  physics_pg2:
    field_names:
    - RelativeHumidity_at_2m_above_surface
    - qv_at_model_bot
    - qv_2m
    - T_2m
    - T_mid_at_model_bot
    - surf_radiative_T
    - ps
    - U_at_10m_above_surface
    - V_at_10m_above_surface
    - wind_speed_10m
    - U_at_90m_above_surface
    - V_at_90m_above_surface
    - SW_flux_dn_at_model_bot
    - sfc_flux_dir_nir
    - sfc_flux_dir_vis
    - sfc_flux_dif_nir
    - sfc_flux_dif_vis
    - LW_flux_up_at_model_top
    - precip_total_surf_mass_flux
    - snow_depth_land
iotype: pnetcdf
output_control:
  frequency: 1
  frequency_units: nhours
restart:
  force_new_file: true
EOF


cat <<EOF >> 15minA_clbuffer.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 35040 # 1 yr x 24 h x 4 
filename_prefix: 15minA_clbuffer
horiz_remap_file: \${DIN_LOC_ROOT}/atm/scream/maps/map_Chilene32x32v1pg2_to_Chilebuffer.pg2icol_shp.20260501.5.nc
fields:
  physics_pg2:
    field_names:
    - RelativeHumidity_at_2m_above_surface
    - qv_at_model_bot
    - qv_2m
    - T_2m
    - T_mid_at_model_bot
    - surf_radiative_T
    - ps
    - U_at_10m_above_surface
    - V_at_10m_above_surface
    - wind_speed_10m
    - U_at_90m_above_surface
    - V_at_90m_above_surface
    - SW_flux_dn_at_model_bot
    - sfc_flux_dir_nir
    - sfc_flux_dir_vis
    - sfc_flux_dif_nir
    - sfc_flux_dif_vis
    - LW_flux_up_at_model_top
    - precip_total_surf_mass_flux
    - snow_depth_land
iotype: pnetcdf
output_control:
  frequency: 15
  frequency_units: nmins
restart:
  force_new_file: true
EOF


#---only for checking in test runs---
cat <<EOF >> 1hA_clbuffer_check.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 8760
filename_prefix: 1hA_clbuffer_check
horiz_remap_file: \${DIN_LOC_ROOT}/atm/scream/maps/map_Chilene32x32v1pg2_to_Chilebuffer.pg2icol_shp.20260501.5.nc
fields:
  physics_pg2:
    field_names:
    - RelativeHumidity_at_2m_above_surface
    - qv_at_model_bot
    - qv_2m
    - T_2m
    - T_mid_at_model_bot
    - surf_radiative_T
    - ps
    - U_at_10m_above_surface
    - V_at_10m_above_surface
    - wind_speed_10m
    - U_at_90m_above_surface
    - V_at_90m_above_surface
    - SW_flux_dn_at_model_bot
    - sfc_flux_dir_nir
    - sfc_flux_dir_vis
    - sfc_flux_dif_nir
    - sfc_flux_dif_vis
    - LW_flux_up_at_model_top
    - precip_total_surf_mass_flux
    - snow_depth_land
iotype: pnetcdf
output_control:
  frequency: 1
  frequency_units: nhours
restart:
  force_new_file: true
EOF


cat <<EOF >> 1mA_nudging_check.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 12
filename_prefix: 1mA_nudging_check
fields:
  physics_pg2:
    field_names:
    - U
    - V
    - T_mid
    - qv
    - ps
iotype: pnetcdf
output_control:
  frequency: 1
  frequency_units: nmonths
restart:
  force_new_file: true
EOF


cat <<EOF >> 3hA_nudging_check.yaml
%YAML 1.1
---
averaging_type: average
max_snapshots_per_file: 2920
filename_prefix: 3hA_nudging_check
fields:
  physics_pg2:
    field_names:
    - U_at_850hPa
    - V_at_850hPa
    - T_mid_at_850hPa
    - qv_at_850hPa
    - ps
iotype: pnetcdf
output_control:
  frequency: 3
  frequency_units: nhours
restart:
  force_new_file: true
EOF
#---only for checking in test runs---



    ./atmchange output_yaml_files="./1mA.yaml"
    ./atmchange output_yaml_files+="./6hI_ne30pg2.yaml"
    ./atmchange output_yaml_files+="./1hA.yaml"
    ./atmchange output_yaml_files+="./15minA_clbuffer.yaml"
    #---below: only for checking in test runs
    #./atmchange output_yaml_files+="./1hA_clbuffer_check.yaml"
    ./atmchange output_yaml_files+="./1mA_nudging_check.yaml"
    ./atmchange output_yaml_files+="./3hA_nudging_check.yaml"

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
