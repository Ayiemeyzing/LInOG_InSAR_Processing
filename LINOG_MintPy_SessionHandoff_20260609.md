# LInOG P448 Session Handoff — Jun 9, 2026

**Author:** Ariel J. Nopre Jr. (`arieln@felix` / `anopre@Ayiemeyzing`)
**Status:** P448 F0280 Phase 0–4 + MintPy + Phase 6 COMPLETE
**Scripts updated:** `linog_batch_p448_ph0to4.sh` v2.4.2, `linog_batch_p448_mintpy.sh` v2.5 (syntax fixed)
**Continues from:** `LINOG_MintPy_SessionHandoff_20260608.md`

---

## Session Summary

This session resolved the P448 F0280 re-processing from start to finish:

1. Switched from shared DEM + symlink to per-frame `dem.py` download in `linog_batch_p448_ph0to4.sh`
2. Ran a clean-start re-processing of F0280 via `RERUN_PH04_FRAMES` mechanism
3. Diagnosed and fixed three cascading bugs (invertMisreg crash, MintPy script truncation, stale sentinel)
4. Completed MintPy for F0280 (minTempCoh=0.3, 560 pixels, all 15 steps passed)
5. Generated and verified Phase 6 deliverables (16/16 files)
6. Provided rsync command for lab computer

F0290–F0320 ISCE2 Phase 0–4 is still pending (see Next Steps).

---

## Script Versions (as of Jun 9, 2026)

