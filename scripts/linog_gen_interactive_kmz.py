#!/usr/bin/env python3
"""
LInOG Interactive KMZ Generator
Produces Google Earth KMZ files with per-pixel time-series charts and tables.

Usage (single frame):
    python linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr
    python linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr_ramp

    # Custom frame directory:
    python linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr \
        --frame-dir /eggraid/home/arieln/projects/linog/insar/p448/f310

Usage (batch all frames):
    python linog_gen_interactive_kmz.py --batch
"""

import numpy as np
import h5py
import os
import zipfile
import argparse
from datetime import datetime

# FIX B6: Move matplotlib import to module level (was inside v2c() per-pixel loop)
# FIX B7: Use matplotlib.colormaps[] instead of deprecated plt.cm.jet
import matplotlib
import matplotlib.pyplot as plt


def make_interactive_kmz(frame_dir, ts_file, vel_file, out_name,
                         delivery_folder, frame_label, process_label):
    """Generate an interactive KMZ with per-pixel time-series charts."""
    geo_dir = os.path.join(frame_dir, 'mintpy', 'geo')
    ts_path = os.path.join(geo_dir, ts_file)
    vel_path = os.path.join(geo_dir, vel_file)
    mask_path = os.path.join(geo_dir, 'geo_maskTempCoh.h5')
    delivery_path = os.path.join(geo_dir, delivery_folder)

    if not os.path.exists(ts_path):
        print(f"Skipping: {ts_path} not found.")
        return

    if not os.path.exists(vel_path):
        print(f"Skipping: {vel_path} not found.")
        return

    # Load data
    with h5py.File(ts_path, 'r') as f:
        ts = f['timeseries'][:] * 100  # m -> cm
        dates = [d.decode() for d in f['date'][:]]
        a = dict(f.attrs)
        yf = float(a['Y_FIRST'])
        xf = float(a['X_FIRST'])
        ys = float(a['Y_STEP'])
        xs = float(a['X_STEP'])

    with h5py.File(vel_path, 'r') as f:
        vel = f['velocity'][:] * 100  # m/yr -> cm/yr
        if 'velocityStd' in f:
            vs_map = f['velocityStd'][:] * 100
        else:
            vs_map = np.zeros_like(vel)

    with h5py.File(mask_path, 'r') as f:
        mask = f['mask'][:].astype(bool)

    dos = [datetime.strptime(d, '%Y%m%d') for d in dates]
    vmin, vmax = -10, 10

    # FIX B6+B7: colormap resolved once at function scope, not per-pixel.
    # matplotlib.colormaps[] replaces the deprecated plt.cm.jet access.
    _cmap = matplotlib.colormaps['jet']

    def v2c(v):
        """Velocity to KML color (aabbggrr format)."""
        n = np.clip((v - vmin) / (vmax - vmin), 0, 1)
        r, g, b, _ = _cmap(n)
        return 'ff{:02x}{:02x}{:02x}'.format(int(b*255), int(g*255), int(r*255))

    pms = []
    print(f"Building KMZ: {frame_label} ({process_label})...")
    point_count = 0

    for r in range(0, ts.shape[1], 5):
        for c in range(0, ts.shape[2], 5):
            if not mask[r, c] or np.isnan(vel[r, c]):
                continue

            la = yf + ys * r
            lo = xf + xs * c
            v = vel[r, c]
            vs = vs_map[r, c]

            rows = [
                f"[new Date({d.year},{d.month-1},{d.day}),{ts[i,r,c]:.2f}]"
                for i, d in enumerate(dos)
            ]
            table_rows = "".join([
                f"<tr><td style='border:1px solid #ddd; padding:2px;'>"
                f"{d.strftime('%Y-%m-%d')}</td>"
                f"<td style='border:1px solid #ddd;'>{ts[i,r,c]:.2f}</td></tr>"
                for i, d in enumerate(dos)
            ])

            bl = f'''<![CDATA[
            <div style="width:480px; font-family:Arial; font-size:12px; color:#333;">
                <h3 style="margin:0 0 5px 0;">LInOG {frame_label} ({process_label})</h3>
                <div style="margin-bottom:10px;">
                    <b>Velocity:</b> {v:.2f} +/- {vs:.2f} cm/yr
                </div>
                <div id="chart_{r}_{c}" style="width:100%; height:220px; border:1px solid #eee; background:#fcfcfc;">
                    <div style="padding:80px 0; text-align:center; color:#999;">Loading...</div>
                </div>
                <div style="margin-top:10px; max-height:130px; overflow-y:auto; border:1px solid #ddd;">
                    <table style="width:100%; border-collapse:collapse; text-align:center;">
                        <thead style="background:#eee; position:sticky; top:0;">
                            <tr>
                                <th style="padding:4px; border:1px solid #ddd;">Date</th>
                                <th style="padding:4px; border:1px solid #ddd;">Disp (cm)</th>
                            </tr>
                        </thead>
                        <tbody>{table_rows}</tbody>
                    </table>
                </div>
                <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
                <script type="text/javascript">
                    (function() {{
                        function draw() {{
                            var data = new google.visualization.DataTable();
                            data.addColumn('date', 'Date');
                            data.addColumn('number', 'Displacement (cm)');
                            data.addRows([{",".join(rows)}]);
                            var options = {{
                                title: 'Displacement History',
                                legend: {{ position: 'none' }},
                                pointSize: 6,
                                colors: ['#008080'],
                                chartArea: {{width: '85%', height: '75%'}},
                                vAxis: {{ title: 'cm', gridlines: {{color: '#f0f0f0'}} }},
                                hAxis: {{ format: 'MMM yyyy' }}
                            }};
                            var el = document.getElementById('chart_{r}_{c}');
                            if(el) {{
                                new google.visualization.ScatterChart(el).draw(data, options);
                            }}
                        }}
                        if (typeof google !== 'undefined' && google.charts) {{
                            if (!google.visualization || !google.visualization.ScatterChart) {{
                                google.charts.load('current', {{'packages':['corechart']}});
                                google.charts.setOnLoadCallback(draw);
                            }} else {{ draw(); }}
                        }}
                    }})();
                </script>
            </div>]]>'''

            pms.append(f'''<Placemark>
                <description>{bl}</description>
                <Style><IconStyle>
                    <color>{v2c(v)}</color><scale>0.5</scale>
                    <Icon><href>http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png</href></Icon>
                </IconStyle></Style>
                <Point><coordinates>{lo:.6f},{la:.6f},0</coordinates></Point>
            </Placemark>''')
            point_count += 1

    kml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2">'
        f'<Document><name>{out_name}</name>'
        f'{chr(10).join(pms)}'
        '</Document></kml>'
    )

    os.makedirs(delivery_path, exist_ok=True)
    out_path = os.path.join(delivery_path, out_name)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("doc.kml", kml)

    print(f"  Created: {out_path} ({point_count} points)")


