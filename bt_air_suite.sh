#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./bt_air_suite.sh
# SCRIPT NAME  : bt_air_suite.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Bluetooth / BLE defensive + authorized Red Team Swiss Army Knife
# VERSION      : v2.0.0
# DATE         : 2026-09-23 07:57
# ==============================================================================
#
# DESIGN
# ------
# - One durable CLI entry point.
# - Exactly one explicit business/control action per invocation.
# - Real operational actions require --exec.
# - --simulate performs no Bluetooth/system change.
# - Discovery, fingerprinting, enumeration, capture and lab tests stay separated.
# - Destructive RF interference / crash / aggressive fuzzing is NOT implemented.
#
# ==============================================================================

set -u
IFS=$'\n\t'

VERSION="v2.0.0"
SCRIPT_DATE="2026-09-23 07:57"
SCRIPT_AUTHOR="Bruno DELNOZ"
SCRIPT_EMAIL="bruno.delnoz@protonmail.com"

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$BASE_DIR"

MYINFO_DIR="$BASE_DIR/myinfo"
KNOWN_FILE="$MYINFO_DIR/known_devices.txt"
EXCLUSION_FILE="$MYINFO_DIR/exclusionsbt.txt"
EXCLUSION_ENRICHED_FILE="$MYINFO_DIR/exclusionsbt_enrichi.txt"
EXCLUSION_OUI_RESOLVED_FILE="$MYINFO_DIR/exclusionsbt_oui_resolved.txt"
OUI_FILE="$MYINFO_DIR/oui.txt"
OUI_BACKUP_FILE="$MYINFO_DIR/oui.txt.bak"
OUI_URL="https://standards-oui.ieee.org/oui/oui.txt"
OUI_TMP_FILE=""

RUNTIME_DIR="$BASE_DIR/.results"
RAW_DIR="$RUNTIME_DIR/raw"
CSV_DIR="$RUNTIME_DIR/csv"
JSONL_DIR="$RUNTIME_DIR/jsonl"
FILTERED_DIR="$RUNTIME_DIR/filtered"
ENRICHED_DIR="$RUNTIME_DIR/enriched"
GENERATED_DIR="$RUNTIME_DIR/generated"
CAPTURE_DIR="$RUNTIME_DIR/captures"
LOG_DIR="$RUNTIME_DIR/logs"
TMP_DIR="$RUNTIME_DIR/tmp"
ARCHIVE_DIR="$RUNTIME_DIR/archive"
PID_FILE="$TMP_DIR/bt_air_suite.pid"

EXEC_MODE=0
SIMULATE_MODE=0
ACTION=""
CONTROLLER="auto"
HCI_IFACE="auto"
TRANSPORT="auto"
PROFILE="standard"
TARGET=""
DURATION=""
INFINITE=0
INTERVAL_MINUTES=""
POST_PROCESS=0
OPEN_KATE=0
ACCEPT_MODE=0
NO_LOG=0
ARCHIVE_OLD=0
RSSI_POLL=2
UB500_ID="2357:0604"
CLEANUP_PAIR=0

PREFIX=""
GLOBAL_LOG_FILE=""
ACTION_LOG_FILE=""
SUDO_KEEPALIVE_PID=""

