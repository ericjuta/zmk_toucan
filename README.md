### Beekeeb Toucan

## Build firmware

`build-firmware.sh` is the canonical local build. It requires Arm GNU
`arm-none-eabi-gcc` 15.2.1 plus Python 3.10 or newer, `west`, CMake, Ninja, Git,
and ripgrep. It bootstraps a pinned build-Python environment and, from a clean
checkout, the pinned west workspace; on an existing workspace it never updates
dependencies. `config/west.lock` fixes every active project commit, and the
build rejects dependency drift. It verifies
and applies the tracked dependency patches, clean-configures, and builds both
halves plus the settings-reset image, proves the generated Kconfig and DTS, and
atomically publishes exactly three UF2s to `beekeeb-zmk-keyboard-toucan/firmware-out`.

```sh
./build-firmware.sh
```
