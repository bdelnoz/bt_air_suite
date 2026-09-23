<!--
DOCUMENT INFORMATION
Document Name: README.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-09-23 07:57
Project: bt_air_suite
Short description: Main documentation for the Bluetooth/BLE air suite.
-->
# bt_air_suite.sh — v2.0.0

## Purpose

`bt_air_suite.sh` is a single durable Bluetooth/BLE Swiss Army Knife for Linux/Kali.

It merges the useful concepts of the previous Bluetooth scripts into one CLI entry point and mirrors the operational philosophy of `wifi_air_suite.sh`: explicit actions, `--exec` / `--simulate`, runtime isolation, interval acquisition, post-processing and predictable output paths.

The Wi-Fi reference separates capture/check/crack/attack actions and uses one explicit execution gate. The Bluetooth suite preserves the same design principle.



## v1.1.2 — remote-only inventory, RSSI capture and real Red Team enrichment

v1.1.2 fixes three issues confirmed by the first real v1.1.1 acquisition.

### Local controller exclusion

BlueZ emits controller events such as:

```text
[CHG] Controller E8:48:B8:C8:20:00 Discovering: yes
```

and remote-device events such as:

```text
[CHG] Device 54:F1:5F:7F:C1:0B RSSI: 0xffffffcc (-52)
```

Only `Device <MAC>` events now define slice membership. The local controller MAC is never exported as a discovered remote device.

### RSSI from the actual slice

RSSI is dynamic and may no longer be present in `bluetoothctl info` after discovery stops.

v1.1.2 therefore stores the **last RSSI event seen for each device inside the current raw scan window**. `bluetoothctl info` is only a fallback.

### Red Team is now behaviorally different

`--redteam` / `--profile redteam` now means:

```text
normal timed discovery
→ remote-only per-slice inventory
→ bounded active Classic SDP browse for observed remote devices
→ dedicated *.redteam.txt report
```

The active enrichment is bounded to 8 seconds per target and at most 12 targets per slice.

It does **not** automatically connect, pair, trust, remove, jam, fuzz or crash a device.

## v1.1.1 scan timing and slice isolation

v1.1.1 corrects the interval behavior observed during the first real Red Team monitor test.

A scan slice now uses:

```text
bluetoothctl --timeout SECONDS scan on|le|bredr
```

The non-interactive BlueZ client therefore remains active for the requested scan window.

Each result set is built from MAC addresses extracted from the **raw output of that exact slice**. The suite no longer uses a global `bluetoothctl devices` listing as the source of slice membership, because BlueZ can retain device objects after discovery.

If a scan returns materially earlier than requested, the slice is rejected and a rolling monitor stops instead of creating misleading interval files.

Before discovery, the suite also verifies that Bluetooth is not soft-blocked and that the controller is powered. Use:

```bash
./bt_air_suite.sh --exec --power-on
```

to clear a Bluetooth rfkill soft block and power the controller on.

## Main script

```text
bt_air_suite.sh
```

## Main action families

| Family | Actions |
|---|---|
| Discovery | `--scan`, `--monitor` |
| Investigation | `--fingerprint`, `--enum-services`, `--rssi-monitor` |
| Capture | `--capture-btmon` |
| Authorized lab tests | `--connect-test`, `--pair-test` |
| Controller | `--status`, `--secure`, `--power-on`, `--power-off` |
| Hotplug | `--hotplug-install`, `--hotplug-remove`, `--hotplug-test` |
| Maintenance | `--doctor`, `--init`, `--list-results`, `--purge`, `--stop` |

## Red Team profile

```bash
./bt_air_suite.sh --exec --monitor \
  --profile redteam \
  --infinite \
  --interval 1 \
  --post-process
```

`--passive`, `--active` and `--redteam` are direct profile aliases. `--aggressive-scan` remains a compatibility alias for the Red Team profile.

The Red Team profile is deliberately focused on active discovery, fingerprinting, service enumeration, connection/pairing tests, RSSI monitoring and HCI capture. The generic suite does not implement RF jamming, forced disruption, destructive crash testing or aggressive fuzzing.

## Canonical execution model

Real action:

```bash
./bt_air_suite.sh --exec --scan --transport le --duration 30
```

Simulation:

```bash
./bt_air_suite.sh --simulate --scan --transport le --duration 30
```

Read-only status:

```bash
./bt_air_suite.sh --status
```

## Bluetooth transports

