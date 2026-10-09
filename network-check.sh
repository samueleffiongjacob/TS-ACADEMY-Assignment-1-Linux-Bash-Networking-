#!/usr/bin/env bash
# =============================================================================
# network-check.sh - Basic network diagnostics for a host.
#
# Usage : ./network-check.sh <hostname-or-ip> [port]
#
# What it does:
#   1. Validates the host (and port, if given)
#   2. Resolves the host and prints the resolved address
#   3. Pings it once (basic connectivity check)
#   4. Shows network interface information
#   5. If a port was given, tests TCP connectivity to it
#
# Exit codes:
#   0 = every check that ran succeeded
#   1 = a check failed (cannot resolve, no ping reply, port closed)
#   2 = invalid input (bad host, bad port, wrong argument count)
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/toolkit.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
    printf '%s [%s] [network-check.sh] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$LOG_FILE" 2>/dev/null || true
}

usage() {
    echo "Usage: $0 <hostname-or-ip> [port]" >&2
    echo "  Example: $0 example.com 443" >&2
}

invalid() {
    echo "Error: $1" >&2
    usage
    log ERROR "Invalid input: $1"
    exit 2
}

# ---- Validation helpers -----------------------------------------------------

# is_valid_ipv4 STRING : four numbers, each 0-255
is_valid_ipv4() {
    local ip="$1" octet
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    local IFS=.
    for octet in $ip; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}

# is_valid_host STRING : IPv4, IPv6, or a DNS-style hostname
is_valid_host() {
    local host="$1"
    (( ${#host} >= 1 && ${#host} <= 253 )) || return 1

    # Looks like a dotted-number address? Then it MUST be a valid IPv4.
    if [[ "$host" =~ ^[0-9.]+$ ]]; then
        is_valid_ipv4 "$host"
        return
    fi
    # IPv6: hex digits and colons only, at least one colon.
    if [[ "$host" == *:* ]]; then
        [[ "$host" =~ ^[0-9A-Fa-f:]+$ ]]
        return
    fi
    # Hostname: letters, digits, dots, hyphens; must not start/end with - or .
    [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

# is_valid_port STRING : integer 1-65535
is_valid_port() {
    [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

# ---- 1. Validate arguments --------------------------------------------------
if [[ $# -lt 1 || $# -gt 2 ]]; then
    invalid "expected 1 or 2 arguments, got $#"
fi

HOST="$1"
PORT="${2:-}"

is_valid_host "$HOST" || invalid "invalid hostname or IP address: '$HOST'"
if [[ -n "$PORT" ]]; then
    is_valid_port "$PORT" || invalid "port must be an integer from 1 to 65535 (got '$PORT')"
fi

log INFO "Started check: host=$HOST port=${PORT:-none}"
STATUS=0    # becomes 1 if any check fails

# ---- 2. Resolve the host ----------------------------------------------------
echo "=== Host resolution ==="
RESOLVED=""
if command -v getent >/dev/null 2>&1; then
    # `getent ahosts` uses the system resolver (/etc/hosts + DNS).
    RESOLVED="$(getent ahosts "$HOST" 2>/dev/null | awk 'NR==1 {print $1}')"
elif is_valid_ipv4 "$HOST"; then
    RESOLVED="$HOST"   # already an address, nothing to resolve
fi

if [[ -n "$RESOLVED" ]]; then
    echo "Host     : $HOST"
    echo "Resolved : $RESOLVED"
    log INFO "Resolved $HOST -> $RESOLVED"
else
    echo "Could not resolve '$HOST'"
    log ERROR "Could not resolve $HOST"
    STATUS=1
fi

# ---- 3. Basic connectivity (ping) -------------------------------------------
echo
echo "=== Connectivity (ping) ==="
if [[ -z "$RESOLVED" ]]; then
    echo "Skipped: host did not resolve"
elif ! command -v ping >/dev/null 2>&1; then
    # A missing tool is not the host's fault, so we do not count it as a failure.
    echo "Skipped: 'ping' is not installed"
    log WARN "ping not installed - connectivity check skipped"
elif timeout 5 ping -c 1 -W 2 "$HOST" >/dev/null 2>&1; then
    echo "Ping reply received from $HOST"
    log INFO "Ping to $HOST succeeded"
else
    echo "No ping reply from $HOST (host down, or ICMP blocked)"
    log WARN "Ping to $HOST failed"
    STATUS=1
fi

# ---- 4. Network interfaces --------------------------------------------------
echo
echo "=== Network interfaces ==="
if command -v ip >/dev/null 2>&1; then
    ip -brief address 2>/dev/null || ip address
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig
elif [[ -d /sys/class/net ]]; then
    # Last resort: just list interface names known to the kernel.
    ls /sys/class/net
else
    echo "No tool available to list interfaces"
fi

# ---- 5. Optional TCP port check ---------------------------------------------
if [[ -n "$PORT" ]]; then
    echo
    echo "=== TCP port check ==="
    if [[ -z "$RESOLVED" ]]; then
        echo "Skipped: host did not resolve"
    # Bash can open TCP connections itself via /dev/tcp/<host>/<port>.
    # The host and port are passed as arguments ($1, $2) - never pasted into
    # the command string - so odd input cannot inject commands.
    elif timeout 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$HOST" "$PORT" 2>/dev/null; then
        echo "Port $PORT on $HOST is OPEN"
        log INFO "TCP $HOST:$PORT open"
    else
        echo "Port $PORT on $HOST is CLOSED or unreachable"
        log WARN "TCP $HOST:$PORT closed/unreachable"
        STATUS=1
    fi
fi

echo
if [[ $STATUS -eq 0 ]]; then
    echo "Result: all checks passed"
else
    echo "Result: one or more checks failed"
fi
log INFO "Finished check for $HOST with status $STATUS"
exit "$STATUS"
