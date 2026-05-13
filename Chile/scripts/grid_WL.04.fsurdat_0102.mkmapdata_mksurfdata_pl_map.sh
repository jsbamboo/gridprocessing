#!/bin/sh

RRMgrid=Chilene32x32v1
#---use the up-to-date elm tool, and revert the toprad commits to avoid `the map_0.01x0.01 does not found error'
mach="LC"
# mach="perlm"
if [ "${mach}" = "LC" ]; then 
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318_notoprad
e3sm_root_build=/p/lustre2/zhang73/GitTmp/E3SM_tool_260410
grids2=/p/lustre2/zhang73/grids2/
fi
if [ "${mach}" = "perlm" ]; then 
# e3sm_root=/global/cfs/cdirs/e3sm/zhang73/GitTmp/E3SM_tool_250429_toprad
e3sm_root=/global/cfs/cdirs/e3sm/zhang73/GitTmp/E3SM_tool_250318_notoprad
e3sm_root_build=/global/cfs/cdirs/e3sm/zhang73/GitTmp/E3SM_tool_260410
grids2=/global/cfs/cdirs/e3sm/zhang73/grids2/
fi
GRIDFILE=${grids2}/${RRMgrid}/${RRMgrid}pg2_scrip.nc
INPUTDATA_ROOT=$DIN_LOC_ROOT
date_tag=$(date +"%Y%m%d")
year_fsurdat=2015
# rcp_tag=""
rcp_level=3-7.0
rcp_tag="-rcp ${rcp_level}"
cdate_manualcheck="260410" #LC
cdate_manualcheck="260411" #LC

do_step="step1_mkmapdata"
do_step="step2_gen_mksurfdata_pl"
# do_step="step3_build_mksurfdata_map"
do_step="step4_run_mksurfdata_map"

use_multiN=true #only needed for map_1km-merge-10min_HYDRO1K-merge-nomask

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1_mkmapdata" ];then
cd ${e3sm_root}/components/elm/tools/mkmapdata

echo '--- ESMFBIN_PATH start mkmapdata_sbatch.sh ---' 
#--- use esmf-mpi from unified env ---

if [ "${mach}" = "LC" ]; then 
export ESMFBIN_PATH=/usr/WS1/e3sm/apps/e3sm-unified/base/envs/e3sm_unified_1.10.0_login/bin
source ~/.bashrc_all_stable26
#--- Speed: WP10ne32x32v1 (WP20ne32x32v1) took 7.5min (<29min) for 1km-merge-10min_HYDRO1K-merge-nomask
export mpiexec="srun --account=focus --time=00:29:00 -p pbatch -N 20"  # waiting for a bank ... OOM on login node
fi  #LC

if [ "${mach}" = "perlm" ]; then 
#--- from grid_WL.fsurdat_0102.mkmapdata_mksurfdata_pl_map_demo_amazonx4v1.perlm.Dalei.sh
ESMF_version="e3sm_unified_1_11_1_pm-cpu_gnu_mpich"
export ESMFBIN_PATH=/global/common/software/e3sm/anaconda_envs/spack/e3sm_unified_1_11_1_pm-cpu_gnu_mpich/var/spack/environments/e3sm_unified_1_11_1_pm-cpu_gnu_mpich/.spack-env/view/bin
export mpiexec="srun -N 20 --time=00:29:00 --qos=regular -C cpu -A mp193"  # waiting for a bank ... OOM on login node
fi #perlm

echo $ESMFBIN_PATH
#--- env with ncl and nco



#--- dry-run to check the mapping file list
# ./mkmapdata.sh --gridfile ${GRIDFILE} --inputdata-path ${INPUTDATA_ROOT} --res ${RRMgrid}pg2 --gridtype global --esmf-path ${ESMFBIN_PATH} --output-filetype 64bit_offset --debug -v --list
# exit 1

#--- regridding 
if $use_multiN; then
./mkmapdata.sh --mpiexec "${mpiexec}" --gridfile ${GRIDFILE} --inputdata-path ${INPUTDATA_ROOT} --res ${RRMgrid}pg2 --gridtype global --esmf-path ${ESMFBIN_PATH}  --output-filetype 64bit_offset -v --batch
else 
./mkmapdata.sh --gridfile ${GRIDFILE} --inputdata-path ${INPUTDATA_ROOT} --res ${RRMgrid}pg2 --gridtype global --esmf-path ${ESMFBIN_PATH} --output-filetype 64bit_offset -v
fi 
echo " ./mkmapdata.sh --gridfile ${GRIDFILE} --inputdata-path ${INPUTDATA_ROOT} --res ${RRMgrid}pg2 --gridtype global --output-filetype 64bit_offset -v"
exit 1

fi #do_step: step1_mkmapdata

# -----------------------------------------------------------------------------
if  [ "${do_step}" == "step2_gen_mksurfdata_pl" ];then
cd ${e3sm_root}/components/elm/tools/mksurfdata_map