```text
--transport auto
--transport le
--transport bredr
```

BlueZ `bluetoothctl` supports Classic BR/EDR and LE and exposes scan modes `on`, `bredr`, and `le`.

## Runtime layout

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
    ├── raw/
    ├── csv/
    ├── jsonl/
    ├── filtered/
    ├── enriched/
    ├── generated/
    ├── captures/
    ├── logs/
    ├── tmp/
    └── archive/
```

## Main options

```text
--controller auto|hciN|MAC
--transport auto|le|bredr
--profile passive|standard|redteam
--passive
--active
--redteam
--aggressive-scan
--target MAC
--duration SECONDS
--infinite
--interval MINUTES
--post-process
--open-kate
--nolog
--known-file FILE
--exclusions-file FILE
--dest-dir DIR
```

## Examples

BLE discovery:

```bash
./bt_air_suite.sh --exec --scan --transport le --duration 30 --post-process
```

Rolling monitor:

```bash
./bt_air_suite.sh --exec --monitor --redteam --infinite --interval 1 --post-process --nolog
```

Fingerprint:

```bash
./bt_air_suite.sh --exec --fingerprint --target AA:BB:CC:DD:EE:FF
```

Services:

```bash
./bt_air_suite.sh --exec --enum-services --target AA:BB:CC:DD:EE:FF
```

RSSI:

```bash
./bt_air_suite.sh --exec --rssi-monitor --target AA:BB:CC:DD:EE:FF --duration 60
```

HCI trace:

```bash
./bt_air_suite.sh --exec --capture-btmon --controller hci0 --duration 60
```

Authorized connection test:

```bash
./bt_air_suite.sh --exec --connect-test --target AA:BB:CC:DD:EE:FF
```

Authorized pairing test:

```bash
./bt_air_suite.sh --exec --pair-test --target AA:BB:CC:DD:EE:FF --cleanup-pair
```

Secure local controller:

```bash
./bt_air_suite.sh --exec --secure
```

## User data

`myinfo/known_devices.txt` is the explicit known-device baseline.

`myinfo/exclusionsbt.txt` removes selected MAC addresses from filtered outputs.

Bluetooth LE devices can use changing/randomized addresses, so a MAC must not automatically be treated as proof of physical identity.

## Documentation set

The package intentionally mirrors the Wi-Fi documentation set, whose canonical repository architecture includes README, INSTALL, CHANGELOG, WHY, task specifications and global specifications.


## v2.0.0 major behavior

v2.0.0 aligns the Bluetooth monitor workflow with the interval/post-process behavior of `wifi_air_suite.sh`.

### Monitor session behavior

- `--duration` is expressed in seconds.
- `--interval` is expressed in minutes.
- `--duration 300 --interval 1` produces five independent 60-second scan slices.
- a final remainder slice is used when total duration is not divisible by the interval;
- `--archive-old` runs once before the first acquisition slice;
- `--post-process` runs after every completed slice before the next one starts;
- a post-processing error is reported but does not cancel the following interval;
- `--open-kate` opens each newly generated filtered Markdown immediately and asynchronously.

Example:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

### OUI database

The canonical local OUI database is:

```text
myinfo/oui.txt
```

Refresh it with:

```bash
./bt_air_suite.sh --update-oui
```

The update workflow downloads the official IEEE OUI text database over HTTPS into a temporary file in `myinfo/`, validates minimum size and entry count, preserves the previous database as `myinfo/oui.txt.bak`, then performs an atomic same-directory rename to `myinfo/oui.txt`.

A failed download or validation never replaces the active database.

### Bluetooth address type and vendor resolution

Each inventory row includes:

```text
address_type
oui_prefix
vendor
oui_status
```

Possible address classifications include:

```text
public
random-static
random-resolvable
random-non-resolvable
random-reserved
unknown
```

OUI manufacturer attribution is performed only when BlueZ identifies the address as public. Random/private BLE addresses are explicitly marked instead of being assigned a possibly false vendor.

### Bluetooth exclusions

Canonical files:

```text
myinfo/exclusionsbt.txt
myinfo/exclusionsbt_enrichi.txt
myinfo/exclusionsbt_oui_resolved.txt
```

`exclusionsbt.txt` drives filtered scan output. The enriched files provide offline OUI context for the exclusions list.

### Complete command reference

See `EXAMPLES.md` for exhaustive, copy/paste-ready examples covering every supported action and option.
