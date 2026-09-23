<!--
DOCUMENT INFORMATION
Document Name: CHANGELOG.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
-->

# CHANGELOG — bt_air_suite.sh

## v1.1.0 — 2026-09-23 — Bruno DELNOZ

### ADDED

- Direct `--passive` alias for `--profile passive`.
- Direct `--active` alias for `--profile standard`.
- Direct `--redteam` alias for `--profile redteam`.

### PRESERVED

- `--profile passive|standard|redteam`.
- `--aggressive-scan` remains compatible and maps to the Red Team profile.
- All v1.0.0 scan, monitor, fingerprint, service, RSSI, btmon, connect/pair, secure and hotplug actions.

---

## v1.0.0 — 2026-09-23 — Bruno DELNOZ

### ADDED

- Single `bt_air_suite.sh` entry point.
- BlueZ Bluetooth Classic + BLE discovery.
- `--scan` and rolling `--monitor`.
- `--transport auto|le|bredr`.
- `--profile passive|standard|redteam`.
- `--aggressive-scan`.
- CSV and JSONL device inventories.
- Known-device baseline and exclusions.
- Optional filtered Markdown generation.
- `--open-kate`.
- Device `--fingerprint`.
- `--enum-services`.
- `--capture-btmon` btsnoop capture.
- `--rssi-monitor`.
- Explicit authorized `--connect-test`.
- Explicit authorized `--pair-test`.
- `--cleanup-pair`.
- `--secure`, `--power-on`, `--power-off`.
- UB500-style hotplug install/remove/test.
- `--exec` / `--simulate`.
- `--duration`, `--infinite`, `--interval`.
- `--nolog`.
- `--doctor`, `--prerequis`, `--install`, `--init`, `--stop`, `--purge`.
- `.results/` runtime tree.
- Wi-Fi-style documentation set.

### DESIGN BOUNDARY

- No RF jamming.
- No forced disruption mode.
- No destructive crash testing.
- No aggressive fuzzing in the generic v1.0.0 action set.
