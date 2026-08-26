#!/usr/bin/env bash
#
# uninstall.sh: removes the vhr-bench VPS benchmark tool and, optionally, the
# benchmark packages the installer added (sysbench, fio).
#
# It always removes /usr/local/bin/vhr-bench. It does NOT remove curl by default,
# because curl is a core system utility that was almost certainly present before
# installation and is relied on by many other tools. Pass --remove-curl to remove
# it anyway.
#
# Usage:
#   curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/uninstall.sh | sudo bash
#   sudo bash uninstall.sh --yes             (remove sysbench and fio without prompting)
#   sudo bash uninstall.sh --keep-packages   (remove only the vhr-bench binary)
#   sudo bash uninstall.sh --remove-curl     (also remove curl)
#
# License: MIT
set -euo pipefail

ASSUME_YES=0
KEEP_PACKAGES=0
REMOVE_CURL=0
BIN="/usr/local/bin/vhr-bench"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)        ASSUME_YES=1; shift ;;
        --keep-packages) KEEP_PACKAGES=1; shift ;;
        --remove-curl)   REMOVE_CURL=1; shift ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -n 18
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Please run as root (e.g. pipe to 'sudo bash')." >&2
    exit 1
fi

# 1. Remove the vhr-bench binary.
if [[ -f "$BIN" ]]; then
    rm -f "$BIN"
    echo "Removed $BIN."
else
    echo "$BIN was not present."
fi

# 2. Optionally remove the benchmark packages.
if [[ $KEEP_PACKAGES -eq 1 ]]; then
    echo "Leaving sysbench and fio installed (--keep-packages)."
    exit 0
fi

pkgs="sysbench fio"
if [[ $REMOVE_CURL -eq 1 ]]; then
    pkgs="$pkgs curl"
fi

if [[ $ASSUME_YES -eq 0 ]]; then
    echo "The installer added these benchmark packages: sysbench, fio."
    if [[ $REMOVE_CURL -eq 1 ]]; then
        echo "You also asked to remove curl. Removing curl can break other software that depends on it."
    else
        echo "curl is left in place (it is a core utility used by other software). Pass --remove-curl to override."
    fi
    read -r -p "Remove these packages now ($pkgs)? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "No packages were removed."; exit 0; }
fi

# Forgiving removal: a package a user already removed manually must not abort the run.
if   command -v apt-get >/dev/null 2>&1; then apt-get remove -y $pkgs || true
elif command -v dnf     >/dev/null 2>&1; then dnf remove -y $pkgs || true
elif command -v yum     >/dev/null 2>&1; then yum remove -y $pkgs || true
elif command -v zypper  >/dev/null 2>&1; then zypper remove -y $pkgs || true
elif command -v apk     >/dev/null 2>&1; then apk del $pkgs || true
else
    echo "No supported package manager found. Remove these manually: $pkgs" >&2
    exit 1
fi

echo "Uninstall complete."
