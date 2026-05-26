#!/bin/bash

mach="LC"
# mach="perlm"
if [ "${mach}" == "LC" ]; then
    host_proc="/p/lustre2/zhang73"
else
    host_proc="/global/cfs/cdirs/e3sm/zhang73"
fi

RRMgrid=Chilene32x32v1

build_method="manual"
build_method="e3sm_unified"

if ! test -d ${host_proc}/grids2/${RRMgrid}; then mkdir -p ${host_proc}/grids2/${RRMgrid}; fi
cd ${host_proc}/grids2/${RRMgrid}


# ======================================================================================================
if [ "${build_method}" = "manual" ]; then
# old: install it by yourself
SQuadGen_dir="/p/lustre2/zhang73/GitTmp/SourceCode"

cd ${SQuadGen_dir}/../
git clone git@github.com:ClimateGlobalChange/squadgen.git squadgen-v1.2.2; cd squadgen-v1.2.2
vi /p/lustre2/zhang73/GitTmp/E3SM_tool_250318_notoprad/cime_config/machines/config_machines.xml  # find NETCDF_FORTRAN_PATH for specific mach in E3SM
vi src/Makefile # copy NETCDF_FORTRAN_PATH
make all

SQuadGen_bin=${SQuadGen_dir}/SQuadGen

# for nco, ncl, tempest-remap
conda create --name all_stable26 -c conda-forge nco ncl ncview cdo imagemagick tempest-remap
conda activate all_stable26
fi 


# ======================================================================================================
if [ "${build_method}" = "e3sm_unified" ]; then
# new Chris G: We use SQuadGen which is available as part of E3SM Unified and refine over a rotated rectangular region using command line options:
if [ "${mach}" == "LC" ]; then
source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh  # need e3sm group
module load gcc/13.3.1
module load mvapich2/2.3.7
module load ncl
fi 
if [ "${mach}" == "perlm" ]; then
source /global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.11.0_pm-cpu.sh
fi 

SQuadGen_bin=SQuadGen
fi 

# if use e3sm_unified conda env 
${SQuadGen_bin} \
--output Chilene32x32v1.g \
--lat_ref -30.25 --lon_ref 289.5 \
--refine_rect "286,-17.5,293,-43,5" --refine_level 5 \
--x_rotate -6 \
--resolution 32 --smooth_type SPRING

GenerateVolumetricMesh --in Chilene32x32v1.g --out Chilene32x32v1pg2.g --np 2 --uniform
ConvertMeshToSCRIP --in Chilene32x32v1.g --out Chilene32x32v1_scrip.nc
ConvertMeshToSCRIP --in Chilene32x32v1pg2.g --out Chilene32x32v1pg2_scrip.nc

# rsync -av Chilene32x32v1.g $DIN_LOC_ROOT/atm/cam/inic/homme/