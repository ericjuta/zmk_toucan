# Toucan Keymap Cheatsheet

Human-readable map for the active keymap in
`beekeeb-zmk-keyboard-toucan/config/toucan.keymap`.

Keep this file in sync whenever the active keymap changes.

## Legend

- Rows show left hand and right hand with the keyboard split between columns.
- This is the maintained 36-key layout: 30 finger keys and six thumb keys.
  Toucan2's devicetree still requires 42 matrix binding slots.
- `--` means no binding.
- `X/Y` means tap `Y`, hold `X`.
- `Cmd` is GUI. `Opt` is Alt.
- `ADJ` is the adjust layer. It is triggered by holding the base `Tab/ADJ`
  thumb key, which presses `SYM` and `NAV` together.
- `BOOT` is the bootloader/reset layer, triggered from `ADJ` by holding the
  left `V/BOOT` key.
- `SCROLL` keeps all keys transparent while the Toucan2 TPS43 trackpad sends
  scroll events.
- `Hyper` means `Ctrl+Shift+Opt+Cmd` (left-side modifiers everywhere).

## Layer Access

| Action | Binding |
| --- | --- |
| `SYM` | Hold left `Esc/SYM` thumb or right `Space/SYM` thumb |
| `NAV` | Hold left `Bspc/NAV` thumb or right `Enter/NAV` thumb |
| `ADJ` | Hold left `Tab/ADJ` thumb, or hold `SYM` and `NAV` together |
| `BOOT` | Hold `ADJ`, then hold left `V/BOOT` |
| `SCROLL` | Hold left `Bspc/NAV` thumb, then hold `Z/SCROLL` |
| `MOUSE` | Hold `NAV`, then hold left `Esc/SYM` thumb |
| `FN` | Hold right `Quote/FN` thumb |
| `Hyper` | On `BASE`, chord the two right thumb keys `Space/SYM` + `Quote/FN` within 50 ms |
| `Caps Word` | Hold `ADJ`, then press left `X` |
| Grave (backtick) | Hold left `Tab/ADJ` to enter `ADJ`, then press `P` |

The Hyper combo requires ~150 ms of typing idle before it can fire, so it does
not misfire during normal typing.

## BASE

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `Q W E R T` | `Y U I O P` |
| Home | `Ctrl/A Opt/S Cmd/D Shift/F G` | `H Shift/J Cmd/K Opt/L Ctrl/;` |
| Bottom | `Z X C V B` | `N M , . /` |
| Thumbs | `Esc/SYM Bspc/NAV Tab/ADJ` | `Enter/NAV Space/SYM Quote/FN` |

Both halves use 1 ms press debounce and 5 ms release debounce. If a switch
starts producing duplicate presses, increase press debounce before tuning
hold-tap timings.

`Esc/SYM` taps Escape when released before 145 ms without another keypress.
It activates `SYM` when another key is pressed while the thumb is held, or
when the 145 ms hold threshold expires. Release Escape before the next key
when leaving an editor mode; overlapping Escape-to-letter rolls become symbol
chords. `Space/SYM`, `Enter/NAV`, and `Quote/FN` remain tap-preferred.

`Shift/F` and `Shift/J` tap F and J. Their balanced hold-taps resolve to left
and right Shift when held past 115 ms, or when held while another key is pressed
and released. Unlike the other timeless home-row modifiers, these Shift keys
have no prior-idle or opposite-hand restriction.

## SYM

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `[ ' " ] ?` | `( Hyper+7 Hyper+8 Hyper+9 Grave` |
| Home | `^ = - $ *` | `) Hyper+4 Hyper+5 Hyper+6 %` |
| Bottom | `< Pipe _ > ~` | `# Hyper+1 Hyper+2 Hyper+3 Backslash` |
| Thumbs | `! : @` | `{ } &` |

## Trackpad

