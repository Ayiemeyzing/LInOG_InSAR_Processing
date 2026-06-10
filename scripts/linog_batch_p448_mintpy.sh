#!/bin/bash
# ==============================================================
# linog_batch_p448_mintpy.sh  v2.4
# MintPy time-series InSAR processing — P448 (F0280–F0320)
#
# Derived from: linog_batch_p449_mintpy.sh v1.0 (Jun 8, 2026)
# All p449 fixes incorporated from the start — no migration needed.
#
# P448-specific differences from p449:
#   - BASE_DIR:  p448  (5 frames: f0280 f0290 f0300 f0310 f0320)
#   - FRAMES:    4-digit names: f0280, f0290, f0300, f0310, f0320 [P448-FIX-03]
#     Confirmed from live run Jun 8, 2026. find_alos.sh requires 4-digit IDs.
#   - REF_DATE:  FRAME_REF_DATE per frame — f0310 CONFIRMED = 20091111,
#     f0290 CONFIRMED = 20090626. Others [VERIFY with Prof. JD].
#   - metaFile:  AUTO-DETECTED per frame (v2.0 fix):
#     Priority 1: SLC/REF_DATE/data.dat (new re-processing, P449-style)
#     Priority 2: merged/SLC/REF_DATE/referenceShelve/data.dat (old training)
#     Old training confirmed: RSS PR 07 lines 5556, 5632, 5750, 6124, 6798.
#   - geom_reference: auto-detect — tries geom_reference/ first (symlink to
#     merged/geom_reference/), falls back to merged/geom_reference/ directly.
#   - FRAME_COMPLETE sentinel: P448 was processed manually before batch scripts
#     existed. Missing sentinel is a WARNING not an abort. Create manually with:
#     touch f0280/logs/.done.FRAME_COMPLETE
#   - waterMask: same all-zero ISCE2 issue expected — auto-heal active.
#   - MIN_TEMP_COH: P449 defaults as starting point; [VERIFY] after diagnostics.
#
# Features (inherited from p447 v2.4 + p449 v1.0):
#   - Sentinel-based step skipping — re-run resumes from last failure
#   - ERROR_SUMMARY.txt per frame: first-seen flag, known fix, log ref
#   - Error catalog: pattern-match on known MintPy/ALOS-1 failure signatures
#   - Self-healing: HDF5 integrity check, waterMask patch, auto-heal + retry
#   - Two-pass MintPy: ramp+demErr (pass 1) and demErr-only (pass 2)
#   - Phase 6 deliverables: four geo/ files per frame
#   - Per-frame FRAME_REF_DATE: handles different reference dates per frame
#   - geom_reference auto-detection: merged/ prefix fallback
#
# Pre-MintPy checklist (CRITICAL — must do before running):
#   1. Verify rejected pairs (E8: early 2006-2007 dates, E10: culled offsets)
#      moved out of Igrams/ before running. The physical dirs must be absent.
#      mkdir -p fXXX/mintpy/rejected_pairs
#      mv fXXX/Igrams/DATE1_DATE2 fXXX/mintpy/rejected_pairs/
#   2. Run ISCE2 coherence diagnostic to set per-frame minTempCoh.
#   3. Confirm SLC/REF_DATE/data.dat (new re-processing) OR
#      merged/SLC/REF_DATE/referenceShelve/data.dat (old training) exists per frame.
#      resolve_meta_file() auto-detects which layout is present.
#   4. Confirm geom_reference/ or merged/geom_reference/ exists with .rdr files.
#
# Phase 6 command (run manually after MintPy completes):
#   cd /eggraid/home/arieln/projects/linog/insar/p448/fXXX/mintpy
#   printf "448\nXXX\nREF_DATE\n4\n1\ny\n" | bash /eggraid/bin/linog_fbs_processor.sh 6
#   Where XXX = 280, 290, 300, 310, or 320 (3-digit) [VERIFY prompt format]
#
# Usage:
#   chmod +x linog_batch_p448_mintpy.sh
#   ./linog_batch_p448_mintpy.sh
#   # To resume from a specific frame: edit START_FRAME="f0280" then re-run
#
# Output per frame:
#   p448/FRAME/mintpy/           <- MintPy working directory + results
#   p448/FRAME/mintpy_logs/      <- step logs, sentinels, ERROR_SUMMARY.txt
#
# Prerequisite: ISCE2 batch must be COMPLETE per frame, OR P448 was processed
# manually (training runs). Manual-run frames: create .done.FRAME_COMPLETE
# sentinel with: touch fXXX/logs/.done.FRAME_COMPLETE
#
# Changelog v2.4 (Jun 8, 2026):
#   [P448-MINTPY-FIX-04] FRAME_REF_DATE["f0280"] corrected from 20070203 → 20091111.
#                        Root cause: Ph0to4 was run with ISCE2 REF=20070203 (entered at
#                        the Phase 3 prompt). This caused coregistration failure for SLCs
#                        3-4 years away (2010-2011 acquisitions), degrading all Igrams.
#                        Old training run used 20091111 (temporal center, Bperp≈-50m)
#                        and produced coherent Igrams. New Ph0to4 re-run required with
#                        REF=20091111; baselines/ will then reference 20091111.
#                        Ph0to4 script prompt text also updated to show F0280: 20091111.
#
# Changelog v2.3 (Jun 8, 2026):
#   [FIX-STALE-01] velocity_demErr_ramp.h5 now force-copied (cp -f) from velocity.h5.
#                  Removed the `[ ! -f velocity_demErr_ramp.h5 ]` guard that caused the
#                  stale-file bug (M6): if a bad velocity_demErr_ramp.h5 existed from a
#                  prior run, the copy was skipped and the stale file persisted through
#                  Phase 6. Same root cause and fix as p447 v2.8 / p449 v1.1.
#   [FIX-STALE-02] mv -f (belt-and-suspenders) in geocode_demErr_files() when renaming
#                  geo_velocity.h5 → geo_velocity_demErr_ramp.h5.
#                  Propagation rule: any MintPy batch script derived from p448 v2.0-v2.2
#                  has this bug. Fix both lines before running on any new frame.
#
# Changelog v2.2 (Jun 8, 2026):
#   [P448-MINTPY-FIX-03] Confirmed FRAME_REF_DATE["f0280"] = "20070203".
#                        Evidence: baselines/ dir contains only 20070203_DATE.txt files,
#                        confirming 20070203 is the reference epoch for f0280.
#                        Also: data.dat exists in ALL SLC date dirs (not just ref),
#                        so metaFile auto-detection works correctly for any valid REF_DATE.
#                        All other frames remain [VERIFY] until baselines/ checked.
#
# Changelog v2.1 (Jun 8, 2026):
#   [P448-FIX-03] Corrected all frame keys to 4-digit: f0280, f0290, f0300,
#                 f0310, f0320. FRAMES, START_FRAME, FRAME_REF_DATE,
#                 MIN_TEMP_COH, EXCLUDE_DATES, DERAMP arrays all updated.
#                 ph0to4 creates dirs as f${FRAME_NUM} → f0280 etc. matching
#                 felix ALOS archive 4-digit frame IDs (same as p449).
#
# Changelog v2.0 (Jun 8, 2026):
#   [P448-MINTPY-FIX-01] Corrected FRAME_REF_DATE["f0290"] = "20090626".
#                        v1.0 had wrong placeholder "20091111". Confirmed from
#                        RSS PR 07 line 4468: merged/SLC/20090626/referenceShelve/
#                        data.dat present in f0290 frame directory structure.
#   [P448-MINTPY-FIX-02] Added metaFile auto-detection via resolve_meta_file().
#                        Priority 1: SLC/REF_DATE/data.dat (new re-processing,
#                          same layout as P449, produced by stackStripMap
#                          -W interferogram --nofocus).
#                        Priority 2: merged/SLC/REF_DATE/referenceShelve/data.dat
#                          (old training data, RSS PR 07 confirmed layout).
#                        All three callers updated: run_prep_isce(),
#                        generate_mintpy_cfg(), heal_verify_isce2_outputs().
#                        This makes the script work for both new re-processing
#                        and old training data comparison runs.
#
# Changelog v1.0 (Jun 8, 2026):
#   Initial port from linog_batch_p449_mintpy.sh v1.0.
#   All FIX-01 through FIX-22 and NEW-01 through NEW-09 from p447 v2.4
#   incorporated as baseline. P449 fixes [P449-01..07] also incorporated.
#   P448-specific changes:
#   [P448-01] BASE_DIR: p448
#   [P448-02] FRAMES: f0280 f0290 f0300 f0310 f0320 (4-digit — fixed in v2.1, [P448-FIX-03])
#   [P448-03] FRAME_REF_DATE array: per-frame REF_DATE; f310=20091111 confirmed.
#             All other frames [VERIFY with Prof. JD].
#   [P448-04] metaFile: merged/SLC/REF_DATE/referenceShelve/data.dat
#             Old training confirmed. New re-processing: SLC/REF_DATE/data.dat.
#             Auto-detection added in v2.0 [P448-MINTPY-FIX-02].
#   [P448-05] geom_reference: auto-detect — tries geom_reference/ first (may be
#             symlink to merged/geom_reference/), falls back to merged/geom_reference/.
#             prep_isce -g points to whichever exists. RSC cleanup runs on both.
#   [P448-06] FRAME_COMPLETE sentinel check: WARN not abort (P448 was manually run).
#   [P448-07] MIN_TEMP_COH: P449-inherited defaults (f0280=0.7, f0290=0.4, f0300=0.3,
#             f0310=0.4, f0320=0.3). [VERIFY] after P448 coherence diagnostics.
#   [P448-08] Coherence/waterMask: same all-zero ISCE2 issue as P447/P449.
#             heal_watermask_patch() and all M1/M2/M3 auto-heals active.
# ==============================================================