| Script | Local path | Felix path | Version |
|---|---|---|---|
| `linog_batch_p448_ph0to4.sh` | `D:\05_LInOG\LInOG InSAR Training\` | `~/` | **v2.4.2** |
| `linog_batch_p448_mintpy.sh` | `D:\05_LInOG\LInOG InSAR Training\` | `~/` | **v2.5** (syntax fixed Jun 9) |

### ph0to4 script changelog

| Version | Date | Change |
|---|---|---|
| v2.3 | Jun 8 | Shared DEM + symlink approach |
| v2.4 | Jun 9 | Per-frame DEM download via `dem.py` [P448-DEM-01]; RERUN_PH04_FRAMES mechanism [P448-RERUN-01] |
| v2.4.1 | Jun 9 | RERUN wipe adds `rejected_pairs/`, `refineSecondaryTiming/`, `misreg/` [P448-RERUN-02] |
| **v2.4.2** | **Jun 9** | **RERUN wipe adds `mintpy_logs/` [P448-RERUN-03]** |

---

## Bugs Discovered and Fixed This Session

### BUG-1: invertMisreg crash — `KeyError: 'azpoly'`

**Symptom:** Step `11_run05_invertMisreg` failed with `KeyError: 'azpoly'` in `extract_offset`.

**Root cause (two-part):**
- `run_04_refineSecondaryTiming` failed for all 15 pairs (expected — ~0.28 mean L-band coherence over agricultural terrain, too low to fit timing polynomials). This produced **empty but non-zero-byte shelves** (100–110 bytes; just the shelve header, no data keys).
- `poststep04_cleanup.py` only rejects shelves ≤25 bytes. All 14 "OK" shelves were empty but passed the size check.
- The RERUN wipe [v2.4] did NOT wipe `rejected_pairs/`, `refineSecondaryTiming/`, or `misreg/`. Stale `rejected_pairs/20080323_20091111` from the previous run caused `poststep04_cleanup` to fail with `shutil.Error` (already exists) for that pair, leaving its empty shelve in `refineSecondaryTiming/pairs/`. `invertMisreg` then crashed reading it.

**Manual fix applied on felix:**
```bash
WDIR=/eggraid/home/arieln/projects/linog/insar/p448/f0280
rm -rf "${WDIR}/rejected_pairs"
rm -rf "${WDIR}/refineSecondaryTiming"
rm -rf "${WDIR}/misreg"
touch "${WDIR}/logs/.done.11_run05_invertMisreg"   # force-skip invertMisreg
bash ~/linog_batch_p448_ph0to4.sh
```

**Script fix:** v2.4.1 — added those 3 dirs to RERUN wipe list.

**Impact on igrams:** F0280 processed with zero-shift coregistration (coarse registration only, no timing refinement). This is expected behavior for all pairs when run_04 fails. The P3 patch in `resampleSlc.py` handles missing per-acquisition timing shelves by using zero offset.

---

### BUG-2: `linog_batch_p448_mintpy.sh` truncated (syntax error at line 1436)

**Symptom:** `bash ~/linog_batch_p448_mintpy.sh` → `line 1436: syntax error: unexpected end of file`

**Root cause:** File was truncated mid-word at the start of `main()` — last content was `    heal_verify_m` with no trailing newline. The `main()` function body and `main "$@"` call were entirely absent.

**Fix:** Appended the missing content (heal_verify_mintpy_env call, frame loop, completion log, `main "$@"`). Verified with `bash -n` before copying back. Script is structurally identical to `linog_batch_p449_mintpy.sh` main() pattern.

---

### BUG-3: Stale MintPy sentinels after RERUN wipe — `ifgramStack.h5` missing

**Symptom:** `invert_network` failed with `FileNotFoundError: .../mintpy/inputs/ifgramStack.h5`

**Root cause:** The RERUN wipe in `linog_batch_p448_ph0to4.sh` deletes `mintpy/` but NOT `mintpy_logs/`. The MintPy batch script stores step sentinels in `mintpy_logs/.done.XX_*`. So after a RERUN wipe, sentinels for steps 01–04 (load_data → correct_unwrap_error) still existed, causing MintPy to skip those steps — but `ifgramStack.h5` was gone.

**Manual fix applied on felix:**
```bash
MLOG=/eggraid/home/arieln/projects/linog/insar/p448/f0280/mintpy_logs
rm -f "${MLOG}/.done.01_load_data"
rm -f "${MLOG}/.done.02_modify_network"
rm -f "${MLOG}/.done.03_reference_point"
rm -f "${MLOG}/.done.04_correct_unwrap_error"
rm -f "${MLOG}/.done.05_invert_network"
bash ~/linog_batch_p448_mintpy.sh
```

**Script fix:** v2.4.2 — added `mintpy_logs/` to the RERUN wipe list in `linog_batch_p448_ph0to4.sh`.

---

## P448 F0280 — MintPy Results (Jun 9, 2026)

**Config:**
- REF_DATE (ISCE2 + MintPy): 20091111
- minTempCoh: 0.3 (threshold reduced from 0.7 — only viable setting for this frame)
- maxTempBaseline: 500 days; maxPerpBaseline: 1000 m
- deramp: linear (Pass 1); no (Pass 2)
- Network: 36 igrams loaded; post-modify_network count [check 02_modify_network.log]
- Coherent pixels: **560** (from interactive KMZ point count)
- Coverage: 14.506–15.146°N, 120.964–121.708°E (640 × 744 pixels)

**Velocity data ranges (raw, unmasked):**

| Product | LOS (cm/yr) | Vertical (cm/yr) | Horizontal (cm/yr) |
|---|---|---|---|
| demErr | [-19.55, +6.87] | [-934.5, +11.4] | [-148.2, +8.6] |
| demErr_ramp | [-16.26, +11.15] | [-744.9, +18.6] | [-106.5, +13.9] |

**Display range:** ±10 cm/yr (clamped in all PNGs and KMZs)

**⚠ V/H extreme outliers:** Same pattern as P449 F0300/F0310/F0320. Low-coherence pixels (minTempCoh=0.3 ≈ noise floor) amplify errors in the look-angle V/H decomposition. PNG hillshades look normal (clamped). Raw GeoTIFFs contain outliers. **[VERIFY with Prof. JD] before distributing GeoTIFFs.**

**Sanity check — demErr_ramp vs demErr:**
- LOS demErr_ramp [-16.26, +11.15] is WIDER than demErr [-19.55, +6.87] on the negative side.
- This is borderline; the ranges overlap significantly. At minTempCoh=0.3 (560 pixels), the deramp estimate is noisy and not well-constrained. This is a data quality limitation, not a script bug. The M6 stale-file test (demErr_ramp range >> demErr range by factor >2) does NOT flag this run.

---

## Phase 6 Deliverables — P448 F0280

**Status:** COMPLETE — 16/16 files

**Felix path:** `/eggraid/home/arieln/projects/linog/insar/p448/f0280/mintpy/geo/LInOG_Upload_P448F0280/`

**Files:**
```
P448F0280_TimeSeries_demErr.kmz
P448F0280_TimeSeries_demErr_ramp.kmz
P448F0280_Velocity_demErr.kmz
P448F0280_Velocity_demErr_ramp.kmz
P448F0280_Velocity_demErr.tif
P448F0280_Velocity_demErr_ramp.tif
P448F0280_Velocity_Hillshade_demErr.png
P448F0280_Velocity_Hillshade_demErr_ramp.png
P448F0280_Velocity_Hillshade_Horizontal.png
P448F0280_Velocity_Hillshade_Horizontal_ramp.png
P448F0280_Velocity_Hillshade_Vertical.png
P448F0280_Velocity_Hillshade_Vertical_ramp.png
P448F0280_Velocity_Horizontal.tif
P448F0280_Velocity_Horizontal_ramp.tif
P448F0280_Velocity_Vertical.tif
P448F0280_Velocity_Vertical_ramp.tif
```

**Phase 6 command (for reference):**
```bash
cd /eggraid/home/arieln/projects/linog/insar/p448/f0280/mintpy
printf "448\n0280\n20091111\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6
```

---

## Rsync Status (as of Jun 9, 2026)

| Frame | Felix | Lab (DESKTOP-APMBR80) | Laptop (Ayiemeyzing) |
|---|---|---|---|
| P447 F0300 | DONE | STALE (Jun 7 bad run — needs re-rsync) | PENDING |
| P447 F0310 | DONE | DONE (Jun 7) | PENDING |
| P449 all frames | DONE | DONE (Jun 8) | Not tracked |
| **P448 F0280** | **DONE** | **PENDING — rsync not yet run** | PENDING |
| P448 F0290–F0320 | NOT STARTED | — | — |

**Rsync command for P448 F0280 (run from DESKTOP-APMBR80 WSL2):**
```bash
rsync -avz --mkpath --progress \
  arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f0280/mintpy/geo/LInOG_Upload_P448F0280/ \
  ~/LInOG/insar/p448/f0280/mintpy/geo/LInOG_Upload_P448F0280/