say()  { printf '%s\n' "$*"; }
info() { printf '[*] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[KO] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

valid_mac() {
    [[ "${1:-}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

normalize_mac() {
    printf '%s' "$1" | tr 'a-f' 'A-F'
}

valid_usb_id() {
    [[ "${1:-}" =~ ^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}$ ]]
}

is_operational_action() {
    case "${1:-}" in
        scan|monitor|fingerprint|enum-services|capture-btmon|rssi-monitor|connect-test|pair-test|secure|power-on|power-off|hotplug-install|hotplug-remove|hotplug-test)
            return 0 ;;
        *) return 1 ;;
    esac
}

set_action() {
    local new_action="$1"
    [[ -z "$ACTION" ]] || die "Une seule action à la fois : déjà '$ACTION', reçu '$new_action'"
    ACTION="$new_action"
}

show_help() {
    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  bt_air_suite.sh – $VERSION – $SCRIPT_DATE
  Author : $SCRIPT_AUTHOR <$SCRIPT_EMAIL>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Unified Bluetooth / BLE discovery, inventory, post-processing, OUI enrichment,
  HCI capture and explicit authorized Red Team inspection tool for Linux/Kali.

USAGE:
  ./bt_air_suite.sh --help
  ./bt_air_suite.sh --prerequis
  ./bt_air_suite.sh --update-oui
  ./bt_air_suite.sh --simulate --<business-action> [OPTIONS]
  ./bt_air_suite.sh --exec --<business-action> [OPTIONS]

CONTROL / INFORMATION:
  --help, -h
      Show this complete help.

  --version
      Print the current version.

  --changelog, -ch
      Print the complete internal changelog.

  --prerequis, -pr
  --prereq
  --check-prereq
      Check required and optional prerequisites.
      --prereq and --check-prereq are compatibility aliases.

  --install, -i
      Install supported prerequisite packages with APT.

  --update-oui
      Download the official IEEE OUI database over HTTPS, validate it, keep the
      previous database as myinfo/oui.txt.bak, then atomically replace
      myinfo/oui.txt. No --exec is required.

  --status
      Read controller / BlueZ / rfkill status. No --exec required.

  --doctor
      Show prerequisites, paths, controller state and USB Bluetooth candidates.

  --init
      Create the expected myinfo/ and .results/ layout.

  --show-paths
      Print resolved project, myinfo and runtime paths.

  --print-config
      Print the resolved invocation configuration.

  --list-results
      List current runtime result files.

  --stop, -st
      Stop the active invocation registered by this script.

  --purge, -pu
  --clean-runtime
      Purge runtime artifacts under the selected .results root.
      myinfo/ is preserved.
      --clean-runtime is a compatibility alias.

BUSINESS ACTIONS:
  --scan
      Run one bounded discovery slice.

  --monitor
      Run Bluetooth discovery as a session.
      With --interval MINUTES, each interval is an independent scan slice.
      With --duration but no --interval, one scan slice uses the total duration.
      With --interval but no finite duration, intervals repeat until CTRL-C.

  --fingerprint
      Collect detailed BlueZ information for --target MAC.

  --enum-services
      Enumerate UUID/service information for --target.
      Uses bluetoothctl and bounded Classic SDP when sdptool is available.

  --capture-btmon
      Record an HCI monitor trace with btmon in btsnoop format.

  --rssi-monitor
      Track RSSI for --target while discovery is active.

  --connect-test
      Explicit authorized connection/disconnection test against --target.

  --pair-test
      Explicit authorized pairing test against --target.
      --cleanup-pair removes the local pairing record after the test.

  --secure
      Power controller on, pairable off, discoverable off.

  --power-on
  --power-off

  --hotplug-install
      Install TP-Link UB500-style udev/systemd secure-on-attach support.

  --hotplug-remove
      Remove hotplug files installed by this suite.

  --hotplug-test
      Inspect USB presence and installed hotplug service/rule state.

EXECUTION GATES:
  --exec, -exe
      Authorize real execution of exactly one operational action.

  --simulate, -s, --dry-run
      Dry-run an operational action without Bluetooth/system changes.

DISCOVERY / MONITOR OPTIONS:
  --controller VALUE
      auto, hciN or Bluetooth controller MAC. Default: auto

  --transport auto|le|bredr
      Discovery transport. Default: auto

  -d, --duration SECONDS
      Total action/session duration in seconds.

  --infinite
      Explicit infinite monitor until CTRL-C.

  --interval MINUTES
      Split --monitor into independent MINUTES-long discovery slices.
      Post-processing runs after EACH completed slice before the next slice.
      If the finite duration is not divisible by the interval, the final slice
      uses the remaining seconds.

  --profile passive|standard|redteam
      passive  : passive-oriented discovery/capture workflow
      standard : normal discovery and inspection
      redteam  : discovery plus bounded Classic SDP enrichment

  --passive
      Alias for --profile passive.

  --active
      Alias for --profile standard.

  --redteam
      Alias for --profile redteam.

  --aggressive-scan
      Compatibility alias for --redteam.

  --target MAC
      Explicit remote Bluetooth device target.

POST-PROCESS / OUTPUT:
  --post-process
      After each completed scan slice:
        1. filter exclusionsbt.txt;
        2. write *.filtered.csv;
        3. write *.filtered.md;
        4. write *.enriched.csv;
        5. refresh exclusionsbt_enrichi.txt / exclusionsbt_oui_resolved.txt;
        6. copy generated artifacts under .results/generated/.

  --no-post-process
      Disable post-processing.

  --open-kate
      Same behavior as wifi_air_suite:
      open EACH newly generated *.filtered.md immediately after creation using
      Kate asynchronously; the next monitor interval does not wait for Kate.
      Requires --post-process and is valid only with --scan or --monitor.

  --accept
      Compatibility option matching the Wi-Fi suite's non-interactive acceptance
      semantics. It never bypasses sudo authentication.

  --archive-old
      Archive current runtime result files once before the acquisition session.

  --nolog, --no-log
      Disable persistent runtime *.log files.
      Scan/result data is still generated.

  --dest_dir DIR, --dest-dir DIR
      Override the default .results runtime root.

OUI / INVENTORY:
  -X, --exclusions-file FILE
      MAC exclusion file.
      Default: $EXCLUSION_FILE

  --known-file FILE
      Known/trusted Bluetooth device list.
      Default: $KNOWN_FILE

  --update-oui
      Refresh $OUI_FILE from:
      $OUI_URL

  Public Bluetooth addresses can be OUI-resolved.
  BLE random/private addresses are classified and are not assigned a vendor as
  if the first three octets were a trustworthy IEEE OUI.

TARGET TEST OPTIONS:
  --rssi-poll SECONDS
      RSSI sampling interval. Default: $RSSI_POLL

  --cleanup-pair
      With --pair-test, remove the local pairing record after testing.

HOTPLUG:
  --ub500-id VVVV:PPPP
      USB VID:PID used by hotplug support.
      Default: $UB500_ID

DEFAULT FILES:
  $EXCLUSION_FILE
  $EXCLUSION_ENRICHED_FILE
  $EXCLUSION_OUI_RESOLVED_FILE
  $KNOWN_FILE
  $OUI_FILE
  $OUI_BACKUP_FILE

RUNTIME LAYOUT:
  $RUNTIME_DIR/
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

RESERVED / NOT IMPLEMENTED:
  --lab-destructive
      Reserved name. Explicitly rejected by the parser in v2.0.0.

RED TEAM BOUNDARY:
  Red Team mode performs discovery plus bounded Classic SDP service enumeration
  for observed remote devices. It never automatically connects, pairs, trusts or
  removes devices. RF jamming, forced disruption, destructive crash testing and
  aggressive fuzzing are not part of the generic action set.

EXAMPLES:
  ./bt_air_suite.sh --status
  ./bt_air_suite.sh --doctor
  ./bt_air_suite.sh --update-oui

  ./bt_air_suite.sh --simulate --scan --transport le -d 20 --post-process
  ./bt_air_suite.sh --exec --scan --transport le -d 20 --post-process --open-kate

  ./bt_air_suite.sh --exec --monitor --redteam --duration 300 --interval 1 --post-process --open-kate --nolog
  ./bt_air_suite.sh --exec --monitor --duration 650 --interval 5 --post-process
  ./bt_air_suite.sh --exec --monitor --infinite --interval 10 --post-process --nolog

  ./bt_air_suite.sh --exec --fingerprint --target AA:BB:CC:DD:EE:FF --redteam
  ./bt_air_suite.sh --exec --enum-services --target AA:BB:CC:DD:EE:FF
  ./bt_air_suite.sh --exec --rssi-monitor --target AA:BB:CC:DD:EE:FF -d 60
  ./bt_air_suite.sh --exec --capture-btmon --controller hci0 -d 60
  ./bt_air_suite.sh --exec --connect-test --target AA:BB:CC:DD:EE:FF
  ./bt_air_suite.sh --exec --pair-test --target AA:BB:CC:DD:EE:FF --cleanup-pair
  ./bt_air_suite.sh --exec --secure
  ./bt_air_suite.sh --exec --hotplug-install --ub500-id 2357:0604

  See EXAMPLES.md for the exhaustive command reference.

EOF
}

show_changelog() {
    cat <<'EOF'
v2.0.0 — 2026-09-23 07:57
- MAJOR: monitor interval/post-process/Kate workflow aligned with wifi_air_suite.
- CHANGED: --duration remains seconds; --interval remains minutes; each completed
  monitor interval is post-processed before the next interval begins.
- CHANGED: --open-kate now follows the Wi-Fi behavior exactly: every newly
  generated *.filtered.md is opened immediately with `kate FILE >/dev/null 2>&1 &`;
  the editor never blocks the next scan interval.
- CHANGED: --open-kate is valid only with --scan/--monitor and requires
  --post-process. Kate is checked before acquisition starts.
- CHANGED: canonical Bluetooth exclusions file is now myinfo/exclusionsbt.txt.
- ADDED: bundled offline myinfo/oui.txt database and OUI/vendor enrichment.
- ADDED: --update-oui downloads the official IEEE OUI database over HTTPS,
  validates it, preserves the previous database as oui.txt.bak, and atomically
  replaces myinfo/oui.txt only after successful validation.
- ADDED: myinfo/exclusionsbt_enrichi.txt and
  myinfo/exclusionsbt_oui_resolved.txt generation.
- ADDED: address_type, oui_prefix, vendor and oui_status fields to CSV/JSONL.
- ADDED: Bluetooth public/random address classification; OUI vendor attribution
  is not asserted for private/random BLE addresses.
- ADDED: --accept compatibility option and --no-post-process.
- ADDED: EXAMPLES.md with exhaustive command examples for every supported action
  and option combination.
- PRESERVED: v1.1.2 real scan timing, per-slice RSSI, local-controller exclusion,
  Red Team bounded SDP enrichment, --nolog, btmon, fingerprint, services,
  connection/pairing tests, secure state and UB500 hotplug support.
- FIXED: removed accidental `set -e` toggling from bounded Red Team/btmon calls.

v1.1.2 — 2026-09-23
- FIXED: the local Bluetooth controller MAC is no longer counted as a discovered
  remote device. Slice membership is extracted only from BlueZ `Device <MAC>`
  events, never `Controller <MAC>` events.
- FIXED: per-slice RSSI is extracted from the last RSSI event observed for each
  remote device in the exact raw scan window. `bluetoothctl info` is only a
  fallback when the raw slice contains no RSSI for that device.
- CHANGED: --redteam now performs a real bounded active enrichment step after
  discovery: Classic SDP browse probes are attempted for observed remote devices
  when sdptool is available. This never auto-connects, pairs, trusts or removes
  a device.
- ADDED: per-slice Red Team report under .results/raw/*.redteam.txt.
- ADDED: redteam_probe_count and redteam_probe_success_count metadata.
- PRESERVED: real scan timing, early-return guard, rfkill/Powered readiness,
  --passive/--active/--redteam aliases and the v1.1.1 runtime layout.

v1.1.1 — 2026-09-23
- FIXED: discovery slices now use bluetoothctl --timeout SECONDS so a requested
  duration is a real scan window instead of returning immediately after setting
  the discovery filter.
- FIXED: each slice inventory is built only from MAC addresses actually observed
  in that slice's bluetoothctl output; cached/stale BlueZ device objects are not
  automatically imported into the slice.
- ADDED: scan readiness checks for rfkill soft-block and Powered=no.
- CHANGED: --power-on unblocks Bluetooth through rfkill before powering BlueZ on.
- ADDED: early-return guard: a scan that exits materially before its requested
  duration is rejected instead of generating misleading interval sets.
- FIXED: RSSI monitoring uses the same bluetoothctl --timeout timing model.

v1.1.0 — 2026-09-23
- Added direct profile aliases: --passive, --active, --redteam.
- --aggressive-scan remains a compatibility alias for the Red Team profile.
- Preserved --profile passive|standard|redteam.

v1.0.0 — 2026-09-23
- Initial unified Bluetooth Swiss Army Knife.
- BlueZ Classic/BLE scanning.
- Rolling monitor mode.
- Persistent CSV/JSONL/Markdown inventory.
- Known/exclusion lists.
- Fingerprint/service enumeration.
- btmon btsnoop capture.
- RSSI monitoring.
- Authorized connect/pair tests.
- Controller secure/power operations.
- UB500-style hotplug install/remove/test.
- --exec / --simulate execution gates.
- --profile redteam / --aggressive-scan.
- --nolog, --duration, --interval, --post-process, --open-kate.
EOF
}

set_runtime_root() {
    local requested="$1"
    if [[ "$requested" == /* ]]; then
        RUNTIME_DIR="$requested"
    else
        RUNTIME_DIR="$BASE_DIR/$requested"
    fi

    RAW_DIR="$RUNTIME_DIR/raw"
    CSV_DIR="$RUNTIME_DIR/csv"
    JSONL_DIR="$RUNTIME_DIR/jsonl"
    FILTERED_DIR="$RUNTIME_DIR/filtered"
    ENRICHED_DIR="$RUNTIME_DIR/enriched"
    GENERATED_DIR="$RUNTIME_DIR/generated"
    CAPTURE_DIR="$RUNTIME_DIR/captures"
    LOG_DIR="$RUNTIME_DIR/logs"
    TMP_DIR="$RUNTIME_DIR/tmp"
    ARCHIVE_DIR="$RUNTIME_DIR/archive"
    PID_FILE="$TMP_DIR/bt_air_suite.pid"
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --exec|-exe) EXEC_MODE=1; shift ;;
            --simulate|-s|--dry-run) SIMULATE_MODE=1; shift ;;

            --status) set_action "status"; shift ;;
            --update-oui) set_action "update-oui"; shift ;;
            --scan) set_action "scan"; shift ;;
            --monitor) set_action "monitor"; shift ;;
            --fingerprint) set_action "fingerprint"; shift ;;
            --enum-services) set_action "enum-services"; shift ;;
            --capture-btmon) set_action "capture-btmon"; shift ;;
            --rssi-monitor) set_action "rssi-monitor"; shift ;;
            --connect-test) set_action "connect-test"; shift ;;
            --pair-test) set_action "pair-test"; shift ;;
            --secure) set_action "secure"; shift ;;
            --power-on) set_action "power-on"; shift ;;
            --power-off) set_action "power-off"; shift ;;
            --hotplug-install) set_action "hotplug-install"; shift ;;
            --hotplug-remove) set_action "hotplug-remove"; shift ;;
            --hotplug-test) set_action "hotplug-test"; shift ;;

            --prerequis|-pr|--prereq|--check-prereq) set_action "prerequis"; shift ;;
            --install|-i) set_action "install"; shift ;;
            --doctor) set_action "doctor"; shift ;;
            --init) set_action "init"; shift ;;
            --show-paths) set_action "show-paths"; shift ;;
            --print-config) set_action "print-config"; shift ;;
            --list-results) set_action "list-results"; shift ;;
            --stop|-st) set_action "stop"; shift ;;
            --purge|-pu|--clean-runtime) set_action "purge"; shift ;;

            --controller)
                [[ $# -ge 2 ]] || die "Valeur manquante après --controller"
                CONTROLLER="$2"
                if [[ "$CONTROLLER" =~ ^hci[0-9]+$ ]]; then HCI_IFACE="$CONTROLLER"; fi
                shift 2
                ;;
            --transport)
                [[ $# -ge 2 ]] || die "Valeur manquante après --transport"
                case "$2" in auto|le|bredr) TRANSPORT="$2" ;; *) die "Transport invalide: $2" ;; esac
                shift 2
                ;;
            --profile)
                [[ $# -ge 2 ]] || die "Valeur manquante après --profile"
                case "$2" in passive|standard|redteam) PROFILE="$2" ;; *) die "Profil invalide: $2" ;; esac
                shift 2
                ;;
            --passive)
                PROFILE="passive"
                shift
                ;;
            --active)
                PROFILE="standard"
                shift
                ;;
            --redteam)
                PROFILE="redteam"
                shift
                ;;
            --aggressive-scan)
                PROFILE="redteam"
                shift
                ;;
            --target)
                [[ $# -ge 2 ]] || die "Valeur manquante après --target"
                valid_mac "$2" || die "MAC cible invalide: $2"
                TARGET="$(normalize_mac "$2")"
                shift 2
                ;;
            -d|--duration)
                [[ $# -ge 2 ]] || die "Valeur manquante après $1"
                [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "Durée invalide: $2"
                DURATION="$2"
                INFINITE=0
                shift 2
                ;;
            --infinite)
                INFINITE=1
                DURATION=""
                shift
                ;;
            --interval)
                [[ $# -ge 2 ]] || die "Valeur manquante après --interval"
                [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "Intervalle invalide: $2"
                INTERVAL_MINUTES="$2"
                shift 2
                ;;
            --post-process) POST_PROCESS=1; shift ;;
            --no-post-process) POST_PROCESS=0; shift ;;
            --open-kate) OPEN_KATE=1; shift ;;
            --accept) ACCEPT_MODE=1; shift ;;
            --archive-old) ARCHIVE_OLD=1; shift ;;
            --nolog|--no-log) NO_LOG=1; shift ;;
            --cleanup-pair) CLEANUP_PAIR=1; shift ;;
            --rssi-poll)
                [[ $# -ge 2 ]] || die "Valeur manquante après --rssi-poll"
                [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "RSSI poll invalide: $2"
                RSSI_POLL="$2"
                shift 2
                ;;
            -X|--exclusions-file)
                [[ $# -ge 2 ]] || die "Valeur manquante après $1"
                EXCLUSION_FILE="$2"
                shift 2
                ;;
            --known-file)
                [[ $# -ge 2 ]] || die "Valeur manquante après --known-file"
                KNOWN_FILE="$2"
                shift 2
                ;;
            --ub500-id)
                [[ $# -ge 2 ]] || die "Valeur manquante après --ub500-id"
                valid_usb_id "$2" || die "USB ID invalide: $2"
                UB500_ID="$(printf '%s' "$2" | tr 'a-f' 'A-F')"
                shift 2
                ;;
            --dest_dir|--dest-dir)
                [[ $# -ge 2 ]] || die "Valeur manquante après $1"
                set_runtime_root "$2"
                shift 2
                ;;
            --version)
                say "$VERSION"
                exit 0
                ;;
            --changelog|-ch)
                show_changelog
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --lab-destructive)
                die "--lab-destructive est réservé et non implémenté dans $VERSION."
                ;;
            *)
                die "Argument inconnu: $1"
                ;;
        esac
    done

    [[ -n "$ACTION" ]] || die "Aucune action sélectionnée."

    if (( EXEC_MODE == 1 && SIMULATE_MODE == 1 )); then
        die "--exec et --simulate sont mutuellement exclusifs."
    fi

    if is_operational_action "$ACTION"; then
        if (( EXEC_MODE == 0 && SIMULATE_MODE == 0 )); then
            die "L'action '$ACTION' exige --exec ou --simulate."
        fi
    fi

    if [[ -n "$INTERVAL_MINUTES" && "$ACTION" != "monitor" ]]; then
        die "--interval est réservé à --monitor."
    fi

    if (( OPEN_KATE == 1 )); then
        case "$ACTION" in
            scan|monitor) ;;
            *) die "--open-kate est disponible uniquement avec --scan ou --monitor." ;;
        esac
        (( POST_PROCESS == 1 )) || die "--open-kate exige --post-process."
    fi

    case "$ACTION" in
        fingerprint|enum-services|rssi-monitor|connect-test|pair-test)
            [[ -n "$TARGET" ]] || die "--$ACTION exige --target MAC."
            ;;
    esac
}

ensure_dirs() {
    mkdir -p "$MYINFO_DIR" "$RAW_DIR" "$CSV_DIR" "$JSONL_DIR" "$FILTERED_DIR" \
             "$ENRICHED_DIR" "$GENERATED_DIR" "$CAPTURE_DIR" "$LOG_DIR" "$TMP_DIR" "$ARCHIVE_DIR"
    [[ -f "$KNOWN_FILE" ]] || : > "$KNOWN_FILE"
    [[ -f "$EXCLUSION_FILE" ]] || : > "$EXCLUSION_FILE"
    [[ -f "$EXCLUSION_ENRICHED_FILE" ]] || : > "$EXCLUSION_ENRICHED_FILE"
    [[ -f "$EXCLUSION_OUI_RESOLVED_FILE" ]] || : > "$EXCLUSION_OUI_RESOLVED_FILE"
    [[ -f "$OUI_FILE" ]] || : > "$OUI_FILE"
}

generate_prefix() {
    local ts i candidate
    ts="$(date +'%Y%m%d_%H%M%S')"
    i=1
    while :; do
        candidate="${ts}_${i}"
        if [[ ! -e "$RAW_DIR/${candidate}.raw.txt" \
           && ! -e "$CSV_DIR/${candidate}.csv" \
           && ! -e "$JSONL_DIR/${candidate}.jsonl" ]]; then
            PREFIX="$candidate"
            return 0
        fi
        ((i++))
    done
}

setup_logs() {
    [[ -n "$PREFIX" ]] || generate_prefix
    if (( NO_LOG == 1 )); then
        GLOBAL_LOG_FILE="/dev/null"
        ACTION_LOG_FILE="/dev/null"
        return 0
    fi

    GLOBAL_LOG_FILE="$LOG_DIR/${PREFIX}.log"
    ACTION_LOG_FILE="$LOG_DIR/${ACTION}-${PREFIX}.log"
    {
        echo "script=bt_air_suite.sh"
        echo "version=$VERSION"
        echo "date=$(date --iso-8601=seconds 2>/dev/null || date)"
        echo "action=$ACTION"
        echo "exec=$EXEC_MODE"
        echo "simulate=$SIMULATE_MODE"
        echo "controller=$CONTROLLER"
        echo "transport=$TRANSPORT"
        echo "profile=$PROFILE"
        echo "target=$TARGET"
        echo "runtime=$RUNTIME_DIR"
    } >> "$GLOBAL_LOG_FILE"
}

archive_old() {
    local d f
    mkdir -p "$ARCHIVE_DIR"
    for d in "$RAW_DIR" "$CSV_DIR" "$JSONL_DIR" "$FILTERED_DIR" "$ENRICHED_DIR" "$GENERATED_DIR" "$CAPTURE_DIR"; do
        [[ -d "$d" ]] || continue
        while IFS= read -r -d '' f; do
            mv -f -- "$f" "$ARCHIVE_DIR/$(basename "$f").done" 2>/dev/null || true
        done < <(find "$d" -maxdepth 1 -type f -print0 2>/dev/null)
    done
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }
need_cmd() { has_cmd "$1" || die "Commande manquante: $1"; }

sudo_keepalive_stop() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    SUDO_KEEPALIVE_PID=""
}

sudo_keepalive_start() {
    local parent_pid
    (( EUID == 0 )) && return 0
    parent_pid="$$"
    (
        while kill -0 "$parent_pid" 2>/dev/null; do
            sleep 45
            sudo -n true >/dev/null 2>&1 || exit 0
        done
    ) >/dev/null 2>&1 &
    SUDO_KEEPALIVE_PID="$!"
}

sudo_ready() {
    if (( EUID == 0 )); then return 0; fi
    need_cmd sudo
    if sudo -n true >/dev/null 2>&1; then
        sudo_keepalive_start
        return 0
    fi
    sudo -v -p "[sudo] Mot de passe de %u : " || die "Authentification sudo refusée."
    sudo -n true >/dev/null 2>&1 || die "Ticket sudo inutilisable."
    sudo_keepalive_start
}

run_privileged() {
    if (( EUID == 0 )); then "$@"; else sudo -n "$@"; fi
}

register_pid() {
    ensure_dirs
    printf '%s %s %s\n' "$$" "$ACTION" "$(date --iso-8601=seconds 2>/dev/null || date)" > "$PID_FILE"
}

unregister_pid() {
    [[ -f "$PID_FILE" ]] || return 0
    local pid
    pid="$(awk '{print $1}' "$PID_FILE" 2>/dev/null || true)"
    [[ "$pid" == "$$" ]] && rm -f "$PID_FILE" || true
}

cleanup() {
    sudo_keepalive_stop || true
    unregister_pid || true
    if [[ -n "${OUI_TMP_FILE:-}" && -f "$OUI_TMP_FILE" ]]; then
        rm -f -- "$OUI_TMP_FILE" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

resolve_hci() {
    if [[ "$CONTROLLER" =~ ^hci[0-9]+$ ]]; then
        HCI_IFACE="$CONTROLLER"
        return 0
    fi

    local p
    for p in /sys/class/bluetooth/hci*; do
        [[ -e "$p" ]] || continue
        HCI_IFACE="$(basename "$p")"
        return 0
    done

    HCI_IFACE="hci0"
}

btctl() {
    bluetoothctl "$@"
}

controller_select_prefix() {
    if valid_mac "$CONTROLLER"; then
        printf 'select %s\n' "$(normalize_mac "$CONTROLLER")"
    fi
}

run_btctl_script() {
    local timeout_s="$1"
    shift
    local select_line=""
    if valid_mac "$CONTROLLER"; then
        select_line="select $(normalize_mac "$CONTROLLER")"
    fi

    {
        [[ -n "$select_line" ]] && printf '%s\n' "$select_line"
        printf '%s\n' "$@"
    } | bluetoothctl --timeout "$timeout_s"
}

run_status() {
    need_cmd bluetoothctl
    say "bt_air_suite.sh $VERSION — STATUS"
    say
    bluetoothctl list 2>/dev/null || true
    say
    bluetoothctl show 2>/dev/null || true
    say
    if has_cmd rfkill; then rfkill list bluetooth 2>/dev/null || true; fi
    say
    if has_cmd systemctl; then systemctl --no-pager --full status bluetooth.service 2>/dev/null | head -n 20 || true; fi
    say
    resolve_hci
    say "Resolved HCI: $HCI_IFACE"
}

run_prerequis() {
    local rc=0 cmd
    local -a required=(bash bluetoothctl btmon timeout awk sed grep find date systemctl rfkill lsusb)
    say "bt_air_suite.sh $VERSION — PREREQUIS"
    for cmd in "${required[@]}"; do
        if has_cmd "$cmd"; then
            printf '[OK] %-16s %s\n' "$cmd" "$(command -v "$cmd")"
        else
            printf '[KO] %-16s missing\n' "$cmd"
            rc=1
        fi
    done
    if has_cmd sdptool; then
        printf '[OK] %-16s %s\n' "sdptool" "$(command -v sdptool)"
    else
        printf '[WARN] %-14s optional (Classic SDP enumeration reduced)\n' "sdptool"
    fi

    if has_cmd curl; then
        printf '[OK] %-16s %s\n' "curl" "$(command -v curl)"
    elif has_cmd wget; then
        printf '[OK] %-16s %s\n' "wget" "$(command -v wget)"
    else
        printf '[WARN] %-14s %s\n' "curl/wget" "missing (--update-oui unavailable)"
    fi

    if has_cmd kate; then
        printf '[OK] %-16s %s\n' "kate" "$(command -v kate)"
    else
        printf '[WARN] %-14s %s\n' "kate" "optional (--open-kate unavailable)"
    fi

    if validate_oui_file "$OUI_FILE"; then
        printf '[OK] %-16s %s\n' "oui.txt" "$OUI_FILE"
    else
        printf '[WARN] %-14s %s\n' "oui.txt" "missing/invalid; run ./bt_air_suite.sh --update-oui"
    fi

    return "$rc"
}

run_install() {
    if (( SIMULATE_MODE == 1 )); then
        say "SIMULATION: apt-get update"
        say "SIMULATION: apt-get install -y bluez rfkill usbutils curl"
        return 0
    fi
    sudo_ready
    run_privileged apt-get update
    run_privileged apt-get install -y bluez rfkill usbutils curl
}

show_paths() {
    cat <<EOF
BASE_DIR=$BASE_DIR
MYINFO_DIR=$MYINFO_DIR
KNOWN_FILE=$KNOWN_FILE
EXCLUSION_FILE=$EXCLUSION_FILE
EXCLUSION_ENRICHED_FILE=$EXCLUSION_ENRICHED_FILE
EXCLUSION_OUI_RESOLVED_FILE=$EXCLUSION_OUI_RESOLVED_FILE
OUI_FILE=$OUI_FILE
OUI_BACKUP_FILE=$OUI_BACKUP_FILE
OUI_URL=$OUI_URL
RUNTIME_DIR=$RUNTIME_DIR
RAW_DIR=$RAW_DIR
CSV_DIR=$CSV_DIR
JSONL_DIR=$JSONL_DIR
FILTERED_DIR=$FILTERED_DIR
ENRICHED_DIR=$ENRICHED_DIR
GENERATED_DIR=$GENERATED_DIR
CAPTURE_DIR=$CAPTURE_DIR
LOG_DIR=$LOG_DIR
TMP_DIR=$TMP_DIR
ARCHIVE_DIR=$ARCHIVE_DIR
PID_FILE=$PID_FILE
EOF
}

print_config() {
    cat <<EOF
VERSION=$VERSION
ACTION=$ACTION
EXEC_MODE=$EXEC_MODE
SIMULATE_MODE=$SIMULATE_MODE
CONTROLLER=$CONTROLLER
HCI_IFACE=$HCI_IFACE
TRANSPORT=$TRANSPORT
PROFILE=$PROFILE
TARGET=$TARGET
DURATION=$DURATION
INFINITE=$INFINITE
INTERVAL_MINUTES=$INTERVAL_MINUTES
POST_PROCESS=$POST_PROCESS
OPEN_KATE=$OPEN_KATE
ACCEPT_MODE=$ACCEPT_MODE
NO_LOG=$NO_LOG
RSSI_POLL=$RSSI_POLL
UB500_ID=$UB500_ID
CLEANUP_PAIR=$CLEANUP_PAIR
EXCLUSION_FILE=$EXCLUSION_FILE
EXCLUSION_ENRICHED_FILE=$EXCLUSION_ENRICHED_FILE
EXCLUSION_OUI_RESOLVED_FILE=$EXCLUSION_OUI_RESOLVED_FILE
KNOWN_FILE=$KNOWN_FILE
OUI_FILE=$OUI_FILE
RUNTIME_DIR=$RUNTIME_DIR
EOF
}

doctor() {
    say "bt_air_suite.sh $VERSION — DOCTOR"
    say
    run_prerequis || true
    say
    show_paths
    say
    run_status
    say
    if has_cmd lsusb; then
        say "USB Bluetooth candidates:"
        lsusb | grep -Ei 'bluetooth|2357:0604' || true
    fi
}

init_layout() {
    ensure_dirs
    refresh_exclusion_enrichment || true
    ok "Layout initialized."
    if ! validate_oui_file "$OUI_FILE"; then
        warn "OUI database missing/invalid: $OUI_FILE"
        warn "Run exactly: ./bt_air_suite.sh --update-oui"
    fi
    show_paths
}

list_results() {
    ensure_dirs
    find "$RUNTIME_DIR" -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort -r
}

purge_action() {
    ensure_dirs
    if (( SIMULATE_MODE == 1 )); then
        say "SIMULATION: would delete runtime files under $RUNTIME_DIR"
        return 0
    fi
    find "$RUNTIME_DIR" -mindepth 2 -type f -delete 2>/dev/null || true
    ok "Runtime files purged. myinfo preserved."
}

stop_action() {
    local pid
    [[ -f "$PID_FILE" ]] || { warn "No active PID file."; return 0; }
    pid="$(awk '{print $1}' "$PID_FILE" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || { rm -f "$PID_FILE"; die "Invalid PID file removed."; }
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        warn "Stale PID removed."
        return 0
    fi
    if (( SIMULATE_MODE == 1 )); then
        say "SIMULATION: would send TERM to PID $pid"
    else
        kill -TERM "$pid"
        ok "TERM sent to PID $pid."
    fi
}

simulation_stop() {
    (( SIMULATE_MODE == 1 )) || return 0
    say "SIMULATION — no Bluetooth/system change will be performed."
    print_config
    case "$ACTION" in
        scan)
            say "Would run one discovery slice and inventory remote devices."
            [[ "$PROFILE" == "redteam" ]] && say "Would then run bounded active Classic SDP enrichment on observed remote devices."
            ;;
        monitor)
            say "Would run Wi-Fi-style monitor session semantics."
            say "Duration: ${DURATION:-INFINITE}; interval minutes: ${INTERVAL_MINUTES:-DISABLED}."
            say "Would post-process after each completed interval: $POST_PROCESS."
            say "Would open each new filtered Markdown asynchronously in Kate: $OPEN_KATE."
            [[ "$PROFILE" == "redteam" ]] && say "Would run bounded active Classic SDP enrichment after each slice."
            ;;
        fingerprint) say "Would inspect target $TARGET with bluetoothctl info." ;;
        enum-services) say "Would inspect target $TARGET UUID/SDP services." ;;
        capture-btmon) say "Would capture HCI traffic with btmon." ;;
        rssi-monitor) say "Would track RSSI for $TARGET while discovery is active." ;;
        connect-test) say "Would connect then disconnect target $TARGET." ;;
        pair-test) say "Would pair target $TARGET; cleanup_pair=$CLEANUP_PAIR." ;;
        secure) say "Would power on, pairable off, discoverable off." ;;
        power-on|power-off) say "Would change controller power state." ;;
        hotplug-install) say "Would install UB500 udev/systemd hook for $UB500_ID." ;;
        hotplug-remove) say "Would remove suite hotplug files." ;;
        hotplug-test) say "Would inspect USB/service hotplug state." ;;
    esac
    exit 0
}

bluetooth_soft_blocked() {
    has_cmd rfkill || return 1
    rfkill list bluetooth 2>/dev/null | awk '
        /Soft blocked:/ {
            if (tolower($3) == "yes") found=1
        }
        END { exit(found ? 0 : 1) }
    '
}

controller_powered() {
    bluetoothctl show 2>/dev/null | awk -F': ' '
        /^[[:space:]]*Powered:/ {
            if (tolower($2) == "yes") ok=1
        }
        END { exit(ok ? 0 : 1) }
    '
}

scan_readiness_check() {
    need_cmd bluetoothctl

    if bluetooth_soft_blocked; then
        err "Bluetooth est soft-blocked par rfkill."
        err "Commande corrective : ./bt_air_suite.sh --exec --power-on"
        return 1
    fi

    if ! controller_powered; then
        err "Le contrôleur Bluetooth est éteint (Powered=no)."
        err "Commande corrective : ./bt_air_suite.sh --exec --power-on"
        return 1
    fi

    return 0
}

strip_ansi() {
    # bluetoothctl can emit terminal colour/control sequences.
    sed -E $'s/\x1B\\[[0-9;?]*[ -\\/]*[@-~]//g'
}

extract_seen_macs() {
    local raw="$1"
    local output="$2"

    # BlueZ scan output contains both:
    #   [CHG] Controller AA:BB:... Discovering: yes
    #   [NEW]/[CHG]/[DEL] Device CC:DD:...
    #
    # Only remote Device events define membership of a scan slice.  This prevents
    # the local controller address from leaking into CSV/JSONL/filtered results.
    strip_ansi < "$raw" \
        | awk '
            match($0, /Device[[:space:]]+([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/) {
                value=substr($0, RSTART, RLENGTH)
                sub(/^Device[[:space:]]+/, "", value)
                print toupper(value)
            }
        ' \
        | awk '!seen[$0]++' > "$output" || true
}

last_rssi_from_raw() {
    local raw="$1"
    local mac="$2"

    strip_ansi < "$raw" | awk -v target="$mac" '
        BEGIN { target=toupper(target); value="" }

        {
            line=toupper($0)

            if (index(line, "DEVICE " target " ") == 0) {
                next
            }

            if (index(line, "RSSI:") == 0) {
                next
            }

            # BlueZ commonly renders:
            #   RSSI: 0xffffffcc (-52)
            # but some versions can expose a direct decimal.
            if (match($0, /\(-?[0-9]+\)/)) {
                v=substr($0, RSTART+1, RLENGTH-2)
                value=v
                next
            }

            if (match($0, /RSSI:[[:space:]]*-?[0-9]+/)) {
                v=substr($0, RSTART, RLENGTH)
                sub(/^RSSI:[[:space:]]*/, "", v)
                value=v
            }
        }

        END {
            if (value != "") print value
        }
    '
}

