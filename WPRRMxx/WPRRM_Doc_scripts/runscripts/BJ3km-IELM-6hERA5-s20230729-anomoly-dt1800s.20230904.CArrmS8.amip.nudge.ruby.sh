#!/bin/bash -fe

# E3SM Water Cycle v2 run_e3sm script template.
#
# Inspired by v1 run_e3sm script as well as SCREAM group simplified run script.
#
# Bash coding style inspired by:
# http://kfirlavi.herokuapp.com/blog/2012/11/14/defensive-bash-programming

main() {

# For debugging, uncomment libe below
#set -x

# --- Configuration flags ----

# Machine and project
readonly MACHINE=ruby
readonly PROJECT="cbronze"

# Simulation
readonly COMPSET="ICRUELM"
readonly RESOLUTION="BJ2023ne128x8v2pg2_BJ2023ne128x8v2pg2"
readonly CASE_NAME="BJ3km-ICRUELM1.20230904.CArrmS8.amip.nudge.${MACHINE}"
# If this is part of a simulation campaign, ask your group lead about using a case_group label
# readonly CASE_GROUP=""

# Code and compilation
readonly CHECKOUT="20221110_CAfire"
readonly BRANCH="tangq/atm/CAfire" # dcef11ca346ac1abd5d888d336ecc7e05c827d0e, as of 2022/12/13
readonly CHERRY=( )
readonly DEBUG_COMPILE=false

# Run options
readonly MODEL_START_TYPE="initial"  # 'initial', 'continue', 'branch', 'hybrid'
#readonly START_DATE="2023-07-29"

FORECASTDATE=20230729
NMONTHSSPIN=12
NCYCLES=5
NMONTHSSPIN=$((NMONTHSSPIN*NCYCLES))
START_DATE=`date -d "${FORECASTDATE} - ${NMONTHSSPIN} months" "+%Y-%m-%d"`
echo "Starting at: "${START_DATE}
#exit 1

# Additional options for 'branch' and 'hybrid'
#readonly GET_REFCASE=TRUE
#readonly RUN_REFDIR="/global/cscratch1/sd/tang30/E3SM_simulations/tst.20221118.CArrm.amip.chemUCI_Linozv3.cori-knl/tests/custom-30_1x10_ndays'
#readonly RUN_REFCASE="tst.20221118.CArrm.amip.chemUCI_Linozv3.cori-knl"
#readonly RUN_REFDATE="2010-01-06"   # same as MODEL_START_DATE for 'branch', can be different for 'hybrid'

# Set paths
readonly CODE_ROOT="/p/lustre2/zhang73/GitTmp/SCREAM_push"
readonly CASE_ROOT="/p/lustre1/E3SMfire/zhang73/E3SM_simulations/100m/${CASE_NAME}"

# Sub-directories
readonly CASE_BUILD_DIR=${CASE_ROOT}/build
readonly CASE_ARCHIVE_DIR=${CASE_ROOT}/archive

# Define type of run
#  short tests: 'S_2x5_ndays', 'M_1x10_ndays', 'M80_1x10_ndays'
#  or 'production' for full simulation
#readonly run='production'
readonly run='custom-80_ndays_ICRUELM-6hERA5-s20230729-anomoly-dt1800s'
if [ "${run}" != "production" ]; then

  # Short test simulations
  tmp=($(echo $run | tr "_" " "))
  layout=${tmp[0]}
  units=${tmp[2]}
  resubmit=$(( ${tmp[1]%%x*} -1 ))
  length=${tmp[1]##*x}

  readonly CASE_SCRIPTS_DIR=${CASE_ROOT}/tests/${run}/case_scripts
  readonly CASE_RUN_DIR=${CASE_ROOT}/tests/${run}/run
  readonly PELAYOUT=${layout}
  readonly WALLTIME="04:00:00"
  #readonly STOP_OPTION=${units}
  #readonly STOP_N=${length}
  #readonly REST_OPTION=${STOP_OPTION}
  #readonly REST_N=${STOP_N}
  readonly STOP_OPTION="nyears"
  readonly STOP_N=${NCYCLES}
  readonly REST_OPTION="end"
  readonly REST_N=${STOP_N}
  #readonly RESUBMIT=${resubmit}
  readonly RESUBMIT=0 #10-12
  readonly DO_SHORT_TERM_ARCHIVING=false

else

  # Production simulation
  readonly CASE_SCRIPTS_DIR=${CASE_ROOT}/case_scripts
  readonly CASE_RUN_DIR=${CASE_ROOT}/run
  readonly PELAYOUT="M"
  readonly WALLTIME="48:00:00"
  readonly STOP_OPTION="nyears"
  readonly STOP_N="15"
  readonly REST_OPTION="nyears"
  readonly REST_N="1"
  readonly RESUBMIT="0"
  readonly DO_SHORT_TERM_ARCHIVING=false
fi

# Coupler history 
readonly HIST_OPTION="nyears"
readonly HIST_N="5"

# Leave empty (unless you understand what it does)
readonly OLD_EXECUTABLE=""

# --- Toggle flags for what to do ----
do_fetch_code=false
do_create_newcase=true
do_case_setup=true
do_case_build=false
do_case_submit=true

# --- Now, do the work ---

# Make directories created by this script world-readable
umask 022

# Fetch code from Github
fetch_code

# Create case
create_newcase

# Custom PE layout
custom_pelayout

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

cat << EOF >> user_nl_eam

 nhtfrq =   0,12,12,   -1,-1,-1,  -1,  30,6, -24,-12,-24
 mfilt  = 1,96,96,   24,24,24,  24,  288,1440, 1,2,1
 avgflag_pertape = 'A','I','A',   'I','I','I',  'X',  'A','A', 'A','A'
 !fincl1 = 'CME','DCQ','DTCOND','DTCORE','TTGW','TTEND_TOT','PTTEND','PTEQ','PTECLDLIQ','PTECLDICE','WSUB','WLARGE','VOR','DIV','DYN_PS','QRAIN','UMR'  !,'Nudge_U','Nudge_V','Nudge_T','Nudge_Q'
 !fincl2 = 'FLUT','SOLIN','PRECT','TREFHT','QREFHT','U10','TMQ','TVQ','TUQ'   !'TTQ','PS','PSL',Z200','T200','Q200','U200','V200','Z850','T850','Q850','U850','V850','Z500','T500','Q500','U500','V500'
 !fincl3 = 'FLUT','SOLIN','PRECT','TREFHT','QREFHT','U10','TMQ','TVQ','TUQ'   !'TTQ','PS','PSL',Z200','T200','Q200','U200','V200','Z850','T850','Q850','U850','V850','Z500','T500','Q500','U500','V500'
 !fincl4 = 'PS','PSL','Z200','T200','Q200','U200','V200','Z850','T850','Q850','U850','V850','Z500','T500','Q500','U500','V500'
 !fincl5 = 'U','V','T','Q','Z3','DIV','VOR','DYN_PS','OMEGA'
 !fincl4 = 'U10','PRECT'
 !fincl5 = 'U10','PRECT'
 !fincl4 = 'EXTINCT','AODVIS','Mass_bc','Mass_pom','Mass_mom','Mass_ncl','Mass_soa','Mass_so4','Mass_dst','MASS','PS','TROP_P','TROP_Z'
 !fincl4 = 'EXTINCT','AODVIS','PS'
 !fincl5 = 'VOR:I','DIV:I','DYN_PS:I'
 !fincl6 = 'Nudge_U','Nudge_V','Nudge_T','Nudge_Q'

 iradsw = 4
 iradlw = 4

 !tropopause_e90_thrd		= 80.0e-9
 !history_gaschmbudget_2d = .false.
 !linoz_psc_t = 198.0
 
 !se_tstep = 9.375
 !dt_remap_factor = 1
 !dt_tracer_factor = 1
 !hypervis_subcycle_q = 1
 ncdata = '/usr/gdata/climdat/ccsm3data/inputdata/atm/cam/inic/homme/HICCUP.atm_era5.2023-07-29.ne0np4_BJ2023ne128x8v2_highorder.L128.nc'

 inithist = 'MONTHLY'

 Nudge_Model        =.false.
 Nudge_Path         ='/p/lustre2/zhang73/L128.mono_BJ2023ne128x8v2pg2.UVTQ/'
 Nudge_File_Template='HICCUP.ERA5.%y-%m-%d-%s.128levs.mono_BJ2023ne128x8v2pg2.nc'
 Nudge_Times_Per_Day    =24   
 Nudge_Tau    		=1.
 Model_Times_Per_Day    =1152
 Nudge_Uprof            =2   
 Nudge_Ucoef            =0.5
 Nudge_Vprof            =2   
 Nudge_Vcoef            =0.5
 Nudge_Tprof            =0
 Nudge_Tcoef            =0.0
 Nudge_Qprof            =0
 Nudge_Qcoef            =0.0
 Nudge_PSprof           =0   
 Nudge_PScoef           =0.00
 Nudge_Beg_Year         =2023
 Nudge_Beg_Month        =7
 Nudge_Beg_Day          =1  
 Nudge_End_Year         =2023
 Nudge_End_Month        =8  
 Nudge_End_Day          =31  
 Nudge_Hwin_lo          =0.1
 Nudge_Hwin_hi          =1.0 
 !Nudge_Hwin_lat0        =39.9
 !Nudge_Hwin_latWidth    =4.
 Nudge_Hwin_latDelta    =0.1
 !Nudge_Hwin_lon0        =116.4
 !Nudge_Hwin_lonWidth    =4.
 Nudge_Hwin_lonDelta    =0.1
 Nudge_Vwin_lo          =0.0
 Nudge_Vwin_hi          =1.0
 Nudge_Vwin_Hindex      =127.0
 Nudge_Vwin_Hdelta      =10.
 Nudge_Vwin_Lindex      =0.0
 Nudge_Vwin_Ldelta      =0.1 !cannot.le.0
 Nudge_File_Ntime       =1
 Nudge_Method       ='Linear'
 Nudge_Loc_PhysOut  =.true.
 Nudge_CurrentStep  =.true.

 prescribed_volcaero_datapath           = '/usr/gdata/climdat/ccsm3data/inputdata/atm/cam/volc'
 prescribed_volcaero_file               = 'CMIP_DOE-ACME_radiation_1850-2014_v3_c20171205.nc'
 prescribed_volcaero_filetype           = 'VOLC_CMIP6'
 prescribed_volcaero_type               = 'CYCLICAL'
 prescribed_volcaero_cycle_yr 		= 2015 
EOF

cat << EOF >> user_nl_elm
 check_finidat_year_consistency = .false.
 check_dynpft_consistency = .false.
 check_finidat_fsurdat_consistency = .false.
 check_finidat_pct_consistency = .false.
 fsurdat = '/usr/gdata/climdat/ccsm3data/inputdata/lnd/clm2/surfdata_map/surfdata_BJ2023ne128x8v2pg2_rcp8.5_simyr2015_c230902.nc'
 finidat = '/p/lustre2/zhang73/grids2/BJ2023ne128x8v2/BJ2023ne128x8v2.elm.r.2015-01-01-00000.nc'

hist_avgflag_pertape='A','A'
hist_nhtfrq = 0,24
hist_mfilt = 1,30
hist_fincl1 = 'TSA','TBOT','RAIN','SNOW'
!hist_fincl2 = 'TSA','TBOT','RAIN','SNOW'
EOF


cat << EOF >> user_nl_datm
anomaly_forcing = "Anomaly.Forcing.Precip", "Anomaly.Forcing.Temperature", "Anomaly.Forcing.Humidity"

tintalgo = "coszen", "nearest", "linear", "linear", "lower", "linear","linear","linear"

streams = "datm.streams.txt.CLMCRUNCEP.Solar 2018 2018 2023",
    	  "datm.streams.txt.CLMCRUNCEP.Precip 2018 2018 2023",
    	  "datm.streams.txt.CLMCRUNCEP.TPQW 2018 2018 2023",
    	  "datm.streams.txt.presaero.clim_2000 1 1 1", 
    	  "datm.streams.txt.topo.observed 1 1 1", 
          "datm.streams.txt.Anomaly.Forcing.Precip 2050 2050 2050",
          "datm.streams.txt.Anomaly.Forcing.Temperature 2050 2050 2050",
          "datm.streams.txt.Anomaly.Forcing.Humidity 2050 2050 2050",
EOF

cp /p/lustre2/zhang73/grids2/datm7/atm_forcing.datm7.ERA5.c231021/user_datm.streams.txt.CLMCRUNCEPv7.Solar ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.Solar
cp /p/lustre2/zhang73/grids2/datm7/atm_forcing.datm7.ERA5.c231021/user_datm.streams.txt.CLMCRUNCEPv7.TPQW ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.TPQW
cp /p/lustre2/zhang73/grids2/datm7/atm_forcing.datm7.ERA5.c231021/user_datm.streams.txt.CLMCRUNCEPv7.Precip ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.CLMCRUNCEP.Precip
cp /p/lustre2/zhang73/grids2/datm7/atm_forcing.datm7.ERA5.c231021/datm.streams.txt.topo.observed ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.topo.observed
cp /p/lustre2/zhang73/grids2/datm7/cesmlens/user_datm.streams.txt.Anomaly.Forcing.Temperature ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.Anomaly.Forcing.Temperature
cp /p/lustre2/zhang73/grids2/datm7/cesmlens/user_datm.streams.txt.Anomaly.Forcing.Humidity ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.Anomaly.Forcing.Humidity
cp /p/lustre2/zhang73/grids2/datm7/cesmlens/user_datm.streams.txt.Anomaly.Forcing.Precip ${CASE_SCRIPTS_DIR}/user_datm.streams.txt.Anomaly.Forcing.Precip
#./preview_namelists




cat <<EOF >> user_nl_mosart
 rtmhist_nhtfrq =   0,-24,-3
 rtmhist_mfilt  = 1,30,240
 rtmhist_fincl1 = 'RIVER_DISCHARGE_OVER_LAND_LIQ'
 !rtmhist_fincl3 = 'RIVER_DISCHARGE_OVER_LAND_LIQ'
EOF

cat <<EOF >> user_nl_cice
  model_year_align               = 2023
  stream_fldfilename             = '/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.20230720_20230809.fillmsg.aave_1x1.fmt-c230921.nc'
  stream_fldvarname              = 'ice_cov'
  stream_year_first              = 2023
  stream_year_last               = 2023
EOF

cat <<EOF >> user_nl_docn
streams = "docn.streams.txt.prescribed 2023 2023 2023"
!tintalgo = 'linear'
!taxmode = 'cycle'
EOF

cat <<EOF >> user_docn.streams.txt.prescribed
<?xml version="1.0"?>
<file id="stream" version="1.0">
<dataSource>
   GENERIC
</dataSource>
<domainInfo>
  <variableNames>
     time    time
        xc      lon
        yc      lat
        area    area
        mask    mask
  </variableNames>
  <filePath>
     /usr/gdata/climdat/ccsm3data/inputdata/ocn/docn7
  </filePath>
  <fileNames>
     domain.ocn.1x1.111007.nc
  </fileNames>
</domainInfo>
<fieldInfo>
   <variableNames>
     SST_cpl t
   </variableNames>
   <filePath>
     /p/lustre2/zhang73/DATA/data_hiccup
   </filePath>
   <fileNames>
     sst_ice.daymean.20230720_20230809.fillmsg.aave_1x1.fmt-c230921.nc 
   </fileNames>
   <offset>
      0
   </offset>
</fieldInfo>
</file>
EOF



}

# =====================================
# Customize MPAS stream files if needed
# =====================================

patch_mpas_streams() {

echo

}

# =====================================================
# Custom PE layout: custom-N where N is number of nodes
# =====================================================

custom_pelayout() {

if [[ ${PELAYOUT} == custom-* ]];
then
    echo $'\n CUSTOMIZE PROCESSOR CONFIGURATION:'

    # Number of cores per node (machine specific)
    if [ "${MACHINE}" == "chrysalis" ]; then
        ncore=64
    elif [ "${MACHINE}" == "compy" ]; then
        ncore=40
    elif [ "${MACHINE}" == "cori-knl" ]; then
        #ncore=68
        # for CA RRM to use existing mpas partition file
        ncore=64
    elif [ "${MACHINE}" == "quartz" ]; then
	ncore=36
    elif [ "${MACHINE}" == "syrah" ]; then
	ncore=16
    elif [ "${MACHINE}" == "ruby" ]; then
	ncore=56
    else
        echo 'ERROR: MACHINE = '${MACHINE}' is not supported for custom PE layout.' 
        exit 400
    fi

    # Extract number of nodes
    tmp=($(echo ${PELAYOUT} | tr "-" " "))
    nnodes=${tmp[1]}

    # Customize
    pushd ${CASE_SCRIPTS_DIR}
    ./xmlchange NTASKS=$(( $nnodes * $ncore ))
    ./xmlchange NTHRDS=1
    ./xmlchange MAX_MPITASKS_PER_NODE=$ncore
    ./xmlchange MAX_TASKS_PER_NODE=$ncore
    popd

fi

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
    local repo=e3sm

    echo "Cloning $repo repository branch $BRANCH under $path"
    if [ -d "${path}" ]; then
        echo "ERROR: Directory already exists. Not overwriting"
        exit 20
    fi
    mkdir -p ${path}
    pushd ${path}

    # This will put repository, with all code
    git clone git@github.com:E3SM-Project/${repo}.git .
    
    # Setup git hooks
    rm -rf .git/hooks
    git clone git@github.com:E3SM-Project/E3SM-Hooks.git .git/hooks
    git config commit.template .git/hooks/commit.template

    # Bring in all submodule components
    git submodule update --init --recursive

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

    if [[ ${PELAYOUT} == custom-* ]];
        then
            layout="M" # temporary placeholder for create_newcase
        else
            layout=${PELAYOUT}
    fi

    if [[ -z "$CASE_GROUP" ]]; then
        ${CODE_ROOT}/cime/scripts/create_newcase \
            --case ${CASE_NAME} \
            --output-root ${CASE_ROOT} \
            --script-root ${CASE_SCRIPTS_DIR} \
            --handle-preexisting-dirs u \
            --compset ${COMPSET} \
            --res ${RESOLUTION} \
            --machine ${MACHINE} \
            --project ${PROJECT} \
            --walltime ${WALLTIME} \
            --pecount ${PELAYOUT}
    else
        ${CODE_ROOT}/cime/scripts/create_newcase \
            --case ${CASE_NAME} \
            --case-group ${CASE_GROUP} \
            --output-root ${CASE_ROOT} \
            --script-root ${CASE_SCRIPTS_DIR} \
            --handle-preexisting-dirs u \
            --compset ${COMPSET} \
            --res ${RESOLUTION} \
            --machine ${MACHINE} \
            --project ${PROJECT} \
            --walltime ${WALLTIME} \
            --pecount ${PELAYOUT}
    fi

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
    ./xmlchange DOUT_S=${DO_SHORT_TERM_ARCHIVING^^}
    ./xmlchange DOUT_S_ROOT=${CASE_ARCHIVE_DIR}

    # QT turn off cosp for testing
    ## Build with COSP, except for a data atmosphere (datm)
    #if [ `./xmlquery --value COMP_ATM` == "datm"  ]; then 
    #  echo $'\nThe specified configuration uses a data atmosphere, so cannot activate COSP simulator\n'
    #else
    #  echo $'\nConfiguring E3SM to use the COSP simulator\n'
    #  ./xmlchange --id CAM_CONFIG_OPTS --append --val='-cosp'
    #fi

    # Extracts input_data_dir in case it is needed for user edits to the namelist later
    local input_data_dir=`./xmlquery DIN_LOC_ROOT --value`

    # QT changing chemistry mechanism
    #local usr_mech_infile="${CODE_ROOT}/components/eam/chem_proc/inputs/pp_chemUCI_linozv3_mam4_resus_mom_soag_tag.in"
    #echo '[QT] Changing chemistry to :'${usr_mech_infile}
    #./xmlchange --id CAM_CONFIG_OPTS --append --val='-usr_mech_infile '${usr_mech_infile}

    # This is specific to the CAx32 RRM grid
    ./xmlchange EPS_AGRID=1e-9
    # components/eam/cime_config/config_component.xml: -phys default -shoc_sgs -microphys p3 -chem spa -nlev 128 -rad rrtmgp -bc_dep_to_snow_updates -cppdefs '-DSCREAM'
    #./xmlchange --id CAM_CONFIG_OPTS --val "-mach $MACH -phys default -phys default -shoc_sgs -microphys p3 -chem spa -nlev 72 -rad rrtmgp -bc_dep_to_snow_updates -cppdefs '-DSCREAM'"
    #./xmlchange --append --id CAM_CONFIG_OPTS --val " -nlev 72 "

    #./xmlchange PIO_VERSION=1

    # Custom user_nl

    ./xmlchange ATM_NCPL=48

    user_nl


    # Finally, run CIME case.setup
    #./case.setup --clean
    ./case.setup --reset
    #./case.setup

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
        if [ "${DEBUG_COMPILE^^}" == "TRUE" ]; then
            ./xmlchange DEBUG=${DEBUG_COMPILE^^}
        fi

        # Run CIME case.build
        ./case.build

    fi

    # Some user_nl settings won't be updated to *_in files under the run directory
    # Call preview_namelists to make sure *_in and user_nl files are consistent.
    echo $'\n----- Preview namelists -----\n'
    ./preview_namelists

    popd
}

#-----------------------------------------------------
runtime_options() {

    echo $'\n----- Starting runtime_options -----\n'
    pushd ${CASE_SCRIPTS_DIR}

    # Set simulation start date
    ./xmlchange RUN_STARTDATE=${START_DATE}
    ./xmlchange DATM_CLMNCEP_YR_ALIGN=2018
    ./xmlchange DATM_CLMNCEP_YR_START=2018
    ./xmlchange DATM_CLMNCEP_YR_END=2023


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

    # Patch mpas streams files
    patch_mpas_streams

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
    ./case.submit

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

