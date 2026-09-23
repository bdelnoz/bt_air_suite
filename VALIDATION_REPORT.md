<!--
DOCUMENT INFORMATION
Document Name: VALIDATION_REPORT.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v3.0.0
Date / Time: 2026-09-24 00:06
Project: bt_air_suite
Short description: Executed validation summary for the v3.0.0 complete package.
-->
# Validation report - bt_air_suite v3.0.0

## Executed checks

- `bash-n`: **OK**
- `version`: **OK** - v3.0.0
- `no-argument-help`: **OK** - ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━;   bt_air_suite.sh – v3.0.0 – 2026-09-24 00:06;   Author : Bruno DELNOZ <bruno.delnoz@protonmail.com>; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- `help`: **OK** - ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━;   bt_air_suite.sh – v3.0.0 – 2026-09-24 00:06;   Author : Bruno DELNOZ <bruno.delnoz@protonmail.com>; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- `changelog`: **OK** - v3.0.0 — 2026-09-24 00:06; - MAJOR: promoted the validated v2.0.0 behavior to the v3 baseline without;   removing or renaming any supported action, option, runtime path or data format.; - ADDED: complete Product Guide delivery for the repos
- `simulate-scan`: **OK** - SIMULATION — no Bluetooth/system change will be performed.; VERSION=v3.0.0; ACTION=scan; EXEC_MODE=0; SIMULATE_MODE=1; CONTROLLER=auto; HCI_IFACE=auto; TRANSPORT=le; PROFILE=standard; TARGET=; DURATION=2; INFINITE=0; INTERVAL_MINUTES=; POST
- `simulate-monitor`: **OK** - SIMULATION — no Bluetooth/system change will be performed.; VERSION=v3.0.0; ACTION=monitor; EXEC_MODE=0; SIMULATE_MODE=1; CONTROLLER=auto; HCI_IFACE=auto; TRANSPORT=auto; PROFILE=redteam; TARGET=; DURATION=300; INFINITE=0; INTERVAL_MINUTES=
- `simulate-update-oui`: **OK** - SIMULATION — OUI database will not be modified.; Would download: https://standards-oui.ieee.org/oui/oui.txt; Would validate temporary file.; Would preserve current database as: /mnt/data/bt_air_suite_v3.0.0/myinfo/oui.txt.bak; Would atomica
- `simulate-btmon`: **OK** - SIMULATION — no Bluetooth/system change will be performed.; VERSION=v3.0.0; ACTION=capture-btmon; EXEC_MODE=0; SIMULATE_MODE=1; CONTROLLER=hci0; HCI_IFACE=hci0; TRANSPORT=auto; PROFILE=standard; TARGET=; DURATION=2; INFINITE=0; INTERVAL_MIN
- `simulate-pair`: **OK** - SIMULATION — no Bluetooth/system change will be performed.; VERSION=v3.0.0; ACTION=pair-test; EXEC_MODE=0; SIMULATE_MODE=1; CONTROLLER=auto; HCI_IFACE=auto; TRANSPORT=auto; PROFILE=standard; TARGET=AA:BB:CC:DD:EE:FF; DURATION=; INFINITE=0; 
- `packaged-oui-integrity`: **OK** - bytes=6132821, base16_entries=37577
- `examples-help-option-coverage`: **OK** - 60 long options covered
- `documentation-current-version-metadata`: **OK** - 7/7 root project Markdown files aligned
- `controlled-mock-scan-postprocess-kate`: **OK** - [*] SCAN slice=1 duration=2s transport=auto profile=redteam; [*] Raw: /mnt/data/_bt_v3_mock/project/.results/raw/20260923_221219_1.raw.txt; SetDiscoveryFilter success; Discovery started; [CHG] Controller E8:48:B8:C8:20:00 Discovering: yes; 
- `mock-controller-exclusion-and-rssi`: **OK** - local controller excluded; last RSSI -64/-52 present
- `mock-kate-asynchronous-invocation`: **OK** - filtered Markdown passed to Kate
- `mock-real-window-timing`: **OK** - 2.53s wall time for requested 2s scan plus post-process
- `no-placeholders`: **OK** - PASS


## Product Guide validation

- `bt_air_suite_v3.0.0_Product_Guide.pdf`: generated successfully.
- Page count: **17 pages**.
- PDF preflight: **openable, not encrypted, not scanned, no XFA**.
- Render verification: **17/17 pages rendered successfully**.
- Visual spot-check: cover, two-page contents, workflow/code/table pages, version history and final page checked for clipping/overlap.

## Documentation synchronization

- Current project Markdown metadata: v3.0.0.
- Product Guide: included in the complete package.
- `EXAMPLES.md`: all long options shown by `--help` are represented.
- Historical changelog and historical feature sections are retained.
- No French specification files are added, matching the repository choice already made for this project.

## Anti-regression status

- v2.0.0 operational script used as the baseline.
- No supported v2.0.0 function or parser option was intentionally removed.
- Runtime directories and inventory field order are preserved.
- v3.0.0 changes are release/version alignment plus documentation/Product Guide packaging.

## Final status

**OK** - package generation may proceed.