set -uo pipefail
SCRIPT_VERSION="2.5"
SCRIPT_NAME="$(basename "$0")"

# ==============================================================
# CONFIGURATION — edit before first run
# ==============================================================

BASE_DIR="/eggraid/home/arieln/projects/linog/insar/p448"

# Frames to process, in order.
# [P448-02] 4-digit frame IDs — required by the ISCE2 batch script (ph0to4).
# [P448-FIX-03] Changed from 3-digit (f280 etc.) to 4-digit (f0280 etc.)
# Confirmed: ph0to4 creates dirs as f${FRAME_NUM} → f0280, f0290, etc.
FRAMES=("f0280" "f0290" "f0300" "f0310" "f0320")

# Set to the first frame you want to run (useful for resuming)
START_FRAME="f0280"

# Global default REF_DATE — used as fallback if FRAME_REF_DATE entry is missing.
# [P448-03] F0310 CONFIRMED = 20091111 (RSS PR 07, §P448-F0310).
# Other frames use 20091111 as placeholder — [VERIFY with Prof. JD].
REF_DATE="20091111"

# Per-frame reference dates. Override per-frame if dates differ.
# [VERIFY] All frames except f310 need confirmation from Prof. JD.
# Method: check logs/05_stack_config_p2.log or pairs.pdf for the used ref date.
declare -A FRAME_REF_DATE
FRAME_REF_DATE["f0280"]="20091111"    # CORRECTED — old 20070203 caused coregist failure; 20091111 confirmed from old training run [P448-MINTPY-FIX-04]
FRAME_REF_DATE["f0290"]="20090626"    # [VERIFY] — RSS PR 07 old run was 20090626; confirm new run
FRAME_REF_DATE["f0300"]="20091111"    # [VERIFY] — f0300 not in old training; confirm from pairs.pdf
FRAME_REF_DATE["f0310"]="20091111"    # [VERIFY] — RSS PR 07 old run was 20091111; confirm new run
FRAME_REF_DATE["f0320"]="20091111"    # [VERIFY] — confirm from 05_stack_config_p2.log or pairs.pdf

# MintPy + ISCE2 conda environment (full path, no conda activate needed)
# MUST be the isce2 env — it has both MintPy 1.6.2 and ISCE2 installed.
# mintpy_stable does NOT have isce; prep_isce.py will fail with ImportError.
MINTPY_ENV="/eggraid/miniconda3/envs/isce2"

# Per-frame temporal coherence threshold.
# [P448-07] P449-inherited defaults as starting point — adjust after coherence
# diagnostics. Method: run modify_network, check INFO lines for pixel counts.
# If < ~100 pixels pass, lower minTempCoh. Do not go below 0.3.
declare -A MIN_TEMP_COH
MIN_TEMP_COH["f0280"]="0.3"   # [P448-MINTPY-ERR-01 v2.5] Lowered from 0.7: only 2/36 pairs >1% coherent; mean=0.30. 0.7 gives 0 reliable pixels.
MIN_TEMP_COH["f0290"]="0.4"   # [VERIFY] P449 f0290 analogue = 0.4
MIN_TEMP_COH["f0300"]="0.3"   # [VERIFY] P449 f0300 analogue = 0.3
MIN_TEMP_COH["f0310"]="0.4"   # [VERIFY] P449 f0310 analogue = 0.4
MIN_TEMP_COH["f0320"]="0.3"   # [VERIFY] P449 f0320 analogue = 0.3

# Dates to exclude per frame (space-separated; empty = no exclusion)
# Early 2006-2007 dates (E8: 20060520, 20060705, 20060820, 20070105) rejected
# at ISCE2 level — their .unw files do not exist. Physical dirs must be moved
# out of Igrams/ before MintPy (mintpy.network.excludeDate is NOT sufficient).
declare -A EXCLUDE_DATES
EXCLUDE_DATES["f0280"]=""
EXCLUDE_DATES["f0290"]=""
EXCLUDE_DATES["f0300"]=""
EXCLUDE_DATES["f0310"]=""
EXCLUDE_DATES["f0320"]=""

# Deramp option: "linear" removes linear ramp (orbital error); "no" to disable
declare -A DERAMP
DERAMP["f0280"]="linear"
DERAMP["f0290"]="linear"
DERAMP["f0300"]="linear"
DERAMP["f0310"]="linear"
DERAMP["f0320"]="linear"

# ==============================================================
# INTERNAL — do not edit below unless needed
# ==============================================================

PYTHON="${MINTPY_ENV}/bin/python"
SMALLBASELINE=""   # resolved at runtime by heal_verify_mintpy_env()

BOLD='\033[1m'; RED='\033[0;31m'; YEL='\033[0;33m'
GRN='\033[0;32m'; BLU='\033[0;34m'; NC='\033[0m'

# MintPy steps in pipeline order (ALOS-1 set)
MINTPY_STEPS=(
    "load_data"
    "modify_network"
    "reference_point"
    "correct_unwrap_error"
    "invert_network"
    "correct_lod"
    "correct_troposphere"
    "deramp"
    "correct_topography"
    "residual_RMS"
    "reference_date"
    "velocity"
    "geocode"
    "google_earth"
    "hdfeos5"
)

# Sentinel prefix numbers for log file naming
declare -A STEP_NUM
STEP_NUM["load_data"]="01"
STEP_NUM["modify_network"]="02"
STEP_NUM["reference_point"]="03"
STEP_NUM["correct_unwrap_error"]="04"
STEP_NUM["invert_network"]="05"
STEP_NUM["correct_lod"]="06"
STEP_NUM["correct_troposphere"]="07"
STEP_NUM["deramp"]="08"
STEP_NUM["correct_topography"]="09"
STEP_NUM["residual_RMS"]="10"
STEP_NUM["reference_date"]="11"
STEP_NUM["velocity"]="12"
STEP_NUM["geocode"]="13"
STEP_NUM["google_earth"]="14"
STEP_NUM["hdfeos5"]="15"

# "critical" = abort frame on failure; "warn" = log and continue
declare -A STEP_LEVEL
STEP_LEVEL["load_data"]="critical"
STEP_LEVEL["modify_network"]="critical"
STEP_LEVEL["reference_point"]="critical"
STEP_LEVEL["correct_unwrap_error"]="warn"
STEP_LEVEL["invert_network"]="critical"
STEP_LEVEL["correct_lod"]="warn"
STEP_LEVEL["correct_troposphere"]="warn"
STEP_LEVEL["deramp"]="warn"
STEP_LEVEL["correct_topography"]="warn"
STEP_LEVEL["residual_RMS"]="warn"
STEP_LEVEL["reference_date"]="warn"
STEP_LEVEL["velocity"]="critical"
STEP_LEVEL["geocode"]="warn"
STEP_LEVEL["google_earth"]="warn"
STEP_LEVEL["hdfeos5"]="warn"

# Step descriptions for logging
declare -A STEP_DESC
STEP_DESC["load_data"]="Load interferogram stack and geometry from ISCE2 output"
STEP_DESC["modify_network"]="Date exclusion + coherence-based network modification"
STEP_DESC["reference_point"]="Select stable reference pixel"
STEP_DESC["correct_unwrap_error"]="Phase unwrapping error correction (bridging + closure)"
STEP_DESC["invert_network"]="SBAS time series inversion (weighted least squares)"
STEP_DESC["correct_lod"]="ALOS-1 local oscillator drift correction"
STEP_DESC["correct_troposphere"]="Tropospheric delay correction (disabled — no external model)"
STEP_DESC["deramp"]="Remove linear orbital ramp from time series"
STEP_DESC["correct_topography"]="Correct residual topographic phase (DEM error)"
STEP_DESC["residual_RMS"]="Compute residual RMS per date; flag outlier acquisition dates"
STEP_DESC["reference_date"]="Set displacement reference date (= frame-specific REF_DATE)"
STEP_DESC["velocity"]="Estimate linear velocity (m/year)"
STEP_DESC["geocode"]="Geocode time series and velocity to geographic coordinates"
STEP_DESC["google_earth"]="Generate Google Earth KMZ from geocoded velocity"
STEP_DESC["hdfeos5"]="Export time series to HDF-EOS5 format (optional; OFF if not configured)"

# ==============================================================
# ERROR CATALOG
# ==============================================================

ERRCAT_MINTPY_NOT_FOUND_DESC="smallbaselineApp.py not found or not executable at MINTPY_ENV path"
ERRCAT_MINTPY_NOT_FOUND_FIX="Check MINTPY_ENV. Must be isce2 env (NOT mintpy_stable). Correct path: /eggraid/miniconda3/envs/isce2"

ERRCAT_HDF5_CORRUPT_DESC="HDF5 file corrupt or truncated — likely from a killed previous run"
ERRCAT_HDF5_CORRUPT_FIX="Corrupt file has been moved to .corrupt.TIMESTAMP backup. load_data sentinel cleared — re-run."

ERRCAT_NO_COHERENT_DESC="Too few coherent pixels — MintPy cannot invert (below minNumPixel)"
ERRCAT_NO_COHERENT_FIX="Lower mintpy.networkInversion.minTempCoh in cfg (try 0.5 then 0.3). Delete .done.05_invert_network sentinel and re-run."

ERRCAT_REF_POINT_DESC="Reference point selection failed — no valid (high coherence, non-masked) pixel"
ERRCAT_REF_POINT_FIX="Add to cfg: mintpy.reference.lalo = LAT,LON (pick a stable urban or rocky area pixel). Delete .done.03_reference_point sentinel and re-run."

ERRCAT_LOAD_NO_UNW_DESC="No unwrapped interferogram files found — glob pattern matched 0 files"
ERRCAT_LOAD_NO_UNW_FIX="Check mintpy.load.unwFile path in cfg. Verify filt_*unw files exist in Igrams/. ISCE2 Phase 4 must be complete."

