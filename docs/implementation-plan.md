# Defense in Depth Prototype Implementation Plan

> **For agentic workers:** Implement inline with superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking. Do not commit unless the user approves each commit; every step that would commit is left out for that reason.

**Goal:** A 3-level web build that tests whether players who lose to a bypass attack understand why and change their build.

**Architecture:** Pure rule classes in `core/` tested by GUT, driven by `.tres` data, displayed by thin Godot scenes. See [technical design](technical-design.md) for all signatures and resource fields, and [balance sheet](balance-sheet.md) for all values.

**Tech Stack:** Godot 4.7.2 standard build, GDScript, GUT 9.7.1, itch.io web export. In commands, `godot` means `D:\DevTools\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe`.

**Status (Nov 1, 2026):** Tasks 1–7 and Task 8 steps 1–2 are built. The build differs from the task text below in ways recorded as decisions 29–34 in the [decision log](decisions.md): rules moved into `LevelSim`, and content moved to `content.gd`. The [technical design](technical-design.md) describes what actually exists. Web and Windows exports succeed and the Windows build starts. Remaining: run the web build in a browser with the stress scene (F9), upload to itch.io, and run the playtests (Task 8 steps 3–5).

**Spec:** [GDD](../Defense%20in%20Depth%20—%20Game%20Design%20Document.md)

## Global Constraints

- About 30 hours in total. If a milestone runs over by more than 50%, apply the cut order.
- Cut order: level 3 first (Task 6 and Level 3 in Task 7).
- Placeholder art only: colored shapes using the GDD's family colors.
- Compatibility renderer; single-threaded web export.
- Target 60 fps at 100 units on web.
- `core/` has no references to `scenes/`.
- No upgrades, abilities, segmentation, events, codex, Reputation or saves.

## Review Focus

- **Restart after a loss:** all units, timers, budget, routes and RNG reset, so a replay matches the first attempt. Test in Task 1 and Task 3, manual check in Task 7.
- **Integrity reaches 0 while a restore is pending:** the level stays lost. Test in Task 3.
- **Every workstation is already compromised when an email lands:** the email has no effect and nothing errors. Test in Task 5.
- **Pausing mid-deploy:** pause doesn't shorten the 3 s delay. Manual check in Task 3.
- **Upkeep exceeds budget:** budget goes negative, purchases are blocked, defenses keep working. Test in Task 3.

---

### Task 1: Project, web export and routing (5 h)

**Files:**
- Create: `project.godot`, `core/game_types.gd`, `core/network/cost_astar.gd`, `core/network/network_graph.gd`, `autoload/event_bus.gd`, `autoload/game_state.gd`, `export_presets.cfg`
- Test: `tests/test_network_graph.gd`

**Interfaces:**
- Produces: `GameTypes` enums, `NetworkGraph` API, `EventBus` signals (technical design).

- [ ] **Step 1: Create the GDScript-only project, install a GUT release compatible with 4.7, set the Compatibility renderer, install matching export templates, and confirm an empty scene runs from a single-threaded web export**

Expected: the page loads in a browser locally. If the .NET build can't export to web, switch to the standard 4.7.2 build before going further.

- [ ] **Step 2: Write failing tests**

```gdscript
func test_route_takes_shortest_path():
    assert_eq(_two_route_graph().cable_route(0, 3), PackedInt64Array([0, 1, 3]))

func test_defended_link_moves_route_to_other_path():
    var g := _two_route_graph()
    g.set_link_defended(0, 1, true)
    assert_eq(g.cable_route(0, 3), PackedInt64Array([0, 2, 3]))

func test_removing_defense_restores_route():
    var g := _two_route_graph()
    g.set_link_defended(0, 1, true)
    g.set_link_defended(0, 1, false)
    assert_eq(g.cable_route(0, 3), PackedInt64Array([0, 1, 3]))

func test_cable_route_ignores_social_edges():
    var g := NetworkGraph.new()
    g.add_node(0, Vector2.ZERO)
    g.add_node(1, Vector2(100, 0))
    g.add_social(0, 1)
    assert_eq(g.cable_route(0, 1).size(), 0)
    assert_eq(g.social_route(0, 1), PackedInt64Array([0, 1]))
```

`_two_route_graph()` has nodes 0 at (0,0), 1 at (100,0), 2 at (100,20), 3 at (200,0), with cables 0-1, 1-3, 0-2, 2-3.

- [ ] **Step 3: Run tests to verify they fail**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: FAIL, `NetworkGraph` not defined.

- [ ] **Step 4: Implement `CostAStar` and `NetworkGraph` as in the technical design; use a penalty of 150**

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: all PASS.

### Task 2: Vertical slice: scanner vs Firewall (5 h)

**Files:**
- Create: `data/types/*.gd`, `data/attacks/scanner.tres`, `data/defenses/firewall.tres`, `core/rules/combat.gd`, `scenes/level/level.tscn`, `level.gd`, `wave_spawner.gd`, `attack_unit.tscn`, `attack_unit.gd`, `defense.tscn`, `defense.gd`, `unit_pool.gd`
- Test: `tests/test_combat.gd`

