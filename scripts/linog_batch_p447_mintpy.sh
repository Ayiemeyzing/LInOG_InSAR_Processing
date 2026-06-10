#!/bin/bash
# ==============================================================
# linog_batch_p447_mintpy.sh  v2.4
# MintPy time-series InSAR processing — P447 (F0300, F0310)
#
# Features:
#   - Sentinel-based step skipping (same pattern as ISCE2 Phase 0-4 script)
#   - ERROR_SUMMARY.txt per frame: first-seen flag, known fix, log reference
#   - Error catalog: pattern-match on known MintPy/ALOS-1 failure signatures
#   - Self-healing: HDF5 integrity check, waterMask patch, auto-heal + retry
#   - Autonomous: discovers ISCE2 output layout, validates prerequisites
#   - Multi-frame: loops over F0300 then F0310; resumes from START_FRAME
#
# Usage:
#   chmod +x linog_batch_p447_mintpy.sh
#   ./linog_batch_p447_mintpy.sh
#   # To resume from F0310 after F0300 is done:
#   # Edit START_FRAME="f0310" then re-run
#
# Output per frame:
#   p447/FRAME/mintpy/           <- MintPy working directory + results
#   p447/FRAME/mintpy_logs/      <- step logs, sentinels, ERROR_SUMMARY.txt
#
# Changelog v1.1 -> v2.0:
#   [FIX-01] MINTPY_ENV: mintpy_stable -> isce2 (has both MintPy + ISCE2)
#   [FIX-02] Removed ISCE2_SITE / PYTHONPATH injection (not needed in isce2 env)
#   [FIX-03] generate_mintpy_cfg: metaFile path includes .dat suffix directly
#   [FIX-04] generate_mintpy_cfg: shelve check uses full path (no double .dat)
#   [FIX-05] generate_mintpy_cfg: lookupFile -> lookupYFile + lookupXFile (separate keys)
#   [FIX-06] generate_mintpy_cfg: intFile = no (h5py 3.x dtype crash on CFloat32)
#   [FIX-07] generate_mintpy_cfg: magFile line removed (not needed downstream)
#   [FIX-08] generate_mintpy_cfg: waterMaskFile = no (waterMask.rdr is all-zero in P447)
#   [FIX-09] generate_mintpy_cfg: networkInversion.waterMaskFile = no (separate key)
#   [FIX-10] generate_mintpy_cfg: unwrapError.method = no (maskConnComp empty for this stack)
#   [FIX-11] generate_mintpy_cfg: baselineDir added explicitly
#   [NEW-01] run_prep_isce(): prep_isce.py mandatory pre-step before load_data
#   [NEW-02] heal_watermask_patch(): patches geometryRadar.h5['waterMask'] to all-ones
#   [NEW-03] Auto-heal + retry for M1 (waterMask NaN in modify_network)
#   [NEW-04] Auto-heal + retry for M2 (empty maskConnComp in correct_unwrap_error)
#   [NEW-05] Auto-heal + retry for M3 (networkInversion.waterMaskFile in invert_network)
#   [NEW-06] MINTPY_STEPS extended: google_earth, hdfeos5
#   [NEW-07] Error catalog: M1, M2, M3 entries added
#
# Changelog v2.0 -> v2.1:
#   [FIX-12] MINTPY_ENV path corrected: /home/arieln/.conda/envs/isce2 ->
#            /eggraid/miniconda3/envs/isce2 (shared felix env; /home path does not exist)
#   [FIX-13] run_prep_isce(): add stale RSC file cleanup before prep_isce call
#            (find Igrams/ geom_reference/ -name "*.rsc" -delete)
#            Without this, a second run leaves P_BASELINE_TOP_HDR missing from sidecar files.
#   [FIX-14] run_prep_isce(): run prep_isce from FRAME_DIR in subshell with relative paths
#            Matches manual working command: cd f0300/ && prep_isce.py -m SLC/20090309/data.dat ...
#   [FIX-15] run_prep_isce(): try both prep_isce.py and prep_isce (no .py) in MINTPY_ENV/bin/
#
# Changelog v2.1 -> v2.2:
#   [FIX-16] heal_watermask_patch(): when waterMask dataset is ABSENT from geometryRadar.h5
#            (valid=-1), CREATE it as all-ones instead of only warning.
#            Root cause: generated cfg uses waterMaskFile=no so load_data never writes
#            waterMask; reference_point.py then crashes with KeyError.
#            This hit F0310 (first frame with auto-generated cfg).
#   [FIX-17] classify_error(): tighten HDF5_CORRUPT pattern from "h5py|HDF5|..." to
#            "HDF5ExtError|unable to open file|file signature not found|truncated.*hdf5|..."
#            The old pattern false-triggered on any log containing h5py in the traceback
#            (e.g., KeyError on missing waterMask dataset was classified as HDF5_CORRUPT).
#
# Changelog v2.3 -> v2.4:
#   [FIX-22] generate_mintpy_cfg(): add mintpy.plot.vlim = -10 10
#            Ensures google_earth step KMZ and all velocity plots use
#            fixed ±10 cm/year range (consistent with Phase 6 hillshades).
#
# Changelog v2.2 -> v2.3:
#   [FIX-18] classify_error(): LOD_FAIL pattern tightened — removed bare "LOD" and
#            "correct_lod" tokens that matched "Remaining steps: ... correct_LOD ..."
#            header printed in EVERY MintPy step log. This caused false LOD_FAIL
#            classification of invert_network failure. New pattern requires full
#            error phrases: "local oscillator", "LOD.*fail", "AttributeError.*lod".
#   [FIX-19] classify_error(): NO_COHERENT pattern extended with
#            "Not enough reliable pixels" — MintPy 1.6.2 invert_network message
#            when fewer than minNumPixel pass the tempCoh threshold.
#   [FIX-20] MIN_TEMP_COH["f0310"]: 0.5 -> 0.3 (F0310 mean tempCoh 0.289;
#            default 0.5 left only 43 reliable pixels, below minNumPixel=100).
#   [FIX-21] generate_mintpy_cfg(): mintpy.reference.minCoherence: 0.7 -> 0.4
#            (F0310 max spatial coh 0.519; 0.7 produced 0 valid reference pixels).
#   [NEW-08] run_mintpy_demErr_pass(): second MintPy pass with deramp=no.
#            Produces timeseries_demErr.h5 and velocity_demErr.h5 required by
#            linog_fbs_processor.sh Phase 6 deliverables workflow.
#            Moves velocity.h5 aside, runs correct_topography+velocity with
#            smallbaselineApp_demonly.cfg, renames outputs, restores velocity.h5.
#   [NEW-09] geocode_demErr_files(): geocodes velocity_demErr.h5 and
#            timeseries_demErr.h5; renames geo_velocity.h5 ->
#            geo_velocity_demErr_ramp.h5. Phase 6 needs all four geo files:
#            geo_velocity_demErr.h5, geo_velocity_demErr_ramp.h5,
#            geo_timeseries_demErr.h5, geo_timeseries_ramp_demErr.h5.
#
# Changelog v2.6 -> v2.7:
#   [NEW-10] EXCLUDE_IGRAMS per-frame dict: space-separated DATE1_DATE2 pairs to remove
#            from Igrams/ before MintPy loads them. Pairs are moved to
#            Igrams/rejected_pairs/ (reversible). Empty = no exclusion.
#   [NEW-11] reject_bad_igrams(): reads EXCLUDE_IGRAMS[FRAME], moves listed pair
#            directories to Igrams/rejected_pairs/. Called in process_frame() before
#            the MintPy cfg block so load_data never sees the excluded pairs.
#            Idempotent: pair already in rejected_pairs/ → logged, not moved twice.
#   [FIX-23] f0300: exclude 4 blank 20090309_* pairs (20090309_20091210,
#            20090309_20100125, 20090309_20100312, 20090309_20110128).
#            These span the rainy season (9–22 months) causing full decorrelation;
#            visible in Igrams report as blank Phase + all-dark Combined images.
#            Confirmed by visual inspection of P447F0300_Igram_Report_Page_3.jpg.
#            Including these pairs adds pure noise to the SBAS inversion.
# ==============================================================

