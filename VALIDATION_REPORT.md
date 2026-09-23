<!--
DOCUMENT INFORMATION
Document Name: VALIDATION_REPORT.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-09-23 07:57
Project: bt_air_suite
Short description: Executed validation summary for the v2.0.0 package.
-->
# Validation report — bt_air_suite v2.0.0

## Executed checks

- Bash syntax (`bash -n`): **OK**
- `--version`: **OK** (`v2.0.0`)
- `--help`: **OK**
- No-argument help behavior: **OK**
- `--changelog` preserves v2.0.0 + v1.1.2 + v1.1.1 + v1.1.0 + v1.0.0: **OK**
- Simulation of Red Team monitor + interval + post-process + Kate + nolog: **OK**
- Simulation of `--update-oui`: **OK**
- Parser/help CLI parity: **OK** (70 parser labels documented in help)
- Parser/EXAMPLES.md parity: **OK** (70 parser labels covered)
- Bundled OUI database validation: **OK** (6132821 bytes, 37577 base-16 entries)
- Canonical `myinfo/exclusionsbt.txt`: **OK**
- No legacy `myinfo/exclusions.txt`: **OK**
- No French specification files in the package: **OK** (explicit project choice)

## Executed mock integration tests

A controlled mock BlueZ environment was executed against the real v2.0.0 script:

- real bounded scan-window logic: **OK**
- local `Controller <MAC>` excluded from remote inventory: **OK**
- last per-slice RSSI preserved: **OK**
- public Samsung OUI resolution: **OK**
- public Sichuan AI-Link OUI resolution: **OK**
- random-static BLE address classification: **OK**
- no OUI vendor asserted for the random BLE address: **OK**
- exclusion filtering: **OK**
- Red Team bounded SDP report: **OK**
- asynchronous Kate invocation after filtered Markdown creation: **OK**

A controlled mock OUI update was also executed:

- valid update accepted: **OK**
- previous database saved as `oui.txt.bak`: **OK**
- validated temporary file atomically promoted to `oui.txt`: **OK**
- invalid update rejected: **OK**
- active OUI database preserved after invalid update: **OK**

## Anti-regression gate against v1.1.2

- Functions v1.1.2: 79
- Functions v2.0.0: 88
- Missing v1.1.2 functions: **0**
- Parser labels v1.1.2: 67
- Parser labels v2.0.0: 70
- Missing v1.1.2 CLI labels: **0**
- Script lines: 1670 → 2149
- Script bytes: 50826 → 68380

Status: **OK**

## Environment limitation

The build environment does not expose the user's physical Bluetooth adapter, so RF/BlueZ behavior on the real UB500 was not executed here. The real-device acceptance test remains the user's Kali run.