**Interfaces:**
- Consumes: `NetworkGraph`.
- Produces: `Combat.damage(base, rating) -> float`, `AttackUnit.activate(data, points)`, `AttackUnit.deactivate()`, data resources.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_strong_is_full_damage():
    assert_eq(Combat.damage(10.0, GameTypes.Rating.STRONG), 10.0)

func test_weak_is_reduced():
    assert_almost_eq(Combat.damage(10.0, GameTypes.Rating.WEAK), 3.5, 0.001)

func test_none_is_zero():
    assert_eq(Combat.damage(10.0, GameTypes.Rating.NONE), 0.0)
```

- [ ] **Step 2: Run tests to verify they fail**, then implement `Combat`, then run them to verify they pass.
- [ ] **Step 3: Build the scenes, pooling with 150 units, Firewall targeting at 10 Hz, and one hand-authored `LevelData`**
- [ ] **Step 4: Add a debug fps overlay and a stress scene with 100 moving units; run it in the web export**

Expected: scanners die on a Firewall-covered route; stress scene result recorded. If below 60 fps, fix now while the code is small.

### Task 3: Economy, Integrity, placement and level flow (4 h)

**Files:**
- Create: `core/rules/economy.gd`, `core/rules/integrity_tracker.gd`, `scenes/ui/hud.tscn`, `scenes/ui/shop.tscn`
- Modify: `scenes/level/level.gd`
- Test: `tests/test_economy.gd`, `tests/test_integrity_tracker.gd`

**Interfaces:**
- Consumes: `DefenseData`, `EventBus`.
- Produces: `Economy` and `IntegrityTracker` APIs (technical design).

- [ ] **Step 1: Write failing tests**

```gdscript
func test_license_upkeep_escalates():
    var e := Economy.new(1000, 100)
    for i in 3: e.buy(_firewall)  # base upkeep 5
    assert_eq(e.upkeep_due(), 30)  # 5 + 10 + 15

func test_mixed_types_only_charge_first_copy_rate():
    var e := Economy.new(1000, 100)
    e.buy(_firewall); e.buy(_edr)  # base 5 and 10
    assert_eq(e.upkeep_due(), 15)

func test_buy_fails_without_funds():
    var e := Economy.new(50, 100)
    assert_false(e.buy(_firewall))
    assert_eq(e.budget, 50)

func test_upkeep_can_make_budget_negative_and_blocks_buying():
    var e := Economy.new(100, 100)
    e.buy(_firewall)
    e.start_wave(1)
    assert_eq(e.budget, -5)
    assert_false(e.can_afford(1))

func test_income_after_waves_3_and_6_only():
    var e := Economy.new(0, 100)
    e.end_wave(1); e.end_wave(3); e.end_wave(6)
    assert_eq(e.budget, 200)

func test_sell_refunds_half_and_drops_upkeep():
    var e := Economy.new(100, 100)
    e.buy(_firewall); e.sell(_firewall)
    assert_eq(e.budget, 50)
    assert_eq(e.upkeep_due(), 0)

func test_breach_reduces_integrity():
    var t := IntegrityTracker.new()
    t.apply_breach(30.0)
    assert_eq(t.integrity, 70.0)

func test_restore_arrives_after_delay_and_clamps():
    var t := IntegrityTracker.new()
    t.apply_ransomware(40.0, 0.75, 10.0)
    t.tick(9.9)
    assert_eq(t.integrity, 60.0)
    t.tick(0.2)
    assert_eq(t.integrity, 90.0)

func test_depletion_is_final_while_restore_pending():
    var t := IntegrityTracker.new()
    t.apply_breach(70.0)
    t.apply_ransomware(40.0, 0.75, 10.0)
    assert_true(t.is_depleted())
    t.tick(11.0)
    assert_true(t.is_depleted())
```

- [ ] **Step 2: Run tests to verify they fail**, implement, run them to verify they pass.
- [ ] **Step 3: Build slot-restricted placement, the 3 s deploy delay, the 15 s build timer with early start, pause, selling, win and lose, and restart**

Manual check: placed mid-wave, a Firewall activates after 3 s of unpaused time; pausing during deploy doesn't advance it; only link slots accept Firewalls.

### Task 4: Level 1 with route adaptation (2 h)

**Files:**
- Create: `data/levels/level_01.tres`
- Modify: `scenes/level/level.gd`

**Interfaces:**
- Consumes: `NetworkGraph.set_link_defended`, `LevelData`.

- [ ] **Step 1: Author Level 1 from the balance sheet, marking links defended when a Firewall deploys or is sold**
- [ ] **Step 2: Recalculate routes in `Level` at wave start only**

Manual check: defending one route moves the next wave to the other route; an empty build loses; a two-Firewall build wins.

### Task 5: Phishing and compromised workstations (5 h)

**Files:**
- Create: `core/rules/phishing_rules.gd`, `core/rules/workstation.gd`, `data/attacks/phishing.tres`, `data/attacks/intruder.tres`, `data/defenses/email_filter.tres`, `data/levels/level_02.tres`
- Modify: `scenes/level/level.gd`, `scenes/level/wave_spawner.gd`
- Test: `tests/test_phishing.gd`

**Interfaces:**
- Consumes: `NetworkGraph.social_route`, `cable_route`, `Economy.add_bounty`.
- Produces: `PhishingRules` and `Workstation` APIs (technical design).

- [ ] **Step 1: Write failing tests**

```gdscript
func test_catch_rate_is_about_chance():
    var rng := RandomNumberGenerator.new(); rng.seed = 1
    var caught := 0
    for i in 1000: if PhishingRules.is_caught(rng, 0.6): caught += 1
    assert_between(caught, 550, 650)

