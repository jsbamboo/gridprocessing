import numpy as np
import os
import xarray as xr
import subprocess
from datetime import datetime


mach = 'LC'
mach = 'perlm'
if mach == 'LC':
    path_grid = '/p/lustre2/zhang73/grids2/'
if mach == 'perlm':
    path_grid = '/global/cfs/cdirs/e3sm/zhang73/grids2/'


#=======================================================================================================
def main():
    RRMgrid = 'Chilene32x32v1'
    shp_name = 'Chilebuffer'
    cdate = datetime.now().strftime("%Y%m%d")

    shp_file = f'{path_grid}shp_mask/{shp_name}.shp_mask_landfrac.{RRMgrid}pg2.nc'
    
    output_dir = f'{path_grid}/{RRMgrid}/gridprocessing/'
    os.makedirs(output_dir, exist_ok=True)
    mapping_output_file = os.path.join(
        output_dir,
        f'map_{RRMgrid}pg2_to_{shp_name}.pg2icol_shp.{cdate}.nc'
    )

    print(f"Find the shpmask pg2 icols with model file {shp_file} ...")
    save_shpmask_icol_mappings_to_netcdf(shp_file, mapping_output_file)


#=======================================================================================================
def save_shpmask_icol_mappings_to_netcdf(shp_file, mapping_output_file):
    ncol, shp_mask = load_shpmask_data(shp_file)

    # Select source grid columns inside the shapefile mask
    # Assuming shp_mask == 1 means inside the mask
    valid = shp_mask == 1
    icols_0based = np.where(valid)[0]

    if len(icols_0based) == 0:
        raise ValueError("No grid cells found with shp_mask == 1.")

    print(f"Total ncol = {ncol}")
    print(f"Selected masked columns = {len(icols_0based)}")

    save_mapping_netcdf(
        output_file=mapping_output_file,
        icols_0based=icols_0based,
        ncol=ncol
    )


#=======================================================================================================
def load_shpmask_data(shp_file):
    ds = xr.open_dataset(shp_file)

    ncol = ds.sizes["ncol"]

    # Find the shp_mask variable automatically
    mask_vars = [v for v in ds.data_vars if v.startswith("shp_mask")]
    if len(mask_vars) != 1:
        raise ValueError(f"Expected exactly one shp_mask variable, found: {mask_vars}")

    shp_mask = ds[mask_vars[0]].values

    ds.close()

    return ncol, shp_mask


#=======================================================================================================
def save_mapping_netcdf(output_file, icols_0based, ncol):
    """
    Mapping convention:
      col = source grid column, 1-based
      row = destination index, 1-based
      S   = mapping weight, here always 1

    Here each selected PG2 grid cell maps to one destination row.
    """

    n_s = len(icols_0based)

    # col is source global grid index, converted to 1-based
    col = icols_0based.astype(np.int32) + 1

    # row is destination grid index, also 1-based
    row = np.arange(1, n_s + 1, dtype=np.int32)

    S = np.ones(n_s, dtype=np.float32)

    ds_map = xr.Dataset(
        {
            "col": ("n_s", col),
            "row": ("n_s", row),
            "S": ("n_s", S),
            "icol_0based": ("n_s", icols_0based.astype(np.int32)),
        },
        coords={
            "n_s": np.arange(n_s, dtype=np.int32),
            "n_a": np.arange(ncol, dtype=np.int32),
            "n_b": np.arange(n_s, dtype=np.int32),
        },
        attrs={
            "description": "Mapping from global RRM PG2 grid columns to shapefile-mask destination columns",
            "convention": "col and row are 1-based; S is mapping weight",
            "source_ncol": int(ncol),
            "destination_ncol": int(n_s),
        }
    )

    ds_map["col"].attrs = {
        "long_name": "source grid column index",
        "index_base": "1-based",
    }
    ds_map["row"].attrs = {
        "long_name": "destination grid row index",
        "index_base": "1-based",
    }
    ds_map["S"].attrs = {
        "long_name": "mapping weights",
        "description": "All weights are 1 because this mapping directly extracts selected source columns",
    }
    ds_map["icol_0based"].attrs = {
        "long_name": "source grid column index in Python/xarray convention",
        "index_base": "0-based",
    }

    ds_map.to_netcdf(output_file)
    print(f"Mapping NetCDF saved to: {output_file}")

    output_file_cdf5 = output_file.replace(".nc", ".5.nc")
    convert_to_cdf5_ncks(output_file, output_file_cdf5)


#=======================================================================================================
def convert_to_cdf5_ncks(input_file, output_file):
    cmd = ["ncks", "-O", "-5", input_file, output_file]
    try:
        subprocess.check_call(cmd)
        print(f"Converted to CDF-5 using NCO: {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to convert to CDF-5: {e}")


#=======================================================================================================
if __name__ == "__main__":
    main()