#!/bin/bash
set -uo pipefail


main() {
# Template script for nudging data generation from ERA5 pressure level data on perlmutter:
#     source directory: /global/cfs/projectdirs/m3522/cmip6/ERA5/. For the data stored 
#     there, each file has a main variable and several time steps.
echo -e " >>>   Template script for nudging data generation from ERA5 pressure level data on perlmutter. "
echo -e " >>>   This script will activate e3sm_unified env \n"

#######################################################
# USER NEED TO SPECIFY
timefreq=3 #the time frequency needed for nudging data
# RRMgrid="WP10ne32x32v1"
RRMgrid="Chilene32x32v1"
TR_flag='TRaave'
nlev=128 # SCREAM RRM target number of vertical levels
drc_out=/global/cfs/cdirs/e3sm/zhang73/nudging.UVTQ/L${nlev}.${TR_flag}_${RRMgrid}pg2.UVTQ.0.25plev.v1/
if [ ${RRMgrid} == "WP10ne32x32v1" ];then 
mapfile=/global/cfs/cdirs/e3sm/zhang73/grids2/WP10ne32x32v1/map_ERA5_721x1440_to_WP10ne32x32v1pg2.TRaave.20251111.nc
fi 
if [ ${RRMgrid} == "WP20ne32x32v1" ];then 
mapfile=/global/cfs/cdirs/e3sm/zhang73/grids2/WP20ne32x32v1/map_ERA5_721x1440_to_WP20ne32x32v1pg2.TRaave.20251111.nc
fi
if [ ${RRMgrid} == "Chilene32x32v1" ];then 
mapfile=/global/cfs/cdirs/e3sm/zhang73/grids2/Chilene32x32v1/gridprocessing/map_ERA5_721x1440_to_Chilene32x32v1pg2.TRaave.20260423.nc
fi

ls ${mapfile}

env_unified="/global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.10.0_pm-cpu.sh"
restore_nounset=false
if [[ $- == *u* ]]; then
  restore_nounset=true
  set +u
fi
source "$env_unified"
if [[ "${restore_nounset}" == "true" ]]; then
  set -u
fi

time_range='20240401-20241231'
time_range='20250101-20251231'
time_range='20260101-20260131' #need to prepare one day more!!!
# time_range='20200101-20231231'
#time_range='20231001-20231231'
#time_range='20221001-20221231'
time_range='20200101-20251231' #check
time_range='20220101-20231231' #check
time_range='20220101-20241231' #check 2

# do_step="v1" #by default run both v0 and v1 steps (v0 is the predecessor of v1)


control_tag="normal" # normal | force_gen
# control_tag="force_gen" # normal | force_gen

# END USER DEFINED SETTINGS
########################################################
force_gen=false
if [[ "${control_tag}" == "force_gen" ]]; then
  force_gen=true
elif [[ "${control_tag}" != "normal" ]]; then
  echo "ERROR: unsupported control_tag=${control_tag}; use normal or force_gen." >&2
  exit 1
fi

if (( timefreq <= 0 || 24 % timefreq != 0 )); then
  echo "ERROR: timefreq must be a positive divisor of 24; got ${timefreq}." >&2
  exit 1
fi
expected_time_count=$((24 / timefreq))


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

# EAMxx nudging input uses a no-leap calendar, so never generate February 29,
# including in Gregorian leap years.  Also skip impossible dates such as
# February 30, which can otherwise leave partial files.
if [[ "${im_fmt}${id_fmt}" == "0229" ]]; then
  echo "Skip no-leap-calendar date ${time_tag}."
  continue
fi
if ! valid_time_tag=$(date -d "${iy_fmt}-${im_fmt}-${id_fmt}" +%Y%m%d 2>/dev/null) ||
   [[ "${valid_time_tag}" != "${time_tag}" ]]; then
  continue
fi

echo "case_t0 = $case_t0"
echo "time_units = $time_units"
echo "time_tag = $time_tag"

#-------------------------------------------------------------------------------------------------------------
outfile_v0=${drc_out}/era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h.nc
v0_regenerated=false

if should_regen_nc "${outfile_v0}" "U,V,T,Q,PS" false; then
  v0_regenerated=true
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

  if nc_file_needs_regen "${outfile_v0}" "U,V,T,Q,PS" false; then
    echo "ERROR: regenerated v0 file failed validation: ${outfile_v0}" >&2
    exit 1
  fi

  echo -e "v0 ---- ${drc_out}/era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h.nc was generated ----\n"
# fi 
else
  echo "Already generated ${outfile_v0}, skip ..."
fi
#-------------------------------------------------------------------------------------------------------------

out_fl="era5p_${TR_flag}_L${nlev}.${time_tag}.${timefreq}h"
outfile_v1=${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc

if [[ "${v0_regenerated}" == "true" ]] ||
   should_regen_nc "${outfile_v1}" "U,V,T_mid,qv,PS,p_mid" true; then

# if [[ "${do_step}" = "v1" ]];then 
  echo "---- Continue generating data on ${time_tag} (v1) ----"


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

  if nc_file_needs_regen "${outfile_v1}" "U,V,T_mid,qv,PS,p_mid" true; then
    echo "ERROR: regenerated v1 file failed validation: ${outfile_v1}" >&2
    exit 1
  fi

  echo -e "v1 ---- ${drc_out}/${out_fl}.ncpdq_FillValue.v1.nc was generated ----\n"
# fi 
else
  echo "Already generated ${outfile_v1}, skip ..."
fi

# exit 1
done #id
done #im
# exit 1
done #iy
rm -rf ${drc_out}/tmp/
}


nc_file_needs_regen() {
  local nc_file="$1"
  local required_vars="$2"
  local require_zero_origin="$3"

  if [ ! -f "${nc_file}" ]; then
    return 0
  fi

  if ! command -v ncdump >/dev/null 2>&1; then
    echo "ERROR: ncdump is required to validate existing NetCDF files: ${nc_file}" >&2
    exit 1
  fi

  if ! ncdump -h "${nc_file}" >/dev/null 2>&1; then
    echo "Existing file is not readable by ncdump, regenerate: ${nc_file}"
    return 0
  fi

  if ! ncks -m -v "${required_vars}" "${nc_file}" >/dev/null 2>&1; then
    echo "Existing file lacks one or more required variables (${required_vars}), regenerate: ${nc_file}"
    return 0
  fi

  # --trd emits one easy-to-parse record per value, e.g. time[1]=3.
  # Verify the count and strictly increasing, uniform spacing.  For v1 the
  # daily time coordinate must additionally be relative to midnight (start 0).
  if ! ncks --trd -H -C -v time "${nc_file}" 2>/dev/null | awk \
    -v expected_count="${expected_time_count}" \
    -v expected_step="${timefreq}" \
    -v require_zero="${require_zero_origin}" '
      BEGIN { count=0; bad=0 }
      /^[[:space:]]*time\[[0-9]+\][[:space:]]*=/ {
        value=$0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        if (value !~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/) {
          bad=1
          next
        }
        value += 0
        if (count == 0) {
          first=value
        } else if (value - previous != expected_step) {
          bad=1
        }
        previous=value
        count++
      }
      END {
        if (count != expected_count) bad=1
        if (require_zero == "true" && (count == 0 || first != 0)) bad=1
        exit(bad ? 1 : 0)
      }
    '; then
    echo "Existing file has an invalid time axis (expected ${expected_time_count} values spaced ${timefreq} hours apart), regenerate: ${nc_file}"
    return 0
  fi

  return 1
}


should_regen_nc() {
  local nc_file="$1"
  local required_vars="$2"
  local require_zero_origin="$3"

  if [[ "${force_gen}" == "true" ]]; then
    echo "force_gen=true, regenerate: ${nc_file}"
    return 0
  fi

  nc_file_needs_regen "${nc_file}" "${required_vars}" "${require_zero_origin}"
}

main "$@"