set -uo pipefail
SCRIPT_VERSION="2.8"
SCRIPT_NAME="$(basename "$0")"

# ==============================================================
# CONFIGURATION — edit before first run
# ==============================================================

BASE_DIR="/eggraid/home/arieln/projects/linog/insar/p447"

# Frames to process, in order
FRAMES=("f0300" "f0310")

# Set to the first frame you want to run (useful for resuming)
START_FRAME="f0300"

# RERUN_MINTPY_FRAMES: force-clear mintpy/ + mintpy_logs/ for listed frames and rerun from scratch.
# Use when ISCE2 was reprocessed (new PERP_BASELINE or reference date) and old MintPy output is stale.
# Space-separated frame IDs matching FRAMES entries (e.g. "f0300 f0310").
# Reset to "" after the rerun completes.
RERUN_MINTPY_FRAMES=""

# MintPy time series reference date (displacement = 0 at this date).
# This is the MintPy anchor epoch — independent of the ISCE2 stack reference.
# Must exist as an acquisition in every frame.
REF_DATE="20090309"

# ISCE2 stack reference date per frame — used to locate the SLC shelve (data.dat)
# for prep_isce.py -m and MintPy metaFile. Must match the -m flag used in Phase 3 Pass 2.
# [v2.5] f0310 rerun with 20091210 reference (Jun 8, 2026 — Dr. JD, mountain frame fix)
declare -A ISCE2_REF_DATE
ISCE2_REF_DATE["f0300"]="20090309"
ISCE2_REF_DATE["f0310"]="20091210"

# MintPy + ISCE2 conda environment (full path, no conda activate needed)
# MUST be the isce2 env — it has both MintPy 1.6.2 and ISCE2 installed.
# mintpy_stable does NOT have isce; prep_isce.py will fail with ImportError.
# Shared felix env confirmed: /eggraid/miniconda3/envs/isce2
MINTPY_ENV="/eggraid/miniconda3/envs/isce2"

# Per-frame temporal coherence threshold
# F0300: urban/coastal area -> good coherence -> use default 0.7
# F0310: vegetated/mountainous -> relaxed to recover sparse pixels
declare -A MIN_TEMP_COH
MIN_TEMP_COH["f0300"]="0.5"   # [v2.6] 0.7->0.5: invert_network NO_COHERENT after PERP_BASELINE=1500 rerun (fewer pairs)
MIN_TEMP_COH["f0310"]="0.3"   # [FIX-20] 0.5->0.3: F0310 mean tempCoh 0.289; 0.5 left only 43 pixels

# Dates to exclude per frame (space-separated; empty = no exclusion)
declare -A EXCLUDE_DATES
EXCLUDE_DATES["f0300"]=""
EXCLUDE_DATES["f0310"]=""

