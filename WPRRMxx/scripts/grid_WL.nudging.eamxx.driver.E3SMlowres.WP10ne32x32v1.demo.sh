#!/bin/bash

# do_step="v1" #by default run both v0 and v1 steps (v0 is the predecessor of v1)
grp_tag="12212023"
caseid="3hI-UVTQ-s2015_2.20190807.DECKv1b_P1_SSP5-8.5.ne30_oEC.ruby.1344"
hx="h4" #the eam.h? tape for U,V,T,Q,PS high frequency outputs used to make the nudging data

nlev_L=72 #E3SM low-res forcing number of vertical levels
nlev_H=128 #SCREAM RRM target number of vertical levels

#######################################################
# USER NEED TO SPECIFY

RRMgrid="WP10ne32x32v1"
# RRMgrid="WP20ne32x32v1"

start_year=2016
end_year=2020

#---output dir setting
drc_out_vrt=/p/lustre2/zhang73/nudging.UVTQ/${caseid}/L${nlev_H}/
drc_out_v0=/p/lustre2/zhang73/nudging.UVTQ/${caseid}/v0/
drc_out_v1=/p/lustre2/zhang73/nudging.UVTQ/${caseid}/v1/

# END USER DEFINED SETTINGS
#######################################################

if ! test -d ${drc_out_vrt}; then mkdir -p ${drc_out_vrt}; fi
if ! test -d ${drc_out_v0}; then mkdir -p ${drc_out_v0}; fi
if ! test -d ${drc_out_v1}; then mkdir -p ${drc_out_v1}; fi

#-----------------------------vrt remapping file----------------------------
vrt_file=/usr/workspace/e3sm/ccsm3data/inputdata/atm/scream/init/vertical_coordinates_L128_20220927.nc

#-----------------------------hori remapping file---------------------------
TR_flag="highorder_se2fv_${RRMgrid}pg2"
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
for im in `seq 1 1 12`;do
for id in `seq 1 1 31`;do
im_fmt=`printf %02d $im`
id_fmt=`printf %02d $id`

drc_in_L=/p/lustre2/zhang73/${grp_tag}/${caseid}/cam.${hx}/${iy_fmt}/ #E3SMv1 ne30 3h UVTQ outputs

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
  # exit 1
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


