<!--
DOCUMENT INFORMATION
Document Name: EXAMPLES.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-09-23 07:57
Project: bt_air_suite
Short description: Exhaustive command examples and behavior reference for every supported bt_air_suite.sh action and option.
-->
# bt_air_suite.sh v2.0.0 — Exhaustive Examples

This document is the exhaustive operator-oriented command reference for the v2.0.0 CLI.

All commands assume the current directory contains `bt_air_suite.sh`.

## 1. General rules

Real operational Bluetooth actions use:

```bash
./bt_air_suite.sh --exec --<action> [OPTIONS]
```

Simulation uses:

```bash
./bt_air_suite.sh --simulate --<action> [OPTIONS]
```

Control/information actions such as `--help`, `--version`, `--changelog`, `--prerequis`, `--doctor`, `--status`, `--init`, `--show-paths`, `--print-config`, `--list-results` and `--update-oui` do not require `--exec`.

No argument:

```bash
./bt_air_suite.sh
```

Behavior: displays the full help and performs no business action.

## 2. Help, version and changelog

Full help:

```bash
./bt_air_suite.sh --help
```

Short alias:

```bash
./bt_air_suite.sh -h
```

Version:

```bash
./bt_air_suite.sh --version
```

Complete internal changelog:

```bash
./bt_air_suite.sh --changelog
```

Short alias:

```bash
./bt_air_suite.sh -ch
```


## 2.1 Compatibility aliases

Simulation compatibility alias:

```bash
./bt_air_suite.sh --dry-run --scan -d 20
```

Prerequisite compatibility aliases:

```bash
./bt_air_suite.sh --prereq
./bt_air_suite.sh --check-prereq
```

Runtime purge compatibility alias:

```bash
./bt_air_suite.sh --clean-runtime
```

These map respectively to `--simulate`, `--prerequis` and `--purge`.

## 3. Prerequisites

Check prerequisites:

```bash
./bt_air_suite.sh --prerequis
```

Short alias:

```bash
./bt_air_suite.sh -pr
```

The check covers the required BlueZ/runtime commands and reports optional `sdptool`, Kate and OUI-update tooling separately.

Install the supported package set:

```bash
./bt_air_suite.sh --install
```

Short alias:

```bash
./bt_air_suite.sh -i
```

Simulate package installation:

```bash
./bt_air_suite.sh --simulate --install
```

## 4. Initialize project/runtime layout

```bash
./bt_air_suite.sh --init
```

Creates the expected `myinfo/` and `.results/` directories/files if missing.

## 5. Paths and resolved configuration

Show paths:

```bash
./bt_air_suite.sh --show-paths
```

Show the resolved invocation configuration:

```bash
./bt_air_suite.sh --print-config
```

Example with custom options:

