# EAMxx 3.25 km Western Pacific RRM Technical Note

_Converted from `WPRRM_Doc.tex` to Markdown._

## Contents

- [Introduction](#introduction)
- [Usage Note](#usage-note)
- [Resources](#resources)
- [Prepare E3SM codebase for standalone tools](#prepare-e3sm-codebase-for-standalone-tools)
- [RRM grid design](#rrm-grid-design)
  - [RRM exodus mesh](#rrm-exodus-mesh)
  - [mapping file](#mapping-file)
  - [domain file](#domain-file)
  - [topography](#topography)
  - [land surface data](#land-surface-data)
  - [dry deposition](#dry-deposition)
- [Initial conditions](#initial-conditions)
  - [atmosphere IC](#atmosphere-ic)
  - [land IC](#land-ic)
- [Model configurations (CIME xml)](#model-configurations-cime-xml)
  - [Prepare E3SM codebase for simulations](#prepare-e3sm-codebase-for-simulations)
  - [grid](#grid)
  - [compset](#compset)
- [Boundary conditions](#boundary-conditions)
  - [create lower BL (SST, ice cover)](#create-lower-bl-sst-ice-cover)
  - [create lateral BL (nudging files)](#create-lateral-bl-nudging-files)
  - [output YAML](#output-yaml)
  - [user namelists](#user-namelists)

**Copyright statement:** The codes documented here are basically inherited/modified from previous practices in Resources listed in Table 1 or mentioned in the text, which is not subject to copyright restrictions.

## Introduction

The Western Pacific Convection-Permitting (CP) Regionally Refined Model (RRM) used for 2023 Jingjinji Flood event is developed based on the Simple Cloud-Resolving E3SM Atmosphere Model (SCREAM) version 0 (Fortran code) under the United States (U.S) Department of Energy (DOE) Energy Exascale Earth System Model (E3SM) project [Caldwell2021] and the regionally refined model (RRM) configuration [Tang2019, Tang2023, Zhang2024, Bogenschutz2024].

SCREAM WPRRM related code changes are located in <https://github.com/jsbamboo/E3SM/tree/jzhang/WPRRMxx>.

## Usage Note

This documentation does not represent best practices and should instead be regarded as a personal user log. Many steps have been simplified to varying degrees, depending on the user's specific research priorities. For example, omitting land spin-up would not be sufficient for users focusing on atm-land coupling (even though in our case the region of interest contains little land, and UVTQ window nudging was applied at the domain boundaries that largely contrained the fluxes coming into the region of interest).

The tools used in this record are not necessarily recommended or endorsed. Many steps can be accomplished using different tools depending on personal preference, availability, and the computational environment at the time. The scripts included here are not guaranteed to be out-of-box, especially for new users, e.g., differences in software versions and computing systems may easily lead to errors. Based on personal experience, most such issues can be resolved through self-debugging. Other users have also reported that AI coding tools can help translate between programming languages without significantly increasing workload.

For reference only.

## Resources

**Table: Main resources for references.**

| Category | Link |
| --- | --- |
| New grid homepage | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/872579110/Running+E3SM+on+New+Grids> |
| RRM grid Library | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/3690397775/Library+of+Regionally-Refined+Model+%28RRM%29+Grids> |
| Topography | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/2720202817/Topography+Generation> |
| atm initial condition | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/1002373272/Generate+atm+initial+condition+from+analysis+data> |
| streamfile | <https://esmci.github.io/cime/versions/ufs_release_v1.1/html/data_models/data-ocean.html> |
| Nudging | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/20153276/How+to+perform+nudging+simulations+with+the+regional+refined+model+RRM> |
| SE grid visualization | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/1210023949/Plotting+data+on+SE+native+grid> |
| TempestRemap algorithm | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/178848194/Recommended+Mapping+Procedures+for+E3SM+Atmosphere+Grids> |
| ncremap | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/754286611/Regridding+E3SM+Data+with+ncremap> |
| lnd initial condition | <https://github.com/zarzycki/betacast/tree/master/land-spinup> |
| CARRM v0 Technical Note | <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/3804299340/SCREAM+California+RRM+v0+Technical+Note> |

## Prepare E3SM codebase for standalone tools

```bash
git clone git@github.com:E3SM-Project/E3SM.git E3SM_tool_250318
git checkout -b jzhang/tools/revert_toprad_250318
git revert afb3c3221f6c439cfbbe7c4e9725fa014fa44867 567fa1d665a2909266a3ee774e725e97b30a7f05
vi components/elm/bld/namelist_files/namelist_defaults_tools.xml
git add components/elm/bld/namelist_files/namelist_defaults_tools.xml
git rm components/elm/tools/mksurfdata_map/src/mktopradMod.F90
git revert --continue
vi components/elm/bld/namelist_files/namelist_defaults.xml
vi components/elm/bld/namelist_files/namelist_defaults_tools.xml
git add components/elm/bld/namelist_files/namelist_defaults.xml components/elm/bld/namelist_files/namelist_defaults_tools.xml
git rm components/elm/tools/mksurfdata_map/src/mktopradMod.F90
git revert --continue
git submodule update --init --recursive; git submodule sync --recursive; git submodule update --recursive
vi components/elm/bld/namelist_files/namelist_defaults_tools.xml # forget something ..
git add components/elm/bld/namelist_files/namelist_defaults_tools.xml
git commit --amend 
```

## RRM grid design

This section is largely inherited (and simplified) from the SCREAM CARRM v0 Technical Note: <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/3804299340/SCREAM+California+RRM+v0+Technical+Note>.

The main reference page (<https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/872579110/Running+E3SM+on+New+Grids>) is a veritable repository of the entire process of generating RRM grids and the associated files needed to run RRM, down to the specific commands for each step and and installation commands of tools. Due to the rapid development of grid tools, many steps have multiple choices (based on different tools or different packages). For example, for mapping function, TempestRemap, mbtempset and ESMF_Regridweightgen are well encapsulated by ncremap; users can choose which tool commands to use by their preference.

### RRM exodus mesh

There are multiple WPRRM meshes. Two versions used in the summary paper are documented here:
- WP10ne32x32v1 (3km 10deg x 10deg)
- WP20ne32x32v1 (3km 20deg x 20deg)

- Use SQuadGen to get the RRM grid and tempestremap to get the pg2 grid and SCRIP files:

```bash
git clone git@github.com:ClimateGlobalChange/squadgen.git squadgen-v1.2.2; cd squadgen-v1.2.2
vi /p/lustre2/zhang73/GitTmp/E3SM_tool_250318/cime_config/machines/config_machines.xml  # find NETCDF_FORTRAN_PATH for specific mach in E3SM
vi src/Makefile # copy NETCDF_FORTRAN_PATH
make all
./SQuadGen --output WP10ne32x32v1.g --lat_ref 7.5 --lon_ref 165 --refine_rect "160,2.5,170,12.5,5" --refine_level 5 --resolution 32 --smooth_type SPRING 
./SQuadGen --output WP20ne32x32v1.g --lat_ref 7.5 --lon_ref 165 --refine_rect "155,-2.5,175,17.5,5" --refine_level 5 --resolution 32 --smooth_type SPRING 

conda create -n tempest-remap-2.2.0 -c conda-forge tempest-remap; conda activate tempest-remap-2.2.0
GenerateVolumetricMesh --in WP10ne32x32v1.g --out WP10ne32x32v1pg2.g --np 2 --uniform
ConvertMeshToSCRIP --in WP10ne32x32v1.g --out WP10ne32x32v1_scrip.nc
ConvertMeshToSCRIP --in WP10ne32x32v1pg2.g --out WP10ne32x32v1pg2_scrip.nc
GenerateVolumetricMesh --in WP20ne32x32v1.g --out WP20ne32x32v1pg2.g --np 2 --uniform
ConvertMeshToSCRIP --in WP20ne32x32v1.g --out WP20ne32x32v1_scrip.nc
ConvertMeshToSCRIP --in WP20ne32x32v1pg2.g --out WP20ne32x32v1pg2_scrip.nc

rsync -av WP10ne32x32v1.g WP20ne32x32v1.g $DIN_LOC_ROOT/atm/cam/inic/homme/
```

The mesh of Western Pacific RRMs are shown in Fig. 1, plotted using NCL:

`../scripts/grid_WL.01.SQuadGen_03.draw_SCRIP_demo.ncl`

![Regionally refined grid for the default and larger Western Pacific CP-RRMs.](../scripts/WPRRM_mesh_0.jpg)

*Figure: Regionally refined grid for the default and larger Western Pacific CP-RRMs.*

### mapping file

WPRRM model grid for atm, land, ocnice are all on WP10ne32x32v1/WP20ne32x32v1, while the river transport model is on a regular latitude-longitude grid with spacing of 0.125°. The mapping files are used for OCN2ATM ATM2ROF (flux, state/vector) and LND2ROF/ROF2LND (flux). All use FV-> FV aave (conservative, monotone, 1st order) algorithm.

Also need to create the mapping file for the Simple Prescribed Aerosol (SPA) scheme used in EAMxx. This is always from ne30np4 to the new grid pg2.

We highly suggest that readers refer to this web page for the knowledge of mapping procedures (notation, validation, issues, etc.) especially if readers plan to use bi-grid or tri-grid for RRM: <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/178848194/Recommended+Mapping+Procedures+for+E3SM+Atmosphere+Grids#RecommendedMappingProceduresforE3SMAtmosphereGrids-E3SMv2withpg2>).

- OCN2ATM:

```bash
ncremap -5 -a fv2fv_mono -s $DIN_LOC_ROOT/ocn/mpas-o/oRRS18to6v3/ocean.oRRS18to6v3.scrip.181106.nc -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}//map_${ocn_grid_name}_to_${atm_grid_name}.TRaave.${date_tag}.nc  
```

- LND2ROF:

```bash
ncremap -5 -a fv2fv_mono -s WP10ne32x32v1pg2.g -g $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -m map_WP10ne32x32v1pg2_to_r0125.TRaave.20250318.nc
```

- ROF2LND:

```bash
ncremap -5 -a fv2fv_mono -s $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -g WP10ne32x32v1pg2.g -m map_r0125_to_WP10ne32x32v1pg2.TRaave.20250318.nc 
```

- mapping file for SPA (intbilin, SE -> FV):

```bash
ncremap -5 -a intbilin_se2fv -s $DIN_LOC_ROOT/atm/cam/inic/homme/ne30.g -g WP10ne32x32v1pg2.g -m map_ne30np4_to_WP10ne32x32v1pg2.intbilin.20250318.nc
```

### domain file

Here the domain files are generated for "oRRS18to6v3" data-ocean (streamfile) and "WP10ne32x32v1/WP20ne32x32v1" atm & land.

`../scripts/grid_WL.02.gen_domain.sh`

```bash
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

ncremap -a fv2fv_mono -s $DIN_LOC_ROOT/ocn/mpas-o/oRRS18to6v3/ocean.oRRS18to6v3.scrip.181106.nc -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}//map_${ocn_grid_name}_to_${atm_grid_name}.TRaave.${date_tag}.nc  
ncremap -a fv2fv_mono -s ${mapping_root}/${atm_grid_name}.g -g $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -m ${mapping_root}/map_${atm_grid_name}_to_r0125.TRaave.${date_tag}.nc
ncremap -a fv2fv_mono -s $DIN_LOC_ROOT/share/meshes/rof/MOSART_global_8th.scrip.20180211c.nc -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}/map_r0125_to_${atm_grid_name}.TRaave.${date_tag}.nc 
ncremap -a intbilin_se2fv -s $DIN_LOC_ROOT/atm/cam/inic/homme/ne30.g -g ${mapping_root}/${atm_grid_name}.g -m ${mapping_root}/map_ne30np4_to_${atm_grid_name}.intbilin.${date_tag}.nc

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
fi 

rsync -av domain.ocn.${atm_grid_name}_${ocn_grid_name}.${date_tag}.nc $DIN_LOC_ROOT/share/domains/
```

### topography

The topography file was generated using the NCAR topography toolchain [Lauritzen2015], with tensor hyperviscosity enabled for the RRM grid. V3 topography tool chain was used in WPRRM codebase (<https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/2712338924/V3+Topography+GLL+PG2+grids>).

`../scripts/grid_WL.03.topo_v3_demo_WP10ne32x32v1.sh`

```bash
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
#       LDFLAGS += $(USER_LDFLAGS)
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
!smooth_phis_numcycle = 12              !for 16xdel2
!hypervis_order = 2                     !for 16xdel2
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
# --- Step 5: ncks: Append the GLL phi_s data to the output of step 4.   !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
cd /p/lustre2/zhang73/grids2/${RRMgrid}/
source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh

ncks -A ${RRMgrid}np4_smoothed_phis_x6t1.nc GTOPO30_${RRMgrid}np4pg2_x6t.nc

rsync -av GTOPO30_${RRMgrid}np4pg2_x6t.nc $DIN_LOC_ROOT/atm/cam/topo/
exit 1
fi 
```

### land surface data

Two steps are needed to generate land surface data (`fsurdat`):
- preparation for the land surface data (`grid_WL.fsurdat_0102.mkmapdata_mksurfdata_pl_map_demo_WP10ne32x32v1.sh`)
- generate mapping files for each land surface input data file to input grid files (mkmapdata.sh)
- build `mksurfdata_map` tool
- generate namelist using `mksurfdata.pl`, and modify it (if needed)

- create the land surface data by `mksurfdata_map` (`grid_WL.fsurdat_02.mksurfdata_map_namelist.bash`)

Beside the land surface data, the land use file (`flanduse_timeseries`) is also needed for a grid-specified compset in multi-year simulations. The additional steps are:
- create a LUT (Land Use Translator) file list
- assign the `mksrf_fdynuse` to the LUT list in surfdata_map's namelist
- assign the `fdyndat` to the name of the land use file you want to create

`../scripts/grid_WL.04.fsurdat_0102.mkmapdata_mksurfdata_pl_map_demo_WP10ne32x32v1.sh`

```bash
#!/bin/sh

RRMgrid=WP10ne32x32v1
#---use the up-to-date elm tool, and revert the toprad commits to avoid `the map_0.01x0.01 does not found error'
e3sm_root=/p/lustre2/zhang73/GitTmp/E3SM_tool_250318  
grids2=/p/lustre2/zhang73/grids2/
GRIDFILE=${grids2}/${RRMgrid}/${RRMgrid}pg2_scrip.nc
INPUTDATA_ROOT=$DIN_LOC_ROOT
date_tag=$(date +"%Y%m%d")
year_fsurdat=2015
# rcp_tag=""
rcp_level=8.5
rcp_tag="-rcp ${rcp_level}"

do_step="step1_mkmapdata"
do_step="step3_build_mksurfdata_map"
do_step="step3_gen_mksurfdata_pl"
do_step="step4_run_mksurfdata_map"

use_multiN=false #only needed for map_1km-merge-10min_HYDRO1K-merge-nomask

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step1_mkmapdata" ];then
cd ${e3sm_root}/components/elm/tools/mkmapdata

echo '--- ESMFBIN_PATH start mkmapdata_sbatch.sh ---' 
#--- use esmf-mpi from unified env ---
export ESMFBIN_PATH=/g/g92/zhang73/miniconda3/envs/esmf/bin
export ESMFBIN_PATH=/usr/WS1/e3sm/apps/e3sm-unified/base/envs/e3sm_unified_1.10.0_login/bin
echo $ESMFBIN_PATH
#--- env with ncl and nco
source ~/.bashrc_all_stable 

#--- Speed: WP10ne32x32v1 (WP20ne32x32v1) took 7.5min (<29min) for 1km-merge-10min_HYDRO1K-merge-nomask
export mpiexec="srun --account=focus --time=00:29:00 -p pbatch -N 20" 

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
fi

# -----------------------------------------------------------------------------
if  [ "${do_step}" == "step3_gen_mksurfdata_pl" ];then
cd ${e3sm_root}/components/elm/tools/mksurfdata_map

./mksurfdata.pl -res usrspec -usr_gname ${RRMgrid}pg2 -usr_gdate 250320 -y ${year_fsurdat} ${rcp_tag} -d -dinlc ${INPUTDATA_ROOT} -usr_mapdir ${e3sm_root}/components/elm/tools/mkmapdata

#---modify it manually if needed, e.g., add the landuse.timeseries <mksrf_fdynuse> <fdyndat>
cp namelist namelist_${RRMgrid}pg2_rcp${rcp_level}-${year_fsurdat}
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step2_build_mksurfdata_map" ];then 
cd ${e3sm_root}/components/elm/tools/mksurfdata_map/src

# eval $(${e3sm_root}/cime/CIME/Tools/get_case_env)
${e3sm_root}/cime/CIME/scripts/configure --macros-format Makefile --mpilib mpi-serial
source ${e3sm_root}/components/elm/tools/mksurfdata_map/src/.env_mach_specific.sh

INC_NETCDF="`nf-config --includedir`" \
    LIB_NETCDF="`nc-config --libdir`" USER_FC="`nc-config --fc`" \
    USER_LDFLAGS="`nc-config --libs` `nf-config --flibs` -Wl,-rpath,${NETCDF_C_PATH}/lib -Wl,-rpath,${NETCDF_FORTRAN_PATH}/lib" make  
exit 1
fi

# -----------------------------------------------------------------------------
if [ "${do_step}" == "step4_run_mksurfdata_map" ];then 
cd ${e3sm_root}/components/elm/tools/mksurfdata_map

source ${e3sm_root}/components/elm/tools/mksurfdata_map/src/.env_mach_specific.sh
./mksurfdata_map < namelist_${RRMgrid}pg2_rcp${rcp_level}-${year_fsurdat}

mv surfdata_${RRMgrid}pg2_rcp8.5_simyr2015_${date_tag}.nc  landuse.timeseries_${RRMgrid}pg2_rcp8.5_simyr2015-2100_${date_tag}.nc  ${grids2}/${RRMgrid}/
rsync -av ${grids2}/${RRMgrid}/surfdata_${RRMgrid}pg2_rcp8.5_simyr2015_${date_tag}.nc  landuse.timeseries_${RRMgrid}pg2_rcp8.5_simyr2015-2100_${date_tag}.nc  $DIN_LOC_ROOT/lnd/clm2/surfdata_map/
fi
```

### dry deposition

`../scripts/grid_WL.05.mkatmsrffile_demo_WP10ne32x32v1.sh`

```bash
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
#       INC = -I$(shell nf-config --includedir)
#       LIB = -L$(shell nc-config --libdir) -lnetcdf -lnetcdff 
#       LIB += $(USER_LDFLAGS)
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

rsync -av ${grids2}/${RRMgrid}/atmsrf_${RRMgrid}pg2_${date_tag}.nc  $DIN_LOC_ROOT/atm/cam/chem/trop_mam/
fi
```

## Initial conditions

### atmosphere IC

The atmosphere IC was generated with the HICCUP package (<https://github.com/E3SM-Project/HICCUP>), which has a built-in download of ERA5 pressure level data, a call to NCO's vertical interpolation algorithm (<https://nco.sourceforge.net/nco.html>), a call to TempestRemap horizontal interpolation algorithm (<https://github.com/ClimateGlobalChange/tempestremap>), and a procedure for adjusting surface temperature and pressure with topography following the ECMWF practice [Trenberth1993].

A good step-by-step tutorial can be found here: <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/1002373272/Generate+atm+initial+condition+from+analysis+data>. The readers are suggested to learn the HICCUP tool (<https://github.com/E3SM-Project/HICCUP>) and the relevant references for a better sense.

Optionally, one can manually generate the mapping files for np4 (IC) and pg2 (nudging) -> ERA5 0.25 deg and pass them to the HICCP run scripts (`hiccup_data.map_file`):

```bash
ncremap -a fv2se_stt --grd_src=/pscratch/sd/z/zhang73/DATA/data_hiccup/ERA5_721x1440_scrip.20220907.nc --grd_dst=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1.g --map=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/map_ERA5_721x1440_to_WP10ne32x32v1np4.TRhighorder.20250322.nc
ncremap -a fv2fv_mono --grd_src=/pscratch/sd/z/zhang73/DATA/data_hiccup/ERA5_721x1440_scrip.20220907.nc --grd_dst=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1pg2_scrip.nc --map=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/map_ERA5_721x1440_to_WP10ne32x32v1pg2.TRaave.20250322.nc
```

We did not need to spin up the atmosphere and to adjust the hyperviscosity additionally. The hyperviscosity timestep for dynamics were set to the default value inferred by the scaling factor from the coarse resolution to RRM.

HICCUP scripts for atm ICs:

```bash
../scripts/HICCUP_fork/get_hindcast_data.ERA5*
../scripts/HICCUP_fork/template_hiccup_scripts/create_EAMxx_IC_from_ERA5.2014-10-01_L128_WP10ne32x32v1.py
../scripts/HICCUP_fork/template_hiccup_scripts/create_EAMxx_IC_from_ERA5.2014-10-01_L128_WP20ne32x32v1.py
```

### land IC

#### climotology simulation

For the climate-length simulations, we can directly use a land IC (e.g., v1 DECK) interpolated from a well-spunup run. Thus, we only need:
- `source_inic_file` (a land restart file from a balanced run to get the balanced land condition)
- `target_inic_file` (a land restart file from the new grid run to get the grid info)

`../scripts/grid_WL.06.finidat.IELM_interpinic.demo_E3SMv1toRRM_WP10ne32x32v1.sh`

```bash
#!/bin/bash

RRMgrid=WP20ne32x32v1
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
```

#### hindcast

Since the WPRRMs include little land areas, and we're using wind UVTQ nudging, we didn't use a spunup land for hindcasts.

If a spinup land initial conditional is needed, one can follow the Beijing RRM workflow: "We spinned up the land using 5-yr ERA5 under the *IELM-type* compset (i.e., *DATM*). The variables include 6-hourly 2-meter temperature, precipitation, 2-meter specific humidity, longwave radition (up) and shortwave radiation (down) at the surface. For the pseudo-global-warming (PGW) simulations, we used deltas from CESM LENS ensemble. "

The main reference is the betacast package's land-spinup part: <https://github.com/zarzycki/betacast/tree/master/land-spinup>. Readers are also suggested to follow <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/872579110/Running+E3SM+on+New+Grids#8.-Generate-a-new-land-initial-condition-(finidat)> and <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/3107586055/Generating+land+model+initial+conditions>. A good reference for RRM land IC generation can be found at Weiran's documentation: <https://acme-climate.atlassian.net/wiki/spaces/NGDNA/pages/3556147426/CONUS+RRM+New+Grid+Generation+Process>.

Specifically:
- use `../scripts/betacast_fork/land-spinup/gen_datm/get-era5/driver-get-era5.sh` to download ERA5 near-surface variables (precipitation, shortwave down at surface, longwave up at surface, 2-m T Q, 10-m winds, surface pressure etc.) used to drive I-compsets
- use `../scripts/betacast_fork/land-spinup/gen_datm/gen-datm/gen-forcing.ncl` to re-format the ERA5 atm forcing data to *DATM* format
- prepare `user_datm.streams.txt.*` (path & filename of stream files of DATM)
- add `user_nl_datm` in `runscript_IELM_core.sh`
- use `finidat_interpinic` tool to interpolate a spinned-up restart file from a historcial run to a temporary `finidat` on the RRM grid (same step as in the climotology simulation)
- add the interpolated `finidat` in `user_nl_elm` for the *IELM-type* run
- The additonal steps for PGW: get deltas from CESM LENS on perlmutter:</global/cfs/cdirs/m2637/betacast/deltas/CESMLENS_mlev/ens_T/Q/PRECC/PRECL_anom.nc>, and prepare `user_datm.streams.txt.Anomaly.*`

`runscript_IELM_core.sh`

```bash
cat << EOF >> user_nl_elm
 check_finidat_year_consistency = .false.
 check_dynpft_consistency = .false.
 check_finidat_fsurdat_consistency = .false.
 check_finidat_pct_consistency = .false.
 fsurdat = '/p/lustre2/zhang73/grids2/BJne128x4x32v5/surfdata_BJne128x4x32v5pg2_rcy8.5_simyr2015_c230921.nc'
 finidat = '/p/lustre2/zhang73/grids2/finidat_interpinic/BJne128x4x32v5np4pg2_hist.elm.r.2015-01-01-00000.nc'
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
```

The runscript for a Beijing RRM IELM simulation can be found at:

`../scripts/runscripts/BJ3km-IELM-6hERA5-s20230729-anomoly-dt1800s.20230904.CArrmS8.amip.nudge.ruby.sh`

## Model configurations (CIME xml)

A series of CIME xml files need to be modified/created to support the new RRM grid and the specific compset required for the simulation. The first part is related to the *grid*. The second part is mainly related to the *compset* (partially subject to common requirements of grid and compset). The RRM related XML list can be found here: <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/872579110/Running+E3SM+on+New+Grids>.

The CIME xml files related to WPRRM are listed as follows:
{
.1 grid.
.2 cime_config/config_grids.xml.
.2 components/eam/bld/config_files/horiz_grid.xml.
.2 driver-mct/cime_config/config_component_e3sm.xml.
.2 components/eamxx/cime_config/namelist_defaults_eamxx.xml.
.2 components/eam/bld/namelist_files/namelist_defaults_eam.xml.
.2 components/elm/bld/namelist_files/namelist_definition.xml.
.1 grid & compset.
.2 components/elm/bld/namelist_files/namelist_defaults.xml.
}

Note that for EAMxx: 1) dont need to add `ncdata` in `components/eam/bld/namelist_files/namelist_defaults_eam.xml`, 2) dont need to add landuse as the `2010_defscream_control` compset set the `sim_year_range` to be constant.

We directly use the `F2010-SCREAMv1` compset. So, only the grid-related XML changes are documented here.

### Prepare E3SM codebase for simulations

```bash
git clone git@github.com:E3SM-Project/E3SM.git WPRRMxx
git remote add fork git@github.com:jsbamboo/E3SM.git
git checkout -b jzhang/WPRRMxx
git submodule update --init --recursive; git submodule sync --recursive; git submodule update --recursive
# After modify all xml
git add .
git commit -m "set WP10ne32x32v1 and WP20ne32x32v1 grids for eamxx"
git checkout -b jzhang/WPRRMxx_p3-extra-diags
git fetch origin 
# Merge p3-extra-diags branch
git merge origin/aarondonahue/eamxx/mahf708/p3-extra-diags 
```

### grid

- Specify the grid-related files in EAMxx's namelist:
- `Filename` (full pathname of initial atmospheric state dataset in NetCDF format)
- `spa_remap_file` (mapping file for SPA scheme)
- `topography_filename` (full pathname of time-invariant boundary dataset for topography fields)
- `mesh_file` (exodus format grid file used when `se_ne`=0, i.e., RRM grids)

- Specify the grid-related files in eam's namelist:
- `drydep_srf_file` (dry deposition surface values interpolated to model grid, required for unstructured atmospheric grids with modal chemistry)
- `bnd_topo`, same as `topography_filename` in EAMxx nl
- `mesh_file`, same as in EAMxx nl

- Set the parameters related to the stability of the model in EAMxx's namelist:
- `rad_frequency` (rad timestep, specified as number of atm steps)
- `number_of_subcycles` (how many times to subcycle this atm process)

- Set the parameters related to the stability of the model in both EAMxx's and eam's namelists:
- `nu_top` (second-order viscosity applied only near the model top [m2/s]), set to follow the the finest resolution grid
- `se_tstep` (dynamics timesteps)
- `dt_tracer_factor` (the tracer advection timestep is `dt_tracer_factor*se_tstep`, where `se_tstep` is the dynamics timesteps)
- `hypervis_subcycle_q` (number of hyperviscosity subcycles done in tracer advection code)
- `hv_ref_profiles` (Modifications to hyperviscosity to minimize dissipation of background reference states)
- `pgrad_correction` (Turn on use of balanced geopotential state to reduce pressure gradient discretization error)

`cime_config/config_grids.xml`

```bash
    <model_grid alias="WP10ne32x32v1pg2_WP10ne32x32v1pg2">
      <grid name="atm">ne0np4_WP10ne32x32v1.pg2</grid>
      <grid name="lnd">ne0np4_WP10ne32x32v1.pg2</grid>
      <grid name="ocnice">ne0np4_WP10ne32x32v1.pg2</grid>
      <grid name="rof">r0125</grid>
      <grid name="glc">null</grid>
      <grid name="wav">null</grid>
      <mask>oRRS18to6v3</mask>
    </model_grid>

    <model_grid alias="WP20ne32x32v1pg2_WP20ne32x32v1pg2">
      <grid name="atm">ne0np4_WP20ne32x32v1.pg2</grid>
      <grid name="lnd">ne0np4_WP20ne32x32v1.pg2</grid>
      <grid name="ocnice">ne0np4_WP20ne32x32v1.pg2</grid>
      <grid name="rof">r0125</grid>
      <grid name="glc">null</grid>
      <grid name="wav">null</grid>
      <mask>oRRS18to6v3</mask>
    </model_grid>

    <domain name="ne0np4_WP10ne32x32v1.pg2">
      <nx>96240</nx>
      <ny>1</ny>
      <file grid="atm|lnd" mask="oRRS18to6v3">$DIN_LOC_ROOT/share/domains/domain.lnd.WP10ne32x32v1pg2_oRRS18to6v3.250318.nc</file>
      <file grid="ice|ocn" mask="oRRS18to6v3">$DIN_LOC_ROOT/share/domains/domain.ocn.WP10ne32x32v1pg2_oRRS18to6v3.250318.nc</file>
      <desc>1-deg with 10 deg x 10 deg 3 km over Western Pacific version 1 pg2:</desc>
    </domain>

    <domain name="ne0np4_WP20ne32x32v1.pg2">
      <nx>267792</nx>
      <ny>1</ny>
      <file grid="atm|lnd" mask="oRRS18to6v3">$DIN_LOC_ROOT/share/domains/domain.lnd.WP20ne32x32v1pg2_oRRS18to6v3.250318.nc</file>
      <file grid="ice|ocn" mask="oRRS18to6v3">$DIN_LOC_ROOT/share/domains/domain.ocn.WP20ne32x32v1pg2_oRRS18to6v3.250318.nc</file>
      <desc>1-deg with 20 deg x 20 deg 3 km over Western Pacific version 1 pg2:</desc>
    </domain>

    <gridmap atm_grid="ne0np4_WP10ne32x32v1.pg2" rof_grid="r0125">
     <map name="ATM2ROF_FMAPNAME">cpl/gridmaps/WP10ne32x32v1pg2/map_WP10ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="ATM2ROF_SMAPNAME">cpl/gridmaps/WP10ne32x32v1pg2/map_WP10ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="LND2ROF_FMAPNAME">cpl/gridmaps/WP10ne32x32v1pg2/map_WP10ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="ROF2LND_FMAPNAME">cpl/gridmaps/WP10ne32x32v1pg2/map_r0125_to_WP10ne32x32v1pg2.TRaave.20250318.nc</map>
    </gridmap>

    <gridmap atm_grid="ne0np4_WP20ne32x32v1.pg2" rof_grid="r0125">
     <map name="ATM2ROF_FMAPNAME">cpl/gridmaps/WP20ne32x32v1pg2/map_WP20ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="ATM2ROF_SMAPNAME">cpl/gridmaps/WP20ne32x32v1pg2/map_WP20ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="LND2ROF_FMAPNAME">cpl/gridmaps/WP20ne32x32v1pg2/map_WP20ne32x32v1pg2_to_r0125.TRaave.20250318.nc</map>
     <map name="ROF2LND_FMAPNAME">cpl/gridmaps/WP20ne32x32v1pg2/map_r0125_to_WP20ne32x32v1pg2.TRaave.20250318.nc</map>
    </gridmap>
```

`components/eam/bld/config_files/horiz_grid.xml`

```bash
<horiz_grid dyn="se" hgrid="ne0np4_WP10ne32x32v1"             ncol="216542" csne="0" csnp="4" npg="0" />
<horiz_grid dyn="se" hgrid="ne0np4_WP10ne32x32v1.pg2"         ncol="96240"  csne="0" csnp="4" npg="2" />
<horiz_grid dyn="se" hgrid="ne0np4_WP20ne32x32v1"             ncol="602534" csne="0" csnp="4" npg="0" />
<horiz_grid dyn="se" hgrid="ne0np4_WP20ne32x32v1.pg2"         ncol="267792" csne="0" csnp="4" npg="2" />
```

`components/eam/bld/namelist_files/namelist_defaults_eam.xml`

```bash
<bnd_topo hgrid="ne0np4_WP10ne32x32v1"  >atm/cam/topo/GTOPO30_WP10ne32x32v1np4pg2_x6t.nc</bnd_topo>
<bnd_topo hgrid="ne0np4_WP20ne32x32v1"  >atm/cam/topo/GTOPO30_WP20ne32x32v1np4pg2_x6t.nc</bnd_topo>
<drydep_srf_file hgrid="ne0np4_WP10ne32x32v1">atm/cam/chem/trop_mam/atmsrf_WP10ne32x32v1pg2_20250321.nc</drydep_srf_file>
<drydep_srf_file hgrid="ne0np4_WP20ne32x32v1">atm/cam/chem/trop_mam/atmsrf_WP20ne32x32v1pg2_20250321.nc</drydep_srf_file>
<se_ne hgrid="ne0np4_WP10ne32x32v1"> 0 </se_ne>
<se_ne hgrid="ne0np4_WP20ne32x32v1"> 0 </se_ne>
<mesh_file hgrid="ne0np4_WP10ne32x32v1"  >atm/cam/inic/homme/WP10ne32x32v1.g</mesh_file>
<mesh_file hgrid="ne0np4_WP20ne32x32v1"  >atm/cam/inic/homme/WP20ne32x32v1.g</mesh_file>
<nu_top dyn_target="theta-l" hgrid="ne0np4_WP10ne32x32v1"> 1e4 </nu_top>
<nu_top dyn_target="theta-l" hgrid="ne0np4_WP20ne32x32v1"> 1e4 </nu_top>
<se_tstep            dyn_target="theta-l" hgrid="ne0np4_WP10ne32x32v1"> 8.333333333333333d0 </se_tstep>
<dt_tracer_factor    dyn_target="theta-l" hgrid="ne0np4_WP10ne32x32v1"> 6 </dt_tracer_factor>
<hypervis_subcycle_q dyn_target="theta-l" hgrid="ne0np4_WP10ne32x32v1"> 6 </hypervis_subcycle_q>
<se_tstep            dyn_target="theta-l" hgrid="ne0np4_WP20ne32x32v1"> 8.333333333333333d0 </se_tstep>
<dt_tracer_factor    dyn_target="theta-l" hgrid="ne0np4_WP20ne32x32v1"> 6 </dt_tracer_factor>
<hypervis_subcycle_q dyn_target="theta-l" hgrid="ne0np4_WP20ne32x32v1"> 6 </hypervis_subcycle_q>
```

`components/eamxx/cime_config/namelist_defaults_eamxx.xml`

```bash
      <spa_remap_file hgrid="ne0np4_WP10ne32x32v1">${DIN_LOC_ROOT}/atm/scream/maps/map_ne30np4_to_WP10ne32x32v1pg2.intbilin.20250318.nc</spa_remap_file>
      <spa_remap_file hgrid="ne0np4_WP20ne32x32v1">${DIN_LOC_ROOT}/atm/scream/maps/map_ne30np4_to_WP20ne32x32v1pg2.intbilin.20250318.nc</spa_remap_file>
      <rad_frequency hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">3</rad_frequency>
      <number_of_subcycles hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">1</number_of_subcycles>
    <Filename hgrid="ne0np4_WP10ne32x32v1" nlev="128">${DIN_LOC_ROOT}/atm/scream/init/HICCUP.atm_era5.2014-10-01.highorder_WP10ne32x32v1.L128.nc</Filename>
    <Filename hgrid="ne0np4_WP20ne32x32v1" nlev="128">${DIN_LOC_ROOT}/atm/scream/init/HICCUP.atm_era5.2014-10-01.highorder_WP20ne32x32v1.L128.nc</Filename>
    <topography_filename hgrid="ne0np4_WP10ne32x32v1">${DIN_LOC_ROOT}/atm/cam/topo/GTOPO30_WP10ne32x32v1np4pg2_x6t.nc</topography_filename>
    <topography_filename hgrid="ne0np4_WP20ne32x32v1">${DIN_LOC_ROOT}/atm/cam/topo/GTOPO30_WP20ne32x32v1np4pg2_x6t.nc</topography_filename>
    <nc hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">0.0</nc>
    <ni hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">0.0</ni>
    <hv_ref_profiles hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">0</hv_ref_profiles>
    <nu_top hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">1.0e4</nu_top>
    <pgrad_correction hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">0</pgrad_correction>
    <se_ne hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1">0</se_ne>
    <se_tstep hgrid="ne0np4_WP10ne32x32v1|ne0np4_WP20ne32x32v1" constraints="gt 0">8.3333333333333</se_tstep>
    <mesh_file hgrid="ne0np4_WP10ne32x32v1">${DIN_LOC_ROOT}/atm/cam/inic/homme/WP10ne32x32v1.g</mesh_file>
    <mesh_file hgrid="ne0np4_WP20ne32x32v1">${DIN_LOC_ROOT}/atm/cam/inic/homme/WP20ne32x32v1.g</mesh_file>
```

`components/elm/bld/namelist_files/namelist_definition.xml`

```bash
<entry id="res" type="char*30" category="default_settings"
       group="default_settings"
       valid_values=
"...,ne0np4_WP10ne32x32v1.pg2,ne0np4_WP20ne32x32v1.pg2,...">
Horizontal resolutions
```

`components/elm/bld/namelist_files/namelist_defaults.xml`

```bash
<fsurdat hgrid="ne0np4_WP10ne32x32v1.pg2"   sim_year="2010" use_crop=".false." >
lnd/clm2/surfdata_map/surfdata_WP10ne32x32v1pg2_rcp8.5_simyr2015_c250320.nc</fsurdat>
<fsurdat hgrid="ne0np4_WP20ne32x32v1.pg2"   sim_year="2010" use_crop=".false." >
lnd/clm2/surfdata_map/surfdata_WP20ne32x32v1pg2_rcp8.5_simyr2015_c250320.nc</fsurdat>
```

`driver-mct/cime_config/config_component_e3sm.xml`

```bash
  <entry id="ATM_NCPL">
    <type>integer</type>
    <default_value>48</default_value>
    <values match="last">
      ...
      <value compset=".+" grid="a%ne0np4_WP10ne32x32v1">864</value>
      <value compset=".+" grid="a%ne0np4_WP20ne32x32v1">864</value>
```

### compset

Simply use the `F2010-SCREAMv1` compset.

## Boundary conditions

### create lower BL (SST, ice cover)

Sea surface temperature (SST) and ice cover were obtained from the same coupled simulation as lower boundary conditions to drive Data Ocean (*PRES_DOCN*) and Prescribed CICE (*SPBC_CICE*) as a streamfile.

#### climotology simulation

The e3sm_to_cmip tool (<https://github.com/E3SM-Project/e3sm_to_cmip>) was used to get 1° lat-lon timeseries which was further processed by NCL to meet the format of the Data Ocean streamfile (<https://esmci.github.io/cime/versions/ufs_release_v1.1/html/data_models/data-ocean.html>):
- use e3sm_to_cmip to transfer the MPAS SST ("timeMonthly_avg_activeTracers_temperature") and ice cov ("timeMonthly_avg_iceAreaCell") to the CMOR formatted (lat-lon, renaming) vars "tos" and "siconc", respectively
- use `poisson_grid_fill` function in NCL to fill missing values over land, replace missing values of ice cover by 0, and add date & datesec variables in streamfile

The e3sm_to_cmip step can be found at:

`../scripts/grid_WL.sst_EAM.0.e3sm_to_cmip_tos_siconc.rerun-12212023.sh`
Note that the reformatting step is called in this script in the "do_ncl" step.

```bash
#!/bin/bash

cd /p/lustre2/zhang73/PCMDI/e3sm_to_cmip
source ~/.bashrc_e3sm_to_cmip_dev

caseid='3hI-UVTQ-s2015_2.20190807.DECKv1b_P1_SSP5-8.5.ne30_oEC.ruby.1344'
grp_tag='12212023'
start_year=2015
# end_year=2099
end_year=2100
rerun_tag='12212023'
cdate='240422'
vdate='20'${cdate}
# vdate=`date +'%Y%m%d'`
compset='ssp585'

drc_g=/p/lustre2/zhang73/${grp_tag}/
drc_data=${drc_g}/data/
drc_stream=/p/lustre2/zhang73/DATA/data_streamfile/
indir_head_ocn='archive/ocn/hist'
indir_head_ice='archive/ice/hist'
# indir_head_ocn='run'
# indir_head_ice='run'
if ! test -d ${drc_data}; then mkdir -p ${drc_data}; fi

#----------------------------------------------------------------------------------------------------------------
do_e3sm_to_cmip=true
do_ncl=true

if $do_e3sm_to_cmip; then
#-----------part 1: e3sm_to_cmip
# * find moc file: vi ${drc_g}/${caseid}/case_scripts/Buildconf/mpaso.input_data_list, copy it to ${drc_g}/${caseid}/run/
if [ -f "${drc_g}/${caseid}/${indir_head_ocn}/oEC60to30v3_Atlantic_region_and_southern_transect.nc" ]; then
    echo 'moc file has been in input_dir'
else
    cp /usr/gdata/climdat/ccsm3data/inputdata/ocn/mpas-o/oEC60to30v3/oEC60to30v3_Atlantic_region_and_southern_transect.nc ${drc_g}/${caseid}/${indir_head_ocn}/
    echo ' >>> Done. cp moc file'
fi

# * copy mpas_mesh to input directory: if input_dir is /archive/ocn/hist/
cp ${drc_g}/${caseid}/archive/rest/2016-01-01-00000/mpaso.rst.2016-01-01_00000.nc ${drc_g}/${caseid}/${indir_head_ocn}/
cp ${drc_g}/${caseid}/archive/rest/2016-01-01-00000/mpaso.rst.2016-01-01_00000.nc ${drc_g}/${caseid}/${indir_head_ice}/

e3sm_to_cmip  -s  --realm mpaso  \
          -v tos  --tables-path /p/lustre2/zhang73/PCMDI/cmip6-cmor-tables/Tables/  \
          --user-metadata /p/lustre2/zhang73/PCMDI/e3sm_to_cmip/e3sm_to_cmip/resources/default_metadata.json \
          --map /p/lustre2/zhang73/PCMDI/map_oEC60to30v3_to_cmip6_180x360_aave.20181001.nc \
          --output ${drc_data}/${caseid}/ \
          --input ${drc_g}/${caseid}/${indir_head_ocn}/
echo ' >>> Done. e3sm_to_cmip tos'

e3sm_to_cmip  -s  --realm mpassi  \
              -v siconc  --tables-path /p/lustre2/zhang73/PCMDI/cmip6-cmor-tables/Tables/  \
              --user-metadata /p/lustre2/zhang73/PCMDI/e3sm_to_cmip/e3sm_to_cmip/resources/default_metadata.json \
              --map /p/lustre2/zhang73/PCMDI/map_oEC60to30v3_to_cmip6_180x360_aave.20181001.nc \
              --output ${drc_data}/${caseid}/ \
              --input ${drc_g}/${caseid}/${indir_head_ice}/
echo ' >>> Done. e3sm_to_cmip siconc'

cp ${drc_data}/${caseid}/CMIP6/CMIP/E3SM-Project/E3SM-1-0/piControl/r1i1p1f1/SImon/siconc/gr/v${vdate}/siconc_SImon_E3SM-1-0_piControl_r1i1p1f1_gr_*.nc ${drc_stream}/siconc_SImon_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}.nc
cp ${drc_data}/${caseid}/CMIP6/CMIP/E3SM-Project/E3SM-1-0/piControl/r1i1p1f1/Omon/tos/gr/v${vdate}/tos_Omon_E3SM-1-0_piControl_r1i1p1f1_gr_*.nc ${drc_stream}/tos_Omon_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}.nc
echo ' >>> Done. cp tos & siconc out from e3sm_to_cmip to drc_stream'
fi 

if $do_ncl; then
#-----------part 2: ncl
source ~/.bashrc_all_stable
cd /g/g92/zhang73/test/zhang73_scripts/

cp grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_rerun_gr_2015-2100_fillmsg.ncl grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_fillmsg_c${cdate}.ncl 
sed -i "s/rerun/${rerun_tag}/g" grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_fillmsg_c${cdate}.ncl
sed -i "s/2100/${end_year}/g" grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_fillmsg_c${cdate}.ncl
sed -i "s/c221031/c${cdate}/g" grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_fillmsg_c${cdate}.ncl
echo ' >>> Done. vi grid_WL.DOCN.make_sst.ncl'

ncl grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_fillmsg_c${cdate}.ncl
#ncdump -h /p/lustre2/zhang73/DATA/data_streamfile/sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_c${cdate}.nc > out_ncdump_grid_WL.DOCN.make_sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_c${cdate}.sh
echo ' >>> Done. ncl grid_WL.DOCN.make_sst.ncl'
fi
exit 1

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!                               after 2056                                    !!! 
# !!! copy & rename to sst_E3SM-1-0_${compset}_r1i1p1f1_rerun_gr_2015-2100_c221031.nc !!!
# cp /p/lustre2/zhang73/DATA/data_streamfile/sst_E3SM-1-0_${compset}_r1i1p1f1_${rerun_tag}_gr_${start_year}-${end_year}_c${cdate}.nc /usr/gdata/climdat/ccsm3data/inputdata/atm/cam/sst/sst_E3SM-1-0_${compset}_r1i1p1f1_rerun_gr_2015-2100_c221031.nc
```

`../scripts/grid_WL.sst_EAM.1.fmt-streamfile.sst_E3SM-1-0_ssp585_r1i1p1f1_rerun_gr_2015-2100_fillmsg.ncl`

```bash
begin

exp_name="E3SM-1-0_ssp585_r1i1p1f1_rerun_gr_2015-2100"
date_make="c221031"
;======================================================================

dir="/p/lustre2/zhang73/DATA/data_streamfile/"
filename_ref="sst_HadOIBl_bc_1x1_1850_2012_c130411.nc"
filename_sst="tos_Omon_"+exp_name+".nc"
filename_ice="siconc_SImon_"+exp_name+".nc"

f0=addfile(dir+filename_ref,"r")
f1=addfile(dir+filename_sst,"r")
f2=addfile(dir+filename_ice,"r")

sst_ref=f0->SST_cpl(0:1,:,:)
ice_ref=f0->ice_cov(0:1,:,:)
time_ref=f0->time
lat = f0->lat
lon = f0->lon
date_ref=f0->date
datesec_ref=f0->datesec
printVarSummary(sst_ref)
printVarSummary(ice_ref)
print(time_ref(0:0+3)+", "+date_ref(0:0+3)+", "+datesec_ref(0:0+3))

sst_in=f1->tos
ice_in=f2->siconc
time_in=f1->time
printVarSummary(sst_in)
printVarSummary(ice_in)
printVarSummary(time_in)

print("----- poisson_grid_fill start -----")
sst_fill = sst_in
print("min,avg,max of sst_fill 0: "+min(sst_fill)+", "+avg(sst_fill)+", "+max(sst_fill))
poisson_grid_fill(sst_fill, True, 1, 1500, 1e-2, 0.6, 0)
printVarSummary(sst_fill)
print("min,avg,max of sst_fill 1: "+min(sst_fill)+", "+avg(sst_fill)+", "+max(sst_fill))
sst_in := sst_fill
print("----- poisson_grid_fill end -----")
; exit 

sst=where(ismissing(sst_in),-1.8,sst_in)
ice_cov=ice_in/100.
ice_cov=where(ismissing(ice_cov),0,ice_cov) ;!!!! last-year here is missing -> 1

time=time_in-(735125.5-15.5) ;let the first time to be mid-month in year 0: 15.5
time@units="days since 2015-01-01 00:00:00"
time@calendar = "365_day"
time!0="time"
time&time=time
;delete_VarAtts(time,(/"bounds","axis","long_name","standard_name"/))

date=(/cd_calendar(time,-2)/)
date@long_name = "current date (YYYYMMDD)"

YYMMDDHH=cd_calendar(time,-3)
HH=toint(str_get_cols(YYMMDDHH,-2,-1))
datesec=HH*3600
datesec@long_name = "current seconds of current date"

date   !0="time"  
datesec!0="time"
date   &time=time   
datesec&time=time  
printVarSummary(date    )   
printVarSummary(datesec ) 
printVarSummary(time    ) 
printVarSummary(lat     ) 
printVarSummary(lon   )

print(time(0:12)+", "+date(0:12)+", "+datesec(0:12)+","+YYMMDDHH(0:12)+"  vs. "+time_ref(0:12)+", "+date_ref(0:12)+", "+datesec_ref(0:12))
print("-------------------------------")
;exit

sst    !0="time"
ice_cov!0="time"
sst    &time=time  
ice_cov&time=time  
sst    !1="lat"
sst    !2="lon"
sst    &lat=lat  
sst    &lon=lon  
ice_cov!1="lat"
ice_cov!2="lon"
ice_cov&lat=lat  
ice_cov&lon=lon  

filo="sst_"+exp_name+"_"+date_make+".nc"
system("/bin/rm -f " + dir+filo)
fout=addfile(dir+filo,"c")
dimNames=(/"time","lat","lon"/)
dimSizes=(/-1,180,360/)
dimUnlim=(/True,False,False/)
filedimdef(fout,dimNames,dimSizes,dimUnlim)

nl = integertochar(10)
globalAtt=True
globalAtt@history = nl+\
      systemfunc("date") + ": ncl < /g/g92/zhang73/test/zhang73_scripts/make_sst_"+exp_name+"_"+date_make+".ncl"
fileattdef(fout, globalAtt)

copy_VarAtts(sst_in,sst)
copy_VarAtts(ice_in,ice_cov)
ice_cov@units="fraction"
delete_VarAtts(sst    ,(/"_FillValue", "missing_value","history"/))
delete_VarAtts(ice_cov,(/"_FillValue", "missing_value","history"/))
printVarSummary(sst     ) 
printVarSummary(ice_cov ) 
;exit
printMinMax(sst,0)
printMinMax(sst_ref,0)
printMinMax(ice_cov,0)
printMinMax(ice_ref,0)
print(num(abs(ice_ref).gt.1))
print(num(.not.ismissing(ice_ref)))

fout->date   = date    
fout->datesec= datesec 
fout->lat    = lat     
fout->lon    = lon    
fout->time   = time    
fout->SST_cpl= sst     
fout->ice_cov= ice_cov 

end
```

#### hindcast

The steps to download and process the NOAA SSTICE data:
- use HICCUP to download NOAA SST and sea ice
- use `poisson_grid_fill` function in NCL to fill missing values over land
- replace missing values of ice cover by 0, and add date & datesec variables in streamfile

Note that the second and third steps are essentially the same as the second step in the climatology simulation workflow. However, I’ve split them into two separate steps, as I generally use 1° SST and ice coverage for the DOCN and CICE simulations. Therefore, an additional regridding step from 0.25° to 1° is included in the third step. This is purely a user preference. The Poisson relaxation method is also widely used by other tools.

The corresponding scripts can be found at:

`../scripts/HICCUP_fork/get_hindcast_data.NOAA_SSTICE.py`

`../scripts/grid_WL.sst_NOAA.0.fillmsg.ncl`

`../scripts/grid_WL.sst_NOAA.1.fmt-streamfile.ncl`

### create lateral BL (nudging files)

To constrain the lateral boundary conditions, the nudging capability has been plugged into the E3SM RRM framework. A global wind nudging is used with the nudging coefficient set by 1 over the whole globe and a consistent nudging strength in the vertical direction. A good step-by-step tutorial to use nudging for RRM can be found here: <https://acme-climate.atlassian.net/wiki/spaces/DOC/pages/20153276/How+to+perform+nudging+simulations+with+the+regional+refined+model+RRM>.

To enable the window (regional) nudging in EAMxx, we need to generate a nudging weights file offline and prescrib its full path in the runscript:

```bash
git clone git@github.com:E3SM-Project/eamxx-scripts.git
cd /p/lustre2/zhang73/GitTmp/SourceCode/eamxx-scripts/run_scripts/RRM_example_scripts
cp SCREAMv1_create_nudging_weights.py SCREAMv1_create_nudging_weights_WP10ne32x32v1pg2.py
vi SCREAMv1_create_nudging_weights_WP10ne32x32v1pg2.py # Modify ``USER DEFINED SETTINGS''
python3  SCREAMv1_create_nudging_weights_WP10ne32x32v1pg2.py  -datafile /p/lustre2/zhang73/grids2/WP10ne32x32v1/GTOPO30_WP10ne32x32v1np4pg2_x6t.nc -nlev 128 -lat lat -lon lon -weightsfile /p/lustre2/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1pg2_weighting_file.nc
```

#### climotology simulation

A Bash script was used to regridding the E3SMv1 ne30pg2 UVTQ to the WPRRM grids using NCO:

- make horizontal mapping files from ne30pg2 to the WPRRM pg2 grids:

```bash
ncremap -a se2fv_stt -s /p/lustre2/zhang73/grids2/ne30/ne30_20200209.g -g /p/lustre2/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1pg2_scrip.nc -m /p/lustre2/zhang73/grids2/WP10ne32x32v1/map_ne30np4_to_WP10ne32x32v1pg2.TR_highorder.20250723.nc
ncremap -a se2fv_stt -s /p/lustre2/zhang73/grids2/ne30/ne30_20200209.g -g /p/lustre2/zhang73/grids2/WP20ne32x32v1/WP20ne32x32v1pg2_scrip.nc -m /p/lustre2/zhang73/grids2/WP20ne32x32v1/map_ne30np4_to_WP20ne32x32v1pg2.TR_highorder.20250723.nc
```

- call the vertical and horizontal remapping using NCO

`../scripts/grid_WL.nudging.eamxx.driver.E3SMlowres.WP10ne32x32v1.demo.sh`

```bash
#!/bin/bash

# do_step="v1" #by default run both v0 and v1 steps (v0 is the predecessor of v1)
grp_tag="12212023"
caseid="3hI-UVTQ-s2015_2.20190807.DECKv1b_P1_SSP5-8.5.ne30_oEC.ruby.1344"
drc_in_L=/p/lustre2/zhang73/${grp_tag}/${caseid}/cam.${hx}/${iy_fmt}/ #E3SMv1 ne30 3h UVTQ outputs

nlev_L=72 #E3SM low-res forcing number of vertical levels
nlev_H=128 #SCREAM RRM target number of vertical levels
hx="h4" #the eam.h? tape for U,V,T,Q,PS high frequency outputs used to make the nudging data

#######################################################
# USER NEED TO SPECIFY
RRMgrid="WP10ne32x32v1"
# RRMgrid="WP20ne32x32v1"

start_year=2015
end_year=2015

#---output dir setting
drc_out_vrt=/p/lustre2/zhang73/nudging.UVTQ/demo/${caseid}/L${nlev_H}/
drc_out_v0=/p/lustre2/zhang73/nudging.UVTQ/demo/${caseid}/v0/
drc_out_v1=/p/lustre2/zhang73/nudging.UVTQ/demo/${caseid}/v1/
#######################################################

if ! test -d ${drc_out_vrt}; then mkdir -p ${drc_out_vrt}; fi
if ! test -d ${drc_out_v0}; then mkdir -p ${drc_out_v0}; fi
if ! test -d ${drc_out_v1}; then mkdir -p ${drc_out_v1}; fi

#-----------------------------vrt remapping file----------------------------
vrt_file=/usr/workspace/e3sm/ccsm3data/inputdata/atm/scream/init/vertical_coordinates_L128_20220927.nc

#-----------------------------hori remapping file---------------------------
TR_flag="highorder_se2fv_RRM${grid}pg2"
#TR_flag="highorder_se2fv_WP20ne32x32v1pg2"
if [ $TR_flag == "highorder_se2fv_WP10ne32x32v1pg2" ]; then map_file=/p/lustre2/zhang73/grids2/WP10ne32x32v1/map_ne30np4_to_WP10ne32x32v1pg2.TR_highorder.20250723.nc; fi
if [ $TR_flag == "highorder_se2fv_WP20ne32x32v1pg2" ]; then map_file=/p/lustre2/zhang73/grids2/WP20ne32x32v1/map_ne30np4_to_WP20ne32x32v1pg2.TR_highorder.20250723.nc; fi
echo ${TR_flag}
echo ${map_file}

#-----------------------rename varname from v0 to v1------------------------
var_out_v0=("U" "V" "T" "Q" "PS")
var_out_v1=("U" "V" "T_mid" "qv" "PS")
nvar=${#var_out_v0[@]}

#-----------------------------processing loop-------------------------------
for iy in `seq $start_year 1 $end_year`;do
iy_fmt=`printf %04d $iy`
for im in `seq 10 1 12`;do
for id in `seq 1 1 31`;do
im_fmt=`printf %02d $im`
id_fmt=`printf %02d $id`

time_tag=${iy_fmt}${im_fmt}${id_fmt}
case_t0="${iy_fmt}-${im_fmt}-${id_fmt}-00000"
time_units='hours since '${iy_fmt}-${im_fmt}-${id_fmt}' 00:00:00'

echo "case_t0 = $case_t0"
echo "time_units = $time_units"
echo "time_tag = $time_tag"

# if [[ "${do_step}" = "v0" ]];then 
  echo -e "---- Generating data on ${time_tag} (v0) ---- \n"
  if [ $nlev_H != $nlev_L ];then 
    #---for nlev_H != nlev_L
    ncremap -5 --vrt_fl=${vrt_file} -i ${drc_in_L}/${caseid}.cam.${hx}.${iy_fmt}-${im_fmt}-${id_fmt}-00000.nc -o ${drc_out_vrt}/${caseid}.cam.${hx}.${iy_fmt}-${im_fmt}-${id_fmt}-00000.L${nlev_H}.nc
    ncremap -5 -m ${map_file} -i ${drc_out_vrt}/${caseid}.cam.${hx}.${iy_fmt}-${im_fmt}-${id_fmt}-00000.L${nlev_H}.nc -o ${drc_out_v0}/${hx}.TQUV.${iy_fmt}-${im_fmt}-${id_fmt}.${nlev_H}levs.${TR_flag}.nc
  else 
    #---for nlev_H = nlev_L, so we can skip the vertical interpolation
    ncremap -5 -m ${map_file} -i ${drc_in_L}/${caseid}.cam.${hx}.${iy_fmt}-${im_fmt}-${id_fmt}-00000.nc -o ${drc_out_v0}/${hx}.TQUV.${iy_fmt}-${im_fmt}-${id_fmt}.${nlev_L}levs.${TR_flag}.nc
  fi 
# fi 

#---------------------------------------------------------------------------
# if [[ "${do_step}" = "v1" ]];then 
  echo -e "---- Continue generating data on ${time_tag} (v1) ---- \n"
  if [ $nlev_H != $nlev_L ];then 
    out_fl="${hx}.TQUV.${iy_fmt}-${im_fmt}-${id_fmt}.${nlev_H}levs.${TR_flag}"
  else 
    out_fl="${hx}.TQUV.${iy_fmt}-${im_fmt}-${id_fmt}.${nlev_L}levs.${TR_flag}"
  fi 

  ncpdq -O -a ncol,lev  ${drc_out_v0}/${out_fl}.nc  ${drc_out_v1}/${out_fl}.ncpdq.nc

  for ((i=0; i<nvar; i++)); do
    if [[ "${var_out_v0[$i]}" != "${var_out_v1[$i]}" ]]; then
      ncrename -O -v  ${var_out_v0[$i]},${var_out_v1[$i]}  ${drc_out_v1}/${out_fl}.ncpdq.nc  ${drc_out_v1}/${out_fl}.ncpdq.nc
    fi
  done
  
  ncap2 -O -s 'PS=float(PS);' ${drc_out_v1}/${out_fl}.ncpdq.nc ${drc_out_v1}/${out_fl}.ncpdq.nc
  ncap2 -O -s 'p_mid[$time,$ncol,$lev]=0.0f;p_mid[$time,$ncol,$lev]=100000.0*hyam+PS*hybm' ${drc_out_v1}/${out_fl}.ncpdq.nc  ${drc_out_v1}/${out_fl}.ncpdq.nc
  ncatted -O -a units,p_mid,o,c,'Pa' ${drc_out_v1}/${out_fl}.ncpdq.nc
  ncatted -O -a long_name,p_mid,o,c,'p_mid' ${drc_out_v1}/${out_fl}.ncpdq.nc

  mv ${drc_out_v1}/${out_fl}.ncpdq.nc  ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc
  ncatted -O -t -a _FillValue,,o,f,3.402824e+33  ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc

  ncap2 -O -s 'time=time-time(0);'  ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc  ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc
  ncatted -O -a units,time,o,c,'days since '${iy_fmt}-${im_fmt}-${id_fmt}' 00:00:00' ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc
  ncatted -O -a case_t0,global,o,c,${case_t0} ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc
  ncks -O --mk_rec_dmn time ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc
  
  echo -e "v1 ---- ${drc_out_v1}/${out_fl}.ncpdq_FillValue.nc was generated ----\n"
  exit 1
# fi 

done #id
done #im
done #iy
```

#### hindcast

Either HICCUP or a Bash script can be used to regrid the nudging files. The surface adjustment is turned off for nudging if using HICCUP.

HICCUP scripts for nudging files:

```bash
../scripts/HICCUP_fork/template_hiccup_scripts/process_nudging_data_EAMxx.2014-10_L128_WP10ne32x32v1pg2.py
../scripts/HICCUP_fork/template_hiccup_scripts/process_nudging_data_EAMxx.2014-10_L128_WP20ne32x32v1pg2.py
```

The Bash script for nudging:

- make horizontal mapping files from ERA5 72x1440 grid to the WPRRM pg2 grids:

```bash
ncremap -a fv2fv_flx -s /pscratch/sd/z/zhang73/DATA/data_hiccup/ERA5_721x1440_scrip.20220907.nc -g /global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1pg2.g -m /global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/map_ERA5_721x1440_to_WP10ne32x32v1pg2.TRaave.20251111.nc
ncremap -a fv2fv_flx -s /pscratch/sd/z/zhang73/DATA/data_hiccup/ERA5_721x1440_scrip.20220907.nc -g /global/cfs/cdirs/e3sm/zhang73/grids2/WP20ne32x32v1/WP20ne32x32v1pg2.g -m /global/cfs/cdirs/e3sm/zhang73/grids2/WP20ne32x32v1/map_ERA5_721x1440_to_WP20ne32x32v1pg2.TRaave.20251111.nc
```

- call the vertical and horizontal remapping using NCO

`../scripts/grid_WL.nudging.eamxx.driver.ERA5pres_NERSC.WP10ne32x32v1.20141001.demo.sh`

```bash
#!/bin/bash

# Template script for nudging data generation from ERA5 pressure level data on perlmutter:
#     source directory: /global/cfs/projectdirs/m3522/cmip6/ERA5/. For the data stored 
#     there, each file has a main variable and several time steps.
echo -e " >>>   Template script for nudging data generation from ERA5 pressure level data on perlmutter. "
echo -e " >>>   This script will activate e3sm_unified env \n"

#######################################################
# USER NEED TO SPECIFY
timefreq=3 #the time frequency needed for nudging data
RRMgrid="WP10ne32x32v1"
TR_flag='TRaave'
nlev=128 # SCREAM RRM target number of vertical levels
drc_out=/global/cfs/cdirs/e3sm/zhang73/nudging.UVTQ/L${nlev}.${TR_flag}_${RRMgrid}pg2.UVTQ.0.25plev.v1/
if [ ${RRMgrid} == "WP10ne32x32v1" ];then 
mapfile=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/map_ERA5_721x1440_to_WP10ne32x32v1pg2.TRaave.20251111.nc
fi 
if [ ${RRMgrid} == "WP20ne32x32v1" ];then 
mapfile=/global/cfs/cdirs/e3sm/zhang73/grids2/WP20ne32x32v1/map_ERA5_721x1440_to_WP20ne32x32v1pg2.TRaave.20251111.nc
fi 
ls ${mapfile}

env_unified="/global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.10.0_pm-cpu.sh"
source $env_unified

time_range='20141001-20141015'

# do_step="v1" #by default run both v0 and v1 steps (v0 is the predecessor of v1)

# END USER DEFINED SETTINGS
########################################################

start_date=${time_range%-*}
case_t0_start=$(date -d "${start_date}" +"%Y-%m-%d")"-00000"
echo ${case_t0_start}
# exit 1

if ! test -d ${drc_out}/tmp/; then mkdir -p ${drc_out}/tmp/; fi
if [ $nlev == 72 ];then 
  vert_coord=/global/cfs/cdirs/e3sm/inputdata/atm/scream/init/vertical_coordinates_L72_20220927.nc
else 
  vert_coord=/global/cfs/cdirs/e3sm/inputdata/atm/scream/init/vertical_coordinates_L128_20220927.nc
fi
start_year=${time_range:0:4}; start_month=${time_range:4:2}; start_day=${time_range:6:2}
end_year=${time_range:9:4}; end_month=${time_range:13:2}; end_day=${time_range:15:2}
echo -e "Start Date: year=$start_year, month=$start_month, day=$start_day"
echo -e "End Date: year=$end_year, month=$end_month, day=$end_day \n"

var_file=("128_131_u.ll025uv" "128_132_v.ll025uv" "128_130_t.ll025sc" "128_133_q.ll025sc" "128_134_sp.ll025sc")
var_in=("U" "V" "T" "Q" "SP")
var_out_v0=("U" "V" "T" "Q" "PS")
var_out_v1=("U" "V" "T_mid" "qv" "PS")
stream=(
 "e5.oper.an.pl"
 "e5.oper.an.pl" 
 "e5.oper.an.pl" 
 "e5.oper.an.pl" 
 "e5.oper.an.sfc" 
 )

nvar=${#var_file[@]}

#-------------------------------------------------------------------------------------------------------------
for iy in `seq $start_year 1 $end_year`;do
iy_fmt=`printf %04d $iy`
for im in `seq $start_month 1 $end_month`;do
im_fmt=`printf %02d $im`
for id in `seq 1 1 31`;do
id_fmt=`printf %02d $id`

time_tag=${iy_fmt}${im_fmt}${id_fmt}
case_t0="${iy_fmt}-${im_fmt}-${id_fmt}-00000"
time_units='hours since '${iy_fmt}-${im_fmt}-${id_fmt}' 00:00:00'

echo "case_t0 = $case_t0"
echo "time_units = $time_units"
echo "time_tag = $time_tag"

#-------------------------------------------------------------------------------------------------------------
# if [[ "${do_step}" = "v0" ]];then 
  echo "---- Start generating data on ${time_tag} (v0) ----"

  for ((i=0; i<nvar; i++)); do
    drc_in=/global/cfs/projectdirs/m3522/cmip6/ERA5/${stream[$i]}/
    if [ "${var_out_v0[$i]}" == "PS" ];then 
      cdo selday,${id}  ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.${iy_fmt}${im_fmt}*.nc  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.1h.nc
      ncks -O -d time,0,,${timefreq}  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.1h.nc  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.${timefreq}h.nc
      rm ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.1h.nc
    else 
      ncks -O -d time,0,,${timefreq}  ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.${time_tag}*.nc  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.${timefreq}h.nc
    fi 
    if [[ "${var_in[$i]}" != "${var_out_v0[$i]}" ]]; then
      ncrename -O -v  ${var_in[$i]},${var_out_v0[$i]}  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.${timefreq}h.nc
    fi

    echo "done. extract ${var_out_v0[$i]}."
  done #var

  #---combine all vars into one file
  cp ${drc_out}/tmp/${var_out_v0[0]}.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/era5p.${time_tag}.${timefreq}h.nc 
  for ((i=1; i<nvar; i++)); do
  ncks -A -v ${var_out_v0[$i]}  ${drc_out}/tmp/${var_out_v0[$i]}.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/era5p.${time_tag}.${timefreq}h.nc 
  done 
  echo "done. combine all vars into one file."

  ncremap -m ${mapfile} -i ${drc_out}/tmp/era5p.${time_tag}.${timefreq}h.nc -o ${drc_out}/tmp/era5p_${TR_flag}.${time_tag}.${timefreq}h.nc
  echo "done. horizontal interpolation to ${TR_flag}."

  #---change plev to Pa to let nco work correctly
  ncrename -O -d level,plev  ${drc_out}/tmp/era5p_${TR_flag}.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc
  ncap2 -O -s 'plev[$plev]=level*100'  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc
  ncatted -O -a units,plev,o,c,'Pa' ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc
  ncatted -a alternate_units,plev,d,,  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc
  ncks -O -x -v level ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc

  ncremap --vrt_fl=${vert_coord} -i  ${drc_out}/tmp/era5p_${TR_flag}_plev.${time_tag}.${timefreq}h.nc -o ${drc_out}/era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h.nc
  echo "done. vertical interpolation."

  echo -e "v0 ---- ${drc_out}/era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h.nc was generated ----\n"
# fi 
#-------------------------------------------------------------------------------------------------------------

# if [[ "${do_step}" = "v1" ]];then 
  echo "---- Continue generating data on ${time_tag} (v1) ----"

  out_fl="era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h"

  ncpdq -O -a ncol,lev  ${drc_out}/${out_fl}.nc  ${drc_out}/${out_fl}.ncpdq.nc

  for ((i=0; i<nvar; i++)); do
    if [[ "${var_out_v0[$i]}" != "${var_out_v1[$i]}" ]]; then
      ncrename -O -v  ${var_out_v0[$i]},${var_out_v1[$i]}  ${drc_out}/${out_fl}.ncpdq.nc  ${drc_out}/${out_fl}.ncpdq.nc
    fi
  done
  
  ncap2 -O -s 'PS=float(PS);' ${drc_out}/${out_fl}.ncpdq.nc ${drc_out}/${out_fl}.ncpdq.nc
  ncap2 -O -s 'p_mid[$time,$ncol,$lev]=0.0f;p_mid[$time,$ncol,$lev]=100000.0*hyam+PS*hybm' ${drc_out}/${out_fl}.ncpdq.nc  ${drc_out}/${out_fl}.ncpdq.nc
  ncatted -O -a units,p_mid,o,c,'Pa' ${drc_out}/${out_fl}.ncpdq.nc
  ncatted -O -a long_name,p_mid,o,c,'p_mid' ${drc_out}/${out_fl}.ncpdq.nc

  mv ${drc_out}/${out_fl}.ncpdq.nc  ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc
  ncatted -O -t -a _FillValue,,o,f,3.402824e+33  ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc

  ncap2 -O -s 'time=time-time(0);'  ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc  ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc
  ncatted -O -a units,time,o,c,'hours since '${iy_fmt}-${im_fmt}-${id_fmt}' 00:00:00' ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc
  ncatted -O -a case_t0,global,o,c,${case_t0} ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc
  ncks -O --mk_rec_dmn time ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc
  
  ncks -O -5 ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc  ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc

  echo -e "v1 ---- ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc was generated ----\n"
# fi 
exit 1
done #id
done #im
# exit 1
done #iy
rm -rf ${drc_out}/tmp/
rm -rf ${drc_out}/
```

### output YAML

Commands for generating mapping files to remap output to ne30 resolution:

```bash
ncremap -a fv2fv_flx -s /p/lustre2/zhang73/grids2/WP10ne32x32v1/WP10ne32x32v1pg2_scrip.nc -g /p/lustre2/zhang73/grids2/ne30/ne30_pg2_scrip.nc -m /p/lustre2/zhang73/grids2/WP10ne32x32v1/map_WP10ne32x32v1pg2_to_ne30pg2.TRaave.20250430.nc
ncremap -a fv2fv_flx -s /p/lustre2/zhang73/grids2/WP20ne32x32v1/WP20ne32x32v1pg2_scrip.nc -g /p/lustre2/zhang73/grids2/ne30/ne30_pg2_scrip.nc -m /p/lustre2/zhang73/grids2/WP10ne32x32v1/map_WP20ne32x32v1pg2_to_ne30pg2.TRaave.20250430.nc
```

### user namelists

The user namelists need to be modified to enable the lower/lateral BLs generated in the previous step. All the modifications are put in the `runscript_core.sh`.

- add prescribed SST and ice cover settings
- set `streams` for DOCN in `user_nl_docn`
- set `SSTICE_DATA_FILENAME`, `SSTICE_YEAR_ALIGN`, `SSTICE_YEAR_START`, `SSTICE_YEAR_END` by xmlchange
- set `stream_fldfilename` for `SPBC_CICE` in `user_nl_cice`

- add GHG forcing by atmchange
- add nudging settings by atmchange
- set YAML outputs by atmchange
- set RUN_STARTDATE, STOP_OPTION, RUN_TYPE, RESUBMIT etc. by xmlchange

`runscript_core.sh`

```bash
...
#-----------------------------------------------------
case_setup() {
...
    ./xmlchange EPS_AGRID=1e-9

    ./xmlchange PIO_NETCDF_FORMAT="64bit_data"
...
}

...
user_nl() {

# let's put all user namelist setup here

cat << EOF >> user_nl_cpl
 ocn_surface_flux_scheme = 2
EOF

# cice && docn nl is needed if you want to set the realistic SST and ice_cov forcing in hindcasts
cat > user_nl_cice << 'eof'
stream_fldfilename = '/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.2014.fillmsg.fmt-c250322.nc'
stream_domfilename = '/usr/workspace/e3sm/ccsm3data/inputdata/ocn/docn7/domain.ocn.0.25x0.25.c20190221.nc'
 model_year_align               = 2014
 stream_fldvarname              = 'ice_cov'
 stream_year_first              = 2014
 stream_year_last               = 2014
eof

cat > user_nl_docn << 'eof'
 streams = 'docn.streams.txt.prescribed 2014 2014 2014'
eof

}

...

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
    ./atmchange mac_aero_mic::atm_procs_list=tms,shoc,cldFraction,spa,p3,nudging
    ./case.setup 
    # make sure that ``time'' is set to unlimited o/w we'll receive SIGSEGV: "invalid memory reference without other clues"
    ./atmchange physics::mac_aero_mic::nudging::nudging_filenames_patterns=${NUDGING_ROOT}/HICCUP.atm_era5.201410??_??.mono_WP20ne32x32v1pg2.L128.nc
    ./atmchange physics::mac_aero_mic::nudging::nudging_fields=U,V
    ./atmchange mac_aero_mic::nudging::source_pressure_type="TIME_DEPENDENT_3D_PROFILE"
    # we do can activate online horiz_remap + weighted nudging at the same time
    #   << if you want that, comment the EKAT MSG with ``coarse'' and ``weighted'' in eamxx_nudging_process_interface.cpp in the source code
    ./atmchange mac_aero_mic::nudging::nudging_refine_remap_mapfile="no-file-given"
    ./atmchange physics::mac_aero_mic::nudging::skip_vert_interpolation=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_timescale=10800
    # need to generate a netcdf file of nudging_weights.  Please see the script
    #  SCREAMv1_create_nudging_weights.py to do this.
    ./atmchange physics::mac_aero_mic::nudging::use_nudging_weights=true
    ./atmchange physics::mac_aero_mic::nudging::nudging_weights_file=/p/lustre2/zhang73/grids2/WP20ne32x32v1/WP20ne32x32v1pg2_weighting_file.nc
    # dont know why now we cannot ask for compute_tendencies for nudging. error: "The key 'nudging_T_mid_tend' is not associated to any registered product"
    #./atmchange physics::mac_aero_mic::nudging::compute_tendencies=T_mid,qv

    # Set atmos IC file
    # Allow for tendency outputs
    ./atmchange physics::mac_aero_mic::shoc::compute_tendencies=T_mid,qv
    ./atmchange physics::mac_aero_mic::p3::compute_tendencies=T_mid,qv
    ./atmchange physics::rrtmgp::compute_tendencies=T_mid
    ./atmchange homme::compute_tendencies=T_mid,qv

    # use GHG levels more appropriate for 2019
    ./atmchange co2vmr=410.5e-6
    ./atmchange ch4vmr=1877.0e-9
    ./atmchange n2ovmr=332.0e-9
    ./atmchange orbital_year=2019
    # use CO2 the same in land model

    ./xmlchange CCSM_CO2_PPMV=410.5

    #user_nl #if you set user_docn.streams instead, must activate it here
    ./xmlchange SSTICE_GRID_FILENAME="/usr/workspace/e3sm/ccsm3data/inputdata/ocn/docn7/domain.ocn.0.25x0.25.c20190221.nc"
    ./xmlchange SSTICE_DATA_FILENAME="/p/lustre2/zhang73/DATA/data_hiccup/sst_ice.daymean.2014.fillmsg.fmt-c250322.nc"
    ./xmlchange SSTICE_YEAR_ALIGN="2014"
    ./xmlchange SSTICE_YEAR_START="2014"
    ./xmlchange SSTICE_YEAR_END="2014"

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

    cp ${YAML_ROOT}"/scream_1hI_pg2.yaml" .
    ./atmchange output_yaml_files="./scream_1hI_pg2.yaml"
    cp ${YAML_ROOT}"/scream_1dA_pg2.yaml" .
    ./atmchange output_yaml_files+="./scream_1dA_pg2.yaml"

    popd
}
...
```

#### Climotology simulation

The runscript for a testing using E3SMv1 1° SSP585 forcing can be found at:

`../scripts/runscripts/WPRRMxx_251103_ctp_qmr.E3SMv1SSP585-UVTQ2d-s20151001-O40-1hBetts-5minAsite-rad3.WP10ne32x32v1pg2.dane.sh`

#### Hindcast

The runscript for a hindcast can be found at:

`../scripts/runscripts/WPRRMxx-UV3h-s20141001-finicold-O1.WP20ne32x32v1pg2.dane.sh.20250401-195230`

This documentation is supported by LLNL LDRD project "IMPACT OF GLOBAL CLI". Work at LLNL was performed under the auspices of the U.S. DOE by the Lawrence Livermore National Laboratory under contract (grant no. DE-AC52-07NA27344; IM release: LLNL-TR-2012974).
