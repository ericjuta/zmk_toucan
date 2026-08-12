#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir="$repo_root/beekeeb-zmk-keyboard-toucan"
workspace="$project_dir/.zmk-workspace"
manifest_src="$project_dir/config/west.yml"
lock_file="$project_dir/config/west.lock"
requirements_file="$project_dir/config/build-requirements.txt"
build_venv="$workspace/.build-venv"
manifest_dir="$workspace/config"
build_root="$workspace/build"
left_build="$build_root/toucan_left_uf2_current"
right_build="$build_root/toucan_right_uf2_current"
reset_build="$build_root/settings_reset_uf2"
firmware_out="$project_dir/firmware-out"
zmk_app="$workspace/zmk/app"

zmk_sha=edf5c0814fd3ea202e43aad2d68fd32e882a518c
zephyr_sha=dacab4875df72109b96cc8977547a0dc04875bcd
rgb_sha=8756cb7b8114069fa3c25c6f6c990f24988fceff
azoteq_sha=c329f309b7481e5723603550b15f48e24d0c8a6a
zoom_sha=91bbe0c0e02145da50c9df798489479d28be1804

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_file() {
    [ -f "$1" ] || fail "missing $2: $1"
}

require_match() {
    if ! rg -q -- "$3" "$1"; then
        fail "missing $2: $1"
    fi
}

require_multiline_match() {
    if ! rg -Uq -- "$3" "$1"; then
        fail "missing $2: $1"
    fi
}

reject_match() {
    if rg -qi -- "$3" "$1"; then
        fail "unexpected $2: $1"
    fi
}

reject_multiline_match() {
    if rg -Uq -- "$3" "$1"; then
        fail "unexpected $2: $1"
    fi
}

sha256_files() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    else
        shasum -a 256 "$@"
    fi
}

venv_matches_requirements() {
    [ -x "$build_venv/bin/python" ] || return 1
    cmp -s "$requirements_file" "$build_venv/requirements.txt" || return 1
    "$build_venv/bin/python" -W ignore::UserWarning -c \
        'import elftools, google.protobuf, grpc_tools.protoc, packaging, pkg_resources, pykwalify, west, yaml' ||
        return 1
    "$build_venv/bin/python" -m pip freeze --all --disable-pip-version-check |
        cmp -s "$requirements_file" -
}

atomic_swap_dirs() {
    "$python_path" - "$1" "$2" <<'PY'
import ctypes
import os
import sys

libc = ctypes.CDLL(None, use_errno=True)
old = os.fsencode(sys.argv[1])
new = os.fsencode(sys.argv[2])

if sys.platform == "darwin":
    rename = libc.renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    result = rename(old, new, 0x00000002)  # RENAME_SWAP
elif sys.platform.startswith("linux"):
    rename = libc.renameat2
    rename.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    result = rename(-100, old, -100, new, 0x00000002)  # AT_FDCWD, RENAME_EXCHANGE
else:
    raise SystemExit(f"atomic directory exchange is unsupported on {sys.platform}")

if result:
    error = ctypes.get_errno()
    raise SystemExit(f"atomic directory exchange failed: {os.strerror(error)}")
PY
}
verify_patch_diff() {
    checkout=$1
    patch=$2
    label=$3
    shift 3
    actual=$(mktemp "${TMPDIR:-/tmp}/toucan-patch.XXXXXX")
    trap 'rm -f "$actual"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    git -C "$checkout" \
        -c core.attributesFile=/dev/null \
        -c diff.noprefix=false \
        -c diff.mnemonicPrefix=false \
        -c diff.context=3 \
        -c diff.algorithm=myers \
        -c diff.orderFile=/dev/null \
        -c diff.suppressBlankEmpty=false \
        diff -O/dev/null --src-prefix=a/ --dst-prefix=b/ --unified=3 \
        --inter-hunk-context=0 --diff-algorithm=myers --no-indent-heuristic \
        --no-renames --no-relative --no-color --no-ext-diff --no-textconv \
        --binary HEAD -- "$@" >"$actual"
    if ! cmp -s "$patch" "$actual"; then
        fail "$label checkout content differs from its tracked patch"
    fi

    rm -f "$actual"
    trap - EXIT HUP INT TERM
}