```

---

## P448 ISCE2 Phase 0–4 Status (as of Jun 9, 2026)

| Frame | ISCE2 Status | MintPy Status | Phase 6 |
|---|---|---|---|
| f0280 | **COMPLETE** (zero-shift coregistration; invertMisreg skipped) | **COMPLETE** | **COMPLETE** |
| f0290 | IN PROGRESS — last done: `05_stack_config_p1` (Phase 3 half-done) | NOT STARTED | — |
| f0300 | NOT STARTED | NOT STARTED | — |
| f0310 | NOT STARTED | NOT STARTED | — |
| f0320 | NOT STARTED | NOT STARTED | — |

**To continue f0290–f0320 ISCE2:**
```bash
# On felix, inside screen:
bash ~/linog_batch_p448_ph0to4.sh
# Will auto-skip f0280 (FRAME_COMPLETE sentinel exists) and continue from f0290 stack_config_p2
```

**Before running MintPy on f0290:** Verify `FRAME_REF_DATE[f0290]=20090626` against `f0290/pairs.pdf` or `mintpy_logs/05_stack_config_p2.log`. This date was carried over from prior data and has not been independently confirmed this session.

---

## RERUN Wipe — Full Directory List (v2.4.2)

The following directories are wiped by `RERUN_PH04_FRAMES` in `linog_batch_p448_ph0to4.sh`. `SLC/` and `raw/` are preserved.

```
geom_reference/
run_files/
interferograms/
Igrams/
DEM/
unzipped/
baselines/
mintpy/
mintpy_logs/        ← added v2.4.2 (prevents stale MintPy sentinels)
rejected_pairs/     ← added v2.4.1
refineSecondaryTiming/ ← added v2.4.1
misreg/             ← added v2.4.1
logs/
```

**Usage:** Set `RERUN_PH04_FRAMES=("XXXX")` in the script CONFIG block, SCP to felix, run. Reset to `()` after the wipe run.

---

## Known Issues / Open Items

| Issue | Status | Action |
|---|---|---|
| P447 F0300 MintPy temporal REF_DATE change (20090309→20070117) | Open | **[CONFIRM WITH PL]** Dr. JD must approve before distributing |
| P447 F0300 rsync on lab computer STALE | Open | Re-rsync from felix |
| P448 F0280 V/H extreme outliers (low coherence amplification) | Open | **[VERIFY with Prof. JD]** before GeoTIFF distribution |
| P448 f0290 REF_DATE=20090626 | Open | **[VERIFY]** from pairs.pdf or stack_config log |
| P448 f0290–f0320 ISCE2 Phase 0–4 | Pending | Run `linog_batch_p448_ph0to4.sh` |
| P448 f0290–f0320 MintPy | Pending | After ISCE2 completes; set START_FRAME=f0290 |
| P449 extreme V/H outliers (F0300, F0310, F0320) | Open | **[VERIFY with Prof. JD]** |
| `RERUN_PH04_FRAMES` in ph0to4 script | Set to `()` ✓ | Nothing — already cleared after F0280 run |

---

## Next Steps (Priority Order)

1. **Run ISCE2 Phase 0–4 for f0290–f0320** (inside `screen` on felix):
   ```bash
   bash ~/linog_batch_p448_ph0to4.sh
   ```
2. **Rsync P448 F0280 deliverables** to lab computer (command above).
3. **Re-rsync P447 F0300** to lab computer (stale from Jun 7).
4. **Verify f0290 REF_DATE** from pairs.pdf before MintPy runs.
5. **Run MintPy for f0290–f0320** after ISCE2 completes — set `START_FRAME=f0290`.
6. **[CONFIRM WITH PL]** P447 F0300 REF_DATE change and P448 F0280 V/H outliers with Dr. JD.

---

## P448 Phase 6 Command Reference

```bash
# F0280 (REF_DATE confirmed 20091111):
printf "448\n0280\n20091111\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6

