#!/bin/bash
# ==============================================================
# linog_batch_p449_mintpy.sh  v1.0
# MintPy time-series InSAR processing — P449 (F0280–F0320)
#
# Derived from: linog_batch_p447_mintpy.sh v2.4 (Jun 7, 2026)
# All p447 fixes incorporated from the start — no migration needed.
#
# Key differences from p447:
#   - BASE_DIR:  p449  (5 frames: f0280 f0290 f0300 f0310 f0320)
#   - REF_DATE:  20081125  (p447 used 20090309)
#   - metaFile:  SLC/20081125/data.dat  [VERIFY shelve subdir on felix]
#   - waterMask: same all-zero ISCE2 issue expected — auto-heal active
#   - MIN_TEMP_COH: all 0.7 to start; adjust per frame if NO_COHERENT fires
#
# Features (inherited from p447 v2.4):
#   - Sentinel-based step skipping — re-run resumes from last failure
#   - ERROR_SUMMARY.txt per frame: first-seen flag, known fix, log ref
#   - Error catalog: pattern-match on known MintPy/ALOS-1 failure signatures
#   - Self-healing: HDF5 integrity check, waterMask patch, auto-heal + retry
#   - Two-pass MintPy: ramp+demErr (pass 1) and demErr-only (pass 2)
#   - Phase 6 deliverables: four geo/ files per frame ready for linog_fbs_processor.sh
#   - Autonomous: discovers ISCE2 output layout, validates prerequisites
#
# Usage:
#   chmod +x linog_batch_p449_mintpy.sh
#   ./linog_batch_p449_mintpy.sh
#   # To resume from a specific frame:
#   # Edit START_FRAME="f0300" then re-run
#
# Output per frame:
#   p449/FRAME/mintpy/           <- MintPy working directory + results
#   p449/FRAME/mintpy_logs/      <- step logs, sentinels, ERROR_SUMMARY.txt
#
# Prerequisite: ISCE2 batch (linog_batch_p449_ph0to4.sh) must be COMPLETE
# per frame (sentinel: p449/FRAME/logs/.done.FRAME_COMPLETE).
# f0280 is COMPLETE as of Jun 7, 2026. f0290-f0320 are pending ISCE2.
#
# Changelog v1.0 (Jun 7, 2026):
#   Initial port from linog_batch_p447_mintpy.sh v2.4.
#   All FIX-01 through FIX-22 and NEW-01 through NEW-09 from p447 v2.4
#   are incorporated as the baseline — no further fixes needed to start.
#   P449-specific changes:
#   [P449-01] BASE_DIR: p449
#   [P449-02] FRAMES: f0280 f0290 f0300 f0310 f0320 (5 frames)
#   [P449-03] REF_DATE: 20081125 (nearest temporal midpoint for p449)
#   [P449-04] MIN_TEMP_COH: 0.7 default all frames; lower f0310 if needed
#   [P449-05] metaFile: SLC/20081125/data.dat [VERIFY shelve subdir on felix]
#   [P449-06] EXCLUDE_DATES: empty all frames — bad early dates (20060520,
#             20060705, 20060820, 20070105) rejected at ISCE2 level (E8
#             run_04 warn + cleanup); their .unw files do not exist
#   [P449-07] waterMask: all-zero ISCE2 issue expected same as P447;
#             heal_watermask_patch() and auto-heal active
# ==============================================================

set -uo pipefail
SCRIPT_VERSION="1.1"
SCRIPT_NAME="$(basename "$0")"

# ==============================================================
# CONFIGURATION — edit before first run
# ==============================================================

BASE_DIR="/eggraid/home/arieln/projects/linog/insar/p449"

# Frames to process, in order
FRAMES=("f0280" "f0290" "f0300" "f0310" "f0320")

# Set to the first frame you want to run (useful for resuming)
# f0280 is ISCE2-complete as of Jun 7, 2026.
# f0290-f0320: run after ISCE2 is complete for each frame.
START_FRAME="f0280"

# Reference date — must match ISCE2 processing reference
# P449 ref date: 20081125 (nearest temporal midpoint of 2006-2011 stack)
REF_DATE="20081125"

