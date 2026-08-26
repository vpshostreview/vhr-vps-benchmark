#!/usr/bin/env bash
#
# install.sh — installs the vhr-bench VPS benchmark tool into /usr/local/bin.
#
# Read this script before running it as root. It:
#   1. Installs the runtime dependencies (sysbench, fio, curl) via your package manager.
#   2. Downloads the vhr-bench script from the pinned release and installs it to
#      /usr/local/bin/vhr-bench.
#
# Usage:
#   curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/install.sh | sudo bash
#
# License: MIT
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/vpshostreview/vhr-vps-benchmark"
REF="${VHR_BENCH_REF:-main}"
DEST="/usr/local/bin/vhr-bench"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Please run as root (e.g. pipe to 'sudo bash')." >&2
    exit 1
fi

echo "Installing dependencies (sysbench, fio, curl)…"
if   command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y sysbench fio curl
elif command -v dnf     >/dev/null 2>&1; then dnf install -y sysbench fio curl
elif command -v yum     >/dev/null 2>&1; then yum install -y sysbench fio curl
elif command -v zypper  >/dev/null 2>&1; then zypper install -y sysbench fio curl
elif command -v apk     >/dev/null 2>&1; then apk add sysbench fio curl
else
    echo "No supported package manager found. Install sysbench, fio, and curl manually." >&2
    exit 1
fi

echo "Downloading vhr-bench (${REF})…"
curl -fsSL "${REPO_RAW}/${REF}/vhr-bench" -o "$DEST"
chmod +x "$DEST"

echo "Installed to ${DEST}."
echo "Run it with:  vhr-bench --token YOUR_UPLOAD_TOKEN"
echo "Get your token at https://vpshostreview.com/user/benchmarks"
