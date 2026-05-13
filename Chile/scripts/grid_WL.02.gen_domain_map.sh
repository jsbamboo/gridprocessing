#!/bin/bash

RRMgrid=Chilene32x32v1
ocn_grid_name=oRRS18to6v3
atm_grid_name=${RRMgrid}pg2
date_tag=$(date +"%Y%m%d")
lnd_grid_name=${atm_grid_name}

build_method="manual"
build_method="use_unified"

if [ "${build_method}" = "manual" ];then 
do_step="build"
fi 
do_step="remap"
do_step="gen_domain"
do_step="rsync_to_inputdata"

mach="LC"
mach="perlm"

if [ "${mach}" = "LC" ]; then
  mapping_root=/p/lustre2/zhang73/grids2/${RRMgrid}/
  source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh # need e3sm group
  # source ~/.bashrc_all_stable26
fi 
if [ "${mach}" = "perlm" ]; then
  mapping_root=/global/cfs/cdirs/e3sm/zhang73/grids2/${RRMgrid}/
  source /global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.10.0_pm-cpu.sh
fi 

# -----------------------------------------------------------------------------
if [ "${build_method}" = "manual" ];then 
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318_notoprad/
gen_domain_bin=${e3sm_root}/cime/tools/mapping/gen_domain_files/gen_domain

cd `dirname ${gen_domain}`/src
eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
${e3sm_root}/cime/CIME/scripts/configure --macros-format Makefile --mpilib mpi-serial # => get .env_mach_specific.sh
#--- addtional changes needed for dane: 
#       [Makefile] LDFLAGS += -L$(NETCDF_C_PATH)/lib -lnetcdf -L$(NETCDF_FORTRAN_PATH)/lib -lnetcdff
# .or.  [Makefile] LDFLAGS += $(shell nc-config --libs) $(shell nf-config --flibs)
# .and. [Makefile] LDFLAGS += -Wl,-rpath,$(NETCDF_C_PATH)/lib -Wl,-rpath,$(NETCDF_FORTRAN_PATH)/lib
# .or.  [.env_mach_specific.sh] export LD_LIBRARY_PATH=$HDF5_ROOT/lib:$NETCDF_C_PATH/lib:$NETCDF_FORTRAN_PATH/lib:$LD_LIBRARY_PATH
source .env_mach_specific.sh
gmake
exit 1

else #if [ "${build_method}" = "use_unified" ];then
gen_domain_bin=gen_domain # use e3sm_unified

fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" = "remap" ];then 
# re-org by Chris G:
echo -e "\n----- Generate mapping file OCN2ATM -----"
# exit 1
ncremap -5 -a fv2fv_mono \
  -s $DIN_LOC_ROOT/ocn/mpas-o/oRRS18to6v3/ocean.oRRS18to6v3.scrip.181106.nc \
  -g ${mapping_root}/${atm_grid_name}.g \
  -m ${mapping_root}/map_${ocn_grid_name}_to_${atm_grid_name}.TRaave.${date_tag}.nc

echo -e "\n----- Generate mapping file LND2ROF -----"
ncremap -5 -a fv2fv_mono \
  -s ${mapping_root}/${atm_grid_name}.g \
  -g $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc \
  -m ${mapping_root}/map_${atm_grid_name}_to_r0125.TRaave.${date_tag}.nc

echo -e "\n----- Generate mapping file ROF2LND -----"
ncremap -5 -a fv2fv_mono \
  -s $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc \
  -g ${mapping_root}/${atm_grid_name}.g \
  -m ${mapping_root}/map_r0125_to_${atm_grid_name}.TRaave.${date_tag}.nc

echo -e "\n----- Generate mapping file for SPA (intbilin, SE -> FV) -----"
GenerateCSMesh --alt --res 30  --file ${mapping_root}/ne30.g
GenerateVolumetricMesh --in ne30.g --out ne30pg2.g --np 2 --uniform
ConvertMeshToSCRIP --in ne30pg2.g --out ne30pg2_scrip.nc

ncremap -5 -a intbilin_se2fv \
  -s ${mapping_root}/ne30.g \
  -g ${mapping_root}/${atm_grid_name}.g \
  -m ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc

ncks -O -5 ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc
fi


# -----------------------------------------------------------------------------
if [ "${do_step}" = "gen_domain" ];then 
echo -e "\n----- Generate domain files -----"
cd ${mapping_root}

# if [ "${build_method}" = "manual" ];then 
#   source `dirname ${gen_domain}`/src/.env_mach_specific.sh
# fi 

#for target_grid_name in ${lnd_grid_name} ${atm_grid_name}; do #only need one as atm/lnd are the same
for target_grid_name in ${atm_grid_name}; do
    map_ocn_to_target=${mapping_root}/map_${ocn_grid_name}_to_${target_grid_name}.TRaave.${date_tag}.nc
    ${gen_domain_bin} -m ${map_ocn_to_target} -o ${ocn_grid_name} -l ${target_grid_name}
done
fi 


# -----------------------------------------------------------------------------
if [ "${do_step}" = "rsync_to_inputdata" ];then 
# echo -e "\n----- Copy mapping files to common input location -----"
# rsync -av ${mapping_root}/map*r0125*.${date_tag}.nc $DIN_LOC_ROOT/cpl/gridmaps/${atm_grid_name}/
# rsync -av ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc $DIN_LOC_ROOT/atm/scream/maps/

# echo -e "----- Copy domain files to common input location -----"
# rsync -av domain.lnd.${atm_grid_name}_${ocn_grid_name}.${date_tag:2}.nc $DIN_LOC_ROOT/share/domains/
# rsync -av domain.ocn.${atm_grid_name}_${ocn_grid_name}.${date_tag:2}.nc $DIN_LOC_ROOT/share/domains/
fi 