Ordinary Toucan2 TPS43 trackpad movement is native pointer movement. `MOUSE`
(layer 3) changes that pointer movement to half speed for precision selection
and dragging. Only the dedicated `SCROLL` layer (layer 7) converts trackpad
movement to smooth scrolling; it does not scroll on `SYM`, `NAV`, or `FN`.
First-touch wake uses 10/10/20/20/40 ms report rates so LP2 no longer
adds a 640 ms activation delay.

The upstream processors handle the TPS43's native zoom and directional swipe
events. Zoom events send `Cmd+-` and `Cmd+=`; north, east, south, and west
three-finger swipes send `Ctrl+Up`, `Ctrl+Right`, `Ctrl+Down`, and
`Ctrl+Left`, respectively.

## SCROLL

All keys are transparent; the TPS43 trackpad scrolls only while this dedicated
`SCROLL` layer is active. Scrolling uses HID resolution multipliers for smooth
movement on supported hosts.

## MOUSE

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- MoveUp -- --` | `-- -- -- -- --` |
| Home | `-- MoveLeft MB1 MoveRight MB2` | `-- MB1 MB2 MB3 --` |
| Bottom | `-- ScrollLeft MoveDown ScrollRight MB3` | `-- -- PgUp PgDn --` |
| Thumbs | `BASE trans trans` | `trans trans trans` |

`trans` means the key falls through to the lower active layer.

Mouse movement keys ramp linearly to their existing maximum speed over 220 ms.
Keyboard scrolling is unchanged. This acceleration setting does not affect
the trackpad.

While `MOUSE` is active, physical pointer movement runs at half the normal speed for precision selection and dragging.

## NAV

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `Cmd+Shift+Space Redo Undo SelectAll Cut` | `PlayPause Stop Prev Next --` |
| Home | `MB3 MB2 MB1 -- Copy` | `-- Left Up Down Right` |
| Bottom | `SCROLL -- -- -- Paste` | `-- Home PgUp PgDn End` |
| Thumbs | `MOUSE BrightnessDown BrightnessUp` | `VolumeDown VolumeUp Mute` |

## FN

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `-- -- -- -- --` | `-- F7 F8 F9 F12` |
| Home | `-- -- -- -- --` | `-- F4 F5 F6 F11` |
| Bottom | `-- -- -- -- --` | `-- F1 F2 F3 F10` |
| Thumbs | `-- -- --` | `F14 F15 --` |

## ADJ

| Row | Left hand | Right hand |
| --- | --- | --- |
| Top | `USB BLE-Out -- -- BT-Clear` | `+ 7 8 9 Grave` |
| Home | `BT-0 BT-1 BT-2 BT-3 BT-4` | `- 4 5 6 *` |
| Bottom | `StudioUnlock CapsWord -- BOOT --` | `= 1 2 3 /` |
| Thumbs | `-- -- --` | `. 0 KP-Enter` |

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
| Bluetooth profile 1 | `ADJ+S` |
| Bluetooth profile 2 | `ADJ+D` |
| Bluetooth profile 3 | `ADJ+F` |
| Bluetooth profile 4 | `ADJ+G` |
| Clear selected Bluetooth profile | `ADJ+T` |

All five ZMK profiles (0-4) are mapped; there is no sixth profile to bind.

For wired sessions, connect the left half with a data-capable USB cable, hold
the left `Tab/ADJ` thumb, and press `Q` to select USB output. USB uses a 1 ms
HID polling interval. The output preference is saved and survives reflashing;
an earlier BLE selection can therefore remain active while USB is connected.
Selecting USB still allows fallback to a connected BLE profile when USB is
unplugged. The right half and trackpad continue to reach the left half over BLE.

## Bootloader And Reset

| Half | Bootloader | Reset |
| --- | --- | --- |
| Left | `BOOT+E` | `BOOT+R` |
| Right | `BOOT+Y` | `BOOT+P` |

## Reserved Layers

`extra_3` is reserved and inactive.
