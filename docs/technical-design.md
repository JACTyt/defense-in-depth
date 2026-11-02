# Technical Design (Prototype)

Implements the [GDD](../Defense%20in%20Depth%20—%20Game%20Design%20Document.md). Values come from the [balance sheet](balance-sheet.md). Godot 4.7.2 standard build, GDScript with static typing.

| Tool | Path |
| --- | --- |
| Editor | `D:\DevTools\Godot_v4.7.2\Godot_v4.7.2-stable_win64.exe` |
| Console (tests, exports) | `D:\DevTools\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe` |

**Principle:** all rules live in `core/` as classes with no scene tree dependency, including a whole-level simulation. Scenes only draw state and forward input, so tests can play entire levels without a window.

## Project structure

```
res://
  core/
    game_types.gd        enums
    level_sim.gd         one attempt at a level: phases, waves, units, defenses, reports
    network/             network_graph.gd, cost_astar.gd
    rules/               combat.gd, economy.gd, integrity_tracker.gd, phishing_rules.gd, workstation.gd
    progress.gd          saved results in user://progress.json
    data/                attack_data.gd, defense_data.gd, level_data.gd, content.gd,
                         level_layout.gd (route-based networks), level_generator.gd (infinite play)
  scenes/
    main.tscn, main.gd   game flow and UI, built in code
    ui_theme.gd          colors, fonts and Godot Theme for all UI
    level_view.gd        map drawing and combat effects
    sfx.gd               sounds synthesized at startup
    stress.tscn, stress.gd   100-unit performance check (F9 in game)
  tests/                 test_*.gd (GUT)
  addons/gut/            GUT 9.7.1
```

`core/` must not reference `scenes/`, which keeps later extraction into Root Access straightforward.

## Data

Attacks, defenses and levels are defined in code in `core/data/content.gd`, not `.tres` files. This keeps every value in one reviewable file and lets tests read it directly. The trade-off is no inspector editing; move to resources if the campaign goes ahead and tuning becomes frequent.

## Network graph and routing

`AStar2D` has per-point weights but not per-link weights, so `CostAStar` overrides `_compute_cost` to add link penalties. Its estimate is straight-line distance, which never exceeds the true cost, so routes stay optimal.

`NetworkGraph` holds two `CostAStar` instances, so cable units can't use social edges:

```gdscript
func add_node(id: int, position: Vector2) -> void
func position_of(id: int) -> Vector2
func add_cable(a: int, b: int) -> void
func add_social(a: int, b: int) -> void
func set_link_defended(a: int, b: int, defended: bool) -> void
func cable_route(from_id: int, to_id: int) -> PackedInt64Array
func social_route(from_id: int, to_id: int) -> PackedInt64Array
```

`LevelSim` caches routes at wave start, so a defense placed mid-wave only changes routes in the next wave. A missing route is an authoring error: it logs with `push_error` and skips the spawn, and a test checks that every level's cable spawns have routes.

## LevelSim

```gdscript
func _init(level: LevelData) -> void
func slots_for(data: DefenseData) -> Array[Slot]
func is_occupied(slot: Slot) -> bool
func place(data: DefenseData, slot: Slot) -> bool
func sell(placed: Placed) -> void
func start_wave_now() -> void
func tick(delta: float) -> void
func deliver_email() -> void
```

Signals: `wave_started`, `wave_ended`, `unit_breached`, `unit_killed`, `email_caught`, `workstation_compromised`, `workstation_cleaned`, `report_raised`, `level_won`, `level_lost`. These replace the planned `EventBus` autoload, since one scene listens to one simulation.

**Restart** creates a new `LevelSim`. Its RNG is seeded from the level, so the attempt replays identically for the same inputs.

**Game speed:** `main.gd` always calls `tick` with a fixed 1/30 s step, and x2, x4 or x8 just runs more steps per frame. Never pass a scaled delta to `tick`: defenses fire at most once per tick, so a larger step would give them fewer shots and change the balance. Tests confirm that outcomes match at every speed and frame rate.

**Pause and modals:** `main.gd` simply stops calling `tick`. The UI keeps working, so the player can place defenses while paused, and deploy timers don't advance. The engine's scene tree pause isn't used.

## Web export

- Export single-threaded (`variant/thread_support=false`), so itch.io needs no cross-origin isolation headers.
- The Compatibility renderer is required for web.
- Presets in `export_presets.cfg` write to `builds/web/` and `builds/windows/`. `tests/` and `addons/gut/` are excluded.
- Check the stress scene on web with F9 in the game. The label shows the average fps.

## Testing

GUT covers rules and routing, the main scene's flow, and full-level tuning builds that play each level headlessly. Visuals, audio and game feel are checked by hand.

```powershell
& "D:\DevTools\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Run `--headless --path . --import` once first after adding new `class_name` scripts.