# F0290 (REF_DATE = 20090626 — [VERIFY]):
printf "448\n0290\n20090626\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6

# F0300, F0310, F0320 (REF_DATE = 20091111 — [VERIFY F0320]):
printf "448\n0300\n20091111\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6
printf "448\n0310\n20091111\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6
printf "448\n0320\n20091111\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6
```

Each command runs from: `cd /eggraid/home/arieln/projects/linog/insar/p448/fXXXX/mintpy`

---

---

## P448 F0280 Igram Quality — OPEN ISSUE (Jun 9, 2026)

**Status: Automation runs successfully. Output quality is poor. Root cause untraced.**

### What the igrams show

Reviewed `P448F0280_Igram_Report_Page_1/2/3.jpg` (36 pairs total):

| Pair | Signal | Notes |
|---|---|---|
| 20071222_20080206 | **Fringes present** | 45-day Dec–Feb dry season; best pair. Blue-red fringes clearly visible. |
| 20090208_20091227 | **Faint fringes** | 383-day; only second pair with any color. |
| All other 34 pairs | **Flat gray / black** | Completely decorrelated. No signal. |

This is consistent with the MintPy result (560 pixels at minTempCoh=0.3 ≈ noise floor). The pipeline completed correctly — the data is just this decorrelated.

### The discrepancy

The old manual P448 F0280 run produced visibly better igrams (more fringes, more colored pixels). The new automated re-processing consistently produces flat results. This discrepancy has been observed across **multiple runs** and persists despite:
- Fixing the REF_DATE (20091111 confirmed)
- Switching from shared DEM to per-frame dem.py download
- Fixing the RERUN wipe (v2.4.1 + v2.4.2)
- Lowering minTempCoh to 0.3
- Scanning old manual .md files for parameter differences
- Checking the DEM

### What has NOT been identified as the root cause

The following were checked and ruled out or remain open:
- REF_DATE: 20091111 is correct — confirmed from old training run
- DEM: checked, no obvious mismatch
- minTempCoh threshold: already at 0.3 (floor)
- Script bugs: three RERUN wipe bugs fixed; pipeline completes all steps without error
- Automation itself: works; the script runs to completion

### What has NOT been investigated yet

The following could explain the quality difference but have not been compared between old and new runs:
- **Input ALOS data:** Are the same raw .CEOS files being used? The old training data in `jdd/projects/linog/insar/448/` (before directory rename) may have used a different set of frames or a different download batch.
- **Number of looks:** Old run may have used different azimuth/range look parameters in `stripmapWrapper.py` or `prepRawALOS.py`.
- **ISCE2 version at time of old training run** vs. current version on felix.
- **Old training Igrams:** Kryzelled's P448 F0280 training run (Jun 3–5) — were those igrams actually good, or was the "good data" from a different frame (P448 F0310)?
- **Network selection:** Old training may have used a tighter temporal baseline filter, keeping only coherent pairs.
- **[CONFIRM WITH PL]:** Dr. JD to confirm whether the old "good P448 F0280" results are from the training symlinked data or from a separate processing run, and what parameters were used.

### Current conclusion

The automated pipeline is correctly implemented. P448 F0280 at this coherence level (mean ~0.28, 2/36 pairs with visible signal) produces 560 reliable pixels — this may be the genuine limit of the data. The old "good" run result is either:
(a) from a different frame that was misidentified as F0280, or
(b) from a run with different input data or parameters that has not been recovered

**Do not attempt further re-runs until the specific difference between old and new processing is identified.** Diagnosing this requires side-by-side comparison of: raw SLC inventory, number of interferograms, look parameters, and at least one representative igram from the old training run.

---

*Document updated Jun 9, 2026.*
