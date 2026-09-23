<!--
DOCUMENT INFORMATION
Document Name: SPECIFICATIONS_GLOBAL.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v3.0.0
Date / Time: 2026-09-24 00:06
Project: bt_air_suite
Short description: Stable global repository specification.
-->
# SPECIFICATIONS_GLOBAL — bt_air_suite.sh — v3.0.0

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
├── EXAMPLES.md
├── SPECIFICATIONS.md
├── SPECIFICATIONS_GLOBAL.md
├── myinfo/
│   ├── known_devices.txt
│   ├── exclusionsbt.txt
│   ├── exclusionsbt_enrichi.txt
│   ├── exclusionsbt_oui_resolved.txt
│   └── oui.txt
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

`--profile redteam`, `--redteam` and `--aggressive-scan` select the Red Team inspection profile. The profile adds bounded Classic SDP enrichment for observed remote devices while still never implicitly chaining connection/pairing tests.

Direct profile aliases are stable:
- `--passive` -> `--profile passive`
- `--active` -> `--profile standard`
- `--redteam` -> `--profile redteam`

Explicit target-changing tests remain separate actions.

## 7. Acquisition timing

- `--duration` is seconds.
- `--interval` is minutes.
- `--interval` is monitor-only.
- every monitor slice gets a unique timestamp/collision-safe prefix;
- every slice uses `bluetoothctl --timeout SECONDS` for its real discovery window;
- slice membership comes only from BlueZ `Device <MAC>` events observed in that slice's raw scan output;
- local `Controller <MAC>` events are excluded from remote-device inventory;
- the last raw per-slice RSSI event is the primary RSSI source;
- a finite final slice uses only remaining seconds;
- infinite mode runs until interruption.

## 8. Inputs

```text
CLI arguments
Bluetooth controller
myinfo/known_devices.txt
myinfo/exclusionsbt.txt
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
- the generic suite does not implement jamming, forced disruption, destructive crash testing or aggressive fuzzing.

## 13. Non-functional requirements

- `bash -n bt_air_suite.sh` succeeds;
- no silent overwrite of acquisition slices;
- a materially early scan exit invalidates the slice and stops rolling monitor generation;
- soft-blocked or Powered=no controllers are rejected before discovery;
- predictable runtime paths;
- no password storage;
- sudo handled by sudo itself;
- `--nolog` suppresses only persistent `.log` files, not result data;
- cleanup/stop paths are bounded and explicit.

## 14. Acceptance criteria

- help and parser agree;
- current release version is v3.0.0;
- scan simulation parses;
- target actions reject missing/invalid MAC;
- interval is rejected outside monitor;
- each slice uses a distinct prefix;
- CSV and JSONL are generated from observed BlueZ data;
- filtered output honors exclusions;
- post-process can generate Markdown.


## v2.0.0 global requirements preserved in v3.0.0

### GFR-31 — Wi-Fi Air Suite interval parity

For Bluetooth `--monitor`:

- `--duration` is seconds;
- `--interval` is minutes;
- each interval receives an independent collision-safe prefix;
- a finite remainder becomes the final slice;
- `--archive-old` executes once before acquisition;
- `--post-process` executes after each completed slice before the next slice;
- post-process failure is reported without aborting subsequent valid scan intervals.

### GFR-32 — Kate parity

`--open-kate`:

- is valid only with `--scan` or `--monitor`;
- requires `--post-process`;
- requires the `kate` executable before acquisition;
- opens each newly generated `*.filtered.md`;
- uses asynchronous invocation so the scan loop does not wait for the editor.

### GFR-33 — canonical Bluetooth exclusion files

The canonical local files are:

```text
myinfo/exclusionsbt.txt
myinfo/exclusionsbt_enrichi.txt
myinfo/exclusionsbt_oui_resolved.txt
```

### GFR-34 — local OUI database

The canonical local database is `myinfo/oui.txt`.

`--update-oui` must:

1. download over HTTPS into a same-directory temporary file;
2. validate non-empty content, minimum size and a substantial count of IEEE `(base 16)` entries;
3. preserve the previous non-empty database as `myinfo/oui.txt.bak`;
4. atomically replace `myinfo/oui.txt` only after validation;
5. leave the current active OUI database unchanged on failed download or failed validation.

### GFR-35 — safe Bluetooth OUI attribution

Inventory output must expose address type, OUI prefix, vendor and OUI status.

Vendor attribution may be asserted only for BlueZ-public addresses. BLE random/private addresses must be marked as random/private and must not be presented as reliably OUI-resolved.

### GFR-36 — v2.0.0 runtime layout

```text
.results/
  raw/
  csv/
  jsonl/
  filtered/
  enriched/
  generated/
  captures/
  logs/
  tmp/
  archive/
```

### GFR-37 — Red Team preservation

The bounded Red Team SDP enrichment introduced before v2.0.0 remains explicit and non-destructive. It does not automatically connect, pair, trust, remove, jam, fuzz or crash devices.

## v3.0.0 global release requirements

### GFR-40 — major baseline continuity

v3.0.0 preserves every supported v2.0.0 business action, control action, parser option, output directory and inventory field. No existing behavior may disappear solely because of the major version bump.

### GFR-41 — Product Guide

The complete release package includes:

```text
bt_air_suite_v3.0.0_Product_Guide.pdf
```

The guide must document installation, CLI concepts, monitor intervals, post-processing, Kate behavior, OUI handling, address types, Red Team boundaries, target actions, runtime layout, examples, troubleshooting, limitations and version history.

### GFR-42 — documentation synchronization

README, INSTALL, CHANGELOG, WHY, EXAMPLES, SPECIFICATIONS and SPECIFICATIONS_GLOBAL must identify v3.0.0 as the current release while retaining historical version context where relevant.

### GFR-43 — exhaustive examples

`EXAMPLES.md` remains the exhaustive CLI command reference and must contain every option documented by `--help`, including compatibility aliases and reserved/rejected options.
