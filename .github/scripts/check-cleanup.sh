#!/usr/bin/env bash
#
# Runs vhr-bench the way the one-command instructions tell a user to, piped into bash
# with --cleanup, then checks that the cleanup kept its promise: sysbench and fio are
# gone and the installed package list is exactly what it was before the run. The smoke
# test runs it on the Ubuntu runner itself and inside distribution containers.
#
# Usage: bash .github/scripts/check-cleanup.sh [--require-readings]
#   --require-readings   also fail when the run exits non-zero or a reading is "not
#                        measured". Containers leave it off: fio often cannot use direct
#                        I/O on an overlay filesystem, and the cleanup must still be right.
set -uo pipefail

require_readings=0
if [[ "${1:-}" == --require-readings ]]; then require_readings=1; fi

# Name, architecture and install state of every package. Versions are left out so an
# existing library that apt upgrades as a dependency does not count as a difference;
# vhr-bench reports those upgrades itself.
list_packages() {
    if command -v dpkg-query >/dev/null 2>&1; then
        # shellcheck disable=SC2016 # ${...} is dpkg-query's format syntax
        dpkg-query -W -f='${binary:Package} ${db:Status-Abbrev}\n'
    elif command -v rpm >/dev/null 2>&1; then
        # Package signing keys are left out: dnf imports the repository's key the first
        # time it installs from it, and vhr-bench keeps it deliberately and says so.
        rpm -qa --qf '%{NAME}.%{ARCH}\n' | grep -v '^gpg-pubkey\.'
    else
        apk info
    fi | sort
}

failures=0
fail() { echo "::error::$*"; failures=$((failures + 1)); }

for tool in sysbench fio; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "::error::$tool is installed before the run, so this run would not test the cleanup."
        exit 1
    fi
done

list_packages > /tmp/packages-before.txt
echo "Packages before the run: $(wc -l < /tmp/packages-before.txt)"

cat vhr-bench | bash -s -- --cleanup --yes 2>&1 | tee /tmp/run.txt
status=${PIPESTATUS[1]}
echo "vhr-bench exited with status $status"

list_packages > /tmp/packages-after.txt
hash -r

grep -q "vhr-bench results" /tmp/run.txt || fail "The run did not reach its results."
grep -q "Cleanup: removed the" /tmp/run.txt || fail "The run did not report removing the packages it installed."
if grep -q "Cleanup: left installed" /tmp/run.txt; then fail "The cleanup left packages installed."; fi
for tool in sysbench fio; do
    if command -v "$tool" >/dev/null 2>&1; then fail "$tool is still installed after the run."; fi
done
# Compared in bash and listed with comm and awk, which every image here has (minimal
# images may lack diffutils).
if [[ "$(cat /tmp/packages-before.txt)" != "$(cat /tmp/packages-after.txt)" ]]; then
    fail "The package list differs from before the run (< only before, > only after):"
    comm -3 /tmp/packages-before.txt /tmp/packages-after.txt |
        awk '/^\t/ { sub(/^\t/, ""); print "> " $0; next } { print "< " $0 }'
fi
if [[ $require_readings -eq 1 ]]; then
    [[ $status -eq 0 ]] || fail "vhr-bench exited with status $status."
    if grep -q "not measured" /tmp/run.txt; then fail "A reading was not measured."; fi
fi

if [[ $failures -gt 0 ]]; then exit 1; fi
echo "Cleanup check passed: the package list matches the one from before the run."
