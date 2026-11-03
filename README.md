# Trash Hunter

Roblox game built with [Rojo](https://rojo.space). Design: `TRASH_HUNTER_GDD.md`.

## Development

1. Install the toolchain: `rokit install`
2. Start syncing: `rojo serve`
3. In Roblox Studio, connect with the Rojo plugin.

## Structure

- `src/shared` → ReplicatedStorage/Shared — types, config, pure utilities
- `src/server` → ServerScriptService/Server — authoritative game systems (`Systems/`)
- `src/client` → StarterPlayerScripts/Client — rendering, input, UI (`Controllers/`)

## Checks

- Format: `stylua src`
- Lint: `selene src`
