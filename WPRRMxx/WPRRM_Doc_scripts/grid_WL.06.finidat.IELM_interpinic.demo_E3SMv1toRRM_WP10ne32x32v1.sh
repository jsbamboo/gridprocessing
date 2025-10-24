#!/bin/bash

RRMgrid=WP10ne32x32v1
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318 #---this netcdf version is not high enough to activate NF_FORMAT_64BIT_OFFSET

interpinic=${e3sm_root}/components/elm/tools/interpinic/
output_root=/p/lustre2/zhang73/grids2/finidat_interpinic
lnd_grid_name=${RRMgrid}pg2

do_step="step1_interpinic_build"
do_step="step2_interpinic_run"

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1_interpinic_build" ];then 
cd ${interpinic}/src
#---this netcdf version is not high enough to activate NF_FORMAT_64BIT_OFFSET
# eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
# ${e3sm_root}/cime/CIME/scripts/configure --macros-format Makefile --mpilib mpi-serial
# source .env_mach_specific.sh
source /p/lustre2/zhang73/GitTmp/SCREAM_tool/components/eam/tools/topo_tool/bin_to_cube/.env_mach_specific.sh

INC_NETCDF="`nf-config --includedir`" \
    LIB_NETCDF="`nc-config --libdir`" USER_FC="`nc-config --fc`" \
    USER_LDFLAGS="`nc-config --libs` `nf-config --flibs` -Wl,-rpath,${NETCDF_C_PATH}/lib -Wl,-rpath,${NETCDF_FORTRAN_PATH}/lib" make
exit 1
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step2_interpinic_run" ];then 
  source_inic_file=/p/lustre2/zhang73/HPSS/20180215.DECKv1b_H1.ne30_oEC.edison/20180215.DECKv1b_H1.ne30_oEC.edison.clm2.r.2015-01-01-00000.nc
  output_inic_file=${output_root}/${lnd_grid_name}.elm.r.2015-01-01.nc
  if [ "${RRMgrid}" == "WP10ne32x32v1" ];then 
  target_inic_file=/p/lustre1/zhang73/E3SM_simulations/wprrmxx_p3/WPRRMxx_p3.WP10ne32x32v1pg2_WP10ne32x32v1pg2.F2010-SCREAMv1.dane/tests/1120x1_nhoursx1_UVTQ3h-s20141001-finicold-O3p3/run/WPRRMxx_p3.WP10ne32x32v1pg2_WP10ne32x32v1pg2.F2010-SCREAMv1.dane.elm.r.2014-10-01-03600.nc
  fi
  if [ "${RRMgrid}" == "WP20ne32x32v1" ];then 
  target_inic_file=/p/lustre1/zhang73/E3SM_simulations/wprrmxx_p3/WPRRMxx.WP20ne32x32v1pg2_WP20ne32x32v1pg2.F2010-SCREAMv1.dane/tests/2240x1_nhoursx1_UV3h-s20141001-finicold-O1/run/WPRRMxx.WP20ne32x32v1pg2_WP20ne32x32v1pg2.F2010-SCREAMv1.dane.elm.r.2014-10-01-03600.nc
  fi 

  if ! test -f ${output_inic_file}; then cp ${target_inic_file} ${output_inic_file}; fi
  cd ${e3sm_root}/components/elm/tools/interpinic
  source /p/lustre2/zhang73/GitTmp/SCREAM_tool/components/eam/tools/topo_tool/bin_to_cube/.env_mach_specific.sh
  ./interpinic -i ${source_inic_file} -o ${output_inic_file}

  rsync -av ${output_inic_file} ${output_root}/../${RRMgrid}/
fi


