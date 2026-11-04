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

Set Max Players to 8 (Sunset Ln has 8 house lots, one per player per server).

Turn on Workspace > StreamingEnabled (scripts cannot) so phones only load the
part of the city around them; players can also pick Low graphics in Settings.

### Robux passes and products

Every pass and product in `Config.Robux` has `id = 0` until you create it in
the Creator Dashboard (Monetization) and paste its id. Until then the shop
shows "Coming soon". Passes give comfort, looks, a sell bonus (VIP) and luck
(Lucky Charm); products give cash, skip a wait or add luck (Lucky Hour, Bag
Reroll).

### Houses and storage

Storage lives in each player's house (the old Hideout shelf moved into it on
load). Everyone owns the Trailer; Maple Realty sells five more house types,
and an owner of several chooses which one to live in. Players never clash
over a house: a profile stores house *types*, and each server hands every
player one of Sunset Ln's lots when they join and builds their type there.

### Localization

Turn on automatic translation (Creator Dashboard > Localization) with
Indonesian as a target, and keep text capture on: every on-screen string is
plain English text that Roblox can capture and translate.

### Security model

Clients send requests through one RemoteFunction; `Router` rejects any
payload that is not a small flat value or table and rate limits every
action. Every handler re-checks distance, ownership and state on the server.
`Guard` pulls players back when they move faster than walking or driving
allows (teleport exploits). Loot is rolled on the server, the summed luck
boost is capped (`Config.Boost.MAX`), Perfect Dig bots lose the bonus, house
likes count once per account, trades are re-validated before the swap, saves
use a session lock and Robux receipts are saved before they are granted.

### Tests

`python3 tests/run.py path/to/luau` runs the shared-module self-checks, the
city layout and economy rules, the Router's payload and rate-limit checks and
a five-minute traffic simulation in the plain Luau CLI
(CI downloads it).

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
    traffic stop), `Weather` brings rain, `Ranks` runs XP / levels / titles,
    `Leaderboards` the global boards, `Trade` player trades, `Events` the
    weekend and happy-hour events, `Crew` the crews, `Story` the chapters;
    `src/server/Analytics.luau` logs cash sources / sinks and key events
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
- New players own no car: buy the Old Sedan ($450) at Maple Motors. `V` /
  Garage: your cars, Spawn, switch, paint (pass)
- Top (leaderboards), Players (visit houses, trade, crew invites), Settings
- Story: talk to Big Sal outside the Hideout for chapters with district bosses
- Crews of up to 4: crewmates close by raise everyone's odds
- `P`: photo mode (hides the HUD)
- Seasonal finds drop only in October (Halloween) and December-January (winter)
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