```bash
./bt_air_suite.sh --print-config \
  --controller hci0 \
  --transport le \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

## 6. Status and doctor

Read Bluetooth/BlueZ/rfkill status:

```bash
./bt_air_suite.sh --status
```

Full doctor view:

```bash
./bt_air_suite.sh --doctor
```

## 7. OUI database

Update the local IEEE OUI database:

```bash
./bt_air_suite.sh --update-oui
```

Simulation:

```bash
./bt_air_suite.sh --simulate --update-oui
```

Successful behavior:

1. HTTPS download to a temporary file under `myinfo/`;
2. validation;
3. backup of the previous non-empty database as `myinfo/oui.txt.bak`;
4. atomic replacement of `myinfo/oui.txt`;
5. regeneration of Bluetooth exclusion enrichment files.

Files:

```text
myinfo/oui.txt
myinfo/oui.txt.bak
myinfo/exclusionsbt_enrichi.txt
myinfo/exclusionsbt_oui_resolved.txt
```

A failed download or validation leaves the active `oui.txt` unchanged.

## 8. Power control

Power on:

```bash
./bt_air_suite.sh --exec --power-on
```

Simulation:

```bash
./bt_air_suite.sh --simulate --power-on
```

If Bluetooth is soft-blocked through rfkill, `--power-on` first clears the Bluetooth soft block.

Power off:

```bash
./bt_air_suite.sh --exec --power-off
```

Simulation:

```bash
./bt_air_suite.sh --simulate --power-off
```

## 9. Secure controller state

```bash
./bt_air_suite.sh --exec --secure
```

Simulation:

```bash
./bt_air_suite.sh --simulate --secure
```

The secure action requests:

```text
power on
pairable off
discoverable off
```

## 10. One-shot scan

Default one-shot scan:

```bash
./bt_air_suite.sh --exec --scan
```

Simulation:

```bash
./bt_air_suite.sh --simulate --scan
```

Explicit 30-second scan:

```bash
./bt_air_suite.sh --exec --scan --duration 30
```

Equivalent short duration form:

```bash
./bt_air_suite.sh --exec --scan -d 30
```

LE-only discovery:

```bash
./bt_air_suite.sh --exec --scan --transport le -d 30
```

BR/EDR-only discovery:

```bash
./bt_air_suite.sh --exec --scan --transport bredr -d 30
```

Automatic transport:

```bash
./bt_air_suite.sh --exec --scan --transport auto -d 30
```

Passive profile:

```bash
./bt_air_suite.sh --exec --scan --passive -d 30
```

Standard/active profile:

```bash
./bt_air_suite.sh --exec --scan --active -d 30
```

Red Team profile:

```bash
./bt_air_suite.sh --exec --scan --redteam -d 30
```

Equivalent profile syntax:

```bash
./bt_air_suite.sh --exec --scan --profile redteam -d 30
```

Compatibility alias:

```bash
./bt_air_suite.sh --exec --scan --aggressive-scan -d 30
```

## 11. One-shot scan with post-processing

```bash
./bt_air_suite.sh --exec --scan \
  --duration 60 \
  --post-process
```

Generated result families include raw, CSV, JSONL, filtered CSV, filtered Markdown, enriched CSV and generated copies.

Disable post-processing explicitly:

```bash
./bt_air_suite.sh --exec --scan \
  --duration 60 \
  --no-post-process
```

## 12. One-shot scan with Kate — exact Wi-Fi Air Suite behavior

```bash
./bt_air_suite.sh --exec --scan \
  --duration 60 \
  --post-process \
  --open-kate
```

Behavior:

```text
scan completes
→ filtered CSV generated
→ filtered Markdown generated
→ enriched CSV generated
→ Kate receives the new filtered Markdown asynchronously
```

`--open-kate` requires `--post-process`.

## 13. Monitor: finite session without interval

One 5-minute discovery slice:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300
```

With post-processing:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --post-process
```

With Red Team:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --post-process
```

Without `--interval`, a finite monitor uses one full-duration scan slice.

## 14. Monitor: finite interval session

Five one-minute slices:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1
```

Five one-minute slices with post-processing:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process
```

Full Red Team example:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

Full Red Team + Kate example:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

This matches the Wi-Fi suite's interval/post-process/Kate workflow: each completed interval is processed before the next interval begins, and every generated filtered Markdown is opened asynchronously.

## 15. Monitor: remainder interval

Total 650 seconds with 5-minute intervals:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 650 \
  --interval 5 \
  --post-process
```

Expected slice lengths:

```text
300 seconds
300 seconds
50 seconds
```

## 16. Monitor: infinite interval loop

Explicit infinite monitor with ten-minute slices:

```bash
./bt_air_suite.sh --exec --monitor \
  --infinite \
  --interval 10
```

With post-processing:

```bash
./bt_air_suite.sh --exec --monitor \
  --infinite \
  --interval 10 \
  --post-process
```

With post-processing, Kate and no persistent logs:

```bash
./bt_air_suite.sh --exec --monitor \
  --infinite \
  --interval 10 \
  --post-process \
  --open-kate \
  --nolog
