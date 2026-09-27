#!/usr/bin/env bash
#
# install.sh: installs the vhr-bench VPS benchmark tool into /usr/local/bin.
#
# Read this script before running it as root. It:
#   1. Installs the runtime dependencies (sysbench, fio, curl) via your package manager.
#   2. Downloads the vhr-bench attached to the latest release (or, when VHR_BENCH_REF
#      names a tag or branch, the vhr-bench at that point in the repository) and
#      installs it to /usr/local/bin/vhr-bench.
#
# The release copy is the default because it is the one each release's SHA256SUMS
# describes and the one the one-command run downloads, so all three agree. A branch
# such as main can hold changes no release has published yet.
#
# Usage:
#   curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/install.sh | sudo bash
#   curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/install.sh | sudo VHR_BENCH_REF=v1.3.0 bash
#
# Everything below is a function until the last line, which calls main, so bash has read
# the whole script before anything runs. When it is piped into bash, a download cut off
# partway runs nothing, and a package manager that reads its input finds the end of the
# pipe rather than the rest of this script.
#
# License: MIT

main() {
    set -euo pipefail

    local SOURCE="https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/vhr-bench"
    local FROM="latest release"
    local DEST="/usr/local/bin/vhr-bench"
    if [[ -n "${VHR_BENCH_REF:-}" ]]; then
        SOURCE="https://raw.githubusercontent.com/vpshostreview/vhr-vps-benchmark/${VHR_BENCH_REF}/vhr-bench"
        FROM="$VHR_BENCH_REF"
    fi

    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Please run as root (e.g. pipe to 'sudo bash')." >&2
        exit 1
    fi

    echo "Installing dependencies (sysbench, fio, curl)…"
    # Two statements, not "update && install": set -e ignores a failure on the left of &&,
    # which would let a failed update go on to report a successful install.
    if   command -v apt-get >/dev/null 2>&1; then apt_update; apt_get install -y --no-remove sysbench fio curl
    elif command -v dnf     >/dev/null 2>&1; then dnf install -y sysbench fio curl
    elif command -v yum     >/dev/null 2>&1; then yum install -y sysbench fio curl
    elif command -v zypper  >/dev/null 2>&1; then ZYPP_LOCK_TIMEOUT=300 zypper install -y sysbench fio curl
    elif command -v apk     >/dev/null 2>&1; then apk add sysbench fio curl
    else
        echo "No supported package manager found. Install sysbench, fio, and curl manually." >&2
        exit 1
    fi

    echo "Downloading vhr-bench (${FROM})…"
    curl -fsSL "$SOURCE" -o "$DEST"
    chmod +x "$DEST"

    echo "Installed to ${DEST}."
    echo "Run it with:  vhr-bench"
    echo "To upload a result to your account, add --token YOUR_UPLOAD_TOKEN"
    echo "(get one at https://vpshostreview.com/user/benchmarks)."
}

# apt-get waits up to five minutes for the dpkg lock instead of failing at once while
# another package manager holds it, as unattended upgrades often does in the first
# minutes after a server boots. apt 1.9.11 and later honor DPkg::Lock::Timeout; older
# apt ignores options it does not know and fails at once, as it always did. --no-remove
# stops apt rather than let it remove software to make room for these tools.
apt_get() { apt-get -o DPkg::Lock::Timeout=300 "$@"; }

# apt-get update takes the package-list lock, which DPkg::Lock::Timeout does not cover,
# so a failure that names that lock is retried for up to five minutes. Any other failure
# returns at once, with apt's own message already on screen.
apt_update() {
    local log tries=0
    log="$(mktemp)"
    until apt_get update 2>&1 | tee "$log"; do
        if ! grep -q "/lists/lock" "$log" || (( ++tries > 30 )); then
            rm -f "$log"
            echo "apt-get update failed (its message is above)." >&2
            return 1
        fi
        if [[ $tries -eq 1 ]]; then
            echo "Another process is updating the package lists. Waiting up to five minutes for it to finish…"
        fi
        sleep 10
    done
    rm -f "$log"
}

# The braces make a download cut off inside this line an unclosed group that bash
# refuses to run, rather than a partial command.
{ main "$@"; }
