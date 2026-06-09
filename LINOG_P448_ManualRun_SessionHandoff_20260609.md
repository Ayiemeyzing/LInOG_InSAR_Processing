# LInOG P448 Manual Run — Session Handoff
**Date:** Jun 9, 2026  
**Author:** Ariel J. Nopre Jr.  
**Continues from:** LINOG_MintPy_SessionHandoff_20260609.md  
**Decision:** Halt batch scripts. Manual rerun of P448 F0280 (and F0290 pending).

---

## Why the Batch Run Produced Gray/No Signal

### Root Cause: run04 (refineSecondaryTiming) Failure → Zero-Shift Coregistration

| Step | Old f0280 run (Mar 6–9, 2026) | Jun 9 batch run (v2.4.2) |
|---|---|---|
| run04 outcome | **SUCCESS** — 980–1109 valid cross-corr points per pair | **FAIL** — empty shelves (100–110 bytes header-only) for all pairs |
| Coregistration | Sub-pixel shifts applied (e.g. az +0.89 px, rg +0.20 px) | Zero-shift fallback (no offset correction) |
| Igrams produced | 36 coherent pairs | 36 pairs but low coherence |
| MintPy pixels | Many — visible signal, coherent velocity maps | 560 pixels at minTempCoh=0.3 — gray/no signal |

The batch script's zero-shift fallback (via `resampleSlc.py` P3 patch) allows ISCE2 to complete, but the resulting igrams have low coherence because coregistration errors are not corrected. At minTempCoh=0.3 (the noise floor), only 560 pixels survive — not enough to see deformation signal.

### Why run04 Succeeded in the Old Run

Evidence from old run logs:
- `run01_reference.3.log` → output path: `/eggraid/home/arieln/projects/linog/insar/p448/f280/merged/geom_reference/` — note `merged/` prefix
- `run04_refineSecondaryTiming.log` → reads `coregSLC/Coarse/YYYYMMDD/YYYYMMDD.slc.vrt`

The old run used an older ISCE2 stripmapStack workflow that generated a `merged/` directory structure with `coregSLC/Coarse/` coarsely reregistered SLCs. The current ISCE2 (Jun 2026) generates `geom_reference/` directly at the frame root with no `merged/` level. Run04 reads the coarsely reregistered SLCs for cross-correlation. The structural change between ISCE2 versions likely affects what run04 reads, degrading cross-correlation quality for this agricultural terrain frame.

**This is not a parameter issue.** AZIMUTH_LOOKS=28, RANGE_LOOKS=12, TEMPORAL_BASELINE=730, PERP_BASELINE=1500, REF_DATE=20091111 — all identical between old run and batch run.

---

## Old f0280 Run Reference Data (on laptop)

Path: `D:\05_LInOG\LInOG InSAR Training\p448\f0280_oldrun\`

DO NOT DELETE — this is the reference for the manual rerun.

| Contents | Status |
|---|---|
| `Igrams/` | 36 .int files (good coherent igrams, FBS only) |
| `mintpy/` | Complete MintPy run — velocity maps, time series, KMZ |
| `mintpy/LInOG_Upload_P448F0280_demErr/` | Phase 6 deliverables (old format) |
| `run04_refineSecondaryTiming.log` | Proof of successful cross-corr: 144 pair results, 980–1109 pts each |
| `pairs.pdf` | Baseline plot from old run |
| `path448_frame0280.log` | find_alos.sh output — 23 ZIPs found, 11 FBS retained |

Key metrics from old run:
- **11 FBS acquisitions**: 20070203, 20071222, 20080206, 20080323, 20081108, 20090208, 20091111, 20091227, 20100211, 20101230, 20110214
- **36 interferograms**
- **run04 RMSE** (from `run05_invertMisreg.log`): Az shifts 0.29–1.60 px, Rg shifts -0.39 to +0.31 px — significant, non-trivial offsets

---

## Manual Run Plan — P448 F0280

### Step 0: Confirm What's in the Current f0280 SLC Directory on Felix

```bash
# SSH to felix first
ssh arieln@felix
conda activate isce2

# Count SLCs
ls /eggraid/home/arieln/projects/linog/insar/p448/f0280/SLC/ | wc -l

# List dates
ls /eggraid/home/arieln/projects/linog/insar/p448/f0280/SLC/

