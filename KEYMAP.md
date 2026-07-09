# Toucan Keymap Cheatsheet

Human-readable map for the active keymap in
`beekeeb-zmk-keyboard-toucan/config/toucan.keymap`.

Keep this file in sync whenever the active keymap changes.

## Legend

- Rows show left hand and right hand with the keyboard split between columns.
- `--` means no binding.
- `X/Y` means tap `Y`, hold `X`.
- `Cmd` is GUI. `Opt` is Alt.
- `ADJ` is the adjust layer. It is triggered by holding the base `Tab/ADJ`
  thumb key, which presses `SYM` and `NAV` together.
- `BOOT` is the bootloader/reset layer, triggered from `ADJ` by holding the
  left `V/BOOT` key.
- `SCROLL` keeps all keys transparent while the glidepoint sends scroll events.
- `Hyper` means `Ctrl+Shift+Opt+Cmd`.

## Layer Access

| Action | Binding |
| --- | --- |
| `SYM` | Hold left `Esc/SYM` thumb or right `Space/SYM` thumb |
| `NAV` | Hold left `Bspc/NAV` thumb or right `Enter/NAV` thumb |
| `ADJ` | Hold left `Tab/ADJ` thumb, or hold `SYM` and `NAV` together |
| `BOOT` | Hold left `Z/BOOT`, or hold `ADJ` then left `V/BOOT` |
| `SCROLL` | Hold left `Bspc/NAV` thumb, then hold `Z/SCROLL`; or hold `Z/BOOT`, then hold left `Bspc/SCROLL` |
| `MOUSE` | Hold `NAV`, then hold left `Esc/SYM` thumb |
| `FN` | Hold right `Quote/FN` thumb |
| `Hyper` | On `BASE`, hold/combo the two right thumb keys `Space/SYM` + `Quote/FN` |

## BASE

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `Q W E R T` | `Y U I O P` |
| Home | `Ctrl/A Opt/S Cmd/D Shift/F G` | `H Shift/J Cmd/K Opt/L Ctrl/;` |
| Bottom | `Z/BOOT X C V B` | `N M , . /` |
| Thumbs | `Esc/SYM Bspc/NAV Tab/ADJ` | `Enter/NAV Space/SYM Quote/FN` |

## SYM

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `[ ' " ] ?` | `( Hyper+7 Hyper+8 Hyper+9 Grave` |
| Home | `^ = - $ *` | `) Hyper+4 Hyper+5 Hyper+6 '` |
| Bottom | `< Pipe _ > /` | `# Hyper+1 Hyper+2 Hyper+3 ?` |
| Thumbs | `! @ :` | `{ } &` |

## NAV

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `Cmd+Shift+Space Redo Undo SelectAll Cut` | `PlayPause Stop Prev Next --` |
| Home | `MB3 MB2 MB1 -- Copy` | `-- Left Up Down Right` |
| Bottom | `SCROLL -- -- -- Paste` | `-- Home PgUp PgDn End` |
| Thumbs | `MOUSE BrightnessDown BrightnessUp` | `VolumeDown VolumeUp Mute` |

## SCROLL

All keys are transparent; the trackpad scrolls only while this dedicated `SCROLL` layer is active.

## MOUSE

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- MoveUp -- --` | `-- -- -- -- --` |
| Home | `Cmd+Shift+Space MoveLeft MB1 MoveRight MB2` | `-- MB1 MB2 MB3 ADJ` |
| Bottom | `-- ScrollLeft MoveDown ScrollRight MB3` | `-- -- PgUp PgDn --` |
| Thumbs | `BASE trans trans` | `trans trans trans` |

`trans` means the key falls through to the lower active layer.

## FN

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- -- -- --` | `-- F7 F8 F9 F12` |
| Home | `-- - = Backslash --` | `-- F4 F5 F6 F11` |
| Bottom | `-- -- -- -- --` | `-- F1 F2 F3 F10` |
| Thumbs | `-- -- --` | `F14 F15 --` |

## ADJ

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `USB BLE-Out -- -- BT-Clear` | `+ 7 8 9 --` |
| Home | `BT-0 LeftAlt BT-2 BT-3 BT-4` | `- 4 5 6 *` |
| Bottom | `StudioUnlock CapsWord BT-1 BOOT --` | `= 1 2 3 /` |
| Thumbs | `-- -- --` | `. 0 )` |

## BOOT

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- Boot Reset --` | `Boot -- -- -- Reset` |
| Home | `-- -- -- -- --` | `-- -- -- -- --` |
| Bottom | `-- -- -- -- --` | `-- -- -- -- --` |
| Thumbs | `-- SCROLL --` | `-- -- --` |

## Bluetooth And Output

| Action | Binding |
| --- | --- |
| USB output | `ADJ+Q` |
| BLE output | `ADJ+W` |
| Bluetooth profile 0 | `ADJ+A` |
| Bluetooth profile 1 | `ADJ+C` |
| Bluetooth profile 2 | `ADJ+D` |
| Bluetooth profile 3 | `ADJ+F` |
| Bluetooth profile 4 | `ADJ+G` |
| Clear selected Bluetooth profile | `ADJ+T` |

No Bluetooth profile 5 binding is currently mapped.

## BOOT

Hold the left `Z/BOOT` key to access bootloader/reset keys.

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- -- BootLeft ResetLeft --` | `BootRight -- -- -- ResetRight --` |
| Home | `-- -- -- -- -- --` | `-- -- -- -- -- --` |
| Bottom | `-- -- -- -- -- --` | `-- -- -- -- -- --` |
| Thumbs | `-- -- --` | `-- -- --` |

## Bootloader And Reset

| Half | Bootloader | Reset |
| --- | --- | --- |
| Left | `BOOT+E` | `BOOT+R` |
| Right | `BOOT+Y` | `BOOT+P` |

## Reserved Layers

`extra_3` is reserved and inactive.