run_discovery_window() {
    local duration="$1"
    local mode="$2"
    local raw="$3"
    local started finished elapsed rc tolerance

    started="$(date +%s)"

    # Important: `bluetoothctl scan on` can return immediately in non-interactive
    # invocation after configuring discovery. BlueZ's own --timeout option keeps
    # the non-interactive client alive for the requested discovery window.
    bluetoothctl --timeout "$duration" scan "$mode" 2>&1 \
        | tee -a "$raw" "$ACTION_LOG_FILE"
    rc=${PIPESTATUS[0]}

    # Best-effort explicit cleanup in case the client/daemon kept discovery state.
    bluetoothctl scan off >/dev/null 2>&1 || true

    finished="$(date +%s)"
    elapsed=$(( finished - started ))

    {
        echo
        echo "scan_requested_seconds=$duration"
        echo "scan_elapsed_seconds=$elapsed"
        echo "scan_return_code=$rc"
    } >> "$raw"

    # Permit a small wall-clock rounding margin. Anything much shorter is not a
    # valid interval and must not be turned into a misleading result set.
    tolerance=2
    if (( duration > tolerance && elapsed < duration - tolerance )); then
        err "Scan terminé trop tôt : ${elapsed}s écoulée(s), ${duration}s demandées."
        err "La tranche est rejetée pour éviter un faux résultat d'intervalle."
        if bluetooth_soft_blocked || ! controller_powered; then
            err "État contrôleur invalide détecté. Lance : ./bt_air_suite.sh --exec --power-on"
        fi
        return 1
    fi

    if (( rc != 0 )); then
        warn "bluetoothctl scan a retourné le code $rc après ${elapsed}s."
    fi

    return 0
}