# Expected: 11 FBS dates. If more, FBD acquisitions are present and must be removed.
# FBD dates to check (from old 0290 run): 20070621, 20070921, 20071106, 20080508,
#   20080808, 20080923, 20090626, 20090926, 20100629, 20100814, 20100929, 20101114
```

### Step 1: Wipe F0280 Processing Outputs (Keep SLC/ and raw/)

Run these from WSL2 on your laptop (or inside screen on felix):

```bash
WDIR=/eggraid/home/arieln/projects/linog/insar/p448/f0280

# Wipe all generated output, keep SLC/ and raw/
cd "${WDIR}"
rm -rf geom_reference run_files interferograms Igrams DEM unzipped baselines
rm -rf mintpy mintpy_logs rejected_pairs refineSecondaryTiming misreg logs
rm -rf merged   # if it exists from old processing

# Verify SLC is intact
ls SLC/
```

### Step 2: Wipe F0290 Processing Outputs (Keep SLC/)

```bash
WDIR2=/eggraid/home/arieln/projects/linog/insar/p448/f0290

cd "${WDIR2}"
# f0290 was only at step 05_stack_config_p1 — wipe everything except SLC/
rm -rf geom_reference run_files interferograms Igrams DEM unzipped baselines
rm -rf mintpy mintpy_logs rejected_pairs refineSecondaryTiming misreg logs
rm -rf merged

ls SLC/
```

### Step 3: (If FBD Present) Run FBS Filter

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280
python ~/bin/filter_for_fbs.py 2>&1 | tee logs/00_fbs_filter.log
# Expected: 11 FBS retained, ~12 FBD moved to removed_FBD_data/
```

### Step 4: Download DEM

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280
mkdir -p DEM && cd DEM
dem.py -a stitch -b 14 18 120 123 -r -s 1 -c 2>&1 | tee ../logs/04_dem.log
cd ..
```

### Step 5: Stack Config Phase 1 (Baseline Plot, No Reference Date Yet)

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280
stackStripMap.py -W interferogram --nofocus \
    -s SLC \
    -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
    -t 730 -b 1500 -a 28 -r 12 -u snaphu \
    2>&1 | tee logs/05_stack_config_p1.log

# Review baseline plot:
scp arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f0280/pairs.pdf .
# Reference date confirmed from old run: 20091111
```

### Step 6: Stack Config Phase 2 (With Reference Date)

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280
stackStripMap.py -W interferogram --nofocus \
    -s SLC \
    -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
    -t 730 -b 1500 -a 28 -r 12 -u snaphu \
    -m 20091111 \
    2>&1 | tee logs/05_stack_config_p2.log

# Verify run files created
ls run_files/
```

### Step 7: Run ISCE2 Steps 01–07 (Sequential)

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280

# run_01: Reference geometry (strip createWaterMask first — known ISCE2 bug)
sed -i '/createWaterMask/d' run_files/run_01_reference
sh run_files/run_01_reference 2>&1 | tee logs/06_run01_reference.log

# Create zero water mask manually (SWBD stitcher bug fix)
python3 - <<'EOF'
import numpy as np, isce
from isceobj.Image import createImage
# Read lat.rdr dimensions to build matching zero mask
import gdal
ds = gdal.Open('geom_reference/lat.rdr')
rows, cols = ds.RasterYSize, ds.RasterXSize
mask = np.zeros((rows, cols), dtype=np.uint8)
mask.tofile('geom_reference/waterMask.rdr')
print(f"waterMask.rdr written: {rows}x{cols}")
EOF

sh run_files/run_02_focus_split 2>&1 | tee logs/07_run02_focus_split.log
sh run_files/run_03_geo2rdr_coarseResamp 2>&1 | tee logs/08_run03_geo2rdr_coarseResamp.log
```

### Step 8: CRITICAL — Run04 (refineSecondaryTiming) and Verify

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280

# Run sequentially (NOT parallel — need per-pair results to check)
sh run_files/run_04_refineSecondaryTiming 2>&1 | tee logs/09_run04_refineSecondaryTiming.log

