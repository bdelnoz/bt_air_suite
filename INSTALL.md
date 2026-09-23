<!--
DOCUMENT INFORMATION
Document Name: INSTALL.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v2.0.0
Date / Time: 2026-09-23 07:57
Project: bt_air_suite
Short description: Installation, prerequisites and first-run instructions.
-->
# INSTALL — bt_air_suite.sh — v2.0.0

## 1. Target environment

Linux/Kali with BlueZ and a Bluetooth controller.

## 2. Place the package

Copy or extract the package into the repository root:

```text
bt_air_suite/
```

Make the main script executable:

```bash
chmod +x bt_air_suite.sh
```

## 3. Check prerequisites

```bash
./bt_air_suite.sh --prerequis
```

Core tools:

```text
bluez / bluetoothctl
btmon
rfkill
usbutils / lsusb
systemd
coreutils
awk / sed / grep
```

`sdptool` is optional and improves Classic SDP enumeration.

## 4. Automatic package installation

```bash
./bt_air_suite.sh --install
```

The supported core install is:

```text
bluez
rfkill
usbutils
```

## 5. Initialize runtime

```bash
./bt_air_suite.sh --init
```

Expected layout:

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

## 6. Verify state

```bash
./bt_air_suite.sh --status
./bt_air_suite.sh --doctor
./bt_air_suite.sh --show-paths
```


## Controller readiness before scanning

Check:

```bash
./bt_air_suite.sh --status
```

If Bluetooth is soft-blocked or the controller is powered off:

```bash
./bt_air_suite.sh --exec --power-on
```

v1.1.1 refuses to generate scan slices until the controller is ready.

## 7. Safe simulation

```bash
./bt_air_suite.sh --simulate --scan --transport le --duration 20 --post-process
```

## 8. First real scan

```bash
./bt_air_suite.sh --exec --scan --transport auto --duration 20 --post-process
```

## 9. Red Team monitor

```bash
./bt_air_suite.sh --exec --monitor \
  --profile redteam \
  --infinite \
  --interval 1 \
  --post-process
```

## 10. btmon capture

```bash
./bt_air_suite.sh --exec --capture-btmon --controller hci0 --duration 60
```

`btmon` writes a btsnoop trace under `.results/captures/`.

## 11. Local baseline

Edit:

```text
myinfo/known_devices.txt
myinfo/exclusionsbt.txt
```

One MAC per line is sufficient. Additional text after the MAC is allowed.

## 12. Stop / clean

```bash
./bt_air_suite.sh --stop
./bt_air_suite.sh --purge
```

`--purge` clears runtime files but preserves sources and `myinfo/`.

## 13. Acceptance criteria

```bash
bash -n bt_air_suite.sh
./bt_air_suite.sh --version
./bt_air_suite.sh --help
./bt_air_suite.sh --simulate --scan --transport le -d 20
./bt_air_suite.sh --simulate --fingerprint --target AA:BB:CC:DD:EE:FF
```


## Red Team v1.1.2 behavior

A real Red Team monitor:

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --nolog
```

now performs the 60-second discovery slice first, then bounded Classic SDP enrichment for the remote devices actually observed in that slice.

`sdptool` is optional. If absent, discovery/inventory continues and the active SDP enrichment is skipped with a warning.


## v2.0.0 first-run sequence

```bash
chmod +x bt_air_suite.sh
./bt_air_suite.sh --version
./bt_air_suite.sh --prerequis
./bt_air_suite.sh --init
./bt_air_suite.sh --update-oui
./bt_air_suite.sh --status
./bt_air_suite.sh --exec --power-on
```

Kate is optional. It is required only when `--open-kate` is requested.

`curl` is installed by `--install` and is used for OUI updates. If curl is not available but `wget` is already installed, `--update-oui` can use wget instead.

## Wi-Fi-style monitor example

```bash
./bt_air_suite.sh --exec --monitor \
  --redteam \
  --duration 300 \
  --interval 1 \
  --post-process \
  --open-kate \
  --nolog
```

Every completed interval is processed before the next interval starts. Each generated `*.filtered.md` is opened in Kate asynchronously.