./mksurfdata.pl -res usrspec -usr_gname ${RRMgrid}pg2 -usr_gdate ${cdate_manualcheck} -y ${year_fsurdat} ${rcp_tag} -d -dinlc ${INPUTDATA_ROOT} -usr_mapdir ${e3sm_root}/components/elm/tools/mkmapdata

#---modify it manually if needed, e.g., add the landuse.timeseries <mksrf_fdynuse> <fdyndat>
cp namelist namelist_${RRMgrid}pg2_rcp${rcp_level}-${year_fsurdat}.${mach}
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step3_build_mksurfdata_map" ];then 
#---26/04/12: need to rebuild ./mksurfdata_map:
#       perlm: error while loading shared libraries: libnetcdff.so.6: cannot open shared object file: No such file or directory
#       LC: HDF5: infinite loop closing library
cd ${e3sm_root_build}/components/elm/tools/mksurfdata_map/src
rm -rf Depends* cmake_macros Macros.*

echo "eval $(${e3sm_root_build}/cime/CIME/Tools/get_case_env)"
echo "${e3sm_root_build}/cime/CIME/scripts/configure"
eval $(${e3sm_root_build}/cime/CIME/Tools/get_case_env)
# ${e3sm_root_build}/cime/CIME/scripts/configure --macros-format Makefile --mpilib mpi-serial #dont use seriel?
${e3sm_root_build}/cime/CIME/scripts/configure
source ${e3sm_root_build}/components/elm/tools/mksurfdata_map/src/.env_mach_specific.sh
echo "MPILIB: $MPILIB"
which nf-config
nf-config --flibs
which ftn #no ftn on LC
which mpif90
ftn --version
exit 1

cd ${e3sm_root}/components/elm/tools/mksurfdata_map/src #back to the code for notoprad
if [ "${mach}" = "LC" ]; then
    FC=ifx
    #---note env use new mach config, but code is old (notoprad)
    source /p/lustre2/zhang73/GitTmp/E3SM_tool_260410/components/elm/tools/mksurfdata_map/src/.env_mach_specific.sh
    INC_NETCDF="`nf-config --includedir`" \
        LIB_NETCDF="`nc-config --libdir`" USER_FC=ifx \
        USER_LDFLAGS="`nc-config --libs` `nf-config --flibs` -Wl,-rpath,${NETCDF_C_PATH}/lib -Wl,-rpath,${NETCDF_FORTRAN_PATH}/lib" make  
    mv mksurfdata_map  mksurfdata_map.LC_E3SM_tool_260410.ifx_240412
fi 

if [ "${mach}" = "perlm" ]; then 
    FC=ftn
    vi makefile.common -> for ftn: FFLAGS += -O2 -fp-model precise
    INC_NETCDF="`nf-config --includedir`" \
        LIB_NETCDF="`nc-config --libdir`" USER_FC=ftn \
        USER_LDFLAGS="`nc-config --libs` `nf-config --flibs` -Wl,-rpath,${NETCDF_C_PATH}/lib -Wl,-rpath,${NETCDF_FORTRAN_PATH}/lib" make  
    mv mksurfdata_map  mksurfdata_map.perlm_E3SM_tool_260410.ftn_noKieee
fi 

# exit 1
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step4_run_mksurfdata_map" ];then 
cd ${e3sm_root}/components/elm/tools/mksurfdata_map

#!!! bin is build with the notoprad code && new build env!!!
if [ "${mach}" = "LC" ]; then 
    mksurfdata_map_bin=${e3sm_root}/components/elm/tools/mksurfdata_map/mksurfdata_map.LC_E3SM_tool_260410.ifx_240412
fi 
if [ "${mach}" = "perlm" ]; then 
    mksurfdata_map_bin=${e3sm_root}/components/elm/tools/mksurfdata_map/mksurfdata_map.perlm_E3SM_tool_260410.ftn_noKieee
fi 
source ${e3sm_root_build}/components/elm/tools/mksurfdata_map/src/.env_mach_specific.sh

#---cannot use MPI actually due to  mpi-serial build? -> in the configure command, dont specify mpi-serial
# srun --account=mp193 --time=00:20:00 -q debug -N 1 -C cpu \
${mksurfdata_map_bin} < namelist_${RRMgrid}pg2_rcp${rcp_level}-${year_fsurdat}.${mach}

# mv surfdata_${RRMgrid}pg2_rcp8.5_simyr2015_${date_tag}.nc  landuse.timeseries_${RRMgrid}pg2_rcp8.5_simyr2015-2100_${date_tag}.nc  ${grids2}/${RRMgrid}/
# rsync -av ${grids2}/${RRMgrid}/surfdata_${RRMgrid}pg2_rcp8.5_simyr2015_${date_tag}.nc  landuse.timeseries_${RRMgrid}pg2_rcp8.5_simyr2015-2100_${date_tag}.nc  $DIN_LOC_ROOT/lnd/clm2/surfdata_map/
fi

