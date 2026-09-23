<!--
DOCUMENT INFORMATION
Document Name: WHY.md
Author: Bruno DELNOZ
Email: bruno.delnoz@protonmail.com
Version: v1.1.0
Date / Time: 2026-09-23
Project: bt_air_suite / bt_air_suite.sh
-->

# WHY — bt_air_suite.sh — v1.1.0

## Why one script

The previous Bluetooth material was split between controller management, UB500 hotplug handling, a very small continuous scan prototype, service-install fragments and design notes.

The new project uses one durable entry point:

```text
bt_air_suite.sh
```

Each historical capability becomes an explicit action instead of remaining a separate shell script.

## Why mirror wifi_air_suite

The Wi-Fi project already has useful operational contracts: one explicit action, `--exec` for real execution, `--simulate`, interval acquisition, runtime directories, post-processing and stable documentation. Its global specification explicitly defines those contracts. fileciteturn11file2L21-L37

The Bluetooth project adopts the same operator model without pretending Bluetooth is Wi-Fi.

## Why BlueZ / bluetoothctl

`bluetoothctl` is the standard BlueZ command-line control path for BR/EDR and LE discovery and device inspection.

## Why btmon

`btmon` provides access to the Linux Bluetooth monitor infrastructure and can write btsnoop traces suitable for later analysis.

## Why scan and monitor are different

`--scan` is one bounded acquisition.

`--monitor` is a logical session containing repeated independent scan slices, similar to the Wi-Fi interval model.

## Why CSV + JSONL

CSV is convenient for direct human inspection and spreadsheet processing.

JSONL is convenient for later correlation, automation and ingestion.

## Why known and excluded are separate

Known devices remain visible but classified as `known`.

Excluded devices are removed from filtered outputs.

That distinction avoids turning the baseline into a blind spot.

## Why MAC is not treated as physical identity

Bluetooth LE privacy/random addressing means an address can change. Correlation must therefore remain evidence-based and may later combine address, name, UUIDs, manufacturer data, RSSI and time behavior.

## Why a Red Team profile exists

The operator may need faster active discovery and explicit authorized interaction with lab devices.

The profile therefore enables an aggressive *inspection* workflow without silently chaining actions.

For operator convenience, v1.1.0 adds direct aliases:

```text
--passive
--active
--redteam
```

These map respectively to `--profile passive`, `--profile standard` and `--profile redteam`.

## Why destructive actions are not part of the generic profile

Jamming, forced disruption, destructive crash testing and aggressive fuzzing have a different operational risk from discovery and enumeration.

They are not silently hidden behind `--profile redteam`. The generic suite keeps them outside v1.0.0 so one wrong target cannot turn a scan command into an outage.

## Why `--pair-test` is explicit

BlueZ pairing can alter pairing/trust/connect state. The action therefore requires `--exec`, an explicit target and a dedicated command.

## Why `--nolog` exists

Long monitoring sessions can create large terminal logs. `--nolog` disables persistent `.log` sinks while keeping scan inventories and capture artifacts.

## Why hotplug support remains

The previous UB500 tooling contained useful automatic secure-state behavior. v1.0.0 preserves the concept as explicit install/remove/test actions while keeping the main suite controller-generic.
