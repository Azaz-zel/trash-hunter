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

### Lighting

For the intended look set Lighting > Technology to **Future** in Studio (scripts
cannot change it) and save the place.

### Server settings

Set Max Players to 8 (the Hideout has 8 display shelves, one per player).

## Structure

- `src/shared` → ReplicatedStorage/Shared: `Config` (all tunables), `Items`, `Loot`, `Net`, `Types`
- `src/server` → ServerScriptService/Server: `Router` (remote dispatch + rate limits) and `Systems/`
  - `World` builds the town (roads, districts, Meridian yard, lighting, day/night),
    `Data` saves profiles (UpdateAsync + session lock),
    `Search` runs digs and loot rolls, `Economy` sells / displays / upgrades,
    `Police` runs suspicion, the three yard officers, Drop & Run and capture,
    `Pedestrians` walks townspeople along the sidewalks (they wait for the
    walk phase at signals and drift toward wherever players are) and staffs
    the street-vendor stalls,
    `Guard` checks movement, `Social` handles the friend bonus and announcements,
    `Wanted` runs city crimes (red lights, running people over), wanted stars and
    the city cops, `StreetEvents` stages street scenes (dancer, fender bender,
    traffic stop), `Weather` brings rain
  - `Npc` (shared helper) builds outfitted R15 NPCs with animations and pathing
- `src/client` → StarterPlayerScripts/Client: `Ui` kit, `Store` (state mirror) and `Controllers/`
  (`Hud`, `SearchUi`, `Panels`, `Guide`, `Ambience` for patrol car and audio, `Traffic`
  for city cars that obey the lights and stop signs, with head/brake/turn lamps,
  police light bars, honks and crashes, and the signal lamps themselves; `WantedUi`
  for the stars; `WeatherFx` for rain and wet roads)

### Sounds and radio

Horn, siren, rain, city hum, crowd and the car radio stations are wired up but
silent until you add sound ids in `src/shared/Config.luau` (`Sounds` and
`Radio`). Use Creator Store audio your experience is allowed to play.

Players spawn at the Hideout (Southside, tier 1). The server holds character
loading until the city is built, so nobody starts at the Baseplate's origin.

The server decides every outcome. Clients send requests through one RemoteFunction
(`Remotes.Action`) and receive pushes through one RemoteEvent (`Remotes.Event`).

## Controls

- `E` / tap prompt: search, sell counter, upgrade shop
- `F` / DIG button: Perfect Dig. Tap while the marker crosses the gold zone
  (+1 bag, better odds) or the green zone (better odds). Searches close
  together build a combo; gold dumpsters on the map are fresh drops.
- Driving: `W/S` gas and brake, `A/D` steer, `Shift` nitro, `H` horn
  (people ahead step aside), `R` radio, `Space` exit
- `B` bag, `C` collection book, `G` Drop & Run, `Esc` close panel
- `M` / tap the radar: full map. Drag to move, scroll or pinch to zoom, tap a pin
  for details and **Set GPS**, or use **Go to** for the nearest Hideout, open
  dumpster, store, quest or mission. The radar (top right) turns with the
  camera, so up is the way you face; the N badge shows north.

## Checks

- Format: `stylua src`
- Lint: `selene src`
- In Studio the server runs `Loot.selfCheck()` on start (odds sanity asserts).