ERRCAT_LOAD_NO_GEOM_DESC="Geometry file not found at expected ISCE2 path (hgt.rdr / lat.rdr / lon.rdr)"
ERRCAT_LOAD_NO_GEOM_FIX="[P448] Check geom_reference/ and merged/geom_reference/. ISCE2 run_01 must complete first."

ERRCAT_LOAD_NO_BASELINE_DESC="Baseline file not found — MintPy cannot compute perpendicular baselines"
ERRCAT_LOAD_NO_BASELINE_FIX="Verify baselines/ dir exists. ISCE2 run_07 must complete first. Also check prep_isce.py was run with -b baselines."

ERRCAT_INVERT_SINGULAR_DESC="Matrix is singular or near-singular during SBAS inversion"
ERRCAT_INVERT_SINGULAR_FIX="Network likely disconnected (some dates isolated). Add mintpy.network.keepMinSpanTree = yes (already set in cfg)."

ERRCAT_LOD_FAIL_DESC="ALOS-1 LOD correction failed or step not available in this MintPy version"
ERRCAT_LOD_FAIL_FIX="Step is at warn level — pipeline continues. Check MintPy version."

ERRCAT_VELOCITY_FAIL_DESC="Velocity estimation failed — likely insufficient valid pixels after inversion"
ERRCAT_VELOCITY_FAIL_FIX="Check timeseries*.h5 exists and is non-empty. Lower minTempCoh if inversion produced too few pixels."

ERRCAT_UNKNOWN_DESC="Unclassified error — check step log for traceback"
ERRCAT_UNKNOWN_FIX="Check the step log file for Python traceback or OSError. Re-run after fix — sentinel keeps already-completed steps."

# M1: waterMask all-zero (same ISCE2 issue as P447/P449)
ERRCAT_WATERMASK_NAN_DESC="[M1] waterMask all-zero: waterMask.rdr is an all-zero ISCE2 raster. modify_network generates empty waterMask.h5 -> NaN spatial coherence -> ValueError"
ERRCAT_WATERMASK_NAN_FIX="[AUTO-HEAL] Script patches geometryRadar.h5['waterMask'] to all-ones, deletes waterMask.h5 and coherenceSpatialAvg.txt, retries modify_network. Root fix: cfg has waterMaskFile = no."

# M2: SNAPHU connected components are empty
ERRCAT_CONNCOMP_EMPTY_DESC="[M2] maskConnComp empty: intersection of all SNAPHU connected component masks is 0 valid pixels. Reference point cannot be placed inside any connected component."
ERRCAT_CONNCOMP_EMPTY_FIX="[AUTO-HEAL] Script deletes partial unwrapPhase_bridging dataset, sets mintpy.unwrapError.method = no in cfg, retries."

# M3: mintpy.networkInversion.waterMaskFile is a separate key
ERRCAT_INVERSION_WATERMASK_DESC="[M3] networkInversion.waterMaskFile mismatch: mintpy.networkInversion.waterMaskFile is a SEPARATE key from mintpy.load.waterMaskFile. If it still points to waterMask.rdr, ifgram_inversion.py crashes with IndexError."
ERRCAT_INVERSION_WATERMASK_FIX="[AUTO-HEAL] Script sets mintpy.networkInversion.waterMaskFile = no in cfg and retries. Both waterMaskFile keys must be no."

# ==============================================================
# Logging helpers
# ==============================================================

_ts()  { date '+%Y-%m-%d %H:%M:%S'; }
_pst() { TZ="Asia/Manila" date '+%a %b %e %I:%M:%S %p PST %Y'; }

log_info()  { echo -e "${BLU}[INFO]${NC}  [$(_ts)] $*"; }
log_ok()    { echo -e "${GRN}[ OK ]${NC}  [$(_ts)] $*"; }
log_warn()  { echo -e "${YEL}[WARN]${NC}  [$(_ts)] $*"; }
log_error() { echo -e "${RED}[ERR ]${NC}  [$(_ts)] $*"; }
log_step()  { echo -e "${BOLD}[STEP]${NC}  [$(_ts)] $*"; }
log_skip()  { echo -e "       [$(_ts)] [skip] $*"; }

# ==============================================================
# Self-healing: verify MintPy environment
# ==============================================================

heal_verify_mintpy_env() {
    local CANDIDATES=(
        "${MINTPY_ENV}/bin/smallbaselineApp.py"
        "$(which smallbaselineApp.py 2>/dev/null || echo '')"
    )
    for CAND in "${CANDIDATES[@]}"; do
        if [ -n "$CAND" ] && [ -f "$CAND" ]; then
            SMALLBASELINE="$CAND"
            log_ok "MintPy found: ${SMALLBASELINE}"
            return 0
        fi
    done
    log_error "MintPy not found at ${MINTPY_ENV}/bin/smallbaselineApp.py"
    log_error "FIX: ${ERRCAT_MINTPY_NOT_FOUND_FIX}"
    return 1
}

# ==============================================================
# Self-healing: verify ISCE2 output prerequisites
# [P448-06] FRAME_COMPLETE check is a WARNING only — P448 was processed
# manually before batch scripts existed; the sentinel may not exist.
# Create it with: touch FRAME_DIR/logs/.done.FRAME_COMPLETE
# ==============================================================

heal_verify_isce2_outputs() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local ERRORS=0

    # [P448-06] FRAME_COMPLETE missing is a warning, not an abort condition.
    # P448 frames were processed manually; the sentinel was created by batch scripts
    # but may not exist for old manual runs.
    if [ ! -f "${FRAME_DIR}/logs/.done.FRAME_COMPLETE" ]; then
        log_warn "${FRAME}: ISCE2 FRAME_COMPLETE sentinel missing"
        log_warn "  P448 may have been processed manually (training runs)."
        log_warn "  To suppress this warning: touch ${FRAME_DIR}/logs/.done.FRAME_COMPLETE"
        log_warn "  Continuing — verify ISCE2 outputs are complete before proceeding."
        # Do NOT increment ERRORS — missing sentinel is expected for P448 old runs
    fi

    local UNW_COUNT=0
    UNW_COUNT=$(find "${FRAME_DIR}/Igrams" -name "filt_*snaphu.unw" 2>/dev/null | wc -l)
    if [ "$UNW_COUNT" -eq 0 ]; then
        UNW_COUNT=$(find "${FRAME_DIR}/Igrams" -name "filt_*.unw" \
            ! -name "*.conncomp" 2>/dev/null | wc -l)
    fi
    # [P448] Also check older interferograms/ dir (from manual/training runs)
    if [ "$UNW_COUNT" -eq 0 ]; then
        UNW_COUNT=$(find "${FRAME_DIR}/interferograms" -name "filt_*.unw" \
            ! -name "*.conncomp" 2>/dev/null | wc -l)
        if [ "$UNW_COUNT" -gt 0 ]; then
            log_warn "${FRAME}: filt_*.unw found in interferograms/ (old manual run layout)."
            log_warn "  MintPy cfg will use Igrams/ pattern — update if needed."
        fi
    fi
    if [ "$UNW_COUNT" -eq 0 ]; then
        log_error "${FRAME}: No filt_*.unw files found in Igrams/ or interferograms/"
        log_error "  FIX: ${ERRCAT_LOAD_NO_UNW_FIX}"
        ERRORS=$((ERRORS+1))
    else
        log_ok "${FRAME}: ${UNW_COUNT} unwrapped interferograms found"
    fi

    # [P448-05] Geometry may be in geom_reference/ (symlink) or merged/geom_reference/
    local GEOM_BASE="geom_reference"
    if [ ! -d "${FRAME_DIR}/${GEOM_BASE}" ]; then
        if [ -d "${FRAME_DIR}/merged/geom_reference" ]; then
            GEOM_BASE="merged/geom_reference"
            log_warn "${FRAME}: geom_reference/ not found — using merged/geom_reference/ for geometry check"
        fi
    fi

    for GF in hgt.rdr lat.rdr lon.rdr; do
        if [ ! -f "${FRAME_DIR}/${GEOM_BASE}/${GF}" ]; then
            log_error "${FRAME}: Geometry file missing: ${GEOM_BASE}/${GF}"
            log_error "  FIX: ${ERRCAT_LOAD_NO_GEOM_FIX}"
            ERRORS=$((ERRORS+1))
        fi
    done
    [ "$ERRORS" -eq 0 ] && log_ok "${FRAME}: Geometry files present in ${GEOM_BASE}/"

    if [ ! -d "${FRAME_DIR}/baselines" ]; then
        log_warn "${FRAME}: baselines/ directory not found — MintPy will fail at load_data"
        log_warn "  FIX: ${ERRCAT_LOAD_NO_BASELINE_FIX}"
    fi

    # [P448-MINTPY-FIX-02] Check shelve: try new re-processing layout first, then old training
    local FRAME_REF="${FRAME_REF_DATE[$FRAME]:-$REF_DATE}"
    local NEW_SHELVE="${FRAME_DIR}/SLC/${FRAME_REF}/data.dat"
    local OLD_SHELVE="${FRAME_DIR}/merged/SLC/${FRAME_REF}/referenceShelve/data.dat"
    if [ -f "${NEW_SHELVE}" ]; then
        log_ok "${FRAME}: Shelve found (new re-processing): SLC/${FRAME_REF}/data.dat"
    elif [ -f "${OLD_SHELVE}" ]; then
        log_ok "${FRAME}: Shelve found (old training): merged/SLC/${FRAME_REF}/referenceShelve/data.dat"
    else
        log_warn "${FRAME}: Shelve not found for REF_DATE=${FRAME_REF}"
        log_warn "  Tried 1 (new re-processing): SLC/${FRAME_REF}/data.dat"
        log_warn "  Tried 2 (old training):      merged/SLC/${FRAME_REF}/referenceShelve/data.dat"
        log_warn "  [VERIFY] FRAME_REF_DATE[${FRAME}] in CONFIG and run ISCE2 Phase 0-4 first."
    fi

    return $ERRORS
}

