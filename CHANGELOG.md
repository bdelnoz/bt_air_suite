<!--
DOCUMENT INFORMATION
Document Name: CHANGELOG.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.2
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
-->

# CHANGELOG — bt_air_suite.sh

## v1.1.2 — 2026-09-23 — Bruno DELNOZ

### FIXED

- Local BlueZ controller MAC is no longer counted as a remote discovered device.
- Slice membership now comes exclusively from `Device <MAC>` events.
- RSSI is populated from the last RSSI event in the exact raw slice.
- `bluetoothctl info` RSSI is now only a fallback.

### CHANGED

- `--redteam` now has concrete behavior beyond profile defaults.
- After each Red Team scan slice, observed remote devices receive bounded Classic SDP enumeration when `sdptool` is available.
- Red Team enrichment is capped at 8 seconds per target and 12 targets per slice.

### ADDED

- `.results/raw/<prefix>.redteam.txt`.
- Red Team probe counts and success counts.

### PRESERVED

- No automatic connect or pair from Red Team monitor.
- `--connect-test` and `--pair-test` remain explicit.
- v1.1.1 real scan timing and early-return protection.
- Existing `.results/` paths and post-processing.

---

## v1.1.1 — 2026-09-23 — Bruno DELNOZ

### FIXED

- Real discovery windows now use `bluetoothctl --timeout SECONDS`.
- Rolling intervals no longer complete immediately after `SetDiscoveryFilter success`.
- Per-slice inventories now contain only MAC addresses observed in that slice.
- RSSI monitoring uses the same BlueZ timeout model.

### ADDED

- Scan readiness check for `rfkill` soft block and `Powered=no`.
- Early-return guard that rejects invalid scan slices.
- `--power-on` clears a Bluetooth rfkill soft block before powering BlueZ on.

### PRESERVED

- `--passive`, `--active`, `--redteam`.
- `--profile passive|standard|redteam`.
- `--aggressive-scan`.
- Existing runtime layout and post-processing.

---

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
