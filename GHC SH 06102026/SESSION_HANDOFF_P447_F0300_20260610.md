# LInOG InSAR Processing — Session Handoff

**Date:** 2026-06-10  
**Project:** LInOG InSAR / ALOS PALSAR-1 / ISCE2 + MintPy  
**Current focus:** P447 / F0300 clean rebuild and transition to MintPy  
**Remote server:** `arieln@felix`  
**Remote project root:** `/eggraid/home/arieln/projects/linog/insar/`  
**Current frame directory:** `/eggraid/home/arieln/projects/linog/insar/p447/f0300`

---

## 1. Role / Working Style for Next Chat

Assistant should act as:

- Remote Sensing Scientist & InSAR Engineer
- Expert in ISCE2 stripmapStack, ALOS PALSAR-1 L1.1 CEOS, MintPy, SBAS, unwrapping, and coherence QC
- Methodical geophysical debugging style
- Preserve logs and processing provenance
- Avoid destructive changes without backups
- Distinguish signal, decorrelation, metadata issues, and processing artifacts

---

## 2. Repository Context

GitHub repo:

```text
Ayiemeyzing/LInOG_InSAR_Processing
```

Relevant repo folders:

```text
reports/
scripts/
```

Report folder checked at commit:

```text
d6ba9329141e297acf4996d692d6e6489799f236
```

The pasted MintPy script came from:

```text
scripts/linog_batch_p447_mintpy.sh
CommitOID: dead5c7645ef9dce9360ecff8c986f5dad158b90
```

Important next-chat task:

- Check whether `linog_batch_p447_mintpy.sh` exists in the current repo/branch.
- Search for comparable MintPy batch scripts for:
  - `p448`
  - `p449`
- Compare naming conventions, folder expectations, reference dates, exclusions, and Phase 6 deliverables.

---

## 3. Remote Environment

ISCE2 environment used for this session:

```text
(linog_isce2)
```

MintPy batch script expects MintPy + ISCE2 environment:

```text
/eggraid/miniconda3/envs/isce2
```