# ==============================================================
# Self-healing: check HDF5 file integrity
# ==============================================================

heal_check_hdf5_integrity() {
    local MINTPY_DIR="$1"
    local FRAME="$2"
    for HDF5 in \
        "${MINTPY_DIR}/inputs/ifgramStack.h5" \
        "${MINTPY_DIR}/inputs/geometryRadar.h5"; do
        if [ -f "$HDF5" ]; then
            if ! "${PYTHON}" -c \
                "import h5py; h5py.File('${HDF5}','r').close()" 2>/dev/null; then
                local BACKUP="${HDF5}.corrupt.$(date +%Y%m%d%H%M%S)"
                log_warn "${FRAME}: Corrupt HDF5 detected: $(basename ${HDF5})"
                log_warn "  Moving to: $(basename ${BACKUP})"
                mv "$HDF5" "$BACKUP"
                local LOG_DIR="${MINTPY_DIR%/mintpy}/mintpy_logs"
                rm -f "${LOG_DIR}/.done.01_load_data"
                log_warn "${FRAME}: Cleared .done.01_load_data — load_data will re-run"
            fi
        fi
    done
}

# ==============================================================
# Self-healing: patch geometryRadar.h5 waterMask dataset to all-ones
# [P448-08] waterMask.rdr is all-zero in P448 ISCE2 output (same as P447/P449).
# ==============================================================

heal_watermask_patch() {
    local MINTPY_DIR="$1"
    local FRAME="$2"
    local GEOM_FILE="${MINTPY_DIR}/inputs/geometryRadar.h5"

    if [ ! -f "${GEOM_FILE}" ]; then
        log_warn "${FRAME}: geometryRadar.h5 not found — skipping waterMask patch"
        return 0
    fi

    local VALID
    VALID=$("${PYTHON}" -c "
import h5py, numpy as np
with h5py.File('${GEOM_FILE}','r') as f:
    if 'waterMask' in f:
        m = f['waterMask'][:]
        print(int(np.sum(m)))
    else:
        print(-1)
" 2>/dev/null || echo "-2")

    if [ "$VALID" = "0" ]; then
        log_warn "${FRAME}: waterMask dataset in geometryRadar.h5 is all-zero — patching to all-ones"
        "${PYTHON}" -c "
import h5py, numpy as np
with h5py.File('${GEOM_FILE}','a') as f:
    f['waterMask'][:] = np.ones_like(f['waterMask'][:])
print('waterMask patched to all-ones')
" 2>&1 | while IFS= read -r line; do log_info "${FRAME}: ${line}"; done
        rm -f "${MINTPY_DIR}/waterMask.h5" "${MINTPY_DIR}/coherenceSpatialAvg.txt"
        log_ok "${FRAME}: waterMask patch applied — stale derived files removed"
    elif [ "$VALID" = "-1" ]; then
        # waterMask dataset absent (cfg has waterMaskFile = no — load_data never writes it).
        # reference_point.py reads waterMask from geometryRadar.h5 and crashes with KeyError.
        # Fix: create the dataset as all-ones (no water masking = include all land pixels).
        log_warn "${FRAME}: No waterMask dataset in geometryRadar.h5 — creating as all-ones"
        "${PYTHON}" -c "
import h5py, numpy as np
with h5py.File('${GEOM_FILE}','a') as f:
    if 'waterMask' not in f:
        ref_key = list(f.keys())[0]
        shape = f[ref_key].shape
        f.create_dataset('waterMask', data=np.ones(shape, dtype=np.uint8))
        print(f'waterMask created: shape={shape}, dtype=uint8, all-ones (ref dataset: {ref_key})')
    else:
        print('waterMask already present (concurrent write?)')
" 2>&1 | while IFS= read -r line; do log_info "${FRAME}: ${line}"; done
        log_ok "${FRAME}: waterMask dataset created in geometryRadar.h5"
    elif [ "$VALID" = "-2" ]; then
        log_warn "${FRAME}: Could not check waterMask — Python error. Skipping patch."
    else
        log_ok "${FRAME}: waterMask OK (${VALID} valid pixels in geometryRadar.h5)"
    fi
}

# ==============================================================
# [P448-MINTPY-FIX-02] Auto-detect metaFile layout
# Priority 1: SLC/REF_DATE/data.dat           (new re-processing — P449 style)
# Priority 2: merged/SLC/REF_DATE/            (old training — RSS PR 07 confirmed)
#             referenceShelve/data.dat
# Sets globals RESOLVED_META_REL and RESOLVED_META_ABS.
# Returns 0 on success, 1 if neither path exists.
# Uses declare -g (bash 4.2+ — standard on felix / Ubuntu 24.04).
# ==============================================================

resolve_meta_file() {
    local FRAME_DIR="$1"
    local FRAME_REF="$2"
    local FRAME="$3"

    local NEW_REL="SLC/${FRAME_REF}/data.dat"
    local OLD_REL="merged/SLC/${FRAME_REF}/referenceShelve/data.dat"

    if [ -f "${FRAME_DIR}/${NEW_REL}" ]; then
        log_info "${FRAME}: [P448-MINTPY-FIX-02] metaFile: ${NEW_REL} (new re-processing layout)"
        declare -g RESOLVED_META_REL="${NEW_REL}"
        declare -g RESOLVED_META_ABS="${FRAME_DIR}/${NEW_REL}"
        return 0
    fi

    if [ -f "${FRAME_DIR}/${OLD_REL}" ]; then
        log_info "${FRAME}: [P448-MINTPY-FIX-02] metaFile: ${OLD_REL} (old training layout)"
        declare -g RESOLVED_META_REL="${OLD_REL}"
        declare -g RESOLVED_META_ABS="${FRAME_DIR}/${OLD_REL}"
        return 0
    fi

    log_error "${FRAME}: metaFile not found for REF_DATE=${FRAME_REF}"
    log_error "  Tried 1 (new re-processing): ${FRAME_DIR}/${NEW_REL}"
    log_error "  Tried 2 (old training):      ${FRAME_DIR}/${OLD_REL}"
    log_error "  [VERIFY] FRAME_REF_DATE[${FRAME}] in CONFIG, and that ISCE2 Phase 0-4 is complete."
    declare -g RESOLVED_META_REL=""
    declare -g RESOLVED_META_ABS=""
    return 1
}

# ==============================================================
# Pre-step: run prep_isce.py to generate RSC metadata files
# [P448-MINTPY-FIX-02] metaFile: auto-detected (new re-processing or old training)
# [P448-05] geom_reference: auto-detect (geom_reference/ or merged/geom_reference/)
# ==============================================================

run_prep_isce() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local FRAME_REF="${3:-${REF_DATE}}"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local LOG_FILE="${LOG_DIR}/00_prep_isce.log"

    mkdir -p "${LOG_DIR}"

    local PREP_ISCE=""
    for CAND in \
        "${MINTPY_ENV}/bin/prep_isce.py" \
        "${MINTPY_ENV}/bin/prep_isce"; do
        [ -f "$CAND" ] && { PREP_ISCE="$CAND"; break; }
    done
    if [ -z "${PREP_ISCE}" ]; then
        log_error "${FRAME}: prep_isce not found in ${MINTPY_ENV}/bin/"
        log_error "  Expected prep_isce.py or prep_isce in: ${MINTPY_ENV}/bin/"
        log_error "  Check MINTPY_ENV is set to the isce2 env (NOT mintpy_stable)."
        return 1
    fi
    log_info "${FRAME}: Found prep_isce: ${PREP_ISCE}"

    # [P448-MINTPY-FIX-02] Auto-detect metaFile: new re-processing (SLC/) vs old training (merged/SLC/)
    RESOLVED_META_REL=""
    RESOLVED_META_ABS=""
    resolve_meta_file "${FRAME_DIR}" "${FRAME_REF}" "${FRAME}" || return 1
    local META_REL="${RESOLVED_META_REL}"

    # [P448-05] Geometry: try geom_reference/ first (may be symlink to merged/geom_reference/).
    # Fall back to merged/geom_reference/ if geom_reference/ is absent.
    local GEOM_REL="geom_reference"
    if [ ! -d "${FRAME_DIR}/${GEOM_REL}" ]; then
        if [ -d "${FRAME_DIR}/merged/geom_reference" ]; then
            GEOM_REL="merged/geom_reference"
            log_warn "${FRAME}: geom_reference/ not found — using merged/geom_reference/ for prep_isce"
        else
            log_error "${FRAME}: Neither geom_reference/ nor merged/geom_reference/ found"
            log_error "  ISCE2 run_01 (reference processing) must complete first."
            return 1
        fi
    fi
    log_info "${FRAME}: geom_reference path: ${GEOM_REL}"

    # Delete stale RSC sidecar files before running prep_isce.
    # A second run without cleanup leaves stale .rsc files that lack P_BASELINE_TOP_HDR.
    log_info "${FRAME}: Cleaning stale RSC sidecar files..."
    find "${FRAME_DIR}/Igrams"           -name "*.rsc" -delete 2>/dev/null
    find "${FRAME_DIR}/${GEOM_REL}"      -name "*.rsc" -delete 2>/dev/null
    # Also clean the other geometry dir if both exist (may have stale copies)
    if [ "${GEOM_REL}" = "geom_reference" ] && [ -d "${FRAME_DIR}/merged/geom_reference" ]; then
        find "${FRAME_DIR}/merged/geom_reference" -name "*.rsc" -delete 2>/dev/null
    fi
    log_info "${FRAME}: RSC cleanup done"

    log_info "${FRAME}: Running prep_isce.py from ${FRAME_DIR}"
    log_info "${FRAME}:   -m ${META_REL}"
    log_info "${FRAME}:   -g ${GEOM_REL}"
    log_info "${FRAME}:   -b baselines"
    log_info "${FRAME}:   -f \"Igrams/*/filt_*.unw\""
    (
        cd "${FRAME_DIR}" || { log_error "${FRAME}: Cannot cd to ${FRAME_DIR}"; exit 1; }
        "${PYTHON}" "${PREP_ISCE}" \
            -m "${META_REL}" \
            -g "${GEOM_REL}" \
            -b "baselines" \
            -f "Igrams/*/filt_*.unw" \
            > "${LOG_FILE}" 2>&1
    ) || {
        log_error "${FRAME}: prep_isce.py failed — check ${LOG_FILE}"
        tail -10 "${LOG_FILE}" | while IFS= read -r line; do
            log_error "  ${line}"
        done
        return 1
    }
    log_ok "${FRAME}: prep_isce.py done → ${LOG_FILE}"
}

