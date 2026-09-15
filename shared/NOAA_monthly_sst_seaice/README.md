# NOAA Monthly SST and Sea Ice Processing

This directory contains an NCL script for processing NOAA monthly sea surface temperature (SST) and sea ice concentration (ICEC) data.

## Script: process_sst_icec.ncl

### Purpose
This script performs two main operations:
1. **Fill missing values in SST** using Poisson grid fill method
2. **Combine SST and ICEC data** into a single output file

### Input Files
The script expects two input files in the parent directory:
- `sst.mon.mean.nc` - Monthly mean sea surface temperature
- `icec.mon.mean.nc` - Monthly mean sea ice concentration

Both files should have:
- Dimensions: time (unlimited), lat (720), lon (1440)
- Resolution: 0.25 degrees
- Time units: days since 1800-01-01 00:00:00

### Output
The script creates a combined file: `sst_icec.mon.mean.combined.c260901.nc`

Output variables (following grid_WL.sst_NOAA.1.fmt-streamfile.ncl format):
- `SST_cpl` - SST with missing values filled (missing values set to -1.8°C)
- `ice_cov` - Ice concentration as fraction (missing values set to 0)
- `date` - Current date in YYYYMMDD format
- `datesec` - Current seconds of the day
- Coordinate variables: `time`, `lat`, `lon`

### Usage
Run the script using NCL:
```bash
cd /p/lustre1/tang30/nudging/jishi_gridprocessing/WPRRMxx/scripts/NOAA_monthly_sst_seaice
ncl process_sst_icec.ncl
```

### Method Details

#### Poisson Grid Fill
The script uses NCL's `poisson_grid_fill` function to fill missing values in SST:
- Uses cyclic boundary conditions (longitude wraps around)
- Initial guess: zonal mean
- Maximum iterations: 1500
- Convergence criterion: 1e-2
- Relaxation coefficient: 0.6

This method is effective for filling data gaps by solving Poisson's equation with appropriate boundary conditions.

#### Data Processing
Following the format of `grid_WL.sst_NOAA.1.fmt-streamfile.ncl`:
- **SST**: After Poisson fill, remaining missing values are set to -1.8°C (freezing point)
- **Ice concentration**: Converted to fraction, missing values set to 0
- **Time variables**: Creates `date` (YYYYMMDD) and `datesec` (seconds of day)
- **Attributes**: Removes `_FillValue` and `missing_value` attributes from final output

### References
Based on example codes:
- `grid_WL.sst_NOAA.0.fillmsg.ncl` - Fill value handling
- `grid_WL.sst_NOAA.1.fmt-streamfile.ncl` - File combination and formatting

### Notes
- Output variable names (`SST_cpl`, `ice_cov`) follow the convention from `grid_WL.sst_NOAA.1.fmt-streamfile.ncl`
- The script creates time coordinate variables (`date`, `datesec`) for compatibility with E3SM/CESM input format
- Missing SST values are set to -1.8°C (approximate ocean freezing point)
- Missing ice concentration values are set to 0 (no ice)
- The output file uses CF-1.5 conventions
