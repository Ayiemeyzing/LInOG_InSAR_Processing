# LInOG InSAR Processing Manual
## ALOS-1 PALSAR FBS Stack Processing
### ISCE2 + MintPy Automated Pipeline
**Version 2.2 — parameterized for reusable Path/Frame runs**

National Institute of Geological Sciences  
University of the Philippines Diliman  
*DOST-PCIEERD LInOG Project*  
April 2026

---

## Table of Contents

- [0. Read This First — Tutorial Roadmap](#0-read-this-first--tutorial-roadmap)
- [1. Pre-Flight: Local Environment Setup](#1-pre-flight-local-environment-setup)
- [2. Installing ISCE2 and MintPy](#2-installing-isce2-and-mintpy)
- [3. Prerequisites and Run Configuration](#3-prerequisites-and-run-configuration)
- [4. Directory Organization and Naming Conventions](#4-directory-organization-and-naming-conventions)
- [5. Phase 0: Workspace Initialization](#5-phase-0-workspace-initialization)
- [6. Phase 1: Data Acquisition](#6-phase-1-data-acquisition)
- [7. Phase 2: DEM Preparation](#7-phase-2-dem-preparation-srtm-download)
- [8. Phase 3: Stack Configuration and Baselines](#8-phase-3-stack-configuration-and-baselines)
- [9. Phase 4: ISCE2 Processing Pipeline](#9-phase-4-isce2-processing-pipeline)
- [10. Phase 4.5: Interferogram Visualization (Local)](#10-phase-45-interferogram-visualization-local-machine)
- [11. Phase 5: MintPy Time-Series Analysis](#11-phase-5-mintpy-time-series-analysis)
- [12. Phase 6: Geocoded Deliverables](#12-phase-6-geocoded-deliverables)
- [13. Phase 7: Quality Control and Checklist](#13-phase-7-quality-control-and-checklist)
- [14. Script Reference](#14-script-reference)
- [15. Deliverables Checklist](#15-deliverables-checklist)
- [16. Troubleshooting: Pre-Flight and Installation](#16-troubleshooting-pre-flight-and-installation)
- [17. Troubleshooting: Processing Pipeline](#17-troubleshooting-processing-pipeline)
- [18. Scientific References](#18-scientific-references)

---

## 0. Read This First — Tutorial Roadmap

This manual supports InSAR time-series processing using ISCE2 and MintPy. It serves two audiences: users learning the pipeline locally, and analysts running production jobs on the felix server at NIGS.

### 0.1 Who This Manual Is For

Users in geology, remote sensing, and related fields. No prior Linux or InSAR experience is assumed, but you should be comfortable following step-by-step instructions carefully. A single missed step can break later phases.

### 0.2 Two Processing Environments

```text
LOCAL (your laptop)      → Learning, visualization, small test runs
FELIX (NIGS server)      → Production runs, full-frame processing
```

Throughout this manual, any instruction that differs between environments is clearly marked with a `[LOCAL]` or `[FELIX]` label.

### 0.3 Before the Tutorial — Required Pre-Work

All users must complete Section 1 (Pre-Flight) before the tutorial session. This includes installing WSL2 (Windows) or Miniforge (macOS/Linux), configuring the terminal, and running the verification script. Expected time: 60–90 minutes with reliable internet.

> **IMPORTANT**  
> If you arrive at the tutorial without completing Section 1, you will not be able to follow along. The tutorial begins at Section 2 (ISCE2 install) and assumes your local environment is ready. If you hit errors during pre-work, consult Section 16 (Troubleshooting) or message the instructor 24 hours before the session.

### 0.4 What You Will Build

By the end of the full tutorial and first processing run, you will have:

- A working ISCE2 + MintPy environment on your laptop, for visualization and learning
- Access to the same environment on felix, for real processing
- One processed frame of ALOS-1 PALSAR FBS data
- Geocoded velocity maps, interactive KMZs, and interferogram QC reports

---

## 1. Pre-Flight: Local Environment Setup

Complete every subsection in order. Do not skip ahead. The verification script in Section 1.6 will confirm whether your setup is correct.

### 1.1 Vim Survival Guide

This manual uses vim as the default text editor because it is available on every Linux system, including felix. If you have never used vim before, read this section carefully. Vim behaves differently from Notepad or TextEdit — you cannot just type into a file.

| Action | Command |
|--------|---------|
| Open a file | `vim filename` |
| Start typing | press `i` |
| Stop typing | press `Esc` |
| Save and quit | `:wq` |
| Quit without saving | `:q!` |
| Stuck? | press `Esc` a few times, then try `:q!` |

The two modes you will use are NORMAL mode and INSERT mode. The `i` key enters insert mode; `Esc` returns to normal mode.

> **WARNING**  
> Do not close your terminal while vim is open with unsaved changes. If you do, vim creates a swap file (`.swp`) that can confuse you the next time you open the file.

### 1.2 Option A — Windows: Install WSL2 + Ubuntu 22.04 LTS

Skip this section if you are on macOS or native Linux.

#### 1.2.1 Check Windows Version

WSL2 requires Windows 10 version 2004+ (build 19041+) or Windows 11. Press `Win+R`, type `winver`, and press Enter. If your version is older, update Windows first.

#### 1.2.2 Enable Virtualization

Restart your computer and enter BIOS/UEFI. Find the virtualization setting — typically VT-x (Intel) or AMD-V — and enable it. Without virtualization enabled, WSL2 will not work and you may see error `0x80370102`.

#### 1.2.3 Install WSL2 with Ubuntu 22.04

Open PowerShell as Administrator and run:

```powershell
wsl --install -d Ubuntu-22.04
```

If needed:

```powershell
wsl --set-default-version 2
wsl --install -d Ubuntu-22.04
```

After installation, restart your computer. On first launch, Ubuntu will ask for a username and password.

> **IMPORTANT**  
> We pin Ubuntu 22.04 to match the tested ISCE2 environment. If you installed a different version:
> ```powershell
> wsl --unregister <DistroName>
> ```
> then reinstall Ubuntu 22.04.

#### 1.2.4 Update Ubuntu

```bash
sudo apt update && sudo apt upgrade -y
```

#### 1.2.5 Install Miniforge

```bash
cd ~
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
```

Then restart your terminal or run:

```bash
source ~/.bashrc
```

### 1.3 Option B — macOS: Install Miniforge

Skip this section if you are on Windows or native Linux.

> **APPLE SILICON WARNING**  
> ISCE2 is not officially distributed for `osx-arm64` via conda-forge. The simplest tutorial path is to use felix for processing and optionally skip local install.

#### 1.3.1 Install Command Line Tools

```bash
xcode-select --install
```

#### 1.3.2 Install Miniforge

For Intel Macs:

```bash
cd ~
curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh
bash Miniforge3-MacOSX-x86_64.sh
```

For Apple Silicon using Rosetta:

```bash
arch -x86_64 /bin/bash
cd ~
curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh
bash Miniforge3-MacOSX-x86_64.sh
```

### 1.4 Option C — Native Linux: Install Miniforge

```bash
cd ~
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
```

### 1.5 Install Git and Build Essentials

**[LOCAL Ubuntu / WSL2]**
```bash
sudo apt install -y git build-essential vim curl
```

**[macOS]**
```bash
brew install vim
```

**[FELIX]** already installed.

Verify git:

```bash
git --version
```

### 1.6 Run the Verification Script

Create and run the pre-flight script:

```bash
cd ~
vim check_preflight.sh
```

Paste the script from `scripts/check_preflight.sh` in this repository, then:

```bash
chmod +x check_preflight.sh
./check_preflight.sh
```

Every line should print `[OK]`.

---

## 2. Installing ISCE2 and MintPy

This section has two installation paths.

| Path | Where | When to use |
|------|-------|-------------|
| Path A | Your local machine | Learning, visualization, small test runs |
| Path B | felix server | Production runs, full-frame processing |

### 2.1 Path A — Local Install (WSL/Linux/macOS)

#### 2.1.1 Clone the ISCE2 Source Tree

```bash
mkdir -p ~/tools/src && cd ~/tools/src
git clone https://github.com/isce-framework/isce2.git
```

Verify:

```bash
ls ~/tools/src/isce2/contrib/stack/
```

#### 2.1.2 Create the isce2 conda environment

```bash
conda create -n isce2 python=3.12 -y
conda activate isce2
conda install -c conda-forge isce2 -y
```

> **NOTE**  
> ISCE2 on conda-forge supports Python 3.9 through 3.12. We pin 3.12 to match felix.

#### 2.1.3 Copy Stack Processor Files into the Environment

```bash
mkdir -p $CONDA_PREFIX/share/isce2
cp -R ~/tools/src/isce2/contrib/stack/* $CONDA_PREFIX/share/isce2
```

### 2.2 Path B — felix Server Install

#### 2.2.1 Source the Group Conda Installation

```bash
source /opt/miniforge3/bin/activate
```

#### 2.2.2 Create the Environment

```bash
conda create -n isce2 python=3.12 -y
conda activate isce2
conda install -c conda-forge isce2 -y
```

#### 2.2.3 Copy Stack Processor Files

```bash
mkdir -p $CONDA_PREFIX/share/isce2
cp -R $HOME/tools/src/isce2/contrib/stack/* $CONDA_PREFIX/share/isce2
```

### 2.3 Create and Configure isce2.rc

```bash
cd ~
vim isce2.rc
```

Paste:

```bash
# isce2.rc for conda-forge installation
export ISCE_HOME=$CONDA_PREFIX/lib/python3.12/site-packages/isce
export ISCE_STACK=$CONDA_PREFIX/share/isce2
export PATH=$ISCE_HOME/bin:$ISCE_HOME/applications:$PATH
export LD_LIBRARY_PATH=$ISCE_HOME/lib:$LD_LIBRARY_PATH
export PYTHONPATH=$ISCE_HOME:$ISCE_HOME/applications:$ISCE_HOME/components:$ISCE_HOME/library:$ISCE_STACK:$PYTHONPATH

# import tops/stripmapStack as python modules
export PYTHONPATH=${PYTHONPATH}:${ISCE_STACK}

# add stack processors to PATH
export PATH=${PATH}:${ISCE_STACK}/stripmapStack

# set number of threads
export OMP_NUM_THREADS=8
```

### 2.3.1 Add a Loader Alias

```bash
vim ~/.bash_aliases
```

Paste:

```bash
load_isce () {
    source ~/miniforge3/bin/activate          # [LOCAL]
    # source /opt/miniforge3/bin/activate     # [FELIX]
    conda activate isce2
    source ~/isce2.rc
}
```

### 2.3.2 Load the Alias

```bash
source ~/.bash_aliases
grep .bash_aliases ~/.bashrc
```

If needed:

```bash
echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> ~/.bashrc
source ~/.bashrc
```

### 2.3.3 Test the Loader

```bash
load_isce
which topsApp.py
python -c 'import isce; print(isce.__file__)'
```

### 2.4 Install MintPy

```bash
load_isce
conda install -c conda-forge mintpy -y
```

Verify:

```bash
smallbaselineApp.py --help | head
```

### 2.5 Install isce2_local (Visualization Environment for Phase 4.5)

**LOCAL ONLY**

```bash
conda create -n isce2_local python=3.12 -y
conda activate isce2_local
conda install -c conda-forge isce2 numpy matplotlib pillow -y
```

Verify:

```bash
python -c 'import isceobj, numpy, matplotlib; print("OK")'
```

---

## 3. Prerequisites and Run Configuration

Complete this once at the start of every frame run.

### 3.1 Required Access

| Requirement | Description |
|-------------|-------------|
| Server SSH | Login to felix |
| NASA EarthData | `urs.earthdata.nasa.gov` |
| ISCE2 env (felix) | `conda activate isce2` after `load_isce` |
| ISCE2 env (local) | `conda activate isce2_local` for Phase 4.5 |
| GNU Parallel | Pre-installed on felix |
| MintPy | Inside isce2 conda env |

### 3.2 Configure .netrc

```bash
cd ~
vim .netrc
```

Paste:

```text
machine urs.earthdata.nasa.gov
    login your_login
    password your_password
```

Then:

```bash
chmod 600 ~/.netrc
```

### 3.3 Setup ~/bin Scripts (felix only)

```bash
mkdir -p ~/bin
cp /eggraid/sbin/*.py ~/bin/
cp /eggraid/sbin/*.sh ~/bin/
chmod +x ~/bin/*
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3.4 Define Run Variables

This manual is parameterized so users only edit Path/Frame once.

#### 3.4.1 Choose Your Frame

Example:
- Path = `448`
- Frame = `0290`

#### 3.4.2 Set the Variables

**[FELIX]**
```bash
export PATH_NUM=448
export FRAME_NUM=0290

export PADDED_PATH=p${PATH_NUM}
export PADDED_FRAME=f${FRAME_NUM}
export FRAME_TAG=P${PATH_NUM}F${FRAME_NUM}

export BASE_DIR=/eggraid/home/$USER/projects/linog/insar
export WORK_DIR=${BASE_DIR}/${PADDED_PATH}/${PADDED_FRAME}
```

**[LOCAL]**
```bash
export PATH_NUM=448
export FRAME_NUM=0290

export PADDED_PATH=p${PATH_NUM}
export PADDED_FRAME=f${FRAME_NUM}
export FRAME_TAG=P${PATH_NUM}F${FRAME_NUM}

export BASE_DIR=$HOME/LInOG/insar
export WORK_DIR=${BASE_DIR}/${PADDED_PATH}/${PADDED_FRAME}
```

#### 3.4.3 Validate the Formats

- `PATH_NUM` must be **3 digits**
- `FRAME_NUM` must be **4 digits**
- Resulting names become:
  - `${PADDED_PATH}` → `p448`
  - `${PADDED_FRAME}` → `f0290`
  - `${FRAME_TAG}` → `P448F0290`

Check:

```bash
echo $PATH_NUM
echo $FRAME_NUM
echo $PADDED_PATH
echo $PADDED_FRAME
echo $FRAME_TAG
echo $WORK_DIR
```

---

## 4. Directory Organization and Naming Conventions

### 4.1 Per-Frame Structure

```text
${PADDED_PATH}/${PADDED_FRAME}/
  raw/             <- Symlinked ALOS zips
  data -> raw      <- Symlink for unzip script
  unzipped/        <- Extracted FBS acquisitions
  SLC/             <- ISCE2 SLC format
  DEM/             <- SRTM DEM
  run_files/       <- ISCE2 run scripts
  interferograms/  <- ISCE2 output pairs
  logs/            <- Versioned logs
  Igrams/          <- Local interferogram visualization
  mintpy/
    geo/
      LInOG_Upload_${FRAME_TAG}/  <- All deliverables
```

### 4.2 Output Naming Convention

Pattern:

```text
P###F####_[DataType]_[Correction].ext
```

Examples:

| Example | Description |
|---------|-------------|
| `${FRAME_TAG}_Velocity_demErr.tif` | LOS velocity, DEM error corrected |
| `${FRAME_TAG}_Velocity_Vertical.tif` | Vertical projection |
| `${FRAME_TAG}_Velocity_Horizontal_ramp.tif` | Horizontal projection, ramp-corrected |
| `${FRAME_TAG}_Velocity_Hillshade_demErr.png` | LOS hillshade |
| `${FRAME_TAG}_TimeSeries_demErr.kmz` | Interactive KMZ |
| `${FRAME_TAG}_Igram_Report_Page_1.jpg` | Interferogram report |

### 4.3 Log Naming

Pattern:

```text
##_[step_name].log.v#
```

### 4.4 Script Naming

All custom LInOG scripts use the `linog_` prefix.

---

## 5. Phase 0: Workspace Initialization

After defining your variables in Section 3.4:

```bash
cd "$BASE_DIR"
mkdir -p "${WORK_DIR}"/{raw,unzipped,SLC,DEM,logs,mintpy/inputs,interferograms,run_files,Igrams/logs}
mkdir -p "${WORK_DIR}/mintpy/geo/LInOG_Upload_${FRAME_TAG}"
cd "$WORK_DIR"
```

Check:

```bash
pwd
ls
```

---

## 6. Phase 1: Data Acquisition

### 6.1 Find and Symlink

```bash
cd "$WORK_DIR"

find_alos.sh "$PATH_NUM" "$FRAME_NUM" /eggraid/data/alos raw/ 2>&1 | tee logs/01_find_alos.log.v1

mv raw/${PATH_NUM}/${FRAME_NUM}/data/*.zip raw/
rm -rf raw/${PATH_NUM}/

ln -s raw data 2>&1 | tee -a logs/01_find_alos.log.v1
```

> **TIP**  
> A symlink is like a shortcut. Instead of copying large SAR zip files, you create pointers to where the originals live on the server.

### 6.2 Unzip FBS Only

```bash
python ~/bin/unzip_ALOS-SLC-pol.py --pol FBS 2>&1 | tee logs/02_unzip_fbs.log.v1
```

> **WARNING**  
> Do not use the `--dir` flag. The script reads from the `data/` symlink automatically.

### 6.3 Unpack to SLC

```bash
run_unpack_all_cli.py 2>&1 | tee logs/03_unpack_all.log.v1
ls SLC/ | wc -l
```

---

## 7. Phase 2: DEM Preparation (SRTM Download)

```bash
mkdir -p DEM && cd DEM
dem.py -a stitch -b 14 18 120 123 -r -s 1 -c \
    -u http://step.esa.int/auxdata/dem/SRTMGL1/ \
    2>&1 | tee ../logs/04_dem.log.v1
rm demLat*.dem demLat*.dem.xml demLat*.dem.vrt
cd ..
```

| Flag | Meaning |
|------|---------|
| `-a stitch` | Download and stitch tiles |
| `-b 14 18 120 123` | Bounding box |
| `-r` | WGS84 reference |
| `-s 1` | 1 arc-second |
| `-c` | Curvature correction |
| `-u http://...` | ESA DEM server |

---

## 8. Phase 3: Stack Configuration and Baselines

```bash
stackStripMap.py -W interferogram --nofocus \
  -s SLC -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
  -t 730 -b 1500 -a 28 -r 12 -u snaphu \
  2>&1 | tee logs/05_stack_config.log.v1
```

Review `pairs.pdf`, then re-run with your chosen reference date:

```bash
stackStripMap.py -W interferogram --nofocus \
  -s SLC -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
  -t 730 -b 1500 -a 28 -r 12 -u snaphu -m 20091111 \
  2>&1 | tee -a logs/05_stack_config.log.v1
```

> **TIP**  
> `20091111` is confirmed optimal for Frame `0310`. Other frames must be reviewed independently.

---

## 9. Phase 4: ISCE2 Processing Pipeline

| Run File | Method | Est. Time |
|----------|--------|-----------|
| `run_01_reference` | `sh` | ~10 min |
| `run_02_focus_split` | `sh` | ~10 min |
| `run_03_geo2rdr_coarseResamp` | `parallel -j4` | ~30 min |
| `run_04_refineSecondaryTiming` | `parallel -j4` | ~30 min |
| `poststep04_cleanup.py` | `python` | ~2 min |
| `run_05_invertMisreg` | `sh` | ~5 min |
| `run_06_fineResamp` | `parallel -j4` | ~20 min |
| `run_07_grid_baseline` | `sh` | ~5 min |
| `run_08_igram` | `parallel -j4` | 1–4+ hours |

### 9.1 Complete Command Sequence

```bash
echo "Starting run_01" | tee logs/06_run01.log.v1
sh run_files/run_01_reference 2>&1 | tee -a logs/06_run01.log.v1

echo "Starting run_02" | tee logs/07_run02.log.v1
sh run_files/run_02_focus_split 2>&1 | tee -a logs/07_run02.log.v1

echo "Starting run_03" | tee logs/08_run03.log.v1
parallel -j 4 < run_files/run_03_geo2rdr_coarseResamp 2>&1 | tee -a logs/08_run03.log.v1

echo "Starting run_04" | tee logs/09_run04.log.v1
parallel -j 4 < run_files/run_04_refineSecondaryTiming 2>&1 | tee -a logs/09_run04.log.v1

poststep04_cleanup.py 2>&1 | tee logs/10_cleanup.log.v1

echo "Starting run_05" | tee logs/11_run05.log.v1
sh run_files/run_05_invertMisreg 2>&1 | tee -a logs/11_run05.log.v1

echo "Starting run_06" | tee logs/12_run06.log.v1
parallel -j 4 < run_files/run_06_fineResamp 2>&1 | tee -a logs/12_run06.log.v1

echo "Starting run_07" | tee logs/13_run07.log.v1
sh run_files/run_07_grid_baseline 2>&1 | tee -a logs/13_run07.log.v1

echo "Starting run_08" | tee logs/14_run08.log.v1
parallel -j 4 < run_files/run_08_igram 2>&1 | tee -a logs/14_run08.log.v1
```

> **WARNING**  
> `run_08` is the longest step. Run it inside `screen` or `tmux` so the job survives disconnection.

---

## 10. Phase 4.5: Interferogram Visualization (Local Machine)

This phase runs on your **LOCAL** machine using the `isce2_local` environment from Section 2.5.

### 10.1 Prerequisites

- Conda environment: `isce2_local`
- Scripts:
  - `linog_save_insar_images.py`
  - `linog_create_grid.py`

### 10.2 Steps

First define the LOCAL run variables:

```bash
export PATH_NUM=448
export FRAME_NUM=0290
export PADDED_PATH=p${PATH_NUM}
export PADDED_FRAME=f${FRAME_NUM}
export FRAME_TAG=P${PATH_NUM}F${FRAME_NUM}
export BASE_DIR=$HOME/LInOG/insar
export WORK_DIR=${BASE_DIR}/${PADDED_PATH}/${PADDED_FRAME}
```

Then:

```bash
mkdir -p "${WORK_DIR}/Igrams/logs"
cd "${WORK_DIR}/Igrams"

rsync -avh --progress \
  "${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED_PATH}/${PADDED_FRAME}/interferograms/*/filt*.int*" . \
  2>&1 | tee logs/fetch_igrams.log.v1

conda activate isce2_local

python linog_save_insar_images.py 2>&1 | tee logs/01_save_images.log.v1
python linog_create_grid.py --path "$PATH_NUM" --frame "$FRAME_NUM" 2>&1 | tee logs/02_report_grid.log.v1
```

### 10.3 Review and Upload

```bash
scp ${FRAME_TAG}_Igram_Report_Page_*.jpg \
  ${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED_PATH}/${PADDED_FRAME}/mintpy/geo/LInOG_Upload_${FRAME_TAG}/
```

---

## 11. Phase 5: MintPy Time-Series Analysis

```bash
cd "${WORK_DIR}/mintpy"
smallbaselineApp.py smallbaselineApp.cfg 2>&1 | tee ../logs/15_mintpy.log.v1
```

Expected outputs include:

- `geo_velocity_demErr.h5`
- `geo_velocity_demErr_ramp.h5`
- `geo_timeseries_demErr.h5`
- `geo_timeseries_ramp_demErr.h5`

---

## 12. Phase 6: Geocoded Deliverables

All outputs go into one folder:

```text
geo/LInOG_Upload_${FRAME_TAG}/
```

### 12.1 Velocity Hillshade PNGs

```bash
cd "${WORK_DIR}/mintpy"

MASK=geo/geo_maskTempCoh.h5
GEOM=geo/geo_geometryRadar.h5
OUT=geo/LInOG_Upload_${FRAME_TAG}

view.py geo/geo_velocity_demErr.h5 velocity --mask $MASK -d $GEOM \
    -v -10 10 --shade-exag 0.05 --nodisplay --save \
    -o $OUT/${FRAME_TAG}_Velocity_Hillshade_demErr.png --dpi 600

view.py geo/geo_velocity_demErr_ramp.h5 velocity --mask $MASK -d $GEOM \
    -v -10 10 --shade-exag 0.05 --nodisplay --save \
    -o $OUT/${FRAME_TAG}_Velocity_Hillshade_demErr_ramp.png --dpi 600
```

### 12.2 Vertical and Horizontal Projections

Computed twice:
- once from `geo_velocity_demErr.h5`
- once from `geo_velocity_demErr_ramp.h5`

```text
V_vert = V_LOS / cos(theta)
V_horz = V_LOS / sin(theta)
```

### 12.3 GeoTIFF and KMZ Exports

- GeoTIFFs via `save_gdal.py`
- Standard KMZ via `save_kmz.py`
- Interactive KMZ via `linog_gen_interactive_kmz.py`

### 12.4 Interactive KMZ

```bash
python ~/bin/linog_gen_interactive_kmz.py --path "$PATH_NUM" --frame "$FRAME_NUM" --correction demErr
python ~/bin/linog_gen_interactive_kmz.py --path "$PATH_NUM" --frame "$FRAME_NUM" --correction demErr_ramp
```

---

## 13. Phase 7: Quality Control and Checklist

The automation script prints a checklist. Verify all items show `[OK]`.

Sync deliverables to local:

```bash
rsync -avP ${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED_PATH}/${PADDED_FRAME}/mintpy/geo/LInOG_Upload_${FRAME_TAG}/ ./${FRAME_TAG}/
```

---

## 14. Script Reference

| Script | Purpose | Location |
|--------|---------|----------|
| `linog_fbs_processor.sh` | Master automation for all phases | `~/bin/` on felix |
| `linog_save_insar_images.py` | Phase/combined JPG from `.int` files | local `~/bin/` |
| `linog_create_grid.py` | Interferogram report pages | local `~/bin/` |
| `linog_gen_interactive_kmz.py` | Interactive KMZ with charts | `~/bin/` on felix |

Repository copies are in `scripts/`.

### 14.1 linog_fbs_processor.sh usage

```bash
./linog_fbs_processor.sh
./linog_fbs_processor.sh 4
./linog_fbs_processor.sh 4.5
./linog_fbs_processor.sh 6
```

### 14.2 linog_create_grid.py usage

```bash
python linog_create_grid.py --path "$PATH_NUM" --frame "$FRAME_NUM"
```

### 14.3 linog_gen_interactive_kmz.py usage

```bash
python linog_gen_interactive_kmz.py --path "$PATH_NUM" --frame "$FRAME_NUM" --correction demErr
python linog_gen_interactive_kmz.py --batch
```

---

## 15. Deliverables Checklist

All files should be in:

```text
LInOG_Upload_${FRAME_TAG}/
```

### 15.1 demErr Correction

| File | Type |
|------|------|
| `${FRAME_TAG}_Velocity_Hillshade_demErr.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_Hillshade_Vertical.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_Hillshade_Horizontal.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_demErr.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_Vertical.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_Horizontal.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_demErr.kmz` | Google Earth KMZ |
| `${FRAME_TAG}_TimeSeries_demErr.kmz` | Interactive KMZ |

### 15.2 demErr_ramp Correction

| File | Type |
|------|------|
| `${FRAME_TAG}_Velocity_Hillshade_demErr_ramp.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_Hillshade_Vertical_ramp.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_Hillshade_Horizontal_ramp.png` | Hillshade PNG |
| `${FRAME_TAG}_Velocity_demErr_ramp.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_Vertical_ramp.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_Horizontal_ramp.tif` | GeoTIFF |
| `${FRAME_TAG}_Velocity_demErr_ramp.kmz` | Google Earth KMZ |
| `${FRAME_TAG}_TimeSeries_demErr_ramp.kmz` | Interactive KMZ |

### 15.3 Interferogram QC

| File | Type |
|------|------|
| `${FRAME_TAG}_Igram_Report_Page_1.jpg` | Report grid |
| `${FRAME_TAG}_Igram_Report_Page_2.jpg` | Report grid |
| `${FRAME_TAG}_Igram_Report_Page_N.jpg` | Additional pages as needed |

**Total:** 16 velocity/KMZ files + N interferogram report pages per frame.

---

## 16. Troubleshooting: Pre-Flight and Installation

### 16.1 WSL2 Installation Errors

| Error | Fix |
|-------|-----|
| `0x80370102` | Enable virtualization |
| `0x8007019e` | Run `wsl --install` again, then restart |
| Wrong Ubuntu version | `wsl --unregister Ubuntu`, then reinstall 22.04 |
| No internet in WSL2 | Check VPN/firewall |
| `Could not resolve archive.ubuntu.com` | Fix DNS / `/etc/resolv.conf` |
| `conda: command not found` | Restart terminal or `source ~/.bashrc` |

### 16.2 macOS Installation Errors

| Error | Fix |
|-------|-----|
| `xcode-select: command not found` | Run Software Update |
| Miniforge blocked | Open with Terminal |
| `PackagesNotFoundError` | Use Rosetta or felix |
| `conda activate` fails | `conda init zsh` or `conda init bash` |

### 16.3 Conda Environment Errors

| Error | Fix |
|-------|-----|
| `ResolvePackageNotFound` | Check conda-forge channel |
| Solver hangs | Install/use mamba |
| `PackageNotFoundError: isce2` | Add `-c conda-forge` |
| `HTTP 000 CONNECTION FAILED` | Check network/proxy |
| `conda activate isce2` does nothing | Restart shell |

### 16.4 ISCE2 Runtime Errors

| Error | Fix |
|-------|-----|
| `No module named isce` | Run `load_isce` |
| `which topsApp.py` returns nothing | Check `isce2.rc` |
| Wrong Python version in `ISCE_HOME` | Edit `~/isce2.rc` |
| Stack scripts not found | Copy `contrib/stack` into `$CONDA_PREFIX/share/isce2` |
| Permission denied in `~/tools/src/isce2` | Use a writable directory |

### 16.5 MintPy Install Errors

| Error | Fix |
|-------|-----|
| GDAL undefined symbol | Recreate env using conda only |
| `smallbaselineApp.py: command not found` | Reload env |
| MintPy install hangs | Use `mamba install -c conda-forge mintpy` |

### 16.6 Verification Script Failures

| Failed check | Action |
|--------------|--------|
| conda is installed | Redo Miniforge install |
| conda-forge is default | Add conda-forge channel |
| git is installed | Redo Section 1.5 |
| vim is installed | Install vim |
| disk space | Clear space |

---

## 17. Troubleshooting: Processing Pipeline

| Error | Fix |
|-------|-----|
| `event not found` | Use single quotes |
| `unzip --dir unrecognized` | Use `data->raw` symlink |
| DEM 401 | Fix `~/.netrc` |
| parallel server slow | Reduce `-j` |
| `SLC/` empty | Re-run unzip; check `data/` symlink |
| MemoryError | Reduce jobs |
| Qt wayland warning | Usually harmless |
| `tee: No such file` | `mkdir -p logs` first |

---

## 18. Scientific References

Pepe, A., and Calo, F. (2017). *A Review of Interferometric Synthetic Aperture RADAR (InSAR) Multi-Track Approaches for the Retrieval of Earth's Surface Displacements.* Remote Sensing, 9(1), 16.

Sandwell, D. T., et al. (2008). *Accuracy and Resolution of ALOS Interferometry.* IEEE TGRS.

Werner, C., et al. (2007). *PALSAR Multi-mode Interferometric Processing.*

Yunjun, Z., Fattahi, H., and Amelung, F. (2019). *Small baseline InSAR time series analysis.* Computers and Geosciences, 133, 104331.

Reference resources:
- Lijun99 ISCE2 install guide
- ISCE-framework repository
- MintPy repository

---

## Notes on Verification and Assumptions

Some steps in this manual are environment-specific and should be verified on your actual deployment:

- `/eggraid/...` paths are felix-specific
- `find_alos.sh`, `run_unpack_all_cli.py`, and `poststep04_cleanup.py` are internal scripts
- Reference date choice must be reviewed per frame
- Exact `reference/*.xml` contents may vary by stripmapStack version

See `ERRATA.md` for audited script fixes and assumptions.

---

*— End of Document —*