Primary remote frame directory:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300
```

---

## 4. P447/F0300 Input Stack

12 ALOS PALSAR-1 HH dates used for apples-to-apples rebuild:

```text
20070117
20070304
20080120
20080421
20081207
20090122
20090309
20091210
20100125
20100312
20110128
20110315
```

ISCE2 stack reference date:

```text
20090309
```

Planned MintPy reference date:

```text
20090309
```

---

## 5. Clean Rebuild History

Old failed p447/f0300 products were archived here:

```text
/eggraid/home/arieln/projects/linog/insar/p447/archive_f0300_old_runs/f0300_old_products_20260610_091917
```

Active `p447/f0300` was rebuilt cleanly from source.

Policy followed:

- Do not copy generated products from archived failed `p447/f0300`.
- Rebuild raw → unzipped → SLC → DEM → stackStripMap products cleanly.
- Use `linog_isce2` for ISCE2 processing.

---

## 6. DEM Status

DEM source used:

```text
/eggraid/home/arieln/projects/linog/insar/p448/f0290/DEM
```

Important detail:

- Initially staged as symlinks.
- Batch precheck failed because `find "$DEM_DIR" -type f` did not count symlinks.
- DEM/SWBD were replaced by real copied files.

DEM sanity check:

```text
EPSG:4326 / WGS84
Size: 10800 x 14400
Bounds: 120E-123E, 14N-18N
```

Current DEM state:

```text
Active DEM directory contains regular files, not symlinks.
```

---

## 7. Raw/SLC Status

Raw ALOS ZIP source:

```text
/eggraid/data/alos
```

Active `raw/` contains symlinks to 12 verified Path 447 / Frame 0300 ZIPs.

SLCs were rebuilt for all 12 dates.

Each date has:

```text
SLC/YYYYMMDD/YYYYMMDD.slc
SLC/YYYYMMDD/YYYYMMDD.slc.xml
SLC/YYYYMMDD/YYYYMMDD.slc.vrt
SLC/YYYYMMDD/data.dat
SLC/YYYYMMDD/data.dir
SLC/YYYYMMDD/data.bak
```

---

## 8. Important ISCE2 Repairs Applied

### 8.1 `--nofocus`

Because the inputs are already focused SLCs, `stackStripMap.py` needed:

```text
--nofocus
```

Batch/script generation was patched to include this.

### 8.2 Zero Doppler Shelf Repair

`run_03_geo2rdr_coarseResamp` initially failed because SLC `data` shelves had only `frame`, and missing `doppler` caused fallback to:

```text
frame._dopplerVsPixel
```

which was `None`.

Fix:

- Backed up SLC `data` shelves under `qc/`.
- Patched shelves with zero-Doppler `Poly1D`.

This matched the zero-Doppler/native geometry path seen in logs.

---

## 9. Coregistration Workflow Status

Successfully completed:

```text
run_03_geo2rdr_coarseResamp
run_04_refineSecondaryTiming
run_05_invertMisreg
run_06_fineResamp
run_07_grid_baseline
```

Return codes:

```text
run03_rc=0
run04_rc=0
run05_rc=0
run06_rc=0
run07_rc=0
```

Coarse SLC outputs:

```text
coregSLC/Coarse/YYYYMMDD/YYYYMMDD.slc
```

Fine SLC outputs:

```text
merged/SLC/YYYYMMDD/YYYYMMDD.slc
```

Final fine SLC stack verification:

```text
MERGED_FINE_SLC_STACK_OK
```

---

## 10. Reference Merged SLC XML Repair

`run_06_fineResamp` copied the reference SLC with:

```text
referenceStackCopy.py
```

but initially did not create:

```text
merged/SLC/20090309/20090309.slc.xml
```

Fix:

- Loaded original:
  ```text
  SLC/20090309/20090309.slc.xml
  ```
- Retargeted filename to:
  ```text
  merged/SLC/20090309/20090309.slc
  ```
- Rendered header.

Verified:

```text
loaded OK
width: 9344
length: 18432
```

---

## 11. Misregistration QC

Pair-level shelves:

```text
refineSecondaryTiming/pairs/*/misreg
```

contain for all 66 pairs:

```text
raw_field
cull_field
azpoly
rgpoly
```

Date-level shelves:

```text
refineSecondaryTiming/dates/YYYYMMDD/misreg
```

contain for all 12 dates:

```text
azpoly
rgpoly
```

Notable azimuth corrections:

```text
20080421 azpoly ≈ -5.35 px
20070304 azpoly ≈ -3.42 px
20090309 azpoly ≈ -3.18 px
```

These are not automatically fatal for old ALOS CEOS processing, but should be kept in mind when assessing coherence and residual offsets.

---

## 12. Interferogram Generation

Workflow inspected:

```text
stackStripMap.py -W interferogram
```

For interferogram workflow generation, use original SLC directory for metadata/baseline discovery:

```text
-s /eggraid/home/arieln/projects/linog/insar/p447/f0300/SLC
```

Generated configs correctly use final fine stack:

```text
merged/SLC/YYYYMMDD/YYYYMMDD.slc
```

---

## 13. Multilook Mistake and Correction

### 13.1 Initial Mistake

The first IFG generation used:

```text
-S alos
```

This triggered `stackStripMap.py` logic:

```text
if sensor == alos:
    ar = 4
inps.alks = int(inps.alks) * ar
```

Resulting wrong looks:

```text
alks = 40
rlks = 10
```

Wrong output raster dimensions:

```text
Size is 934, 460
```

This was not the target resolution.

### 13.2 Correct Target

Target multilooks:

```text
28 azimuth looks × 12 range looks
```

Approximate target pixel size:

```text
~90 m × ~90 m
```

Correct command used:

```bash
stackStripMap.py \
  -s /eggraid/home/arieln/projects/linog/insar/p447/f0300/SLC \
  -d /eggraid/home/arieln/projects/linog/insar/p447/f0300/DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
  -w /eggraid/home/arieln/projects/linog/insar/p447/f0300 \
  -m 20090309 \
  --nofocus \
  -W interferogram \
  -a 28 \
  -r 12 \
  -u no
```

Important:

```text
Do NOT include -S alos when explicitly using -a 28 -r 12.
```

Verified config:

```text
alks : 28
rlks : 12
```

Reran `run_08_igram` with GNU parallel:

```text
-j 4
```

Successful:

```text
run08_28x12_rc=0
```

All 66 corrected IFGs verified:

```text
ALL_IGRAMS_28AZ_12RNG_OK
```

All pairs now have:

```text
Size is 778, 658
```

This matches:

```text
range   floor(9344 / 12) = 778
azimuth floor(18432 / 28) = 658
```

---

## 14. Corrected IFG Product Layout

Current corrected products are in:

```text
/eggraid/home/arieln/projects/linog/insar/p447/f0300/Igrams
```

Per pair:

```text
Igrams/YYYYMMDD_YYYYMMDD/YYYYMMDD_YYYYMMDD.int
Igrams/YYYYMMDD_YYYYMMDD/YYYYMMDD_YYYYMMDD.amp
Igrams/YYYYMMDD_YYYYMMDD/filt_YYYYMMDD_YYYYMMDD.int
Igrams/YYYYMMDD_YYYYMMDD/filt_YYYYMMDD_YYYYMMDD.cor
```

with sidecars:

```text
.xml
.vrt
```

Current products are wrapped-only:

```text
-u no
```

No `.unw` products were generated in this chat.

---

## 15. Coherence Statistics

Coherence stats were computed from the earlier 40×10 run, so recompute if exact final 28×12 stats are needed.

Qualitative result:

Mean coherence range:

```text
~0.281 to ~0.478
```

Best pair:

```text
20070304_20091210 mean=0.4775 p50=0.3368 p75=0.7260 p95=0.9495
```

Weak reference-date pairs involving `20090309`:

```text
20070304_20090309 mean=0.2812
20081207_20090309 mean=0.2812
20070117_20090309 mean=0.2812
20090309_20091210 mean=0.2814
20090309_20100125 mean=0.2815
20090309_20110315 mean=0.2818
20090309_20100312 mean=0.2819
20090309_20110128 mean=0.2822
```

Existing MintPy script excludes four f0300 pairs:

```text
20090309_20091210
20090309_20100125
20090309_20100312
20090309_20110128
```

Reason from script comments:

```text
blank / rainy-season decorrelation / noisy SBAS contribution
```

---

## 16. Local Rsync / Report Grid Notes

Correct remote:

```text
arieln@felix:/eggraid/home/arieln/projects/linog/insar/p447/f0300/Igrams
```

Correct local:

```text
~/LInOG/insar/p447/f0300/Igrams
```

A bad command was attempted with a line break:

```bash
filt*
.int*
```

This caused:

```text
.int*: command not found
```

Also, without `--relative`, rsync flattened pair directories.

Preferred clean local rsync:

```bash
set -euo pipefail

LOCAL_FRAME="$HOME/LInOG/insar/p447/f0300"
REMOTE_FRAME="/eggraid/home/arieln/projects/linog/insar/p447/f0300"
REMOTE_HOST="arieln@felix"

rm -rf "$LOCAL_FRAME/Igrams"
mkdir -p "$LOCAL_FRAME/Igrams" "$LOCAL_FRAME/qc"

rsync -avh --progress --relative \
  "$REMOTE_HOST:$REMOTE_FRAME/./Igrams/*/filt_*.int*" \
  "$REMOTE_HOST:$REMOTE_FRAME/./Igrams/*/filt_*.cor*" \
  "$LOCAL_FRAME/"

rsync -avh --progress \
  "$REMOTE_HOST:$REMOTE_FRAME/README_CLEAN_REBUILD.txt" \
  "$REMOTE_HOST:$REMOTE_FRAME/manual_run_logs/verify_all_igrams_28az_12rng_*.log" \
  "$LOCAL_FRAME/qc/" || true
```

Local verification:

```bash
LOCAL_FRAME="$HOME/LInOG/insar/p447/f0300"

find "$LOCAL_FRAME/Igrams" -maxdepth 1 -mindepth 1 -type d | wc -l

for pair in 20070117_20070304 20090309_20091210 20110128_20110315; do
    echo "--- $pair ---"
    gdalinfo "$LOCAL_FRAME/Igrams/$pair/filt_$pair.int.vrt" | grep 'Size is'
    gdalinfo "$LOCAL_FRAME/Igrams/$pair/filt_$pair.cor.vrt" | grep 'Size is'
done
```

Expected:

```text
66
Size is 778, 658
```

---

## 17. GitHub Report Check

At commit:

```text
d6ba9329141e297acf4996d692d6e6489799f236
```

`reports/` contains new P447/F0300 report pages:

```text
P447F0300_Igram_Report_Page_1.jpg size=693,913
P447F0300_Igram_Report_Page_2.jpg size=697,274
P447F0300_Igram_Report_Page_3.jpg size=698,581
P447F0300_Igram_Report_Page_4.jpg size=709,634
P447F0300_Igram_Report_Page_5.jpg size=698,032
P447F0300_Igram_Report_Page_6.jpg size=423,552
```

These are larger than the older wrong-resolution report pages around `474–484 KB`, consistent with corrected `28×12` products.

P448/F0290 report pages are also present:

```text
P448F0290_Igram_Report_Page_1.jpg
P448F0290_Igram_Report_Page_2.jpg
P448F0290_Igram_Report_Page_3.jpg
```

---

## 18. Current GitHub Scripts Listing

At current commit `d6ba932...`, `scripts/` listing showed:

```text
check_preflight.sh
linog_create_grid
linog_create_grid.py
linog_fbs_processor.sh
linog_gen_interactive_kmz.py
linog_save_insar_images.py
```

The pasted MintPy script:

```text
scripts/linog_batch_p447_mintpy.sh
```

was provided from older commit:

```text
dead5c7645ef9dce9360ecff8c986f5dad158b90
```

Next chat should verify if that script exists in the current repo state or only the older commit.

---

## 19. Pasted MintPy Script Summary

Script:

```text
scripts/linog_batch_p447_mintpy.sh
```

Internal version:

```text
SCRIPT_VERSION="2.8"
```

Base directory:

```text
BASE_DIR="/eggraid/home/arieln/projects/linog/insar/p447"
```

Frames:

```text
FRAMES=("f0300" "f0310")
```

Start frame:

```text
START_FRAME="f0300"
```

MintPy env:

```text
MINTPY_ENV="/eggraid/miniconda3/envs/isce2"
```

MintPy reference date:

```text
REF_DATE="20090309"
```

ISCE2 reference dates:

```text
ISCE2_REF_DATE["f0300"]="20090309"
ISCE2_REF_DATE["f0310"]="20091210"
```

F0300 pair exclusions:

```text
EXCLUDE_IGRAMS["f0300"]="20090309_20091210 20090309_20100125 20090309_20100312 20090309_20110128"
```

MintPy config generated by script expects unwrapped files:

```text
mintpy.load.unwFile      = Igrams/*/filt_*.unw
mintpy.load.connCompFile = Igrams/*/filt_*.unw.conncomp
```

Current p447/f0300 state only has wrapped IFGs:

```text
filt_*.int
filt_*.cor
```

Therefore:

```text
Unwrapping is required before running MintPy batch as-is.
```

The script precheck fails if no `.unw` files exist.

---

## 20. MintPy Script Important Behaviors

The script runs `prep_isce.py` before `load_data`:

```text
prep_isce.py \
  -m SLC/20090309/data.dat \
  -g geom_reference \
  -b baselines \
  -f "Igrams/*/filt_*.unw"