# Interferogram pairs to physically exclude before MintPy loads them.
# Format: space-separated DATE1_DATE2 strings matching Igrams/ subdirectory names.
# Listed pairs are MOVED to Igrams/rejected_pairs/ by reject_bad_igrams().
# Reversible: move them back to Igrams/ to restore. Empty = no exclusion.
# [v2.7] f0300: 4 pairs blank in Igrams report (rainy-season decorrelation):
#   20090309_20091210 (9 mo), 20090309_20100125 (10.5 mo),
#   20090309_20100312 (12 mo), 20090309_20110128 (22 mo)
#   All span Philippine rainy season (Jun-Oct) → full vegetation decorrelation.
# [v2.7] f0310: empty — network too sparse to exclude more pairs safely;
#   only 5–6 coherent pairs exist; MintPy weighted SBAS handles poor pairs.
declare -A EXCLUDE_IGRAMS
EXCLUDE_IGRAMS["f0300"]="20090309_20091210 20090309_20100125 20090309_20100312 20090309_20110128"
EXCLUDE_IGRAMS["f0310"]=""

# Deramp option: "linear" removes linear ramp (orbital error); "no" to disable
declare -A DERAMP
DERAMP["f0300"]="linear"
DERAMP["f0310"]="linear"

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
STEP_DESC["reference_date"]="Set displacement reference date (= ${REF_DATE})"
STEP_DESC["velocity"]="Estimate linear velocity (m/year)"
STEP_DESC["geocode"]="Geocode time series and velocity to geographic coordinates"
STEP_DESC["google_earth"]="Generate Google Earth KMZ from geocoded velocity"
STEP_DESC["hdfeos5"]="Export time series to HDF-EOS5 format (optional; OFF if not configured)"

# ==============================================================
# ERROR CATALOG
# Each known error: _DESC (what it is) and _FIX (what to do)
# Pattern-matched at runtime; first-seen flag printed once
# ==============================================================

# --- General errors ---

ERRCAT_MINTPY_NOT_FOUND_DESC="smallbaselineApp.py not found or not executable at MINTPY_ENV path"
ERRCAT_MINTPY_NOT_FOUND_FIX="Check MINTPY_ENV. Must be isce2 env (NOT mintpy_stable). Correct path: /eggraid/miniconda3/envs/isce2"

ERRCAT_HDF5_CORRUPT_DESC="HDF5 file corrupt or truncated — likely from a killed previous run"
ERRCAT_HDF5_CORRUPT_FIX="Corrupt file has been moved to .corrupt.TIMESTAMP backup. load_data sentinel cleared — re-run."

ERRCAT_NO_COHERENT_DESC="Too few coherent pixels — MintPy cannot invert (below minNumPixel)"
ERRCAT_NO_COHERENT_FIX="Lower mintpy.networkInversion.minTempCoh in cfg (try 0.5 for F0300, 0.3 for F0310). Delete .done.05_invert_network sentinel and re-run."

ERRCAT_REF_POINT_DESC="Reference point selection failed — no valid (high coherence, non-masked) pixel"
ERRCAT_REF_POINT_FIX="Add to cfg: mintpy.reference.lalo = LAT,LON (pick a stable urban area pixel). For F0300 try Olongapo/Subic Bay area. Delete .done.03_reference_point sentinel and re-run."

ERRCAT_LOAD_NO_UNW_DESC="No unwrapped interferogram files found — glob pattern matched 0 files"
ERRCAT_LOAD_NO_UNW_FIX="Check mintpy.load.unwFile path in cfg. Verify filt_*unw files exist in Igrams/."

ERRCAT_LOAD_NO_GEOM_DESC="Geometry file not found at expected ISCE2 path (hgt.rdr / lat.rdr / lon.rdr)"
ERRCAT_LOAD_NO_GEOM_FIX="Verify geom_reference/ exists. ISCE2 run_01 must complete first."

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

# --- P447-specific errors (discovered Jun 7, 2026 during F0300 processing) ---

# M1: waterMask.rdr is all-zero in P447 ISCE2 output -> modify_network generates empty waterMask.h5 -> NaN coherence
ERRCAT_WATERMASK_NAN_DESC="[M1] waterMask all-zero: P447 waterMask.rdr is an all-zero ISCE2 raster. modify_network generates empty waterMask.h5 -> NaN spatial coherence -> ValueError"
ERRCAT_WATERMASK_NAN_FIX="[AUTO-HEAL] Script patches geometryRadar.h5['waterMask'] to all-ones, deletes waterMask.h5 and coherenceSpatialAvg.txt, retries modify_network. Root fix: cfg has waterMaskFile = no."

# M2: SNAPHU connected components are empty (rainy-season pairs) -> maskConnComp.h5 is 0/N valid -> unwrap error step fails
ERRCAT_CONNCOMP_EMPTY_DESC="[M2] maskConnComp empty: intersection of all SNAPHU connected component masks is 0 valid pixels (rainy-season decorrelation). Reference point cannot be placed inside any connected component."
ERRCAT_CONNCOMP_EMPTY_FIX="[AUTO-HEAL] Script deletes partial unwrapPhase_bridging dataset, sets mintpy.unwrapError.method = no in cfg, retries. Bridging is not viable for this scene."

