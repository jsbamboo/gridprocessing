#!/usr/bin/env python3
"""
Compare SST and sea ice data between input and output files
Generate figures showing differences and improvements from processing
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from netCDF4 import Dataset
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from datetime import datetime

print("=" * 60)
print("Starting comparison analysis...")
print("=" * 60)

# File paths
indir = "/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/"
outdir = "/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/NOAA_monthly_sst_seaice/"

sst_file = indir + "sst.mon.mean.nc"
icec_file = indir + "icec.mon.mean.nc"

# Find the most recent output file (matches pattern sst_icec.mon.mean.combined.c*.nc)
import glob
output_files = sorted(glob.glob(outdir + "sst_icec.mon.mean.combined.c*.nc"))
if not output_files:
    raise FileNotFoundError(f"No output files found matching pattern: {outdir}sst_icec.mon.mean.combined.c*.nc")
output_file = output_files[-1]  # Use the most recent one

# Output figure directory
figdir = outdir + "figures/"
import os
os.makedirs(figdir, exist_ok=True)

print(f"Input SST file:  {sst_file}")
print(f"Input ICEC file: {icec_file}")
print(f"Output file:     {output_file}")
print(f"Figure directory: {figdir}")
print()

# Read input files
print("Reading input files...")
nc_sst_in = Dataset(sst_file, 'r')
nc_icec_in = Dataset(icec_file, 'r')
nc_out = Dataset(output_file, 'r')

sst_orig = nc_sst_in.variables['sst'][:]
icec_orig = nc_icec_in.variables['icec'][:]
lat_in = nc_sst_in.variables['lat'][:]
lon_in = nc_sst_in.variables['lon'][:]
time_in = nc_sst_in.variables['time'][:]

sst_filled = nc_out.variables['SST_cpl'][:]
ice_cov = nc_out.variables['ice_cov'][:]
lat_out = nc_out.variables['lat'][:]
lon_out = nc_out.variables['lon'][:]
time_out = nc_out.variables['time'][:]

print(f"SST original shape: {sst_orig.shape}")
print(f"SST filled shape:   {sst_filled.shape}")
print(f"ICEC original shape: {icec_orig.shape}")
print(f"ice_cov shape:       {ice_cov.shape}")
print()

# Calculate statistics
print("Calculating statistics...")
n_missing_orig = np.sum(np.isnan(sst_orig.data) | sst_orig.mask if hasattr(sst_orig, 'mask') else np.isnan(sst_orig))
n_missing_filled = np.sum(sst_filled == -1.8)  # Check for the fill value
n_total = sst_orig.size

print(f"Original SST missing values: {n_missing_orig} ({100*n_missing_orig/n_total:.3f}%)")
print(f"Filled SST at -1.8°C: {n_missing_filled} ({100*n_missing_filled/n_total:.3f}%)")
print(f"SST range - Original: [{np.nanmin(sst_orig):.2f}, {np.nanmax(sst_orig):.2f}] °C")
print(f"SST range - Filled:   [{np.min(sst_filled):.2f}, {np.max(sst_filled):.2f}] °C")
print(f"Ice range - Original: [{np.nanmin(icec_orig):.4f}, {np.nanmax(icec_orig):.4f}]")
print(f"Ice range - Output:   [{np.min(ice_cov):.4f}, {np.max(ice_cov):.4f}]")
print()

# =============================================================================
# Figure 1: Time series comparison
# =============================================================================
print("Creating Figure 1: Time series comparison...")
fig, axes = plt.subplots(3, 1, figsize=(12, 10))

# Plot 1: Number of missing values over time
missing_per_time_orig = np.sum(np.isnan(sst_orig.data) | sst_orig.mask if hasattr(sst_orig, 'mask') else np.isnan(sst_orig), axis=(1, 2))
missing_per_time_filled = np.sum(sst_filled == -1.8, axis=(1, 2))

axes[0].plot(range(len(time_in)), missing_per_time_orig, 'b-', linewidth=1.5, label='Original missing')
axes[0].plot(range(len(time_out)), missing_per_time_filled, 'r--', linewidth=1.5, label='Filled at -1.8°C')
axes[0].set_xlabel('Time Step', fontsize=11)
axes[0].set_ylabel('Number of Missing/Filled Points', fontsize=11)
axes[0].set_title('Missing Values Over Time', fontsize=12, fontweight='bold')
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Plot 2: Mean SST over time
mean_sst_orig = np.nanmean(sst_orig, axis=(1, 2))
mean_sst_filled = np.mean(sst_filled, axis=(1, 2))

axes[1].plot(range(len(time_in)), mean_sst_orig, 'b-', linewidth=1.5, label='Original SST')
axes[1].plot(range(len(time_out)), mean_sst_filled, 'r-', linewidth=1.5, label='Filled SST')
axes[1].set_xlabel('Time Step', fontsize=11)
axes[1].set_ylabel('Mean SST (°C)', fontsize=11)
axes[1].set_title('Global Mean SST Over Time', fontsize=12, fontweight='bold')
axes[1].legend()
axes[1].grid(True, alpha=0.3)

# Plot 3: Mean ice coverage over time
mean_ice_orig = np.nanmean(icec_orig, axis=(1, 2))
mean_ice_out = np.mean(ice_cov, axis=(1, 2))

axes[2].plot(range(len(time_in)), mean_ice_orig, 'b-', linewidth=1.5, label='Original ICEC')
axes[2].plot(range(len(time_out)), mean_ice_out, 'r-', linewidth=1.5, label='Output ice_cov')
axes[2].set_xlabel('Time Step', fontsize=11)
axes[2].set_ylabel('Mean Ice Fraction', fontsize=11)
axes[2].set_title('Global Mean Ice Concentration Over Time', fontsize=12, fontweight='bold')
axes[2].legend()
axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(figdir + 'timeseries_comparison.png', dpi=300, bbox_inches='tight')
print(f"Saved: {figdir}timeseries_comparison.png")
plt.close()

# =============================================================================
# Figure 2: Spatial comparison for a sample time step (middle of time series)
# =============================================================================
print("Creating Figure 2: Spatial comparison maps...")
t_sample = len(time_in) // 2  # Middle time step

fig = plt.figure(figsize=(16, 12))

# Create 2D meshgrid for plotting
lon_2d, lat_2d = np.meshgrid(lon_in, lat_in)

# Plot 1: Original SST
ax1 = plt.subplot(3, 2, 1, projection=ccrs.PlateCarree())
im1 = ax1.pcolormesh(lon_2d, lat_2d, sst_orig[t_sample, :, :],
                      transform=ccrs.PlateCarree(),
                      cmap='RdYlBu_r', vmin=-2, vmax=32)
ax1.coastlines(linewidth=0.5)
ax1.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax1.set_title(f'Original SST (t={t_sample})', fontsize=11, fontweight='bold')
plt.colorbar(im1, ax=ax1, orientation='horizontal', pad=0.05, label='SST (°C)')

# Plot 2: Filled SST
ax2 = plt.subplot(3, 2, 2, projection=ccrs.PlateCarree())
im2 = ax2.pcolormesh(lon_2d, lat_2d, sst_filled[t_sample, :, :],
                      transform=ccrs.PlateCarree(),
                      cmap='RdYlBu_r', vmin=-2, vmax=32)
ax2.coastlines(linewidth=0.5)
ax2.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax2.set_title(f'Filled SST (t={t_sample})', fontsize=11, fontweight='bold')
plt.colorbar(im2, ax=ax2, orientation='horizontal', pad=0.05, label='SST (°C)')

# Plot 3: Missing mask in original
ax3 = plt.subplot(3, 2, 3, projection=ccrs.PlateCarree())
missing_mask = np.isnan(sst_orig[t_sample, :, :].data) | sst_orig[t_sample, :, :].mask if hasattr(sst_orig[t_sample, :, :], 'mask') else np.isnan(sst_orig[t_sample, :, :])
im3 = ax3.pcolormesh(lon_2d, lat_2d, missing_mask.astype(float),
                      transform=ccrs.PlateCarree(),
                      cmap='Reds', vmin=0, vmax=1)
ax3.coastlines(linewidth=0.5)
ax3.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax3.set_title('Missing Values in Original SST', fontsize=11, fontweight='bold')
plt.colorbar(im3, ax=ax3, orientation='horizontal', pad=0.05, label='Missing (1=yes)')

# Plot 4: Filled regions
ax4 = plt.subplot(3, 2, 4, projection=ccrs.PlateCarree())
filled_mask = (sst_filled[t_sample, :, :] == -1.8).astype(float)
im4 = ax4.pcolormesh(lon_2d, lat_2d, filled_mask,
                      transform=ccrs.PlateCarree(),
                      cmap='Oranges', vmin=0, vmax=1)
ax4.coastlines(linewidth=0.5)
ax4.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax4.set_title('Filled at -1.8°C in Output', fontsize=11, fontweight='bold')
plt.colorbar(im4, ax=ax4, orientation='horizontal', pad=0.05, label='Filled (1=yes)')

# Plot 5: Original Ice
ax5 = plt.subplot(3, 2, 5, projection=ccrs.PlateCarree())
im5 = ax5.pcolormesh(lon_2d, lat_2d, icec_orig[t_sample, :, :],
                      transform=ccrs.PlateCarree(),
                      cmap='Blues', vmin=0, vmax=1)
ax5.coastlines(linewidth=0.5)
ax5.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax5.set_title(f'Original Ice Conc. (t={t_sample})', fontsize=11, fontweight='bold')
plt.colorbar(im5, ax=ax5, orientation='horizontal', pad=0.05, label='Ice Fraction')

# Plot 6: Output Ice
ax6 = plt.subplot(3, 2, 6, projection=ccrs.PlateCarree())
im6 = ax6.pcolormesh(lon_2d, lat_2d, ice_cov[t_sample, :, :],
                      transform=ccrs.PlateCarree(),
                      cmap='Blues', vmin=0, vmax=1)
ax6.coastlines(linewidth=0.5)
ax6.add_feature(cfeature.LAND, facecolor='lightgray', alpha=0.3)
ax6.set_title(f'Output ice_cov (t={t_sample})', fontsize=11, fontweight='bold')
plt.colorbar(im6, ax=ax6, orientation='horizontal', pad=0.05, label='Ice Fraction')

plt.tight_layout()
plt.savefig(figdir + 'spatial_comparison.png', dpi=300, bbox_inches='tight')
print(f"Saved: {figdir}spatial_comparison.png")
plt.close()

# =============================================================================
# Figure 3: Histograms
# =============================================================================
print("Creating Figure 3: Data distribution histograms...")
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

# SST histograms
axes[0, 0].hist(sst_orig.flatten()[~np.isnan(sst_orig.flatten())], bins=100,
                alpha=0.7, label='Original SST', color='blue', edgecolor='black')
axes[0, 0].set_xlabel('SST (°C)', fontsize=11)
axes[0, 0].set_ylabel('Frequency', fontsize=11)
axes[0, 0].set_title('Original SST Distribution', fontsize=12, fontweight='bold')
axes[0, 0].set_yscale('log')
axes[0, 0].grid(True, alpha=0.3)
axes[0, 0].legend()

axes[0, 1].hist(sst_filled.flatten(), bins=100,
                alpha=0.7, label='Filled SST', color='red', edgecolor='black')
axes[0, 1].set_xlabel('SST (°C)', fontsize=11)
axes[0, 1].set_ylabel('Frequency', fontsize=11)
axes[0, 1].set_title('Filled SST Distribution', fontsize=12, fontweight='bold')
axes[0, 1].set_yscale('log')
axes[0, 1].grid(True, alpha=0.3)
axes[0, 1].legend()

# Ice histograms
axes[1, 0].hist(icec_orig.flatten()[~np.isnan(icec_orig.flatten())], bins=100,
                alpha=0.7, label='Original ICEC', color='blue', edgecolor='black')
axes[1, 0].set_xlabel('Ice Fraction', fontsize=11)
axes[1, 0].set_ylabel('Frequency', fontsize=11)
axes[1, 0].set_title('Original Ice Concentration Distribution', fontsize=12, fontweight='bold')
axes[1, 0].set_yscale('log')
axes[1, 0].grid(True, alpha=0.3)
axes[1, 0].legend()

axes[1, 1].hist(ice_cov.flatten(), bins=100,
                alpha=0.7, label='Output ice_cov', color='red', edgecolor='black')
axes[1, 1].set_xlabel('Ice Fraction', fontsize=11)
axes[1, 1].set_ylabel('Frequency', fontsize=11)
axes[1, 1].set_title('Output ice_cov Distribution', fontsize=12, fontweight='bold')
axes[1, 1].set_yscale('log')
axes[1, 1].grid(True, alpha=0.3)
axes[1, 1].legend()

plt.tight_layout()
plt.savefig(figdir + 'histograms.png', dpi=300, bbox_inches='tight')
print(f"Saved: {figdir}histograms.png")
plt.close()

# Close netCDF files
nc_sst_in.close()
nc_icec_in.close()
nc_out.close()

print()
print("=" * 60)
print("Comparison analysis complete!")
print(f"All figures saved to: {figdir}")
print("=" * 60)
