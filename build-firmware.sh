#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir="$repo_root/beekeeb-zmk-keyboard-toucan"
build_root="$project_dir/.zmk-workspace/build"
left_build="$build_root/toucan_left_uf2_current"
right_build="$build_root/toucan_right_uf2_current"
firmware_out="$project_dir/firmware-out"

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_file() {
    if [ ! -f "$1" ]; then
        fail "Missing $2: $1"
    fi
}

require_match() {
    if ! rg -q -- "$3" "$1"; then
        fail "Missing $2: $1"
    fi
}

require_multiline_match() {
    if ! rg -Uq -- "$3" "$1"; then
        fail "Missing $2: $1"
    fi
}

reject_match() {
    if rg -qi -- "$3" "$1"; then
        fail "Stale Toucan1 generated DTS ($2): $1; rebuild after migrating the shield"
    fi
}

reject_multiline_match() {
    if rg -Uq -- "$3" "$1"; then
        fail "Unexpected $2: $1"
    fi
}

for build_dir in "$left_build" "$right_build"; do
    require_file "$build_dir/CMakeCache.txt" "canonical build directory"
done

cmake --build "$left_build"
cmake --build "$right_build"

left_config="$left_build/zephyr/.config"
right_config="$right_build/zephyr/.config"
left_dts="$left_build/zephyr/zephyr.dts"
right_dts="$right_build/zephyr/zephyr.dts"
left_uf2="$left_build/zephyr/zmk.uf2"
right_uf2="$right_build/zephyr/zmk.uf2"

for artifact in \
    "$left_config" "$right_config" \
    "$left_dts" "$right_dts" \
    "$left_uf2" "$right_uf2"; do
    require_file "$artifact" "build artifact"
done
for dts in "$left_dts" "$right_dts"; do
    for stale_driver in cirque pinnacle glidepoint; do
        reject_match "$dts" "$stale_driver" "$stale_driver"
    done
done


require_match "$left_config" "left Studio RPC" '^CONFIG_ZMK_STUDIO=y$'
require_match "$left_config" "left pointing support" '^CONFIG_ZMK_POINTING=y$'
require_match "$left_config" "left mouse support" '^CONFIG_ZMK_MOUSE=y$'
require_match "$left_config" "smooth scrolling support" '^CONFIG_ZMK_POINTING_SMOOTH_SCROLLING=y$'
require_match "$left_config" "central battery fetching" '^CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y$'
require_match "$left_config" "central battery proxy" '^CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY=y$'
require_match "$left_config" "KSCAN queue depth" '^CONFIG_ZMK_KSCAN_EVENT_QUEUE_SIZE=8$'
require_match "$left_config" "60-minute deep-sleep timeout" '^CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=3600000$'
require_match "$left_config" "60-second idle timeout" '^CONFIG_ZMK_IDLE_TIMEOUT=60000$'
require_match "$left_config" "deep-sleep support" '^CONFIG_ZMK_SLEEP=y$'
require_match "$left_config" "soft-off power management" '^CONFIG_ZMK_PM_SOFT_OFF=y$'
require_match "$left_config" "Toucan2 central input stack" '^CONFIG_INPUT_THREAD_STACK_SIZE=2048$'
require_match "$left_dts" "left nice_view_gem display" 'zephyr,display = &nice_view;'

require_match "$right_config" "right pointing support" '^CONFIG_ZMK_POINTING=y$'
require_match "$right_config" "right mouse support" '^CONFIG_ZMK_MOUSE=y$'
require_match "$right_config" "TPS43 I2C support" '^CONFIG_I2C=y$'
require_match "$right_config" "TPS43 input driver" '^CONFIG_INPUT_TPS43=y$'
require_match "$right_config" "TPS43 math support" '^CONFIG_NEWLIB_LIBC=y$'
require_match "$right_config" "KSCAN queue depth" '^CONFIG_ZMK_KSCAN_EVENT_QUEUE_SIZE=8$'
require_match "$right_config" "60-minute deep-sleep timeout" '^CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=3600000$'
require_match "$right_config" "60-second idle timeout" '^CONFIG_ZMK_IDLE_TIMEOUT=60000$'
require_match "$right_config" "deep-sleep support" '^CONFIG_ZMK_SLEEP=y$'
require_match "$right_config" "soft-off power management" '^CONFIG_ZMK_PM_SOFT_OFF=y$'
require_match "$right_config" "Toucan2 peripheral input stack" '^CONFIG_INPUT_THREAD_STACK_SIZE=2048$'
require_match "$right_config" "right USB disabled" '^# CONFIG_USB_DEVICE_STACK is not set$'

