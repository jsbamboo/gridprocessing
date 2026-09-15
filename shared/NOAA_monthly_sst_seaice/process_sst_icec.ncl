begin

; ============================================================
; Script to process NOAA monthly SST and sea ice concentration
; Version 2: With progress monitoring and time-step processing
; ============================================================

print("=========================================")
print("Starting NCL script...")
print("=========================================")

exp_name = "monthly"
; Generate creation date in YYYYMMDD format
date_make = "c" + systemfunc("date +%Y%m%d")

; Get input file paths from environment variables (with defaults)
sst_input = getenv("SST_INPUT_FILE")
if (ismissing(sst_input) .or. sst_input .eq. "") then
    sst_input = "/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/sst.mon.mean.nc"
    print("Warning: SST_INPUT_FILE not set, using default: " + sst_input)
end if

icec_input = getenv("ICEC_INPUT_FILE")
if (ismissing(icec_input) .or. icec_input .eq. "") then
    icec_input = "/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/icec.mon.mean.nc"
    print("Warning: ICEC_INPUT_FILE not set, using default: " + icec_input)
end if

; Get output directory from environment variable (with default)
outdir = getenv("SST_OUTPUT_DIR")
if (ismissing(outdir) .or. outdir .eq. "") then
    outdir = systemfunc("pwd") + "/"
    print("Warning: SST_OUTPUT_DIR not set, using current directory: " + outdir)
end if

; Output file
outfile = "sst_icec.mon.mean.combined." + date_make + ".nc"

print("Reading input files...")
print("SST file:  " + sst_input)
print("ICEC file: " + icec_input)

; Read SST data
f_sst = addfile(sst_input, "r")
sst_in = f_sst->sst
time_in = f_sst->time
lat = f_sst->lat
lon = f_sst->lon

; Store global attributes from input files for provenance
sst_att_names = getvaratts(f_sst)

dims_sst = dimsizes(sst_in)
print("SST dimensions: " + dims_sst(0) + " x " + dims_sst(1) + " x " + dims_sst(2))

; Read ice concentration data
f_icec = addfile(icec_input, "r")
icec_in = f_icec->icec

; Store global attributes from ice concentration file
icec_att_names = getvaratts(f_icec)

dims_icec = dimsizes(icec_in)
print("ICEC dimensions: " + dims_icec(0) + " x " + dims_icec(1) + " x " + dims_icec(2))

; ============================================================
; Step 1: Fill missing values in SST time-step by time-step
; ============================================================
ntimes = dimsizes(time_in)
print("=========================================")
print("Filling missing values in SST...")
print("Processing " + ntimes + " time steps")
print("=========================================")

sst_fill = sst_in
; Process each time step individually to show progress
do it = 0, ntimes-1
    if (mod(it, 10) .eq. 0) then
        print("Processing time step " + it + " of " + ntimes + "...")
    end if

    ; Fill this time step if it has missing values
    if (any(ismissing(sst_in(it,:,:)))) then
        poisson_grid_fill(sst_fill(it,:,:), True, 1, 1500, 1e-2, 0.6, 0)
    end if
end do

min_sst = min(sst_fill)
max_sst = max(sst_fill)
print("SST filling complete!")
print("Min SST: " + min_sst + ", Max SST: " + max_sst)

; ============================================================
; Step 2: Process data following fmt-streamfile format
; ============================================================
print("=========================================")
print("Processing data for output...")
print("=========================================")

; Handle SST: set missing values to -1.8 (freezing point)
sst = where(ismissing(sst_fill), -1.8, sst_fill)

; Handle ice concentration: set missing to 0
ice_cov = where(ismissing(icec_in), 0, icec_in)

; Process time coordinate
time = time_in
time@calendar = "gregorian"
time!0 = "time"
time@long_name = "time"
time&time = time

; Create date variable (YYYYMMDD format)
date = (/cd_calendar(time, -2)/)
date@long_name = "current date (YYYYMMDD)"

; Create datesec variable (seconds of current date)
YYMMDDHH = cd_calendar(time, -3)
HH = toint(str_get_cols(YYMMDDHH, -2, -1))
datesec = HH * 3600
datesec@long_name = "current seconds of current date"

; Set coordinate attributes for date and datesec
date!0 = "time"
datesec!0 = "time"
date&time = time
datesec&time = time

; Set coordinate attributes for sst and ice_cov
sst!0 = "time"
ice_cov!0 = "time"
sst&time = time
ice_cov&time = time
sst!1 = "lat"
sst!2 = "lon"
sst&lat = lat
sst&lon = lon
ice_cov!1 = "lat"
ice_cov!2 = "lon"
ice_cov&lat = lat
ice_cov&lon = lon

