#!/usr/bin/env bash
# =============================================================================
# system-info.sh - Print key facts about the machine this script runs on.
#
# Usage : ./system-info.sh
# Output: hostname, user, date/time, OS, kernel, uptime, CPU, memory, cwd
# Exit  : 0 = success
#
# Every value is read from the system at runtime (nothing is hardcoded).
# =============================================================================

# -u : treat unset variables as errors (catches typos).
# We do NOT use -e here, because a missing optional tool (e.g. `free`)
# should not abort the whole report - each section has its own fallback.
set -u

# ---- Logging setup ----------------------------------------------------------
# Logs live in <script folder>/logs so the script works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/toolkit.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# log LEVEL MESSAGE  ->  "2025-01-31 10:15:00 [INFO] [system-info.sh] message"
log() {
    printf '%s [%s] [system-info.sh] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$LOG_FILE" 2>/dev/null || true
}

# ---- Helper functions (each one tries the best tool, then falls back) -------

get_hostname() {
    hostname 2>/dev/null || uname -n
}

get_user() {
    whoami 2>/dev/null || id -un
}

get_os() {
    # /etc/os-release is the standard place on modern Linux distributions.
    if [[ -r /etc/os-release ]]; then
        # Run in a subshell so its variables do not leak into this script.
        ( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-Linux}}" )
    else
        uname -s
    fi
}

get_uptime() {
    # `uptime -p` gives "up 2 hours, 5 minutes" but is not on every system.
    if uptime -p >/dev/null 2>&1; then
        uptime -p
    elif [[ -r /proc/uptime ]]; then
        # /proc/uptime: first field = seconds since boot.
        awk '{
            s = int($1); d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60)
            printf "up %d days, %d hours, %d minutes\n", d, h, m
        }' /proc/uptime
    else
        echo "unavailable"
    fi
}

get_cpu() {
    local model cores
    model="$(grep -m1 -i 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')"
    cores="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
    echo "${model:-$(uname -m)} (${cores} cores)"
}

show_memory() {
    if command -v free >/dev/null 2>&1; then
        free -h
    elif [[ -r /proc/meminfo ]]; then
        # Fallback: read the totals straight from the kernel (values are in kB).
        awk '/^MemTotal|^MemAvailable/ {printf "%-14s %8.0f MB\n", $1, $2/1024}' /proc/meminfo
    else
        echo "unavailable"
    fi
}

# ---- Main report ------------------------------------------------------------
log INFO "Started system report"

echo "=============================================="
echo "              SYSTEM INFORMATION"
echo "=============================================="
echo "Hostname          : $(get_hostname)"
echo "Current user      : $(get_user)"
echo "Date/time         : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Operating system  : $(get_os)"
echo "Kernel version    : $(uname -r)"
echo "Uptime            : $(get_uptime)"
echo "CPU               : $(get_cpu)"
echo "Working directory : $(pwd)"
echo "----------------------------------------------"
echo "Memory:"
show_memory
echo "=============================================="

log INFO "Finished system report for host $(get_hostname)"
exit 0