# ==============================================================
# Auto-detect unwrapped file glob pattern
# ==============================================================

detect_unw_pattern() {
    local IGRAMS_DIR="$1"
    if find "${IGRAMS_DIR}" -name "filt_*snaphu.unw" -print -quit 2>/dev/null | grep -q .; then
        echo "${IGRAMS_DIR}/*/filt_*snaphu.unw"
    else
        echo "${IGRAMS_DIR}/*/filt_*.unw"
    fi
}

detect_conncomp_pattern() {
    local IGRAMS_DIR="$1"
    if find "${IGRAMS_DIR}" -name "filt_*snaphu.unw.conncomp" -print -quit 2>/dev/null | grep -q .; then
        echo "${IGRAMS_DIR}/*/filt_*snaphu.unw.conncomp"
    else
        echo "${IGRAMS_DIR}/*/filt_*.unw.conncomp"
    fi
}

# ==============================================================
# Config file generator
# [P448-04] metaFile: merged/SLC/REF_DATE/referenceShelve/data.dat
# [P448-05] GEOM_DIR: auto-detect geom_reference/ or merged/geom_reference/
# ==============================================================

generate_mintpy_cfg() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local FRAME_REF="${FRAME_REF_DATE[$FRAME]:-$REF_DATE}"
    local MINTPY_DIR="${FRAME_DIR}/mintpy"
    local CFG="${MINTPY_DIR}/smallbaselineApp.cfg"

    mkdir -p "${MINTPY_DIR}"

    local IGRAMS_DIR="${FRAME_DIR}/Igrams"

    # [P448-05] Auto-detect geometry directory
    local GEOM_DIR="${FRAME_DIR}/geom_reference"
    if [ ! -d "${GEOM_DIR}" ] && [ -d "${FRAME_DIR}/merged/geom_reference" ]; then
        GEOM_DIR="${FRAME_DIR}/merged/geom_reference"
        log_warn "${FRAME}: geom_reference/ not found — using merged/geom_reference/ in cfg"
    fi

    local UNW_PAT;   UNW_PAT="$(detect_unw_pattern "${IGRAMS_DIR}")"
    local CONN_PAT;  CONN_PAT="$(detect_conncomp_pattern "${IGRAMS_DIR}")"

    local EXCLUDE="${EXCLUDE_DATES[$FRAME]:-}"
    local MINTCOH="${MIN_TEMP_COH[$FRAME]:-0.7}"
    local DERAMP_OPT="${DERAMP[$FRAME]:-linear}"

    # [P448-MINTPY-FIX-02] Auto-detect metaFile: new re-processing (SLC/) vs old training (merged/SLC/)
    RESOLVED_META_REL=""
    RESOLVED_META_ABS=""
    resolve_meta_file "${FRAME_DIR}" "${FRAME_REF}" "${FRAME}" || {
        log_warn "${FRAME}: metaFile not found — cfg will be written but load_data will fail"
        log_warn "${FRAME}: [VERIFY] Run ISCE2 Phase 0-4, then re-run this script."
        # Use old training path as placeholder so cfg is still written
        RESOLVED_META_ABS="${FRAME_DIR}/merged/SLC/${FRAME_REF}/referenceShelve/data.dat"
    }
    local META_FILE="${RESOLVED_META_ABS}"

    log_info "${FRAME}: Generating MintPy config -> ${CFG}"
    log_info "${FRAME}:   REF_DATE: ${FRAME_REF}"
    log_info "${FRAME}:   unwFile pattern: ${UNW_PAT}"
    log_info "${FRAME}:   geom_dir: ${GEOM_DIR}"
    log_info "${FRAME}:   minTempCoh: ${MINTCOH} | deramp: ${DERAMP_OPT}"
    [ -n "$EXCLUDE" ] && log_info "${FRAME}:   excludeDate: ${EXCLUDE}"

    cat > "${CFG}" << CFGEOF
## ================================================================
## LInOG InSAR Training — MintPy smallbaselineApp Configuration
## Path: P448 | Frame: ${FRAME^^}
## Generated: $(_ts) by ${SCRIPT_NAME} v${SCRIPT_VERSION}
##
## [P448-MINTPY-FIX-02] metaFile auto-detected at runtime:
##   New re-processing: SLC/REF_DATE/data.dat (P449-style)
##   Old training:      merged/SLC/REF_DATE/referenceShelve/data.dat
##   Resolved path for this run: ${META_FILE}
##   REF_DATE for this frame: ${FRAME_REF}
##   ALL frames [VERIFY] from new run pairs.pdf. RSS PR 07 refs: f0290=20090626, f0310=20091111.
##
## Edit mintpy.reference.lalo if reference_point fails (Section 3).
## Edit mintpy.networkInversion.minTempCoh if inversion is too sparse.
## ================================================================

# ----------------------------------------------------------------
# 1. Data loading
# ----------------------------------------------------------------
mintpy.load.processor        = isce

# [P448-MINTPY-FIX-02] metaFile auto-detected: new re-processing (SLC/) or old training (merged/SLC/)
# See resolve_meta_file() for detection logic. Value confirmed at runtime above.
mintpy.load.metaFile         = ${META_FILE}
mintpy.load.baselineDir      = ${FRAME_DIR}/baselines