# M3: mintpy.networkInversion.waterMaskFile is a separate key from mintpy.load.waterMaskFile.
#     If it still points to waterMask.rdr, ifgram_inversion.py tries to open binary ISCE2 raster as HDF5 -> IndexError.
ERRCAT_INVERSION_WATERMASK_DESC="[M3] networkInversion.waterMaskFile mismatch: mintpy.networkInversion.waterMaskFile is a SEPARATE key from mintpy.load.waterMaskFile. If it still points to waterMask.rdr, ifgram_inversion.py crashes with IndexError: list index out of range."
ERRCAT_INVERSION_WATERMASK_FIX="[AUTO-HEAL] Script sets mintpy.networkInversion.waterMaskFile = no in cfg and retries. Always set BOTH waterMaskFile keys to no for P447."

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
# Sets global SMALLBASELINE to the correct path.
# MUST use isce2 env — prep_isce.py needs 'import isce'.
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
# Returns number of errors found (0 = clean).
# ==============================================================

heal_verify_isce2_outputs() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local ERRORS=0

    if [ ! -f "${FRAME_DIR}/logs/.done.FRAME_COMPLETE" ]; then
        log_error "${FRAME}: ISCE2 FRAME_COMPLETE sentinel missing — run ISCE2 batch script first"
        ERRORS=$((ERRORS+1))
    fi

    local UNW_COUNT=0
    UNW_COUNT=$(find "${FRAME_DIR}/Igrams" -name "filt_*snaphu.unw" 2>/dev/null | wc -l)
    if [ "$UNW_COUNT" -eq 0 ]; then
        UNW_COUNT=$(find "${FRAME_DIR}/Igrams" -name "filt_*.unw" \
            ! -name "*.conncomp" 2>/dev/null | wc -l)
    fi
    if [ "$UNW_COUNT" -eq 0 ]; then
        log_error "${FRAME}: No filt_*.unw files found in Igrams/"
        log_error "  FIX: ${ERRCAT_LOAD_NO_UNW_FIX}"
        ERRORS=$((ERRORS+1))
    else
        log_ok "${FRAME}: ${UNW_COUNT} unwrapped interferograms found in Igrams/"
    fi

    for GF in hgt.rdr lat.rdr lon.rdr; do
        if [ ! -f "${FRAME_DIR}/geom_reference/${GF}" ]; then
            log_error "${FRAME}: Geometry file missing: geom_reference/${GF}"
            log_error "  FIX: ${ERRCAT_LOAD_NO_GEOM_FIX}"
            ERRORS=$((ERRORS+1))
        fi
    done
    [ "$ERRORS" -eq 0 ] && log_ok "${FRAME}: Geometry files present in geom_reference/"

    if [ ! -d "${FRAME_DIR}/baselines" ]; then
        log_warn "${FRAME}: baselines/ directory not found — MintPy will fail at load_data"
        log_warn "  FIX: ${ERRCAT_LOAD_NO_BASELINE_FIX}"
    fi

    return $ERRORS
}

# ==============================================================
# Self-healing: check HDF5 file integrity
# Detects corrupt files from interrupted runs and moves them.
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
# Required for P447: waterMask.rdr is all-zero in ISCE2 geom_reference/.
# If MintPy loads the all-zero raster, waterMask.h5 ends up 0/N valid,
# causing modify_network to produce all-NaN coherenceSpatialAvg.txt.
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
        # waterMask dataset absent from geometryRadar.h5.
        # This happens when the cfg has waterMaskFile = no — load_data never writes the dataset.
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
# Pre-step: run prep_isce.py to generate RSC metadata files
# Must run before load_data (generates P_BASELINE_TOP_HDR and
# other keys that MintPy reads from *.rsc sidecar files).
# ==============================================================

