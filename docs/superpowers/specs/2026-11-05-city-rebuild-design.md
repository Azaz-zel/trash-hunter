# City Rebuild: Dense Open-World City (GTA + Cyberpunk Style)

Date: 2026-11-05. Approved through the clarifying questions in chat:
- Total rebuild.
- About 2× the current size.
- Areas: downtown, beach and pier, freeway and bridge, hills.
- Some buildings enterable.
- The layout is **original**, not a copy of any GTA map.

## Goals
- A dense, busy city: blocks are tight, buildings sit shoulder to shoulder,
  and there is no empty lawn.
- Variety: many house styles, colours, yards and cars. Downtown has neon,
  in a cyberpunk style.
- Driving is fun: arterial grid, an elevated freeway with ramps, and a
  suspension bridge to Port Haven island.
- Stores are real buildings you walk into; the counter and clerk are inside.
- The Robux shop and the store windows are separate from the Bag/Book window.

## Layout (5400 × 4050 studs, north = +Z)

| Area | x | z | Tier | Notes |
|---|---|---|---|---|
| Westshore (beach) | -2300..-1700 | -2000..1200 | 2 | sand, boardwalk, pier, Ferris wheel |
| Southside | -1700..-300 | -2000..-900 | 1 | start area, Hideout, dense small houses |
| Eastgate | -300..1100 | -2000..-900 | 1 | suburbs, player house lots, Maple Realty |
| Midtown | -1700..1100 | -900..1200 | 2 | shops, apartments, park; permit: 12 searches |
| Downtown | -500..600 | -400..400 | 4 | neon skyscrapers, plaza; permit: $5,000 earned |
| Vista Hills | -1750..900 | 1200..2050 | 3 | raised plateau (y = 40), villas; permit: 4 Rare+ |
| Industrial Park | 1100..1800 | -2000..1200 | 5 | warehouses, Meridian yard (guards) |
| Old Port (island) | 2000..2350 | -1300..1300 | 3 | Port Haven city items, Harbor Lockup |
| The Docks (island) | 2350..2700 | -1300..1300 | 5 | containers, cranes; permit: 12 Rare+ |

- Water: ocean west of x = -2250, a channel at x 1800..2000, and ocean east of the island.
- Freeway: elevated at y = 36 along z = -650, from x -1700 to 2350. Ramps
  at both ends; the bridge spans the channel.
- Hills access: the Vista Dr ramp climbs from Hillside Ave (z = 1150) to the plateau.

## Architecture
- `src/shared/CityPlan.luau` is the single source of truth:
  - roads (width, elevation), districts, water, landmark positions;
  - stores, quest givers, hideouts, the yard, house lots;
  - deterministic dumpster spots and reserved areas.
- `Config` and `MapData` derive their world data from it.
- The server builds roads and landmarks, then runs `Infill`. Infill packs
  every free roadside lot with buildings that fit the district.
- About 20% of homes are enterable, with a simple interior.
- Client traffic, pedestrians and the map all read roads from the plan.
  Traffic supports elevation.
- UI:
  - `ShopUi` is its own window. Store counters open the store's stock;
    the R$ button opens the Robux shop.
  - The Panels window keeps only Bag / Trunk / Book.

## Out of scope
- Terrain sculpting (the hills are a part-built plateau).
- Interiors for towers.
- A traffic-light AI. Intersections are turn-taking.