scan_arg() {
    case "$TRANSPORT" in
        le) printf 'le\n' ;;
        bredr) printf 'bredr\n' ;;
        *) printf 'on\n' ;;
    esac
}

default_scan_duration() {
    if [[ -n "$DURATION" ]]; then
        printf '%s\n' "$DURATION"
        return
    fi
    case "$PROFILE" in
        redteam) printf '15\n' ;;
        passive) printf '30\n' ;;
        *) printf '20\n' ;;
    esac
}

csv_escape() {
    local s="${1:-}"
    s="${s//\"/\"\"}"
    printf '"%s"' "$s"
}

json_escape() {
    local s="${1:-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

known_status() {
    local mac="$1"
    if grep -Eiq "^[[:space:]]*$mac([[:space:]]|$)" "$KNOWN_FILE" 2>/dev/null; then
        printf 'known\n'
    else
        printf 'unknown\n'
    fi
}

excluded_mac() {
    local mac="$1"
    grep -Eiq "^[[:space:]]*$mac([[:space:]]|$)" "$EXCLUSION_FILE" 2>/dev/null
}

device_field() {
    local info_text="$1"
    local key="$2"
    printf '%s\n' "$info_text" | awk -F': ' -v k="$key" '$1 ~ "^[[:space:]]*" k "$" {sub(/^[^:]*: /,""); print; exit}'
}

normalize_oui_prefix() {
    local mac="$1"
    printf '%s\n' "${mac:0:8}" | tr 'a-f' 'A-F'
}

resolve_oui_vendor() {
    local mac="$1"
    local key

    [[ -s "$OUI_FILE" ]] || return 1
    key="$(printf '%s' "${mac:0:8}" | tr -d ':' | tr 'a-f' 'A-F')"

    awk -v key="$key" '
        BEGIN { IGNORECASE=1 }
        toupper($1) == key && $2 == "(base" && $3 == "16)" {
            $1=""; $2=""; $3=""
            sub(/^[[:space:]]+/, "")
            gsub(/\r/, "")
            print
            exit
        }
    ' "$OUI_FILE"
}

classify_random_address() {
    local mac="$1"
    local first_hex="${mac%%:*}"
    local first_dec=$((16#$first_hex))
    local top=$(( first_dec & 0xC0 ))

    case "$top" in
        192) printf 'random-static\n' ;;
        64)  printf 'random-resolvable\n' ;;
        0)   printf 'random-non-resolvable\n' ;;
        128) printf 'random-reserved\n' ;;
        *)   printf 'random\n' ;;
    esac
}