run_prep_isce() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local LOG_DIR="${FRAME_DIR}/mintpy_logs"
    local LOG_FILE="${LOG_DIR}/00_prep_isce.log"

    mkdir -p "${LOG_DIR}"

    # Locate prep_isce — check both .py and non-.py entry point names.
    # MintPy installs differ: pip may create prep_isce.py; conda may create prep_isce.
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

    local ISCE2_REF="${ISCE2_REF_DATE[$FRAME]:-$REF_DATE}"
    local META="SLC/${ISCE2_REF}/data.dat"
    if [ ! -f "${FRAME_DIR}/${META}" ]; then
        log_error "${FRAME}: shelve metadata not found: ${FRAME_DIR}/${META}"
        log_error "  ISCE2 must be fully processed before running MintPy."
        log_error "  ISCE2_REF_DATE[${FRAME}]=${ISCE2_REF} — verify this matches Phase 3 Pass 2 reference."
        return 1
    fi

    # CRITICAL: delete stale RSC sidecar files before running prep_isce.
    # A second run without cleanup reads stale RSC files, which may lack
    # P_BASELINE_TOP_HDR (written only when -b is given) or carry wrong
    # metadata from a previous aborted attempt.
    # Matches the working manual procedure: find . -name "*.rsc" -delete
    log_info "${FRAME}: Cleaning stale RSC sidecar files in Igrams/ and geom_reference/"
    find "${FRAME_DIR}/Igrams"       -name "*.rsc" -delete 2>/dev/null
    find "${FRAME_DIR}/geom_reference" -name "*.rsc" -delete 2>/dev/null
    log_info "${FRAME}: RSC cleanup done"

    # Run prep_isce from the frame directory with RELATIVE paths.
    # This matches the working manual command exactly:
    #   cd /eggraid/.../p447/f0300/
    #   prep_isce.py -m SLC/20090309/data.dat -g geom_reference \
    #                -b baselines -f "Igrams/*/filt_*.unw"
    # The subshell isolates the cd so the caller's CWD is not changed.
    log_info "${FRAME}: Running prep_isce.py from ${FRAME_DIR}"
    log_info "${FRAME}:   -m ${META}"
    log_info "${FRAME}:   -g geom_reference"
    log_info "${FRAME}:   -b baselines"
    log_info "${FRAME}:   -f \"Igrams/*/filt_*.unw\""
    (
        cd "${FRAME_DIR}" || { log_error "${FRAME}: Cannot cd to ${FRAME_DIR}"; exit 1; }
        "${PYTHON}" "${PREP_ISCE}" \
            -m "SLC/${ISCE2_REF}/data.dat" \
            -g "geom_reference" \
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
# Writes a corrected smallbaselineApp.cfg per frame.
# Only runs if cfg does not already exist.
#
# Key corrections from v1.1 (see FIX-03 through FIX-11 in header):
#   - waterMaskFile = no (waterMask.rdr is all-zero in P447)
#   - networkInversion.waterMaskFile = no (separate key — must set independently)
#   - unwrapError.method = no (maskConnComp is empty for this stack)
#   - lookupYFile + lookupXFile (separate keys, not lookupFile)
#   - intFile = no (h5py 3.x dtype crash on CFloat32 .int files)
#   - metaFile = SLC/REF_DATE/data.dat (full .dat path, P447 layout)
#   - baselineDir added
# ==============================================================

generate_mintpy_cfg() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local MINTPY_DIR="${FRAME_DIR}/mintpy"
    local CFG="${MINTPY_DIR}/smallbaselineApp.cfg"

    mkdir -p "${MINTPY_DIR}"

    local IGRAMS_DIR="${FRAME_DIR}/Igrams"
    local GEOM_DIR="${FRAME_DIR}/geom_reference"

    local UNW_PAT;   UNW_PAT="$(detect_unw_pattern "${IGRAMS_DIR}")"
    local CONN_PAT;  CONN_PAT="$(detect_conncomp_pattern "${IGRAMS_DIR}")"

    local EXCLUDE="${EXCLUDE_DATES[$FRAME]:-}"
    local MINTCOH="${MIN_TEMP_COH[$FRAME]:-0.7}"
    local DERAMP_OPT="${DERAMP[$FRAME]:-linear}"
    local ISCE2_REF="${ISCE2_REF_DATE[$FRAME]:-$REF_DATE}"

    # P447 layout: shelve is directly in SLC/ISCE2_REF/ (no merged/ prefix, no referenceShelve/ subdir)
    # Unlike P448 which uses merged/SLC/REF_DATE/referenceShelve/data.dat
    # ISCE2_REF is per-frame (f0300=20090309, f0310=20091210 after Jun 8 rerun)
    local META_FILE="${FRAME_DIR}/SLC/${ISCE2_REF}/data.dat"
    if [ ! -f "${META_FILE}" ]; then
        log_warn "${FRAME}: Shelve not found: ${META_FILE} — metaFile will be set but may fail"
        log_warn "  Verify ISCE2 ran with ISCE2_REF_DATE[${FRAME}]=${ISCE2_REF}"
    else
        log_info "${FRAME}: metaFile -> ${META_FILE}"
    fi

    log_info "${FRAME}: Generating MintPy config -> ${CFG}"
    log_info "${FRAME}:   unwFile pattern: ${UNW_PAT}"
    log_info "${FRAME}:   minTempCoh: ${MINTCOH} | deramp: ${DERAMP_OPT}"
    [ -n "$EXCLUDE" ] && log_info "${FRAME}:   excludeDate: ${EXCLUDE}"

    cat > "${CFG}" << CFGEOF
## ================================================================
## LInOG InSAR Training — MintPy smallbaselineApp Configuration
## Path: P447 | Frame: ${FRAME^^}
## Generated: $(_ts) by ${SCRIPT_NAME} v${SCRIPT_VERSION}
##
## Edit mintpy.reference.lalo if reference_point fails (Section 3).
## Edit mintpy.networkInversion.minTempCoh if inversion is too sparse.
## ================================================================

# ----------------------------------------------------------------
# 1. Data loading
# ----------------------------------------------------------------
mintpy.load.processor        = isce

# P447 shelve layout: SLC/REF_DATE/data.dat (no merged/ or referenceShelve/ prefix)
# prep_isce.py reads this to write STARTING_RANGE etc. into *.rsc sidecar files.
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
mintpy.load.demFile          = ${GEOM_DIR}/hgt.rdr

# lookupYFile / lookupXFile: SEPARATE keys in MintPy 1.6.2 (NOT lookupFile).
# These load lat.rdr and lon.rdr into geometryRadar.h5 as latitude/longitude datasets.
# Without them, geocode and modify_network cannot compute geographic coordinates.
mintpy.load.lookupYFile      = ${GEOM_DIR}/lat.rdr
mintpy.load.lookupXFile      = ${GEOM_DIR}/lon.rdr

mintpy.load.incAngleFile     = ${GEOM_DIR}/incLocal.rdr
mintpy.load.azAngleFile      = ${GEOM_DIR}/los.rdr

# waterMaskFile MUST be no for P447.
# waterMask.rdr in geom_reference/ is an all-zero ISCE2 binary raster.
# If loaded, geometryRadar.h5['waterMask'] becomes all-zero, waterMask.h5
# ends up 0/N valid, and modify_network crashes with NaN coherence. [M1]
mintpy.load.waterMaskFile    = no

# ----------------------------------------------------------------
# 2. Network modification
# ----------------------------------------------------------------
mintpy.network.coherenceBased    = no
mintpy.network.keepMinSpanTree   = yes
$([ -n "${EXCLUDE}" ] \
    && echo "mintpy.network.excludeDate = ${EXCLUDE}" \
    || echo "# mintpy.network.excludeDate = auto  (no exclusions for this frame)")

# ----------------------------------------------------------------
# 3. Reference point
# ----------------------------------------------------------------
# auto = MintPy selects highest-coherence pixel.
# If this step fails, override with known stable coordinates:
#   mintpy.reference.lalo = LAT,LON
#   (P447-F0300: Olongapo/Subic Bay urban area ~15.8N,120.3E)
#   (P447-F0310: stable rock in NW mountainous patch)
mintpy.reference.date          = ${REF_DATE}
mintpy.reference.minCoherence  = 0.4

# ----------------------------------------------------------------
# 4. Unwrapping error correction
# ----------------------------------------------------------------
# Set to no: maskConnComp.h5 is empty for this scene (rainy-season pairs
# have zero valid connected components; their intersection is 0/N pixels).
# Bridging requires a non-empty maskConnComp to place the reference point.
# Phase closure alone would require maskConnComp too. [M2]
mintpy.unwrapError.method      = no

# ----------------------------------------------------------------
# 5. Time series inversion
# ----------------------------------------------------------------
mintpy.networkInversion.weightFunc     = var
mintpy.networkInversion.minTempCoh     = ${MINTCOH}
mintpy.networkInversion.minNumPixel    = 100

# networkInversion.waterMaskFile is a SEPARATE key from load.waterMaskFile.
# Must be set to no independently. If it still points to waterMask.rdr,
# ifgram_inversion.py tries to open the ISCE2 binary raster as HDF5 and
# crashes: IndexError: list index out of range. [M3]
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
# This ensures consistent colorscale across frames and correction sets.
mintpy.plot.vlim               = -10 10

CFGEOF

    log_ok "${FRAME}: Config written (${CFG})"
}

