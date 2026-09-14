"""Read-only, full-grid validation of NOAA 2020 SST noleap outputs.
Run with the all_stablee Python environment. Reports are written beside this script.
"""
from pathlib import Path
import csv
import json
import numpy as np
from netCDF4 import Dataset, num2date

ROOT = Path('/global/cfs/cdirs/e3sm/zhang73/DATA/data_hiccup')
OUT = Path(__file__).resolve().parent
FILES = {
    'raw': ROOT / 'sst.day.mean.2020.nc',
    'filled': ROOT / 'sst_ice.daymean.2020.fillmsg.nc',
    'new': ROOT / 'sst_ice.daymean.2020.fillmsg.fmt-c260422_noleap.nc',
    'old': ROOT / '_err_noleap_/sst_ice.daymean.2020.fillmsg.fmt-c260422_noleap.nc',
}

def dates(f):
    t = f['time']
    return [d.strftime('%Y%m%d') for d in num2date(t[:], t.units, getattr(t, 'calendar', 'standard'))]

def compare(a, b, mask=None):
    a, b = np.asarray(a), np.asarray(b)
    if mask is not None:
        a, b = a[mask], b[mask]
    return {'count': int(a.size), 'different': int(np.count_nonzero(a != b)),
            'max_abs_error': float(np.max(np.abs(a.astype('f8') - b.astype('f8')))) if a.size else 0.0}

def main():
    fs = {k: Dataset(p) for k, p in FILES.items()}
    try:
        raw, filled, new, old = [fs[k] for k in ('raw', 'filled', 'new', 'old')]
        source_dates = dates(raw)
        expected_dates = [d for d in source_dates if d != '20200229']
        source_index = [source_dates.index(d) for d in expected_dates]
        report = {'files': {k: str(p) for k, p in FILES.items()}, 'metadata': {}, 'daily': []}
        for name, f in fs.items():
            report['metadata'][name] = {
                'records': len(f.dimensions['time']),
                'calendar': getattr(f['time'], 'calendar', 'standard'),
                'units': f['time'].units,
                'grid_equals_raw': all(np.array_equal(f[k][:], raw[k][:]) for k in ('lat', 'lon')),
            }
        assert dates(filled) == source_dates
        for name, f in [('new', new), ('old', old)]:
            m = report['metadata'][name]
            m['dates_equal_expected'] = dates(f) == expected_dates
            m['time_equals_half_days'] = np.array_equal(f['time'][:], np.arange(365) + .5)
            m['date_variable_equals_expected'] = np.array_equal(f['date'][:], np.array(expected_dates, dtype='i4'))
            m['datesec_equals_43200'] = bool(np.all(f['datesec'][:] == 43200))
        j = int(np.argmin(abs(raw['lat'][:] + 30)))
        i = int(np.argmin(abs(raw['lon'][:] - 280)))
        report['sample_grid'] = {'lat_index_0based': j, 'lon_index_0based': i,
                                 'lat': float(raw['lat'][j]), 'lon': float(raw['lon'][i])}
        samples = []
        for out_idx, src_idx in enumerate(source_index):
            r = raw['sst'][src_idx]
            mask = ~np.ma.getmaskarray(r)
            expected = np.ma.filled(filled['sst_fill'][src_idx], np.float32(-1.8))
            expected_ice = np.ma.filled(filled['icec'][src_idx], 0)
            n, o = new['SST_cpl'][out_idx], old['SST_cpl'][out_idx]
            row = {'date': expected_dates[out_idx], 'source_index_0based': src_idx,
                   'new_vs_raw_valid_ocean': compare(n, r.data, mask),
                   'new_vs_filled_all_grid': compare(n, expected),
                   'new_ice_vs_filled_all_grid': compare(new['ice_cov'][out_idx], expected_ice),
                   'old_vs_raw_valid_ocean': compare(o, r.data, mask),
                   'old_vs_source_same_record': compare(o, np.ma.filled(filled['sst_fill'][out_idx], np.float32(-1.8))),
                   'old_vs_new_all_grid': compare(o, n),
                   'new_nonfinite_count': int(np.count_nonzero(~np.isfinite(n)))}
            report['daily'].append(row)
            if row['date'] in ['20200228', '20200301', '20201231']:
                assert mask[j, i], 'Sample is not a valid ocean cell'
                samples.append({'date': row['date'], 'raw_correct_date': float(r[j,i]),
                                'filled_correct_date': float(expected[j,i]), 'new': float(n[j,i]),
                                'old': float(o[j,i]), 'old_source_date': source_dates[out_idx],
                                'raw_old_source_date': float(raw['sst'][out_idx,j,i])})
            if out_idx % 50 == 0:
                print(f'Checked {out_idx + 1}/365 dates', flush=True)
        report['samples'] = samples
        report['summary'] = {}
        for key in ['new_vs_raw_valid_ocean', 'new_vs_filled_all_grid', 'new_ice_vs_filled_all_grid',
                    'old_vs_raw_valid_ocean', 'old_vs_source_same_record', 'old_vs_new_all_grid']:
            rows = report['daily']
            report['summary'][key] = {
                'compared_cells': sum(r[key]['count'] for r in rows),
                'different_cells': sum(r[key]['different'] for r in rows),
                'max_abs_error': max(r[key]['max_abs_error'] for r in rows),
                'different_days': sum(r[key]['different'] > 0 for r in rows),
                'first_different_date': next((r['date'] for r in rows if r[key]['different']), None),
            }
        (OUT / 'sst_2020_noleap_validation.json').write_text(json.dumps(report, indent=2) + '\n')
        with (OUT / 'sst_2020_noleap_samples.csv').open('w') as fp:
            w = csv.DictWriter(fp, fieldnames=list(samples[0]))
            w.writeheader()
            w.writerows(samples)
        print(json.dumps({'metadata': report['metadata'], 'summary': report['summary'], 'sample_grid': report['sample_grid'], 'samples': samples}, indent=2), flush=True)
    finally:
        for f in fs.values():
            f.close()

if __name__ == '__main__':
    main()
