#!/usr/bin/env bash
# ==============================================================================
# PATH         : ./bt_air_suite.sh
# SCRIPT NAME  : bt_air_suite.sh
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Bluetooth / BLE defensive + authorized Red Team Swiss Army Knife
# VERSION      : v1.0.0
# DATE         : 2026-09-23
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

VERSION="v1.0.0"
SCRIPT_DATE="2026-09-23"
SCRIPT_AUTHOR="Bruno DELNOZ"
SCRIPT_EMAIL="bruno.delnoz@protonmail.com"

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$BASE_DIR"

MYINFO_DIR="$BASE_DIR/myinfo"
KNOWN_FILE="$MYINFO_DIR/known_devices.txt"
EXCLUSION_FILE="$MYINFO_DIR/exclusions.txt"

RUNTIME_DIR="$BASE_DIR/.results"
RAW_DIR="$RUNTIME_DIR/raw"
CSV_DIR="$RUNTIME_DIR/csv"
JSONL_DIR="$RUNTIME_DIR/jsonl"
FILTERED_DIR="$RUNTIME_DIR/filtered"
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
  Bluetooth / BLE Swiss Army Knife for Linux/Kali.
  Defensive discovery + explicit authorized Red Team inspection/test actions.

USAGE:
  ./bt_air_suite.sh --help
  ./bt_air_suite.sh --prerequis
  ./bt_air_suite.sh --doctor
  ./bt_air_suite.sh --simulate --<action> [OPTIONS]
  ./bt_air_suite.sh --exec --<action> [OPTIONS]

CONTROL / INFORMATION:
  --help, -h
  --version
  --changelog, -ch
  --prerequis, -pr
  --install, -i
  --doctor
  --init
  --show-paths
  --print-config
  --list-results
  --stop, -st
  --purge, -pu

BUSINESS ACTIONS:
  --status
      Read controller / BlueZ / rfkill status. No --exec required.

  --scan
      One Bluetooth discovery slice.

  --monitor
      Rolling Bluetooth discovery slices until duration expires or CTRL-C.

  --fingerprint
      Collect detailed BlueZ information for --target MAC.

  --enum-services
      Enumerate UUID/service information for --target.
      Uses bluetoothctl and sdptool when available.

  --capture-btmon
      Record an HCI monitor trace with btmon in btsnoop format.

  --rssi-monitor
      Track RSSI for --target while discovery is active.

  --connect-test
      Explicit authorized connection/disconnection test against --target.

  --pair-test
      Explicit authorized pairing test against --target.
      Pairing changes local/remote pairing state. Use only on owned/lab devices.
      --cleanup-pair removes the local pairing record after the test.

  --secure
      Power controller on, pairable off, discoverable off.

  --power-on
  --power-off

  --hotplug-install
      Install a TP-Link UB500-style udev/systemd secure-on-attach hook.

  --hotplug-remove
      Remove the udev/systemd hook installed by this suite.

  --hotplug-test
      Inspect USB presence and installed hotplug unit state.

EXECUTION GATES:
  --exec, -exe
      Authorize real operational execution.

  --simulate, -s, --dry-run
      Parse and print the planned operation without Bluetooth/system changes.

COMMON OPTIONS:
  --controller VALUE
      auto, hciN, or Bluetooth controller MAC. Default: auto

  --transport auto|le|bredr
      Discovery transport. Default: auto

  -d, --duration SECONDS
      Action/session duration in seconds.

  --infinite
      Infinite monitor until CTRL-C.

  --interval MINUTES
      Rolling monitor slice interval in minutes.

  --profile passive|standard|redteam
      passive  : discovery/capture focus
      standard : normal inspection
      redteam  : faster active discovery and richer inspection defaults

  --aggressive-scan
      Alias for --profile redteam.

  --target MAC
      Explicit remote device target.

  --post-process
      Create filtered CSV/Markdown generated artifacts.

  --open-kate
      Open generated filtered Markdown asynchronously.
      Requires --post-process.

  -X, --exclusions-file FILE
      Device MAC exclusions file.

  --known-file FILE
      Known/trusted device list.

  --rssi-poll SECONDS
      RSSI sampling interval. Default: $RSSI_POLL

  --ub500-id VVVV:PPPP
      USB ID used by hotplug support. Default: $UB500_ID

  --cleanup-pair
      With --pair-test, remove local pairing after the test.

  --archive-old
      Archive current runtime result files before an acquisition action.

  --nolog, --no-log
      Disable persistent *.log files. Result data is still generated.

  --dest_dir DIR, --dest-dir DIR
      Override .results runtime root.

RED TEAM BOUNDARY:
  This release implements active discovery, fingerprinting, service enumeration,
  connection tests, pairing tests, RSSI tracking and HCI capture.
  RF jamming, forced disruption, destructive crash testing and aggressive fuzzing
  are intentionally not implemented in the generic action set.

