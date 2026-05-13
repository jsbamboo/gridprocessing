#!/bin/bash

# Template script for IELM-DATM data generation from ERA5 pressure level data on perlmutter:
#     source directory: /global/cfs/projectdirs/m3522/cmip6/ERA5/. For the data stored 
#     there, each file has a main variable and several time steps.
echo -e " >>>   Template script for IELM-DATM generation (for betacast's gen-forcing.py) from ERA5 pressure level data on perlmutter. "
echo -e " >>>   This script will activate e3sm_unified env \n"

#######################################################
# USER NEED TO SPECIFY
timefreq=3 #the time frequency needed for IELM-DATM data

env_unified="/global/common/software/e3sm/anaconda_envs/load_e3sm_unified_1.10.0_pm-cpu.sh"
# source $env_unified

drc_out=/global/cfs/cdirs/e3sm/zhang73/datm7src_nersc/ERA5-DATM_3hourly/

# # year="2020"
echo "year: $1"
year=$1
# for year in `seq 2019 1 2025`;do
# for year in `seq 2003 1 2010`;do
# for year in `seq 2011 1 2018`;do
# for year in `seq 1940 1 2002`;do #1940 - 2018: dtn01, 2019-2025: dtn02
time_range="${year}0101-${year}1231"

# END USER DEFINED SETTINGS
########################################################

if ! test -d ${drc_out}/tmp/${year}/; then mkdir -p ${drc_out}/tmp/${year}/; fi
if ! test -d ${drc_out}/scripts/; then mkdir -p ${drc_out}/scripts/; fi
start_year=${time_range:0:4}; start_month=${time_range:4:2}; start_day=${time_range:6:2}
end_year=${time_range:9:4}; end_month=${time_range:13:2}; end_day=${time_range:15:2}
echo -e "Start Date: year=$start_year, month=$start_month, day=$start_day"
echo -e "End Date: year=$end_year, month=$end_month, day=$end_day \n"

# betacast var NERSC var in path  NERSC var in file  NERSC parent path        NERSC var long_name
# u10          128_165_10u        VAR_10U            e5.oper.an.sfc           "10 metre U wind component"
# v10          128_166_10v        VAR_10V            e5.oper.an.sfc           "10 metre V wind component"
# d2m          128_168_2d         VAR_2D             e5.oper.an.sfc           "2 metre dewpoint temperature"
# t2m          128_167_2t         VAR_2T             e5.oper.an.sfc           "2 metre temperature"
# sp           128_134_sp         SP                 e5.oper.an.sfc           "Surface pressure"
# mtpr         235_055_mtpr       MTPR               e5.oper.fc.sfc.meanflux  "Mean total precipitation rate"
# msdwswrf     235_035_msdwswrf   MSDWSWRF           e5.oper.fc.sfc.meanflux  "Mean surface downward short-wave radiation flux"
# msdwlwrf     235_036_msdwlwrf   MSDWLWRF           e5.oper.fc.sfc.meanflux  "Mean surface downward long-wave radiation flux"
var_file=(
 "128_165_10u"
 "128_166_10v"
 "128_168_2d"
 "128_167_2t"
 "128_134_sp"
 "235_055_mtpr"
 "235_035_msdwswrf"
 "235_036_msdwlwrf"
)
var_in=(
 "VAR_10U"
 "VAR_10V"
 "VAR_2D"
 "VAR_2T"
 "SP"
 "MTPR"
 "MSDWSWRF"
 "MSDWLWRF"
)
var_out=(
 "u10"      #0
 "v10"      #1
 "d2m"      #2
 "t2m"      #3
 "sp"       #4
 "mtpr"     #5
 "msdwswrf" #6
 "msdwlwrf" #7
)
stream=(
 "e5.oper.an.sfc"
 "e5.oper.an.sfc"
 "e5.oper.an.sfc"
 "e5.oper.an.sfc"
 "e5.oper.an.sfc"
 "e5.oper.fc.sfc.meanflux"
 "e5.oper.fc.sfc.meanflux"
 "e5.oper.fc.sfc.meanflux"
 )

