#!/usr/bin/env bash
# =============================================================================
# disk-check.sh - Warn when disk usage reaches a threshold.
#
# Usage : ./disk-check.sh <threshold> [path]
#           threshold : integer 1-100 (percent)
#           path      : file or directory to check (default: /)
#
# Exit codes:
#   0 = usage is BELOW the threshold
#   1 = usage REACHED or EXCEEDED the threshold (or df failed)
#   2 = invalid input (bad threshold, unknown path, wrong argument count)
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/toolkit.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
    printf '%s [%s] [disk-check.sh] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$LOG_FILE" 2>/dev/null || true
}

usage() {
    echo "Usage: $0 <threshold 1-100> [path]" >&2
    echo "  Example: $0 80 /home" >&2
}

# invalid MESSAGE -> print the problem, log it, exit with code 2
invalid() {
    echo "Error: $1" >&2
    usage
    log ERROR "Invalid input: $1"
    exit 2
}

# ---- 1. Validate arguments --------------------------------------------------
if [[ $# -lt 1 || $# -gt 2 ]]; then
    invalid "expected 1 or 2 arguments, got $#"
fi

THRESHOLD="$1"
TARGET="${2:-/}"          # default path is /

# Only 1-3 digits allowed. This also blocks "-5", "abc", "1.5" and giant numbers
# that could overflow Bash arithmetic.
if [[ ! "$THRESHOLD" =~ ^[0-9]{1,3}$ ]]; then
    invalid "threshold must be an integer from 1 to 100 (got '$THRESHOLD')"
fi
# "10#" forces base 10 so a value such as "08" is not read as (invalid) octal.
THRESHOLD=$((10#$THRESHOLD))
if (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    invalid "threshold must be between 1 and 100 (got '$THRESHOLD')"
fi

if [[ ! -e "$TARGET" ]]; then
    invalid "path does not exist: $TARGET"
fi

# ---- 2. Read disk usage -----------------------------------------------------
# df -P = POSIX format (one line per filesystem, so parsing is predictable).
# Line 2, column 5 is "Use%" e.g. "42%". gsub removes the % sign.
USAGE="$(df -P "$TARGET" 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"

if [[ ! "$USAGE" =~ ^[0-9]+$ ]]; then
    echo "Error: could not read disk usage for '$TARGET'" >&2
    log ERROR "df failed for path $TARGET"
    exit 1
fi

# ---- 3. Compare and report --------------------------------------------------
echo "Path      : $TARGET"
echo "Usage     : ${USAGE}%"
echo "Threshold : ${THRESHOLD}%"

if (( USAGE >= THRESHOLD )); then
    echo "Status    : WARNING - usage has reached or exceeded the threshold"
    log WARN "Path=$TARGET usage=${USAGE}% threshold=${THRESHOLD}% -> THRESHOLD REACHED"
    exit 1
fi

echo "Status    : OK - usage is below the threshold"
log INFO "Path=$TARGET usage=${USAGE}% threshold=${THRESHOLD}% -> OK"
exit 0