EXAMPLES:
  ./bt_air_suite.sh --status
  ./bt_air_suite.sh --doctor

  ./bt_air_suite.sh --simulate --scan --transport le -d 20 --post-process
  ./bt_air_suite.sh --exec --scan --transport le -d 20 --post-process

  ./bt_air_suite.sh --exec --monitor --infinite --interval 1 --profile redteam --post-process --nolog

  ./bt_air_suite.sh --exec --fingerprint --target AA:BB:CC:DD:EE:FF --profile redteam
  ./bt_air_suite.sh --exec --enum-services --target AA:BB:CC:DD:EE:FF
  ./bt_air_suite.sh --exec --rssi-monitor --target AA:BB:CC:DD:EE:FF -d 60

  ./bt_air_suite.sh --exec --capture-btmon --controller hci0 -d 60

  ./bt_air_suite.sh --exec --connect-test --target AA:BB:CC:DD:EE:FF
  ./bt_air_suite.sh --exec --pair-test --target AA:BB:CC:DD:EE:FF --cleanup-pair

  ./bt_air_suite.sh --exec --secure
  ./bt_air_suite.sh --exec --hotplug-install --ub500-id 2357:0604

EOF
}

show_changelog() {
    cat <<'EOF'
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
            --open-kate) OPEN_KATE=1; shift ;;
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

    if (( OPEN_KATE == 1 && POST_PROCESS == 0 )); then
        die "--open-kate exige --post-process."
    fi

    case "$ACTION" in
        fingerprint|enum-services|rssi-monitor|connect-test|pair-test)
            [[ -n "$TARGET" ]] || die "--$ACTION exige --target MAC."
            ;;
    esac
}

ensure_dirs() {
    mkdir -p "$MYINFO_DIR" "$RAW_DIR" "$CSV_DIR" "$JSONL_DIR" "$FILTERED_DIR" \
             "$GENERATED_DIR" "$CAPTURE_DIR" "$LOG_DIR" "$TMP_DIR" "$ARCHIVE_DIR"
    [[ -f "$KNOWN_FILE" ]] || : > "$KNOWN_FILE"
    [[ -f "$EXCLUSION_FILE" ]] || : > "$EXCLUSION_FILE"
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
    for d in "$RAW_DIR" "$CSV_DIR" "$JSONL_DIR" "$FILTERED_DIR" "$GENERATED_DIR" "$CAPTURE_DIR"; do
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
    return "$rc"
}

run_install() {
    if (( SIMULATE_MODE == 1 )); then
        say "SIMULATION: apt-get update"
        say "SIMULATION: apt-get install -y bluez rfkill usbutils"
        return 0
    fi
    sudo_ready
    run_privileged apt-get update
    run_privileged apt-get install -y bluez rfkill usbutils
}

show_paths() {
    cat <<EOF
BASE_DIR=$BASE_DIR
MYINFO_DIR=$MYINFO_DIR
KNOWN_FILE=$KNOWN_FILE
EXCLUSION_FILE=$EXCLUSION_FILE
RUNTIME_DIR=$RUNTIME_DIR
RAW_DIR=$RAW_DIR
CSV_DIR=$CSV_DIR
JSONL_DIR=$JSONL_DIR
FILTERED_DIR=$FILTERED_DIR
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
NO_LOG=$NO_LOG
RSSI_POLL=$RSSI_POLL
UB500_ID=$UB500_ID
CLEANUP_PAIR=$CLEANUP_PAIR
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
    ok "Layout initialized."
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
        scan) say "Would run one discovery slice and inventory devices." ;;
        monitor) say "Would run rolling discovery slices and per-slice inventory." ;;
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

