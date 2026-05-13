#!/bin/bash

# Template script for nudging data generation from ERA5 pressure level data on perlmutter:
# 	  source directory: /global/cfs/projectdirs/m3522/cmip6/ERA5/. For the data stored 
# 	  there, each file has a main variable and several time steps.
# Note: This script is not officially maintained by any project, and has no financial support.
# 	  If you have non-trival issues, please contact zhang73@llnl.gov directly.
echo -e " ♫   Template script for nudging data generation from ERA5 pressure level data on perlmutter. "
echo -e " ♫   To use it, activate e3sm_unified env: source /global/common/software/e3sm/anaconda_envs/load_latest_e3sm_unified_pm-cpu.sh \n"

#######################################################
# USER NEED TO SPECIFY
timefreq=6 #the time frequency needed for nudging data
drc_out=/pscratch/sd/z/zhang73/nudging.UVTQ/L72.mono_northamericax4v1pg2.UVTQ.pres1mon/
TR_flag='TRaave'
mapfile=/pscratch/sd/z/zhang73/grids2/CAne32x32v1/map_ERA5_721x1440_to_northamericax4v1pg2.${TR_flag}.20241102.nc
nlev=72 # model vertical coordinate levels
time_range='19980401-19980430'
# END USER DEFINED SETTINGS
########################################################

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
var_out=("U" "V" "T" "Q" "PS")
stream=(
 "e5.oper.an.pl"
 "e5.oper.an.pl" 
 "e5.oper.an.pl" 
 "e5.oper.an.pl" 
 "e5.oper.an.sfc" 
 )
nn=${#var_file[@]}

#-------------------------------------------------------------------------------------------------------------
for iy in `seq $start_year 1 $end_year`;do
iy_fmt=`printf %04d $iy`
for im in `seq $start_month 1 $end_month`;do
im_fmt=`printf %02d $im`
for id in `seq 1 1 31`;do
  id_fmt=`printf %02d $id`

  echo "---- Start generating data on ${iy_fmt}${im_fmt}${id_fmt} ----"
  for ((i=0; i<nn; i++)); do
  	drc_in=/pscratch/sd/t/tang30/share/ForJinbo/${stream[$i]}/
  	if [ "${var_out[$i]}" == "PS" ];then 
	  cdo selday,${id}  ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.${iy_fmt}${im_fmt}*.nc  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.1h.nc
	  ncks -O -d time,0,,${timefreq}  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.1h.nc  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
	  ncrename -O -v  ${var_in[$i]},${var_out[$i]}  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
	  rm ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.1h.nc
    else 
	  ncks -O -d time,0,,${timefreq}  ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.${iy_fmt}${im_fmt}${id_fmt}*.nc  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
	fi 
  echo "done. extract ${var_out[$i]}."
  done #var

  #---combine all vars into one file
  cp ${drc_out}/tmp/${var_out[0]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/era5p.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc 
  for ((i=1; i<nn; i++)); do
	ncks -A -v ${var_out[$i]}  ${drc_out}/tmp/${var_out[$i]}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/era5p.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc 
  done 
  echo "done. combine all vars into one file."

  ncremap -m ${mapfile} -i ${drc_out}/tmp/era5p.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc -o ${drc_out}/tmp/era5p_${TR_flag}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  echo "done. horizontal interpolation to ${TR_flag}."

  #---change plev to Pa to let nco work correctly
  ncrename -O -d level,plev  ${drc_out}/tmp/era5p_${TR_flag}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  ncap2 -O -s 'plev[$plev]=level*100'  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  ncatted -O -a units,plev,o,c,'Pa' ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  ncatted -a alternate_units,plev,d,,  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  ncks -O -x -v level ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc

  ncremap --vrt_fl=${vert_coord} -i  ${drc_out}/tmp/era5p_${TR_flag}_plev.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc -o ${drc_out}/era5p_${TR_flag}_L${nlev}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc
  echo "done. vertical interpolation."

echo -e "---- ${drc_out}/era5p_${TR_flag}_L${nlev}.${iy_fmt}${im_fmt}${id_fmt}.${timefreq}h.nc was generated ----\n"
done #id
done #im
done #iy
rm -rf ${drc_out}/tmp/