func test_same_seed_gives_same_rolls():
    var a := RandomNumberGenerator.new(); a.seed = 7
    var b := RandomNumberGenerator.new(); b.seed = 7
    for i in 20:
        assert_eq(PhishingRules.is_caught(a, 0.6), PhishingRules.is_caught(b, 0.6))

func test_no_uncompromised_target_returns_minus_one():
    var rng := RandomNumberGenerator.new()
    assert_eq(PhishingRules.pick_target(rng, PackedInt64Array()), -1)

func test_workstation_waits_then_spawns_on_schedule():
    var w := Workstation.new()
    w.compromise()
    assert_eq(w.tick(2.9), 0)
    assert_eq(w.tick(0.2), 1)   # at 3 s
    assert_eq(w.tick(7.7), 0)   # 10.8 s elapsed
    assert_eq(w.tick(0.4), 1)   # past 11 s, 8 s after the first

func test_workstation_caps_at_four_per_wave():
    var w := Workstation.new()
    w.compromise()
    var total := 0
    for i in 100: total += w.tick(1.0)
    assert_eq(total, 4)

func test_clean_stops_spawning():
    var w := Workstation.new()
    w.compromise()
    w.clean()
    assert_eq(w.tick(100.0), 0)

func test_reset_for_wave_clears_compromise():
    var w := Workstation.new()
    w.compromise()
    w.reset_for_wave()
    assert_eq(w.tick(100.0), 0)
```

- [ ] **Step 2: Run tests to verify they fail**, implement, run them to verify they pass.
- [ ] **Step 3: Connect emails, the filter roll, social travel and intruders in `Level`; show the 60% catch chance in the filter's tooltip**
- [ ] **Step 4: Author Level 2**

Manual check against the tuning targets: Firewall-only loses in 5 of 5 tries; Firewall + Email Filter wins with damage. Adjust `.tres` values and update the balance sheet as needed. **This task is the core of the prototype: don't start Task 6 until it passes.**

### Task 6: Ransomware, EDR and Backups (3 h)

**Files:**
- Create: `data/attacks/ransomware.tres`, `data/defenses/edr.tres`, `data/defenses/backups.tres`, `data/levels/level_03.tres`
- Modify: `scenes/level/level.gd`, `scenes/level/defense.gd`

**Interfaces:**
- Consumes: `IntegrityTracker.apply_ransomware`, `Workstation.clean`.

- [ ] **Step 1: Apply `apply_ransomware` when an `encrypts` unit breaches, using Backups' fraction and delay if the asset has Backups, otherwise a fraction of 0**
- [ ] **Step 2: Add EDR's target filtering and 4 s cleaning of compromised workstations in range**
- [ ] **Step 3: Author Level 3**

Manual check against the tuning targets: no Backups loses, Backups-only loses, EDR + Backups wins.

### Task 7: Briefing, incident reports and full playthrough (3 h)

**Files:**
- Create: `scenes/level/incident_reporter.gd`, `scenes/ui/briefing.tscn`, `scenes/ui/incident_report.tscn`
- Modify: `scenes/level/level.gd`, `autoload/game_state.gd`, `data/attacks/*.tres`

**Interfaces:**
- Consumes: `EventBus.unit_breached`, `level_lost`, `wave_ended`, `AttackData.report_text`, `DefenseData.report_text`.

- [ ] **Step 1: Show a briefing with families and rough size only**
- [ ] **Step 2: Show a toast at wave end, a full report at each attack type's first breach (pausing the game) and a report on loss**

Each report names the attack, its path and the defense that would have stopped it, in plain language with no technical attack details.

- [ ] **Step 3: Link levels 1 → 2 → 3 with immediate restart on loss**

Manual check: play all 3 levels; restart gives identical emails and targets to the first attempt; no leftover units or timers.

### Task 8: Audio, release and playtests (3 h, sessions extra)

**Files:**
- Create: `autoload/audio_manager.gd`, `audio/*`, `docs/playtest-results.md`

- [ ] **Step 1: Add one sound per family, a breach alarm and a button click**
- [ ] **Step 2: Run the full GUT suite**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: all PASS.

- [ ] **Step 3: Upload the web build to itch.io (with the user's approval, as a restricted or draft page) and run the stress scene on a mid-range laptop**

Expected: 60 fps at 100 units.

- [ ] **Step 4: Run at least 5 watched sessions and record each check from the GDD's decision-point table in `docs/playtest-results.md`**
- [ ] **Step 5: Apply the decision-point outcome**