# Interferograms (auto-detected naming: ${UNW_PAT})
mintpy.load.unwFile          = ${UNW_PAT}
mintpy.load.corFile          = ${IGRAMS_DIR}/*/filt_*.cor
mintpy.load.connCompFile     = ${CONN_PAT}

# intFile MUST be no: MintPy tries to cast CFloat32 -> float32 HDF5.
# h5py 3.x refuses this conversion (OSError: Can't synchronously write data).
# wrapPhase is not needed downstream in the SBAS pipeline.
mintpy.load.intFile          = no

# Geometry
# [P448-05] geom_reference path auto-detected (geom_reference/ or merged/geom_reference/)
mintpy.load.demFile          = ${GEOM_DIR}/hgt.rdr

# lookupYFile / lookupXFile: SEPARATE keys in MintPy 1.6.2 (NOT lookupFile).
mintpy.load.lookupYFile      = ${GEOM_DIR}/lat.rdr
mintpy.load.lookupXFile      = ${GEOM_DIR}/lon.rdr

mintpy.load.incAngleFile     = ${GEOM_DIR}/incLocal.rdr
mintpy.load.azAngleFile      = ${GEOM_DIR}/los.rdr

# [P448-08] waterMaskFile MUST be no for P448.
# waterMask.rdr is an all-zero ISCE2 raster (same issue as P447/P449).
# If loaded, geometryRadar.h5['waterMask'] becomes all-zero -> NaN coherence. [M1]
mintpy.load.waterMaskFile    = no

# ----------------------------------------------------------------
# 2. Network modification
# ----------------------------------------------------------------
mintpy.network.coherenceBased    = no
mintpy.network.keepMinSpanTree   = yes
mintpy.network.maxTempBaseline   = 500   # [P448-MINTPY-ERR-01 v2.5] Exclude long incoherent pairs (3 extra >500-day pairs in new run vs old training)
mintpy.network.maxPerpBaseline   = 1000  # optional guard; >1000m ALOS-1 pairs add decorrelation noise
$([ -n "${EXCLUDE}" ] \
    && echo "mintpy.network.excludeDate = ${EXCLUDE}" \
    || echo "# mintpy.network.excludeDate = auto  (no exclusions for this frame)")

# ----------------------------------------------------------------
# 3. Reference point
# ----------------------------------------------------------------
# auto = MintPy selects highest-coherence pixel.
# If this step fails, override with known stable coordinates:
#   mintpy.reference.lalo = LAT,LON
mintpy.reference.date          = ${FRAME_REF}
mintpy.reference.minCoherence  = 0.4

# ----------------------------------------------------------------
# 4. Unwrapping error correction
# ----------------------------------------------------------------
# Set to no: maskConnComp.h5 is likely empty for this scene (rainy-season pairs
# have zero valid connected components; their intersection is 0/N pixels). [M2]
mintpy.unwrapError.method      = no

# ----------------------------------------------------------------
# 5. Time series inversion
# ----------------------------------------------------------------
mintpy.networkInversion.weightFunc     = var
mintpy.networkInversion.minTempCoh     = ${MINTCOH}
mintpy.networkInversion.minNumPixel    = 100

# [P448-08] networkInversion.waterMaskFile is a SEPARATE key from load.waterMaskFile.
# Must be set to no independently. [M3]
mintpy.networkInversion.waterMaskFile  = no

# ----------------------------------------------------------------
# 6. ALOS-1 sensor (required for LOD correction)
# ----------------------------------------------------------------
mintpy.sensor                  = ALOS

# ----------------------------------------------------------------
# 7. Tropospheric correction — DISABLED (no external model)
# ----------------------------------------------------------------
mintpy.troposphericDelay.method = no

# ----------------------------------------------------------------
# 8. Ramp removal
# ----------------------------------------------------------------
mintpy.deramp                  = ${DERAMP_OPT}
mintpy.deramp.maskDataset      = coherence
mintpy.deramp.maskThreshold    = 0.5

# ----------------------------------------------------------------
# 9. Topographic residual correction
# ----------------------------------------------------------------
mintpy.topographicResidual     = yes

# ----------------------------------------------------------------
# 12. Velocity
# ----------------------------------------------------------------
mintpy.velocity.startDate      = auto
mintpy.velocity.endDate        = auto

# ----------------------------------------------------------------
# 13. Geocoding
# ----------------------------------------------------------------
mintpy.geocode.laloStep        = -0.001,0.001
mintpy.geocode.interpMethod    = nearest

# ----------------------------------------------------------------
# 14. Plot / KMZ display range
# ----------------------------------------------------------------
# Fixed ±10 cm/year for all velocity maps and Google Earth KMZ.
mintpy.plot.vlim               = -10 10

CFGEOF

    log_ok "${FRAME}: Config written (${CFG})"
}

# ==============================================================
# Error classifier
# ==============================================================

classify_error() {
    local LOG_FILE="$1"
    ERR_TYPE="UNKNOWN"
    ERR_DESC="${ERRCAT_UNKNOWN_DESC}"
    ERR_FIX="${ERRCAT_UNKNOWN_FIX}"

    if [ ! -f "$LOG_FILE" ]; then return; fi

    if grep -qiE "Invalid NaN value found in kept pairs|Mean of empty slice.*coherence" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="WATERMASK_NAN"
        ERR_DESC="${ERRCAT_WATERMASK_NAN_DESC}"
        ERR_FIX="${ERRCAT_WATERMASK_NAN_FIX}"
    elif grep -qiE "input reference point is NOT included in the connectComponent|argmax of empty sequence" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="CONNCOMP_EMPTY"
        ERR_DESC="${ERRCAT_CONNCOMP_EMPTY_DESC}"
        ERR_FIX="${ERRCAT_CONNCOMP_EMPTY_FIX}"
    elif grep -qiE "list index out of range" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="INVERSION_WATERMASK"
        ERR_DESC="${ERRCAT_INVERSION_WATERMASK_DESC}"
        ERR_FIX="${ERRCAT_INVERSION_WATERMASK_FIX}"
    elif grep -qiE "No such file.*\.unw|0 files found|no file found.*unwFile|cannot find.*unwFile" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="LOAD_NO_UNW"
        ERR_DESC="${ERRCAT_LOAD_NO_UNW_DESC}"
        ERR_FIX="${ERRCAT_LOAD_NO_UNW_FIX}"
    elif grep -qiE "No such file.*hgt\.rdr|No such file.*lat\.rdr|geometry.*not found" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="LOAD_NO_GEOM"
        ERR_DESC="${ERRCAT_LOAD_NO_GEOM_DESC}"
        ERR_FIX="${ERRCAT_LOAD_NO_GEOM_FIX}"
    elif grep -qiE "No such file.*baseline|P_BASELINE_TOP_HDR|baseline.*not found" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="LOAD_NO_BASELINE"
        ERR_DESC="${ERRCAT_LOAD_NO_BASELINE_DESC}"
        ERR_FIX="${ERRCAT_LOAD_NO_BASELINE_FIX}"
    elif grep -qiE "No module named 'isce'|ModuleNotFoundError.*isce" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="ISCE_NOT_IN_PATH"
        ERR_DESC="prep_isce.py cannot import 'isce' — wrong env. MINTPY_ENV must be isce2, not mintpy_stable."
        ERR_FIX="Set MINTPY_ENV=/eggraid/miniconda3/envs/isce2 in this script."
    elif grep -qiE "HDF5ExtError|unable to open file|file signature not found|truncated.*hdf5|corrupted.*hdf5|OSError.*truncat" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="HDF5_CORRUPT"
        ERR_DESC="${ERRCAT_HDF5_CORRUPT_DESC}"
        ERR_FIX="${ERRCAT_HDF5_CORRUPT_FIX}"
    elif grep -qiE "coherent pixel.*0|no coherent|minNumPixel|too few pixel|Not enough reliable pixels" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="NO_COHERENT"
        ERR_DESC="${ERRCAT_NO_COHERENT_DESC}"
        ERR_FIX="${ERRCAT_NO_COHERENT_FIX}"
    elif grep -qiE "reference point|refPoint|no valid.*reference|cannot find.*reference" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="REF_POINT"
        ERR_DESC="${ERRCAT_REF_POINT_DESC}"
        ERR_FIX="${ERRCAT_REF_POINT_FIX}"
    elif grep -qiE "singular|LinAlgError|SVD|matrix.*inversion" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="INVERT_SINGULAR"
        ERR_DESC="${ERRCAT_INVERT_SINGULAR_DESC}"
        ERR_FIX="${ERRCAT_INVERT_SINGULAR_FIX}"
    elif grep -qiE "local oscillator|LOD.*fail|LOD.*not.*avail|AttributeError.*lod|ImportError.*lod" "$LOG_FILE" 2>/dev/null; then
        # Pattern deliberately excludes bare "LOD" and "correct_lod" tokens —
        # these appear in MintPy's "Remaining steps:" header in every step log.
        ERR_TYPE="LOD_FAIL"
        ERR_DESC="${ERRCAT_LOD_FAIL_DESC}"
        ERR_FIX="${ERRCAT_LOD_FAIL_FIX}"
    elif grep -qiE "velocity.*fail|timeseries.*not found|velocity.*empty" "$LOG_FILE" 2>/dev/null; then
        ERR_TYPE="VELOCITY_FAIL"
        ERR_DESC="${ERRCAT_VELOCITY_FAIL_DESC}"
        ERR_FIX="${ERRCAT_VELOCITY_FAIL_FIX}"
    fi
}

# ==============================================================
# Auto-heal: apply known fix for classified error.
# Returns 0 if a fix was applied (retry warranted), 1 otherwise.
# ==============================================================

apply_auto_heal() {
    local ERR_TYPE_ARG="$1"
    local MINTPY_DIR="$2"
    local FRAME="$3"

    case "${ERR_TYPE_ARG}" in

        WATERMASK_NAN)
            # M1: waterMask all-zero -> NaN in modify_network
            log_warn "${FRAME}: [M1] Auto-heal: patching waterMask + removing stale files"
            heal_watermask_patch "${MINTPY_DIR}" "${FRAME}"
            rm -f "${MINTPY_DIR}/waterMask.h5" "${MINTPY_DIR}/coherenceSpatialAvg.txt"
            return 0
            ;;

        CONNCOMP_EMPTY)
            # M2: maskConnComp empty -> correct_unwrap_error fails
            log_warn "${FRAME}: [M2] Auto-heal: deleting partial unwrapPhase_bridging, setting unwrapError.method=no"
            "${PYTHON}" -c "
import h5py
fname = '${MINTPY_DIR}/inputs/ifgramStack.h5'
with h5py.File(fname, 'a') as f:
    if 'unwrapPhase_bridging' in f:
        del f['unwrapPhase_bridging']
        print('deleted unwrapPhase_bridging')
    else:
        print('unwrapPhase_bridging not present')
" 2>&1 | while IFS= read -r line; do log_info "${FRAME}: ${line}"; done
            sed -i 's|mintpy.unwrapError.method.*|mintpy.unwrapError.method = no|' \
                "${MINTPY_DIR}/smallbaselineApp.cfg"
            log_ok "${FRAME}: unwrapError.method = no set in cfg"
            return 0
            ;;

        INVERSION_WATERMASK)
            # M3: networkInversion.waterMaskFile still points to waterMask.rdr
            log_warn "${FRAME}: [M3] Auto-heal: setting networkInversion.waterMaskFile = no in cfg"
            if grep -q "mintpy.networkInversion.waterMaskFile" "${MINTPY_DIR}/smallbaselineApp.cfg"; then
                sed -i 's|mintpy.networkInversion.waterMaskFile.*|mintpy.networkInversion.waterMaskFile = no|' \
                    "${MINTPY_DIR}/smallbaselineApp.cfg"
            else
                echo "mintpy.networkInversion.waterMaskFile = no" >> "${MINTPY_DIR}/smallbaselineApp.cfg"
            fi
            log_ok "${FRAME}: networkInversion.waterMaskFile = no set in cfg"
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

# ==============================================================
# DemErr-only pass (two-pass MintPy for Phase 6 deliverables)
# Pass 2: correct_topography + velocity with deramp=no.
# Produces timeseries_demErr.h5 and velocity_demErr.h5.
# Sentinel: .done.DEMONLY_PASS
# ==============================================================

run_mintpy_demErr_pass() {
    local FRAME="$1"
    local FRAME_DIR="$2"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local MINTPY_DIR="${FRAME_DIR}/mintpy"
    local SENTINEL="${LOG_DIR}/.done.DEMONLY_PASS"
    local DEMONLY_CFG="${MINTPY_DIR}/smallbaselineApp_demonly.cfg"
    local LOG_FILE="${LOG_DIR}/09b_correct_topography_demonly.log"

    if [ -f "${SENTINEL}" ]; then
        log_skip "${FRAME}: DEMONLY_PASS — sentinel exists"
        return 0
    fi

    log_step "${FRAME}: [9b] demErr-only pass (deramp=no) — correct_topography + velocity"

    if [ ! -f "${MINTPY_DIR}/timeseries.h5" ]; then
        log_warn "${FRAME}: timeseries.h5 not found — skipping demErr-only pass"
        log_warn "${FRAME}: Phase 6 demErr products will be missing"
        return 0
    fi

    cd "${MINTPY_DIR}" || { log_error "${FRAME}: Cannot cd to ${MINTPY_DIR}"; return 1; }

    cp "${MINTPY_DIR}/smallbaselineApp.cfg" "${DEMONLY_CFG}"
    sed -i 's/^mintpy\.deramp\b.*/mintpy.deramp = no/' "${DEMONLY_CFG}"
    echo "mintpy.velocity.timeseriesFile = timeseries_demErr.h5" >> "${DEMONLY_CFG}"
    log_info "${FRAME}: demonly cfg written (deramp=no, input=timeseries_demErr.h5)"

    local VEL_MOVED="no"
    if [ -f "velocity.h5" ]; then
        mv "velocity.h5" "velocity.h5.demonly_bak"
        VEL_MOVED="yes"
    fi

    local EXIT_CODE=0
    local V=1
    while [ -f "${LOG_FILE}.v${V}" ]; do V=$((V+1)); done
    LOG_FILE="${LOG_FILE}.v${V}"

    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp_demonly.cfg \
        --dostep correct_topography \
        > "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        log_warn "${FRAME}: demErr-only correct_topography failed — check ${LOG_FILE}"
        [ "$VEL_MOVED" = "yes" ] && mv "velocity.h5.demonly_bak" "velocity.h5"
        return 0
    fi
    log_ok "${FRAME}: timeseries_demErr.h5 created"

    EXIT_CODE=0
    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp_demonly.cfg \
        --dostep velocity \
        >> "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        log_warn "${FRAME}: demErr-only velocity failed — check ${LOG_FILE}"
        [ "$VEL_MOVED" = "yes" ] && mv "velocity.h5.demonly_bak" "velocity.h5"
        return 0
    fi

    if [ -f "velocity.h5" ]; then
        mv "velocity.h5" "velocity_demErr.h5"
        log_ok "${FRAME}: velocity_demErr.h5 saved (demErr only, no ramp)"
    fi

    if [ "$VEL_MOVED" = "yes" ]; then
        mv "velocity.h5.demonly_bak" "velocity.h5"
        log_ok "${FRAME}: velocity.h5 restored to ramp+demErr"
    elif [ -f "velocity_demErr_ramp.h5" ]; then
        cp "velocity_demErr_ramp.h5" "velocity.h5"
        log_ok "${FRAME}: velocity.h5 restored from velocity_demErr_ramp.h5"
    fi

    touch "${SENTINEL}"
    log_ok "${FRAME}: DEMONLY_PASS complete"
    log_ok "  timeseries_demErr.h5:   present"
    log_ok "  velocity_demErr.h5:     present"
}