classify_address_type() {
    local mac="$1"
    local bluez_type="${2:-}"
    bluez_type="$(printf '%s' "$bluez_type" | tr '[:upper:]' '[:lower:]')"

    case "$bluez_type" in
        public) printf 'public\n' ;;
        random) classify_random_address "$mac" ;;
        *)      printf 'unknown\n' ;;
    esac
}

is_locally_administered_mac() {
    local mac="$1"
    local first_hex="${mac%%:*}"
    local first_dec=$((16#$first_hex))
    (( first_dec & 0x02 ))
}

validate_oui_file() {
    local file="$1"
    local bytes entries

    [[ -s "$file" ]] || return 1
    bytes="$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]')"
    entries="$(grep -Eic '^[0-9A-F]{6}[[:space:]]+\(base[[:space:]]+16\)' "$file" 2>/dev/null || true)"
    bytes="${bytes:-0}"
    entries="${entries:-0}"

    (( bytes >= 100000 && entries >= 1000 ))
}

refresh_exclusion_enrichment() {
    local line mac prefix vendor type status total=0 resolved=0 local_random=0 unknown=0

    ensure_dirs

    {
        echo "# exclusionsbt_enrichi.txt"
        echo "# Generated by bt_air_suite.sh $VERSION"
        echo "# Generated: $(date --iso-8601=seconds 2>/dev/null || date)"
        echo "# Source exclusions: $EXCLUSION_FILE"
        echo "# OUI source: $OUI_FILE"
        echo "#"
        printf '%-17s | %-8s | %-18s | %-42s | %s\n' "MAC" "OUI" "TYPE" "VENDOR / RESOLUTION" "SOURCE LINE"
        printf '%s\n' "------------------+----------+--------------------+--------------------------------------------+------------------------------------------"
    } > "$EXCLUSION_ENRICHED_FILE"

    {
        echo "# exclusionsbt_oui_resolved.txt"
        echo "# Generated by bt_air_suite.sh $VERSION"
        echo "# Generated: $(date --iso-8601=seconds 2>/dev/null || date)"
        echo "# Only exclusions with a reliable offline IEEE OUI lookup are listed."
        echo "#"
        printf '%-17s | %-8s | %-42s\n' "MAC" "OUI" "VENDOR"
        printf '%s\n' "------------------+----------+--------------------------------------------"
    } > "$EXCLUSION_OUI_RESOLVED_FILE"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        mac="$(printf '%s\n' "$line" | grep -Eo '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -n1 | tr 'a-f' 'A-F')"
        valid_mac "${mac:-}" || continue

        ((total++))
        prefix="$(printf '%s' "$mac" | tr -d ':' | cut -c1-6)"

        if is_locally_administered_mac "$mac"; then
            type="LOCAL/RANDOMIZED"
            vendor="No reliable IEEE OUI attribution"
            status="RANDOM_ADDRESS"
            ((local_random++))
        else
            vendor="$(resolve_oui_vendor "$mac" || true)"
            if [[ -n "$vendor" ]]; then
                type="IEEE OUI"
                status="OUI_RESOLVED"
                ((resolved++))
            else
                type="IEEE OUI"
                vendor="Unknown"
                status="OUI_NOT_FOUND"
                ((unknown++))
            fi
        fi

        printf '%-17s | %-8s | %-18s | %-42s | %s\n' \
            "$mac" "$prefix" "$type" "$vendor" "$line" >> "$EXCLUSION_ENRICHED_FILE"

        if [[ "$status" == "OUI_RESOLVED" ]]; then
            printf '%-17s | %-8s | %-42s\n' \
                "$mac" "$prefix" "$vendor" >> "$EXCLUSION_OUI_RESOLVED_FILE"
        fi
    done < "$EXCLUSION_FILE"

    {
        echo
        echo "# Summary"
        echo "# entries=$total"
        echo "# oui_resolved=$resolved"
        echo "# local_or_randomized=$local_random"
        echo "# oui_not_found=$unknown"
    } >> "$EXCLUSION_ENRICHED_FILE"

    {
        echo
        echo "# resolved=$resolved"
    } >> "$EXCLUSION_OUI_RESOLVED_FILE"
}

run_update_oui() {
    local bytes entries old_present=0

    ensure_dirs

    if (( SIMULATE_MODE == 1 )); then
        say "SIMULATION — OUI database will not be modified."
        say "Would download: $OUI_URL"
        say "Would validate temporary file."
        say "Would preserve current database as: $OUI_BACKUP_FILE"
        say "Would atomically replace: $OUI_FILE"
        return 0
    fi

    OUI_TMP_FILE="$MYINFO_DIR/.oui.txt.tmp.$$"
    rm -f -- "$OUI_TMP_FILE" 2>/dev/null || true

    info "OUI download         : $OUI_URL"
    if has_cmd curl; then
        curl -fL --connect-timeout 15 --max-time 180 --retry 2 \
            --retry-delay 2 -o "$OUI_TMP_FILE" "$OUI_URL" \
            || { rm -f -- "$OUI_TMP_FILE"; OUI_TMP_FILE=""; die "Téléchargement OUI échoué. Base actuelle conservée."; }
    elif has_cmd wget; then
        wget --https-only --timeout=20 --tries=3 -O "$OUI_TMP_FILE" "$OUI_URL" \
            || { rm -f -- "$OUI_TMP_FILE"; OUI_TMP_FILE=""; die "Téléchargement OUI échoué. Base actuelle conservée."; }
    else
        die "curl ou wget est requis pour --update-oui. Lance : ./bt_air_suite.sh --install"
    fi

    if ! validate_oui_file "$OUI_TMP_FILE"; then
        rm -f -- "$OUI_TMP_FILE"
        OUI_TMP_FILE=""
        die "Validation OUI échouée. myinfo/oui.txt n'a pas été modifié."
    fi

    if [[ -s "$OUI_FILE" ]]; then
        cp -f -- "$OUI_FILE" "$OUI_BACKUP_FILE" \
            || { rm -f -- "$OUI_TMP_FILE"; OUI_TMP_FILE=""; die "Impossible de créer $OUI_BACKUP_FILE"; }
        old_present=1
    fi

    mv -f -- "$OUI_TMP_FILE" "$OUI_FILE" \
        || die "Remplacement atomique de $OUI_FILE impossible."
    OUI_TMP_FILE=""

    bytes="$(wc -c < "$OUI_FILE" | tr -d '[:space:]')"
    entries="$(grep -Eic '^[0-9A-F]{6}[[:space:]]+\(base[[:space:]]+16\)' "$OUI_FILE" || true)"

    refresh_exclusion_enrichment

    ok "OUI database updated: $OUI_FILE"
    (( old_present == 1 )) && ok "Previous OUI backup : $OUI_BACKUP_FILE"
    ok "OUI bytes           : $bytes"
    ok "OUI base16 entries  : $entries"
}

write_inventory() {
    local raw="$1"
    local seen_file="$2"
    local csv="$3"
    local jsonl="$4"
    local mac info_text name alias rssi txpower icon paired trusted connected status uuids ts label count=0
    local bluez_address_type address_type oui_prefix vendor oui_status

    ts="$(date --iso-8601=seconds 2>/dev/null || date)"

    printf '%s\n' 'timestamp,mac,address_type,oui_prefix,vendor,oui_status,label,name,alias,rssi,tx_power,icon,paired,trusted,connected,status,uuids' > "$csv"
    : > "$jsonl"

    {
        echo
        echo "===== MACS OBSERVED IN THIS SLICE ====="
        cat "$seen_file" 2>/dev/null || true
    } >> "$raw"

    while IFS= read -r mac; do
        valid_mac "${mac:-}" || continue
        mac="$(normalize_mac "$mac")"
        ((count++))

        info_text="$(bluetoothctl info "$mac" 2>/dev/null || true)"
        printf '\n===== INFO %s =====\n%s\n' "$mac" "$info_text" >> "$raw"

        name="$(device_field "$info_text" "Name")"
        alias="$(device_field "$info_text" "Alias")"
        bluez_address_type="$(device_field "$info_text" "AddressType")"
        address_type="$(classify_address_type "$mac" "$bluez_address_type")"
        oui_prefix="$(normalize_oui_prefix "$mac")"

        rssi="$(last_rssi_from_raw "$raw" "$mac")"
        [[ -n "$rssi" ]] || rssi="$(device_field "$info_text" "RSSI")"

        txpower="$(device_field "$info_text" "TxPower")"
        icon="$(device_field "$info_text" "Icon")"
        paired="$(device_field "$info_text" "Paired")"
        trusted="$(device_field "$info_text" "Trusted")"
        connected="$(device_field "$info_text" "Connected")"
        uuids="$(printf '%s\n' "$info_text" | awk -F': ' '/^[[:space:]]*UUID:/ {sub(/^[^:]*: /,""); printf "%s%s", sep, $0; sep=" | "} END{print ""}')"
        label="${name:-${alias:-}}"
        status="$(known_status "$mac")"

        vendor=""
        case "$address_type" in
            public)
                vendor="$(resolve_oui_vendor "$mac" || true)"
                if [[ -n "$vendor" ]]; then
                    oui_status="OUI_RESOLVED"
                else
                    oui_status="OUI_NOT_FOUND"
                fi
                ;;
            random-*)
                oui_status="RANDOM_ADDRESS"
                ;;
            *)
                oui_status="NOT_APPLICABLE"
                ;;
        esac

        {
            csv_escape "$ts"; printf ','
            csv_escape "$mac"; printf ','
            csv_escape "$address_type"; printf ','
            csv_escape "$oui_prefix"; printf ','
            csv_escape "$vendor"; printf ','
            csv_escape "$oui_status"; printf ','
            csv_escape "$label"; printf ','
            csv_escape "$name"; printf ','
            csv_escape "$alias"; printf ','
            csv_escape "$rssi"; printf ','
            csv_escape "$txpower"; printf ','
            csv_escape "$icon"; printf ','
            csv_escape "$paired"; printf ','
            csv_escape "$trusted"; printf ','
            csv_escape "$connected"; printf ','
            csv_escape "$status"; printf ','
            csv_escape "$uuids"; printf '\n'
        } >> "$csv"

        printf '{"timestamp":"%s","mac":"%s","address_type":"%s","oui_prefix":"%s","vendor":"%s","oui_status":"%s","label":"%s","name":"%s","alias":"%s","rssi":"%s","tx_power":"%s","icon":"%s","paired":"%s","trusted":"%s","connected":"%s","status":"%s","uuids":"%s"}\n' \
            "$(json_escape "$ts")" "$(json_escape "$mac")" "$(json_escape "$address_type")" \
            "$(json_escape "$oui_prefix")" "$(json_escape "$vendor")" "$(json_escape "$oui_status")" \
            "$(json_escape "$label")" "$(json_escape "$name")" "$(json_escape "$alias")" \
            "$(json_escape "$rssi")" "$(json_escape "$txpower")" "$(json_escape "$icon")" \
            "$(json_escape "$paired")" "$(json_escape "$trusted")" "$(json_escape "$connected")" \
            "$(json_escape "$status")" "$(json_escape "$uuids")" >> "$jsonl"

    done < "$seen_file"

    printf '\nseen_device_count=%s\n' "$count" >> "$raw"
    info "Devices seen this slice: $count"
}

