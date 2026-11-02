# Defense in Depth: System Manual

For anyone building, testing, changing or releasing the game. For how to play, see the [user manual](user-manual.md). For design intent, see the [game design document](../Defense%20in%20Depth%20—%20Game%20Design%20Document.md).

## Requirements

| Tool | Version | Needed for |
| --- | --- | --- |
| Godot, standard build (not .NET) | 4.7.2 | Editing, running, testing, exporting |
| Godot export templates | 4.7.2, matching the editor | Exports only |
| GUT | 9.7.1, included in `addons/gut/` | Tests |
| Python 3 (optional) | Any recent version | Serving the web build locally |

Use the standard build. The project is GDScript-only, and official Godot 4.7 can't export C# projects to web.

In the commands below, `godot` means the console executable, such as `Godot_v4.7.2-stable_win64_console.exe`. Run commands from the repo root.

## Set up

```powershell
git clone <repository-url>
cd <repository-folder>
godot --headless --path . --import
```

The import step generates the `.godot/` cache, including the list of `class_name` scripts. Repeat it after adding a new `class_name` script or asset outside the editor.

To play from source, open `project.godot` in the editor and press F5.

## Test

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

The exit code is 0 when everything passes. To run one file, add `-gselect=test_balance`.

| File | Covers |
| --- | --- |
| `test_network_graph.gd` | Routing and defended-link costs |
| `test_rules.gd` | Combat, economy, integrity, phishing and workstation rules; wave totals for levels 1-3 |
| `test_level_sim.gd` | Whole-level rules, plus tuning builds for levels 1-3 |
| `test_campaign.gd` | Workstation filters, saves, level validity, level generation |
| `test_balance.gd` | Scripted builds across all story levels and infinite play |
| `test_main.gd` | Game flow and speed |
| `test_menu.gd` | Menu, level select, infinite play flow, top bar fit |
| `test_ui.gd` | Theme, fonts, shop, feed, hints, screen settings |
| `test_icons.gd` | Icons exist, contain pixels and stay loaded |

Tests can't judge appearance. After visual changes, look at the running game: a texture freed too early still passes most tests but draws as a white box.

## Architecture

```
core/        Rules, data and saves. No dependency on scenes.
  level_sim.gd       One attempt at a level; advanced by tick(delta)
  progress.gd        Saved results
  network/           Routing
  rules/             Combat, economy, integrity, phishing, workstations
  data/              Attacks, defenses, levels, level generation
scenes/      Displays state and forwards input
  main.gd            Menu, game flow, HUD, reports
  level_view.gd      Map, units and effects
  ui_theme.gd        Colors, fonts and theme
  sfx.gd             Sounds synthesized at startup
  stress.gd          100-unit performance scene
art/         Icons and fonts
tests/       GUT tests
```

The key rule is that **all game rules live in `core/`**. `LevelSim` has no scene dependency, so tests can play entire levels without a window. Scenes read its state and listen to its signals.

Other rules to keep:

- **Fixed simulation step:** `main.gd` always calls `tick` with 1/30 s, and higher game speeds run more steps per frame. Never pass a scaled delta, because defenses fire at most once per tick and the balance would change.
- **Determinism:** each `LevelSim` has an RNG seeded from its level, so the same inputs replay identically. Don't use global random functions in `core/`.
- **Routes are fixed per wave:** they're computed at wave start, so a defense placed mid-wave only changes routes from the next wave.
- **Keep textures referenced:** canvas draws don't keep a texture alive. Get icons through `LevelView.icon_texture()`.

Interfaces are listed in the [technical design](technical-design.md).

## Saved data

`Progress` writes JSON to `user://progress.json`:

```json
{"best": {"0": 100, "1": 88}, "infinite": 4}
```

`best` maps a zero-based story level index to its best rounded Data Integrity. A level is unlocked if the previous one has an entry. `infinite` is the deepest infinite level cleared. A missing or damaged file starts fresh.