```

Stop with CTRL-C or from another terminal using `--stop`.

## 17. Monitor without duration and without interval

```bash
./bt_air_suite.sh --exec --monitor
```

Because non-interactive BlueZ discovery is bounded internally, v2.0.0 implements this as repeated 60-second slices until interruption.

## 18. `--accept`

Compatibility with the Wi-Fi suite:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process \
  --accept
```

`--accept` does not bypass sudo and does not automatically authorize pairing/connection actions.

## 19. `--nolog`

Disable persistent runtime `.log` files while keeping scan/result artifacts:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

Alias:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process \
  --no-log
```

## 20. Archive old runtime results

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --archive-old
```

With post-processing:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --archive-old \
  --post-process
```

Archiving runs once before the first acquisition slice.

## 21. Custom runtime destination

Relative path:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --dest-dir .results_test
```

Equivalent spelling:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --dest_dir .results_test
```

Absolute path:

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --dest-dir /tmp/bt_air_results
```

Combine with post-processing/Kate:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --dest-dir .results_v200_test \
  --post-process \
  --open-kate \
  --nolog
```

## 22. Custom exclusion file

Default:

```text
myinfo/exclusionsbt.txt
```

Override:

```bash
./bt_air_suite.sh --exec --scan \
  -d 60 \
  --post-process \
  --exclusions-file ./myinfo/another_exclusions_file.txt
```

Short form:

```bash
./bt_air_suite.sh --exec --scan \
  -d 60 \
  --post-process \
  -X ./myinfo/another_exclusions_file.txt
```

Exclusions affect filtered output; raw acquisition is preserved.

## 23. Known-device file

Default:

```text
myinfo/known_devices.txt
```

Override:

```bash
./bt_air_suite.sh --exec --scan \
  -d 60 \
  --known-file ./myinfo/known_devices_lab.txt
```

Known devices are labeled through the inventory `status` field.

## 24. Bluetooth address type and OUI fields

v2.0.0 CSV/JSONL inventory contains:

```text
timestamp
mac
address_type
oui_prefix
vendor
oui_status
label
name
alias
rssi
tx_power
icon
paired
trusted
connected
status
uuids
```

OUI states include:

```text
OUI_RESOLVED
OUI_NOT_FOUND
RANDOM_ADDRESS
NOT_APPLICABLE
```

Public address example:

```text
address_type=public
oui_prefix=7C:64:56
vendor=Samsung Electronics Co.,Ltd
oui_status=OUI_RESOLVED
```

Random/private BLE addresses are not presented as reliably vendor-resolved.

## 25. Controller selection

Automatic controller:

```bash
./bt_air_suite.sh --exec --scan \
  --controller auto \
  -d 30
```

HCI interface for actions that consume HCI interface names:

```bash
./bt_air_suite.sh --exec --capture-btmon \
  --controller hci0 \
  -d 60
```

Controller MAC form:

```bash
./bt_air_suite.sh --exec --secure \
  --controller AA:BB:CC:DD:EE:FF
```

## 26. Fingerprint a target

```bash
./bt_air_suite.sh --exec --fingerprint \
  --target AA:BB:CC:DD:EE:FF
```

Simulation:

```bash
./bt_air_suite.sh --simulate --fingerprint \
  --target AA:BB:CC:DD:EE:FF
```

Profile flag can still be supplied for consistent operator context:

```bash
./bt_air_suite.sh --exec --fingerprint \
  --target AA:BB:CC:DD:EE:FF \
  --redteam
```

## 27. Enumerate services

```bash
./bt_air_suite.sh --exec --enum-services \
  --target AA:BB:CC:DD:EE:FF
```

Simulation:

```bash
./bt_air_suite.sh --simulate --enum-services \
  --target AA:BB:CC:DD:EE:FF
```

The action records BlueZ UUID/device information and uses bounded `sdptool browse` when `sdptool` exists.

## 28. RSSI monitor

Default 60-second RSSI monitor:

```bash
./bt_air_suite.sh --exec --rssi-monitor \
  --target AA:BB:CC:DD:EE:FF
