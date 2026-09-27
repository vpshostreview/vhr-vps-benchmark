#!/usr/bin/env bash
#
# uninstall.sh: removes the vhr-bench VPS benchmark tool and, optionally, the
# benchmark packages sysbench and fio.
#
# It always removes /usr/local/bin/vhr-bench. The installer keeps no record of which
# packages it installed, so sysbench and fio are removed even if they were installed
# before vhr-bench, and the package manager also removes any package that depends on
# them; the prompt says so before anything goes. It does NOT remove curl by default,
# because curl is a core system utility that was almost certainly present before
# installation and is relied on by many other tools. Pass --remove-curl to remove
# it anyway.
#
# The commands and options are in usage() just below, or run it with --help.
#
# Everything below is a function until the last line, which calls main, so bash has read
# the whole script before anything runs. When it is piped into bash, a download cut off
# partway runs nothing, and a package manager that reads its input finds the end of the
# pipe rather than the rest of this script.
#
# License: MIT

usage() {
    cat <<'EOF'
uninstall.sh: removes the vhr-bench VPS benchmark tool and, optionally, the
benchmark packages sysbench and fio.

It always removes /usr/local/bin/vhr-bench. sysbench and fio are removed even if
they were installed before vhr-bench, and your package manager also removes any
package that depends on them. It does NOT remove curl by default,
because curl is a core system utility that was almost certainly present before
installation and is relied on by many other tools. Pass --remove-curl to remove
it anyway.

Usage:
  curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/uninstall.sh | sudo bash
  sudo bash uninstall.sh --yes             (remove sysbench and fio without prompting)
  sudo bash uninstall.sh --keep-packages   (remove only the vhr-bench binary)
  sudo bash uninstall.sh --remove-curl     (also remove curl)

License: MIT
EOF
}

main() {
    set -euo pipefail

    local ASSUME_YES=0 KEEP_PACKAGES=0 REMOVE_CURL=0
    local BIN="/usr/local/bin/vhr-bench"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)        ASSUME_YES=1; shift ;;
            --keep-packages) KEEP_PACKAGES=1; shift ;;
            --remove-curl)   REMOVE_CURL=1; shift ;;
            -h|--help)       usage; exit 0 ;;
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

    local pkgs=(sysbench fio) reply=""
    if [[ $REMOVE_CURL -eq 1 ]]; then
        pkgs+=(curl)
    fi

    if [[ $ASSUME_YES -eq 0 ]]; then
        echo "It can also remove the benchmark packages sysbench and fio. Answer y only if nothing"
        echo "else on this server needs them: they are removed even if they were installed before"
        echo "vhr-bench, and your package manager also removes any package that depends on them."
        if [[ $REMOVE_CURL -eq 1 ]]; then
            echo "You also asked to remove curl. Removing curl can break other software that depends on it."
        else
            echo "curl is left in place (it is a core utility used by other software). Pass --remove-curl to override."
        fi
        # When invoked as `curl ... | sudo bash`, stdin is the pipe, not the terminal, so read
        # from the controlling terminal. The device is opened as the test rather than checked
        # with -r, because /dev/tty exists even where there is no terminal and only opening it
        # fails. With no terminal (truly non-interactive), do not guess.
        if [[ -t 0 ]]; then
            read -r -p "Remove these packages now (${pkgs[*]})? [y/N] " reply || true
        elif (: </dev/tty) 2>/dev/null; then
            read -r -p "Remove these packages now (${pkgs[*]})? [y/N] " reply </dev/tty || true
        else
            echo "No terminal available to confirm (for example when piped to bash)." >&2
            echo "Re-run with --yes to remove sysbench and fio, or --keep-packages to remove only the tool." >&2
            exit 0
        fi
        [[ "$reply" =~ ^[Yy]$ ]] || { echo "No packages were removed."; exit 0; }
    fi

    # Forgiving removal: a package a user already removed manually must not abort the run.
    if   command -v apt-get >/dev/null 2>&1; then apt-get remove -y "${pkgs[@]}" || true
    elif command -v dnf     >/dev/null 2>&1; then dnf remove -y "${pkgs[@]}" || true
    elif command -v yum     >/dev/null 2>&1; then yum remove -y "${pkgs[@]}" || true
    elif command -v zypper  >/dev/null 2>&1; then zypper remove -y "${pkgs[@]}" || true
    elif command -v apk     >/dev/null 2>&1; then apk del "${pkgs[@]}" || true
    else
        echo "No supported package manager found. Remove these manually: ${pkgs[*]}" >&2
        exit 1
    fi

    echo "Uninstall complete."
}

# The braces make a download cut off inside this line an unclosed group that bash
# refuses to run, rather than a partial command.
{ main "$@"; }