# MintPy + ISCE2 conda environment (full path, no conda activate needed)
# MUST be the isce2 env — it has both MintPy 1.6.2 and ISCE2 installed.
# mintpy_stable does NOT have isce; prep_isce.py will fail with ImportError.
MINTPY_ENV="/eggraid/miniconda3/envs/isce2"

# Per-frame temporal coherence threshold
# Starting default: 0.7 for all frames.
# Lower if invert_network fires NO_COHERENT (classify_error will flag this).
# P447 f0310 (vegetated/mountainous) needed 0.3 — expect similar for P449 f0310.
# Adjust and delete the .done.05_invert_network sentinel to retry.
declare -A MIN_TEMP_COH
MIN_TEMP_COH["f0280"]="0.7"   # Good coherence frame — default
MIN_TEMP_COH["f0290"]="0.4"   # Very low coherence (~1-3 coherent pairs); per diagnostic §7.3
MIN_TEMP_COH["f0300"]="0.3"   # Near-zero coherence; may still fail — per diagnostic §7.3
MIN_TEMP_COH["f0310"]="0.4"   # Low coherence, 1 standout pair; per diagnostic §7.3
MIN_TEMP_COH["f0320"]="0.3"   # Near-zero coherence; per diagnostic §7.3

# Dates to exclude per frame (space-separated; empty = no exclusion)
# [P449-06] Early scenes 20060520/20060705/20060820/20070105 rejected at ISCE2
# level (E8: run_04 failures + cleanup) — their .unw files do not exist.
# Only add explicit exclusions if MintPy inversion or residual_RMS flags a date.
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
ERRCAT_NO_COHERENT_FIX="Lower mintpy.networkInversion.minTempCoh in cfg (try 0.5 then 0.3 for low-coherence frames). Delete .done.05_invert_network sentinel and re-run."

ERRCAT_REF_POINT_DESC="Reference point selection failed — no valid (high coherence, non-masked) pixel"
ERRCAT_REF_POINT_FIX="Add to cfg: mintpy.reference.lalo = LAT,LON (pick a stable urban or rocky area pixel). Delete .done.03_reference_point sentinel and re-run."

ERRCAT_LOAD_NO_UNW_DESC="No unwrapped interferogram files found — glob pattern matched 0 files"
ERRCAT_LOAD_NO_UNW_FIX="Check mintpy.load.unwFile path in cfg. Verify filt_*unw files exist in Igrams/. ISCE2 Phase 4 must be complete."

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

# --- P449-specific errors (same root causes as P447; see comments) ---

# M1: waterMask.rdr is all-zero in P449 ISCE2 output (same issue as P447).
# [P449-07] Confirmed same ISCE2 version/pipeline; auto-heal active.
ERRCAT_WATERMASK_NAN_DESC="[M1] waterMask all-zero: waterMask.rdr is an all-zero ISCE2 raster. modify_network generates empty waterMask.h5 -> NaN spatial coherence -> ValueError"
ERRCAT_WATERMASK_NAN_FIX="[AUTO-HEAL] Script patches geometryRadar.h5['waterMask'] to all-ones, deletes waterMask.h5 and coherenceSpatialAvg.txt, retries modify_network. Root fix: cfg has waterMaskFile = no."

# M2: SNAPHU connected components are empty (rainy-season pairs).
ERRCAT_CONNCOMP_EMPTY_DESC="[M2] maskConnComp empty: intersection of all SNAPHU connected component masks is 0 valid pixels (rainy-season decorrelation). Reference point cannot be placed inside any connected component."
ERRCAT_CONNCOMP_EMPTY_FIX="[AUTO-HEAL] Script deletes partial unwrapPhase_bridging dataset, sets mintpy.unwrapError.method = no in cfg, retries. Bridging is not viable for this scene."

