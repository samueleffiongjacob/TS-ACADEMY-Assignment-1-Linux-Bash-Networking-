# Assignment 1 — Linux, Bash & Networking Toolkit

A small set of Bash scripts that collect system information, check disk usage
and run basic network checks. Every action is written to a log file.

## Repository layout

```
assignment-1/
├── README.md
├── system-info.sh     # hostname, user, OS, kernel, uptime, CPU, memory ...
├── disk-check.sh      # disk usage vs. a threshold
├── network-check.sh   # resolve, ping, interfaces, optional TCP port test
├── grade.sh           # local grading script
└── logs/
    └── .gitkeep       # keeps the empty logs/ folder in Git
```

## Installation / setup

Requirements: a Linux shell with Bash 4+ and the usual core tools
(`df`, `awk`, `getent`, `timeout`). `ping`, `ip` and `free` are used when
present; the scripts fall back gracefully when they are not.

```bash
git clone <your-repository-url>
cd <repository>
chmod +x *.sh
```

## Usage

### system-info.sh
```bash
./system-info.sh
```
Prints hostname, current user, date/time, OS, kernel, uptime, CPU, memory and
the current working directory. All values are read at runtime.

### disk-check.sh
```bash
./disk-check.sh <threshold> [path]
./disk-check.sh 80            # check "/" against 80 %
./disk-check.sh 90 /home      # check /home against 90 %
```
| Exit code | Meaning                                              |
|-----------|------------------------------------------------------|
| 0         | usage is **below** the threshold                     |
| 1         | usage **reached/exceeded** the threshold (or df failed) |
| 2         | invalid input (threshold not 1–100, unknown path, wrong argument count) |

### network-check.sh
```bash
./network-check.sh <hostname-or-ip> [port]
./network-check.sh localhost
./network-check.sh example.com 443
```
Validates input, resolves the host, pings it once, lists network interfaces and
(optionally) tests a TCP port (1–65535).

| Exit code | Meaning                                                     |
|-----------|-------------------------------------------------------------|
| 0         | all checks that ran succeeded                               |
| 1         | a check failed (no resolution, no ping reply, port closed)  |
| 2         | invalid host, invalid port or wrong argument count          |

## Logging

All scripts append to `logs/toolkit.log`. Each line has a timestamp, a level
and the script name, for example:

```
2025-01-31 10:15:00 [INFO] [disk-check.sh] Path=/ usage=42% threshold=80% -> OK
2025-01-31 10:15:02 [ERROR] [disk-check.sh] Invalid input: threshold must be an integer from 1 to 100 (got 'abc')
```

Log files are ignored by Git (see `.gitignore`); only `logs/.gitkeep` is committed.

## Testing

```bash
./grade.sh                     # runs the full local grader
bash -n system-info.sh disk-check.sh network-check.sh   # syntax check only

# manual checks
./disk-check.sh 0;   echo "exit=$?"    # expect 2
./disk-check.sh 100; echo "exit=$?"    # expect 0 or 1
./network-check.sh localhost 0; echo "exit=$?"   # expect 2
```

## Assumptions

- Target platform is Linux; no cloud services or root access are needed.
- A missing optional tool (`ping`, `ip`, `free`) is reported as "skipped"
  instead of being treated as a failure.
- If `ping` replies are blocked (some containers/firewalls), `network-check.sh`
  reports the ping as failed and exits `1`, even if the host resolves.
- Exit code `1` on a disk-usage warning is intentional so the script can be used
  in cron jobs and CI.
- No secrets, tokens or machine-specific paths are stored in the repository.

## Git workflow

Work was done on a feature branch (`feature/scripts`) with small commits and
then merged into `main`.
