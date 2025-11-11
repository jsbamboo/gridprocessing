begin

exp_name="20230720_20230809"
date_make="c230921"
exp_name="2023"
date_make="c240501"
exp_name="2021"
date_make="c240901"
exp_name="2022"
date_make="c241104"
exp_name="2020"
date_make="c250725"

start_year=str_get_cols(exp_name, 0, 3)
start_month=str_get_cols(exp_name, 4, 5)
start_day=str_get_cols(exp_name, 6, 7)
if(start_month.eq."")then start_month="01" end if
if(start_day.eq."")then start_day="01" end if

dir="/p/lustre2/zhang73/DATA/data_hiccup/"
filename_ref="sst_ice.daymean."+exp_name+".fillmsg.nc"
filename_sst="sst_ice.daymean."+exp_name+".fillmsg.aave_1x1.nc"
filename_ice="sst_ice.daymean."+exp_name+".fillmsg.aave_1x1.nc"
ncremap = systemfunc("ncremap -m "+dir+"/map_NOAA_0.25x0.25_to_1x1_nco.aave.20230921.nc -i "+dir+"/"+filename_ref+" -o "+dir+"/"+filename_sst)  

f0=addfile(dir+filename_ref,"r")
f1=addfile(dir+filename_sst,"r")
f2=addfile(dir+filename_ice,"r")

sst_ref=f0->sst_fill(:,:,:)
ice_ref=f0->icec(:,:,:)
time_ref=f0->time
lat = f1->lat
lon = f1->lon
printVarSummary(sst_ref)
printVarSummary(ice_ref)


sst_in=f1->sst_fill
ice_in=f2->icec
time_in=f1->time
sst_in = where(sst_in.lt.min(sst_ref).or.sst_in.gt.max(sst_ref), sst_in@_Fillvalue, sst_in)
ice_in = where(ice_in.lt.min(ice_ref).or.ice_in.gt.max(ice_ref), ice_in@_Fillvalue, ice_in)
printMinMax(sst_in,0)
printMinMax(ice_in,0)
printVarSummary(time_in)

sst=where(ismissing(sst_in),-1.8,sst_in)
; ice_cov=ice_in/100.
ice_cov=where(ismissing(ice_in),0,ice_in)

print(time_in@actual_range)
; print(time_in)
time=(/time_in - time_in(0) + 0.5/) ;let the first time to be 12:00 UTC in the first day 2023-07-20
time@units="days since "+start_year+"-"+start_month+"-"+start_day+" 00:00:00"
print(time@units)
time@calendar = "365_day"
time!0="time"
time@long_name="time"
time&time=time
print(time+" "+cd_calendar(time,-3))
; exit

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
printVarSummary(lon 	)

print(time(0:12)+", "+date(0:12)+", "+datesec(0:12)+","+YYMMDDHH(0:12))
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


filo="sst_ice.daymean."+exp_name+".fillmsg.aave_1x1.fmt-"+date_make+".nc"
filo_noleap = "sst_ice.daymean."+exp_name+".fillmsg.aave_1x1.fmt-"+date_make+"_noleap.nc"
system("/bin/rm -f " + dir+filo)
fout=addfile(dir+filo,"c")
dimNames=(/"time","lat","lon"/)
dimSizes=(/-1,180,360/)
dimUnlim=(/True,False,False/)
filedimdef(fout,dimNames,dimSizes,dimUnlim)

nl = integertochar(10)
globalAtt=True
globalAtt@history = nl+\
      systemfunc("date") + ": ncl < /g/g92/zhang73/test/zhang73_scripts/make_sst_NOAA_"+exp_name+"_"+date_make+".ncl"
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

if(dimsizes(time).gt.365)then 
print("... convert leap to noleap year ...")
command_cut_to_noleap = systemfunc("ncks -F -d time,1,59 -d time,59 -d time,60,365 "+fout+" "+dir+filo_noleap)
end if 

end