```

Explicit duration:

```bash
./bt_air_suite.sh --exec --rssi-monitor \
  --target AA:BB:CC:DD:EE:FF \
  --duration 120
```

Poll every second:

```bash
./bt_air_suite.sh --exec --rssi-monitor \
  --target AA:BB:CC:DD:EE:FF \
  --duration 120 \
  --rssi-poll 1
```

Poll every five seconds:

```bash
./bt_air_suite.sh --exec --rssi-monitor \
  --target AA:BB:CC:DD:EE:FF \
  --duration 120 \
  --rssi-poll 5
```

Simulation:

```bash
./bt_air_suite.sh --simulate --rssi-monitor \
  --target AA:BB:CC:DD:EE:FF \
  -d 60
```

## 29. btmon / HCI capture

Default 60 seconds:

```bash
./bt_air_suite.sh --exec --capture-btmon \
  --controller hci0
```

Two-minute capture:

```bash
./bt_air_suite.sh --exec --capture-btmon \
  --controller hci0 \
  --duration 120
```

Simulation:

```bash
./bt_air_suite.sh --simulate --capture-btmon \
  --controller hci0 \
  -d 60
```

Output is stored under `.results/captures/` as a btsnoop file.

## 30. Explicit connection test

Authorized target only:

```bash
./bt_air_suite.sh --exec --connect-test \
  --target AA:BB:CC:DD:EE:FF
```

Simulation:

```bash
./bt_air_suite.sh --simulate --connect-test \
  --target AA:BB:CC:DD:EE:FF
```

This action connects, records information, then disconnects.

## 31. Explicit pairing test

Authorized/owned target only:

```bash
./bt_air_suite.sh --exec --pair-test \
  --target AA:BB:CC:DD:EE:FF
```

Pair and remove the local pairing record afterwards:

```bash
./bt_air_suite.sh --exec --pair-test \
  --target AA:BB:CC:DD:EE:FF \
  --cleanup-pair
```

Simulation:

```bash
./bt_air_suite.sh --simulate --pair-test \
  --target AA:BB:CC:DD:EE:FF \
  --cleanup-pair
```

## 32. Red Team profile

One Red Team scan:

```bash
./bt_air_suite.sh --exec --scan \
  --redteam \
  -d 60
```

Red Team monitor:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1
```

Red Team monitor with full result workflow:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

For each observed remote target, the Red Team profile can perform bounded Classic SDP enumeration when `sdptool` is installed.

It does not automatically perform connection or pairing tests.

## 33. Profile syntax variants

Passive:

```bash
./bt_air_suite.sh --exec --scan --profile passive -d 60
./bt_air_suite.sh --exec --scan --passive -d 60
```

Standard:

```bash
./bt_air_suite.sh --exec --scan --profile standard -d 60
./bt_air_suite.sh --exec --scan --active -d 60
```

Red Team:

```bash
./bt_air_suite.sh --exec --scan --profile redteam -d 60
./bt_air_suite.sh --exec --scan --redteam -d 60
./bt_air_suite.sh --exec --scan --aggressive-scan -d 60
```

## 34. Transport syntax variants

Auto:

```bash
./bt_air_suite.sh --exec --scan --transport auto -d 60
```

BLE / LE:

```bash
./bt_air_suite.sh --exec --scan --transport le -d 60
```

Classic BR/EDR:

```bash
./bt_air_suite.sh --exec --scan --transport bredr -d 60
```

## 35. Hotplug installation for TP-Link UB500

Default VID:PID:

```bash
./bt_air_suite.sh --exec --hotplug-install
```

Explicit default:

```bash
./bt_air_suite.sh --exec --hotplug-install \
  --ub500-id 2357:0604
```

Another lab VID:PID:

```bash
./bt_air_suite.sh --exec --hotplug-install \
  --ub500-id 1234:ABCD
```

Simulation:

```bash
./bt_air_suite.sh --simulate --hotplug-install \
  --ub500-id 2357:0604
```

## 36. Hotplug inspection