On Windows, `user://` is `%APPDATA%\Godot\app_userdata\Defense in Depth\`. The folder depends on the project name, so renaming the game orphans existing saves.

## Change the game

All game values are in `core/data/content.gd` and `core/data/level_layout.gd`. After changing one:

1. Run the tests. `test_balance.gd` and the tuning tests in `test_level_sim.gd` fail if the difficulty curve breaks.
2. Update [balance-sheet.md](balance-sheet.md).

### Add or change a story level

- **Levels 4-10:** add or edit a row in `Content.LATER_LEVELS`, with name, briefing, routes, hops, workstations per route and difficulty. `LevelLayout` builds the network and waves from those.
- **A hand-made level:** follow `_build_level_3()` in `content.gd`, and add it to the `match` in `Content.level()`.
- **Either way:** update `Content.LEVEL_COUNT`.

`test_campaign.gd` checks that every level has a database, connected workstations, valid routes and on-map nodes.

Node ID 1 must be the Modem, and a node needs the exact label "Core switch" for the balance tests' builds to find it.

### Add a defense

1. Add a function in `content.gd` that creates its `DefenseData`.
2. Add it to the `allowed_defenses` of the levels that use it.
3. Add an SVG to `art/icons/` and a row in `LevelView.DEFENSE_ICONS`.
4. Add its description to `_describe()` and its placement text to `_placement_hint()` in `main.gd`.
5. Add its key to `SHOP_KEYS` if there are more than four defenses, and check that the bottom bar still fits.
6. Add any new behavior to `LevelSim`, with tests first.

### Add an attack

1. Add a function in `content.gd` that creates its `AttackData`.
2. Add it to wave data with a `SpawnEntry`.
3. Give it a distinct shape in `LevelView._draw_unit()`, so it isn't identified by color alone.
4. Add any new behavior to `LevelSim`, with tests first.

### Change the look

Colors, fonts and button styles are in `scenes/ui_theme.gd`. Elements that touch the window edge use `UiTheme.flush()`, and floating elements use `UiTheme.box()`, which has chamfered corners. The base layout is 1280x720, and it scales up and expands to fit other screen shapes.

## Build a release

Install the export templates first, in the editor under **Editor > Manage Export Templates**.

```powershell
godot --headless --path . --export-release Windows builds/windows/DefenseInDepth.exe
godot --headless --path . --export-release Web builds/web/index.html
```

The folders under `builds/` must already exist. `export_presets.cfg` excludes `tests/` and `addons/gut/`.

**Windows release:** zip `runner.bat` and `builds/windows/`, keeping the layout. The executable is about 104 MB, which is over GitHub's 100 MB limit for repository files, so publish it as a GitHub Release asset. `builds/` is deliberately ignored by git.

**Web release:** upload the contents of `builds/web/`, with `index.html` at the root of the zip. The export is single-threaded, so it needs no special server headers. To test it locally:

```powershell
python -m http.server 8000 --directory builds/web
```

Then open http://localhost:8000. Opening `index.html` directly from disk won't work.

## Check performance

Press **F9** in the game to open the stress scene, which runs 100 units with defenses and shows the average frames per second. Esc returns to the game. The target is 60 fps on a mid-range laptop and on web.

| Check | Result |
| --- | --- |
| Desktop, this project's development PC | 163 fps average at 100 units |
| Web | Not measured yet |
| Mid-range laptop | Not measured yet |

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Could not find type` or `Identifier not declared` when running tests | The class cache is out of date, or you're in the wrong folder. Run the import command from the repo root. |
| Icons draw as white boxes | The texture was freed before rendering. Use `LevelView.icon_texture()`. |
| Export fails with missing templates | Install 4.7.2 templates that match the editor build. |
| Export can't write the Windows file | The game is still running. Close it and try again. |
| Tests pass but the game looks wrong | Tests don't judge appearance. Check it by running the game. |
| Godot imports files from `builds/` or `docs/` | A `.gdignore` is missing from that folder. |

## Known limitations

- The web build exports successfully, but hasn't been run in a browser. Saves on web are untested.
- Levels 4-10 have no new attacks or defenses.
- Upgrades, abilities, segmentation and events from the design document aren't built.
- Balance has only been tested with scripted builds, not with players.
- Only Windows has been built and run. There's no Linux export preset yet.
