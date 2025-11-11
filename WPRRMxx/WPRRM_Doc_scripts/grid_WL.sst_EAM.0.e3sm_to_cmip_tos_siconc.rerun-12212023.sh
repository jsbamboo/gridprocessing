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

