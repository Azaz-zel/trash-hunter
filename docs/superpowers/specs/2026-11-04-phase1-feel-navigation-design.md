# Phase 1: Feel, navigation and physical shops

Date: 2026-11-04. Status: draft for review.

## Intent

The town should feel like a real, unhurried American town. Legendary finds
should feel earned. Players should never get lost. Shopping should happen at
real stores in the world.

This is the first of four phases agreed on 2026-11-04 (from LLM Council 3):

1.  Feel and navigation (this spec).
2.  House and quests.
3.  Second city on the same connected map.
4.  Social: barter with pedestrians, two-player dumpsters, notifications.

Owner decisions this spec must respect:

-   One giant connected map; no separate places.
-   Shopping is done at physical stores. Shopping from anywhere is a Robux
    game pass.
-   Barter stays (Phase 4).

## Success criteria

-   Day/night takes about 3x longer than now.
-   Legendary-or-better per search, assuming the player picks the best of 3
    bags, lands near these targets:

      District        Now      Target
      --------------- -------- --------
      Town Center     3.1%     ~0.4%
      Industrial      20.2%    ~2.5%
      Meridian yard   37.3%    ~6%

-   After 120 searches with no Legendary, the next search is guaranteed one.
    After 30 searches with no Epic, one bag is guaranteed Epic.
-   The first session stays generous: the tutorial Rare still applies.
-   Every dumpster sits against a wall or in an enclosure, next to a back
    door or a loading area. None stands alone on open ground.
-   A minimap is always visible and shows roads, districts, the Hideout,
    stores, ready dumpsters and the player arrow. Tapping it opens a full map.
-   Entering a district shows a clean location card with name, tier and a
    "Hot today" tag. Entering the yard shows a private-property warning.
-   No Shop tab in the player menu unless the player owns the Shop Anywhere
    pass. Without the pass, stores are the only way to buy.

## Design

### 1. Day cycle

`Config.DayCycle.DAY_LENGTH` goes from 480 to 1440 seconds, so a full day
takes 24 minutes. Night stays shorter (`NIGHT_SPEED` 1.8). No other change.

### 2. Rarity and pity

-   Lower the base weights for Legendary (0.9 to 0.25) and Jackpot (0.1 to
    0.02), and `BIAS_STEP` (0.55 to 0.4).
-   Tune these until the self-check measures the targets above within ±50%.
-   Pity counters are saved in the profile:
    -   `sinceEpic`: searches since the last Epic or better.
    -   `sinceLegendary`: searches since the last Legendary or better.
-   When a counter reaches its threshold (30 or 120), the server forces that
    rarity on one random bag. The counters reset when the player picks an
    item of that rarity or better.
-   Pity is decided on the server; the client only sees the bags as usual.
-   `Loot.selfCheck` gains a test for "Legendary+ per search, best of 3" in
    each district. It asserts that each value sits within the target band.

### 3. Natural dumpster placement

-   Each dumpster spec gains a `pad` option: `"wall"` (backed against a
    building wall) or `"enclosure"` (a three-sided concrete-block pen with a
    gate, like real commercial bins).
-   World builds a concrete pad under every dumpster. It adds the enclosure
    walls when the spec asks for them.
-   Locations are reworked district by district. Each dumpster sits behind a
    real building: in the alley behind Main St shops, at the strip mall
    loading lane, beside motel and apartment back doors, at Hillcrest service
    lanes, behind office towers, and at factory docks.
-   Dumpster count stays the same, about 31.

### 4. Minimap, full map and location card

-   New client controller `MapUi`.
-   **Minimap:** a 170x170 rounded square, top right. It is drawn as 2D
    frames from shared map data, with no screenshots:
    -   Roads as grey bars.
    -   Districts as faint tinted areas.
    -   The yard in red.
    -   Icons for the Hideout and stores.
    -   Ready dumpsters (not on cooldown for this player) as dots.
    -   The player as an arrow that rotates with the camera.
