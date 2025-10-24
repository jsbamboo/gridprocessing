#!/bin/bash

RRMgrid=WP10ne32x32v1
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318/
e3sm_root_env=/p/lustre2/zhang73/GitTmp/SCREAM_tool/
machine=dane-intel
homme_tool_root=${e3sm_root}/components/homme/test/tool
grids2=/p/lustre2/zhang73/grids2/

do_step="step1.1_homme_tool_np4_build"
do_step="step1.2_homme_tool_np4_run"
do_step="step1.3_homme_tool_np4_ncl"
do_step="step2.1_cube_to_target_run1_build"
do_step="step2.2_cube_to_target_run1_run"
# do_step="step3_homme_tool_smoothing"
# do_step="step4_cube_to_target_run2"
# do_step="step5_ncks_smoothedtopo"

echo ${do_step} '...'
# -----------------------------------------------------------------------------

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- Step 1: Create GLL and pg2 grid template files for !!!
#       the "USGS-topo-cube3000" high res data and the  !!!
#       target EAM grid.                                !!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- Generate GLL SCRIP file for target grid: for RRM grids, this SCRIP files are good enough
#--- for topo downsampling, but not conservative enough for use in the coupled model:
# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1.1_homme_tool_np4_build" ];then 
#--- 1.1 build homme_tool ---
# eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
rm -rf ${e3sm_root}/cmake_homme && mkdir ${e3sm_root}/cmake_homme && cd ${e3sm_root}/cmake_homme
source ${e3sm_root_env}/components/eam/tools/topo_tool/bin_to_cube/.env_mach_specific.sh
cmake \
    -C ${e3sm_root}/components/homme/cmake/machineFiles/dane-intel.cmake \
    -DBUILD_HOMME_WITHOUT_PIOLIBRARY=OFF \
    -DPREQX_PLEV=26 ${e3sm_root}/components/homme/
make -j4 homme_tool
exit 1
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1.2_homme_tool_np4_run" ];then 
#--- 1.2 run homme_tool ---
cd /p/lustre2/zhang73/grids2/${RRMgrid}/

rm -f input.nl
cat > input.nl <<EOF
&ctl_nl                                                                                                             
ne = 0                                                                                                       
mesh_file = "/p/lustre2/zhang73/grids2/${RRMgrid}/${RRMgrid}.g"                                                   
/                                                                                                                    
&vert_nl                                                                                                            
/                                                                                                                   

&analysis_nl                                                                                                        
tool = 'grid_template_tool'                                                                                         
output_dir = "./"                                                                                                   
output_timeunits=1                                                                                                  
output_frequency=1                                                                                                  
output_varnames1='area','corners','cv_lat','cv_lon'                                                                 
!output_type='netcdf'                                                                                                
output_type='netcdf4p'  ! needed for ne1024                                                                        
io_stride = 16                                                                                                      
/                                                                                                                   
EOF

rm -f homme_tool_inputnl.sh
cat > homme_tool_inputnl.sh <<EOF
#!/bin/bash
#
#SBATCH --account=focus
#SBATCH --job-name=topo_gene
#SBATCH --nodes=1
##SBATCH -C cpu
#SBATCH --time=00:05:00
#SBATCH -p pdebug

source /p/lustre2/zhang73/GitTmp/SCREAM_tool/components/eam/tools/topo_tool/bin_to_cube/.env_mach_specific.sh
srun  -K -c 1 -N 1 /p/lustre2/zhang73/GitTmp/E3SM_tool_250318/cmake_homme/src/tool/homme_tool < input.nl 
EOF
sbatch --exclusive homme_tool_inputnl.sh
exit 1
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1.3_homme_tool_np4_ncl" ];then 
#--- 1.3 NCL ---

cd /p/lustre2/zhang73/grids2/${RRMgrid}/

# build NCL: conda install -c conda-forge ncl
source ~/.bashrc_all_stable
# ---make the 'scrip' file for target GLL grid       
ncks -O -v lat,lon,area,cv_lat,cv_lon ne0np4_tmp1.nc ${RRMgrid}np4_tmp.nc
ncl ${e3sm_root}/components/homme/test/tool/ncl/HOMME2SCRIP.ncl  name=\"${RRMgrid}np4\"  ne=0  np=4
exit 1 
fi 


