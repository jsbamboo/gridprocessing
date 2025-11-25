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