filter_inventory() {
    local input="$1"
    local output="$2"
    awk -F',' -v excl_file="$EXCLUSION_FILE" '
        BEGIN {
            while ((getline l < excl_file) > 0) {
                if (match(l,/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/)) {
                    m=toupper(substr(l,RSTART,RLENGTH))
                    excluded[m]=1
                }
            }
            close(excl_file)
        }
        NR==1 {print; next}
        {
            mac=toupper($2)
            gsub(/^"|"$/,"",mac)
            if (!(mac in excluded)) print
        }
    ' "$input" > "$output"
}

csv_to_markdown() {
    local input="$1"
    local output="$2"
    awk -F',' '
        function clean(v) {
            gsub(/^"|"$/,"",v)
            gsub(/""/,"\"",v)
            gsub(/\|/,"\\|",v)
            return v
        }
        NR==1 {
            print "# Bluetooth filtered results"
            print ""
            printf "|"
            for(i=1;i<=NF;i++) printf " %s |", clean($i)
            print ""
            printf "|"
            for(i=1;i<=NF;i++) printf " --- |"
            print ""
            next
        }
        {
            printf "|"
            for(i=1;i<=NF;i++) printf " %s |", clean($i)
            print ""
        }
    ' "$input" > "$output"
}

run_redteam_enrichment() {
    local seen_file="$1"
    local raw="$2"
    local out="$3"
    local mac count=0 success=0
    local probe_timeout=8
    local max_targets=12
    local rc

    [[ "$PROFILE" == "redteam" ]] || return 0

    {
        echo "bt_air_suite=$VERSION"
        echo "mode=redteam-active-enrichment"
        echo "timestamp=$(date --iso-8601=seconds 2>/dev/null || date)"
        echo "source_raw=$(basename "$raw")"
        echo "probe=classic-sdp-browse"
        echo "probe_timeout_seconds=$probe_timeout"
        echo "max_targets=$max_targets"
        echo
        echo "NOTE:"
        echo "- No automatic connect"
        echo "- No automatic pair"
        echo "- No trust/remove"
        echo "- No destructive/fuzz/jamming action"
        echo
    } > "$out"

    if ! has_cmd sdptool; then
        echo "sdptool unavailable: active Classic SDP enrichment skipped." >> "$out"
        warn "REDTEAM: sdptool absent, active SDP enrichment skipped."
        return 0
    fi

    while IFS= read -r mac; do
        valid_mac "${mac:-}" || continue
        (( count >= max_targets )) && {
            warn "REDTEAM: target cap reached ($max_targets); remaining devices not actively probed."
            break
        }

        ((count++))

        {
            echo "================================================================"
            echo "TARGET $count: $mac"
            echo "================================================================"
            echo
            echo "===== bluetoothctl info ====="
            bluetoothctl info "$mac" 2>&1 || true
            echo
            echo "===== bounded Classic SDP browse (${probe_timeout}s max) ====="
        } >> "$out"

        timeout --foreground --signal=INT --kill-after=2s "${probe_timeout}s" \
            sdptool browse "$mac" >> "$out" 2>&1
        rc=$?

        case "$rc" in
            0)
                ((success++))
                echo "redteam_probe_result=success" >> "$out"
                ;;
            124|130|137)
                echo "redteam_probe_result=timeout_or_interrupted rc=$rc" >> "$out"
                ;;
            *)
                echo "redteam_probe_result=not_available_or_failed rc=$rc" >> "$out"
                ;;
        esac
        echo >> "$out"
    done < "$seen_file"

    {
        echo
        echo "redteam_probe_count=$count"
        echo "redteam_probe_success_count=$success"
    } >> "$out"

    info "REDTEAM active probes: $count target(s), $success SDP success(es)"
    ok "REDTEAM report: $out"
}