# ==============================================================
# Error classifier
# Pattern-matches the log file against the error catalog.
# Sets globals ERR_TYPE, ERR_DESC, ERR_FIX.
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
        # [FIX-18] Pattern deliberately excludes bare "LOD" and "correct_lod" — these appear
        # in MintPy's "Remaining steps: ... correct_LOD ..." header in every step log and
        # would cause false LOD_FAIL classification of any other step's failure.
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
            # Patch cfg
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
# [NEW-08] DemErr-only pass
# Runs correct_topography + velocity with deramp=no to produce
# timeseries_demErr.h5 and velocity_demErr.h5.
# Required by linog_fbs_processor.sh Phase 6 (dual-correction deliverables).
# Called AFTER the standard pipeline completes for a frame.
# Prerequisite: velocity_demErr_ramp.h5 must already be saved from velocity.h5.
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
    log_info "${FRAME}:   Input:  timeseries.h5 -> timeseries_demErr.h5"
    log_info "${FRAME}:   Output: velocity_demErr.h5 (no ramp removal)"

    # Prerequisite: timeseries.h5 from invert_network
    if [ ! -f "${MINTPY_DIR}/timeseries.h5" ]; then
        log_warn "${FRAME}: timeseries.h5 not found — skipping demErr-only pass"
        log_warn "${FRAME}: Phase 6 demErr products will be missing"
        return 0
    fi

    cd "${MINTPY_DIR}" || { log_error "${FRAME}: Cannot cd to ${MINTPY_DIR}"; return 1; }

    # Create demonly cfg: copy standard, override deramp, pin velocity input
    cp "${MINTPY_DIR}/smallbaselineApp.cfg" "${DEMONLY_CFG}"
    sed -i 's/^mintpy\.deramp\b.*/mintpy.deramp = no/' "${DEMONLY_CFG}"
    # Explicitly set velocity input to avoid ambiguity when both
    # timeseries_ramp_demErr.h5 and timeseries_demErr.h5 will coexist
    echo "mintpy.velocity.timeseriesFile = timeseries_demErr.h5" >> "${DEMONLY_CFG}"
    log_info "${FRAME}: demonly cfg written (deramp=no, input=timeseries_demErr.h5)"

    # Temporarily move velocity.h5 aside so MintPy update mode does not skip the step.
    # velocity_demErr_ramp.h5 was already saved by process_frame() before this call.
    local VEL_MOVED="no"
    if [ -f "velocity.h5" ]; then
        mv "velocity.h5" "velocity.h5.demonly_bak"
        VEL_MOVED="yes"
    fi

    local EXIT_CODE=0
    local V=1
    while [ -f "${LOG_FILE}.v${V}" ]; do V=$((V+1)); done
    LOG_FILE="${LOG_FILE}.v${V}"

    # --- correct_topography with deramp=no: timeseries.h5 -> timeseries_demErr.h5 ---
    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp_demonly.cfg \
        --dostep correct_topography \
        > "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        log_warn "${FRAME}: demErr-only correct_topography failed — check ${LOG_FILE}"
        # Restore velocity.h5 before returning
        [ "$VEL_MOVED" = "yes" ] && mv "velocity.h5.demonly_bak" "velocity.h5"
        return 0  # warn only — do not abort frame
    fi
    log_ok "${FRAME}: timeseries_demErr.h5 created"

    # --- velocity with demonly cfg: timeseries_demErr.h5 -> velocity.h5 ---
    EXIT_CODE=0
    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp_demonly.cfg \
        --dostep velocity \
        >> "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        log_warn "${FRAME}: demErr-only velocity failed — check ${LOG_FILE}"
        [ "$VEL_MOVED" = "yes" ] && mv "velocity.h5.demonly_bak" "velocity.h5"
        return 0
    fi

    # velocity.h5 is now the demErr-only product — rename it
    if [ -f "velocity.h5" ]; then
        mv "velocity.h5" "velocity_demErr.h5"
        log_ok "${FRAME}: velocity_demErr.h5 saved (demErr only, no ramp)"
    fi

    # Restore velocity.h5 to the ramp+demErr product for geocode and KMZ
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
# [NEW-09] Geocode demErr-only products + rename standard geo_velocity
# After the standard geocode step runs (via MINTPY_STEPS), geo_velocity.h5
# contains the ramp+demErr velocity. This function:
#   1. Renames geo_velocity.h5 -> geo_velocity_demErr_ramp.h5
#   2. Geocodes velocity_demErr.h5 -> geo_velocity_demErr.h5
#   3. Geocodes timeseries_demErr.h5 -> geo_timeseries_demErr.h5
# After this, all 4 files required by Phase 6 are present in geo/:
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

    # Locate geocode.py
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

    # 1. geo_velocity.h5 (from standard geocode) = ramp+demErr velocity -> rename
    if [ -f "${GEO_DIR}/geo_velocity.h5" ]; then
        mv -f "${GEO_DIR}/geo_velocity.h5" "${GEO_DIR}/geo_velocity_demErr_ramp.h5"
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
# Wraps a single MintPy --dostep call with:
#   - sentinel check (skip if done)
#   - prep_isce.py pre-step (load_data only)
#   - versioned log file
#   - error classification and ERROR_SUMMARY logging
#   - auto-heal + single retry for M1, M2, M3
#   - first-seen flag: prints known fix only on first occurrence
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

    # Skip if sentinel exists
    if [ -f "${SENTINEL}" ]; then
        log_skip "${FRAME}: ${STEP_N}_${STEP} — sentinel exists"
        return 0
    fi

    log_step "${FRAME}: [${STEP_N}/${#MINTPY_STEPS[@]}] ${STEP} — ${STEP_DESC[$STEP]}"

    # Pre-step healing
    case "$STEP" in
        load_data)
            heal_check_hdf5_integrity "${MINTPY_DIR}" "${FRAME}"
            run_prep_isce "${FRAME_DIR}" "${FRAME}" || return 1
            ;;
    esac

    # Version log file
    local V=1
    while [ -f "${LOG_DIR}/${STEP_N}_${STEP}.log.v${V}" ]; do V=$((V+1)); done
    local LOG_FILE="${LOG_DIR}/${STEP_N}_${STEP}.log.v${V}"

    local START_TS; START_TS="$(_pst)"
    local EXIT_CODE=0

    cd "${MINTPY_DIR}" || {
        log_error "${FRAME}: Cannot cd to ${MINTPY_DIR}"
        return 1
    }

    # Run the step (no PYTHONPATH injection — isce2 env has everything)
    "${PYTHON}" "${SMALLBASELINE}" smallbaselineApp.cfg --dostep "${STEP}" \
        > "${LOG_FILE}" 2>&1 || EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        touch "${SENTINEL}"
        log_ok "${FRAME}: ${STEP} done -> $(basename ${LOG_FILE})"
        # Post-step actions
        case "$STEP" in
            load_data)
                heal_watermask_patch "${MINTPY_DIR}" "${FRAME}"
                ;;
        esac
        return 0
    fi

    # ---- First attempt failed ----
    ERR_TYPE=""; ERR_DESC=""; ERR_FIX=""
    classify_error "${LOG_FILE}"

    # Try auto-heal + single retry
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
        # Still failed after auto-heal — re-classify
        classify_error "${LOG_FILE}"
    fi

    # ---- Log failure to ERROR_SUMMARY ----
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
# Interferogram pair exclusion  [v2.7]
# ==============================================================

