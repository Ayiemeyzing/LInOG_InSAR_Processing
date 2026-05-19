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
  . /etc/os-release
  echo "Distro: $PRETTY_NAME"
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
FREE_GB=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$FREE_GB" -ge 10 ]; then
  echo "[OK]   disk space ($FREE_GB GB free in $HOME)"
  PASS=$((PASS+1))
else
  echo "[FAIL] disk space ($FREE_GB GB free; need >=10GB)"
  FAIL=$((FAIL+1))
fi

echo
echo "=== Result: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo 'You are ready for Section 2 of the manual.'
else
  echo 'See Section 16 (Troubleshooting) for each [FAIL] item.'
fi