write_inventory() {
    local raw="$1"
    local csv="$2"
    local jsonl="$3"
    local devices mac label info_text name alias rssi txpower icon paired trusted connected status uuids ts

    ts="$(date --iso-8601=seconds 2>/dev/null || date)"

    printf '%s\n' 'timestamp,mac,label,name,alias,rssi,tx_power,icon,paired,trusted,connected,status,uuids' > "$csv"
    : > "$jsonl"

    devices="$(bluetoothctl devices 2>/dev/null || true)"
    printf '%s\n' "$devices" >> "$raw"

    while read -r _ mac label; do
        valid_mac "${mac:-}" || continue
        mac="$(normalize_mac "$mac")"

        info_text="$(bluetoothctl info "$mac" 2>/dev/null || true)"
        printf '\n===== %s =====\n%s\n' "$mac" "$info_text" >> "$raw"

        name="$(device_field "$info_text" "Name")"
        alias="$(device_field "$info_text" "Alias")"
        rssi="$(device_field "$info_text" "RSSI")"
        txpower="$(device_field "$info_text" "TxPower")"
        icon="$(device_field "$info_text" "Icon")"
        paired="$(device_field "$info_text" "Paired")"
        trusted="$(device_field "$info_text" "Trusted")"
        connected="$(device_field "$info_text" "Connected")"
        uuids="$(printf '%s\n' "$info_text" | awk -F': ' '/^[[:space:]]*UUID:/ {sub(/^[^:]*: /,""); printf "%s%s", sep, $0; sep=" | "} END{print ""}')"
        status="$(known_status "$mac")"

        {
            csv_escape "$ts"; printf ','
            csv_escape "$mac"; printf ','
            csv_escape "${label:-}"; printf ','
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

        printf '{"timestamp":"%s","mac":"%s","label":"%s","name":"%s","alias":"%s","rssi":"%s","tx_power":"%s","icon":"%s","paired":"%s","trusted":"%s","connected":"%s","status":"%s","uuids":"%s"}\n' \
            "$(json_escape "$ts")" "$(json_escape "$mac")" "$(json_escape "${label:-}")" \
            "$(json_escape "$name")" "$(json_escape "$alias")" "$(json_escape "$rssi")" \
            "$(json_escape "$txpower")" "$(json_escape "$icon")" "$(json_escape "$paired")" \
            "$(json_escape "$trusted")" "$(json_escape "$connected")" "$(json_escape "$status")" \
            "$(json_escape "$uuids")" >> "$jsonl"

    done <<< "$devices"
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

post_process_inventory() {
    local csv="$1"
    local base filtered md
    base="$(basename "${csv%.csv}")"
    filtered="$FILTERED_DIR/${base}.filtered.csv"
    md="$FILTERED_DIR/${base}.filtered.md"

    filter_inventory "$csv" "$filtered"
    csv_to_markdown "$filtered" "$md"

    cp -f "$csv" "$GENERATED_DIR/" 2>/dev/null || true
    cp -f "$filtered" "$GENERATED_DIR/" 2>/dev/null || true
    cp -f "$md" "$GENERATED_DIR/" 2>/dev/null || true

    ok "Filtered CSV: $filtered"
    ok "Filtered MD : $md"

    if (( OPEN_KATE == 1 )); then
        if has_cmd kate; then
            kate "$md" >/dev/null 2>&1 &
        else
            warn "Kate introuvable."
        fi
    fi
}

run_scan_slice() {
    local duration="$1"
    local slice_index="${2:-1}"
    local mode raw csv jsonl rc

    generate_prefix
    setup_logs
    mode="$(scan_arg)"
    raw="$RAW_DIR/${PREFIX}.raw.txt"
    csv="$CSV_DIR/${PREFIX}.csv"
    jsonl="$JSONL_DIR/${PREFIX}.jsonl"

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

    # bluetoothctl scan is attached to its D-Bus client. Bound the client duration.
    set +e
    timeout --foreground --signal=INT --kill-after=2s "${duration}s" \
        bluetoothctl scan "$mode" 2>&1 | tee -a "$raw" "$ACTION_LOG_FILE"
    rc=${PIPESTATUS[0]}
    set -e 2>/dev/null || true

    bluetoothctl scan off >/dev/null 2>&1 || true

    case "$rc" in
        0|124|130|137) ;;
        *) warn "bluetoothctl scan returned $rc" ;;
    esac

    write_inventory "$raw" "$csv" "$jsonl"
    ok "CSV   : $csv"
    ok "JSONL : $jsonl"

    if (( POST_PROCESS == 1 )); then
        post_process_inventory "$csv"
    fi
}

prepare_acquisition() {
    ensure_dirs
    need_cmd bluetoothctl
    need_cmd timeout
    [[ "$ARCHIVE_OLD" == "1" ]] && archive_old
    register_pid
}

run_scan() {
    simulation_stop
    prepare_acquisition
    run_scan_slice "$(default_scan_duration)" 1
}

run_monitor() {
    local interval_seconds total remaining slice_duration index=1

    simulation_stop
    prepare_acquisition

    if [[ -n "$INTERVAL_MINUTES" ]]; then
        interval_seconds=$(( INTERVAL_MINUTES * 60 ))
    elif [[ "$PROFILE" == "redteam" ]]; then
        interval_seconds=30
    else
        interval_seconds=60
    fi

    if (( INFINITE == 1 )) || [[ -z "$DURATION" ]]; then
        info "MONITOR infinite. Slice=${interval_seconds}s"
        while :; do
            run_scan_slice "$interval_seconds" "$index"
            ((index++))
        done
    fi

    total="$DURATION"
    remaining="$total"
    while (( remaining > 0 )); do
        if (( remaining < interval_seconds )); then
            slice_duration="$remaining"
        else
            slice_duration="$interval_seconds"
        fi
        run_scan_slice "$slice_duration" "$index"
        remaining=$(( remaining - slice_duration ))
        ((index++))
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
    set +e
    run_privileged timeout --foreground --signal=INT --kill-after=2s "${duration}s" \
        btmon -i "$HCI_IFACE" -w "$out"
    local rc=$?
    set -e 2>/dev/null || true

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

    timeout --foreground --signal=INT --kill-after=2s "${duration}s" \
        bluetoothctl scan "$(scan_arg)" >"$scanlog" 2>&1 &
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