open_markdown_in_kate() {
    local md_file="$1"

    (( OPEN_KATE == 1 )) || return 0

    if ! command -v kate >/dev/null 2>&1; then
        warn "--open-kate demandé mais Kate est introuvable dans PATH."
        return 1
    fi

    info "Ouverture Kate      : $md_file"
    kate "$md_file" >/dev/null 2>&1 &
    return 0
}

post_process_inventory() {
    local csv="$1"
    local base filtered filtered_md enriched jsonl

    [[ -s "$csv" ]] || {
        warn "CSV vide/introuvable pour post-process : $csv"
        return 1
    }

    base="$(basename "${csv%.csv}")"
    filtered="$FILTERED_DIR/${base}.filtered.csv"
    filtered_md="$FILTERED_DIR/${base}.filtered.md"
    enriched="$ENRICHED_DIR/${base}.enriched.csv"
    jsonl="$JSONL_DIR/${base}.jsonl"

    filter_inventory "$csv" "$filtered"
    csv_to_markdown "$filtered" "$filtered_md"

    # The primary inventory CSV is already OUI-enriched in v2.0.0.
    # Keep the dedicated enriched artifact to mirror the Wi-Fi suite layout.
    cp -f "$filtered" "$enriched"

    refresh_exclusion_enrichment || true

    cp -f "$csv" "$GENERATED_DIR/" 2>/dev/null || true
    cp -f "$filtered" "$GENERATED_DIR/" 2>/dev/null || true
    cp -f "$filtered_md" "$GENERATED_DIR/" 2>/dev/null || true
    cp -f "$enriched" "$GENERATED_DIR/" 2>/dev/null || true
    [[ -f "$jsonl" ]] && cp -f "$jsonl" "$GENERATED_DIR/" 2>/dev/null || true
    [[ "$GLOBAL_LOG_FILE" != "/dev/null" && -f "$GLOBAL_LOG_FILE" ]] \
        && cp -f "$GLOBAL_LOG_FILE" "$GENERATED_DIR/" 2>/dev/null || true

    info "CSV filtré         : $filtered"
    info "MD filtré          : $filtered_md"
    info "CSV enrichi        : $enriched"
    info "Generated          : $GENERATED_DIR"

    [[ -f "$filtered_md" ]] && open_markdown_in_kate "$filtered_md" || true
}

run_scan_slice() {
    local duration="$1"
    local slice_index="${2:-1}"
    local mode raw csv jsonl seen

    generate_prefix
    setup_logs
    mode="$(scan_arg)"
    raw="$RAW_DIR/${PREFIX}.raw.txt"
    csv="$CSV_DIR/${PREFIX}.csv"
    jsonl="$JSONL_DIR/${PREFIX}.jsonl"
    seen="$TMP_DIR/${PREFIX}.seen_macs.txt"

    info "SCAN slice=$slice_index duration=${duration}s transport=$TRANSPORT profile=$PROFILE"
    info "Raw: $raw"

    {
        echo "bt_air_suite=$VERSION"
        echo "timestamp=$(date --iso-8601=seconds 2>/dev/null || date)"
        echo "slice=$slice_index"
        echo "transport=$TRANSPORT"
        echo "profile=$PROFILE"
        echo
    } > "$raw"

    scan_readiness_check || return 1
    run_discovery_window "$duration" "$mode" "$raw" || return 1

    extract_seen_macs "$raw" "$seen"
    write_inventory "$raw" "$seen" "$csv" "$jsonl"

    if [[ "$PROFILE" == "redteam" ]]; then
        run_redteam_enrichment             "$seen"             "$raw"             "$RAW_DIR/${PREFIX}.redteam.txt"
    fi

    ok "CSV   : $csv"
    ok "JSONL : $jsonl"

    if (( POST_PROCESS == 1 )); then
        info "Post-process tranche : démarrage"
        if post_process_inventory "$csv"; then
            ok "Post-process tranche terminé."
        else
            warn "Post-process tranche en erreur ; la tranche suivante continuera."
        fi
    fi
}

prepare_acquisition() {
    ensure_dirs
    need_cmd bluetoothctl
    need_cmd timeout
    if (( OPEN_KATE == 1 )); then
        need_cmd kate
    fi
    refresh_exclusion_enrichment || true
    [[ "$ARCHIVE_OLD" == "1" ]] && archive_old
    register_pid
}

run_scan() {
    simulation_stop
    prepare_acquisition
    run_scan_slice "$(default_scan_duration)" 1         || die "Scan invalide ou interrompu avant la durée demandée."
}

run_monitor() {
    local interval_seconds=0
    local remaining=0
    local slice_duration=""
    local slice_index=1
    local slice_total=1

    simulation_stop
    prepare_acquisition

    info "MONITOR $VERSION"
    info "Durée totale       : ${DURATION:-INFINITE}"
    info "Intervalle         : ${INTERVAL_MINUTES:-DISABLED}${INTERVAL_MINUTES:+ minute(s)}"
    info "Post-process       : $POST_PROCESS"
    info "Open Kate          : $OPEN_KATE"
    info "Accept             : $ACCEPT_MODE"
    info "Logs persistants   : $(( NO_LOG == 0 ? 1 : 0 ))"
    info "Profile            : $PROFILE"
    info "Transport          : $TRANSPORT"

    if [[ -n "$INTERVAL_MINUTES" ]]; then
        interval_seconds=$(( INTERVAL_MINUTES * 60 ))
        if [[ -n "$DURATION" && "$INFINITE" != "1" ]]; then
            slice_total=$(( (DURATION + interval_seconds - 1) / interval_seconds ))
            info "Nombre de tranches : $slice_total"
        else
            slice_total=0
            info "Nombre de tranches : illimité (CTRL-C pour arrêter)"
        fi
    fi

    # Same session semantics as wifi_air_suite:
    # finite duration without --interval => one full-duration slice.
    if [[ -z "$INTERVAL_MINUTES" && -n "$DURATION" && "$INFINITE" != "1" ]]; then
        run_scan_slice "$DURATION" 1 \
            || die "Scan invalide ou interrompu avant la durée demandée."
        return 0
    fi

    # No --interval and no finite duration: BlueZ non-interactive discovery is
    # implemented as repeated 60-second slices until CTRL-C.
    if [[ -z "$INTERVAL_MINUTES" ]]; then
        interval_seconds=60
        slice_total=0
        info "Tranches BlueZ     : 60s en boucle continue"
    fi

    if (( INFINITE == 1 )) || [[ -z "$DURATION" ]]; then
        while :; do
            run_scan_slice "$interval_seconds" "$slice_index" \
                || die "Tranche $slice_index invalide ; monitor arrêté."
            ((slice_index++))
        done
    fi

    remaining="$DURATION"
    while (( remaining > 0 )); do
        if (( remaining < interval_seconds )); then
            slice_duration="$remaining"
        else
            slice_duration="$interval_seconds"
        fi

        run_scan_slice "$slice_duration" "$slice_index" \
            || die "Tranche $slice_index invalide ; monitor arrêté."

        remaining=$(( remaining - slice_duration ))
        ((slice_index++))
    done
}

