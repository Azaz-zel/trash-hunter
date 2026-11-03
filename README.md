# Trash Hunter

Roblox scavenging game built with [Rojo](https://rojo.space). Design: `TRASH_HUNTER_GDD.md`.

## Development

1. Install the toolchain: `rokit install`
2. Start syncing: `rojo serve`
3. In Roblox Studio, open a Baseplate place and connect with the Rojo plugin.
4. Press Play. The map, dumpsters, Hideout and security guard are built by code at server start.

### Saving progress in Studio

DataStores only work in a published place. Publish the place, then turn on
Game Settings > Security > Enable Studio Access to API Services. Without that,
the game runs and logs `[Data] DataStore unavailable`, and progress resets each session.

### Server settings

Set Max Players to 8 (the Hideout has 8 display shelves, one per player).

## Structure

- `src/shared` → ReplicatedStorage/Shared: `Config` (all tunables), `Items`, `Loot`, `Net`, `Types`
- `src/server` → ServerScriptService/Server: `Router` (remote dispatch + rate limits) and `Systems/`
  - `World` builds the map, `Data` saves profiles (UpdateAsync + session lock),
    `Search` runs digs and loot rolls, `Economy` sells / displays / upgrades,
    `Police` runs suspicion, the guard, Drop & Run and capture,
    `Guard` checks movement, `Social` handles the friend bonus and announcements
- `src/client` → StarterPlayerScripts/Client: `Ui` kit, `Store` (state mirror) and `Controllers/`
  (`Hud`, `SearchUi`, `Panels`, `Guide`)

The server decides every outcome. Clients send requests through one RemoteFunction
(`Remotes.Action`) and receive pushes through one RemoteEvent (`Remotes.Event`).

## Controls

- `E` / tap prompt: search, sell counter, upgrade shop
- `F` / DIG button: Perfect Dig tap
- `B` bag, `C` collection book, `G` Drop & Run, `Esc` close panel

## Checks

- Format: `stylua src`
- Lint: `selene src`
- In Studio the server runs `Loot.selfCheck()` on start (odds sanity asserts).
