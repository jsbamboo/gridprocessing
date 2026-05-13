begin

exp_name="2020"


dir="/p/lustre2/zhang73/DATA/data_hiccup/"
cp = systemfunc("cp "+dir+"/sst.day.mean."+exp_name+".nc "+dir+"/sst_ice.daymean."+exp_name+".nc")  
ncks = systemfunc("ncks -A -v icec "+dir+"/icec.day.mean."+exp_name+".nc "+dir+"/sst_ice.daymean."+exp_name+".nc") 

filename="sst_ice.daymean."+exp_name+".nc"

f0=addfile(dir+filename,"r")

sst=f0->sst(:,:,:)
; ice=f0->icec(:,:,:)
time=f0->time
lat = f0->lat
lon = f0->lon
printVarSummary(sst)
printMinMax(sst,0)

sst_fill = sst
poisson_grid_fill(sst_fill, True, 1, 1500, 1e-2, 0.6, 0)
printVarSummary(sst_fill)
printMinMax(sst_fill,0)
; exit 

diro=dir
filo="sst_ice.daymean."+exp_name+".fillmsg.nc"
system("/bin/rm -f " + diro + filo)
system("if ! test -f " + diro+filo +" ; then cp "+ diro+filename +" "+ diro+filo +" ; fi")
fout = addfile (diro + filo, "w")  

nl = integertochar(10)
globalAtt=True
globalAtt@history = nl+\
      systemfunc("date") + ": ncl < /g/g92/zhang73/test/zhang73_scripts/make_sst_NOAA0.fillmsg."+exp_name+".ncl"
fileattdef(fout, globalAtt)

fout->sst_fill = sst_fill

end
