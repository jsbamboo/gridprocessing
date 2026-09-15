#!/bin/bash

# Input file paths - modify these as needed
export SST_INPUT_FILE="/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/sst.mon.mean.nc"
export ICEC_INPUT_FILE="/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/icec.mon.mean.nc"
export SST_OUTPUT_DIR="/p/lustre1/tang30/nudging/jsz_gridprocessing/shared/NOAA_monthly_sst_seaice/"

# Load required modules for NCL
module load StdEnv gcc/13.3.1 mvapich2/2.3.7 ncl/6.6.2

# Load e3sm-unified environment for ncks (NCO tools)
# source /usr/workspace/e3sm/apps/e3sm-unified/load_latest_e3sm_unified_dane.sh

# Run NCL script
cd /p/lustre1/tang30/nudging/jsz_gridprocessing/shared/NOAA_monthly_sst_seaice

echo "========================================="
echo "NCL SST/ICEC Processing"
echo "========================================="
echo "Input SST file:  $SST_INPUT_FILE"
echo "Input ICEC file: $ICEC_INPUT_FILE"
echo "Output directory: $SST_OUTPUT_DIR"
echo "========================================="
echo "Starting NCL processing at $(date)"
echo "This may take 30-60 minutes for 539 time steps..."
echo ""

ncl process_sst_icec.ncl

echo ""
echo "NCL processing completed at $(date)"