```

It cleans stale `.rsc` files before prep:

```text
find Igrams/ geom_reference/ -name "*.rsc" -delete
```

Important config behavior:

```text
mintpy.load.processor = isce
mintpy.load.intFile = no
mintpy.load.waterMaskFile = no
mintpy.networkInversion.waterMaskFile = no
mintpy.unwrapError.method = no
mintpy.networkInversion.weightFunc = var
mintpy.networkInversion.minTempCoh["f0300"] = 0.5
mintpy.reference.minCoherence = 0.4
mintpy.sensor = ALOS
mintpy.troposphericDelay.method = no
mintpy.deramp = linear
mintpy.plot.vlim = -10 10
```

Watermask handling:

- P447 `waterMask.rdr` is all-zero.
- Script patches `geometryRadar.h5['waterMask']` to all-ones or creates it if absent.

Deliverable behavior:

- Runs a second demErr-only pass.
- Produces expected Phase 6 geo products:
  ```text
  geo_velocity_demErr.h5
  geo_velocity_demErr_ramp.h5
  geo_timeseries_demErr.h5
  geo_timeseries_ramp_demErr.h5
  ```

---

## 21. Next Work To Do

Primary next objective:

```text
MintPy processing of P447/F0300 corrected interferograms following the LInOG InSAR Processing Manual, naming conventions, and folder structure.
```

Recommended next steps:

### Step 1 — Confirm current scripts

In next chat, inspect repo for:

```text
linog_batch_p447_mintpy.sh
linog_batch_p448_mintpy.sh
linog_batch_p449_mintpy.sh
```

or older naming equivalents.

Compare:

- `BASE_DIR`
- frames
- reference dates
- excluded dates/pairs
- MintPy config generation
- output naming
- Phase 6 compatibility

### Step 2 — Preserve corrected wrapped IFGs

Current corrected wrapped IFGs are good and should not be overwritten without backup.

Consider archiving:

```text
Igrams_28az_12rng_wrapped_archive_TIMESTAMP
```

or at least ensure `README_CLEAN_REBUILD.txt` documents the current state.

### Step 3 — Decide unwrapping network

Options:

1. **Unwrap all 66 pairs**, then let MintPy script reject the 4 bad f0300 pairs.
2. **Reject bad pairs first**, then unwrap only accepted pairs.
3. **Build a pruned connected network** based on coherence, then unwrap only selected pairs.

Because the existing MintPy script already implements pair rejection, easiest path may be:

```text
unwrap all 66 → run MintPy script → script moves 4 bad pairs to Igrams/rejected_pairs/
```

But this may waste time unwrapping bad pairs.

### Step 4 — Generate unwrapping configs

Need inspect `stackStripMap.py -W interferogram -u snaphu` behavior.

Important:

```text
Use -a 28 -r 12
Do NOT use -S alos
```

Possible command to test/generate:

```bash
stackStripMap.py \
  -s "$FRAME_DIR/SLC" \
  -d "$FRAME_DIR/DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84" \
  -w "$FRAME_DIR" \
  -m 20090309 \
  --nofocus \
  -W interferogram \
  -a 28 \
  -r 12 \
  -u snaphu