# Move listed pairs from Igrams/ to Igrams/rejected_pairs/ before MintPy loads them.
# Idempotent: if a pair is already in rejected_pairs/, it is skipped (not double-moved).
# Called from process_frame() before cfg generation so load_data never sees bad pairs.
reject_bad_igrams() {
    local FRAME="$1"
    local PAIRS="${EXCLUDE_IGRAMS[$FRAME]:-}"
    [[ -z "$PAIRS" ]] && return 0

    local IGRAMS_DIR="${BASE_DIR}/${FRAME}/Igrams"
    local REJ_DIR="${IGRAMS_DIR}/rejected_pairs"

    if [[ ! -d "$IGRAMS_DIR" ]]; then
        log_warn "${FRAME}: reject_bad_igrams — Igrams/ not found at ${IGRAMS_DIR}; skipping"
        return 0
    fi

    mkdir -p "$REJ_DIR"
    log_info "${FRAME}: reject_bad_igrams — checking ${PAIRS// / } pairs for exclusion"

    for PAIR in $PAIRS; do
        local SRC="${IGRAMS_DIR}/${PAIR}"
        local DST="${REJ_DIR}/${PAIR}"
        if [[ -d "$SRC" ]]; then
            mv "$SRC" "$REJ_DIR/"
            log_info "${FRAME}:   moved excluded pair ${PAIR} → rejected_pairs/"
        elif [[ -d "$DST" ]]; then
            log_info "${FRAME}:   pair ${PAIR} already in rejected_pairs/ — skip"
        else
            log_warn "${FRAME}:   excluded pair ${PAIR} not found in Igrams/ or rejected_pairs/"
        fi
    done
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

    # RERUN_MINTPY_FRAMES: clear mintpy/ + mintpy_logs/ for listed frames before running.
    # Handles the case where ISCE2 was reprocessed and old MintPy output is stale.
    for _rerun_f in ${RERUN_MINTPY_FRAMES}; do
        if [[ "${FRAME}" == "${_rerun_f}" ]]; then
            log_warn "${FRAME}: RERUN_MINTPY_FRAMES — clearing mintpy/ and mintpy_logs/"
            rm -rf "${FRAME_DIR}/mintpy/"
            rm -rf "${LOG_DIR}"
            log_info "${FRAME}: Cleared. Fresh MintPy run will follow."
            break
        fi
    done

    mkdir -p "${LOG_DIR}"

    local START_TS; START_TS="$(_pst)"

    if [ -f "${COMPLETE_SENTINEL}" ]; then
        log_ok "P447-${FRAME^^}: MINTPY_COMPLETE sentinel exists — already done. Skipping."
        return 0
    fi

    {
        echo ""
        echo "=== LInOG MintPy Run ==="
        echo "Frame: P447-${FRAME^^} | Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
        echo "Started: ${START_TS}"
    } >> "${ERROR_LOG}"

    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info " P447-${FRAME^^}  MintPy pipeline"
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

    # [v2.7] Move excluded interferogram pairs to rejected_pairs/ before MintPy loads them.
    # Must run before cfg generation (load_data reads directly from Igrams/).
    reject_bad_igrams "$FRAME"

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
            echo "FRAME ABORTED: P447-${FRAME^^} at ${ABORT_TS}" >> "${ERROR_LOG}"
            log_error "${FRAME}: Pipeline aborted at ${STEP}."
            log_error "  Re-run after fixing: completed steps will be skipped automatically."
            log_error "  To resume from this frame: set START_FRAME=${FRAME} in the script."
            return 1
        }
    done

    # ---- Post-pipeline: produce dual-correction products for Phase 6 deliverables ----
    # Standard pipeline produced velocity.h5 (ramp+demErr) and geo_velocity.h5.
    # Phase 6 requires BOTH demErr-only and ramp+demErr variants in geo/.
    local MINTPY_DIR="${FRAME_DIR}/mintpy"

    # Save velocity.h5 (ramp+demErr) before demErr-only pass overwrites it
    # [FIX-STALE-01 v2.8]: Always force-save velocity_demErr_ramp.h5 from current velocity.h5.
    # Prior [ ! -f ] condition skipped this copy when old file existed from a previous bad run,
    # leaving stale data for Phase 6 deliverables. Root cause of Jun 8 2026 bad demErr_ramp output.
    if [ -f "${MINTPY_DIR}/velocity.h5" ]; then
        cp -f "${MINTPY_DIR}/velocity.h5" "${MINTPY_DIR}/velocity_demErr_ramp.h5"
        log_info "${FRAME}: velocity_demErr_ramp.h5 force-saved from velocity.h5 [FIX-STALE-01]"
    fi

    # Second pass: correct_topography + velocity with deramp=no
    run_mintpy_demErr_pass "${FRAME}" "${FRAME_DIR}"

    # Geocode demErr products and rename geo_velocity.h5 -> geo_velocity_demErr_ramp.h5
    geocode_demErr_files "${FRAME}" "${FRAME_DIR}"

    touch "${COMPLETE_SENTINEL}"
    local END_TS; END_TS="$(_pst)"
    echo "COMPLETED MintPy: P447-${FRAME^^} at ${END_TS}" >> "${ERROR_LOG}"
    log_ok "P447-${FRAME^^}: MintPy COMPLETE"
    log_ok "  timeseries_ramp_demErr.h5:   ${FRAME_DIR}/mintpy/timeseries_ramp_demErr.h5"
    log_ok "  timeseries_demErr.h5:        ${FRAME_DIR}/mintpy/timeseries_demErr.h5"
    log_ok "  velocity_demErr_ramp.h5:     ${FRAME_DIR}/mintpy/velocity_demErr_ramp.h5"
    log_ok "  velocity_demErr.h5:          ${FRAME_DIR}/mintpy/velocity_demErr.h5"
    log_ok "  geo_velocity_demErr_ramp.h5: ${FRAME_DIR}/mintpy/geo/geo_velocity_demErr_ramp.h5"
    log_ok "  geo_velocity_demErr.h5:      ${FRAME_DIR}/mintpy/geo/geo_velocity_demErr.h5"
    log_ok "  geo_timeseries_ramp_demErr.h5: ${FRAME_DIR}/mintpy/geo/geo_timeseries_ramp_demErr.h5"
    log_ok "  geo_timeseries_demErr.h5:    ${FRAME_DIR}/mintpy/geo/geo_timeseries_demErr.h5"
}

# ==============================================================
# Main
# ==============================================================

main() {
    echo ""
    echo -e "${BOLD}LInOG MintPy Batch Script${NC} v${SCRIPT_VERSION}"
    echo "  Path:       P447"
    echo "  Frames:     ${FRAMES[*]}"
    echo "  RefDate:    ${REF_DATE}"
    echo "  StartFrom:  ${START_FRAME}"
    echo "  MintPyEnv:  ${MINTPY_ENV} (isce2 — required)"
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
    log_ok "All P447 frames complete. Phase 6 geo files per frame:"
    for FRAME in "${FRAMES[@]}"; do
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_velocity_demErr_ramp.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_velocity_demErr.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_timeseries_ramp_demErr.h5"
        log_ok "  ${BASE_DIR}/${FRAME}/mintpy/geo/geo_timeseries_demErr.h5"
    done
    echo ""
}

main "$@"
