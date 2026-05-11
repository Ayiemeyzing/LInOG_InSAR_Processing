#!/bin/bash
# ==============================================================================
# LInOG FBS InSAR Processing Pipeline v2.0
# ALOS-1 PALSAR Fine Beam Single (FBS) Stack Processor
# ISCE2 + MintPy Automated Workflow
#
# Project:  LInOG (Leveraging InSAR for Observation and modeling of
#           earthquake Generators)
# Author:   Ariel J. Nopre Jr., Remote Sensing Scientist, UPD-NIGS
# Version:  2.0.0
# Date:     March 2026
#
# Usage:    ./linog_fbs_processor.sh          (full pipeline, interactive)
#           ./linog_fbs_processor.sh [phase]   (single phase)
#
# Phases:   0=setup, 1=data, 2=dem, 3=stack, 4=isce2,
#           4.5=igram_viz (LOCAL), 5=mintpy, 6=deliverables, 7=summary
#
# Naming:   Scripts  -> linog_*.sh / linog_*.py
#           Outputs  -> P###F####_[type]_[correction].ext
#           Logs     -> ##_[step_name].log.v#
#
# Ref:      Pepe & Calo (2017), doi:10.3390/rs9010016
# ==============================================================================

set -euo pipefail

SCRIPT_VERSION="2.0.0"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# -- Colors --
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# -- LInOG DEM bounds (Luzon, Philippines) --
DEM_MIN_LAT=14; DEM_MAX_LAT=18; DEM_MIN_LON=120; DEM_MAX_LON=123
DEM_URL="http://step.esa.int/auxdata/dem/SRTMGL1/"

# -- ISCE2 Stack Parameters (FBS) --
TEMPORAL_BASELINE=730
PERP_BASELINE=1500
AZIMUTH_LOOKS=28
RANGE_LOOKS=12
UNWRAPPER="snaphu"

# -- MintPy --
COHERENCE_THRESHOLD=0.4

# -- Server paths --
ALOS_DATA_SOURCE="/eggraid/data/alos"
SCRIPTS_SOURCE="/eggraid/sbin"

# ==============================================================================
# UTILITIES
# ==============================================================================

log_info()    { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
log_step()    { echo ""; echo -e "${CYAN}${BOLD}======== PHASE $1: $2 ========${NC}"; echo ""; }
log_substep() { echo -e "${BLUE}[STEP]${NC} $1"; }

get_log_version() {
    local base="$1" dir="$2" v=1
    while [ -f "${dir}/${base}.v${v}" ]; do v=$((v + 1)); done
    echo "${dir}/${base}.v${v}"
}

check_status() {
    local name="$1" code="$2" log="$3"
    if [ "$code" -ne 0 ]; then
        log_error "$name FAILED (exit $code). Log: $log"
        echo "FAILED: $name at $(date)" >> "${WORK_DIR}/logs/ERROR_SUMMARY.txt"
        return 1
    fi
    log_info "$name completed."
}

# ==============================================================================
# USER INPUT
# ==============================================================================

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║       LInOG FBS InSAR Processing Pipeline v${SCRIPT_VERSION}           ║"
    echo "  ║       ALOS-1 PALSAR | ISCE2 + MintPy Automation            ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  Stack: FBS only | Looks: ${AZIMUTH_LOOKS}az x ${RANGE_LOOKS}rg (~90m)"
    echo "  Coherence: ${COHERENCE_THRESHOLD} | Corrections: demErr + demErr_ramp"
    echo "  Deliverables: GeoTIFF, KMZ, Hillshade PNG, Interactive KMZ"
    echo ""
}

