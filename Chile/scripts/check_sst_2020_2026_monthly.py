"""Read-only monthly full-ocean SST check for the c260914 concatenated file."""
from pathlib import Path
from datetime import date, timedelta
import csv
import numpy as np
from netCDF4 import Dataset, num2date

ROOT = Path('/global/cfs/cdirs/e3sm/zhang73/DATA/data_hiccup')
TARGET = ROOT / 'sst_ice.daymean.20200101_20260602_noleap.fillmsg.fmt-c260914.nc'

def decoded(f):
    t = f['time']
    return [x.strftime('%Y%m%d') for x in num2date(t[:], t.units, getattr(t, 'calendar', 'standard'))]

def main():
    expected = []
    d = date(2020, 1, 1)
    while d <= date(2026, 6, 2):
        if (d.month, d.day) != (2, 29):
            expected.append(d.strftime('%Y%m%d'))
        d += timedelta(days=1)
    rows = []
    with Dataset(TARGET) as f:
        ds = decoded(f)
        checks = {
            'records_2343': len(ds) == 2343,
            'calendar_365_day': f['time'].calendar == '365_day',
            'all_dates_continuous_and_expected': ds == expected,
            'time_continuous_half_days': np.array_equal(f['time'][:], np.arange(len(expected)) + .5),
            'date_variable_correct': np.array_equal(f['date'][:], np.array(expected, dtype='i4')),
            'datesec_all_43200': bool(np.all(f['datesec'][:] == 43200)),
        }
        print('TIME CHECKS', checks, flush=True)
        assert all(checks.values())
        for year in range(2020, 2027):
            p = ROOT / f'sst.day.mean.{year}.nc'
            if year == 2026:
                p = ROOT / '_err_noleap_/sst.day.mean.20260101-20260602.nc'
            with Dataset(p) as raw:
                assert all(np.array_equal(f[k][:], raw[k][:]) for k in ('lat', 'lon'))
                rd = decoded(raw)
                j = int(np.argmin(abs(raw['lat'][:] + 30)))
                i = int(np.argmin(abs(raw['lon'][:] - 280)))
                for month in range(1, 7 if year == 2026 else 13):
                    day = f'{year}{month:02d}01'
                    r = raw['sst'][rd.index(day)]
                    n = f['SST_cpl'][ds.index(day)]
                    valid = ~np.ma.getmaskarray(r) & np.isfinite(r.data)
                    assert np.count_nonzero(valid) > 0
                    assert not np.any(np.ma.getmaskarray(n)[valid])
                    a, b = np.asarray(n)[valid], r.data[valid]
                    diff = np.abs(a.astype('f8') - b.astype('f8'))
                    row = {'date': day, 'ocean_cells': int(a.size),
                           'different_cells': int(np.count_nonzero(a != b)),
                           'max_abs_error_C': float(diff.max()),
                           'sample_raw_C': float(r[j, i]), 'sample_merged_C': float(n[j, i]),
                           'raw_file': str(p)}
                    rows.append(row)
                    print(day, row['ocean_cells'], row['different_cells'], row['max_abs_error_C'], flush=True)
        # Check the final date as well as all 78 month starts.
        with Dataset(ROOT / '_err_noleap_/sst.day.mean.20260101-20260602.nc') as raw:
            r = raw['sst'][decoded(raw).index('20260602')]
            n = f['SST_cpl'][-1]
            mask = ~np.ma.getmaskarray(r) & np.isfinite(r.data)
            assert np.array_equal(np.asarray(n)[mask], r.data[mask])
            print('ENDPOINT 20260602: exact ocean match', flush=True)
    output = Path('/tmp/sst_2020_2026_monthly_validation.csv')
    with output.open('w') as fp:
        w = csv.DictWriter(fp, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print('SUMMARY', {'months': len(rows), 'ocean_values': sum(r['ocean_cells'] for r in rows),
                       'different_values': sum(r['different_cells'] for r in rows),
                       'max_abs_error_C': max(r['max_abs_error_C'] for r in rows), 'csv': str(output)}, flush=True)
    assert len(rows) == 78 and all(r['different_cells'] == 0 for r in rows)

if __name__ == '__main__':
    main()
