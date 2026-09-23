<!--
DOCUMENT INFORMATION
Document Name: SPECIFICATIONS_GLOBAL.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.0.0
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
-->

# SPECIFICATIONS_GLOBAL — bt_air_suite.sh — v1.0.0

## 1. Purpose

Define stable project-wide behavior for the Bluetooth Swiss Army Knife.

## 2. Durable entry point

```text
bt_air_suite.sh
```

## 3. Execution contract

1. No arguments show help only.
2. Exactly one action is selected.
3. Real operational actions require `--exec`.
4. Simulations use `--simulate` and perform no Bluetooth/system change.
5. Read-only information actions may run without `--exec`.
6. No acquisition action implicitly starts another Red Team action.

## 4. Repository architecture

```text
bt_air_suite/
├── bt_air_suite.sh
├── README.md
├── INSTALL.md
├── CHANGELOG.md
├── WHY.md
├── SPECIFICATIONS.md
├── SPECIFICATIONS_FR.md
├── SPECIFICATIONS_GLOBAL.md
├── SPECIFICATIONS_GLOBAL_FR.md
├── myinfo/
│   ├── known_devices.txt
│   └── exclusions.txt
└── .results/
```

## 5. Functional scope

The suite supports:

- controller/BlueZ status;
- Classic + BLE discovery;
- rolling monitoring;
- device fingerprinting;
- service/UUID enumeration;
- RSSI tracking;
- HCI capture through btmon;
- authorized connection tests;
- authorized pairing tests;
- secure local controller state;
- controller power control;
- UB500-style hotplug support;
- filtering and generated Markdown;
- known/excluded device baselines.

## 6. Red Team profile

`--profile redteam` and `--aggressive-scan` increase inspection intensity but do not implicitly chain connection/pairing tests.

Explicit target-changing tests remain separate actions.

## 7. Acquisition timing

- `--duration` is seconds.
- `--interval` is minutes.
- `--interval` is monitor-only.
- every monitor slice gets a unique timestamp/collision-safe prefix;
- a finite final slice uses only remaining seconds;
- infinite mode runs until interruption.

## 8. Inputs

```text
CLI arguments
Bluetooth controller
myinfo/known_devices.txt
myinfo/exclusions.txt
explicit target MAC
```

## 9. Outputs

```text
.results/
├── raw/
├── csv/
├── jsonl/
├── filtered/
├── generated/
├── captures/
├── logs/
├── tmp/
└── archive/
```

## 10. Data contract

Inventory should contain, when BlueZ exposes them:

```text
timestamp
MAC
label
Name
Alias
RSSI
TxPower
Icon
Paired
Trusted
Connected
known/unknown classification
UUIDs
```

Missing properties remain empty; they are not invented.

## 11. Filtering contract

- known devices remain present with status `known`;
- exclusions are removed only from filtered outputs;
- raw acquisition remains preserved;
- MAC address alone is not proof of physical identity.

## 12. Safety / operational boundary

- connection and pairing tests require explicit target + execution gate;
- `--pair-test` may change pairing state;
- `--cleanup-pair` removes the local pairing record after the test;
- generic v1.0.0 does not implement jamming, forced disruption, destructive crash testing or aggressive fuzzing.

## 13. Non-functional requirements

- `bash -n bt_air_suite.sh` succeeds;
- no silent overwrite of acquisition slices;
- predictable runtime paths;
- no password storage;
- sudo handled by sudo itself;
- `--nolog` suppresses only persistent `.log` files, not result data;
- cleanup/stop paths are bounded and explicit.

## 14. Acceptance criteria

- help and parser agree;
- version is v1.0.0;
- scan simulation parses;
- target actions reject missing/invalid MAC;
- interval is rejected outside monitor;
- each slice uses a distinct prefix;
- CSV and JSONL are generated from observed BlueZ data;
- filtered output honors exclusions;
- post-process can generate Markdown.
