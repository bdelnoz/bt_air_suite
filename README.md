<!--
DOCUMENT INFORMATION
Document Name: README.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
Short description: Project overview, canonical CLI, Red Team profiles and runtime layout.
-->

# bt_air_suite.sh — v1.1.0

## Purpose

`bt_air_suite.sh` is a single durable Bluetooth/BLE Swiss Army Knife for Linux/Kali.

It merges the useful concepts of the previous Bluetooth scripts into one CLI entry point and mirrors the operational philosophy of `wifi_air_suite.sh`: explicit actions, `--exec` / `--simulate`, runtime isolation, interval acquisition, post-processing and predictable output paths.

The Wi-Fi reference separates capture/check/crack/attack actions and uses one explicit execution gate. The Bluetooth suite preserves the same design principle. fileciteturn11file0L12-L50

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
├── SPECIFICATIONS.md
├── SPECIFICATIONS_FR.md
├── SPECIFICATIONS_GLOBAL.md
├── SPECIFICATIONS_GLOBAL_FR.md
├── myinfo/
│   ├── known_devices.txt
│   └── exclusions.txt
└── .results/
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

`myinfo/exclusions.txt` removes selected MAC addresses from filtered outputs.

Bluetooth LE devices can use changing/randomized addresses, so a MAC must not automatically be treated as proof of physical identity.

## Documentation set

The package intentionally mirrors the Wi-Fi documentation set, whose canonical repository architecture includes README, INSTALL, CHANGELOG, WHY, task specifications and global specifications. fileciteturn11file2L39-L54