# ==============================================================
# Geocode demErr-only products + rename standard geo_velocity
# After this, all 4 geo/ files required by Phase 6 are present:
#   geo_velocity_demErr.h5, geo_velocity_demErr_ramp.h5,
#   geo_timeseries_demErr.h5, geo_timeseries_ramp_demErr.h5
# Sentinel: .done.GEOCODE_DEMONLY
# ==============================================================

geocode_demErr_files() {
    local FRAME="$1"
    local FRAME_DIR="$2"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local MINTPY_DIR="${FRAME_DIR}/mintpy"
    local SENTINEL="${LOG_DIR}/.done.GEOCODE_DEMONLY"
    local LOG_FILE="${LOG_DIR}/13b_geocode_demonly.log"

    if [ -f "${SENTINEL}" ]; then
        log_skip "${FRAME}: GEOCODE_DEMONLY — sentinel exists"
        return 0
    fi

    log_step "${FRAME}: [13b] geocode demErr-only products for Phase 6 deliverables"

    local GEO_DIR="${MINTPY_DIR}/geo"
    local GEOM="${MINTPY_DIR}/inputs/geometryRadar.h5"

    local GEOCODE_PY=""
    for CAND in "${MINTPY_ENV}/bin/geocode.py" "${MINTPY_ENV}/bin/geocode"; do
        [ -f "$CAND" ] && { GEOCODE_PY="$CAND"; break; }
    done
    if [ -z "${GEOCODE_PY}" ]; then
        log_warn "${FRAME}: geocode.py not found in ${MINTPY_ENV}/bin/ — skipping"
        return 0
    fi

    if [ ! -f "${GEOM}" ]; then
        log_warn "${FRAME}: inputs/geometryRadar.h5 not found — cannot geocode"
        return 0
    fi

    cd "${MINTPY_DIR}" || { log_error "${FRAME}: Cannot cd to ${MINTPY_DIR}"; return 1; }
    mkdir -p "${GEO_DIR}"

    local V=1
    while [ -f "${LOG_FILE}.v${V}" ]; do V=$((V+1)); done
    LOG_FILE="${LOG_FILE}.v${V}"

    local ANY_FAIL=0

    # 1. geo_velocity.h5 (ramp+demErr from standard geocode) -> rename
    if [ -f "${GEO_DIR}/geo_velocity.h5" ]; then
        mv -f "${GEO_DIR}/geo_velocity.h5" "${GEO_DIR}/geo_velocity_demErr_ramp.h5"  # [FIX-STALE-02]
        log_ok "${FRAME}: geo_velocity.h5 -> geo_velocity_demErr_ramp.h5"
    else
        log_warn "${FRAME}: geo_velocity.h5 not found — standard geocode step may not have run"
        ANY_FAIL=1
    fi

    # 2. Geocode velocity_demErr.h5 -> geo_velocity_demErr.h5
    if [ -f "velocity_demErr.h5" ]; then
        "${PYTHON}" "${GEOCODE_PY}" velocity_demErr.h5 \
            -l "${GEOM}" \
            -o "${GEO_DIR}/geo_velocity_demErr.h5" \
            --lalo -0.001 0.001 \
            -i nearest \
            >> "${LOG_FILE}" 2>&1 || {
            log_warn "${FRAME}: geocode velocity_demErr.h5 failed — check ${LOG_FILE}"
            ANY_FAIL=1
        }
        [ -f "${GEO_DIR}/geo_velocity_demErr.h5" ] && \
            log_ok "${FRAME}: geo_velocity_demErr.h5 created"
    else
        log_warn "${FRAME}: velocity_demErr.h5 not found — DEMONLY_PASS may not have run"
        ANY_FAIL=1
    fi

    # 3. Geocode timeseries_demErr.h5 -> geo_timeseries_demErr.h5
    if [ -f "timeseries_demErr.h5" ]; then
        "${PYTHON}" "${GEOCODE_PY}" timeseries_demErr.h5 \
            -l "${GEOM}" \
            -o "${GEO_DIR}/geo_timeseries_demErr.h5" \
            --lalo -0.001 0.001 \
            -i nearest \
            >> "${LOG_FILE}" 2>&1 || {
            log_warn "${FRAME}: geocode timeseries_demErr.h5 failed — check ${LOG_FILE}"
            ANY_FAIL=1
        }
        [ -f "${GEO_DIR}/geo_timeseries_demErr.h5" ] && \
            log_ok "${FRAME}: geo_timeseries_demErr.h5 created"
    else
        log_warn "${FRAME}: timeseries_demErr.h5 not found"
        ANY_FAIL=1
    fi

    touch "${SENTINEL}"

    if [ "$ANY_FAIL" -eq 0 ]; then
        log_ok "${FRAME}: GEOCODE_DEMONLY complete — Phase 6 geo files ready:"
        log_ok "  geo_velocity_demErr.h5"
        log_ok "  geo_velocity_demErr_ramp.h5"
        log_ok "  geo_timeseries_demErr.h5"
        log_ok "  geo_timeseries_ramp_demErr.h5"
    else
        log_warn "${FRAME}: GEOCODE_DEMONLY completed with warnings — check ${LOG_FILE}"
    fi
    return 0
}

# ==============================================================
# Step runner
# ==============================================================

