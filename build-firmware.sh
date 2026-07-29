#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir="$repo_root/beekeeb-zmk-keyboard-toucan"
build_root="$project_dir/.zmk-workspace/build"
left_build="$build_root/toucan_left_uf2_current"
right_build="$build_root/toucan_right_uf2_current"
firmware_out="$project_dir/firmware-out"

for build_dir in "$left_build" "$right_build"; do
    if [ ! -f "$build_dir/CMakeCache.txt" ]; then
        printf 'Missing canonical build directory: %s\n' "$build_dir" >&2
        exit 1
    fi
done

cmake --build "$left_build"
cmake --build "$right_build"

left_config="$left_build/zephyr/.config"
right_config="$right_build/zephyr/.config"
left_dts="$left_build/zephyr/zephyr.dts"
right_dts="$right_build/zephyr/zephyr.dts"
left_uf2="$left_build/zephyr/zmk.uf2"
right_uf2="$right_build/zephyr/zmk.uf2"

rg -q '^CONFIG_ZMK_STUDIO=y$' "$left_config"
rg -q '^CONFIG_ZMK_POINTING_SMOOTH_SCROLLING=y$' "$left_config"
rg -q '^# CONFIG_USB_DEVICE_STACK is not set$' "$right_config"
rg -q '&kp KP_ENTER' "$project_dir/config/toucan.keymap"

for dts in "$left_dts" "$right_dts"; do
    rg -q 'zip_xy_scaler 0x5 0x2' "$dts"
    rg -q 'zip_xy_scaler 0x5 0x4' "$dts"
    rg -q 'zip_scroll_scaler 0x1 0x5' "$dts"
    rg -q '0x70058' "$dts"
done

rg -n 'adj_hold|conditional_layers|if-layers|then-layer|base \{|mouse \{|adj \{|scroller \{' \
    "$left_dts" "$right_dts"

mkdir -p "$firmware_out"
cp "$left_uf2" "$firmware_out/toucan_left.uf2"
cp "$right_uf2" "$firmware_out/toucan_right.uf2"
cmp -s "$left_uf2" "$firmware_out/toucan_left.uf2"
cmp -s "$right_uf2" "$firmware_out/toucan_right.uf2"

shasum -a 256 \
    "$firmware_out/toucan_left.uf2" \
    "$firmware_out/toucan_right.uf2"