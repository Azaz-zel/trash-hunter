# Graph Report - Roblox-Trash Hunter  (2026-11-05)

## Corpus Check
- 54 files · ~87,204 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: .toml 4, (none) 3)

## Summary
- 531 nodes · 1244 edges · 28 communities (23 shown, 5 thin omitted)
- Extraction: 72% EXTRACTED · 28% INFERRED · 0% AMBIGUOUS · INFERRED: 348 edges (avg confidence: 0.85)
- Token cost: 205,815 input · 0 output

## Community Hubs (Navigation)
- Server Systems & Data
- Client UI Controllers
- Remote Router & Avatar
- Guard & Police Security
- World Builder
- Infill Building Generator
- City Landmarks
- Dumpster Search Flow
- Search Reveal UI
- NPC & Pedestrians
- Open-World City Plan Spec
- CI & Visual Direction
- Loot & Rarity Design
- Map, Districts & Red Zone
- Quests & District Missions
- Risk Loop (Dig, Suspicion, Police)
- Networking & Anti-Exploit
- Car Driving
- Road Network Builder
- Phase 1 Feel Spec
- Client Traffic
- Shop & Monetization
- Collection & Mutations
- Client/Server Entry
- Serena Config
- Core Pillars
- Login Streak

## God Nodes (most connected - your core abstractions)
1. `Data.get()` - 33 edges
2. `Router.send()` - 26 edges
3. `Data.push()` - 26 edges
4. `Ui.new()` - 25 edges
5. `Ui.label()` - 17 edges
6. `Ui.corner()` - 15 edges
7. `updateSuspicion()` - 15 edges
8. `updateOfficer()` - 13 edges
9. `drawWorld()` - 12 edges
10. `Data.removeItem()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Districts and loot tiers (Config.Districts boost)` --semantically_similar_to--> `Four zones (Suburbs, Downtown, Industrial, Rich District)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md
- `Single Action RemoteFunction + Event push channel` --semantically_similar_to--> `Anti-exploit from Phase 1 (distance, rate limit, speed check)`  [INFERRED] [semantically similar]
  README.md → TRASH_HUNTER_GDD.md
- `Target server service architecture (LootService, SuspicionService, PoliceService, DataService...)` --semantically_similar_to--> `Router (remote dispatch + rate limits)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → README.md
- `Police AI state machine (Patrol/Investigate/Chase/Catch/Return)` --semantically_similar_to--> `Police AI (v1 staged)`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md
- `Realistic American small-town visual direction (Appendix C)` --semantically_similar_to--> `Semi-realistic American urban visual direction`  [INFERRED] [semantically similar]
  TRASH_HUNTER_GDD.md → TRASH_HUNTER_GDD_v1.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Risk and escape loop (red zone, suspicion, police, Drop & Run, capture)** — trash_hunter_gdd_red_zone, trash_hunter_gdd_suspicion_bar, trash_hunter_gdd_police_state_machine, trash_hunter_gdd_drop_and_run, trash_hunter_gdd_capture_consequence [EXTRACTED 1.00]
- **Physical shopping and Robux convenience rule** — docs_superpowers_specs_2026_11_04_phase1_feel_navigation_design_physical_stores, docs_superpowers_specs_2026_11_04_phase1_feel_navigation_design_shop_anywhere_pass, docs_superpowers_specs_2026_11_05_city_rebuild_design_shopui, trash_hunter_gdd_robux_passes, trash_hunter_gdd_monetization_principle [INFERRED 0.85]
- **District tiering and unlock progression** — trash_hunter_gdd_district_loot_tiers, trash_hunter_gdd_district_permits, trash_hunter_gdd_district_unlock_missions, docs_prompts_district_expansion_five_districts, docs_superpowers_specs_2026_11_05_city_rebuild_design_district_layout [INFERRED 0.85]

## Communities (28 total, 5 thin omitted)

### Community 0 - "Server Systems & Data"
Cohesion: 0.06
Nodes (78): script_parent_cityplan, script_parent_world, onAnnounce(), day(), Router.send(), answer(), Barter.start(), bind() (+70 more)

