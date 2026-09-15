# SST and Ice Concentration Comparison Analysis

## Overview
The `compare_sst_icec.py` script performs a comprehensive comparison between the input files (original SST and ice concentration) and the processed output file, generating detailed visualizations.

## Requirements
```bash
pip install numpy matplotlib netCDF4 cartopy
```

Or if using conda:
```bash
conda install numpy matplotlib netCDF4 cartopy
```

## Usage
```bash
cd /p/lustre1/tang30/nudging/jishi_gridprocessing/WPRRMxx/scripts/NOAA_monthly_sst_seaice
python compare_sst_icec.py
```

Or run directly:
```bash
./compare_sst_icec.py
```

## Output Figures

The script creates three main figures in the `figures/` subdirectory:

### 1. timeseries_comparison.png
Three time series plots showing:
- **Top panel**: Number of missing values over time (original vs filled)
- **Middle panel**: Global mean SST over time (original vs filled)
- **Bottom panel**: Global mean ice concentration over time (original vs output)

This shows how the data quality and values change over the entire time series.

### 2. spatial_comparison.png
Six spatial maps for a sample time step (middle of the time series):
- **Top row**: Original SST (left) vs Filled SST (right)
- **Middle row**: Missing value mask in original (left) vs Filled regions at -1.8°C (right)
- **Bottom row**: Original ice concentration (left) vs Output ice_cov (right)

This provides a visual comparison of the spatial patterns and where filling occurred.

### 3. histograms.png
Four histogram plots showing data distributions:
- **Top row**: Original SST distribution (left) vs Filled SST distribution (right)
- **Bottom row**: Original ice concentration distribution (left) vs Output ice_cov distribution (right)

Log scale is used on y-axis to show the full range of values.

## Statistics Reported

The script prints comprehensive statistics including:
- Number and percentage of missing values (original vs filled)
- SST value ranges (original vs filled)
- Ice concentration ranges (original vs output)
- Time step information

## Files Compared

**Input files:**
- `sst.mon.mean.nc` - Original monthly mean SST
- `icec.mon.mean.nc` - Original monthly mean ice concentration

**Output file:**
- `sst_icec.mon.mean.combined.c260901.nc` - Processed combined file

## Key Differences to Look For

1. **Missing value handling**: Original missing values should be filled with -1.8°C or interpolated
2. **Ice concentration units**: Original may be in percent, output should be in fraction (0-1)
3. **Data continuity**: Filled SST should show smooth transitions where gaps were filled
4. **Spatial coverage**: Output should have fewer missing values in ocean regions
