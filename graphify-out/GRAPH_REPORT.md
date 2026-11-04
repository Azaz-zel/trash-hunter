# Graph Report - Roblox-Trash Hunter  (2026-11-05)

## Corpus Check
- 80 files · ~136,501 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: .toml 4, (none) 3)

## Summary
- 764 nodes · 1813 edges · 53 communities (43 shown, 10 thin omitted)
- Extraction: 72% EXTRACTED · 28% INFERRED · 0% AMBIGUOUS · INFERRED: 509 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `442afc49`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Data.get
- script_parent_parent_store
- Vehicles.luau
- Police.luau
- World.luau
- Infill.luau
- CityDistricts.luau
- Search.luau
- SearchUi.luau
- Pedestrians.luau
- City Rebuild spec: dense open-world city
- Districts and loot tiers (Config.Districts boost)
- README
- Police pressure and escape as market differentiator
- Progress.luau
- Police AI state machine (Patrol/Investigate/Chase/Catch/Return)
- Pity counters (sinceEpic 30, sinceLegendary 120)
- CarDriver.luau
- Ui.new
- Phase 1 spec: Feel, navigation and physical shops
- Wanted.luau
- Physical stores (Hank's Hardware, Maple Motors)
- Mutations (Shiny x2, Golden x5)
- child
- Serena project config
- Fun gate (5 strangers play 15+ min)
- Login streak
- Loot.luau
- StreetEvents.luau
- StoryUi.luau
- Ui.luau
- Config.luau
- shim.luau
- script_parent_parent_router
- BarterUi.luau
- Trade.luau
- run.py
- TradeUi.luau
- Crew.luau
- Router.on
- loader.luau
- CI lint job
- Four-phase roadmap (LLM Council 3)
- Router.luau
- chip
- District unlock missions (contact NPCs)
- Realistic American small-town visual direction (Appendix C)
- Cars and trunk storage
- Trash Hunter GDD v1

## God Nodes (most connected - your core abstractions)
1. `Data.get()` - 38 edges
2. `Router.send()` - 36 edges
3. `pick()` - 35 edges
4. `Ui.new()` - 34 edges
5. `Data.push()` - 28 edges
6. `Ui.label()` - 25 edges
7. `Ui.corner()` - 20 edges
8. `Guard.root()` - 18 edges
9. `Ui.button()` - 15 edges
10. `render()` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Districts and loot tiers (Config.Districts boost)` --semantically_similar_to--> `Four zones (Suburbs, Downtown, Industrial, Rich District)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md
- `Realistic American small-town visual direction (Appendix C)` --semantically_similar_to--> `Semi-realistic American urban visual direction`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md
- `Police AI state machine (Patrol/Investigate/Chase/Catch/Return)` --semantically_similar_to--> `Police AI (v1 staged)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md
- `Target server service architecture (LootService, SuspicionService, PoliceService, DataService...)` --semantically_similar_to--> `Router (remote dispatch + rate limits)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → README.md
- `Single Action RemoteFunction + Event push channel` --semantically_similar_to--> `Anti-exploit from Phase 1 (distance, rate limit, speed check)`  [INFERRED] [semantically similar]
  README.md → TRASH_HUNTER_GDD.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Risk and escape loop (red zone, suspicion, police, Drop & Run, capture)** — trash_hunter_gdd_red_zone, trash_hunter_gdd_suspicion_bar, trash_hunter_gdd_police_state_machine, trash_hunter_gdd_drop_and_run, trash_hunter_gdd_capture_consequence [EXTRACTED 1.00]
- **District tiering and unlock progression** — trash_hunter_gdd_district_loot_tiers, trash_hunter_gdd_district_permits, trash_hunter_gdd_district_unlock_missions, docs_prompts_district_expansion_five_districts, docs_superpowers_specs_2026_11_05_city_rebuild_design_district_layout [INFERRED 0.85]
- **Physical shopping and Robux convenience rule** — docs_superpowers_specs_2026_11_04_phase1_feel_navigation_design_physical_stores, docs_superpowers_specs_2026_11_04_phase1_feel_navigation_design_shop_anywhere_pass, docs_superpowers_specs_2026_11_05_city_rebuild_design_shopui, trash_hunter_gdd_robux_passes, trash_hunter_gdd_monetization_principle [INFERRED 0.85]

## Communities (53 total, 10 thin omitted)

### Community 0 - "Data.get"
Cohesion: 0.05
Nodes (89): script_parent_housing, script_parent_search, script_parent_wanted, script_parent_world, Analytics.sink(), Analytics.source(), economy(), Router.send() (+81 more)

### Community 1 - "script_parent_parent_store"
Cohesion: 0.09
Nodes (14): script_parent_parent_store, script_parent_parent_ui, shared_waitforchild, row(), grid(), heading(), note(), small() (+6 more)

### Community 2 - "Vehicles.luau"
Cohesion: 0.12
Nodes (25): replicatedstorage_shared_config, script_parent_data, script_parent_pedestrians, buildBoard(), Leaderboards.start(), nameOf(), publish(), read() (+17 more)

### Community 3 - "Police.luau"
Cohesion: 0.20
Nodes (27): Analytics.event(), Guard.root(), buildOfficer(), capture(), clampToPost(), confiscate(), dispatchInvestigations(), dropAndRun() (+19 more)

### Community 4 - "World.luau"
Cohesion: 0.14
Nodes (30): replicatedstorage_shared_districts, script_parent_parent_citydistricts, script_parent_parent_infill, script_parent_parent_roads, bench(), box(), buildMeridianYard(), civilian() (+22 more)

### Community 5 - "Infill.luau"
Cohesion: 0.10
Nodes (46): blocked(), brickWalkup(), buildHangouts(), choose(), cottage(), diner(), dressStreets(), fallbacks() (+38 more)

### Community 6 - "CityDistricts.luau"
Cohesion: 0.10
Nodes (38): game_getservice, at(), billboard(), boat(), buildBeach(), buildHills(), buildIsland(), buildPark() (+30 more)

### Community 7 - "Search.luau"
Cohesion: 0.18
Nodes (16): script_parent_crew, script_parent_social, Crew.bonus(), Data.hasTool(), beginDig(), bindDumpster(), boostFor(), dumpsterPos() (+8 more)

### Community 8 - "SearchUi.luau"
Cohesion: 0.29
Nodes (11): bodyOf(), cameraShake(), choose(), closeDumpster(), hideAll(), hingeCFrame(), lidOf(), onSearchStarted() (+3 more)

### Community 9 - "Pedestrians.luau"
Cohesion: 0.13
Nodes (21): describe(), flat(), Npc.face(), Npc.moveToward(), Npc.new(), customer(), flatDir(), flatDist() (+13 more)

### Community 10 - "City Rebuild spec: dense open-world city"
Cohesion: 0.29
Nodes (8): MapData shared road module, City Rebuild spec: dense open-world city, CityPlan single source of truth, Elevated Harbor freeway and suspension bridge, Infill (pack roadside lots with district buildings), Trash Hunter GDD v2.0, GPS waypoint shortest road route, Polyline road graph with road hierarchy

### Community 11 - "Districts and loot tiers (Config.Districts boost)"
Cohesion: 0.22
Nodes (9): Prompt: District expansion + minimal UI, Five tiered districts (Eastside < Maple Grove < Hillcrest < Business < Industrial), Minimal modern UI restyle, Location card (district, tier, Hot today, Private property), MapUi minimap and full map, City district layout (Westshore, Southside, Eastgate, Midtown, Downtown, Vista Hills, Industrial, Old Port, The Docks), Districts and loot tiers (Config.Districts boost), Hot District (daily boosted district) (+1 more)

### Community 12 - "README"
Cohesion: 0.29
Nodes (7): README, DataStore Studio API access requirement, Future lighting technology, Loot.selfCheck odds sanity asserts, Max Players = 8, Rojo sync workflow, Sell or display (Hideout shelves)

### Community 13 - "Police pressure and escape as market differentiator"
Cohesion: 0.29
Nodes (7): DUMP (competitor), Dumpster Divers! (competitor), Prospecting! (competitor), Heavy bin (2-player dumpster), Meridian Logistics yard (police red zone), Police pressure and escape as market differentiator, Red zones

### Community 14 - "Progress.luau"
Cohesion: 0.11
Nodes (31): script_parent_config, script_parent_story, day(), accept(), cheapestAtLeast(), districtName(), giverAt(), missionAccept() (+23 more)

### Community 15 - "Police AI state machine (Patrol/Investigate/Chase/Catch/Return)"
Cohesion: 0.20
Nodes (10): Dig deeper (push-your-luck), Drop & Run, Perfect Dig (dig layer timing), Police AI state machine (Patrol/Investigate/Chase/Catch/Return), Rummage (pick 1 of 3 weighted bags), Suspicion bar, Tools (Gloves, Shoes, Flashlight, Crowbar, Metal Detector), Police AI (v1 staged) (+2 more)

### Community 16 - "Pity counters (sinceEpic 30, sinceLegendary 120)"
Cohesion: 0.29
Nodes (8): Pity counters (sinceEpic 30, sinceLegendary 120), Router (remote dispatch + rate limits), Single Action RemoteFunction + Event push channel, Anti-exploit from Phase 1 (distance, rate limit, speed check), Capture consequence (lose backpack only; disconnect counts as caught), Content Maturity target Minimal/Mild, DataStore persistence (UpdateAsync + session lock), Target server service architecture (LootService, SuspicionService, PoliceService, DataService...)

### Community 17 - "CarDriver.luau"
Cohesion: 0.08
Nodes (31): replicatedstorage_waitforchild, script_parent_parent_settings, Ambience.start(), lightBar(), loopSound(), setupAudio(), setupCityAudio(), CarDriver.start() (+23 more)

### Community 18 - "Ui.new"
Cohesion: 0.25
Nodes (28): build(), side(), build(), pedal(), Guide.init(), chipLabel(), toast(), build() (+20 more)

### Community 19 - "Phase 1 spec: Feel, navigation and physical shops"
Cohesion: 0.22
Nodes (9): Phase 1 spec: Feel, navigation and physical shops, Day cycle 24 min (DAY_LENGTH 1440), Natural dumpster placement (wall / enclosure pads), Rarity retune (lower Legendary/Jackpot weights, BIAS_STEP), Two-storey storefront builder, First five minutes (FTUE, guaranteed tutorial Rare), Mythic and Secret rarities, Per-player dumpster loot and cooldown (+1 more)

### Community 20 - "Wanted.luau"
Cohesion: 0.27
Nodes (17): script_parent_police, carOf(), checkHits(), checkRedLight(), clear(), crime(), flat(), roadPath() (+9 more)

### Community 21 - "Physical stores (Hank's Hardware, Maple Motors)"
Cohesion: 0.50
Nodes (5): Physical stores (Hank's Hardware, Maple Motors), Shop Anywhere game pass, ShopUi separate window (store stock vs Robux shop), Monetization: sell convenience, not power or odds, Robux passes and products (Config.Robux)

### Community 22 - "Mutations (Shiny x2, Golden x5)"
Cohesion: 0.50
Nodes (4): Collection book, Junk Mechanics (competitor), Mutations (Shiny x2, Golden x5), Item condition and repair

### Community 28 - "Loot.luau"
Cohesion: 0.17
Nodes (15): script_parent_items, itemPicture(), Search.init(), ItemModels.build(), ItemModels.show(), ItemModels.trophy(), rgb(), v() (+7 more)

### Community 29 - "StreetEvents.luau"
Cohesion: 0.32
Nodes (15): replicatedstorage_shared_cityplan, argue(), blinkers(), car(), curbFrame(), facing(), fenderBender(), part() (+7 more)

### Community 30 - "StoryUi.luau"
Cohesion: 0.18
Nodes (12): script_parent_settings, BarterUi.start(), find(), Guide.start(), render(), PhotoMode.start(), giver(), play() (+4 more)

### Community 31 - "Ui.luau"
Cohesion: 0.26
Nodes (13): show(), floatDelta(), renderState(), renderSuspicion(), onSearchBags(), scaleOf(), scaleTo(), Ui.bump() (+5 more)

### Community 32 - "Config.luau"
Cohesion: 0.18
Nodes (7): script_parent_avatar, script_parent_cityplan, script_parent_guard, script_parent_parent_analytics, script_parent_parent_npc, script_parent_progress, script_parent_ranks

### Community 33 - "shim.luau"
Cohesion: 0.21
Nodes (5): C.ToObjectSpace(), C.VectorToObjectSpace(), cnew(), V.Cross(), vnew()

### Community 34 - "script_parent_parent_router"
Cohesion: 0.29
Nodes (8): script_parent_parent_router, Router.broadcast(), current(), Events.start(), onPlayerAdded(), Social.announce(), Social.hasFriendHere(), Social.start()

### Community 35 - "BarterUi.luau"
Cohesion: 0.22
Nodes (8): answer(), BarterUi.init(), hide(), CarDriver.init(), LeaderboardUi.init(), LeaderboardUi.start(), StoryUi.init(), Ui.autoScale()

### Community 36 - "Trade.luau"
Cohesion: 0.29
Nodes (7): close(), near(), cancel(), confirm(), execute(), Trade.init(), Trade.start()

### Community 37 - "run.py"
Cohesion: 0.28
Nodes (8): glob, os, subprocess, sys, bundle(), main(), module_source(), Runs the Luau tests in tests/*.test.luau with the plain `luau` CLI. The CLI…

### Community 38 - "TradeUi.luau"
Cohesion: 0.28
Nodes (7): save(), clear(), openPicker(), sendOffer(), TradeUi.init(), Store.action(), Store.emit()

### Community 39 - "Crew.luau"
Cohesion: 0.52
Nodes (5): Crew.init(), Crew.start(), leave(), publish(), respond()

### Community 40 - "Router.on"
Cohesion: 0.33
Nodes (6): Router.on(), Barter.init(), Economy.init(), Housing.init(), Shop.init(), Vehicles.init()

### Community 41 - "loader.luau"
Cohesion: 0.47
Nodes (3): fakeScript(), load(), loaderRequire()

### Community 42 - "CI lint job"
Cohesion: 0.40
Nodes (5): CI workflow (ci.yml), CI lint job, selene src lint, setup-rokit toolchain install, stylua --check src

### Community 43 - "Four-phase roadmap (LLM Council 3)"
Cohesion: 0.40
Nodes (5): Four-phase roadmap (LLM Council 3), Enterable homes (~20%), Barter with pedestrians, Player house (Sunset Lane, Maple Realty), Port Haven second city (Old Port, The Docks, Harbor Lockup)

### Community 44 - "Router.luau"
Cohesion: 0.70
Nodes (3): validPayload(), validScalar(), validTable()

### Community 45 - "chip"
Cohesion: 0.83
Nodes (3): chip(), nearest(), selectPlace()

### Community 48 - "District unlock missions (contact NPCs)"
Cohesion: 0.67
Nodes (3): District permits, District unlock missions (contact NPCs), Daily quest NPCs

### Community 49 - "Realistic American small-town visual direction (Appendix C)"
Cohesion: 0.67
Nodes (3): Raccoon mascot, Realistic American small-town visual direction (Appendix C), Semi-realistic American urban visual direction

## Knowledge Gaps
- **41 isolated node(s):** `Elevated Harbor freeway and suspension bridge`, `Barter with pedestrians`, `District permits`, `GPS waypoint shortest road route`, `Port Haven second city (Old Port, The Docks, Harbor Lockup)` (+36 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 118 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `pick()` connect `Infill.luau` to `Police.luau`, `Wanted.luau`, `StreetEvents.luau`, `Search.luau`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Why does `tile()` connect `Ui.new` to `Data.get`, `Police.luau`, `TradeUi.luau`, `Ui.luau`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Why does `Items.value()` connect `Police.luau` to `Data.get`, `Ui.new`, `Loot.luau`, `Progress.luau`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 37 inferred relationships involving `Data.get()` (e.g. with `Avatar.refresh()` and `answer()`) actually correct?**
  _`Data.get()` has 37 INFERRED edges - model-reasoned connections that need verification._
- **Are the 35 inferred relationships involving `Router.send()` (e.g. with `answer()` and `bind()`) actually correct?**
  _`Router.send()` has 35 INFERRED edges - model-reasoned connections that need verification._
- **Are the 31 inferred relationships involving `pick()` (e.g. with `brickWalkup()` and `cottage()`) actually correct?**
  _`pick()` has 31 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `Ui.new()` (e.g. with `build()` and `side()`) actually correct?**
  _`Ui.new()` has 23 INFERRED edges - model-reasoned connections that need verification._