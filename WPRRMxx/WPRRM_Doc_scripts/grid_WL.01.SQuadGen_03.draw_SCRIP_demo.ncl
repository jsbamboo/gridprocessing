;======================================================================
; geo_4.ncl
;
; Concepts illustrated:
;   - Plotting data on a high-res geodesic mesh
;   - Setting the cell bounds for an unstructured mesh
;   - Using opacity to emphasize or subdue overlain features
;======================================================================
; This script requires NCL V6.6.0 or later to run, since it uses
; an updated version of gsn_coordinates.
;======================================================================

begin
;!!!!!!!!!!!!!!!!!!!! User Need to Change !!!!!!!!!!!!!!!!!!!!!
  filepath      = (/"/p/lustre2/zhang73/grids2/WP10ne32x32v1/",\
                    "/p/lustre2/zhang73/grids2/WP20ne32x32v1/"/)
  filename      = (/"WP10ne32x32v1pg2_scrip.nc",\
                    "WP20ne32x32v1pg2_scrip.nc"/)
  lat_width     = 30.
  lon_width     = 30.
  mpCenterLatF  = 7.5
  mpCenterLonF  = 165.
  path_plots = "/p/lustre2/zhang73/plots/"
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  wks = gsn_open_wks("pdf",path_plots+"area_pdf."+filename(0))

  draw_SP = False
  draw_mark = False

do ifile=0,dimsizes(filename)-1
  f = addfile(filepath(ifile)+filename(ifile),"r")

  r2d = get_r2d("float")
  cx = f->grid_corner_lon(::1,:) ;* r2d
  cy = f->grid_corner_lat(::1,:) ;* r2d

  dim=dimsizes(cx) ;/grid_size, grid_corners/

  ke=new(dim(0), float)
  ke=1
  ke(::2)=2
  ke(::3)=4
  ke@lon1d := f->grid_center_lon ;* r2d
  ke@lat1d := f->grid_center_lat ;* r2d
  grid_area := f->grid_area


  ;---Check if the grid size is as expected 
  re   = 6.37122e06
  grid_length_km := sqrt(grid_area)*re/1e3
  printMinMax(grid_length_km,0)
  print(num(grid_length_km.lt.5)+" of total: "+dimsizes(grid_area))
  ; plot=gsn_csm_xy(wks, area_pdf@bin_center, area_pdf, True)
  ; exit

  res                         = True
  res@gsnMaximize             = True
  res@gsnRightString          = ""
  res@gsnLeftString           = ""
  res@gsnCenterString         = "" 

  res@gsnDraw                 = False
  res@gsnFrame                = False

  res@mpProjection            = "Orthographic"     ; choose projection
  res@mpCenterLatF            = mpCenterLatF
  res@mpCenterLonF            = mpCenterLonF
  res@mpOutlineOn             = False
  res@mpPerimOn               = False
  res@mpFillOn                = True
  res@mpGridAndLimbOn         = False
  res@mpGridMaskMode          = "MaskLand"

  res@mpLandFillColor         = "tan"
  res@mpOceanFillColor        = "LightBlue"
  res@mpInlandWaterFillColor  = "Blue"

  ; res@tiMainString            = "Contours of data on high-res geodesic mesh (" +\
  ;                                dimsizes(ke) + " cells)"
  res@tiMainFontHeightF       = 0.02
  res@tiMainFont              = "helvetica"
  ; plot = gsn_csm_contour_map(wks,ke,res)

  ; res@tiMainString            =  filename(ifile) + " ("+ dimsizes(ke) + " cells)"
  res@tiMainString            =  "" ;"CA RRM grids (CA_ne32_x32)"
  ; plot = gsn_csm_contour_map(wks,ke,res)

  gsres                            = True
  gsres@gsnCoordsMeshLatBounds     = cy
  gsres@gsnCoordsMeshLonBounds     = cx
  gsres@gsnCoordsMeshClosePolygons = True      ; necessary to get fully closed polygons
  gsres@gsMarkerColor              = "Blue"   ; color to use for cell centers
  gsres@gsLineColor                = "gray30"   ; color to use for cell edges
  gsres@gsMarkerSizeF              = 1.0
  gsres@gsLineThicknessF           = 0.4;0.2

  res2=res
  projection_type="CylindricalEquidistant"
  res2@mpProjection=projection_type
  res2@mpProjection="Orthographic"
  plot = gsn_csm_map(wks, res2)
  ;---plot the first global mesh
  gsn_coordinates(wks,plot,(/ke/),gsres)


  ;---Zoom into the region of interest
  res@mpLimitMode                 = "LatLon"
  res@mpCenterLatF                = mpCenterLatF
  res@mpCenterLonF                = mpCenterLonF
  res@mpMinLatF                   = res@mpCenterLatF-lat_width/2.
  res@mpMaxLatF                   = res@mpCenterLatF+lat_width/2.
  res@mpMinLonF                   = res@mpCenterLonF-lon_width/2.
  res@mpMaxLonF                   = res@mpCenterLonF+lon_width/2.

  res@mpOutlineOn                 = True
  res@mpOutlineBoundarySets       = "AllBoundaries" ;"USStates"
  res@mpLandFillColor             = "gray85"
  res@mpOceanFillColor            = -1
  res@mpInlandWaterFillColor      = -1

  res@mpUSStateLineColor          = "green"
  res@mpUSStateLineThicknessF     = 3.
  res@mpNationalLineColor         = res@mpUSStateLineColor
  res@mpNationalLineThicknessF    = res@mpUSStateLineThicknessF * 2.0
  res@mpGeophysicalLineColor      = res@mpUSStateLineColor
  res@mpGeophysicalLineThicknessF = res@mpUSStateLineThicknessF
  res@mpCountyLineColor           = res@mpUSStateLineColor
  res@mpDataBaseVersion           = "Ncarg4_1"

  plot = gsn_csm_map(wks, res)
  ;---plot the second zoom in mesh
  gsn_coordinates(wks,plot,(/ke/),gsres)

  delete([/cx,cy,ke,res,res2,gsres/])
end do ;ifile

end