### Community 1 - "Client UI Controllers"
Cohesion: 0.07
Nodes (72): script_parent_parent_store, script_parent_parent_ui, shared_waitforchild, Ambience.start(), lightBar(), loopSound(), setupAudio(), answer() (+64 more)

### Community 2 - "Remote Router & Avatar"
Cohesion: 0.07
Nodes (37): game_getservice, script_parent_avatar, script_parent_data, script_parent_guard, script_parent_parent_router, script_parent_progress, Router.broadcast(), Router.on() (+29 more)

### Community 3 - "Guard & Police Security"
Cohesion: 0.16
Nodes (31): script_parent_search, flat(), Guard.inHideout(), Guard.inRedZone(), Guard.nearestHideout(), Guard.root(), Guard.start(), Guard.teleport() (+23 more)

### Community 4 - "World Builder"
Cohesion: 0.13
Nodes (31): replicatedstorage_shared_cityplan, replicatedstorage_shared_config, replicatedstorage_shared_districts, script_parent_parent_citydistricts, script_parent_parent_infill, script_parent_parent_roads, bench(), box() (+23 more)

### Community 5 - "Infill Building Generator"
Cohesion: 0.13
Nodes (26): blocked(), buildHangouts(), choose(), clearTrees(), cottage(), dressStreets(), fillInteriors(), fillLots() (+18 more)

### Community 6 - "City Landmarks"
Cohesion: 0.16
Nodes (25): at(), billboard(), boat(), buildBeach(), buildHills(), buildIsland(), buildPark(), buildPlaza() (+17 more)

### Community 7 - "Dumpster Search Flow"
Cohesion: 0.16
Nodes (21): script_parent_items, script_parent_social, Data.hasTool(), Guard.distance(), beginDig(), bindDumpster(), boostFor(), dumpsterPos() (+13 more)

### Community 8 - "Search Reveal UI"
Cohesion: 0.18
Nodes (14): bodyOf(), choose(), closeDumpster(), hideAll(), hingeCFrame(), itemPicture(), lidOf(), onSearchStarted() (+6 more)

### Community 9 - "NPC & Pedestrians"
Cohesion: 0.17
Nodes (13): script_parent_parent_npc, describe(), flat(), Npc.face(), Npc.moveToward(), Npc.new(), loiterer(), pickSidewalk() (+5 more)

### Community 10 - "Open-World City Plan Spec"
Cohesion: 0.15
Nodes (15): Four-phase roadmap (LLM Council 3), City Rebuild spec: dense open-world city, CityPlan single source of truth, City district layout (Westshore, Southside, Eastgate, Midtown, Downtown, Vista Hills, Industrial, Old Port, The Docks), Enterable homes (~20%), Elevated Harbor freeway and suspension bridge, Infill (pack roadside lots with district buildings), Barter with pedestrians (+7 more)

### Community 11 - "CI & Visual Direction"
Cohesion: 0.18
Nodes (13): CI workflow (ci.yml), CI lint job, selene src lint, setup-rokit toolchain install, stylua --check src, Prompt: District expansion + minimal UI, Five tiered districts (Eastside < Maple Grove < Hillcrest < Business < Industrial), Minimal modern UI restyle (+5 more)

### Community 12 - "Loot & Rarity Design"
Cohesion: 0.17
Nodes (12): Rarity retune (lower Legendary/Jackpot weights, BIAS_STEP), README, DataStore Studio API access requirement, Future lighting technology, Loot.selfCheck odds sanity asserts, Max Players = 8, Rojo sync workflow, First five minutes (FTUE, guaranteed tutorial Rare) (+4 more)

### Community 13 - "Map, Districts & Red Zone"
Cohesion: 0.18
Nodes (11): Location card (district, tier, Hot today, Private property), MapData shared road module, MapUi minimap and full map, DUMP (competitor), Dumpster Divers! (competitor), Prospecting! (competitor), Heavy bin (2-player dumpster), Hot District (daily boosted district) (+3 more)