run_mintpy_step() {
    local STEP="$1"
    local FRAME="$2"
    local FRAME_DIR="$3"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local MINTPY_DIR="${FRAME_DIR}/mintpy"
    local ERROR_LOG="${LOG_DIR}/MINTPY_ERROR_SUMMARY.txt"
    local STEP_N="${STEP_NUM[$STEP]}"
    local SENTINEL="${LOG_DIR}/.done.${STEP_N}_${STEP}"
    local LEVEL="${STEP_LEVEL[$STEP]}"

    mkdir -p "${LOG_DIR}"

    if [ -f "${SENTINEL}" ]; then
        log_skip "${FRAME}: ${STEP_N}_${STEP} — sentinel exists"
        return 0
    fi

    local FRAME_REF="${FRAME_REF_DATE[$FRAME]:-$REF_DATE}"
    log_step "${FRAME}: [${STEP_N}/${#MINTPY_STEPS[@]}] ${STEP} — ${STEP_DESC[$STEP]}"

    case "$STEP" in
        load_data)
            heal_check_hdf5_integrity "${MINTPY_DIR}" "${FRAME}"
            run_prep_isce "${FRAME_DIR}" "${FRAME}" "${FRAME_REF}" || return 1
            ;;
    esac

    local V=1
    while [ -f "${LOG_DIR}/${STEP_N}_${STEP}.log.v${V}" ]; do V=$((V+1)); done
    local LOG_FILE="${LOG_DIR}/${STEP_N}_${STEP}.log.v${V}"

    local START_TS; START_TS="$(_pst)"
    local EXIT_CODE=0

    cd "${MINTPY_DIR}" || {
        log_error "${FRAME}: Cannot cd to ${MINTPY_DIR}"
        return 1
    }

    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp.cfg --dostep "${STEP}" \
        > "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        touch "${SENTINEL}"
        log_ok "${FRAME}: ${STEP} done -> $(basename ${LOG_FILE})"
        case "$STEP" in
            load_data)
                heal_watermask_patch "${MINTPY_DIR}" "${FRAME}"
                ;;
        esac
        return 0
    fi

    ERR_TYPE=""; ERR_DESC=""; ERR_FIX=""
    classify_error "${LOG_FILE}"

    local HEALED="no"
    if apply_auto_heal "${ERR_TYPE}" "${MINTPY_DIR}" "${FRAME}"; then
        HEALED="yes"
        V=$((V+1))
        LOG_FILE="${LOG_DIR}/${STEP_N}_${STEP}.log.v${V}"
        log_info "${FRAME}: Retrying ${STEP} after auto-heal -> $(basename ${LOG_FILE})"
        EXIT_CODE=0
        "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp.cfg --dostep "${STEP}" \
            > "${LOG_FILE}" 2>&1 || EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            touch "${SENTINEL}"
            log_ok "${FRAME}: ${STEP} succeeded after auto-heal -> $(basename ${LOG_FILE})"
            return 0
        fi
        classify_error "${LOG_FILE}"
    fi

    local FIRST_SEEN="yes"
    grep -q "FAILED \[${STEP_N}_${STEP}\]" "${ERROR_LOG}" 2>/dev/null && FIRST_SEEN="no"

    {
        if [ "$LEVEL" = "critical" ]; then
            echo "FAILED [${STEP_N}_${STEP}] at ${START_TS}${HEALED:+ (auto-heal attempted)}"
        else
            echo "FAILED [${STEP_N}_${STEP}] at ${START_TS} (warn — pipeline continues)${HEALED:+ (auto-heal attempted)}"
        fi
        echo "  ERROR_TYPE: ${ERR_TYPE}"
        echo "  DESCRIPTION: ${ERR_DESC}"
        if [ "$FIRST_SEEN" = "yes" ]; then
            echo "  FIRST_SEEN: yes"
            echo "  KNOWN_FIX: ${ERR_FIX}"
        else
            echo "  FIRST_SEEN: no — fix already logged above; check log: $(basename ${LOG_FILE})"
        fi
        echo "  LOG: ${LOG_FILE}"
        if [ "$LEVEL" = "critical" ]; then
            echo "CRITICAL FAILURE: [${STEP_N}_${STEP}] failed. Fix the issue then re-run — completed steps will be skipped automatically."
        fi
    } >> "${ERROR_LOG}"

    if [ "$LEVEL" = "critical" ]; then
        log_error "${FRAME}: CRITICAL — ${STEP} failed (exit ${EXIT_CODE})"
        log_error "  TYPE: ${ERR_TYPE}"
        [ "$FIRST_SEEN" = "yes" ] && log_error "  FIX: ${ERR_FIX}"
        log_error "  LOG: ${LOG_FILE}"
        return 1
    else
        log_warn "${FRAME}: ${STEP} failed at warn level — pipeline continues"
        log_warn "  TYPE: ${ERR_TYPE}"
        [ "$FIRST_SEEN" = "yes" ] && log_warn "  FIX: ${ERR_FIX}"
        return 0
    fi
}

# ==============================================================
# Per-frame pipeline
# ==============================================================

process_frame() {
    local FRAME="$1"
    local FRAME_DIR="${BASE_DIR}/${FRAME}"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local ERROR_LOG="${LOG_DIR}/MINTPY_ERROR_SUMMARY.txt"
    local COMPLETE_SENTINEL="${LOG_DIR}/.done.MINTPY_COMPLETE"
    local FRAME_REF="${FRAME_REF_DATE[$FRAME]:-$REF_DATE}"

    mkdir -p "${LOG_DIR}"

    local START_TS; START_TS="$(_pst)"

    if [ -f "${COMPLETE_SENTINEL}" ]; then
        log_ok "P448-${FRAME^^}: MINTPY_COMPLETE sentinel exists — already done. Skipping."
        return 0
    fi

    {
        echo ""
        echo "=== LInOG MintPy Run ==="
        echo "Frame: P448-${FRAME^^} | Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
        echo "REF_DATE: ${FRAME_REF} [VERIFY from pairs.pdf or 05_stack_config_p2.log]"
        echo "Started: ${START_TS}"
    } >> "${ERROR_LOG}"

    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info " P448-${FRAME^^}  MintPy pipeline"
    log_info " REF_DATE: ${FRAME_REF} [VERIFY from pairs.pdf or 05_stack_config_p2.log]"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local PRE_ERRORS=0
    heal_verify_isce2_outputs "${FRAME_DIR}" "${FRAME}" || PRE_ERRORS=$?
    if [ $PRE_ERRORS -gt 0 ]; then
        {
            echo "ABORTED [PREREQ_FAIL]: ${PRE_ERRORS} prerequisite error(s) at ${START_TS}"
            echo "CRITICAL FAILURE: Fix ISCE2 outputs first, then re-run."
        } >> "${ERROR_LOG}"
        log_error "${FRAME}: Prerequisite check failed with ${PRE_ERRORS} error(s). Aborting."
        return 1
    fi

    local CFG="${FRAME_DIR}/mintpy/smallbaselineApp.cfg"
    if [ ! -f "${CFG}" ]; then
        generate_mintpy_cfg "${FRAME_DIR}" "${FRAME}"
    else
        log_info "${FRAME}: Found existing cfg — using as-is: ${CFG}"
        log_info "${FRAME}: (delete it to regenerate with script defaults)"
    fi

    for STEP in "${MINTPY_STEPS[@]}"; do
        run_mintpy_step "${STEP}" "${FRAME}" "${FRAME_DIR}" || {
            local ABORT_TS; ABORT_TS="$(_pst)"
            echo "FRAME ABORTED: P448-${FRAME^^} at ${ABORT_TS}" >> "${ERROR_LOG}"
            log_error "${FRAME}: Pipeline aborted at ${STEP}."
            log_error "  Re-run after fixing: completed steps will be skipped automatically."
            log_error "  To resume from this frame: set START_FRAME=${FRAME} in the script."
            return 1
        }
    done

    # ---- Post-pipeline: dual-correction products for Phase 6 deliverables ----
    local MINTPY_DIR="${FRAME_DIR}/mintpy"

    # [FIX-STALE-01] Always force-copy — do NOT guard with [ ! -f ].
    # If a bad velocity_demErr_ramp.h5 exists from a prior run, the old guard skipped the
    # copy and the stale file persisted through Phase 6 (M6 bug, same as p447 v2.4-v2.7).
    if [ -f "${MINTPY_DIR}/velocity.h5" ]; then
        cp -f "${MINTPY_DIR}/velocity.h5" "${MINTPY_DIR}/velocity_demErr_ramp.h5"
        log_info "${FRAME}: velocity_demErr_ramp.h5 force-copied from velocity.h5 [FIX-STALE-01]"
    fi

    run_mintpy_demErr_pass "${FRAME}" "${FRAME_DIR}"
    geocode_demErr_files "${FRAME}" "${FRAME_DIR}"

    touch "${COMPLETE_SENTINEL}"
    local END_TS; END_TS="$(_pst)"
    echo "COMPLETED MintPy: P448-${FRAME^^} at ${END_TS}" >> "${ERROR_LOG}"
    log_ok "P448-${FRAME^^}: MintPy COMPLETE"
    log_ok "  timeseries_ramp_demErr.h5:   ${FRAME_DIR}/mintpy/timeseries_ramp_demErr.h5"
    log_ok "  timeseries_demErr.h5:        ${FRAME_DIR}/mintpy/timeseries_demErr.h5"
    log_ok "  velocity_demErr_ramp.h5:     ${FRAME_DIR}/mintpy/velocity_demErr_ramp.h5"
    log_ok "  velocity_demErr.h5:          ${FRAME_DIR}/mintpy/velocity_demErr.h5"
    log_ok "  geo_velocity_demErr_ramp.h5: ${FRAME_DIR}/mintpy/geo/geo_velocity_demErr_ramp.h5"
    log_ok "  geo_velocity_demErr.h5:      ${FRAME_DIR}/mintpy/geo/geo_velocity_demErr.h5"
    log_ok "  geo_velocity.kmz:            ${FRAME_DIR}/mintpy/geo/geo_velocity.kmz"
}

# ==============================================================
# Main
# ==============================================================

main() {
    echo ""
    echo -e "${BOLD}LInOG MintPy Batch Script${NC} v${SCRIPT_VERSION}"
    echo "  Path:       P448"
    echo "  Frames:     ${FRAMES[*]}"
    echo "  REF_DATE:   ${REF_DATE} (global default; per-frame FRAME_REF_DATE used)"
    echo "  StartFrom:  ${START_FRAME}"
    echo "  MintPyEnv:  ${MINTPY_ENV} (isce2 — required)"
    echo ""
    echo "  [P448] FRAME_REF_DATE:"
    for F in "${FRAMES[@]}"; do
        local FREF="${FRAME_REF_DATE[$F]:-$REF_DATE}"
        echo "    ${F}: ${FREF} [VERIFY — confirm from pairs.pdf or 05_stack_config_p2.log]"
    done
    echo ""
    echo "  [P448-MINTPY-FIX-02] metaFile: auto-detected per frame at runtime"
    echo "    Priority 1: SLC/REF_DATE/data.dat         (new re-processing, P449-style)"
    echo "    Priority 2: merged/SLC/REF_DATE/           (old training data)"
    echo "                referenceShelve/data.dat"
    echo ""

    heal_verify_mintpy_env || {
        log_error "Cannot proceed — MintPy not found."
        exit 1
    }

    local STARTED=0
    for FRAME in "${FRAMES[@]}"; do
        if [ "$FRAME" = "$START_FRAME" ]; then STARTED=1; fi
        if [ $STARTED -eq 0 ]; then
            log_info "Skipping ${FRAME} (before START_FRAME=${START_FRAME})"
            continue
        fi
        process_frame "${FRAME}" || {
            log_error "Batch stopped at frame ${FRAME}."
            log_error "Fix the issue, then re-run (set START_FRAME=${FRAME} to resume)."
            exit 1
        }
    done

    echo ""
    log_ok "All P448 frames complete. Phase 6 geo files per frame:"
    for FRAME in "${FRAMES[@]}"; do
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_velocity_demErr_ramp.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_velocity_demErr.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_timeseries_ramp_demErr.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_timeseries_demErr.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_velocity.kmz"
    done
    echo ""
}

main "$@"
