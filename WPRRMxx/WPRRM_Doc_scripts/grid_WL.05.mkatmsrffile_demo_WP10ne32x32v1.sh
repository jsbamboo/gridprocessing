#!/bin/bash

RRMgrid=WP10ne32x32v1
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318  
mkatmsrffile=${e3sm_root}/components/eam/tools/mkatmsrffile/old_mkatmsrffile
grids2=/p/lustre2/zhang73/grids2/
INPUTDATA_ROOT=$DIN_LOC_ROOT
date_tag=$(date +"%Y%m%d")

do_step="step1_mkatmsrffile_build"
do_step="step2_gen_map"
do_step="step3_mkatmsrffile_run"

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1_mkatmsrffile_build" ];then 
cd ${mkatmsrffile} && echo ${mkatmsrffile}
# eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
${e3sm_root}/cime/CIME/scripts/configure --macros-format=Makefile
source .env_mach_specific.sh

#---Modify Makefile: 
# 		INC = -I$(shell nf-config --includedir)
# 		LIB = -L$(shell nc-config --libdir) -lnetcdf -lnetcdff
# 		LIB += $(USER_LDFLAGS)
 FC="`nc-config --fc`" \
    USER_LDFLAGS="`nc-config --libs` `nf-config --flibs` -Wl,-rpath,${NETCDF_C_PATH}/lib -Wl,-rpath,${NETCDF_FORTRAN_PATH}/lib" make  
exit 1
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step2_gen_map" ];then
source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh

ncremap -5 -a fv2fv_mono -s ${grids2}/1x1d.nc -g ${grids2}/${RRMgrid}/${RRMgrid}pg2.g -m ${grids2}/${RRMgrid}/map_1x1_to_${RRMgrid}pg2.TRaave.${date_tag}.nc
exit 1
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step3_mkatmsrffile_run" ];then 
cat > ${mkatmsrffile}/nml_atmsrf <<EOF 
&input
srfFileName = '${grids2}/1x1d.nc'
landFileName = '${INPUTDATA_ROOT}/atm/cam/chem/trop_mozart/dvel/regrid_vegetation.nc'
soilwFileName = '${INPUTDATA_ROOT}/atm/cam/chem/trop_mozart/dvel/clim_soilw.nc'
atmFileName = '${grids2}/${RRMgrid}/${RRMgrid}pg2_scrip.nc'
srf2atmFmapname = '${grids2}/${RRMgrid}/map_1x1_to_${RRMgrid}pg2.TRaave.${date_tag}.nc'
outputFileName = '${grids2}/${RRMgrid}/atmsrf_${RRMgrid}pg2_${date_tag}.nc'
/
EOF

cd ${mkatmsrffile}
./mkatmsrffile

mv nml_atmsrf nml_atmsrf_${RRMgrid}pg2
fi