### Community 14 - "Quests & District Missions"
Cohesion: 0.39
Nodes (7): script_parent_config, Progress.gateMessage(), Quests.missionFor(), Quests.nextMission(), Quests.offer(), Quests.permitted(), Quests.selfCheck()

### Community 15 - "Risk Loop (Dig, Suspicion, Police)"
Cohesion: 0.22
Nodes (9): Dig deeper (push-your-luck), Drop & Run, Police AI state machine (Patrol/Investigate/Chase/Catch/Return), Rummage (pick 1 of 3 weighted bags), Suspicion bar, Tools (Gloves, Shoes, Flashlight, Crowbar, Metal Detector), Police AI (v1 staged), Wanted levels 0-3 (+1 more)

### Community 16 - "Networking & Anti-Exploit"
Cohesion: 0.29
Nodes (8): Pity counters (sinceEpic 30, sinceLegendary 120), Router (remote dispatch + rate limits), Single Action RemoteFunction + Event push channel, Anti-exploit from Phase 1 (distance, rate limit, speed check), Capture consequence (lose backpack only; disconnect counts as caught), Content Maturity target Minimal/Mild, DataStore persistence (UpdateAsync + session lock), Target server service architecture (LootService, SuspicionService, PoliceService, DataService...)

### Community 17 - "Car Driving"
Cohesion: 0.43
Nodes (5): drive(), keyAxis(), onCharacter(), readInput(), stop()

### Community 18 - "Road Network Builder"
Cohesion: 0.46
Nodes (6): buildDeck(), buildStreet(), flat(), isJunction(), slice(), strip()

### Community 19 - "Phase 1 Feel Spec"
Cohesion: 0.29
Nodes (7): Phase 1 spec: Feel, navigation and physical shops, Day cycle 24 min (DAY_LENGTH 1440), Natural dumpster placement (wall / enclosure pads), Two-storey storefront builder, Trash Hunter GDD v2.0, Per-player dumpster loot and cooldown, Trash Hunter GDD v1

### Community 20 - "Client Traffic"
Cohesion: 0.62
Nodes (6): at(), buildLanes(), cumulative(), flat(), offsetLine(), trimmed()

### Community 21 - "Shop & Monetization"
Cohesion: 0.40
Nodes (6): Physical stores (Hank's Hardware, Maple Motors), Shop Anywhere game pass, ShopUi separate window (store stock vs Robux shop), Cars and trunk storage, Monetization: sell convenience, not power or odds, Robux passes and products (Config.Robux)

### Community 22 - "Collection & Mutations"
Cohesion: 0.50
Nodes (4): Collection book, Junk Mechanics (competitor), Mutations (Shiny x2, Golden x5), Item condition and repair

## Knowledge Gaps
- **34 isolated node(s):** `CI workflow (ci.yml)`, `setup-rokit toolchain install`, `Serena project config`, `Luau language server`, `Rojo sync workflow` (+29 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 75 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `World.init()` connect `World Builder` to `Infill Building Generator`, `City Landmarks`?**
  _High betweenness centrality (0.110) - this node is a cross-community bridge._
- **Why does `Infill.build()` connect `Infill Building Generator` to `World Builder`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Why does `Hud.start()` connect `Client UI Controllers` to `World Builder`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Are the 32 inferred relationships involving `Data.get()` (e.g. with `Avatar.refresh()` and `answer()`) actually correct?**
  _`Data.get()` has 32 INFERRED edges - model-reasoned connections that need verification._
- **Are the 25 inferred relationships involving `Router.send()` (e.g. with `answer()` and `bind()`) actually correct?**
  _`Router.send()` has 25 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `Data.push()` (e.g. with `answer()` and `Router.send()`) actually correct?**
  _`Data.push()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 15 inferred relationships involving `Ui.new()` (e.g. with `build()` and `side()`) actually correct?**
  _`Ui.new()` has 15 INFERRED edges - model-reasoned connections that need verification._