#!/bin/bash

RRMgrid=WP10ne32x32v1
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318/
gen_domain=${e3sm_root}/cime/tools/mapping/gen_domain_files/gen_domain
mapping_root=/p/lustre2/zhang73/grids2/${RRMgrid}/
ocn_grid_name=oRRS18to6v3
atm_grid_name=${RRMgrid}pg2
date_tag=$(date +"%Y%m%d")
lnd_grid_name=${atm_grid_name}

do_step="build"
do_step="remap"
do_step="gen_domain"

# -----------------------------------------------------------------------------
if [ "${do_step}" == "build" ];then 
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
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "remap" ];then 
source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh

ncremap -5 -a fv2fv_mono -s $DIN_LOC_ROOT/ocn/mpas-o/oRRS18to6v3/ocean.oRRS18to6v3.scrip.181106.nc -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}//map_${ocn_grid_name}_to_${atm_grid_name}.TRaave.${date_tag}.nc  
ncremap -5 -a fv2fv_mono -s ${mapping_root}/${atm_grid_name}.g -g $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -m ${mapping_root}/map_${atm_grid_name}_to_r0125.TRaave.${date_tag}.nc
ncremap -5 -a fv2fv_mono -s $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}/map_r0125_to_${atm_grid_name}.TRaave.${date_tag}.nc 
ncremap -5 -a intbilin_se2fv -s $DIN_LOC_ROOT/atm/cam/inic/homme/ne30.g -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc

rsync -av ${mapping_root}/map*r0125*TRaave.${date_tag}.nc  $DIN_LOC_ROOT/cpl/gridmaps/${atm_grid_name}/
rsync -av ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc  $DIN_LOC_ROOT/atm/scream/maps/
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "gen_domain" ];then 
# source `dirname ${gen_domain}`/src/.env_mach_specific.sh

domain_root=${mapping_root} 
cd ${domain_root}
for target_grid_name in ${lnd_grid_name} ${atm_grid_name}; do
    map_ocn_to_target=${mapping_root}/map_${ocn_grid_name}_to_${target_grid_name}.TRaave.${date_tag}.nc
    ${gen_domain} -m ${map_ocn_to_target} -o ${ocn_grid_name} -l ${target_grid_name}
done

rsync -av domain.ocn.${atm_grid_name}_${ocn_grid_name}.${date_tag}.nc $DIN_LOC_ROOT/share/domains/
fi 