get_user_inputs() {
    echo -e "${BOLD}--- Required Inputs ---${NC}"

    while true; do
        read -p "  ALOS Path (3-digit, e.g. 448): " INPUT_PATH
        [[ "$INPUT_PATH" =~ ^[0-9]{3}$ ]] && break
        log_warn "Must be 3 digits."
    done

    while true; do
        read -p "  ALOS Frame (4-digit, e.g. 0310): " INPUT_FRAME
        [[ "$INPUT_FRAME" =~ ^[0-9]{4}$ ]] && break
        log_warn "Must be 4 digits."
    done

    read -p "  Reference date (YYYYMMDD or blank for auto): " INPUT_REF_DATE
    REF_DATE=${INPUT_REF_DATE:-auto}

    read -p "  Parallel jobs (check htop) [4]: " INPUT_JOBS
    PARALLEL_JOBS=${INPUT_JOBS:-4}

    echo "  Server: 1) Remote (felix/eggraid)  2) Local"
    read -p "  Select [1]: " INPUT_SERVER
    SERVER_TYPE=${INPUT_SERVER:-1}

    if [ "$SERVER_TYPE" -eq 1 ]; then
        BASE_DIR="/eggraid/home/${USER}/projects/linog/insar"
    else
        BASE_DIR="${HOME}/LInOG/insar"
    fi

    PADDED_PATH="p${INPUT_PATH}"
    PADDED_FRAME="f${INPUT_FRAME}"
    WORK_DIR="${BASE_DIR}/${PADDED_PATH}/${PADDED_FRAME}"
    FRAME_TAG="P${INPUT_PATH}F${INPUT_FRAME}"
    DEM_FILE="demLat_N${DEM_MIN_LAT}_N${DEM_MAX_LAT}_Lon_E${DEM_MIN_LON}_E${DEM_MAX_LON}.dem.wgs84"

    echo ""
    echo -e "${BOLD}--- Summary ---${NC}"
    echo "  Frame Tag:   ${FRAME_TAG}"
    echo "  Working Dir: ${WORK_DIR}"
    echo "  Ref Date:    ${REF_DATE}"
    echo "  Jobs:        ${PARALLEL_JOBS}"
    echo ""
    read -p "  Proceed? (y/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

# ==============================================================================
# PHASE 0: DIRECTORY SETUP
# ==============================================================================

phase_0_setup() {
    log_step "0" "Directory Setup"
    mkdir -p "${WORK_DIR}"/{raw,unzipped,SLC,DEM,logs,mintpy/inputs,interferograms,run_files,Igrams/logs}
    mkdir -p "${WORK_DIR}/mintpy/geo/LInOG_Upload_${FRAME_TAG}"

    echo "=== LInOG Error Summary ===" > "${WORK_DIR}/logs/ERROR_SUMMARY.txt"
    echo "Frame: ${FRAME_TAG} | Started: $(date)" >> "${WORK_DIR}/logs/ERROR_SUMMARY.txt"

    log_info "Directories created at: ${WORK_DIR}"
}

# ==============================================================================
# PHASE 1: DATA ACQUISITION
# ==============================================================================

phase_1_data_acquisition() {
    log_step "1" "Data Acquisition"
    cd "${WORK_DIR}"

    # 1.1 Find and symlink
    log_substep "1.1: Finding ALOS data..."
    local LOG=$(get_log_version "01_find_alos.log" "logs")
    find_alos.sh "${INPUT_PATH}" "${INPUT_FRAME}" "${ALOS_DATA_SOURCE}" raw/ 2>&1 | tee "${LOG}"

    # Fix nested directory from find_alos.sh
    if [ -d "raw/${INPUT_PATH}/${INPUT_FRAME}/data" ]; then
        mv raw/${INPUT_PATH}/${INPUT_FRAME}/data/*.zip raw/ 2>&1 | tee -a "${LOG}"
        rm -rf "raw/${INPUT_PATH}/" 2>&1 | tee -a "${LOG}"
    fi

    # Create data->raw symlink (required by unzip script)
    [ ! -L "data" ] && ln -s raw data 2>&1 | tee -a "${LOG}"

    log_info "Acquisitions found: $(ls raw/*.zip 2>/dev/null | wc -l)"

    # 1.2 Unzip FBS only
    log_substep "1.2: Extracting FBS acquisitions..."
    local LOG=$(get_log_version "02_unzip_fbs.log" "logs")
    python ~/bin/unzip_ALOS-SLC-pol.py --pol FBS 2>&1 | tee "${LOG}"
    check_status "FBS Unzip" $? "${LOG}" || return 1

    # 1.3 Unpack to SLC
    log_substep "1.3: Unpacking to SLC format..."
    local LOG=$(get_log_version "03_unpack_all.log" "logs")
    run_unpack_all_cli.py 2>&1 | tee "${LOG}"
    check_status "SLC Unpack" $? "${LOG}" || return 1

    log_info "FBS SLC dates: $(ls SLC/ | wc -l)"
    ls SLC/ | sort
}

# ==============================================================================
# PHASE 2: DEM PREPARATION (download only)
# ==============================================================================

phase_2_dem() {
    log_step "2" "DEM Preparation (SRTM Download)"
    cd "${WORK_DIR}"

    local LOG=$(get_log_version "04_dem.log" "logs")

    log_substep "Downloading SRTM DEM via dem.py..."
    mkdir -p DEM && cd DEM
    dem.py -a stitch \
        -b ${DEM_MIN_LAT} ${DEM_MAX_LAT} ${DEM_MIN_LON} ${DEM_MAX_LON} \
        -r -s 1 -c \
        -u "${DEM_URL}" 2>&1 | tee "${WORK_DIR}/${LOG}"

    # Clean individual tiles
    rm -f demLat*.dem demLat*.dem.xml demLat*.dem.vrt 2>&1 | tee -a "${WORK_DIR}/${LOG}"
    cd "${WORK_DIR}"

    if ls DEM/*.dem.wgs84 1>/dev/null 2>&1; then
        log_info "DEM ready: $(ls DEM/*.dem.wgs84)"
    else
        log_error "DEM not found. Aborting."
        return 1
    fi
}

# ==============================================================================
# PHASE 3: STACK CONFIGURATION
# ==============================================================================

phase_3_stack_config() {
    log_step "3" "Stack Configuration & Baselines"
    cd "${WORK_DIR}"

    local LOG=$(get_log_version "05_stack_config.log" "logs")
    local STACK_CMD="stackStripMap.py -W interferogram --nofocus \
        -s SLC -d DEM/${DEM_FILE} \
        -t ${TEMPORAL_BASELINE} -b ${PERP_BASELINE} \
        -a ${AZIMUTH_LOOKS} -r ${RANGE_LOOKS} -u ${UNWRAPPER}"

    if [ "$REF_DATE" != "auto" ]; then
        STACK_CMD="${STACK_CMD} -m ${REF_DATE}"
    fi

    log_substep "Running stackStripMap.py..."
    eval "${STACK_CMD}" 2>&1 | tee "${LOG}"
    check_status "Stack Config" $? "${LOG}" || return 1

    if [ "$REF_DATE" = "auto" ]; then
        log_warn "Review pairs.pdf to choose reference date."
        echo "  scp ${USER}@felix:${WORK_DIR}/pairs.pdf ."
        read -p "  Enter chosen reference date (YYYYMMDD): " REF_DATE
        if [ -n "$REF_DATE" ]; then
            eval "${STACK_CMD} -m ${REF_DATE}" 2>&1 | tee -a "${LOG}"
        fi
    fi

    log_info "Run files generated:"
    ls -1 run_files/
}

# ==============================================================================
# PHASE 4: ISCE2 PROCESSING
# ==============================================================================

phase_4_isce2() {
    log_step "4" "ISCE2 Processing Pipeline"
    cd "${WORK_DIR}"

    local steps=(
        "sh|run_01_reference|06_run01_reference.log"
        "sh|run_02_focus_split|07_run02_focus_split.log"
        "parallel|run_03_geo2rdr_coarseResamp|08_run03_geo2rdr.log"
        "parallel|run_04_refineSecondaryTiming|09_run04_refineSecondary.log"
    )

    local step_num=1
    for entry in "${steps[@]}"; do
        IFS='|' read -r method runfile logbase <<< "$entry"
        local LOG=$(get_log_version "${logbase}" "logs")
        log_substep "4.${step_num}: ${runfile}..."
        echo "Starting ${runfile}" | tee "${LOG}"
        if [ "$method" = "sh" ]; then
            sh "run_files/${runfile}" 2>&1 | tee -a "${LOG}"
        else
            parallel -j ${PARALLEL_JOBS} < "run_files/${runfile}" 2>&1 | tee -a "${LOG}"
        fi
        check_status "${runfile}" $? "${LOG}" || return 1
        step_num=$((step_num + 1))
    done

    # Cleanup
    log_substep "4.5: Post-step-04 cleanup..."
    local LOG=$(get_log_version "10_cleanup.log" "logs")
    poststep04_cleanup.py 2>&1 | tee "${LOG}"

    local steps2=(
        "sh|run_05_invertMisreg|11_run05_invertMisreg.log"
        "parallel|run_06_fineResamp|12_run06_fineResamp.log"
        "sh|run_07_grid_baseline|13_run07_grid_baseline.log"
        "parallel|run_08_igram|14_run08_igram.log"
    )

    step_num=6
    for entry in "${steps2[@]}"; do
        IFS='|' read -r method runfile logbase <<< "$entry"
        local LOG=$(get_log_version "${logbase}" "logs")
        log_substep "4.${step_num}: ${runfile}..."
        echo "Starting ${runfile}" | tee "${LOG}"
        if [ "$method" = "sh" ]; then
            sh "run_files/${runfile}" 2>&1 | tee -a "${LOG}"
        else
            if [ "$runfile" = "run_08_igram" ]; then
                log_warn "Longest step. Consider screen/tmux."
            fi
            parallel -j ${PARALLEL_JOBS} < "run_files/${runfile}" 2>&1 | tee -a "${LOG}"
        fi
        check_status "${runfile}" $? "${LOG}" || return 1
        step_num=$((step_num + 1))
    done

    log_info "ISCE2 processing complete."
}

# ==============================================================================
# PHASE 4.5: INTERFEROGRAM VISUALIZATION (LOCAL MACHINE ONLY)
# ==============================================================================

phase_4_5_igram_viz() {
    log_step "4.5" "Interferogram Visualization (LOCAL)"

    echo -e "${YELLOW}${BOLD}"
    echo "  This phase runs on your LOCAL machine (not felix)."
    echo "  It requires: conda activate isce2_local (or equivalent)"
    echo "  Scripts needed: linog_save_insar_images.py, linog_create_grid.py"
    echo -e "${NC}"
    echo ""
    echo "  Step 1: On your LOCAL machine, create the Igrams directory:"
    echo "    mkdir -p ~/LInOG/insar/${PADDED_PATH}/${PADDED_FRAME}/Igrams/logs"
    echo "    cd ~/LInOG/insar/${PADDED_PATH}/${PADDED_FRAME}/Igrams"
    echo ""
    echo "  Step 2: Rsync filtered interferograms from felix:"
    echo "    rsync -avh --progress \\"
    echo "      \"${USER}@felix:${WORK_DIR}/interferograms/*/filt*.int*\" . \\"
    echo "      2>&1 | tee logs/fetch_igrams.log.v1"
    echo ""
    echo "  Step 3: Generate individual phase + combined images:"
    echo "    conda activate isce2_local"
    # FIX B4: was "python save_insar_images.py" — missing linog_ prefix
    echo "    python linog_save_insar_images.py 2>&1 | tee logs/01_save_images.log.v1"
    echo ""
    echo "  Step 4: Generate interferogram report grid pages:"
    # FIX B4: was "python create_grid.py" — missing linog_ prefix
    echo "    python linog_create_grid.py --path ${INPUT_PATH} --frame ${INPUT_FRAME} \\"
    echo "      2>&1 | tee logs/02_report_grid.log.v1"
    echo ""
    echo "  Step 5: Review the report pages. Identify bad dates to exclude."
    echo "    Output: ${FRAME_TAG}_Igram_Report_Page_*.jpg"
    echo ""
    echo "  Step 6: Upload report pages to the delivery folder:"
    echo "    scp ${FRAME_TAG}_Igram_Report_Page_*.jpg \\"
    echo "      ${USER}@felix:${WORK_DIR}/mintpy/geo/LInOG_Upload_${FRAME_TAG}/"
    echo ""

    read -p "  Press Enter when local visualization is done (or 's' to skip)... " SKIP
    if [[ "$SKIP" == "s" ]]; then
        log_warn "Skipped interferogram visualization."
    else
        log_info "Interferogram visualization completed by user."
    fi
}

# ==============================================================================
# PHASE 5: MINTPY TIME-SERIES
# ==============================================================================

phase_5_mintpy() {
    log_step "5" "MintPy Time-Series Analysis"
    cd "${WORK_DIR}"

    log_substep "5.1: Generating MintPy config..."
    local CFG="${WORK_DIR}/mintpy/smallbaselineApp.cfg"

    cat > "${CFG}" << CFGEOF
##----- MintPy Config for ${FRAME_TAG} -----##
##----- Generated by linog_fbs_processor v${SCRIPT_VERSION} -----##
##----- $(date) -----##

mintpy.load.processor      = isce
# FIX B2: IW1.xml is Sentinel-1/TOPS-specific; stripmapStack produces SLC XMLs.
# Wildcard matches whatever XML stripmapStack writes into reference/.
mintpy.load.metaFile       = ${WORK_DIR}/reference/*.xml
mintpy.load.baselineDir    = ${WORK_DIR}/baselines

# FIX B3: filt_fine.* is topsStack naming. stripmapStack uses date-pair names.
# Wildcards match e.g. filt_20091111_20100127.unw
mintpy.load.unwFile        = ${WORK_DIR}/interferograms/*/filt_*.unw
mintpy.load.corFile        = ${WORK_DIR}/interferograms/*/filt_*.cor
mintpy.load.connCompFile   = ${WORK_DIR}/interferograms/*/filt_*.unw.conncomp

mintpy.load.demFile        = ${WORK_DIR}/merged/geom_reference/hgt.rdr
mintpy.load.incAngleFile   = ${WORK_DIR}/merged/geom_reference/los.rdr
mintpy.load.azAngleFile    = ${WORK_DIR}/merged/geom_reference/los.rdr
mintpy.load.shadowMaskFile = ${WORK_DIR}/merged/geom_reference/shadowMask.rdr
mintpy.load.waterMaskFile  = ${WORK_DIR}/merged/geom_reference/waterMask.rdr

mintpy.network.coherenceBased  = yes
mintpy.network.minCoherence    = ${COHERENCE_THRESHOLD}

mintpy.troposphericDelay.method = no
mintpy.deramp                   = no
mintpy.topographicResidual      = yes
mintpy.geocode                 = yes
mintpy.reference.lalo          = auto
CFGEOF

    log_substep "5.2: Running smallbaselineApp.py..."
    cd "${WORK_DIR}/mintpy"
    local LOG=$(get_log_version "15_mintpy.log" "${WORK_DIR}/logs")
    smallbaselineApp.py smallbaselineApp.cfg 2>&1 | tee "${LOG}"
    check_status "MintPy" $? "${LOG}" || return 1
    cd "${WORK_DIR}"
}

# ==============================================================================
# PHASE 6: GEOCODED DELIVERABLES
# ==============================================================================

phase_6_deliverables() {
    log_step "6" "Geocoded Deliverables"
    cd "${WORK_DIR}/mintpy"

    local OUT="geo/LInOG_Upload_${FRAME_TAG}"
    local MASK="geo/geo_maskTempCoh.h5"
    local GEOM="geo/geo_geometryRadar.h5"
    mkdir -p "${OUT}"

    local LOG=$(get_log_version "16_deliverables.log" "${WORK_DIR}/logs")

    # =============================================
    # Process BOTH correction types: demErr, demErr_ramp
    # =============================================
    local CORRECTIONS=("demErr" "demErr_ramp")
    local VEL_FILES=("geo/geo_velocity_demErr.h5" "geo/geo_velocity_demErr_ramp.h5")
    local TS_FILES=("geo/geo_timeseries_demErr.h5" "geo/geo_timeseries_ramp_demErr.h5")

    for idx in 0 1; do
        local CORR="${CORRECTIONS[$idx]}"
        local VEL="${VEL_FILES[$idx]}"
        local TS="${TS_FILES[$idx]}"

        if [ ! -f "${VEL}" ]; then
            log_warn "${VEL} not found. Skipping ${CORR} outputs."
            continue
        fi

        # Suffix for ramp files
        local SUFFIX=""
        [ "$CORR" = "demErr_ramp" ] && SUFFIX="_ramp"

        log_substep "--- Processing ${CORR} outputs ---"

        # 6.1: LOS Velocity Hillshade
        log_substep "LOS velocity hillshade (${CORR})..."
        view.py "${VEL}" velocity --mask ${MASK} -d ${GEOM} \
            -v -10 10 --shade-exag 0.05 --nodisplay --save \
            -o "${OUT}/${FRAME_TAG}_Velocity_Hillshade_demErr${SUFFIX}.png" --dpi 600 \
            2>&1 | tee -a "${LOG}"

        # 6.2: Vertical & Horizontal Projections
        log_substep "Computing V/H projections (${CORR})..."

        export FRAME_TAG VEL CORR SUFFIX OUT
        python3 << 'PYEOF'
import h5py, numpy as np, os

vel_file = os.environ['VEL']
corr = os.environ['CORR']
suffix = os.environ['SUFFIX']
out_dir = os.environ['OUT']
frame_tag = os.environ['FRAME_TAG']

geom_file = 'geo/geo_geometryRadar.h5'

with h5py.File(vel_file, 'r') as f_vel, h5py.File(geom_file, 'r') as f_geo:
    vel = f_vel['velocity'][:]
    inc = np.deg2rad(f_geo['incidenceAngle'][:])

    # Pepe & Calo (2017), Eq. 43
    v_vert = vel / np.cos(inc)
    v_horz = vel / np.sin(inc)

    for name, data, desc in [
        ('vertical', v_vert, 'Vertical Projection (V_LOS / cos(inc))'),
        ('horizontal', v_horz, 'Horizontal EW Projection (V_LOS / sin(inc))')]:
        outf = f'geo/geo_velocity_{name}{suffix}.h5'
        with h5py.File(outf, 'w') as f_out:
            f_out.create_dataset('velocity', data=data, compression='gzip')
            for k, v in f_vel.attrs.items():
                f_out.attrs[k] = v
            f_out.attrs['DESCRIPTION'] = f'{desc} [{corr}] - assumes zero orthogonal motion'
        print(f"  Saved: {outf}")
PYEOF

        # Hillshade PNGs for V/H
        log_substep "Vertical hillshade (${CORR})..."
        view.py "geo/geo_velocity_vertical${SUFFIX}.h5" velocity --mask ${MASK} -d ${GEOM} \
            -v -10 10 --shade-exag 0.05 --nodisplay --save \
            -o "${OUT}/${FRAME_TAG}_Velocity_Hillshade_Vertical${SUFFIX}.png" --dpi 600 \
            2>&1 | tee -a "${LOG}"

        log_substep "Horizontal hillshade (${CORR})..."
        view.py "geo/geo_velocity_horizontal${SUFFIX}.h5" velocity --mask ${MASK} -d ${GEOM} \
            -v -10 10 --shade-exag 0.05 --nodisplay --save \
            -o "${OUT}/${FRAME_TAG}_Velocity_Hillshade_Horizontal${SUFFIX}.png" --dpi 600 \
            2>&1 | tee -a "${LOG}"

        # 6.3: GeoTIFF exports
        log_substep "GeoTIFFs (${CORR})..."
        save_gdal.py "${VEL}" \
            -o "${OUT}/${FRAME_TAG}_Velocity_demErr${SUFFIX}.tif" 2>&1 | tee -a "${LOG}"
        save_gdal.py "geo/geo_velocity_vertical${SUFFIX}.h5" \
            -o "${OUT}/${FRAME_TAG}_Velocity_Vertical${SUFFIX}.tif" 2>&1 | tee -a "${LOG}"
        save_gdal.py "geo/geo_velocity_horizontal${SUFFIX}.h5" \
            -o "${OUT}/${FRAME_TAG}_Velocity_Horizontal${SUFFIX}.tif" 2>&1 | tee -a "${LOG}"

        # 6.4: KMZ exports (standard)
        log_substep "KMZ (${CORR})..."
        save_kmz.py "${VEL}" \
            -o "${OUT}/${FRAME_TAG}_Velocity_demErr${SUFFIX}.kmz" 2>&1 | tee -a "${LOG}"

        # 6.5: Interactive KMZ (time-series with chart + table)
        log_substep "Interactive KMZ (${CORR})..."
        if [ -f "${TS}" ]; then
            python3 ~/bin/linog_gen_interactive_kmz.py \
                --path "${INPUT_PATH}" --frame "${INPUT_FRAME}" \
                --correction "${CORR}" \
                --frame-dir "${WORK_DIR}" \
                2>&1 | tee -a "${LOG}"
        else
            log_warn "Time-series file ${TS} not found. Skipping interactive KMZ."
        fi
    done

    log_info "All deliverables in: ${OUT}/"
    ls -1 "${OUT}/" 2>/dev/null
    cd "${WORK_DIR}"
}

# ==============================================================================
# PHASE 7: SUMMARY & CHECKLIST
# ==============================================================================

phase_7_summary() {
    log_step "7" "Processing Summary"
    cd "${WORK_DIR}"

    local OUT="${WORK_DIR}/mintpy/geo/LInOG_Upload_${FRAME_TAG}"

    echo ""
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║     ${FRAME_TAG} PROCESSING COMPLETE          ║"
    echo "  ╚═══════════════════════════════════════════════╝"
    echo ""

    # demErr deliverables
    local DEMRR_ITEMS=(
        "${FRAME_TAG}_Velocity_Hillshade_demErr.png"
        "${FRAME_TAG}_Velocity_Hillshade_Vertical.png"
        "${FRAME_TAG}_Velocity_Hillshade_Horizontal.png"
        "${FRAME_TAG}_Velocity_demErr.tif"
        "${FRAME_TAG}_Velocity_Vertical.tif"
        "${FRAME_TAG}_Velocity_Horizontal.tif"
        "${FRAME_TAG}_Velocity_demErr.kmz"
        "${FRAME_TAG}_TimeSeries_demErr.kmz"
    )

    # demErr_ramp deliverables
    local RAMP_ITEMS=(
        "${FRAME_TAG}_Velocity_Hillshade_demErr_ramp.png"
        "${FRAME_TAG}_Velocity_Hillshade_Vertical_ramp.png"
        "${FRAME_TAG}_Velocity_Hillshade_Horizontal_ramp.png"
        "${FRAME_TAG}_Velocity_demErr_ramp.tif"
        "${FRAME_TAG}_Velocity_Vertical_ramp.tif"
        "${FRAME_TAG}_Velocity_Horizontal_ramp.tif"
        "${FRAME_TAG}_Velocity_demErr_ramp.kmz"
        "${FRAME_TAG}_TimeSeries_demErr_ramp.kmz"
    )

    echo "  demErr Deliverables:"
    for item in "${DEMRR_ITEMS[@]}"; do
        if [ -f "${OUT}/${item}" ]; then
            echo -e "    ${GREEN}[OK]${NC}  ${item}"
        else
            echo -e "    ${RED}[--]${NC}  ${item}"
        fi
    done

    echo ""
    echo "  demErr_ramp Deliverables:"
    for item in "${RAMP_ITEMS[@]}"; do
        if [ -f "${OUT}/${item}" ]; then
            echo -e "    ${GREEN}[OK]${NC}  ${item}"
        else
            echo -e "    ${RED}[--]${NC}  ${item}"
        fi
    done

    # Igram report pages
    echo ""
    echo "  Interferogram Report Pages:"
    local IGRAM_COUNT=$(ls "${OUT}/${FRAME_TAG}_Igram_Report_Page_"*.jpg 2>/dev/null | wc -l)
    if [ "$IGRAM_COUNT" -gt 0 ]; then
        echo -e "    ${GREEN}[OK]${NC}  ${IGRAM_COUNT} report page(s) found"
    else
        echo -e "    ${RED}[--]${NC}  No report pages (run Phase 4.5 locally)"
    fi

    echo ""
    echo "  Output folder: ${OUT}/"
    echo ""
    echo "  Sync to local:"
    echo "    rsync -avP ${USER}@felix:${OUT}/ ./${FRAME_TAG}/"
    echo ""
    echo "Completed: $(date)" >> "${WORK_DIR}/logs/ERROR_SUMMARY.txt"
    log_info "Done."
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    print_banner
    get_user_inputs
    phase_0_setup
    phase_1_data_acquisition
    phase_2_dem
    phase_3_stack_config
    phase_4_isce2
    phase_4_5_igram_viz
    phase_5_mintpy
    phase_6_deliverables
    phase_7_summary
}

case "${1:-all}" in
    0|setup)      get_user_inputs; phase_0_setup ;;
    1|data)       get_user_inputs; phase_1_data_acquisition ;;
    2|dem)        get_user_inputs; phase_2_dem ;;
    3|stack)      get_user_inputs; phase_3_stack_config ;;
    4|isce2)      get_user_inputs; phase_4_isce2 ;;
    4.5|igram)    get_user_inputs; phase_4_5_igram_viz ;;
    5|mintpy)     get_user_inputs; phase_5_mintpy ;;
    6|deliver)    get_user_inputs; phase_6_deliverables ;;
    7|summary)    get_user_inputs; phase_7_summary ;;
    all)          main ;;
    *)
        echo "Usage: $0 [phase]"
        echo "  0=setup 1=data 2=dem 3=stack 4=isce2 4.5=igram"
        echo "  5=mintpy 6=deliver 7=summary all"
        exit 1 ;;
esac