# === DIAGNOSTIC: Did run04 succeed? ===
# Check shelve sizes in refineSecondaryTiming/pairs/
echo "=== Shelve sizes ==="
for d in refineSecondaryTiming/pairs/*/; do
    pair=$(basename "$d")
    size=$(du -sb "$d" | cut -f1)
    echo "$pair: $size bytes"
done

# SUCCESS criterion: shelves > 200 bytes contain polynomial data
# FAIL criterion: shelves ~100-110 bytes = empty headers (zero-shift will apply)
# Old run had all 36 pairs succeed. If < half succeed here, abort and investigate.
```

### Step 9: Continue Steps 05–08

```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280

sh run_files/run_05_invertMisreg 2>&1 | tee logs/10_run05_invertMisreg.log
sh run_files/run_06_fineResamp 2>&1 | tee logs/11_run06_fineResamp.log
sh run_files/run_07_grid_baseline 2>&1 | tee logs/12_run07_grid_baseline.log

# run_08: interferograms (parallel)
parallel -j 4 < run_files/run_08_igram 2>&1 | tee logs/13_run08_igram.log

# Verify igrams
ls interferograms/ | wc -l   # expect ~36
```

### Step 10: Quick Igram Visual Check Before MintPy

```bash
# SCP one igram to check fringes
scp arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f0280/interferograms/20090208_20091111/filt_20090208_20091111.int .

# View with mdx.py or QGIS
# If fringes are visible → proceed to MintPy
# If gray → run04 still failed, need deeper investigation
```

---

## Retrieving Old F0290 Run Logs from Felix

The old P448 F0290 manual run is at `/eggraid/home/arieln/projects/linog/insar/448/0290/` (old 3-digit path, different from current `p448/f0290/`).

Run from WSL2 on your laptop to save to local:

```bash
# Create local directory
mkdir -p "/mnt/d/05_LInOG/LInOG InSAR Training/p448/f0290"

# Retrieve all logs from old 0290 run
scp arieln@felix:/eggraid/home/arieln/projects/linog/insar/448/0290/*.log \
    "/mnt/d/05_LInOG/LInOG InSAR Training/p448/f0290/"

# Also grab pairs.pdf and the run config
scp arieln@felix:/eggraid/home/arieln/projects/linog/insar/448/0290/pairs.pdf \
    "/mnt/d/05_LInOG/LInOG InSAR Training/p448/f0290/"

# Or grab the whole directory (minus SLC/raw to save bandwidth)
rsync -avz --progress \
    --exclude='SLC/' --exclude='raw/' --exclude='unzipped/' \
    --exclude='Igrams/' --exclude='coregSLC/' \
    arieln@felix:/eggraid/home/arieln/projects/linog/insar/448/0290/ \
    "/mnt/d/05_LInOG/LInOG InSAR Training/p448/f0290/"
```

**NOTE**: If old 0290 path doesn't exist on felix, check:
```bash
ssh arieln@felix "ls /eggraid/home/arieln/projects/linog/insar/448/"
ssh arieln@felix "ls /eggraid/home/arieln/projects/linog/insar/p448/"
```

---

## Local Directory State (Laptop)

| Path | Contents | Action |
|---|---|---|
| `p448/f0280_oldrun/` | Good March 2026 run: 36 igrams, full MintPy | **Keep — DO NOT delete** |
| `p448/f0290/` | Empty | Can delete or keep for rsync target |
| `p448/P448F0280_pairs.pdf` | Baseline plot from old run | Keep |
| `p448/reports/` | [VERIFY contents] | Keep |

---

## If Manual Run04 Still Fails

If run04 fails again with the current ISCE2 on felix, options:

**Option A — Use old run igrams directly**  
The `f0280_oldrun/Igrams/` has 36 good .int files already on your laptop. rsync them back to felix into a new MintPy-ready structure and run MintPy from there. This bypasses the ISCE2 coregistration issue entirely.

```bash
rsync -avz --progress \
    "/mnt/d/05_LInOG/LInOG InSAR Training/p448/f0280_oldrun/Igrams/" \
    arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f0280/Igrams/
```

**Option B — Use old run MintPy results directly**  
`f0280_oldrun/mintpy/` already has velocity maps and time series. The Phase 6 deliverables in `LInOG_Upload_P448F0280_demErr/` need to be re-formatted to the current Phase 6 format (16-file set). Compare with the Jun 9 batch run's Phase 6 output to decide which is scientifically better.

**Option C — Investigate ISCE2 version on felix**  
```bash
ssh arieln@felix "conda activate isce2 && python -c 'import isce; print(isce.__version__)'"
```
Compare to the ISCE2 version active in March 2026 (check felix changelog or conda history).

---

## Open Items

| Item | Priority | Action |
|---|---|---|
| Manual run04 diagnostic (does it succeed now?) | HIGH | Run wipe + manual steps above |
| F0290 old run logs on felix | MEDIUM | scp from `448/0290/` to local |
| [CONFIRM WITH PL] F0280 — which run to use for deliverables (old vs batch) | HIGH | Dr. JD review |
| F0290–F0320 processing plan | LOW | After F0280 resolved |

---

*Document created Jun 9, 2026. Continues: LINOG_MintPy_SessionHandoff_20260609.md*