```bash
./bt_air_suite.sh --exec --hotplug-test
```

Simulation:

```bash
./bt_air_suite.sh --simulate --hotplug-test
```

## 37. Remove hotplug support

```bash
./bt_air_suite.sh --exec --hotplug-remove
```

Simulation:

```bash
./bt_air_suite.sh --simulate --hotplug-remove
```

## 38. Stop an active suite invocation

```bash
./bt_air_suite.sh --stop
```

Short alias:

```bash
./bt_air_suite.sh -st
```

Simulation:

```bash
./bt_air_suite.sh --simulate --stop
```

## 39. List runtime results

```bash
./bt_air_suite.sh --list-results
```

With another runtime root:

```bash
./bt_air_suite.sh --dest-dir .results_v200_test --list-results
```

## 40. Purge runtime files

```bash
./bt_air_suite.sh --purge
```

Short alias:

```bash
./bt_air_suite.sh -pu
```

Simulation:

```bash
./bt_air_suite.sh --simulate --purge
```

`myinfo/` is not purged.

## 41. Combined practical workflows

### 41.1 Normal five-minute scan, unknowns visible in filtered output

```bash
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

### 41.2 Red Team five-minute scan with Kate

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

### 41.3 BLE-only five-minute scan

```bash
./bt_air_suite.sh --exec --monitor \
  --transport le \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

### 41.4 Classic-only five-minute Red Team scan

```bash
./bt_air_suite.sh --exec --monitor \
  --transport bredr \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

### 41.5 Archive previous runtime before a fresh acquisition

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --archive-old \
  --post-process \
  --open-kate \
  --nolog
```

### 41.6 Isolated test result directory

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --dest-dir .results_v200_test \
  --post-process \
  --open-kate \
  --nolog
```

### 41.7 Refresh OUI then scan

```bash
./bt_air_suite.sh --update-oui
./bt_air_suite.sh --exec --monitor \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

## 42. Files generated by a normal interval scan

Typical per-slice files:

```text
.results/raw/<prefix>.raw.txt
.results/csv/<prefix>.csv
.results/jsonl/<prefix>.jsonl
.results/filtered/<prefix>.filtered.csv
.results/filtered/<prefix>.filtered.md
.results/enriched/<prefix>.enriched.csv
```

Red Team can additionally generate:

```text
.results/raw/<prefix>.redteam.txt
```

Copies of post-processed artifacts are placed under:

```text
.results/generated/
```

Temporary per-slice MAC membership data is placed under:

```text
.results/tmp/
```

## 43. Important option compatibility

Valid:

```bash
./bt_air_suite.sh --simulate --scan -d 20
./bt_air_suite.sh --exec --scan -d 20
./bt_air_suite.sh --exec --monitor --duration 300 --interval 1
./bt_air_suite.sh --exec --monitor --duration 300 --interval 1 --post-process --open-kate
```

Invalid:

```text
--exec without a business action
--exec together with --simulate
--interval with an action other than --monitor
--open-kate without --post-process
--open-kate with fingerprint/services/RSSI/connect/pair/hotplug actions
target actions without --target
```

## 44. Red Team safety boundary

The generic v2.0.0 Red Team profile supports bounded discovery/enumeration behavior and keeps state-changing connection/pairing tests as separate explicit actions.

The generic suite does not implement:

```text
RF jamming
forced disruption
destructive crash testing
aggressive fuzzing
automatic connect/pair chains
```


## 44.1 Reserved `--lab-destructive`

The parser recognizes the reserved name:

```bash
./bt_air_suite.sh --lab-destructive
```

v2.0.0 intentionally rejects it with an explicit error. No destructive lab action is implemented behind this flag.

## 45. Canonical operator command

For the workflow discussed for this project:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

This creates five independent one-minute scan slices, post-processes every completed slice, opens every newly generated filtered Markdown in Kate asynchronously, keeps persistent `.log` files disabled, preserves raw/result data and runs bounded Red Team service enrichment.