#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- Step 2: cube_to_target, run 1: Compute phi_s on the np4 grid.   !!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# -----------------------------------------------------------------------------
if [ "${do_step}" == "step2.1_cube_to_target_run1_build" ];then 
#--- build cube_to_target ---
export OS=Linux
cd ${e3sm_root}/components/eam/tools/topo_tool/cube_to_target
# eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
${e3sm_root}/cime/CIME/scripts/configure
source .env_mach_specific.sh
#--- changes added to ${e3sm_root}/components/eam/tools/topo_tool/cube_to_target/Makefile: 
#		LDFLAGS += $(USER_LDFLAGS)
# .and. LDFLAGS += -Wl,-rpath,$(NETCDF_C_PATH)/lib -Wl,-rpath,$(NETCDF_FORTRAN_PATH)/lib
    INC_NETCDF="`nf-config --includedir`" \
        LIB_NETCDF="`nc-config --libdir`" USER_FC="`nc-config --fc`" \
        USER_LDFLAGS="`nc-config --libs` `nf-config --flibs`" make  
exit 1 
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step2.2_cube_to_target_run1_run" ];then 
${e3sm_root}/components/eam/tools/topo_tool/cube_to_target/cube_to_target \
--target-grid ${grids2}/${RRMgrid}/${RRMgrid}np4_scrip.nc \
--input-topography ${grids2}/USGS-topo-cube3000.nc \
--output-topography ${grids2}/${RRMgrid}/${RRMgrid}np4_gtopo30.nc
exit 1
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step3_homme_tool_smoothing" ];then 
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- Step 3: homme_tool:                                           !!!
#     Starting with the unsmoothed topo data on the GLL grid,     !!!
#     apply dycore specific smoothing. This uses the standard     !!!
#     tensor laplace smoothing algorithm with 6 iterations.       !!!
#     We use the naming convention "xNt", where N is the value    !!!
#     used for smooth_phis_numcycle and "t" denotes the use of    !!!
#     the tensor laplace.                                         !!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
cd /p/lustre2/zhang73/grids2/${RRMgrid}/

rm -f input2.nl
cat > input2.nl <<EOF
&ctl_nl
ne = 0
mesh_file = '/p/lustre2/zhang73/grids2/${RRMgrid}/${RRMgrid}.g'
smooth_phis_p2filt = 0
smooth_phis_numcycle = 6       ! increase for more smoothing
!smooth_phis_numcycle = 12  			!for 16xdel2
!hypervis_order = 2 					!for 16xdel2
smooth_phis_nudt = 4e-16
hypervis_scaling = 2
se_ftype = 2 ! actually output NPHYS; overloaded use of ftype
/
&vert_nl
/
&analysis_nl
tool = 'topo_pgn_to_smoothed'
infilenames = './${RRMgrid}np4_gtopo30.nc', './${RRMgrid}np4_smoothed_phis_x6t'
! output_type = 'netcdf'
io_stride = 16
/
EOF

rm -f homme_tool_inputnl2.sh
cat > homme_tool_inputnl2.sh <<EOF
#!/bin/bash
#
#SBATCH --account=focus
#SBATCH --job-name=topo_gene
#SBATCH --nodes=1
##SBATCH -C cpu
#SBATCH --time=00:05:00
#SBATCH -p pdebug

source /p/lustre2/zhang73/GitTmp/SCREAM_tool/components/eam/tools/topo_tool/bin_to_cube/.env_mach_specific.sh
srun  -K -c 1 -N 1 /p/lustre2/zhang73/GitTmp/E3SM_tool_250318/cmake_homme/src/tool/homme_tool < input2.nl 
EOF
sbatch --exclusive homme_tool_inputnl2.sh
exit 1 
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step4_cube_to_target_run2" ];then 
# #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# #--- Step 4: cube_to_target, run 2: Compute SGH, SGH30, LANDFRAC,       !!!
# #       and LANDM_COSLAT on the pg2 grid, using the pg2 phi_s data.     !!!
# #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${e3sm_root}/components/eam/tools/topo_tool/cube_to_target/cube_to_target \
--target-grid ${grids2}/${RRMgrid}/${RRMgrid}pg2_scrip.nc \
--input-topography ${grids2}/USGS-topo-cube3000.nc \
--smoothed-topography ${grids2}/${RRMgrid}/${RRMgrid}np4_smoothed_phis_x6t1.nc \
--output-topography ${grids2}/${RRMgrid}/GTOPO30_${RRMgrid}np4pg2_x6t.nc
exit 1
fi 

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step5_ncks_smoothedtopo" ];then 
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# --- Step 5: ncks: Append the GLL phi_s data to the output of step 4. 	 !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
cd /p/lustre2/zhang73/grids2/${RRMgrid}/
source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh

ncks -A ${RRMgrid}np4_smoothed_phis_x6t1.nc GTOPO30_${RRMgrid}np4pg2_x6t.nc
exit 1
fi 
