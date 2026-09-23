<!--
DOCUMENT INFORMATION
Document Name: SPECIFICATIONS.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.2
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
-->

# SPECIFICATIONS — Initial unified Bluetooth Swiss Army Knife — v1.1.2

## 1. Purpose

Create the first unified release of `bt_air_suite.sh` from the useful Bluetooth controller, scan, hotplug and investigation concepts.

## 2. Functional requirements

### FR-1 — single entry point

All supported capabilities are exposed through:

```text
bt_air_suite.sh
```

### FR-2 — explicit execution gate

Operational actions require either:

```text
--exec
```

or:

```text
--simulate
```

### FR-3 — discovery transport

```text
--transport auto
--transport le
--transport bredr
```

### FR-4 — one-shot scan

`--scan` performs one bounded discovery and writes raw + CSV + JSONL inventory.

### FR-5 — rolling monitor

`--monitor` repeats discovery slices.

### FR-6 — duration compatibility

`--duration` is seconds.

### FR-7 — interval

`--interval` is minutes and monitor-only.

### FR-8 — post-processing

`--post-process` creates a filtered CSV and Markdown representation.

### FR-9 — exclusions

Excluded MACs are removed from filtered output only.

### FR-10 — known baseline

MACs listed in `known_devices.txt` receive status `known`; others receive `unknown`.

### FR-11 — fingerprint

`--fingerprint --target MAC` records BlueZ device information.

### FR-12 — service enumeration

`--enum-services --target MAC` records UUID information and Classic SDP when `sdptool` exists.

### FR-13 — btmon capture

`--capture-btmon` records a bounded btsnoop trace.

### FR-14 — RSSI monitor

`--rssi-monitor --target MAC` samples RSSI while discovery is active.

### FR-15 — connection test

`--connect-test --target MAC` performs one explicit connect/info/disconnect test.

### FR-16 — pairing test

`--pair-test --target MAC` performs one explicit pairing test.

### FR-17 — cleanup pairing

`--cleanup-pair` removes the local pairing record after `--pair-test`.

### FR-18 — secure controller

`--secure` powers on the controller and disables pairable/discoverable mode.

### FR-19 — power control

Explicit `--power-on` and `--power-off`.

### FR-20 — Direct profile aliases

The CLI exposes:

```text
--passive  -> --profile passive
--active   -> --profile standard
--redteam  -> --profile redteam
```

`--aggressive-scan` remains a compatibility alias for the Red Team profile.

The Red Team profile selects more aggressive inspection defaults but does not automatically invoke connection/pairing tests.

### FR-21 — no-log

`--nolog` disables persistent `.log` files while preserving result data.

### FR-22 — UB500 hotplug

Install/remove/test actions preserve the useful secure-on-attach concept for a configurable `VVVV:PPPP` USB ID.


### FR-23 — real scan duration

Discovery must use BlueZ non-interactive timeout semantics:

```text
bluetoothctl --timeout SECONDS scan on|le|bredr
```

A scan that exits materially before the requested duration is invalid.

### FR-24 — per-slice observed membership

CSV/JSONL membership must be derived from MAC addresses actually present in the raw output of the current scan slice.

A global cached BlueZ device list must not define membership for the slice.

### FR-25 — scan readiness

Discovery must reject a controller that is soft-blocked or `Powered=no` and print the exact corrective command.

### FR-26 — power-on recovery

`--power-on` must clear a Bluetooth rfkill soft block before issuing BlueZ `power on`.


### FR-27 — exclude the local controller

Slice membership must be extracted from BlueZ `Device <MAC>` events only.

`Controller <MAC>` events must never create CSV/JSONL rows.

### FR-28 — RSSI source priority

For each remote device:

1. use the last RSSI event observed inside the exact raw slice;
2. fall back to `bluetoothctl info` only when the raw slice contains no RSSI.

### FR-29 — Red Team active enrichment

When `PROFILE=redteam`, every completed discovery slice must run a bounded active Classic SDP enumeration step for observed remote devices when `sdptool` is available.

The enrichment:
- has an 8-second timeout per target;
- processes at most 12 targets per slice;
- creates `.results/raw/<prefix>.redteam.txt`;
- never automatically connects, pairs, trusts or removes a device.

### FR-30 — Red Team separation

`--connect-test` and `--pair-test` remain explicit actions and are never implicitly triggered by `--redteam`.

## 3. Out of scope for v1.0.0

```text
RF jamming
forced Bluetooth disruption
destructive crash testing
aggressive protocol fuzzing
automatic exploit execution
```

## 4. Validation

```bash
bash -n bt_air_suite.sh
./bt_air_suite.sh --help
./bt_air_suite.sh --version
./bt_air_suite.sh --simulate --scan --transport le -d 20
./bt_air_suite.sh --simulate --monitor --duration 125 --interval 1
./bt_air_suite.sh --simulate --fingerprint --target AA:BB:CC:DD:EE:FF
./bt_air_suite.sh --simulate --capture-btmon --controller hci0 -d 30
./bt_air_suite.sh --simulate --secure
```
