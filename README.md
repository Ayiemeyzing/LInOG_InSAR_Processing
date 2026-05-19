# LInOG InSAR Processing Manual
## ALOS-1 PALSAR FBS Stack Processing
### ISCE2 + MintPy Automated Pipeline
**Version 2.1 — with Pre-Flight Setup for Local WSL/Linux/macOS**

National Institute of Geological Sciences  
University of the Philippines Diliman  
*DOST-PCIEERD LInOG Project*  
April 2026

---

## Table of Contents

- [0. Read This First — Tutorial Roadmap](#0-read-this-first--tutorial-roadmap)
- [1. Pre-Flight: Local Environment Setup](#1-pre-flight-local-environment-setup)
- [2. Installing ISCE2 and MintPy](#2-installing-isce2-and-mintpy)
- [3. Prerequisites and Environment Setup](#3-prerequisites-and-environment-setup)
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

This manual supports InSAR time-series processing using ISCE2 and MintPy. It serves two audiences: students learning the pipeline locally, and analysts running production jobs on the felix server at NIGS.

### 0.1 Who This Manual Is For

Graduate students in geology, remote sensing, and related fields. No prior Linux or InSAR experience is assumed, but you should be comfortable following step-by-step instructions carefully. A single missed step can break later phases.

### 0.2 Two Processing Environments

```
LOCAL (your laptop)      → Learning, visualization, small test runs
FELIX (NIGS server)      → Production runs, full-frame processing
```

Throughout this manual, any instruction that differs between environments is clearly marked with a `[LOCAL]` or `[FELIX]` label.

### 0.3 Before the Tutorial — Required Pre-Work

All students must complete Section 1 (Pre-Flight) before the tutorial session. This includes installing WSL2 (Windows) or Miniforge (macOS/Linux), configuring the terminal, and running the verification script. Expected time: 60–90 minutes with reliable internet.

> **IMPORTANT**  
> If you arrive at the tutorial without completing Section 1, you will not be able to follow along. The tutorial begins at Section 2 (ISCE2 install) and assumes your local environment is ready. If you hit errors during pre-work, consult Section 16 (Troubleshooting) or message the instructor 24 hours before the session.

### 0.4 What You Will Build

By the end of the full tutorial and first processing run, you will have:

- A working ISCE2 + MintPy environment on your laptop (for visualization and learning)
- Access to the same environment on felix (for real processing)
- One processed frame of ALOS-1 PALSAR FBS data from Central Luzon
- Geocoded velocity maps, interactive KMZs, and interferogram QC reports

---

## 1. Pre-Flight: Local Environment Setup

Complete every subsection in order. Do not skip ahead. The verification script in Section 1.6 will confirm whether your setup is correct.

### 1.1 Vim Survival Guide

This manual uses vim as the default text editor because it is available on every Linux system, including felix. If you have never used vim before, read this section carefully. Vim behaves differently from Notepad or TextEdit — you cannot just type into a file.

| Action | Command |
|--------|---------|
| Open a file | `vim filename` |
| Start typing | press `i` (you'll see `-- INSERT --` at the bottom) |
| Stop typing | press `Esc` (the `-- INSERT --` disappears) |
| Save and quit | press `Esc`, then type `:wq`, then press Enter |
| Quit without saving | press `Esc`, then type `:q!`, then press Enter |
| Stuck? | press `Esc` a few times, then try `:q!` to force-quit |

The two modes you will use are NORMAL mode (for commands like save/quit) and INSERT mode (for typing text). The `i` key enters insert mode; `Esc` returns to normal mode. That is 90% of what you need.

> **WARNING**  
> Do not close your terminal while vim is open with unsaved changes. If you do, vim creates a swap file (`.swp`) that will confuse you the next time you open the file. If you see a 'swap file exists' message when opening a file, press `D` to delete the old swap file (only if you are sure no other session is editing it).

### 1.2 Option A — Windows: Install WSL2 + Ubuntu 22.04 LTS

Skip this section if you are on macOS or native Linux.

#### 1.2.1 Check Windows Version

WSL2 requires Windows 10 version 2004+ (build 19041+) or Windows 11. Press `Win+R`, type `winver`, and press Enter. If your version is older, update Windows first.

#### 1.2.2 Enable Virtualization

Restart your computer and enter BIOS/UEFI (usually F2, F10, or Del during boot). Find the virtualization setting — typically labeled VT-x (Intel) or AMD-V — and enable it. Save and exit. Without virtualization enabled, WSL2 will not work and you will see error `0x80370102`.

#### 1.2.3 Install WSL2 with Ubuntu 22.04

Open PowerShell as Administrator (right-click Start → Terminal (Admin) or Windows PowerShell (Admin)). Run:

```powershell
wsl --install -d Ubuntu-22.04
```

This installs the WSL2 engine and Ubuntu 22.04 LTS. If you already have WSL installed with a different distro, this command may fail — in that case run:

```powershell
wsl --set-default-version 2
wsl --install -d Ubuntu-22.04
```

After installation, restart your computer. On first launch, Ubuntu will ask for a username and password. Use lowercase letters and no spaces. The password prompt shows no characters as you type — this is normal.

> **IMPORTANT**  
> We pin Ubuntu 22.04 (not the default 'Ubuntu' which currently pulls 24.04) to match the tested ISCE2 environment. Version drift between students will cause the tutorial to diverge. If you accidentally installed a different version, uninstall it with:
> ```
> wsl --unregister <DistroName>
> ```
> and reinstall with the command above.

#### 1.2.4 Update Ubuntu

Inside your new Ubuntu terminal:

```bash
sudo apt update && sudo apt upgrade -y
```

This takes 5–15 minutes depending on internet speed. Enter your Ubuntu password when prompted.

#### 1.2.5 Install Miniforge (conda)

Miniforge is a minimal conda distribution preconfigured with conda-forge, which is required for ISCE2. Run these commands one at a time inside Ubuntu:

```bash
cd ~
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
```

During the installer:
- Press Enter to read the license, then Space until you reach the bottom
- Type `yes` to accept
- Press Enter to accept the default install path (`~/miniforge3`)
- When asked 'Do you wish to update your shell profile?' type `yes`

Close and reopen your Ubuntu terminal. You should now see `(base)` at the start of your prompt. If not, run:

```bash
source ~/.bashrc
```

### 1.3 Option B — macOS: Install Miniforge

Skip this section if you are on Windows or native Linux.

> **APPLE SILICON (M1/M2/M3) WARNING**  
> ISCE2 is NOT officially distributed for Apple Silicon (osx-arm64) via conda-forge. You have three options: (1) install the osx-64 build under Rosetta 2 — works but slower; (2) use homebrew or macports; (3) SSH to felix for all processing and skip local install. For a tutorial, option (3) is simplest. If you choose option (1), install `Miniforge-MacOSX-x86_64.sh` (NOT arm64) and run your terminal under Rosetta.

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

For Apple Silicon Macs willing to use Rosetta (recommended for ISCE2 compatibility):

```bash
arch -x86_64 /bin/bash
cd ~
curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh
bash Miniforge3-MacOSX-x86_64.sh
```

Follow the same installer prompts as in Section 1.2.5. Close and reopen your Terminal (or iTerm2). You should see `(base)` at your prompt.

### 1.4 Option C — Native Linux: Install Miniforge

Skip this section if you are on Windows or macOS. Tested on Ubuntu 22.04 and 24.04.

```bash
cd ~
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
```

Follow the installer prompts as in Section 1.2.5.

### 1.5 Install Git and Build Essentials

ISCE2 stack processor scripts come from the GitHub source tree, which we need to clone. Git may not be installed by default on a fresh system.

**[LOCAL Ubuntu / WSL2]:**
```bash
sudo apt install -y git build-essential vim curl
```

**[macOS]:** git and curl come with Command Line Tools installed in Section 1.3.1. Install vim explicitly:
```bash
brew install vim    # if you have homebrew; otherwise the system vim is fine
```

**[FELIX]:** already installed; skip this subsection.

Verify git:
```bash
git --version    # should print git 2.x.x or newer
```

### 1.6 Run the Verification Script

Before you close this setup session, run the verification script to confirm every component is in place. Create the file with vim:

```bash
cd ~
vim check_preflight.sh
```

Press `i` to enter insert mode, then paste the following script (also available as `scripts/check_preflight.sh` in this repository):

```bash
#!/bin/bash
# LInOG Pre-Flight Verification Script
echo '=== LInOG Pre-Flight Check ==='
echo

PASS=0; FAIL=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "[OK]   $1"; PASS=$((PASS+1))
  else
    echo "[FAIL] $1"; FAIL=$((FAIL+1))
  fi
}

# OS detection
UNAME=$(uname -s)
echo "OS: $UNAME"
if [ -f /etc/os-release ]; then
  . /etc/os-release; echo "Distro: $PRETTY_NAME"
fi
echo

check 'conda is installed'           'command -v conda'
check 'conda-forge is default'       "conda config --show channels | grep -q conda-forge"
check 'git is installed'             'command -v git'
check 'vim is installed'             'command -v vim'
check 'curl or wget is available'    'command -v curl || command -v wget'
check 'home directory is writable'   "[ -w $HOME ]"
check '~/.bashrc exists'             "[ -f $HOME/.bashrc ] || [ -f $HOME/.zshrc ]"

# Disk space check (need >10GB free for ISCE2 + MintPy + test data)
FREE_GB=$(df -BG $HOME | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$FREE_GB" -ge 10 ]; then
  echo "[OK]   disk space ($FREE_GB GB free in $HOME)"; PASS=$((PASS+1))
else
  echo "[FAIL] disk space ($FREE_GB GB free; need >=10GB)"; FAIL=$((FAIL+1))
fi

echo
echo "=== Result: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo 'You are ready for Section 2 of the manual.'
else
  echo 'See Section 16 (Troubleshooting) for each [FAIL] item.'
fi
```

Press `Esc`, then type `:wq` and press Enter to save and quit. Now run the script:

```bash
chmod +x check_preflight.sh
./check_preflight.sh
```

Every line should print `[OK]`. If any line prints `[FAIL]`, stop here and check Section 16. Do not proceed to Section 2 until all checks pass.

> **TIP**  
> Save the output of this script and send it to the instructor before the tutorial day. This lets us spot problems early.

---

## 2. Installing ISCE2 and MintPy

This section has two installation paths. Choose based on where you are installing:

| Path | Where | When to use |
|------|-------|-------------|
| Path A | Your local machine (WSL, native Linux, or macOS) | Learning, visualization (Phase 4.5), small test runs |
| Path B | felix server | Production runs, full-frame processing |

If you completed Section 1 (Pre-Flight), start with Path A. You will also need Path B to run real data — most students do both eventually.

### 2.1 Path A — Local Install (WSL/Linux/macOS)

#### 2.1.1 Clone the ISCE2 Source Tree

We need the stack processor scripts, which live in the ISCE2 GitHub repository. Create a tools directory and clone:

```bash
mkdir -p ~/tools/src && cd ~/tools/src
git clone https://github.com/isce-framework/isce2.git
```

Verify the clone:

```bash
ls ~/tools/src/isce2/contrib/stack/
# should list: alosStack/  stripmapStack/  topsStack/  ...
```

#### 2.1.2 Create the isce2 conda environment

```bash
conda create -n isce2 python=3.12 -y
conda activate isce2
conda install -c conda-forge isce2 -y
```

The install step takes 5–15 minutes while conda resolves dependencies. If the solver appears to hang, let it run — it is not frozen, just slow.

> **NOTE**  
> ISCE2 on conda-forge supports Python 3.9 through 3.12. We pin 3.12 to match felix. If 3.12 is ever dropped from conda-forge in the future, fall back to 3.11.

#### 2.1.3 Copy Stack Processor Files into the Environment

```bash
mkdir -p $CONDA_PREFIX/share/isce2
cp -R ~/tools/src/isce2/contrib/stack/* $CONDA_PREFIX/share/isce2
```

Proceed to Section 2.3.

### 2.2 Path B — felix Server Install

On felix, most of the heavy lifting has already been done by the system administrator. Follow these steps to set up your user environment on felix.

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

This follows the lijun99/isce2-install guide for conda-forge ISCE2.

#### 2.2.3 Copy Stack Processor Files

On felix the ISCE2 source is pre-cloned at `$HOME/tools/src/isce2`. If it is not, follow Section 2.1.1 to clone it.

```bash
mkdir -p $CONDA_PREFIX/share/isce2
cp -R $HOME/tools/src/isce2/contrib/stack/* $CONDA_PREFIX/share/isce2
```

### 2.3 Create and Configure isce2.rc

This step applies to **BOTH** Path A and Path B. The `isce2.rc` file sets environment variables ISCE2 needs at runtime.

```bash
cd ~
vim isce2.rc
```

Press `i` to enter INSERT mode, then paste the following block:

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

Press `Esc`, then type `:wq` and press Enter to save and quit.

> **NOTE**  
> On a local laptop with fewer than 8 cores, reduce `OMP_NUM_THREADS` to the number of physical cores you have (check with `nproc` on Linux/WSL, or `sysctl -n hw.physicalcpu` on macOS).

#### 2.3.1 Add a Loader Alias to ~/.bash_aliases

```bash
vim ~/.bash_aliases
```

Press `i` to enter INSERT mode. If the file has existing content, move to the bottom with `G`, then press `o` to start a new line in insert mode. Paste:

```bash
# Activates ISCE2 and sets PATH and PYTHONPATH from isce2.rc
load_isce () {
    source ~/miniforge3/bin/activate          # [LOCAL] use your Miniforge path
    # source /opt/miniforge3/bin/activate     # [FELIX] uncomment this and comment the line above
    conda activate isce2
    source ~/isce2.rc
}
```

On felix, swap which line is commented as indicated. Press `Esc`, then `:wq`, Enter.

#### 2.3.2 Load the Alias

```bash
source ~/.bash_aliases
```

Make sure `.bashrc` sources `.bash_aliases`. On most Ubuntu systems it does by default. Verify:

```bash
grep .bash_aliases ~/.bashrc
```

If the command prints nothing, add the sourcing yourself:

```bash
echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> ~/.bashrc
source ~/.bashrc
```

#### 2.3.3 Test the Loader

Open a fresh terminal, then run:

```bash
load_isce
which topsApp.py    # should print a path inside miniforge3
python -c 'import isce; print(isce.__file__)'
```

If both commands succeed, ISCE2 is installed and loadable. Every time you log in, you must run `load_isce` before using ISCE2 commands.

### 2.4 Install MintPy

We install MintPy inside the isce2 environment, matching the v2.0 manual and felix configuration. This keeps dependencies in one place.

```bash
load_isce
conda install -c conda-forge mintpy -y
```

Verify:

```bash
smallbaselineApp.py --help | head
```

> **WARNING**  
> Do NOT install MintPy with pip inside the isce2 env. Mixing pip and conda for MintPy/ISCE2 breaks GDAL dependencies silently and the failure shows up much later, during Phase 5. If conda fails to install MintPy, report the error in Section 16 — do not work around it with pip.

### 2.5 Install isce2_local (Visualization Environment for Phase 4.5)

Phase 4.5 runs on your local machine and generates interferogram images for QC. It needs a lightweight environment with ISCE2's Python modules, matplotlib, and numpy — separate from the main isce2 env to keep it fast to activate.

**Skip this subsection if you are only installing on felix. This env is LOCAL ONLY.**

```bash
conda create -n isce2_local python=3.12 -y
conda activate isce2_local
conda install -c conda-forge isce2 numpy matplotlib pillow -y
```

Verify:

```bash
python -c 'import isceobj, numpy, matplotlib; print("OK")'
```

> **TIP**  
> You do NOT need `isce2_local` on felix. On your laptop, activate it only when running Phase 4.5 scripts (`linog_save_insar_images.py`, `linog_create_grid.py`). For all other local ISCE2 work, use the main isce2 env via `load_isce`.

---

## 3. Prerequisites and Environment Setup

One-time setup. Complete before processing.

### 3.1 Required Access

| Requirement | Description |
|-------------|-------------|
| Server SSH | Login to felix (ask supervisor) |
| NASA EarthData | urs.earthdata.nasa.gov (register free) |
| ISCE2 env (felix) | `conda activate isce2` (after `load_isce`) |
| ISCE2 env (local) | `conda activate isce2_local` (for Phase 4.5) |
| GNU Parallel | Pre-installed on felix |
| MintPy | Inside isce2 conda env (Section 2.4) |

### 3.2 Configure .netrc (for NASA EarthData DEM downloads)

On felix:

```bash
cd ~
vim .netrc
```

Press `i`, then paste:

```
machine urs.earthdata.nasa.gov
    login your_login
    password your_password
```

Press `Esc`, `:wq`, Enter. Then set restrictive permissions:

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

---

## 4. Directory Organization and Naming Conventions

### 4.1 Per-Frame Structure

```
p448/f310/
  raw/             <- Symlinked ALOS zips
  data -> raw      <- Symlink for unzip script
  unzipped/        <- Extracted FBS acquisitions
  SLC/             <- ISCE2 SLC format
  DEM/             <- SRTM DEM
  run_files/       <- ISCE2 run scripts
  interferograms/  <- ISCE2 output pairs
  logs/            <- Versioned logs
  Igrams/          <- Local interferogram viz
  mintpy/          <- MintPy workspace
    geo/
      LInOG_Upload_P448F0310/  <- ALL deliverables
```

### 4.2 Output Naming Convention

Pattern: `P###F####_[DataType]_[Correction].ext`

All outputs go into ONE combined folder per frame: `LInOG_Upload_P###F####/`

| Example | Description |
|---------|-------------|
| `P448F0310_Velocity_demErr.tif` | LOS velocity, DEM error corrected |
| `P448F0310_Velocity_Vertical.tif` | Vertical projection (demErr) |
| `P448F0310_Velocity_Horizontal_ramp.tif` | Horizontal projection (demErr_ramp) |
| `P448F0310_Velocity_Hillshade_demErr.png` | LOS hillshade (demErr) |
| `P448F0310_TimeSeries_demErr.kmz` | Interactive KMZ with charts |
| `P448F0310_Igram_Report_Page_1.jpg` | Interferogram report grid |

### 4.3 Log Naming

Pattern: `##_[step_name].log.v#` (auto-incrementing version on re-runs)

### 4.4 Script Naming

All custom LInOG scripts use the `linog_` prefix.

---

## 5. Phase 0: Workspace Initialization

```bash
cd /eggraid/home/$USER/projects/linog/insar
mkdir -p p448/f310/{raw,unzipped,SLC,DEM,logs,mintpy/inputs,interferograms,run_files,Igrams/logs}
mkdir -p p448/f310/mintpy/geo/LInOG_Upload_P448F0310
cd p448/f310
```

---

## 6. Phase 1: Data Acquisition

### 6.1 Find and Symlink

> **TIP**  
> A symlink is like a shortcut. Instead of copying huge SAR zip files, we create pointers to where the originals live on the server.

```bash
cd /eggraid/home/$USER/projects/linog/insar/p448/f310
# Find and symlink ALOS data
find_alos.sh 448 0310 /eggraid/data/alos raw/ 2>&1 | tee logs/01_find_alos.log.v1
# Fix nested directory from find_alos.sh
mv raw/448/0310/data/*.zip raw/
rm -rf raw/448/
# Create data->raw symlink (REQUIRED by unzip script)
ln -s raw data 2>&1 | tee -a logs/01_find_alos.log.v1
```

### 6.2 Unzip FBS Only

```bash
python ~/bin/unzip_ALOS-SLC-pol.py --pol FBS 2>&1 | tee logs/02_unzip_fbs.log.v1
```

> **WARNING**  
> Do NOT use the `--dir` flag. The script reads from the `data/` symlink automatically.

### 6.3 Unpack to SLC

```bash
run_unpack_all_cli.py 2>&1 | tee logs/03_unpack_all.log.v1
ls SLC/ | wc -l  # Count FBS dates
```

---

## 7. Phase 2: DEM Preparation (SRTM Download)

> **TIP**  
> A DEM (Digital Elevation Model) is needed to remove topographic phase from interferograms and to geocode final results.

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
| `-b 14 18 120 123` | Bounding box (Luzon) |
| `-r` | WGS84 reference |
| `-s 1` | 1 arc-second (~30m) |
| `-c` | Curvature correction |
| `-u http://...` | ESA DEM server |

---

## 8. Phase 3: Stack Configuration and Baselines

```bash
stackStripMap.py -W interferogram --nofocus \
  -s SLC -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
  -t 730 -b 1500 -a 28 -r 12 -u snaphu \
  2>&1 | tee logs/05_stack_config.log.v1

# Review pairs.pdf, then re-run with reference date:
stackStripMap.py -W interferogram --nofocus \
  -s SLC -d DEM/demLat_N14_N18_Lon_E120_E123.dem.wgs84 \
  -t 730 -b 1500 -a 28 -r 12 -u snaphu -m 20091111 \
  2>&1 | tee -a logs/05_stack_config.log.v1
```

> **TIP**  
> For Frame 0310, reference date `20091111` is confirmed optimal.

---

## 9. Phase 4: ISCE2 Processing Pipeline

| Run File | Method | Est. Time |
|----------|--------|-----------|
| run_01_reference | sh (sequential) | ~10 min |
| run_02_focus_split | sh (sequential) | ~10 min |
| run_03_geo2rdr_coarseResamp | parallel -j4 | ~30 min |
| run_04_refineSecondaryTiming | parallel -j4 | ~30 min |
| poststep04_cleanup.py | python | ~2 min |
| run_05_invertMisreg | sh (sequential) | ~5 min |
| run_06_fineResamp | parallel -j4 | ~20 min |
| run_07_grid_baseline | sh (sequential) | ~5 min |
| run_08_igram | parallel -j4 | 1–4+ hours |

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
> `run_08` is the longest. Run inside screen or tmux so the job survives disconnection:
> ```bash
> screen -S insar
> ```
> ...then `Ctrl+A D` to detach. Reattach later with `screen -r insar`.

---

## 10. Phase 4.5: Interferogram Visualization (Local Machine)

This phase runs on your **LOCAL machine** using the `isce2_local` environment built in Section 2.5. You rsync the filtered interferograms down from felix, generate phase and combined images, then create report grid pages for QC review.

### 10.1 Prerequisites (Local)

- Conda environment: `isce2_local` (see Section 2.5)
- Scripts: `linog_save_insar_images.py`, `linog_create_grid.py`

### 10.2 Steps

```bash
# On LOCAL machine:
mkdir -p ~/LInOG/insar/p448/f310/Igrams/logs
cd ~/LInOG/insar/p448/f310/Igrams

# Rsync filtered interferograms from felix:
rsync -avh --progress \
  "arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f310/interferograms/*/filt*.int*" . \
  2>&1 | tee logs/fetch_igrams.log.v1

# Activate local ISCE2 environment:
conda activate isce2_local

# Generate phase + combined images:
python linog_save_insar_images.py 2>&1 | tee logs/01_save_images.log.v1

# Generate report grid pages:
python linog_create_grid.py --path 448 --frame 0310 2>&1 | tee logs/02_report_grid.log.v1
```

### 10.3 Review and Upload

Review the report pages. Identify any bad dates to exclude before MintPy. Then upload report pages to the delivery folder on felix:

```bash
scp P448F0310_Igram_Report_Page_*.jpg \
  arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f310/mintpy/geo/LInOG_Upload_P448F0310/
```

---

## 11. Phase 5: MintPy Time-Series Analysis

MintPy performs SBAS time-series inversion. Key parameters: coherence threshold 0.4, no deramp, no atmospheric correction, topographic residual correction enabled.

```bash
cd mintpy/
smallbaselineApp.py smallbaselineApp.cfg 2>&1 | tee ../logs/15_mintpy.log.v1
```

Produces: `geo_velocity_demErr.h5`, `geo_velocity_demErr_ramp.h5`, `geo_timeseries_demErr.h5`, `geo_timeseries_ramp_demErr.h5`

---

## 12. Phase 6: Geocoded Deliverables

All outputs go into ONE combined folder: `geo/LInOG_Upload_P###F####/`

Both `demErr` and `demErr_ramp` corrections are processed. Vertical and horizontal projections are computed for each.

### 12.1 Velocity Hillshade PNGs

```bash
MASK=geo/geo_maskTempCoh.h5
GEOM=geo/geo_geometryRadar.h5
OUT=geo/LInOG_Upload_P448F0310

# demErr LOS hillshade:
view.py geo/geo_velocity_demErr.h5 velocity --mask $MASK -d $GEOM \
    -v -10 10 --shade-exag 0.05 --nodisplay --save \
    -o $OUT/P448F0310_Velocity_Hillshade_demErr.png --dpi 600

# demErr_ramp LOS hillshade:
view.py geo/geo_velocity_demErr_ramp.h5 velocity --mask $MASK -d $GEOM \
    -v -10 10 --shade-exag 0.05 --nodisplay --save \
    -o $OUT/P448F0310_Velocity_Hillshade_demErr_ramp.png --dpi 600
```

### 12.2 Vertical and Horizontal Projections

Computed TWICE: once from `geo_velocity_demErr.h5` and once from `geo_velocity_demErr_ramp.h5`.

```
V_vert = V_LOS / cos(theta),   V_horz = V_LOS / sin(theta)   [Pepe and Calo, 2017, Eq. 43]
```

### 12.3 GeoTIFF and KMZ Exports

GeoTIFFs via `save_gdal.py`, standard KMZ via `save_kmz.py`, interactive KMZ via `linog_gen_interactive_kmz.py`.

### 12.4 Interactive KMZ

The interactive KMZ includes per-pixel Google Charts time-series scatter plots and displacement tables:

```bash
python ~/bin/linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr
python ~/bin/linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr_ramp
```

The script reads the correct velocity file per correction: `geo_velocity_demErr.h5` for `demErr`, `geo_velocity_demErr_ramp.h5` for `demErr_ramp`.

---

## 13. Phase 7: Quality Control and Checklist

The automation script prints a color-coded checklist. Verify all items show `[OK]`.

Sync deliverables to local:

```bash
rsync -avP arieln@felix:/eggraid/home/arieln/projects/linog/insar/p448/f310/mintpy/geo/LInOG_Upload_P448F0310/ ./P448F0310/
```

---

## 14. Script Reference

| Script | Purpose | Location |
|--------|---------|----------|
| `linog_fbs_processor.sh` | Master automation (all phases) | `~/bin/` (felix) |
| `linog_save_insar_images.py` | Phase/combined JPG from .int files | LOCAL `~/bin/` |
| `linog_create_grid.py` | Interferogram report grid pages | LOCAL `~/bin/` |
| `linog_gen_interactive_kmz.py` | Interactive KMZ with charts | `~/bin/` (felix) |

All scripts are in the `scripts/` folder of this repository.

### 14.1 linog_fbs_processor.sh usage

```bash
./linog_fbs_processor.sh          # Full pipeline
./linog_fbs_processor.sh 4        # ISCE2 only
./linog_fbs_processor.sh 4.5      # Igram viz (local instructions)
./linog_fbs_processor.sh 6        # Deliverables only
```

### 14.2 linog_create_grid.py usage

```bash
python linog_create_grid.py --path 448 --frame 0310
```

### 14.3 linog_gen_interactive_kmz.py usage

```bash
# Single frame:
python linog_gen_interactive_kmz.py --path 448 --frame 0310 --correction demErr

# All frames batch:
python linog_gen_interactive_kmz.py --batch
```

---

## 15. Deliverables Checklist

All files in ONE folder: `LInOG_Upload_P###F####/`

### 15.1 demErr Correction

| File | Type |
|------|------|
| `P###F####_Velocity_Hillshade_demErr.png` | Hillshade PNG |
| `P###F####_Velocity_Hillshade_Vertical.png` | Hillshade PNG |
| `P###F####_Velocity_Hillshade_Horizontal.png` | Hillshade PNG |
| `P###F####_Velocity_demErr.tif` | GeoTIFF |
| `P###F####_Velocity_Vertical.tif` | GeoTIFF |
| `P###F####_Velocity_Horizontal.tif` | GeoTIFF |
| `P###F####_Velocity_demErr.kmz` | Google Earth KMZ |
| `P###F####_TimeSeries_demErr.kmz` | Interactive KMZ |

### 15.2 demErr_ramp Correction

| File | Type |
|------|------|
| `P###F####_Velocity_Hillshade_demErr_ramp.png` | Hillshade PNG |
| `P###F####_Velocity_Hillshade_Vertical_ramp.png` | Hillshade PNG |
| `P###F####_Velocity_Hillshade_Horizontal_ramp.png` | Hillshade PNG |
| `P###F####_Velocity_demErr_ramp.tif` | GeoTIFF |
| `P###F####_Velocity_Vertical_ramp.tif` | GeoTIFF |
| `P###F####_Velocity_Horizontal_ramp.tif` | GeoTIFF |
| `P###F####_Velocity_demErr_ramp.kmz` | Google Earth KMZ |
| `P###F####_TimeSeries_demErr_ramp.kmz` | Interactive KMZ |

### 15.3 Interferogram QC

| File | Type |
|------|------|
| `P###F####_Igram_Report_Page_1.jpg` | Report grid (phase + combined) |
| `P###F####_Igram_Report_Page_2.jpg` | Report grid (continued) |
| `P###F####_Igram_Report_Page_N.jpg` | Additional pages as needed |

**Total: 16 velocity/KMZ files + N interferogram report pages per frame.**

---

## 16. Troubleshooting: Pre-Flight and Installation

Errors you might hit during Sections 1 and 2.

### 16.1 WSL2 Installation Errors (Windows)

| Error | Fix |
|-------|-----|
| `0x80370102` virtualization not enabled | Enable VT-x/AMD-V in BIOS (Section 1.2.2) |
| `WslRegisterDistribution failed 0x8007019e` | Run `wsl --install` again, then restart Windows |
| Ubuntu installed but opens to a weird prompt | You got Ubuntu (no version). Run `wsl --unregister Ubuntu`, then `wsl --install -d Ubuntu-22.04` |
| Cannot connect to internet inside WSL2 | Corporate VPN or firewall conflict. Try disconnecting VPN, or see WSL networking docs |
| `apt update: Could not resolve archive.ubuntu.com` | DNS issue in WSL2. Edit `/etc/resolv.conf` to use `8.8.8.8` (temporary) or see Microsoft WSL docs |
| `conda: command not found` after Miniforge install | Close and reopen the terminal, or run `source ~/.bashrc` |

### 16.2 macOS Installation Errors

| Error | Fix |
|-------|-----|
| `xcode-select: command not found` | Run Software Update in System Settings first |
| Miniforge installer: 'cannot be opened because it is from an unidentified developer' | Right-click the `.sh` file → Open, or run in Terminal with `bash` |
| ISCE2 install: 'PackagesNotFoundError' | You are on Apple Silicon without Rosetta. See Section 1.3 warning box |
| `conda activate` does not work | Close Terminal, reopen, then `conda init zsh` (if using zsh) or `conda init bash` |

### 16.3 Conda Environment Errors

| Error | Fix |
|-------|-----|
| `Solving environment: failed. ResolvePackageNotFound` | Check conda-forge is in your channels: `conda config --show channels` |
| Solver is stuck for >30 minutes | Cancel with Ctrl+C. Install mamba first: `conda install -n base -c conda-forge mamba`, then use `mamba install` instead |
| `PackageNotFoundError: isce2` | You did not pass `-c conda-forge`. Re-run with the channel flag |
| `CondaHTTPError: HTTP 000 CONNECTION FAILED` | Network/proxy issue. Check internet or corporate proxy settings |
| Env created but `conda activate isce2` does nothing | Run `source ~/.bashrc` or open a new terminal |

### 16.4 ISCE2 Runtime Errors

| Error | Fix |
|-------|-----|
| `ImportError: No module named isce` | Forgot to source isce2.rc. Run `load_isce` |
| `which topsApp.py` returns nothing | PATH not set. Check isce2.rc has ISCE_HOME pointing to the right python version |
| ISCE_HOME points to python3.11 but env is 3.12 | Edit `~/isce2.rc` to match your installed Python version |
| Stack processor scripts not found | You skipped Section 2.1.3 / 2.2.3. Copy `contrib/stack` into `$CONDA_PREFIX/share/isce2` |
| Permission denied: `~/tools/src/isce2` | Clone repo to a directory you own, not a system path |

### 16.5 MintPy Install Errors

| Error | Fix |
|-------|-----|
| `mintpy import: undefined symbol in GDAL` | Classic pip-vs-conda conflict. Recreate the env from scratch, install via conda only |
| `smallbaselineApp.py: command not found` | Run `load_isce`, then `conda activate isce2` again |
| Mintpy conda install hangs >20 minutes | Use mamba instead: `mamba install -c conda-forge mintpy` |

### 16.6 Verification Script Failures

| Failed check | Action |
|--------------|--------|
| conda is installed | Redo Section 1.2.5 / 1.3.2 / 1.4 |
| conda-forge is default | Run: `conda config --add channels conda-forge && conda config --set channel_priority strict` |
| git is installed | Redo Section 1.5 |
| vim is installed | `sudo apt install vim` (Linux/WSL) or `brew install vim` (macOS) |
| disk space | Clear space or relocate conda to another disk |

---

## 17. Troubleshooting: Processing Pipeline

| Error | Fix |
|-------|-----|
| `event not found` (echo shebang) | Use single quotes for `#!/bin/bash` |
| `unzip --dir unrecognized` | Use `--source_dir` or create `data->raw` symlink |
| DEM 401 error | Fix `~/.netrc`, check `chmod 600` |
| parallel server slow | Reduce `-j` count, check htop |
| SLC/ empty | Re-run unzip; check `data/` symlink exists |
| Killed / MemoryError | Reduce parallel `-j`; wait for server |
| Qt wayland plugin error | Harmless warning; images still generate |
| `tee: No such file` | Create logs/ directory first: `mkdir -p logs` |

---

## 18. Scientific References

Pepe, A., and Calo, F. (2017). A Review of Interferometric Synthetic Aperture RADAR (InSAR) Multi-Track Approaches for the Retrieval of Earth's Surface Displacements. *Remote Sensing*, 9(1), 16. https://doi.org/10.3390/rs9010016

Sandwell, D. T., et al. (2008). Accuracy and Resolution of ALOS Interferometry. *IEEE TGRS*.

Werner, C., et al. (2007). PALSAR Multi-mode Interferometric Processing. *Gamma Remote Sensing*.

Yunjun, Z., Fattahi, H., and Amelung, F. (2019). Small baseline InSAR time series analysis. *Computers and Geosciences*, 133, 104331.

- Lijun99 ISCE2 install guide: https://github.com/lijun99/isce2-install
- ISCE-framework repository: https://github.com/isce-framework/isce2
- MintPy repository: https://github.com/insarlab/MintPy

---

*— End of Document —*
