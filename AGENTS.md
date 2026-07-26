# Toucan ZMK Agent Notes

This repo is a ZMK config for the Beekeeb Toucan split keyboard. Optimize for
live proof over memory: source keymap, generated DTS, CMake cache, build output,
and git status are the truth surfaces.

## Operating Cycle

1. Start every non-trivial turn with a short plan and keep it current.
2. Read live state before deciding:
   - `git status --short --untracked-files=all`
   - `git log --oneline -5 --decorate`
   - `git diff --stat`
3. Distinguish active user config from shield defaults:
   - Active builds use `beekeeb-zmk-keyboard-toucan/config/toucan.keymap`.
   - `boards/shields/toucan/toucan.keymap` is the shield default and may be stale.
4. When editing the active keymap, update root `KEYMAP.md` in the same change;
   it is the human cheatsheet for all maintained layers.
5. For behavior bugs, inspect compiled DTS before trusting source intent.
6. Rebuild both halves when keymap behavior changes.
7. Never revert unrelated human changes. If dirty files predate the task, name
   that in status/final notes and work around them.

## Important Map

| Path | Why it matters |
| --- | --- |
| `KEYMAP.md` | Human-readable layer cheatsheet. Keep it synced with the active keymap. |
| `beekeeb-zmk-keyboard-toucan/config/toucan.keymap` | Active keymap used by local and user-config builds. Start here for layout behavior. |
| `beekeeb-zmk-keyboard-toucan/build.yaml` | GitHub Actions matrix. Nothing consumes it: this repo has no CI. Kept correct in case Actions is ever enabled; changing it does not affect any firmware you flash. |
| `beekeeb-zmk-keyboard-toucan/boards/shields/toucan/toucan.dtsi` | Shared physical layout, matrix transform, kscan rows, glidepoint listener. |
| `beekeeb-zmk-keyboard-toucan/boards/shields/toucan/toucan_left.overlay` | Left-half GPIO columns, display SPI, central-side glidepoint listener enable. |
| `beekeeb-zmk-keyboard-toucan/boards/shields/toucan/toucan_right.overlay` | Right-half col offset, touchpad SPI device, split input wiring. |
| `beekeeb-zmk-keyboard-toucan/boards/shields/toucan/Kconfig.defconfig` | Split role: left is central; shared split/pointing defaults live here. |
| `beekeeb-zmk-keyboard-toucan/config/toucan.json` | Physical layout positions for key position reasoning. |
| `beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/*/CMakeCache.txt` | Confirms `KEYMAP_FILE`, `SHIELD`, `ZMK_CONFIG`, `BOARD_ROOT`, and module paths. |
| `beekeeb-zmk-keyboard-toucan/boards/shields/toucan/toucan_left.conf` | Real Kconfig for the left half. `config/` holds no `.conf` files; shield-dir confs are the only ones. |
| `beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/*/zephyr/zephyr.dts` | Compiled devicetree truth. Use this to prove what firmware actually contains. |
| `beekeeb-zmk-keyboard-toucan/firmware-out/*.uf2` | Local flash artifacts. Keep at most three canonical files: `settings_reset.uf2`, `toucan_left.uf2`, and `toucan_right.uf2`. They may be ignored by git; verify hashes and timestamps. |

## Build And Proof Loop

There is no CI. Local builds are the only build. Exactly two canonical build
directories exist, plus `settings_reset_uf2`; do not create more. Prefer them,
they already know the Zephyr package path and module roots.

| Build dir | Half | Notes |
| --- | --- | --- |
| `toucan_left_uf2_current` | left (central) | has `CONFIG_ZMK_STUDIO=y` |
| `toucan_right_uf2_current` | right | USB disabled |
| `settings_reset_uf2` | either | flash to clear settings |

```sh
cmake --build beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_left_uf2_current
cmake --build beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_right_uf2_current
```

After building, prove the generated firmware view:

```sh
rg -n "adj_hold|conditional_layers|if-layers|then-layer|base \\{|mouse \\{|adj \\{" \
  beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_left_uf2_current/zephyr/zephyr.dts \
  beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_right_uf2_current/zephyr/zephyr.dts

shasum -a 256 \
  beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_left_uf2_current/zephyr/zmk.uf2 \
  beekeeb-zmk-keyboard-toucan/.zmk-workspace/build/toucan_right_uf2_current/zephyr/zmk.uf2
```

If a build dir needs Studio, confirm it rather than assuming: a missing
`CONFIG_ZMK_STUDIO=y` in `<build>/zephyr/.config` silently no-ops
`&studio_unlock`.

Fresh `west build` configuration can fail if Zephyr package discovery is not
set up. If a clean build is required, copy the paths and cmake args from a known
good `CMakeCache.txt` rather than guessing.

## Keymap Debugging Notes

- ZMK uses the highest-numbered active layer first.
- Conditional `then-layer` targets are controlled by the conditional-layer
  engine. Do not use a plain `&mo ADJ` for a layer that is also a
  `then-layer`; it can be immediately deactivated if the condition is false.
- Current ADJ path: `adj_hold` presses `SYM` and `NAV`; the conditional
  layer then activates `ADJ`.
- Keep `ADJ` numerically above the layers it should override. Current active
  order is `BASE=0`, `SYM=1`, `NAV=2`, `MOUSE=3`, `FN=4`, `ADJ=5`.
- Combos are processed before the normal keymap and can capture key presses
  while waiting for a chord. Avoid putting slow combos on layer-hold keys unless
  the delay is intentional.
- For split issues, remember the left half is central. Flash both halves after
  keymap or split transport changes unless proving one side is untouched.

## Fast Triage Patterns

| Symptom | First checks |
| --- | --- |
| Layer appears not to trigger | Check generated DTS layer order, conditional layers, and combos on that key position. |
| Source changed but board acts old | Check `KEYMAP_FILE` in CMake cache, rebuild both halves, compare UF2 hashes/timestamps. |
| Pointer/touchpad oddness | Read right overlay for device wiring and `toucan.dtsi` glidepoint listener/processors. |
| GitHub artifact differs from local | Compare `build.yaml` matrix args with local CMake cache values. |
| Position confusion | Use `toucan.dtsi` transform plus `config/toucan.json`; key positions are zero-based. |

## Commit Hygiene

- Commit source/config changes separately from generated artifacts when possible.
- If a user explicitly asks to commit the current state, include the dirty files
  that belong to that state, but call out any pre-existing changes.
- Before final response after a commit, report commit hash, remaining git status,
  and any build warnings that are real but non-blocking.