; Copy and modify variable attributes
copy_VarAtts(sst_in, sst)
copy_VarAtts(icec_in, ice_cov)

; Modify ice_cov units to fraction
ice_cov@units = "fraction"

; Remove FillValue and missing_value attributes
delete_VarAtts(sst, (/"_FillValue", "missing_value", "history"/))
delete_VarAtts(ice_cov, (/"_FillValue", "missing_value", "history"/))

min_sst_final = min(sst)
max_sst_final = max(sst)
min_ice = min(ice_cov)
max_ice = max(ice_cov)
print("Final SST range: " + min_sst_final + " to " + max_sst_final)
print("Final ice_cov range: " + min_ice + " to " + max_ice)

; ============================================================
; Step 3: Write output file
; ============================================================
print("=========================================")
print("Creating output file...")
print("=========================================")

; Remove existing output file if present
system("/bin/rm -f " + outdir + outfile)

; Create new output file
fout = addfile(outdir + outfile, "c")

; Define dimensions
dimNames = (/"time", "lat", "lon"/)
dimSizes = (/-1, dimsizes(lat), dimsizes(lon)/)
dimUnlim = (/True, False, False/)
filedimdef(fout, dimNames, dimSizes, dimUnlim)

; Add global attributes
nl = integertochar(10)
globalAtt = True

; Get current script path dynamically
script_path = get_script_name()
if (ismissing(script_path)) then
    script_path = systemfunc("readlink -f process_sst_icec.ncl")
end if

; Copy relevant global attributes from input files for provenance
; From SST file
do i = 0, dimsizes(sst_att_names) - 1
    att_name = sst_att_names(i)
    ; Skip certain attributes that will be overwritten
    if (att_name .ne. "history" .and. att_name .ne. "Conventions" .and. \
        att_name .ne. "source" .and. att_name .ne. "title") then
        new_att_name = "source_sst_" + att_name
        globalAtt@$new_att_name$ = f_sst@$att_name$
    end if
end do

; From ICEC file
do i = 0, dimsizes(icec_att_names) - 1
    att_name = icec_att_names(i)
    ; Skip certain attributes that will be overwritten
    if (att_name .ne. "history" .and. att_name .ne. "Conventions" .and. \
        att_name .ne. "source" .and. att_name .ne. "title") then
        new_att_name = "source_icec_" + att_name
        globalAtt@$new_att_name$ = f_icec@$att_name$
    end if
end do

; Add processing history and metadata
globalAtt@history = nl + \
      systemfunc("date") + ": ncl < " + script_path + nl + \
      "  - Filled SST missing values using Poisson grid fill (time-step by time-step)" + nl + \
      "  - Combined SST and ICEC into single file"
globalAtt@Conventions = "CF-1.5"
globalAtt@source_sst = sst_input
globalAtt@source_icec = icec_input
globalAtt@creation_date = systemfunc("date +%Y%m%d")
globalAtt@created_by = systemfunc("whoami")
globalAtt@created_on_system = systemfunc("hostname")
globalAtt@processor = "NCL " + get_ncl_version()
fileattdef(fout, globalAtt)

; Write all variables
print("Writing variables to output file...")
fout->date = date
fout->datesec = datesec
fout->lat = lat
fout->lon = lon
fout->time = time
fout->SST_cpl = sst
fout->ice_cov = ice_cov

print("=========================================")
print("Output file created successfully:")
print(outdir + outfile)
print("=========================================")
print("Variables written:")
print("  - date    (YYYYMMDD)")
print("  - datesec (seconds of day)")
print("  - time    (coordinate)")
print("  - lat     (coordinate)")
print("  - lon     (coordinate)")
print("  - SST_cpl (filled SST)")
print("  - ice_cov (ice concentration fraction)")
print("=========================================")

; ============================================================
; Step 4: Convert to PnetCDF/CDF5 format using ncks
; ============================================================
print("=========================================")
print("Converting to PnetCDF/CDF5 format...")
print("=========================================")

temp_file = outdir + outfile + ".tmp"
cmd = "ncks -5 -O " + outdir + outfile + " " + temp_file
print("Running: " + cmd)
status = systemfunc(cmd)
print(status)

; Replace original file with converted version
system("mv " + temp_file + " " + outdir + outfile)
print("Conversion complete!")
print("Final output: " + outdir + outfile)
print("=========================================")

end