nvar=${#var_file[@]}

#-------------------------------------------------------------------------------------------------------------
helper_py="${drc_out}/scripts/extract_meanflux_3hourly.py"

cat > "$helper_py" <<'PYEOF'
#!/usr/bin/env python
import argparse
import xarray as xr
import pandas as pd
import numpy as np

p = argparse.ArgumentParser()
p.add_argument("--files", nargs="+", required=True)
p.add_argument("--var-in", required=True)
p.add_argument("--var-out", required=True)
p.add_argument("--year", type=int, required=True)
p.add_argument("--month", type=int, required=True)
p.add_argument("--out", required=True)
p.add_argument("--timefreq", type=int, required=True)
args = p.parse_args()

ds = xr.open_mfdataset(args.files, combine="by_coords")

da = ds[args.var_in]

fit_name = "forecast_initial_time"
fh_name  = "forecast_hour"

fit = pd.to_datetime(ds[fit_name].values).to_numpy()
fh = np.asarray(ds[fh_name].values)
print("forecast_initial_time sample:", fit[:3])
print("forecast_hour sample:", fh[:])
print("forecast_hour dtype:", fh.dtype)

# broadcast
fh_td = pd.to_timedelta(fh, unit="h").to_numpy()
valid = fit[:, None] + fh_td[None, :]

da2 = da.stack(time=(fit_name, fh_name))
# remove MultiIndex-created coordinate variables before overwriting time
da2 = da2.drop_vars(["time", fit_name, fh_name], errors="ignore")
da2 = da2.assign_coords(time=("time", valid.reshape(-1)))
da2 = da2.sortby("time")

month_start = pd.Timestamp(args.year, args.month, 1)
next_month = month_start + pd.offsets.MonthBegin(1)

target_hours = list(range(0, 24, args.timefreq))

da2 = da2.where(
    (da2.time >= month_start)
    & (da2.time < next_month)
    & (da2.time.dt.hour.isin(target_hours)),
    drop=True,
)

times = pd.to_datetime(da2.time.values)
print("Selected valid_time:")
for t in times:
    print(t.strftime("%Y-%m-%d %H:%M:%S"))

expected = pd.date_range(
    start=month_start,
    end=next_month - pd.Timedelta(hours=args.timefreq),
    freq=f"{args.timefreq}h",
)
missing = expected.difference(times)
extra = pd.DatetimeIndex(times).difference(expected)

print(f"Selected ntime = {len(times)}")
print(f"Expected ntime = {len(expected)}")
if len(missing) > 0:
    print("Missing times:")
    for t in missing:
        print(t.strftime("%Y-%m-%d %H:%M:%S"))
if len(extra) > 0:
    print("Extra times:")
    for t in extra:
        print(t.strftime("%Y-%m-%d %H:%M:%S"))
if len(missing) > 0 or len(extra) > 0:
    raise RuntimeError("Selected valid_time does not match expected 6-hourly target times.")

out = da2.rename(args.var_out).to_dataset()
out = out.transpose("time", "latitude", "longitude")
# encoding = {
#     args.var_out: {"dtype": "float32"},
#     "latitude": {"dtype": "float32"},
#     "longitude": {"dtype": "float32"},
#     "time": {
#         "units": "hours since 1900-01-01 00:00:00",
#         "calendar": "standard",
#     },
# }
out.to_netcdf(args.out) #, encoding=encoding

PYEOF
chmod +x "$helper_py"

#-------------------------------------------------------------------------------------------------------------
for iy in `seq $start_year 1 $end_year`;do
iy_fmt=`printf %04d $iy`

if ! test -d ${drc_out}/${iy_fmt}/; then mkdir -p ${drc_out}/${iy_fmt}/; fi

for im in `seq 1 1 12`;do
im_fmt=`printf %02d $im`
# for id in `seq 1 1 31`;do
# id_fmt=`printf %02d $id`

# time_units='hours since '${iy_fmt}-${im_fmt}-01' 00:00:00'
# echo "time_units = $time_units"

#-------------------------------------------------------------------------------------------------------------
  echo "---- Start generating data on ${iy_fmt}${im_fmt} ----"

  for ((i=0; i<nvar; i++)); do # ori is monthly hourly 744 -> 124 (6-hourly)
  # for ((i=0; i<5; i++)); do # ori is monthly hourly 744 -> 124 (6-hourly)
  # for ((i=5; i<nvar; i++)); do #after 5: meanflux
  # for ((i=0; i<1; i++)); do # ori is monthly hourly 744 -> 124 (6-hourly)
    echo " >> loop for var: ${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc ... "
    drc_in=/global/cfs/projectdirs/m3522/cmip6/ERA5/${stream[$i]}/

    if [[ "${stream[$i]}" == *"e5.oper.an.sfc"* ]]; then

      ls -lhr ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.ll025sc.${iy_fmt}${im_fmt}*.nc
      ncks -O -d time,0,,${timefreq}  ${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.ll025sc.${iy_fmt}${im_fmt}*.nc  ${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc

      if [[ "${var_in[$i]}" != "${var_out[$i]}" ]]; then
        ncrename -O -v  ${var_in[$i]},${var_out[$i]}  ${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc  ${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc
      fi
      # exit 1

    else #meanflux is complex, need to convert the forecast_initial_time + forecast_hour -> valid_time

      prev_ym=$(date -d "${iy_fmt}-${im_fmt}-01 -1 month" +%Y%m)
      prev_y=${prev_ym:0:4}
      prev_m=${prev_ym:4:2}

      files_meanflux=(
        "${drc_in}/${prev_y}${prev_m}/${stream[$i]}.${var_file[$i]}.ll025sc.${prev_y}${prev_m}16*.nc"
        "${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.ll025sc.${iy_fmt}${im_fmt}01*.nc"
        "${drc_in}/${iy_fmt}${im_fmt}/${stream[$i]}.${var_file[$i]}.ll025sc.${iy_fmt}${im_fmt}16*.nc"
      )

      python "$helper_py" \
        --files ${files_meanflux[@]} \
        --var-in "${var_in[$i]}" \
        --var-out "${var_out[$i]}" \
        --year "$iy" \
        --month "$im" \
        --timefreq "$timefreq" \
        --out "${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc"
      # exit 1

    fi 

    echo "done. extract ${var_out[$i]}."
  done #var

  echo " >> combine all vars into one file: ${drc_out}/${iy_fmt}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc ..."
  # ---combine all vars into one file
  cp ${drc_out}/tmp/${year}/${var_out[0]}.${iy_fmt}${im_fmt}.${timefreq}h.nc  ${drc_out}/tmp/${year}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc 
  for ((i=1; i<nvar; i++)); do
  ncks -A -v ${var_out[$i]}  ${drc_out}/tmp/${year}/${var_out[$i]}.${iy_fmt}${im_fmt}.${timefreq}h.nc  ${drc_out}/tmp/${year}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc  
  # check the coord vars: /time, latitude, longitude/ = /120, 721, 1440/
  done 
  mv  ${drc_out}/tmp/${year}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc  ${drc_out}/${iy_fmt}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc 

  #---temporary fix
  # ncks -A -v  ${var_out[0]} ${drc_out}/tmp/${year}/${var_out[0]}.${iy_fmt}${im_fmt}.${timefreq}h.nc  ${drc_out}/${iy_fmt}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc
  # exit 1
  echo "done. combine all vars into one file."


  echo -e "---- ${drc_out}/tmp/${year}/out.${iy_fmt}.${im_fmt}.${timefreq}h.nc  was generated ----\n"
# exit 1
#-------------------------------------------------------------------------------------------------------------
# done #id
done #im
# exit 1
done #iy
rm ${drc_out}/tmp/${year}/*
done #year

