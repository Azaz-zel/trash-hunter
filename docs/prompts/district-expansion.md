# Prompt: District expansion + minimal UI

Target: Claude Code, in the Trash Hunter repo (Rojo; the map is built in code).

```xml
<context>
Roblox game Trash Hunter. The map is built at server start by src/server/Systems/World.luau
from anchors in src/shared/Config.luau (World, Dumpsters, GUARD_POINTS). Loot odds come from
src/shared/Loot.luau (boost shifts rarity weights). Search.luau adds boost per dumpster.
Client UI kit: src/client/Ui.luau; HUD/panels in src/client/Controllers/*.
Locked decisions: realistic American small-town look (no cartoon), Meridian Logistics yard is
the police red zone, server decides all loot, stylua + selene must pass.
</context>

<task>
1. Reduce exposed grass and add many more trees: street trees on every residential sidewalk,
   backyard trees, a dense tree belt around the map edge, paved ground in commercial/industrial areas.
2. Add five districts, each with a loot tier that rises in this order:
   Eastside (low-income housing) < Maple Grove (middle-class) < Hillcrest Estates (luxury homes)
   < Business District (offices) < Industrial Park (factories, contains the Meridian yard).
   Each district: distinct buildings, a welcome sign, at least 3 dumpsters, and a rect + tier +
   boost in Config. Search adds the district boost on top of the red-zone boost.
3. Show the district name and tier when the player enters it, and the tier on each dumpster prompt.
4. Restyle the UI to minimal/modern: translucent dark panels, thin low-contrast borders, one
   modern sans font, one accent color, no thick comic outlines. Keep 44px+ tap targets.
</task>

<constraints>
- Only change files under src/ plus Config, README and the GDD appendix.
- MUST keep every existing gameplay system working (search, sell, police, data).
- NEVER add dependencies or external assets except the Roblox-owned police car already used.
- Keep part count reasonable (streaming is on); prefer few large parts over many tiny ones.
</constraints>

<done>
- stylua --check src and selene src report 0 errors.
- Studio playtest: no new console errors; each district has dumpsters; district banner appears;
  a dumpster in Industrial Park rolls with a higher boost than one in Eastside (verify via code).
- Commit and push to origin/main.
</done>
```

This prompt is for an agentic tool with real system access. Review the scope and done criteria before pasting.