# M3: mintpy.networkInversion.waterMaskFile is a separate key from mintpy.load.waterMaskFile.
ERRCAT_INVERSION_WATERMASK_DESC="[M3] networkInversion.waterMaskFile mismatch: mintpy.networkInversion.waterMaskFile is a SEPARATE key from mintpy.load.waterMaskFile. If it still points to waterMask.rdr, ifgram_inversion.py crashes with IndexError: list index out of range."
ERRCAT_INVERSION_WATERMASK_FIX="[AUTO-HEAL] Script sets mintpy.networkInversion.waterMaskFile = no in cfg and retries. Always set BOTH waterMaskFile keys to no for P449."

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
# ==============================================================

heal_verify_isce2_outputs() {
    local FRAME_DIR="$1"
    local FRAME="$2"
    local ERRORS=0

    if [ ! -f "${FRAME_DIR}/logs/.done.FRAME_COMPLETE" ]; then
        log_error "${FRAME}: ISCE2 FRAME_COMPLETE sentinel missing — run ISCE2 batch script first"
        log_error "  Expected: ${FRAME_DIR}/logs/.done.FRAME_COMPLETE"
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
# [P449-07] waterMask.rdr is all-zero in P449 ISCE2 output (same as P447).
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
# Pre-step: run prep_isce.py to generate RSC metadata files
# ==============================================================

run_prep_isce() {
    local FRAME_DIR="$1"
    local FRAME="$2"
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

    # [P449-05] P449 shelve layout expected same as P447: SLC/REF_DATE/data.dat
    # (no merged/ prefix, no referenceShelve/ subdir — verify on felix if unsure)
    local META="SLC/${REF_DATE}/data.dat"
    if [ ! -f "${FRAME_DIR}/${META}" ]; then
        log_error "${FRAME}: shelve metadata not found: ${FRAME_DIR}/${META}"
        log_error "  ISCE2 must be fully processed before running MintPy."
        log_error "  [VERIFY] If shelve is at merged/SLC/${REF_DATE}/referenceShelve/data.dat,"
        log_error "  update META in run_prep_isce() and metaFile in generate_mintpy_cfg()."
        return 1
    fi

    # Delete stale RSC sidecar files before running prep_isce.
    # A second run without cleanup leaves stale .rsc files that lack P_BASELINE_TOP_HDR.
    log_info "${FRAME}: Cleaning stale RSC sidecar files in Igrams/ and geom_reference/"
    find "${FRAME_DIR}/Igrams"         -name "*.rsc" -delete 2>/dev/null
    find "${FRAME_DIR}/geom_reference" -name "*.rsc" -delete 2>/dev/null
    log_info "${FRAME}: RSC cleanup done"

    log_info "${FRAME}: Running prep_isce.py from ${FRAME_DIR}"
    log_info "${FRAME}:   -m ${META}"
    log_info "${FRAME}:   -g geom_reference"
    log_info "${FRAME}:   -b baselines"
    log_info "${FRAME}:   -f \"Igrams/*/filt_*.unw\""
    (
        cd "${FRAME_DIR}" || { log_error "${FRAME}: Cannot cd to ${FRAME_DIR}"; exit 1; }
        "${PYTHON}" "${PREP_ISCE}" \
            -m "SLC/${REF_DATE}/data.dat" \
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
# All P447 fixes baked in from the start.
#
# [P449-05] metaFile: SLC/REF_DATE/data.dat (verify shelve subdir on felix)
# [P449-07] waterMaskFile = no for both load and networkInversion keys
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

    # [P449-05] P449 shelve layout: SLC/REF_DATE/data.dat
    # Same structure as P447 (no merged/ prefix, no referenceShelve/ subdir).
    # If this path is wrong on felix, update here and in run_prep_isce().
    local META_FILE="${FRAME_DIR}/SLC/${REF_DATE}/data.dat"
    if [ ! -f "${META_FILE}" ]; then
        log_warn "${FRAME}: Shelve not found: ${META_FILE} — metaFile will be set but may fail"
        log_warn "  Verify ISCE2 ran with ref date ${REF_DATE}"
        log_warn "  [VERIFY] If P449 uses merged/SLC/${REF_DATE}/referenceShelve/data.dat,"
        log_warn "  update META_FILE path here and in run_prep_isce()."
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
## Path: P449 | Frame: ${FRAME^^}
## Generated: $(_ts) by ${SCRIPT_NAME} v${SCRIPT_VERSION}
##
## Edit mintpy.reference.lalo if reference_point fails (Section 3).
## Edit mintpy.networkInversion.minTempCoh if inversion is too sparse.
## ================================================================

# ----------------------------------------------------------------
# 1. Data loading
# ----------------------------------------------------------------
mintpy.load.processor        = isce

# [P449-05] P449 shelve layout expected same as P447: SLC/REF_DATE/data.dat
# If this path is wrong, update generate_mintpy_cfg() and run_prep_isce().
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
mintpy.load.lookupYFile      = ${GEOM_DIR}/lat.rdr
mintpy.load.lookupXFile      = ${GEOM_DIR}/lon.rdr

mintpy.load.incAngleFile     = ${GEOM_DIR}/incLocal.rdr
mintpy.load.azAngleFile      = ${GEOM_DIR}/los.rdr

# [P449-07] waterMaskFile MUST be no for P449.
# waterMask.rdr in geom_reference/ is an all-zero ISCE2 raster (same as P447).
# If loaded, geometryRadar.h5['waterMask'] becomes all-zero -> NaN coherence. [M1]
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
mintpy.reference.date          = ${REF_DATE}
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

# [P449-07] networkInversion.waterMaskFile is a SEPARATE key from load.waterMaskFile.
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

    log_step "${FRAME}: [${STEP_N}/${#MINTPY_STEPS[@]}] ${STEP} — ${STEP_DESC[$STEP]}"

    case "$STEP" in
        load_data)
            heal_check_hdf5_integrity "${MINTPY_DIR}" "${FRAME}"
            run_prep_isce "${FRAME_DIR}" "${FRAME}" || return 1
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

    mkdir -p "${LOG_DIR}"

    local START_TS; START_TS="$(_pst)"

    if [ -f "${COMPLETE_SENTINEL}" ]; then
        log_ok "P449-${FRAME^^}: MINTPY_COMPLETE sentinel exists — already done. Skipping."
        return 0
    fi

    {
        echo ""
        echo "=== LInOG MintPy Run ==="
        echo "Frame: P449-${FRAME^^} | Script: ${SCRIPT_NAME} v${SCRIPT_VERSION}"
        echo "Started: ${START_TS}"
    } >> "${ERROR_LOG}"

    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info " P449-${FRAME^^}  MintPy pipeline"
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
            echo "FRAME ABORTED: P449-${FRAME^^} at ${ABORT_TS}" >> "${ERROR_LOG}"
            log_error "${FRAME}: Pipeline aborted at ${STEP}."
            log_error "  Re-run after fixing: completed steps will be skipped automatically."
            log_error "  To resume from this frame: set START_FRAME=${FRAME} in the script."
            return 1
        }
    done

    # ---- Post-pipeline: dual-correction products for Phase 6 deliverables ----
    local MINTPY_DIR="${FRAME_DIR}/mintpy"

    # [FIX-STALE-01 v1.1]: Always force-save velocity_demErr_ramp.h5 from current velocity.h5.
    # Prior [ ! -f ] condition skipped this copy when old file existed from a previous bad run,
    # leaving stale data for Phase 6 deliverables. Root cause of Jun 8 2026 bad demErr_ramp output.
    if [ -f "${MINTPY_DIR}/velocity.h5" ]; then
        cp -f "${MINTPY_DIR}/velocity.h5" "${MINTPY_DIR}/velocity_demErr_ramp.h5"
        log_info "${FRAME}: velocity_demErr_ramp.h5 force-saved from velocity.h5 [FIX-STALE-01]"
    fi

    run_mintpy_demErr_pass "${FRAME}" "${FRAME_DIR}"
    geocode_demErr_files "${FRAME}" "${FRAME_DIR}"

    touch "${COMPLETE_SENTINEL}"
    local END_TS; END_TS="$(_pst)"
    echo "COMPLETED MintPy: P449-${FRAME^^} at ${END_TS}" >> "${ERROR_LOG}"
    log_ok "P449-${FRAME^^}: MintPy COMPLETE"
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
    echo "  Path:       P449"
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
    log_ok "All P449 frames complete. Phase 6 geo files per frame:"
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