```

Before running, inspect generated config/run files to confirm:

- It keeps `alks : 28`
- It keeps `rlks : 12`
- It does not regenerate wrong products
- It adds unwrapping properly

### Step 5 — Run unwrapping

Likely through:

```text
run_08_igram
```

or a new generated run file.

Use GNU parallel cautiously:

```text
-j 4
```

### Step 6 — Verify unwrapped products

Expected possible filenames:

```text
filt_PAIR.unw
filt_PAIR.unw.vrt
filt_PAIR.unw.xml
filt_PAIR.unw.conncomp
```

or possibly:

```text
filt_PAIR_snaphu.unw
filt_PAIR_snaphu.unw.conncomp
```

Need verify actual naming before MintPy.

### Step 7 — Run / patch MintPy batch

Use/adapt:

```text
scripts/linog_batch_p447_mintpy.sh
```

Before running, check:

- Does `.done.FRAME_COMPLETE` exist?
  ```text
  p447/f0300/logs/.done.FRAME_COMPLETE
  ```
- If manual rebuild did not create this sentinel, either:
  - create it after documenting successful ISCE2/IFG completion, or
  - patch precheck.
- Ensure unwrapped IFGs exist.
- Ensure bad pairs are moved/rejected as intended.
- Ensure `mintpy/` and `mintpy_logs/` are clean if rerunning.

### Step 8 — Run MintPy

Expected final outputs:

```text
mintpy/timeseries.h5
mintpy/timeseries_ramp_demErr.h5
mintpy/timeseries_demErr.h5
mintpy/velocity.h5
mintpy/velocity_demErr_ramp.h5
mintpy/velocity_demErr.h5
mintpy/geo/geo_velocity_demErr_ramp.h5
mintpy/geo/geo_velocity_demErr.h5
mintpy/geo/geo_timeseries_ramp_demErr.h5
mintpy/geo/geo_timeseries_demErr.h5
```

---

## 22. Important Cautions

- Do not rerun p447/f0300 IFG generation with `-S alos`.
- Always use:
  ```text
  -a 28 -r 12
  ```
  for target ~90 m products.
- Current `Igrams/` are corrected 28×12 wrapped products.
- MintPy requires unwrapped IFGs; current state is wrapped only.
- Existing p447 MintPy script expects `.unw` files and will fail without them.
- Existing script excludes four problematic f0300 pairs.
- Before physical pair exclusion, backup `Igrams/` or rely on reversible move to:
  ```text
  Igrams/rejected_pairs/
  ```

---

## 23. Useful Verified Remote Logs

```text
manual_run_logs/verify_all_igrams_28az_12rng_20260610_145708.log
manual_run_logs/check_igram_dimensions_28az_12rng_*.log
manual_run_logs/run08_igram_28az_12rng_j4_*.log
manual_run_logs/regenerate_igram_configs_28az_12rng_*.log
manual_run_logs/60_post_run08_igram_qc_20260610_143555.log
manual_run_logs/61_compute_coherence_statistics_all_pairs_20260610_143647.log
README_CLEAN_REBUILD.txt
```

---

## 24. Current Answer to Original Concern

The earlier report-frame size mismatch was caused by:

```text
-S alos auto-scaling azimuth looks
```

which generated:

```text
40 az × 10 rng
```

instead of:

```text
28 az × 12 rng
```

The corrected workflow used:

```text
-a 28 -r 12
```

without `-S alos`.

All 66 corrected IFGs are now:

```text
778 x 658
```

and the regenerated GitHub report pages are consistent with the corrected higher-resolution products.

---

## 25. Suggested Opening Prompt for Next Chat

Paste this at the beginning of the next chat:

```text
We are continuing P447/F0300 LInOG InSAR processing. Please read this handoff. The corrected 28 az × 12 rng wrapped IFGs are complete and reports were regenerated. Next task: prepare unwrapping and MintPy processing using the LInOG manual and existing batch scripts, especially linog_batch_p447_mintpy.sh. First check the current repo scripts for p447/p448/p449 MintPy workflows and verify what needs patching before running MintPy.
```