load "./grid_WL.shp_mask.00.shapefile_utils.ncl"

begin
mach="LC"
mach="perlm"
if(mach.eq."LC")then 
host_proc="/p/lustre2/zhang73"
end if
if(mach.eq."perlm")then 
host_proc="/global/cfs/cdirs/e3sm/zhang73"
end if

  grid="Chilene32x32v1"  
  if(str_get_cols(grid,0,2).eq."CAx")then 
    grid_real = str_get_cols(grid,0,1)+"ne32"+str_get_cols(grid,2,-1)
  else 
    grid_real = grid
  end if 
  print(grid_real)
  ; exit

  region="Chilebuffer"
  name_shp="shp_mask_"+grid+"pg2"

  if(grid.eq."Chilene32x32v1")then 
    scrip_name=""+host_proc+"/grids2/Chilene32x32v1/gridprocessing/Chilene32x32v1pg2_scrip.nc"
    a = addfile("/global/cfs/cdirs/e3sm/zhang73/backup/lc/lustre1/E3SM_simulations/ChileRRMxx/ChileRRMxx.Chilene32x32v1pg2_Chilene32x32v1pg2.F2010-SCREAMv1.dane/tests/1120x1_nhoursx1_ERA5pres-UVTQ6h-s20250101-O3/run/1hA.AVERAGE.nhours_x1.2025-01-01-03600.nc", "r")
  end if 

  if(region.eq."Chile_buffer")then 
    shp_filename = ""+host_proc+"/grids2/shapefile/chile_shp/cl_dissolved_buffered-1deg.shp"
  end if 
  
  f = addfile(scrip_name,"r")  
  r2d = get_r2d("float")
  x  = f->grid_center_lon ;* r2d
  y  = f->grid_center_lat ;* r2d
  cx = f->grid_corner_lon ;* r2d
  cy = f->grid_corner_lat ;* r2d
  print(cx(0:2,:)+", "+cy(0:2,:))
; exit
  dim=dimsizes(cx) ;/grid_size, grid_corners/
  ncol=dim(0)
  delete(dim)

diro = ""+host_proc+"/grids2/"+grid_real+"/"
if(region.eq."CA")then 
filo = region+"_shp_mask_"+grid+"pg2.nc"
else
filo = region+".shp_mask_landfrac."+grid+"pg2.nc"
end if

;================================================================================================
;---generate shp_mask
opt1             = True
opt1@return_mask = True
opt1@debug       = True
opt1@keep        = True

; make var's coordinates to fit shapefile
x_forshp=where(x.ge.180., x-360., x)
y_forshp=y

area = a->area
lat  = a->lat
lon  = a->lon
if(grid.eq."northamericax4v1")then
landfrac = a1->LANDFRAC(0,:)
else if(grid.eq."Chilene32x32v1")then 
landfrac = a->landfrac
else
landfrac = a->LANDFRAC(0,:)
end if
end if
if(grid.eq."Chilene32x32v1")then 
var_tmp = a->ps(0,:)
else 
var_tmp = a->PS(0,:)
end if 
var_tmp@lon1d = x_forshp
var_tmp@lat1d = y_forshp
shp_mask  = shapefile_mask_data(var_tmp, shp_filename, opt1)

;================================================================================================
;---save shp_mask to nc file
; setfileoption("nc", "Format",  "LargeFile")
; system("if ! test -d " + diro +" ; then mkdir -p " + diro + " ; fi")
system("/bin/rm -f " + diro + filo)
fout = addfile (diro + filo, "c")  

nl = integertochar(10)
globalAtt=True
globalAtt@history = nl+\
      systemfunc("date") + ": ncl < grid_WL.YAML.eamxx.pg2icol_shp.00.shp_mask.ncl "+nl + \
                            " scrip_name: "+scrip_name+" "+nl +\
                            " shp_filename: "+shp_filename
fileattdef(fout, globalAtt)

shp_mask!0="ncol"
fout->$name_shp$ = shp_mask
fout->area       = area
fout->lat        = lat 
fout->lon        = lon 
fout->landfrac   = landfrac

system("rsync -av "+diro + filo+" "+host_proc+"/grids2/shp_mask/")
;================================================================================================
;--use shp_mask to mask var
; var_mask = mask(var_tmp, shp_mask, 1)
end