project_head() {
    git -C "$1" rev-parse HEAD
}

verify_head() {
    actual=$(project_head "$1")
    [ "$actual" = "$2" ] || fail "$3 is at $actual, expected $2; update it deliberately before building"
}
verify_west_lock() {
    lock_actual=$(mktemp "${TMPDIR:-/tmp}/toucan-west-actual.XXXXXX")
    lock_expected=$(mktemp "${TMPDIR:-/tmp}/toucan-west-expected.XXXXXX")
    trap 'rm -f "$lock_actual" "$lock_expected"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if ! (
        CDPATH= cd -- "$workspace"
        west list -f '{name} {path}'
    ) >"$lock_actual"; then
        fail "cannot enumerate active west projects"
    fi
    printf 'manifest config\n' >"$lock_expected"
    cut -d ' ' -f1-2 "$lock_file" >>"$lock_expected"
    LC_ALL=C sort -u -o "$lock_actual" "$lock_actual"
    LC_ALL=C sort -u -o "$lock_expected" "$lock_expected"
    if ! cmp -s "$lock_expected" "$lock_actual"; then
        printf 'Active west projects differ from %s:\n' "$lock_file" >&2
        diff -u "$lock_expected" "$lock_actual" >&2 || true
        fail "west project set does not match the dependency lock"
    fi

    rm -f "$lock_actual" "$lock_expected"
    trap - EXIT HUP INT TERM

    while IFS=' ' read -r lock_name lock_path lock_sha lock_extra ||
        [ -n "$lock_name$lock_path$lock_sha${lock_extra:-}" ]; do
        [ -n "$lock_name" ] && [ -n "$lock_path" ] && [ -n "$lock_sha" ] &&
            [ -z "${lock_extra:-}" ] ||
            fail "malformed dependency lock row for ${lock_name:-unknown}"
        if ! lock_head=$(git -C "$workspace/$lock_path" rev-parse HEAD); then
            fail "cannot read $lock_name HEAD"
        fi
        [ "$lock_head" = "$lock_sha" ] ||
            fail "$lock_name is at $lock_head, expected $lock_sha"
        case "$lock_path" in
        zmk | zephyr | zmk-rgbled-widget | zmk_driver_azoteq | zmk-input-zoom)
            ;;
        *)
            verify_dirty_paths "$workspace/$lock_path" "$lock_name"
            ;;
        esac
    done <"$lock_file"
}


apply_patch() {
    checkout=$1
    patch=$2
    label=$3
    require_file "$patch" "$label patch"

    if git -C "$checkout" apply --check "$patch" >/dev/null 2>&1; then
        git -C "$checkout" apply "$patch"
    elif git -C "$checkout" apply --reverse --check "$patch" >/dev/null 2>&1; then
        :
    else
        fail "$label patch is neither cleanly applicable nor already applied: $patch"
    fi
}

verify_dirty_paths() {
    checkout=$1
    label=$2
    shift 2
    raw=$(mktemp "${TMPDIR:-/tmp}/toucan-status.XXXXXX")
    actual=$(mktemp "${TMPDIR:-/tmp}/toucan-dirty.XXXXXX")
    expected=$(mktemp "${TMPDIR:-/tmp}/toucan-expected.XXXXXX")
    trap 'rm -f "$raw" "$actual" "$expected"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if ! git -C "$checkout" status --porcelain --untracked-files=all >"$raw"; then
        fail "cannot read dirty paths in $label"
    fi
    cut -c4- "$raw" | LC_ALL=C sort -u >"$actual"
    if [ "$#" -gt 0 ]; then
        printf '%s\n' "$@" | LC_ALL=C sort -u >"$expected"
    else
        : >"$expected"
    fi
    if ! cmp -s "$actual" "$expected"; then
        printf 'Unexpected dirty paths in %s:\n' "$label" >&2
        diff -u "$expected" "$actual" >&2 || true
        fail "$label checkout does not match the tracked patch set"
    fi

    rm -f "$raw" "$actual" "$expected"
    trap - EXIT HUP INT TERM
}