-   The map is north-up and scrolls to keep the player centered.
-   **Full map:** tap the minimap or press M. It opens a full-screen version
    with a legend and labels.
-   **Shared data:** the road list moves from `World.luau` to a new shared
    module `MapData.luau`, so the server and the map share one source.
-   **Location card:** replaces the current banner. A small card slides in
    under the minimap with the district name, tier stars and a "Hot today"
    tag. Entering the yard shows a red "Private property" card instead.

### 5. Physical stores and the Robux rule

-   **Hank's Hardware** (Town Center, on Main St) sells:
    -   Backpack upgrades ("bags").
    -   Tools ("perks"): gloves, shoes, flashlight, crowbar, detector.
-   **Maple Motors** (Town Center, by the gas station) sells and swaps cars.
-   Each store is a real storefront with a counter and a ProximityPrompt.
    The prompt opens the Shop panel filtered to that store.
-   **Server rule:** buying requires standing within 14 studs of that
    store's counter, or owning the `shopanywhere` pass. This replaces the
    current "in the Hideout" check.
-   **New game pass:** Shop Anywhere (`Config.Robux.Passes.shopanywhere`).
    It shows the Shop tab in the player menu and lets the player buy from
    anywhere.
-   **Robux products** (cash packs and passes) stay purchasable from a small
    "R$" button in the HUD. They are not gated by location.
-   **Hideout:** the sell counter and display shelves stay. The gear bench
    is removed.

### 6. Roads, grass and storefront polish

Focus on the first 30 seconds: the spawn area, Town Center and Main St.

-   Raised concrete curbs along every sidewalk edge.
-   Expansion joints in the sidewalk every 10 studs.
-   Lawn color variation: darker and lighter patches.
-   Grass verges between the sidewalk and lots.
-   Asphalt patches and manhole covers on main roads.
-   **New storefront builder:**
    -   Two-storey facade with a cornice and an upper row of windows.
    -   Brick or stucco walls, with pilasters between shops.
    -   A projecting blade sign.
    -   A striped canvas awning.
    -   Lit display windows and a recessed door.
-   It is used for all Main St, Eastside and strip mall shops.

### 7. Hideout polish

-   Keep the footprint.
-   Add a neon "OPEN" sign, a pegboard tool wall, and a parked tow truck
    prop.
-   Add warm interior lighting, a wall-mounted TV, and floor paint lines.
-   Add a small fenced parking area out front where player cars spawn.

## Data changes

-   **Profile** gains `sinceEpic` and `sinceLegendary` (numbers, default 0).
    `reconcile` fills them in.
-   **Config** gains:
    -   `Stores`: id, name, position, what it sells.
    -   `Robux.Passes.shopanywhere`.
    -   `Loot.PITY`: `{ EPIC = 30, LEGENDARY = 120 }`.
-   No migration needed. New fields default to 0.

## Security

-   Store purchases are validated server-side by distance to the store
    counter or by pass ownership. The pass is cached as an attribute from
    `UserOwnsGamePassAsync`, as the existing passes already are.
-   The store kind is checked: Hank's cannot sell cars, Maple Motors cannot
    sell tools.
-   Pity is decided entirely on the server.

## Testing

-   `Loot.selfCheck` covers the rarity targets and the pity thresholds.
-   Studio playtest:
    -   Buying at Hank's works near the counter and fails away from it
        ("Visit Hank's Hardware").
    -   The Shop tab is hidden without the pass.
    -   The minimap updates when walking and driving.
    -   The location card shows on district change.
    -   Every dumpster has a pad.
    -   The console shows no errors.
-   Screenshots of Main St, the Hideout and the minimap.

## Out of scope (later phases)

House, quests, login streak, challenge gates, bigger districts (Phase 2);
second city (Phase 3); barter, two-player dumpsters, notifications (Phase 4).