# ==============================================================================
# Correction type -> file mapping
# ==============================================================================

CORRECTION_MAP = {
    'demErr': {
        'ts_file': 'geo_timeseries_demErr.h5',
        'vel_file': 'geo_velocity_demErr.h5',
    },
    'demErr_ramp': {
        'ts_file': 'geo_timeseries_ramp_demErr.h5',
        'vel_file': 'geo_velocity_demErr_ramp.h5',
    },
}


def process_single(args):
    """Process a single frame + correction."""
    path = args.path
    frame = args.frame
    corr = args.correction
    frame_label = f"F{frame}"
    frame_tag = f"P{path}F{frame}"

    if args.frame_dir:
        frame_dir = args.frame_dir
    else:
        frame_dir = f"/eggraid/home/{os.environ.get('USER', 'arieln')}/projects/linog/insar/p{path}/f{frame}"

    if corr not in CORRECTION_MAP:
        print(f"Error: Unknown correction '{corr}'. Use: demErr or demErr_ramp")
        return

    cfg = CORRECTION_MAP[corr]
    out_name = f"{frame_tag}_TimeSeries_{corr}.kmz"
    delivery_folder = f"LInOG_Upload_{frame_tag}"

    make_interactive_kmz(
        frame_dir=frame_dir,
        ts_file=cfg['ts_file'],
        vel_file=cfg['vel_file'],
        out_name=out_name,
        delivery_folder=delivery_folder,
        frame_label=frame_label,
        process_label=corr
    )


def process_batch():
    """Process all P448 frames for both corrections."""
    frames = [
        ('448', '0280'), ('448', '0290'),
        ('448', '0300'), ('448', '0310'), ('448', '0320'),
    ]
    for path, frame in frames:
        for corr in ['demErr', 'demErr_ramp']:
            frame_dir = f"/eggraid/home/{os.environ.get('USER', 'arieln')}/projects/linog/insar/p{path}/f{frame}"
            frame_label = f"F{frame}"
            frame_tag = f"P{path}F{frame}"
            cfg = CORRECTION_MAP[corr]

            make_interactive_kmz(
                frame_dir=frame_dir,
                ts_file=cfg['ts_file'],
                vel_file=cfg['vel_file'],
                out_name=f"{frame_tag}_TimeSeries_{corr}.kmz",
                delivery_folder=f"LInOG_Upload_{frame_tag}",
                frame_label=frame_label,
                process_label=corr
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="LInOG Interactive KMZ Generator")
    parser.add_argument("--path", default="448",
                        help="ALOS Path (e.g., 448)")
    parser.add_argument("--frame", default="0310",
                        help="ALOS Frame (e.g., 0310)")
    parser.add_argument("--correction", default="demErr",
                        choices=["demErr", "demErr_ramp"],
                        help="Correction type")
    parser.add_argument("--frame-dir",
                        help="Override frame directory path")
    parser.add_argument("--batch", action="store_true",
                        help="Process all P448 frames")
    args = parser.parse_args()

    if args.batch:
        process_batch()
    else:
        process_single(args)
