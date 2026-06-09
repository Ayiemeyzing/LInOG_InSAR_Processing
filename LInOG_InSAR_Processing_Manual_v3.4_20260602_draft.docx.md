

**LInOG InSAR Processing Manual**

ALOS-1 PALSAR FBS Stack Processing

ISCE2 \+ MintPy Automated Pipeline

**Version 3.4**

**National Institute of Geological Sciences**

University of the Philippines Diliman

DOST-PCIEERD LInOG Project

**June 1–5, 2026**

[0\. Read This First — Tutorial Roadmap	5](#0.-read-this-first-—-tutorial-roadmap)  
[0.1 Who This Manual Is For	5](#0.1-who-this-manual-is-for)  
[0.2 Two Processing Environments	5](#0.2-two-processing-environments)  
[0.3 Before the Tutorial — Required Pre-Work	5](#0.3-before-the-tutorial-—-required-pre-work)  
[0.4 What You Will Build	5](#0.4-what-you-will-build)  
[1\. Pre-Flight: Local Environment Setup	5](#1.-pre-flight:-local-environment-setup)  
[1.1 Vim Survival Guide	6](#1.1-vim-survival-guide)  
[1.2 Option A — Windows: Install WSL2 \+ Ubuntu 22.04 LTS	6](#1.2-option-a-—-windows:-install-wsl2-+-ubuntu-22.04-lts)  
[1.2.1 Check Windows Version	6](#1.2.1-check-windows-version)  
[1.2.2 Enable Virtualization	6](#1.2.2-enable-virtualization)  
[1.2.3 Install WSL2 with Ubuntu 22.04	7](#1.2.3-install-wsl2-with-ubuntu-22.04)  
[1.2.4 Update Ubuntu	7](#1.2.4-update-ubuntu)  
[1.2.5 Install Miniforge (conda)	7](#1.2.5-install-miniforge-\(conda\))  
[1.3 Option B — macOS: Install Miniforge	7](#1.3-option-b-—-macos:-install-miniforge)  
[1.3.1 Install Command Line Tools	8](#1.3.1-install-command-line-tools)  
[1.3.2 Install Miniforge	8](#1.3.2-install-miniforge)  
[1.4 Option C — Native Linux: Install Miniforge	8](#1.4-option-c-—-native-linux:-install-miniforge)  
[1.5 Install Git and Build Essentials	8](#1.5-install-git-and-build-essentials)  
[1.6 Run the Verification Script	9](#1.6-run-the-verification-script)  
[2\. Installing ISCE2 and MintPy	10](#2.-installing-isce2-and-mintpy)  
[2.1 Path A — Local Install (WSL/Linux/macOS)	10](#2.1-path-a-—-local-install-\(wsl/linux/macos\))  
[2.1.1 Clone the ISCE2 Source Tree	10](#2.1.1-clone-the-isce2-source-tree)  
[2.1.2 Create the isce2 conda environment	10](#2.1.2-create-the-isce2-conda-environment)  
[2.1.3 Copy Stack Processor Files into the Environment	11](#2.1.3-copy-stack-processor-files-into-the-environment)  
[2.2 Path B — felix Server Install	11](#2.2-path-b-—-felix-server-install)  
[2.2.1 Set Up SSH Shortcut for Felix (Recommended)	11](#2.2.1-set-up-ssh-shortcut-for-felix-\(recommended\))  
[2.2.2 Source the Group Conda Installation	11](#2.2.2-source-the-group-conda-installation)  
[2.2.2 Create the Environment	11](#2.2.2-create-the-environment)  
[2.2.3 Copy Stack Processor Files	12](#2.2.3-copy-stack-processor-files)  
[2.3 Create and Configure isce2.rc	12](#2.3-create-and-configure-isce2.rc)  
[2.3.1 Add a Loader Alias to \~/.bash\_aliases	12](#2.3.1-add-a-loader-alias-to-~/.bash_aliases)  
[2.3.2 Load the Alias	13](#2.3.2-load-the-alias)  
[2.3.3 Test the Loader	13](#2.3.3-test-the-loader)  
[2.4 Install MintPy	13](#2.4-install-mintpy)  
[2.5 Install isce2\_local (Visualization Environment for Phase 4.5)	13](#2.5-install-isce2_local-\(visualization-environment-for-phase-4.5\))  
[3\. Prerequisites and Run Configuration	14](#3.-prerequisites-and-run-configuration)  
[3.1 Required Access	14](#3.1-required-access)  
[3.2 Configure .netrc (for NASA EarthData DEM downloads)	14](#3.2-configure-.netrc-\(for-nasa-earthdata-dem-downloads\))  
[3.3 LInOG Scripts on felix (already in PATH)	14](#3.3-linog-scripts-on-felix-\(already-in-path\))  
[3.4 Define Run Variables	15](#3.4-define-run-variables)  
[3.4.1 Choose Your Frame	15](#3.4.1-choose-your-frame)  
[3.4.2 Set the Variables	15](#3.4.2-set-the-variables)  
[3.4.3 Validate the Formats	15](#3.4.3-validate-the-formats)  
[4\. Directory Organization and Naming Conventions	16](#4.-directory-organization-and-naming-conventions)  
[4.1 Per-Frame Structure	16](#4.1-per-frame-structure)  
[4.2 Output Naming Convention	16](#4.2-output-naming-convention)  
[4.3 Log Naming	17](#4.3-log-naming)  
[4.4 Script Naming	17](#4.4-script-naming)  
[5\. Phase 0: Workspace Initialization	17](#5.-phase-0:-workspace-initialization)  
[6\. Phase 1: Data Acquisition	17](#6.-phase-1:-data-acquisition)  
[6.1 Find and Symlink	17](#6.1-find-and-symlink)  
[6.2 Unzip FBS Only	18](#6.2-unzip-fbs-only)  
[6.3 Unpack to SLC	18](#6.3-unpack-to-slc)  
[7\. Phase 2: DEM Preparation (SRTM Download)	18](#7.-phase-2:-dem-preparation-\(srtm-download\))  
[8\. Phase 3: Stack Configuration and Baselines	19](#8.-phase-3:-stack-configuration-and-baselines)  
[9\. Phase 4: ISCE2 Processing Pipeline	20](#9.-phase-4:-isce2-processing-pipeline)  
[9.1 Complete Command Sequence	20](#9.1-complete-command-sequence)  
[10\. Phase 4.5: Interferogram Visualization (Local Machine)	21](#10.-phase-4.5:-interferogram-visualization-\(local-machine\))  
[10.1 Prerequisites	21](#10.1-prerequisites)  
[10.2 Steps	21](#10.2-steps)  
[10.3 Review and Upload	22](#10.3-review-and-upload)  
[11\. Phase 5: MintPy Time-Series Analysis	22](#11.-phase-5:-mintpy-time-series-analysis)  
[12\. Phase 6: Geocoded Deliverables	23](#12.-phase-6:-geocoded-deliverables)  
[12.1 Velocity Hillshade PNGs	23](#12.1-velocity-hillshade-pngs)  
[12.2 Vertical and Horizontal Projections	23](#12.2-vertical-and-horizontal-projections)  
[12.3 GeoTIFF and KMZ Exports	23](#12.3-geotiff-and-kmz-exports)  
[12.4 Interactive KMZ	24](#12.4-interactive-kmz)  
[13\. Phase 7: Quality Control and Checklist	24](#13.-phase-7:-quality-control-and-checklist)  
[14\. Script Reference	24](#14.-script-reference)  
[14.1 linog\_fbs\_processor.sh usage	24](#14.1-linog_fbs_processor.sh-usage)  
[14.2 linog\_create\_grid.py usage	25](#14.2-linog_create_grid.py-usage)  
[14.3 linog\_gen\_interactive\_kmz.py usage	25](#14.3-linog_gen_interactive_kmz.py-usage)  
[15\. Deliverables Checklist	25](#15.-deliverables-checklist)  
[15.1 demErr Correction	25](#15.1-demerr-correction)  
[15.2 demErr\_ramp Correction	26](#15.2-demerr_ramp-correction)  
[15.3 Interferogram QC	26](#15.3-interferogram-qc)  
[16\. Troubleshooting: Pre-Flight and Installation	26](#16.-troubleshooting:-pre-flight-and-installation)  
[16.1 WSL2 Installation Errors (Windows)	27](#16.1-wsl2-installation-errors-\(windows\))  
[16.2 macOS Installation Errors	27](#16.2-macos-installation-errors)  
[16.3 Conda Environment Errors	27](#16.3-conda-environment-errors)  
[16.4 ISCE2 Runtime Errors	27](#16.4-isce2-runtime-errors)  
[16.5 MintPy Install Errors	28](#16.5-mintpy-install-errors)  
[16.6 Verification Script Failures	28](#16.6-verification-script-failures)  
[17\. Troubleshooting: Processing Pipeline	29](#17.-troubleshooting:-processing-pipeline)  
[18\. Scientific References	29](#18.-scientific-references)

# **0\. Read This First — Tutorial Roadmap** {#0.-read-this-first-—-tutorial-roadmap}

This manual supports InSAR time-series processing using ISCE2 and MintPy. It serves two audiences: users learning the pipeline locally, and analysts running production jobs on the felix server at NIGS.

## **0.1 Who This Manual Is For** {#0.1-who-this-manual-is-for}

Users in geology, remote sensing, and related fields. No prior Linux or InSAR experience is assumed, but you should be comfortable following step-by-step instructions carefully. A single missed step can break later phases.

## **0.2 Two Processing Environments** {#0.2-two-processing-environments}

All work in this manual happens in one of two environments. Understanding which environment a step belongs to is critical — do not mix them up.

LOCAL (your laptop)      → Learning, visualization, small test runs  
FELIX (NIGS server)      → Production runs, full-frame processing

Throughout this manual, any instruction that differs between environments is clearly marked with a \[LOCAL\] or \[FELIX\] label.

## **0.3 Before the Tutorial — Required Pre-Work** {#0.3-before-the-tutorial-—-required-pre-work}

All users must complete Section 1 (Pre-Flight) before the tutorial session. This includes installing WSL2 (Windows) or Miniforge (macOS/Linux), configuring the terminal, and running the verification script. Expected time: 60–90 minutes with reliable internet.

**IMPORTANT:** If you arrive at the tutorial without completing Section 1, you will not be able to follow along. The tutorial begins at Section 2 (ISCE2 install) and assumes your local environment is ready. If you hit errors during pre-work, consult Section 16 (Troubleshooting) or message the instructor 24 hours before the session.

## **0.4 What You Will Build** {#0.4-what-you-will-build}

By the end of the full tutorial and first processing run, you will have:

* A working ISCE2 \+ MintPy environment on your laptop, for visualization and learning  
* Access to the same environment on felix, for real processing  
* One processed frame of ALOS-1 PALSAR FBS data from Central Luzon  
* Geocoded velocity maps, interactive KMZs, and interferogram QC reports

# **1\. Pre-Flight: Local Environment Setup** {#1.-pre-flight:-local-environment-setup}

This section sets up your local machine so it can run ISCE2 and MintPy. Complete every subsection in order. Do not skip ahead. The verification script in Section 1.6 will confirm whether your setup is correct.

## **1.1 Vim Survival Guide** {#1.1-vim-survival-guide}

This manual uses vim as the default text editor because it is available on every Linux system, including felix. If you have never used vim before, read this section carefully. Vim behaves differently from Notepad or TextEdit — you cannot just type into a file. You must switch to INSERT mode first.

| Action | Command |
| :---- | :---- |
| Open a file | vim filename |
| Start typing | press i |
| Stop typing | press Esc |
| Save and quit | :wq |
| Quit without saving | :q\! |
| Stuck? | press Esc a few times, then try :q\! |

The two modes you will use are NORMAL mode and INSERT mode. The i key enters insert mode; Esc returns to normal mode. When you see instructions that say "press i then paste," this means: enter INSERT mode first, then paste your content, then press Esc and type :wq to save.

**WARNING:** Do not close your terminal while vim is open with unsaved changes. If you do, vim creates a swap file (.swp) that can confuse you the next time you open the file.

## **1.2 Option A — Windows: Install WSL2 \+ Ubuntu 22.04 LTS** {#1.2-option-a-—-windows:-install-wsl2-+-ubuntu-22.04-lts}

WSL2 (Windows Subsystem for Linux 2\) gives you a full Ubuntu terminal inside Windows. This is the required environment for running ISCE2 locally on a Windows machine. Skip this section if you are on macOS or native Linux.

### **1.2.1 Check Windows Version** {#1.2.1-check-windows-version}

WSL2 requires Windows 10 version 2004 or later (build 19041+), or Windows 11\. Run the command below to check your build number before proceeding.

Press Win+R, type winver, and press Enter. If your version is older, update Windows first through Settings → Windows Update.

### **1.2.2 Enable Virtualization** {#1.2.2-enable-virtualization}

WSL2 runs a lightweight virtual machine and requires CPU virtualization to be enabled in your BIOS or UEFI firmware. Without it, the installation will fail with error code 0x80370102.

Restart your computer and enter BIOS/UEFI (usually F2, F10, or Del during boot). Find the virtualization setting — typically labeled VT-x on Intel or AMD-V on AMD — and enable it. Save and exit.

### **1.2.3 Install WSL2 with Ubuntu 22.04** {#1.2.3-install-wsl2-with-ubuntu-22.04}

Open PowerShell as Administrator (right-click the Start menu → Terminal (Admin) or Windows PowerShell (Admin)). This single command installs the WSL2 engine and Ubuntu 22.04 LTS simultaneously.

wsl \--install \-d Ubuntu-22.04

If you already have WSL installed with a different distribution, run these two commands instead to force version 2 and install Ubuntu 22.04:

wsl \--set-default-version 2  
wsl \--install \-d Ubuntu-22.04

After installation completes, restart your computer. On first launch, Ubuntu will prompt you to create a username and password. Use lowercase letters and no spaces. The password prompt shows no characters as you type — this is normal behavior.

**IMPORTANT:** We pin Ubuntu 22.04 to match the tested ISCE2 environment. If you installed a different version:  
    wsl \--unregister \<DistroName\>  
then reinstall Ubuntu 22.04.

### **1.2.4 Update Ubuntu** {#1.2.4-update-ubuntu}

After first login, update the package list and upgrade all installed packages. This ensures your system has the latest security patches and base libraries before you install anything else.

sudo apt update && sudo apt upgrade \-y

This step takes 5–15 minutes depending on internet speed. Enter your Ubuntu password when prompted.

### **1.2.5 Install Miniforge (conda)** {#1.2.5-install-miniforge-(conda)}

Miniforge is a minimal conda distribution pre-configured with the conda-forge channel. It is required for installing ISCE2 and MintPy. Run these commands one at a time inside your Ubuntu terminal.

The first command downloads the installer. The second runs it and walks you through the license agreement and install path.

cd \~  
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86\_64.sh  
bash Miniforge3-Linux-x86\_64.sh

During the installer: accept the license, press Enter to use the default path (\~/miniforge3), and answer yes when asked to update your shell profile. Then close and reopen your Ubuntu terminal. You should see (base) at the start of your prompt. If not, run:

source \~/.bashrc

## **1.3 Option B — macOS: Install Miniforge** {#1.3-option-b-—-macos:-install-miniforge}

Skip this section if you are on Windows or native Linux.

**WARNING:** APPLE SILICON WARNING: ISCE2 is not officially distributed for osx-arm64 via conda-forge. The simplest tutorial path is to use felix for processing and optionally skip local install.

### **1.3.1 Install Command Line Tools** {#1.3.1-install-command-line-tools}

Command Line Tools provides the compiler toolchain (clang, make, git) that conda packages depend on during installation. Run the command below and follow the dialog that appears.

xcode-select \--install

### **1.3.2 Install Miniforge** {#1.3.2-install-miniforge}

For Intel Macs, download and run the x86\_64 installer directly:

cd \~  
curl \-L \-O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86\_64.sh  
bash Miniforge3-MacOSX-x86\_64.sh

For Apple Silicon (M1/M2/M3) Macs, start a Rosetta x86\_64 shell first, then run the same installer. This makes conda run under emulation so ISCE2 packages install correctly.

arch \-x86\_64 /bin/bash  
cd \~  
curl \-L \-O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86\_64.sh  
bash Miniforge3-MacOSX-x86\_64.sh

Follow the same installer prompts as in Section 1.2.5. Close and reopen your Terminal. You should see (base) at your prompt.

## **1.4 Option C — Native Linux: Install Miniforge** {#1.4-option-c-—-native-linux:-install-miniforge}

Skip this section if you are on Windows or macOS. Tested on Ubuntu 22.04 and 24.04. The process is the same as Section 1.2.5 — download and run the Linux x86\_64 installer.

cd \~  
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86\_64.sh  
bash Miniforge3-Linux-x86\_64.sh

Follow the installer prompts as in Section 1.2.5.

## **1.5 Install Git and Build Essentials** {#1.5-install-git-and-build-essentials}

Git is needed to download the ISCE2 stack processor scripts from GitHub. Build-essential provides compilers and system libraries that conda packages depend on.

\[LOCAL Ubuntu / WSL2\] — installs git, the C/C++ compiler toolchain, vim, and curl in one command:

sudo apt install \-y git build-essential vim curl

\[macOS\] — git and curl are already installed via Command Line Tools (Section 1.3.1). Install vim explicitly if needed:

brew install vim

\[FELIX\] — all tools are already installed system-wide. Skip this subsection.

After installation, verify git is available and shows version 2.x or newer:

git \--version

## **1.6 Run the Verification Script** {#1.6-run-the-verification-script}

This script checks that all required tools — conda, git, vim, curl/wget, disk space, and shell configuration — are correctly installed. Run it before moving to Section 2\. If any check fails, fix it before proceeding.

Create the script file using vim:

cd \~  
vim check\_preflight.sh

Press i to enter INSERT mode, then paste the entire script below. Press Esc, type :wq, and press Enter to save.

\#\!/bin/bash  
\# LInOG Pre-Flight Verification Script  
echo '=== LInOG Pre-Flight Check \==='  
echo  
   
PASS=0; FAIL=0  
check() {  
  if eval "$2" \>/dev/null 2\>&1; then  
    echo "\[OK\]   $1"; PASS=$((PASS+1))  
  else  
    echo "\[FAIL\] $1"; FAIL=$((FAIL+1))  
  fi  
}  
   
\# OS detection  
UNAME=$(uname \-s)  
echo "OS: $UNAME"  
if \[ \-f /etc/os-release \]; then  
  . /etc/os-release  
  echo "Distro: $PRETTY\_NAME"  
fi  
echo  
   
check 'conda is installed'         'command \-v conda'  
check 'conda-forge is default'     "conda config \--show channels | grep \-q conda-forge"  
check 'git is installed'           'command \-v git'  
check 'vim is installed'           'command \-v vim'  
check 'curl or wget is available'  'command \-v curl || command \-v wget'  
check 'home directory is writable' "\[ \-w $HOME \]"  
check '\~/.bashrc exists'           "\[ \-f $HOME/.bashrc \] || \[ \-f $HOME/.zshrc \]"  
   
\# Disk space check (need \>10GB free)  
FREE\_GB=$(df \-BG "$HOME" | tail \-1 | awk '{print $4}' | tr \-d 'G')  
if \[ "$FREE\_GB" \-ge 10 \]; then  
  echo "\[OK\]   disk space ($FREE\_GB GB free in $HOME)"  
  PASS=$((PASS+1))  
else  
  echo "\[FAIL\] disk space ($FREE\_GB GB free; need \>=10GB)"  
  FAIL=$((FAIL+1))  
fi  
   
echo  
echo "=== Result: $PASS passed, $FAIL failed \==="  
if \[ "$FAIL" \-eq 0 \]; then  
  echo 'You are ready for Section 2 of the manual.'  
else  
  echo 'See Section 16 (Troubleshooting) for each \[FAIL\] item.'  
fi

Make the script executable, then run it. Every item should print \[OK\]. If any item shows \[FAIL\], stop here and consult Section 16 for that specific failure before continuing.

chmod \+x check\_preflight.sh  
./check\_preflight.sh

# **2\. Installing ISCE2 and MintPy** {#2.-installing-isce2-and-mintpy}

ISCE2 (InSAR Scientific Computing Environment 2\) is the main processing engine for generating interferograms from ALOS-1 PALSAR data. MintPy (Miami InSAR Time-series software in Python) performs the time-series analysis. Both must be installed before any processing can begin.

| Path | Where | When to use |
| :---- | :---- | :---- |
| Path A | Your local machine | Learning, visualization, small test runs |
| Path B | felix server | Production runs, full-frame processing |

## **2.1 Path A — Local Install (WSL/Linux/macOS)** {#2.1-path-a-—-local-install-(wsl/linux/macos)}

Follow this path to install ISCE2 on your own laptop. This environment is primarily used for Section 1 pre-flight, the isce2\_local visualization in Phase 4.5, and learning the workflow before running on felix.

### **2.1.1 Clone the ISCE2 Source Tree** {#2.1.1-clone-the-isce2-source-tree}

The stripmapStack processor scripts are distributed inside the ISCE2 GitHub repository. You do not need to build ISCE2 from source — you only need these scripts. Clone the repository into a tools directory:

mkdir \-p \~/tools/src && cd \~/tools/src  
git clone https://github.com/isce-framework/isce2.git

After cloning, verify the stack processor directories exist. You should see at minimum alosStack, stripmapStack, and topsStack:

ls \~/tools/src/isce2/contrib/stack/

### **2.1.2 Create the isce2 conda environment** {#2.1.2-create-the-isce2-conda-environment}

Create a dedicated conda environment for ISCE2 and MintPy. Isolating these packages in their own environment prevents version conflicts with other Python tools you may have installed. The installation step can take 5–15 minutes while conda resolves the dependency graph — do not interrupt it.

conda create \-n isce2 python=3.12 \-y  
conda activate isce2  
conda install \-c conda-forge isce2 \-y

**NOTE:** ISCE2 on conda-forge supports Python 3.9 through 3.12. We pin 3.12 to match the felix server configuration.

### **2.1.3 Copy Stack Processor Files into the Environment** {#2.1.3-copy-stack-processor-files-into-the-environment}

The stripmapStack scripts cloned in Section 2.1.1 must be copied into the conda environment so ISCE2 can find them at runtime. This makes the scripts importable as Python modules and accessible on your PATH.

mkdir \-p $CONDA\_PREFIX/share/isce2  
cp \-R \~/tools/src/isce2/contrib/stack/\* $CONDA\_PREFIX/share/isce2

## **2.2 Path B — felix Server Install** {#2.2-path-b-—-felix-server-install}

Follow this path to set up your personal ISCE2 environment on the felix server. The server already has a shared conda installation and the ISCE2 source tree pre-cloned. You only need to create your own conda environment and copy the stack scripts.

### **2.2.1 Set Up SSH Shortcut for Felix (Recommended)** {#2.2.1-set-up-ssh-shortcut-for-felix-(recommended)}

Before doing anything else on felix, set up an SSH shortcut on your local machine. By default you connect with ssh USERNAME@10.207.130.201. This creates a named alias — Host felix — so you connect as ssh USERNAME@felix (replacing USERNAME with your account name). Any tool that uses SSH (scp, rsync, VS Code Remote) will also recognize the name felix and use your credentials automatically. This is a one-time setup in your local WSL2 terminal and changes nothing on the server.

Run the following in your LOCAL WSL2 Ubuntu terminal (not on felix). Replace YOUR\_USERNAME with your assigned username: deol, alfiep, moisesm, or kryzelled.

mkdir \-p \~/.ssh

cat \>\> \~/.ssh/config \<\< 'EOF'

Host felix

    HostName 10.207.130.201

    User YOUR\_USERNAME

EOF

chmod 600 \~/.ssh/config

Test the connection. You will be prompted for your felix password (LInOG@PHIVOLCS2026 on first login — you will be forced to change it immediately).

ssh USERNAME@felix   \# instead of: ssh YOUR\_USERNAME@10.207.130.201

Windows note: run all of the above inside the WSL2 Ubuntu terminal. Do not use Windows PowerShell or CMD — the \~/.ssh/config file must live inside the WSL2 filesystem.

### **2.2.2 Source the Group Conda Installation** {#2.2.2-source-the-group-conda-installation}

Activate the shared conda base installation on felix. This makes the conda command available in your current session. You only need to do this the first time — after adding the loader alias in Section 2.3.1, the alias handles activation automatically.

source /opt/miniforge3/bin/activate

### **2.2.2 Create the Environment** {#2.2.2-create-the-environment}

Create your personal isce2 conda environment on felix, using the same Python version and package source as the local install. This keeps your environment isolated from other users on the server.

conda create \-n isce2 python=3.12 \-y  
conda activate isce2  
conda install \-c conda-forge isce2 \-y

### **2.2.3 Copy Stack Processor Files** {#2.2.3-copy-stack-processor-files}

Copy the stripmapStack scripts from the shared ISCE2 source tree into your personal conda environment. The source tree is pre-cloned at $HOME/tools/src/isce2 on felix. If it is not there, follow Section 2.1.1 to clone it first.

mkdir \-p $CONDA\_PREFIX/share/isce2  
cp \-R $HOME/tools/src/isce2/contrib/stack/\* $CONDA\_PREFIX/share/isce2

## **2.3 Create and Configure isce2.rc** {#2.3-create-and-configure-isce2.rc}

The isce2.rc file sets the environment variables that ISCE2 requires every time it runs: where to find its Python modules, where to find the stack processors, and how many CPU threads to use. This file must be created on both LOCAL and FELIX. Navigate to your home directory and open the file for editing:

cd \~  
vim isce2.rc

Press i to enter INSERT mode, paste the block below, then press Esc and type :wq to save. The ISCE\_HOME variable points into your conda environment. ISCE\_STACK points to the stack processor scripts you copied in Section 2.1.3 or 2.2.3. OMP\_NUM\_THREADS controls parallel computation — 8 threads is appropriate for both your laptop and felix.

\# isce2.rc for conda-forge installation  
export ISCE\_HOME=$CONDA\_PREFIX/lib/python3.12/site-packages/isce  
export ISCE\_STACK=$CONDA\_PREFIX/share/isce2  
export PATH=$ISCE\_HOME/bin:$ISCE\_HOME/applications:$PATH  
export LD\_LIBRARY\_PATH=$ISCE\_HOME/lib:$LD\_LIBRARY\_PATH  
export PYTHONPATH=$ISCE\_HOME:$ISCE\_HOME/applications:$ISCE\_HOME/components:$ISCE\_HOME/library:$ISCE\_STACK:$PYTHONPATH  
   
\# import tops/stripmapStack as python modules  
export PYTHONPATH=${PYTHONPATH}:${ISCE\_STACK}  
   
\# add stack processors to PATH  
export PATH=${PATH}:${ISCE\_STACK}/stripmapStack  
   
\# set number of threads  
export OMP\_NUM\_THREADS=8

### **2.3.1 Add a Loader Alias to \~/.bash\_aliases** {#2.3.1-add-a-loader-alias-to-~/.bash_aliases}

Instead of manually sourcing isce2.rc every session, create a shell alias called load\_isce that does all three steps in one command: activates the base conda, activates the isce2 environment, and sources the rc file. Open the aliases file:

vim \~/.bash\_aliases

Press i, paste the block below, press Esc and type :wq. On LOCAL, the first source line is active. On FELIX, comment out the first source line and uncomment the second one.

\# Activates ISCE2 and sets PATH and PYTHONPATH from isce2.rc  
load\_isce () {  
    source \~/miniforge3/bin/activate          \# \[LOCAL\]  
    \# source /opt/miniforge3/bin/activate     \# \[FELIX\]  
    conda activate isce2  
    source \~/isce2.rc  
}

### **2.3.2 Load the Alias** {#2.3.2-load-the-alias}

Source the aliases file so the load\_isce function is available in your current session. Then verify that .bashrc already sources .bash\_aliases — on most Ubuntu systems it does by default.

source \~/.bash\_aliases  
grep .bash\_aliases \~/.bashrc

If the grep command prints nothing, the sourcing line is missing from .bashrc. Add it manually so the alias is available every time you open a new terminal:

echo 'if \[ \-f \~/.bash\_aliases \]; then . \~/.bash\_aliases; fi' \>\> \~/.bashrc  
source \~/.bashrc

### **2.3.3 Test the Loader** {#2.3.3-test-the-loader}

Open a fresh terminal and run load\_isce. Then verify that the ISCE2 executables are on your PATH and that Python can import the isce module. Both commands must succeed before continuing.

load\_isce  
which topsApp.py  
python \-c 'import isce; print(isce.\_\_file\_\_)'

If both return valid paths, ISCE2 is correctly installed and loadable. Every time you log in or open a new terminal, run load\_isce before using any ISCE2 commands.

## **2.4 Install MintPy** {#2.4-install-mintpy}

Install MintPy inside the same isce2 conda environment. This keeps all time-series analysis dependencies in one place and ensures MintPy can access ISCE2 outputs directly. First activate the environment with load\_isce, then install:

load\_isce  
conda install \-c conda-forge mintpy \-y

After installation, verify that the MintPy command-line entry point is available:

smallbaselineApp.py \--help | head

## **2.5 Install isce2\_local (Visualization Environment for Phase 4.5)** {#2.5-install-isce2_local-(visualization-environment-for-phase-4.5)}

Phase 4.5 generates interferogram QC images on your local machine. It needs a lightweight environment with ISCE2 Python modules, matplotlib, numpy, and pillow — but not the full ISCE2 runtime. This separate environment activates faster and avoids interfering with the main isce2 environment. Skip this subsection if you are only installing on felix.

conda create \-n isce2\_local python=3.12 \-y  
conda activate isce2\_local  
conda install \-c conda-forge isce2 numpy matplotlib pillow \-y

Verify that the required Python modules are importable:

python \-c 'import isceobj, numpy, matplotlib; print("OK")'

# **3\. Prerequisites and Run Configuration** {#3.-prerequisites-and-run-configuration}

This section covers one-time configuration steps and defines the run variables used throughout the processing workflow. Complete Sections 3.1–3.3 once on initial setup. Section 3.4 must be completed at the start of every new frame run.

## **3.1 Required Access** {#3.1-required-access}

Verify you have all of the following before starting a processing run. Missing access to any item will cause failures in later phases.

| Requirement | Description |
| :---- | :---- |
| Server SSH | Login to felix |
| NASA EarthData | urs.earthdata.nasa.gov (for DEM download) |
| ISCE2 env (felix) | conda activate isce2 after load\_isce |
| ISCE2 env (local) | conda activate isce2\_local for Phase 4.5 |
| GNU Parallel | Pre-installed on felix |
| MintPy | Inside isce2 conda env |

## **3.2 Configure .netrc (for NASA EarthData DEM downloads)** {#3.2-configure-.netrc-(for-nasa-earthdata-dem-downloads)}

Phase 2 downloads SRTM DEM tiles from NASA EarthData. The dem.py script reads authentication credentials from \~/.netrc. Without this file, all DEM downloads will fail with HTTP 401 errors. Create the file and add your EarthData credentials:

cd \~  
vim .netrc

Press i, paste your credentials replacing the placeholder values, press Esc and type :wq:

machine urs.earthdata.nasa.gov  
    login your\_login  
    password your\_password

Set restrictive file permissions so only you can read it. This is required by NASA EarthData — the server will reject requests from world-readable .netrc files.

chmod 600 \~/.netrc

## **3.3 LInOG Scripts on felix (already in PATH)** {#3.3-linog-scripts-on-felix-(already-in-path)}

All LInOG scripts are pre-installed in /eggraid/bin/ and are in your PATH system-wide via /etc/profile.d/linog\_path.sh. You do not need to copy or configure anything. Call any script directly by name from any directory on felix.

\# Verify scripts are in PATH:  
which find\_alos.sh  
which check\_preflight.sh

*If which returns no output, log out and log back in to reload the PATH. Scripts live in /eggraid/bin/ (root:linog 755\) — source: github.com/Ayiemeyzing/LInOG\_InSAR\_Processing*

## **3.4 Define Run Variables** {#3.4-define-run-variables}

This is the most important setup step before any processing run. The entire workflow uses these six variables — PATH\_NUM, FRAME\_NUM, PADDED\_PATH, PADDED\_FRAME, FRAME\_TAG, and WORK\_DIR — to build all directory paths, file names, and script arguments automatically. Define them once and every subsequent command will use them without further editing.

### **3.4.1 Choose Your Frame** {#3.4.1-choose-your-frame}

Identify the ALOS-1 path and frame numbers you will process. For this training, the example values are:

* Path \= 448  
* Frame \= 0290

### **3.4.2 Set the Variables** {#3.4.2-set-the-variables}

Run the appropriate block for your environment. These commands define your run variables for the current terminal session. If you open a new terminal, you must re-run this block before continuing.

\[FELIX\]

export PATH\_NUM=448  
export FRAME\_NUM=0290  
   
export PADDED\_PATH=p${PATH\_NUM}  
export PADDED\_FRAME=f${FRAME\_NUM}  
export FRAME\_TAG=P${PATH\_NUM}F${FRAME\_NUM}  
   
export BASE\_DIR=/eggraid/home/$USER/projects/linog/insar  
export WORK\_DIR=${BASE\_DIR}/${PADDED\_PATH}/${PADDED\_FRAME}

\[LOCAL\]

export PATH\_NUM=448  
export FRAME\_NUM=0290  
   
export PADDED\_PATH=p${PATH\_NUM}  
export PADDED\_FRAME=f${FRAME\_NUM}  
export FRAME\_TAG=P${PATH\_NUM}F${FRAME\_NUM}  
   
export BASE\_DIR=$HOME/LInOG/insar  
export WORK\_DIR=${BASE\_DIR}/${PADDED\_PATH}/${PADDED\_FRAME}

### **3.4.3 Validate the Formats** {#3.4.3-validate-the-formats}

Before running anything, verify the variables are correctly set. A wrong digit count in PATH\_NUM or FRAME\_NUM will produce mismatched directory names and corrupt deliverable file names.

* PATH\_NUM must be exactly 3 digits  
* FRAME\_NUM must be exactly 4 digits  
* ${PADDED\_PATH} → p448  |  ${PADDED\_FRAME} → f0290  |  ${FRAME\_TAG} → P448F0290

Print each variable and confirm the output matches the expected format:

echo $PATH\_NUM  
echo $FRAME\_NUM  
echo $PADDED\_PATH  
echo $PADDED\_FRAME  
echo $FRAME\_TAG  
echo $WORK\_DIR

# **4\. Directory Organization and Naming Conventions** {#4.-directory-organization-and-naming-conventions}

All processing work for a single path/frame is contained within one directory tree. Understanding this structure is essential — ISCE2 run scripts, MintPy, and the LInOG scripts all read from and write to specific locations within this tree. Do not rename or reorganize these directories.

## **4.1 Per-Frame Structure** {#4.1-per-frame-structure}

The directory tree below is created in Phase 0 using the run variables from Section 3.4. Each subdirectory has a specific role in the pipeline:

${PADDED\_PATH}/${PADDED\_FRAME}/  
  raw/             \<- Symlinked ALOS zips (Phase 1\)  
  data \-\> raw      \<- Symlink required by the unzip script  
  unzipped/        \<- Extracted FBS acquisitions (Phase 1\)  
  SLC/             \<- ISCE2 SLC format scenes (Phase 1\)  
  DEM/             \<- SRTM DEM and derived files (Phase 2\)  
  run\_files/       \<- ISCE2-generated run scripts (Phase 3\)  
  interferograms/  \<- ISCE2 interferogram pairs (Phase 4\)  
  logs/            \<- Versioned step logs (all phases)  
  Igrams/          \<- Local interferogram visualization (Phase 4.5)  
  mintpy/  
    geo/  
      LInOG\_Upload\_${FRAME\_TAG}/  \<- All final deliverables (Phase 6\)

## **4.2 Output Naming Convention** {#4.2-output-naming-convention}

All deliverable files follow a consistent naming pattern using the FRAME\_TAG variable. This makes it unambiguous which frame a file belongs to and what correction has been applied.

Pattern: P\#\#\#F\#\#\#\#\_\[DataType\]\_\[Correction\].ext

| Example | Description |
| :---- | :---- |
| ${FRAME\_TAG}\_Velocity\_demErr.tif | LOS velocity, DEM error corrected |
| ${FRAME\_TAG}\_Velocity\_Vertical.tif | Vertical component of velocity |
| ${FRAME\_TAG}\_Velocity\_Horizontal\_ramp.tif | Horizontal component, ramp-corrected |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_demErr.png | LOS velocity hillshade overlay |
| ${FRAME\_TAG}\_TimeSeries\_demErr.kmz | Interactive KMZ with time series |
| ${FRAME\_TAG}\_Igram\_Report\_Page\_1.jpg | Interferogram QC report grid |

## **4.3 Log Naming** {#4.3-log-naming}

Every processing step writes a log file. Log files are numbered by step and versioned so re-runs do not overwrite earlier logs. This lets you compare outputs before and after a fix.

Pattern: \#\#\_\[step\_name\].log.v\# (auto-incrementing version number on re-runs)

## **4.4 Script Naming** {#4.4-script-naming}

All custom LInOG scripts use the linog\_ prefix to distinguish them from ISCE2 and MintPy built-in tools. If a command does not have this prefix, it is a system or framework command, not a LInOG-specific script.

# **5\. Phase 0: Workspace Initialization** {#5.-phase-0:-workspace-initialization}

Before any data can be processed, the full directory tree for your frame must exist. This phase creates all required directories in a single command using brace expansion. Run this on FELIX where the actual processing will happen.

First, confirm your run variables from Section 3.4 are set in the current terminal, then create the workspace:

cd "$BASE\_DIR"  
mkdir \-p "${WORK\_DIR}"/{raw,unzipped,SLC,DEM,logs,mintpy/inputs,interferograms,run\_files,Igrams/logs}  
mkdir \-p "${WORK\_DIR}/mintpy/geo/LInOG\_Upload\_${FRAME\_TAG}"  
cd "$WORK\_DIR"

The mkdir \-p command creates all directories in one call. The brace expansion {raw,unzipped,...} is shorthand for listing each subdirectory. The second mkdir creates the deliverables folder with the full FRAME\_TAG name.

After creating the workspace, confirm you are in the correct directory and that all subdirectories are present:

pwd  
ls

Expected output of pwd: the full path to your WORK\_DIR. Expected output of ls: raw, unzipped, SLC, DEM, logs, mintpy, interferograms, run\_files, Igrams.

# **6\. Phase 1: Data Acquisition** {#6.-phase-1:-data-acquisition}

Phase 1 locates the ALOS-1 PALSAR raw data archives on the felix server, links them into your workspace, and unpacks them into the SLC format that ISCE2 requires. Complete all three subsections in order.

## **6.1 Find and Symlink** {#6.1-find-and-symlink}

The find\_alos.sh script searches the server archive at /eggraid/data/alos for zip files matching your path and frame numbers, then creates symbolic links to them inside your raw/ directory. This avoids duplicating the large raw data files.

After the find step, the zip files are nested inside path/frame subdirectories. Move them to the top level of raw/ and remove the now-empty nested directories. Then create a symbolic link named data pointing to raw/ — this link is required by the unzip script, which specifically looks for a directory called data.

cd "$WORK\_DIR"  
   
find\_alos.sh "$PATH\_NUM" "$FRAME\_NUM" /eggraid/data/alos raw/ 2\>&1 | tee logs/01\_find\_alos.log.v1  
   
mv raw/${PATH\_NUM}/${FRAME\_NUM}/data/\*.zip raw/  
rm \-rf raw/${PATH\_NUM}/  
   
ln \-s raw data 2\>&1 | tee \-a logs/01\_find\_alos.log.v1

**TIP:** A symlink is like a shortcut. Instead of copying large SAR zip files (each can be several gigabytes), you create lightweight pointer files. The actual data stays in the server archive.

## **6.2 Unzip FBS Only** {#6.2-unzip-fbs-only}

ALOS-1 PALSAR data comes in multiple polarization modes. For this workflow, only FBS (Fine Beam Single polarization, HH) is needed. The \--pol FBS flag filters out all other polarization modes so only the relevant acquisitions are extracted. This saves disk space and avoids processing data you do not need.

The script automatically reads from the data/ symlink created in Section 6.1. Do not pass a \--dir flag.

unzip\_ALOS-SLC-pol.py \--pol FBS 2\>&1 | tee logs/02\_unzip\_fbs.log.v1

**WARNING:** Do not use the \--dir flag. The script reads from the data/ symlink automatically. Passing \--dir will break the expected path.

## **6.3 Unpack to SLC** {#6.3-unpack-to-slc}

The ALOS-1 zip archives contain raw CEOS-format data. ISCE2 requires data in its own SLC (Single Look Complex) format. The run\_unpack\_all\_cli.py script converts all extracted acquisitions in the unzipped/ directory into ISCE2-compatible SLC scenes, writing them into the SLC/ directory.

After unpacking, count the scenes in SLC/ to confirm the expected number of acquisitions were processed successfully:

run\_unpack\_all\_cli.py 2\>&1 | tee logs/03\_unpack\_all.log.v1  
ls SLC/ | wc \-l

The count should match the number of ALOS-1 acquisition dates available for your path/frame. If the count is lower than expected, check the log for errors.

# **7\. Phase 2: DEM Preparation (SRTM Download)** {#7.-phase-2:-dem-preparation-(srtm-download)}

InSAR processing requires a Digital Elevation Model to remove topographic phase from the interferograms. This phase downloads SRTM 1 arc-second tiles from the ESA auxiliary data server and stitches them into a single DEM covering Central Luzon. The DEM is also used by MintPy for geometric corrections in later phases.

The bounding box (-b 14 18 120 123\) covers the latitude range 14°N–18°N and longitude range 120°E–123°E. Adjust these bounds if processing a frame outside this region.

mkdir \-p DEM && cd DEM  
dem.py \-a stitch \-b 14 18 120 123 \-r \-s 1 \-c \\  
    \-u http://step.esa.int/auxdata/dem/SRTMGL1/ \\  
    2\>&1 | tee ../logs/04\_dem.log.v1  
rm demLat\*.dem demLat\*.dem.xml demLat\*.dem.vrt  
cd ..

After dem.py completes, remove the intermediate per-tile files (demLat\*.dem and companions). Only the stitched and corrected .dem.wgs84 file is needed for subsequent processing.

| Flag | Meaning |
| :---- | :---- |
| \-a stitch | Download and stitch all tiles within the bounding box |
| \-b 14 18 120 123 | Bounding box: lat\_S lat\_N lon\_W lon\_E |
| \-r | Apply WGS84 ellipsoid reference |
| \-s 1 | 1 arc-second resolution (\~30 m) |
| \-c | Apply Earth curvature correction |
| \-u http://... | Download from the ESA STEP auxiliary data server |

# **8\. Phase 3: Stack Configuration and Baselines** {#8.-phase-3:-stack-configuration-and-baselines}

Phase 3 configures the interferometric stack — it determines which pairs of scenes will be processed into interferograms based on temporal and perpendicular baseline thresholds. This is a two-step process: first generate and review the pairs, then rebuild the stack with your chosen reference date.

Step 1: Run stackStripMap.py without a reference date. This generates the pairs.pdf file showing the full network of proposed interferogram pairs, the baseline plot, and temporal coverage. Review pairs.pdf carefully before proceeding.

stackStripMap.py \-W interferogram \--nofocus \\  
  \-s SLC \-d DEM/demLat\_N14\_N18\_Lon\_E120\_E123.dem.wgs84 \\  
  \-t 730 \-b 1500 \-a 28 \-r 12 \-u snaphu \\  
  2\>&1 | tee logs/05\_stack\_config.log.v1

The \-t 730 flag limits pairs to a maximum temporal baseline of 730 days (2 years). The \-b 1500 flag limits perpendicular baseline to 1500 meters. \-a 28 and \-r 12 set the azimuth and range looks for multi-looking. \-u snaphu specifies the unwrapping algorithm.

Step 2: After reviewing pairs.pdf and selecting your reference date, re-run with the \-m flag to rebuild the stack centered on that date. The run\_files/ directory is regenerated with the correct reference.

stackStripMap.py \-W interferogram \--nofocus \\  
  \-s SLC \-d DEM/demLat\_N14\_N18\_Lon\_E120\_E123.dem.wgs84 \\  
  \-t 730 \-b 1500 \-a 28 \-r 12 \-u snaphu \-m 20091111 \\  
  2\>&1 | tee \-a logs/05\_stack\_config.log.v1

**TIP:** 20091111 is the confirmed optimal reference date for Frame 0310\. For other frames, review pairs.pdf and select the scene with the most connections and a central position in the baseline plot.

# **9\. Phase 4: ISCE2 Processing Pipeline** {#9.-phase-4:-isce2-processing-pipeline}

Phase 4 runs the eight ISCE2 processing steps in sequence, converting your SLC scenes and DEM into filtered, unwrapped interferograms. Each run file is a shell script generated by stackStripMap.py in Phase 3\. Steps run\_01 through run\_07 must be run in order — they are sequential and each depends on the output of the previous step. run\_08 is the final and longest step.

| Run File | Method | Est. Time |
| :---- | :---- | :---- |
| run\_01\_reference | sh | \~10 min |
| run\_02\_focus\_split | sh | \~10 min |
| run\_03\_geo2rdr\_coarseResamp | parallel \-j4 | \~30 min |
| run\_04\_refineSecondaryTiming | parallel \-j4 | \~30 min |
| poststep04\_cleanup.py | python | \~2 min |
| run\_05\_invertMisreg | sh | \~5 min |
| run\_06\_fineResamp | parallel \-j4 | \~20 min |
| run\_07\_grid\_baseline | sh | \~5 min |
| run\_08\_igram | parallel \-j4 | 1–4+ hours |

## **9.1 Complete Command Sequence** {#9.1-complete-command-sequence}

run\_01\_reference focuses and processes the reference scene — the scene chosen in Phase 3 that all other scenes will be aligned to. This must complete without errors before any other run step can proceed.

run\_02\_focus\_split focuses all secondary scenes in the stack. Unlike run\_01, it does not perform alignment — it only generates the focused SLC products for each non-reference acquisition.

run\_03\_geo2rdr\_coarseResamp computes geometric coregistration offsets for every secondary scene relative to the reference. This step maps pixel coordinates from the reference geometry to each secondary scene. It runs in parallel across pairs using GNU Parallel.

run\_04\_refineSecondaryTiming refines the coregistration timing offsets computed in run\_03 using cross-correlation. This improves sub-pixel alignment accuracy. It also runs in parallel.

poststep04\_cleanup.py removes large intermediate files produced by run\_03 and run\_04 that are no longer needed. Running this step before run\_05 recovers significant disk space without affecting processing results.

run\_05\_invertMisreg combines all per-pair timing offsets into a stack-wide misregistration solution. It is run once as a single serial process.

run\_06\_fineResamp applies the final refined coregistration to all secondary scenes, producing fully coregistered SLC images ready for interferogram formation.

run\_07\_grid\_baseline computes the perpendicular baseline grid for each interferometric pair. This geometric product is required by MintPy in Phase 5\.

run\_08\_igram forms all the interferometric pairs: it generates filtered interferograms, coherence maps, and performs phase unwrapping. This is the heaviest step in the pipeline. Run it inside screen or tmux to keep it alive if your SSH connection drops.

echo "Starting run\_01" | tee logs/06\_run01.log.v1  
sh run\_files/run\_01\_reference 2\>&1 | tee \-a logs/06\_run01.log.v1  
   
echo "Starting run\_02" | tee logs/07\_run02.log.v1  
sh run\_files/run\_02\_focus\_split 2\>&1 | tee \-a logs/07\_run02.log.v1  
   
echo "Starting run\_03" | tee logs/08\_run03.log.v1  
parallel \-j 4 \< run\_files/run\_03\_geo2rdr\_coarseResamp 2\>&1 | tee \-a logs/08\_run03.log.v1  
   
echo "Starting run\_04" | tee logs/09\_run04.log.v1  
parallel \-j 4 \< run\_files/run\_04\_refineSecondaryTiming 2\>&1 | tee \-a logs/09\_run04.log.v1  
   
poststep04\_cleanup.py 2\>&1 | tee logs/10\_cleanup.log.v1  
   
echo "Starting run\_05" | tee logs/11\_run05.log.v1  
sh run\_files/run\_05\_invertMisreg 2\>&1 | tee \-a logs/11\_run05.log.v1  
   
echo "Starting run\_06" | tee logs/12\_run06.log.v1  
parallel \-j 4 \< run\_files/run\_06\_fineResamp 2\>&1 | tee \-a logs/12\_run06.log.v1  
   
echo "Starting run\_07" | tee logs/13\_run07.log.v1  
sh run\_files/run\_07\_grid\_baseline 2\>&1 | tee \-a logs/13\_run07.log.v1  
   
echo "Starting run\_08" | tee logs/14\_run08.log.v1  
parallel \-j 4 \< run\_files/run\_08\_igram 2\>&1 | tee \-a logs/14\_run08.log.v1

**WARNING:** run\_08 is the longest step and can take several hours. Run it inside screen (type screen before the command, and Ctrl+A then D to detach) so the job continues even if your SSH connection drops.

# **10\. Phase 4.5: Interferogram Visualization (Local Machine)** {#10.-phase-4.5:-interferogram-visualization-(local-machine)}

Phase 4.5 runs on your LOCAL machine. Before MintPy processing begins, you should visually inspect all interferograms to identify any badly unwrapped pairs, atmospheric artifacts, or low-coherence scenes. This phase downloads the filtered interferogram files from felix, generates JPEG images from the binary .int data, and assembles a multi-page report grid for review.

## **10.1 Prerequisites** {#10.1-prerequisites}

* Conda environment isce2\_local must be installed (Section 2.5)  
* Scripts linog\_save\_insar\_images.py and linog\_create\_grid.py must be in your local \~/bin/

## **10.2 Steps** {#10.2-steps}

Define the LOCAL run variables in your local terminal. These must match the frame you processed on felix:

export PATH\_NUM=448  
export FRAME\_NUM=0290  
export PADDED\_PATH=p${PATH\_NUM}  
export PADDED\_FRAME=f${FRAME\_NUM}  
export FRAME\_TAG=P${PATH\_NUM}F${FRAME\_NUM}  
export BASE\_DIR=$HOME/LInOG/insar  
export WORK\_DIR=${BASE\_DIR}/${PADDED\_PATH}/${PADDED\_FRAME}

Create the local Igrams directory and download all filtered interferogram files from felix using rsync. The wildcard filt\*.int\* matches both the complex phase file and its XML metadata. The \--progress flag shows transfer speed and estimated completion time.

mkdir \-p "${WORK\_DIR}/Igrams/logs"  
cd "${WORK\_DIR}/Igrams"  
   
rsync \-avh \--progress \\  
  "${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED\_PATH}/${PADDED\_FRAME}/interferograms/\*/filt\*.int\*" . \\  
  2\>&1 | tee logs/fetch\_igrams.log.v1

After the download completes, activate the visualization environment and run the two image-generation scripts. linog\_save\_insar\_images.py converts each binary .int file into a JPEG showing the interferometric phase and magnitude. linog\_create\_grid.py then assembles all individual images into report pages with labeled dates.

conda activate isce2\_local  
   
python linog\_save\_insar\_images.py 2\>&1 | tee logs/01\_save\_images.log.v1  
python linog\_create\_grid.py \--path "$PATH\_NUM" \--frame "$FRAME\_NUM" 2\>&1 | tee logs/02\_report\_grid.log.v1

## **10.3 Review and Upload** {#10.3-review-and-upload}

Open the generated report pages (${FRAME\_TAG}\_Igram\_Report\_Page\_\*.jpg) and review every interferogram. Flag any pairs with severe unwrapping errors, unusable coherence, or obvious atmospheric contamination — these may need to be excluded from MintPy. After review, upload the report pages back to felix so they are stored with the rest of the deliverables:

scp ${FRAME\_TAG}\_Igram\_Report\_Page\_\*.jpg \\  
  ${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED\_PATH}/${PADDED\_FRAME}/mintpy/geo/LInOG\_Upload\_${FRAME\_TAG}/

# **11\. Phase 5: MintPy Time-Series Analysis** {#11.-phase-5:-mintpy-time-series-analysis}

Phase 5 runs the full MintPy small-baseline time-series inversion. This converts the stack of unwrapped interferograms from Phase 4 into a displacement time series and mean LOS velocity map for every coherent pixel in the scene. The entire pipeline is driven by a single configuration file (smallbaselineApp.cfg) and runs automatically through all internal steps.

Navigate to the mintpy directory and run the application, piping all output to a log file. This step can take 30 minutes to several hours depending on the number of interferograms and scene size:

cd "${WORK\_DIR}/mintpy"  
smallbaselineApp.py smallbaselineApp.cfg 2\>&1 | tee ../logs/15\_mintpy.log.v1

When complete, verify the following output files exist in the geo/ subdirectory. These are the primary science products used in Phase 6:

* geo\_velocity\_demErr.h5 — mean LOS velocity with DEM error correction  
* geo\_velocity\_demErr\_ramp.h5 — mean LOS velocity with DEM error and orbital ramp correction  
* geo\_timeseries\_demErr.h5 — displacement time series with DEM error correction  
* geo\_timeseries\_ramp\_demErr.h5 — displacement time series with both corrections

# **12\. Phase 6: Geocoded Deliverables** {#12.-phase-6:-geocoded-deliverables}

Phase 6 generates all final deliverable files from the MintPy outputs. Every file is written into the LInOG\_Upload\_${FRAME\_TAG}/ folder — this folder is the single handoff package for each processed frame. All commands run from the mintpy/ directory on felix.

## **12.1 Velocity Hillshade PNGs** {#12.1-velocity-hillshade-pngs}

view.py generates hillshade-enhanced velocity map images by draping the velocity color scale over a terrain illumination model. The \-v \-10 10 flag sets the color scale range to ±10 mm/year. \--shade-exag 0.05 controls terrain relief exaggeration. \--nodisplay \--save writes the image directly to file without opening a GUI window. Two versions are generated: one for the demErr correction and one for the demErr\_ramp correction.

cd "${WORK\_DIR}/mintpy"  
   
MASK=geo/geo\_maskTempCoh.h5  
GEOM=geo/geo\_geometryRadar.h5  
OUT=geo/LInOG\_Upload\_${FRAME\_TAG}  
   
view.py geo/geo\_velocity\_demErr.h5 velocity \--mask $MASK \-d $GEOM \\  
    \-v \-10 10 \--shade-exag 0.05 \--nodisplay \--save \\  
    \-o $OUT/${FRAME\_TAG}\_Velocity\_Hillshade\_demErr.png \--dpi 600  
   
view.py geo/geo\_velocity\_demErr\_ramp.h5 velocity \--mask $MASK \-d $GEOM \\  
    \-v \-10 10 \--shade-exag 0.05 \--nodisplay \--save \\  
    \-o $OUT/${FRAME\_TAG}\_Velocity\_Hillshade\_demErr\_ramp.png \--dpi 600

## **12.2 Vertical and Horizontal Projections** {#12.2-vertical-and-horizontal-projections}

The LOS (Line-of-Sight) velocity measured by SAR is a combination of true vertical and horizontal ground motion, mixed by the satellite look angle. To separate the components, project the LOS velocity using the incidence angle (theta) from the geometry file. This calculation is done twice: once from the demErr velocity and once from the demErr\_ramp velocity.

V\_vert \= V\_LOS / cos(theta)    \<- vertical component  
V\_horz \= V\_LOS / sin(theta)    \<- horizontal component (range direction)

Use save\_gdal.py or view.py with the geometry file to perform the projection. Refer to the MintPy documentation for the exact command syntax for your version.

## **12.3 GeoTIFF and KMZ Exports** {#12.3-geotiff-and-kmz-exports}

save\_gdal.py exports the velocity and time-series HDF5 outputs to GeoTIFF format, which is compatible with QGIS, ArcGIS, and other GIS tools. save\_kmz.py generates a standard KMZ file that can be opened directly in Google Earth for spatial review of the velocity pattern.

## **12.4 Interactive KMZ** {#12.4-interactive-kmz}

linog\_gen\_interactive\_kmz.py generates a custom interactive KMZ that embeds displacement time-series charts directly in Google Earth. When a user clicks on any pixel, a popup shows the full time-series plot for that point. Run this script twice — once per correction type — to produce both demErr and demErr\_ramp interactive KMZs.

linog\_gen\_interactive\_kmz.py \--path "$PATH\_NUM" \--frame "$FRAME\_NUM" \--correction demErr  
linog\_gen\_interactive\_kmz.py \--path "$PATH\_NUM" \--frame "$FRAME\_NUM" \--correction demErr\_ramp

# **13\. Phase 7: Quality Control and Checklist** {#13.-phase-7:-quality-control-and-checklist}

Phase 7 is the final verification step before the frame is considered complete. The automation script (linog\_fbs\_processor.sh) prints a checklist of expected output files and marks each as present or missing. Verify all items show \[OK\] before handing off the deliverables.

After passing the checklist, sync the entire LInOG\_Upload\_${FRAME\_TAG}/ folder from felix to your local machine for archiving and final review. The \-P flag in rsync enables progress display and resumes partial transfers:

rsync \-avP ${USER}@felix:/eggraid/home/${USER}/projects/linog/insar/${PADDED\_PATH}/${PADDED\_FRAME}/mintpy/geo/LInOG\_Upload\_${FRAME\_TAG}/ ./${FRAME\_TAG}/

Open the downloaded folder locally and perform a final visual check: open the hillshade PNGs, load the KMZ files in Google Earth, and review the interferogram report pages. If any file is missing or visually incorrect, go back to the relevant phase and rerun.

# **14\. Script Reference** {#14.-script-reference}

The following LInOG scripts are used throughout this workflow. All are maintained in the GitHub repository (https://github.com/Ayiemeyzing/LInOG\_InSAR\_Processing). The repository copies under scripts/ are the authoritative versions with all bug fixes applied.

| Script | Purpose | Location |
| :---- | :---- | :---- |
| linog\_fbs\_processor.sh | Master automation: runs all phases end-to-end or per-phase | /eggraid/bin/ (in PATH) |
| linog\_save\_insar\_images.py | Converts binary .int files to phase and magnitude JPEGs | local \~/bin/ |
| linog\_create\_grid.py | Assembles interferogram images into labeled report pages | local \~/bin/ |
| linog\_gen\_interactive\_kmz.py | Generates interactive KMZ with embedded time-series charts | /eggraid/bin/ (in PATH) |

## **14.1 linog\_fbs\_processor.sh usage** {#14.1-linog_fbs_processor.sh-usage}

Run the master automation script with no argument to execute all phases end-to-end. Pass a phase number to start from a specific phase. Phase 4.5 runs the interferogram visualization on local; all other phases run on felix.

./linog\_fbs\_processor.sh          \# run all phases  
./linog\_fbs\_processor.sh 4        \# start from Phase 4  
./linog\_fbs\_processor.sh 4.5      \# run Phase 4.5 visualization only  
./linog\_fbs\_processor.sh 6        \# run Phase 6 deliverables only

## **14.2 linog\_create\_grid.py usage** {#14.2-linog_create_grid.py-usage}

Generate the interferogram report grid for the current frame. The \--path and \--frame arguments must match your run variables. Output pages are written to the current directory.

python linog\_create\_grid.py \--path "$PATH\_NUM" \--frame "$FRAME\_NUM"

## **14.3 linog\_gen\_interactive\_kmz.py usage** {#14.3-linog_gen_interactive_kmz.py-usage}

Generate interactive KMZ files. The \--correction argument accepts either demErr or demErr\_ramp. Use \--batch to process all frames in the project at once.

python linog\_gen\_interactive\_kmz.py \--path "$PATH\_NUM" \--frame "$FRAME\_NUM" \--correction demErr  
python linog\_gen\_interactive\_kmz.py \--batch

# **15\. Deliverables Checklist** {#15.-deliverables-checklist}

All deliverable files for a completed frame are stored in a single folder: LInOG\_Upload\_${FRAME\_TAG}/. This folder is the handoff package — it must contain exactly the files listed below before a frame is considered complete. The total count is 16 velocity/KMZ files plus N interferogram report pages.

## **15.1 demErr Correction** {#15.1-demerr-correction}

Eight files per frame using DEM error correction only:

| File | Type |
| :---- | :---- |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_demErr.png | LOS velocity hillshade |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_Vertical.png | Vertical component hillshade |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_Horizontal.png | Horizontal component hillshade |
| ${FRAME\_TAG}\_Velocity\_demErr.tif | LOS velocity GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_Vertical.tif | Vertical component GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_Horizontal.tif | Horizontal component GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_demErr.kmz | Standard Google Earth KMZ |
| ${FRAME\_TAG}\_TimeSeries\_demErr.kmz | Interactive KMZ with time series |

## **15.2 demErr\_ramp Correction** {#15.2-demerr_ramp-correction}

Eight files per frame using DEM error plus orbital ramp correction:

| File | Type |
| :---- | :---- |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_demErr\_ramp.png | LOS velocity hillshade |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_Vertical\_ramp.png | Vertical component hillshade |
| ${FRAME\_TAG}\_Velocity\_Hillshade\_Horizontal\_ramp.png | Horizontal component hillshade |
| ${FRAME\_TAG}\_Velocity\_demErr\_ramp.tif | LOS velocity GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_Vertical\_ramp.tif | Vertical component GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_Horizontal\_ramp.tif | Horizontal component GeoTIFF |
| ${FRAME\_TAG}\_Velocity\_demErr\_ramp.kmz | Standard Google Earth KMZ |
| ${FRAME\_TAG}\_TimeSeries\_demErr\_ramp.kmz | Interactive KMZ with time series |

## **15.3 Interferogram QC** {#15.3-interferogram-qc}

One or more report page images generated in Phase 4.5. The number of pages depends on how many interferograms were processed.

| File | Type |
| :---- | :---- |
| ${FRAME\_TAG}\_Igram\_Report\_Page\_1.jpg | Interferogram report grid, page 1 |
| ${FRAME\_TAG}\_Igram\_Report\_Page\_2.jpg | Interferogram report grid, page 2 |
| ${FRAME\_TAG}\_Igram\_Report\_Page\_N.jpg | Additional pages as needed |

Total: 16 velocity/KMZ files \+ N interferogram report pages per frame.

# **16\. Troubleshooting: Pre-Flight and Installation** {#16.-troubleshooting:-pre-flight-and-installation}

Use this section when the verification script from Section 1.6 reports \[FAIL\], or when any installation step in Sections 1–2 produces an error. Find the error message in the relevant table and apply the fix before retrying.

## **16.1 WSL2 Installation Errors (Windows)** {#16.1-wsl2-installation-errors-(windows)}

| Error | Fix |
| :---- | :---- |
| 0x80370102 | Enable virtualization (VT-x or AMD-V) in BIOS/UEFI |
| 0x8007019e | Run wsl \--install again as Administrator, then restart |
| Wrong Ubuntu version installed | wsl \--unregister Ubuntu, then reinstall Ubuntu-22.04 |
| No internet access inside WSL2 | Check VPN or firewall blocking WSL2 traffic |
| Could not resolve archive.ubuntu.com | Fix DNS in /etc/resolv.conf or disable VPN temporarily |
| conda: command not found after Miniforge install | Close and reopen terminal, or run source \~/.bashrc |

## **16.2 macOS Installation Errors** {#16.2-macos-installation-errors}

| Error | Fix |
| :---- | :---- |
| xcode-select: command not found | Run Software Update from the Apple menu |
| Miniforge installer blocked by Gatekeeper | Right-click the .sh file and choose Open with Terminal |
| PackagesNotFoundError for isce2 | Ensure you are using conda-forge channel with \-c conda-forge |
| conda activate fails with no output | Run conda init zsh or conda init bash for your shell |

## **16.3 Conda Environment Errors** {#16.3-conda-environment-errors}

| Error | Fix |
| :---- | :---- |
| ResolvePackageNotFound: isce2 | Ensure conda-forge is the default channel |
| Solver hangs for more than 30 minutes | Install mamba and use mamba install instead of conda install |
| PackageNotFoundError: isce2 | Add explicit \-c conda-forge flag to the install command |
| HTTP 000 CONNECTION FAILED | Check your network connection or corporate proxy settings |
| conda activate isce2 has no effect | Close and reopen your terminal, then retry |

## **16.4 ISCE2 Runtime Errors** {#16.4-isce2-runtime-errors}

| Error | Fix |
| :---- | :---- |
| No module named isce | You forgot to run load\_isce before using ISCE2 commands |
| which topsApp.py returns nothing | Check that \~/isce2.rc has the correct ISCE\_HOME path |
| Wrong Python version shown in ISCE\_HOME path | Edit \~/isce2.rc to match the Python version in your conda env |
| Stack scripts not found at runtime | Re-copy contrib/stack into $CONDA\_PREFIX/share/isce2 |
| Permission denied in \~/tools/src/isce2 | Clone the repository into a directory you own |

## **16.5 MintPy Install Errors** {#16.5-mintpy-install-errors}

| Error | Fix |
| :---- | :---- |
| GDAL: undefined symbol error at import | Delete and recreate the conda environment using conda only, not pip |
| smallbaselineApp.py: command not found | Run load\_isce to activate the isce2 environment |
| conda install mintpy hangs for \>30 min | Use mamba install \-c conda-forge mintpy instead |

## **16.6 Verification Script Failures** {#16.6-verification-script-failures}

| Failed check | Action |
| :---- | :---- |
| conda is installed | Redo Miniforge install from Section 1.2.5 or 1.3.2 |
| conda-forge is default | Run: conda config \--add channels conda-forge |
| conda-forge is default — false negative (copy-paste line break in script) | If conda config \--show channels already shows conda-forge, the script may have a copy-paste line break. Verify: sed \-n '22p' \~/check\_preflight.sh — the line must end with conda-forge" not with grep \-q. Fix: sed \-i '22{N; s/\\n/ /}' \~/check\_preflight.sh then re-run ./check\_preflight.sh. |
| git is installed | Install git as in Section 1.5 |
| vim is installed | Install vim as in Section 1.5 |
| vim is installed — APT refuses to install (orphaned package downgrade error) | An older orphaned version of vim files from a previously removed repository is blocking the install. APT refuses to automatically downgrade them. Fix: (1) Update the local package database to clear stale mirror references: sudo apt update (2) Install vim and downgrade the orphaned files simultaneously: sudo apt install \--allow-downgrades vim \-y |
| disk space | Clear at least 10 GB in your home directory before proceeding |

# **17\. Troubleshooting: Processing Pipeline** {#17.-troubleshooting:-processing-pipeline}

Use this section when errors occur during Phases 0–7. Most errors can be identified by searching the relevant log file for the keyword ERROR or Traceback.

| Error | Fix |
| :---- | :---- |
| event not found (bash) | Wrap arguments containing \! or $ in single quotes instead of double quotes |
| unzip \--dir: unrecognized option | The script does not accept \--dir; use the data-\>raw symlink as in Section 6.1 |
| DEM download fails with HTTP 401 | Check \~/.netrc credentials and run chmod 600 \~/.netrc |
| parallel jobs are very slow | Reduce \-j value from 4 to 2 if felix is under heavy load |
| SLC/ is empty after unpack | Re-run unzip step; verify the data/ symlink points to raw/ |
| MemoryError during ISCE2 run | Reduce \-j to 1 or 2 to lower peak memory usage |
| Qt: Could not connect to display (wayland) | Usually harmless; ISCE2 can still process without a display |
| tee: logs/...: No such file or directory | Run mkdir \-p logs before the processing command |

# **18\. Scientific References** {#18.-scientific-references}

Pepe, A., and Calo, F. (2017). A Review of Interferometric Synthetic Aperture RADAR (InSAR) Multi-Track Approaches for the Retrieval of Earth's Surface Displacements. Remote Sensing, 9(1), 16\.

Sandwell, D. T., et al. (2008). Accuracy and Resolution of ALOS Interferometry: A Vector Decomposition Approach for Ascending and Descending Passes. IEEE TGRS.

Werner, C., et al. (2007). PALSAR Multi-mode Interferometric Processing Using the GAMMA Software. IGARSS Proceedings.

Yunjun, Z., Fattahi, H., and Amelung, F. (2019). Small baseline InSAR time series analysis: Unwrapping error correction and noise reduction. Computers and Geosciences, 133, 104331\.

Reference resources: Lijun99 ISCE2 install guide | ISCE-framework GitHub repository (github.com/isce-framework/isce2) | MintPy GitHub repository (github.com/insarlab/MintPy)

**NOTE:** Some steps in this manual are environment-specific and must be verified on the actual deployment:  
/eggraid/... paths are specific to the felix server at NIGS — they do not exist on your local machine.  
find\_alos.sh, run\_unpack\_all\_cli.py, and poststep04\_cleanup.py are internal LInOG scripts, not part of ISCE2.  
The reference date 20091111 applies to Frame 0310 only — other frames require independent review.  
For the full script bug fix history and audit records, see ERRATA.md in the GitHub repository.

*— End of Document —*