run_fingerprint() {
    simulation_stop
    ensure_dirs
    need_cmd bluetoothctl
    generate_prefix
    setup_logs
    local out="$RAW_DIR/${PREFIX}.fingerprint.${TARGET//:/-}.txt"

    {
        echo "Target: $TARGET"
        echo "Timestamp: $(date --iso-8601=seconds 2>/dev/null || date)"
        echo
        bluetoothctl info "$TARGET" 2>&1
    } | tee "$out" "$ACTION_LOG_FILE"

    ok "Fingerprint: $out"
}

run_enum_services() {
    simulation_stop
    ensure_dirs
    need_cmd bluetoothctl
    generate_prefix
    setup_logs
    local out="$RAW_DIR/${PREFIX}.services.${TARGET//:/-}.txt"

    {
        echo "Target: $TARGET"
        echo "Timestamp: $(date --iso-8601=seconds 2>/dev/null || date)"
        echo
        echo "===== BlueZ device information / UUIDs ====="
        bluetoothctl info "$TARGET" 2>&1 || true
        echo
        echo "===== Classic SDP ====="
        if has_cmd sdptool; then
            timeout 30s sdptool browse "$TARGET" 2>&1 || true
        else
            echo "sdptool unavailable"
        fi
    } | tee "$out" "$ACTION_LOG_FILE"

    ok "Service report: $out"
}

run_btmon_capture() {
    simulation_stop
    ensure_dirs
    need_cmd btmon
    need_cmd timeout
    sudo_ready
    resolve_hci
    generate_prefix
    setup_logs

    local duration="${DURATION:-60}"
    local out="$CAPTURE_DIR/${PREFIX}.${HCI_IFACE}.btsnoop"

    info "btmon capture: HCI=$HCI_IFACE duration=${duration}s"
    run_privileged timeout --foreground --signal=INT --kill-after=2s "${duration}s" \
        btmon -i "$HCI_IFACE" -w "$out"
    local rc=$?

    case "$rc" in 0|124|130|137) ;; *) warn "btmon returned $rc" ;; esac
    [[ -f "$out" ]] && ok "BTSnoop: $out" || warn "No btsnoop file produced."
}

run_rssi_monitor() {
    simulation_stop
    ensure_dirs
    need_cmd bluetoothctl
    need_cmd timeout
    generate_prefix
    setup_logs
    register_pid

    local duration="${DURATION:-60}"
    local out="$CSV_DIR/${PREFIX}.rssi.${TARGET//:/-}.csv"
    local scanlog="$RAW_DIR/${PREFIX}.rssi.scan.txt"
    local start now rssi

    printf 'timestamp,mac,rssi\n' > "$out"

    scan_readiness_check || die "Contrôleur non prêt pour le suivi RSSI."

    bluetoothctl --timeout "$duration" scan "$(scan_arg)" >"$scanlog" 2>&1 &
    local scanpid=$!

    start="$(date +%s)"
    while kill -0 "$scanpid" 2>/dev/null; do
        now="$(date +%s)"
        (( now - start < duration )) || break
        rssi="$(bluetoothctl info "$TARGET" 2>/dev/null | awk -F': ' '/^[[:space:]]*RSSI:/ {print $2; exit}')"
        printf '"%s","%s","%s"\n' "$(date --iso-8601=seconds 2>/dev/null || date)" "$TARGET" "$rssi" >> "$out"
        printf '%s %s RSSI=%s\n' "$(date '+%H:%M:%S')" "$TARGET" "${rssi:-n/a}"
        sleep "$RSSI_POLL"
    done

    wait "$scanpid" 2>/dev/null || true
    bluetoothctl scan off >/dev/null 2>&1 || true

    now="$(date +%s)"
    if (( duration > 2 && now - start < duration - 2 )); then
        warn "Le scan RSSI s'est arrêté avant la durée demandée."
    fi

    ok "RSSI CSV: $out"
}

run_connect_test() {
    simulation_stop
    ensure_dirs
    need_cmd bluetoothctl
    generate_prefix
    setup_logs

    info "Authorized connect test: $TARGET"
    bluetoothctl --timeout 20 connect "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE"
    bluetoothctl info "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE"
    bluetoothctl --timeout 10 disconnect "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE" || true
}

run_pair_test() {
    simulation_stop
    ensure_dirs
    need_cmd bluetoothctl
    generate_prefix
    setup_logs

    warn "PAIR TEST modifies pairing state. Target must be owned/authorized: $TARGET"
    bluetoothctl --agent NoInputNoOutput --timeout 45 pair "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE"
    bluetoothctl info "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE" || true
    bluetoothctl disconnect "$TARGET" >/dev/null 2>&1 || true

    if (( CLEANUP_PAIR == 1 )); then
        bluetoothctl remove "$TARGET" 2>&1 | tee -a "$ACTION_LOG_FILE" || true
    fi
}

run_secure() {
    simulation_stop
    need_cmd bluetoothctl
    info "Applying secure controller state."
    run_btctl_script 15 "power on" "pairable off" "discoverable off" "show"
}

run_power() {
    local state="$1"
    simulation_stop
    need_cmd bluetoothctl

    if [[ "$state" == "on" ]] && has_cmd rfkill && bluetooth_soft_blocked; then
        sudo_ready
        info "rfkill: déblocage Bluetooth."
        run_privileged rfkill unblock bluetooth             || die "Impossible de débloquer Bluetooth via rfkill."
    fi

    run_btctl_script 10 "power $state" "show"
}

hotplug_paths() {
    HOTPLUG_SCRIPT="/usr/local/sbin/bt_air_suite.sh"
    HOTPLUG_SERVICE="/etc/systemd/system/bt-air-suite-ub500.service"
    HOTPLUG_RULE="/etc/udev/rules.d/90-bt-air-suite-ub500.rules"
}

run_hotplug_install() {
    simulation_stop
    sudo_ready
    need_cmd systemctl
    need_cmd udevadm
    hotplug_paths

    local vid="${UB500_ID%:*}"
    local pid="${UB500_ID#*:}"
    local tmp_service="$TMP_DIR/bt-air-suite-ub500.service"
    local tmp_rule="$TMP_DIR/90-bt-air-suite-ub500.rules"

    ensure_dirs
    cp -f "$0" "$TMP_DIR/bt_air_suite.sh"

    cat > "$tmp_service" <<EOF
[Unit]
Description=bt_air_suite secure Bluetooth controller after UB500 attach
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=oneshot
ExecStart=$HOTPLUG_SCRIPT --exec --secure --nolog
EOF

    cat > "$tmp_rule" <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${vid,,}", ATTR{idProduct}=="${pid,,}", RUN+="/bin/systemctl --no-block start bt-air-suite-ub500.service"
EOF

    run_privileged install -m 0755 "$TMP_DIR/bt_air_suite.sh" "$HOTPLUG_SCRIPT"
    run_privileged install -m 0644 "$tmp_service" "$HOTPLUG_SERVICE"
    run_privileged install -m 0644 "$tmp_rule" "$HOTPLUG_RULE"
    run_privileged systemctl daemon-reload
    run_privileged udevadm control --reload-rules
    run_privileged udevadm trigger
    ok "Hotplug installed for USB $UB500_ID"
}

run_hotplug_remove() {
    simulation_stop
    sudo_ready
    hotplug_paths
    run_privileged rm -f "$HOTPLUG_SERVICE" "$HOTPLUG_RULE" "$HOTPLUG_SCRIPT"
    run_privileged systemctl daemon-reload
    run_privileged udevadm control --reload-rules
    ok "Suite hotplug files removed."
}

run_hotplug_test() {
    simulation_stop
    hotplug_paths
    say "USB ID: $UB500_ID"
    lsusb | grep -i "$UB500_ID" || warn "USB ID not currently present."
    say
    if [[ -f "$HOTPLUG_SERVICE" ]]; then
        systemctl --no-pager --full status bt-air-suite-ub500.service 2>/dev/null | head -n 30 || true
    else
        warn "Hotplug service not installed."
    fi
    say
    [[ -f "$HOTPLUG_RULE" ]] && cat "$HOTPLUG_RULE" || warn "Hotplug udev rule not installed."
}

main() {
    parse_args "$@"

    case "$ACTION" in
        status) run_status ;;
        update-oui) run_update_oui ;;
        prerequis) run_prerequis ;;
        install) run_install ;;
        doctor) doctor ;;
        init) init_layout ;;
        show-paths) show_paths ;;
        print-config) print_config ;;
        list-results) list_results ;;
        stop) stop_action ;;
        purge) purge_action ;;

        scan) run_scan ;;
        monitor) run_monitor ;;
        fingerprint) run_fingerprint ;;
        enum-services) run_enum_services ;;
        capture-btmon) run_btmon_capture ;;
        rssi-monitor) run_rssi_monitor ;;
        connect-test) run_connect_test ;;
        pair-test) run_pair_test ;;
        secure) run_secure ;;
        power-on) run_power on ;;
        power-off) run_power off ;;
        hotplug-install) run_hotplug_install ;;
        hotplug-remove) run_hotplug_remove ;;
        hotplug-test) run_hotplug_test ;;
        *) die "Action inconnue: $ACTION" ;;
    esac
}

main "$@"