for dts in "$left_dts" "$right_dts"; do

    for layer in BASE SYM NAV MOUSE FN ADJ BOOT SCROLL; do
        require_match "$dts" "keymap layer $layer" "display-name = \"$layer\";"
    done

    require_match "$dts" "adj_hold macro" 'adj_hold: adjust_hold \{'
    require_match "$dts" "adj_hold SYM/NAV press" 'bindings = < &macro_press &mo 0x1 &mo 0x2 >'
    require_match "$dts" "conditional ADJ layer" 'if-layers = < 0x1 0x2 >;'
    require_match "$dts" "conditional ADJ target" 'then-layer = < 0x5 >;'
done

require_match "$right_dts" "TPS43 trackpad node" 'tps43_trackpad: trackpad@74 \{'
require_match "$right_dts" "TPS43 azoteq compatible" 'compatible = "azoteq,tps43";'
require_match "$right_dts" "TPS43 I2C address" 'reg = < 0x74 >;'
require_multiline_match "$right_dts" "TPS43-backed trackpad_split" \
    '(?s)trackpad_split: trackpad_split@0 \{[^}]*device = < &tps43_trackpad >;'

require_multiline_match "$left_dts" "enabled central trackpad listener with native gestures" \
    '(?s)trackpad_listener: trackpad_listener \{[^}]*status = "okay";[^}]*device = < &trackpad_split >;[^}]*input-processors = < &zip_xy_scaler 0x64 0x64 >, < &zip_scroll_scaler 0x1 0x14 >, < &zip_zoom_mapper >, < &swipe_button_mapper >;'
require_multiline_match "$left_dts" "native zoom processor" \
    '(?s)zip_zoom_mapper: zip_zoom_mapper \{[^}]*compatible = "zmk,input-processor-zoom";'
require_multiline_match "$left_dts" "native swipe processor" \
    '(?s)swipe_button_mapper: swipe_button_mapper \{[^}]*compatible = "zmk,input-processor-behaviors";'
require_multiline_match "$left_dts" "three-finger Control-arrow bindings" \
    '(?s)swipe_button_mapper: swipe_button_mapper \{[^}]*codes = < 0x133 0x131 0x130 0x134 >;[^}]*bindings = < &kp 0x1070052 >, < &kp 0x107004f >, < &kp 0x1070051 >, < &kp 0x1070050 >;'
reject_match "$left_dts" "touch-triggered layer activation" 'is_touching_processor'
require_multiline_match "$left_dts" "layer-3 precision pointer override" \
    '(?s)pointer \{[^}]*layers = < 0x3 >;[^}]*input-processors = < &zip_xy_scaler 0x32 0x64 >;'
require_multiline_match "$left_dts" "layer-7 XY-to-scroll override" \
    '(?s)scroller \{[^}]*layers = < 0x7 >;[^}]*input-processors = < &zip_xy_to_scroll_mapper &zip_scroll_scaler 0x1 0x14 &zip_scroll_transform 0x2 >;'
reject_multiline_match "$left_dts" "XY-to-scroll on a non-SCROLL layer" \
    'scroller \{[^}]*layers = < 0x[124] >;'

require_match "$project_dir/config/toucan.keymap" "ADJ keypad Enter binding" '&kp KP_ENTER'

mkdir -p "$firmware_out"
cp "$left_uf2" "$firmware_out/toucan_left.uf2"
cp "$right_uf2" "$firmware_out/toucan_right.uf2"
cmp -s "$left_uf2" "$firmware_out/toucan_left.uf2"
cmp -s "$right_uf2" "$firmware_out/toucan_right.uf2"

(
    cd "$firmware_out"
    shasum -a 256 toucan_left.uf2 toucan_right.uf2
)