configure_target() {
    build_dir=$1
    shield=$2
    extra_modules=$3
    shift 3
    if [ -e "$build_root" ] || [ -L "$build_root" ]; then
        [ -d "$build_root" ] && [ ! -L "$build_root" ] ||
            fail "build root is not a real directory: $build_root"
    fi
    case "$build_dir" in
    "$build_root"/*) ;;
    *) fail "refusing to replace non-canonical build directory: $build_dir" ;;
    esac
    rm -rf "$build_dir"
    mkdir -p "$build_dir"


    ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb GNUARMEMB_TOOLCHAIN_PATH="$toolchain_root" \
        cmake -S "$zmk_app" -B "$build_dir" -G Ninja \
            -DBOARD=seeeduino_xiao_ble \
            -DSHIELD="$shield" \
            -DZMK_CONFIG="$project_dir/config" \
            -DBOARD_ROOT="$zmk_app;$project_dir;$workspace/zmk-rgbled-widget" \
            -DZMK_EXTRA_MODULES="$extra_modules" \
            -DZEPHYR_BASE="$workspace/zephyr" \
            -DZephyr_DIR="$workspace/zephyr/share/zephyr-package/cmake" \
            -DPython3_EXECUTABLE="$python_path" \
            -DCMAKE_C_COMPILER="$compiler_path" \
            -DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
            "$@"
    cmake --build "$build_dir"
}

for command_name in cmake ninja west git rg cmp diff sed cut sort mktemp python3 arm-none-eabi-gcc; do
    require_command "$command_name"
done

compiler_version=$(arm-none-eabi-gcc -dumpfullversion -dumpversion)
[ "$compiler_version" = 15.2.1 ] || fail "arm-none-eabi-gcc 15.2.1 is required; found $compiler_version"
compiler_path=$(command -v arm-none-eabi-gcc)
toolchain_root=$(CDPATH= cd -- "$(dirname -- "$compiler_path")/.." && pwd)
bootstrap_west_path=$(command -v west)
bootstrap_west_version=$("$bootstrap_west_path" --version)
[ "$bootstrap_west_version" = "West version: v1.5.0" ] ||
    fail "west 1.5.0 is required; found $bootstrap_west_version"
bootstrap_python_path=$(command -v python3)
"$bootstrap_python_path" -c \
    'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' ||
    fail "python3 3.10 or newer is required"
require_file "$requirements_file" "build Python requirements"
require_match "$manifest_src" "ZMK manifest pin" "revision: $zmk_sha$"
require_match "$manifest_src" "Zephyr manifest pin" "revision: $zephyr_sha$"
require_match "$manifest_src" "RGB widget manifest pin" "revision: $rgb_sha$"
require_match "$manifest_src" "Azoteq manifest pin" "revision: $azoteq_sha$"
require_match "$manifest_src" "zoom manifest pin" "revision: $zoom_sha$"
require_file "$lock_file" "west dependency lock"

if [ -e "$workspace" ] || [ -L "$workspace" ]; then
    [ -d "$workspace" ] && [ ! -L "$workspace" ] ||
        fail "workspace path is not a real directory: $workspace"
fi

if [ ! -d "$workspace/.west" ]; then
    [ ! -e "$workspace" ] ||
        fail "workspace exists without .west; move it aside before rebuilding: $workspace"

    bootstrap_dir=""
    init_cwd=""
    cleanup_bootstrap() {
        if [ -n "$init_cwd" ] && [ -d "$init_cwd" ]; then
            rm -rf "$init_cwd"
        fi
        if [ -n "$bootstrap_dir" ] && [ -d "$bootstrap_dir" ]; then
            rm -rf "$bootstrap_dir"
        fi
    }
    bootstrap_dir=$(mktemp -d "$project_dir/.zmk-workspace.bootstrap.XXXXXX")
    trap cleanup_bootstrap EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    init_cwd=$(mktemp -d "${TMPDIR:-/tmp}/toucan-west-init.XXXXXX")
    mkdir -p "$bootstrap_dir/config"
    cp "$manifest_src" "$bootstrap_dir/config/west.yml"
    if ! (
        unset ZEPHYR_BASE
        CDPATH= cd -- "$init_cwd"
        "$bootstrap_west_path" init -l --mf west.yml "$bootstrap_dir/config"
        CDPATH= cd -- "$bootstrap_dir"
        "$bootstrap_west_path" update
    ); then
        fail "failed to bootstrap the pinned west workspace"
    fi
    [ ! -e "$workspace" ] ||
        fail "workspace path appeared during bootstrap: $workspace"
    mv "$bootstrap_dir" "$workspace"
    bootstrap_dir=""
    rm -rf "$init_cwd"
    init_cwd=""
    trap - EXIT HUP INT TERM
fi

mkdir -p "$manifest_dir"
if ! cmp -s "$manifest_src" "$manifest_dir/west.yml"; then
    cp "$manifest_src" "$manifest_dir/west.yml"
fi

if ! venv_matches_requirements; then
    rm -rf "$build_venv"
    "$bootstrap_python_path" -m venv "$build_venv"
    "$build_venv/bin/python" -m pip install --disable-pip-version-check --no-input \
        -r "$requirements_file"
    cp "$requirements_file" "$build_venv/requirements.txt"
fi

python_path="$build_venv/bin/python"
PATH="$build_venv/bin:$PATH"
export PATH
venv_matches_requirements ||
    fail "pinned build Python does not exactly match $requirements_file"

require_file "$workspace/.west/config" "west workspace configuration"
require_match "$workspace/.west/config" "local manifest path" '^path = config$'
require_match "$workspace/.west/config" "local manifest file" '^file = west.yml$'
verify_west_lock

verify_head "$workspace/zmk" "$zmk_sha" ZMK
verify_head "$workspace/zephyr" "$zephyr_sha" Zephyr
verify_head "$workspace/zmk-rgbled-widget" "$rgb_sha" zmk-rgbled-widget
verify_head "$workspace/zmk_driver_azoteq" "$azoteq_sha" zmk_driver_azoteq
verify_head "$workspace/zmk-input-zoom" "$zoom_sha" zmk-input-zoom

apply_patch "$workspace/zmk" "$repo_root/patches/zmk/0001-gcc15-case-scope.patch" "ZMK GCC 15"
apply_patch "$workspace/zmk" "$repo_root/patches/zmk/0002-split-input-reliability.patch" "ZMK split input reliability"
apply_patch "$workspace/zmk" "$repo_root/patches/zmk/0003-xiao-ble-qspi-flash.patch" "XIAO BLE QSPI flash selection"
apply_patch "$workspace/zmk-rgbled-widget" "$repo_root/patches/zmk-rgbled-widget/0001-gcc15-case-scope.patch" "RGB widget GCC 15"
apply_patch "$workspace/zmk_driver_azoteq" "$repo_root/patches/zmk-driver-azoteq/0001-tps43-runtime-reliability.patch" "TPS43 reliability"
verify_patch_diff "$workspace/zmk" "$repo_root/patches/zmk/0001-gcc15-case-scope.patch" \
    "ZMK GCC 15" app/src/behaviors/behavior_key_toggle.c app/src/usb_hid.c
verify_patch_diff "$workspace/zmk" "$repo_root/patches/zmk/0002-split-input-reliability.patch" \
    "ZMK split input reliability" app/src/pointing/input_split.c \
    app/src/split/bluetooth/Kconfig app/src/split/bluetooth/central.c \
    app/src/split/bluetooth/service.c
verify_patch_diff "$workspace/zmk" "$repo_root/patches/zmk/0003-xiao-ble-qspi-flash.patch" \
    "XIAO BLE QSPI flash selection" app/boards/seeeduino_xiao_ble.overlay
verify_patch_diff "$workspace/zmk-rgbled-widget" \
    "$repo_root/patches/zmk-rgbled-widget/0001-gcc15-case-scope.patch" \
    "RGB widget GCC 15" src/widget.c
verify_patch_diff "$workspace/zmk_driver_azoteq" \
    "$repo_root/patches/zmk-driver-azoteq/0001-tps43-runtime-reliability.patch" \
    "TPS43 reliability" drivers/input/Kconfig drivers/input/tps43.c \
    dts/bindings/input/azoteq,tps43-common.yaml

verify_dirty_paths "$workspace/zmk" ZMK \
    app/src/behaviors/behavior_key_toggle.c \
    app/boards/seeeduino_xiao_ble.overlay \
    app/src/pointing/input_split.c \
    app/src/split/bluetooth/Kconfig \
    app/src/split/bluetooth/central.c \
    app/src/split/bluetooth/service.c \
    app/src/usb_hid.c
verify_dirty_paths "$workspace/zephyr" Zephyr
verify_dirty_paths "$workspace/zmk-rgbled-widget" zmk-rgbled-widget src/widget.c
verify_dirty_paths "$workspace/zmk_driver_azoteq" zmk_driver_azoteq \
    drivers/input/Kconfig drivers/input/tps43.c dts/bindings/input/azoteq,tps43-common.yaml
verify_dirty_paths "$workspace/zmk-input-zoom" zmk-input-zoom

modules="$project_dir;$workspace/zmk-rgbled-widget;$workspace/zmk_driver_azoteq;$workspace/zmk-input-zoom"
configure_target "$reset_build" settings_reset "$project_dir"
configure_target "$right_build" "toucan_right rgbled_adapter" "$modules" \
    -DCONFIG_ZMK_USB=n -DCONFIG_USB_DEVICE_STACK=n
configure_target "$left_build" "toucan_left rgbled_adapter nice_view_gem" "$modules" \
    -DSNIPPET=studio-rpc-usb-uart -DCONFIG_ZMK_STUDIO=y

left_config="$left_build/zephyr/.config"
right_config="$right_build/zephyr/.config"
reset_config="$reset_build/zephyr/.config"
left_dts="$left_build/zephyr/zephyr.dts"
right_dts="$right_build/zephyr/zephyr.dts"
reset_dts="$reset_build/zephyr/zephyr.dts"
left_uf2="$left_build/zephyr/zmk.uf2"
right_uf2="$right_build/zephyr/zmk.uf2"
reset_uf2="$reset_build/zephyr/zmk.uf2"

for artifact in "$left_config" "$right_config" "$reset_config" "$left_dts" "$right_dts" \
    "$left_uf2" "$right_uf2" "$reset_uf2"; do
    require_file "$artifact" "build artifact"
done
for build_dir in "$left_build" "$right_build" "$reset_build"; do
    require_match "$build_dir/CMakeCache.txt" "Ninja generator" \
        '^CMAKE_GENERATOR:INTERNAL=Ninja$'
    require_match "$build_dir/CMakeCache.txt" "Arm GCC compiler identity" \
        "^CMAKE_C_COMPILER:(FILEPATH|STRING)=$compiler_path$"
    require_match "$build_dir/CMakeCache.txt" "build Python identity" \
        "^Python3_EXECUTABLE:(FILEPATH|UNINITIALIZED)=$python_path$"
done

for dts in "$left_dts" "$right_dts"; do
    for stale_driver in cirque pinnacle glidepoint; do
        reject_match "$dts" "$stale_driver" "$stale_driver"
    done
    for layer in BASE SYM NAV MOUSE FN ADJ BOOT SCROLL; do
        require_match "$dts" "keymap layer $layer" "display-name = \"$layer\";"
    done
    require_match "$dts" "adj_hold macro" 'adj_hold: adjust_hold \{'
    require_match "$dts" "adj_hold SYM/NAV press" 'bindings = < &macro_press &mo 0x1 &mo 0x2 >'
    require_match "$dts" "conditional ADJ input layers" 'if-layers = < 0x1 0x2 >;'
    require_match "$dts" "conditional ADJ target" 'then-layer = < 0x5 >;'
done

for dts in "$left_dts" "$right_dts" "$reset_dts"; do
    require_multiline_match "$dts" "enabled QSPI parent" \
        '(?s)qspi: qspi@[0-9a-f]+ \{[^{}]*status = "okay";'
    require_multiline_match "$dts" "disabled incompatible GD25Q16 flash" \
        '(?s)gd25q16: gd25q16@0 \{[^{}]*jedec-id = \[ C8 40 15 \];[^{}]*status = "disabled";'
    require_multiline_match "$dts" "enabled P25Q16H flash" \
        '(?s)p25q16h: p25q16h@0 \{[^{}]*compatible = "nordic,qspi-nor";[^{}]*reg = < 0x0 >;[^{}]*jedec-id = \[ 85 60 15 \];[^{}]*has-dpd;'
done

for config in "$left_config" "$right_config"; do
    require_match "$config" "pointing support" '^CONFIG_ZMK_POINTING=y$'
    require_match "$config" "mouse support" '^CONFIG_ZMK_MOUSE=y$'
    require_match "$config" "KSCAN queue depth" '^CONFIG_ZMK_KSCAN_EVENT_QUEUE_SIZE=8$'
    require_match "$config" "battery reporting" '^CONFIG_ZMK_BATTERY_REPORTING=y$'
    require_match "$config" "deep-sleep support" '^CONFIG_ZMK_SLEEP=y$'
    require_match "$config" "60-minute deep-sleep timeout" \
        '^CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=3600000$'
    require_match "$config" "60-second idle timeout" '^CONFIG_ZMK_IDLE_TIMEOUT=60000$'
    require_match "$config" "soft-off power management" '^CONFIG_ZMK_PM_SOFT_OFF=y$'
    require_match "$config" "input thread stack size" '^CONFIG_INPUT_THREAD_STACK_SIZE=2048$'
done

require_match "$left_config" "left Studio RPC" '^CONFIG_ZMK_STUDIO=y$'
require_match "$left_config" "smooth scrolling support" '^CONFIG_ZMK_POINTING_SMOOTH_SCROLLING=y$'
require_match "$left_config" "central input queue depth" '^CONFIG_ZMK_SPLIT_BLE_CENTRAL_POSITION_QUEUE_SIZE=16$'
require_match "$left_config" "central battery fetching" \
    '^CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y$'
require_match "$left_config" "central battery proxy" \
    '^CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY=y$'
require_match "$left_config" "Toucan status screen" '^CONFIG_TOUCAN_STATUS_SCREEN=2$'
require_match "$left_config" "display tick period" '^CONFIG_ZMK_DISPLAY_TICK_PERIOD_MS=50$'
require_match "$left_config" "display blanking disabled" '^# CONFIG_ZMK_DISPLAY_BLANK_ON_IDLE is not set$'
require_match "$left_config" "unused animated image widget disabled" '^# CONFIG_LV_USE_ANIMIMG is not set$'
require_match "$left_config" "left SPI support" '^CONFIG_SPI=y$'
require_match "$left_dts" "left nice_view_gem display" 'zephyr,display = &nice_view;'

require_match "$right_config" "TPS43 I2C support" '^CONFIG_I2C=y$'
require_match "$right_config" "TPS43 input driver" '^CONFIG_INPUT_TPS43=y$'
require_match "$right_config" "minimal libc" '^CONFIG_MINIMAL_LIBC=y$'
reject_match "$right_config" "right Newlib selection" '^CONFIG_NEWLIB_LIBC=y$'
require_match "$right_config" "TPS43 register dump disabled" '^# CONFIG_INPUT_TPS43_DEBUG_REGISTER_DUMP is not set$'
require_match "$right_config" "right USB disabled" '^# CONFIG_USB_DEVICE_STACK is not set$'
require_match "$right_config" "peripheral input queue depth" \
    '^CONFIG_ZMK_SPLIT_BLE_PERIPHERAL_INPUT_QUEUE_SIZE=16$'
require_multiline_match "$right_dts" "TPS43 driver node" \
    '(?s)tps43_trackpad: trackpad@74 \{[^{}]*compatible = "azoteq,tps43";[^{}]*reg = < 0x74 >;[^{}]*scroll-angle = < 0x1e >;[^{}]*\};'
require_multiline_match "$right_dts" "TPS43-backed split input" \
    '(?s)trackpad_split: trackpad_split@0 \{[^}]*device = < &tps43_trackpad >;'

require_multiline_match "$left_dts" "nested central trackpad processor precedence" \
    '(?s)trackpad_listener: trackpad_listener \{[^{}]*status = "okay";[^{}]*device = < &trackpad_split >;[^{}]*input-processors = < &zip_scroll_scaler 0x1 0x14 >, < &zip_zoom_mapper >, < &swipe_button_mapper >;[^{}]*scroller \{[^{}]*layers = < 0x7 >;[^{}]*input-processors = < &zip_xy_to_scroll_mapper &zip_scroll_scaler 0x1 0x14 &zip_scroll_transform 0x2 >;[^{}]*\};[^{}]*pointer \{[^{}]*layers = < 0x3 >;[^{}]*input-processors = < &zip_xy_scaler 0x1 0x2 >;[^{}]*process-next;[^{}]*\};[^{}]*\};'
require_multiline_match "$left_dts" "three-finger Control-arrow bindings" \
    '(?s)swipe_button_mapper: swipe_button_mapper \{[^}]*codes = < 0x133 0x131 0x130 0x134 >;[^}]*bindings = < &kp 0x1070052 >, < &kp 0x107004f >, < &kp 0x1070051 >, < &kp 0x1070050 >;'
reject_match "$left_dts" "touch-triggered layer activation" 'is_touching_processor'
reject_multiline_match "$left_dts" "XY-to-scroll outside SCROLL" \
    'scroller \{[^}]*layers = < 0x[0-6] >;'
require_match "$project_dir/config/toucan.keymap" "ADJ keypad Enter binding" '&kp KP_ENTER'

require_match "$reset_config" "settings reset shield" '^CONFIG_SHIELD_SETTINGS_RESET=y$'
require_match "$reset_config" "settings reset on boot" '^CONFIG_ZMK_SETTINGS_RESET_ON_START=y$'
if [ -e "$firmware_out" ] || [ -L "$firmware_out" ]; then
    [ -d "$firmware_out" ] && [ ! -L "$firmware_out" ] ||
        fail "firmware output path is not a real directory: $firmware_out"
fi

set -- "$project_dir"/.firmware-out.previous.*
if [ -e "$1" ] || [ -L "$1" ]; then
    [ "$#" -eq 1 ] || fail "multiple prior firmware backups require manual recovery"
    [ -d "$1" ] && [ ! -L "$1" ] ||
        fail "prior firmware backup is not a real directory: $1"
    if [ -e "$firmware_out" ]; then
        fail "prior firmware backup requires manual recovery: $1"
    fi
    mv "$1" "$firmware_out"
fi

stage_dir=$(mktemp -d "$project_dir/.firmware-stage.XXXXXX")
cleanup() {
    if [ -n "$stage_dir" ] && [ -d "$stage_dir" ]; then
        rm -rf "$stage_dir"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cp "$reset_uf2" "$stage_dir/settings_reset.uf2"
cp "$left_uf2" "$stage_dir/toucan_left.uf2"
cp "$right_uf2" "$stage_dir/toucan_right.uf2"
cmp -s "$reset_uf2" "$stage_dir/settings_reset.uf2"
cmp -s "$left_uf2" "$stage_dir/toucan_left.uf2"
cmp -s "$right_uf2" "$stage_dir/toucan_right.uf2"

set -- "$stage_dir"/*.uf2
[ "$#" -eq 3 ] || fail "staging directory does not contain exactly three UF2 files"

if [ -e "$firmware_out" ]; then
    atomic_swap_dirs "$stage_dir" "$firmware_out" ||
        fail "failed to atomically publish firmware artifacts"
    rm -rf "$stage_dir"
else
    mv "$stage_dir" "$firmware_out"
fi
stage_dir=""
trap - EXIT HUP INT TERM

printf '\nProvenance\n'
printf '  root: %s\n' "$(project_head "$repo_root")"
printf '  root status:\n'
git -C "$repo_root" status --short --untracked-files=all | sed 's/^/    /'
printf '  zmk: %s\n' "$(project_head "$workspace/zmk")"
printf '  zephyr: %s\n' "$(project_head "$workspace/zephyr")"
printf '  zmk-rgbled-widget: %s\n' "$(project_head "$workspace/zmk-rgbled-widget")"
printf '  zmk_driver_azoteq: %s\n' "$(project_head "$workspace/zmk_driver_azoteq")"
printf '  zmk-input-zoom: %s\n' "$(project_head "$workspace/zmk-input-zoom")"
printf '  west: %s\n' "$(west --version)"
printf '  cmake: %s\n' "$(cmake --version | sed -n '1p')"
printf '  compiler: %s\n' "$(arm-none-eabi-gcc --version | sed -n '1p')"
printf '\nArtifacts\n'
(
    cd "$firmware_out"
    wc -c settings_reset.uf2 toucan_left.uf2 toucan_right.uf2
    sha256_files settings_reset.uf2 toucan_left.uf2 toucan_right.uf2
)
