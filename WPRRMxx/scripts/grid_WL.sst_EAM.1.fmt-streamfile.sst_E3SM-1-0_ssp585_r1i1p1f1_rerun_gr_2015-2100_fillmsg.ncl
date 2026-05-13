begin

exp_name="E3SM-1-0_ssp585_r1i1p1f1_rerun_gr_2015-2100"
date_make="c221031"
;======================================================================

;f=addfile("/g/g92/zhang73/HICCUP/data/HICCUP_TEST.ERA5.sfc.low-res_revsst.nc","w")
;sst=f->sst-273.15
;sst@units="degC"
;sst=where(sst.lt.-20.,sst@_FillValue,sst)
;f->sst=sst
;exit
;
;
;
;f=addfile("/usr/gdata/climdat/ccsm3data/inputdata/atm/cam/sst/sst_"+exp_name+"_"+date_make+"_testfmt-HICCUP.nc","w")
;;f=addfile("/usr/gdata/climdat/ccsm3data/inputdata/atm/cam/sst/sst_HadOIBl_bc_1x1_clim_c101029_testfmt-HICCUP.nc","w")
;ice_cov=f->ice_cov
;ice_cov=where(ice_cov.eq.1,-32767.,ice_cov)
;ice_cov@_FillValue=-32767.
;ice_cov@missing_value=-32767.
;
;SST_cpl=f->SST_cpl
;SST_cpl=where(SST_cpl.eq.-1.8,-32767.,SST_cpl)
;SST_cpl@_FillValue=-32767.
;SST_cpl@missing_value=-32767.
;
;f->ice_cov=ice_cov
;f->SST_cpl=SST_cpl
;exit

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
printVarSummary(lon 	)

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
