# Defense in Depth — Game Design Document

Oct 31, 2026 · @Dmytro Maistruk

Related docs: [technical design](docs/technical-design.md) · [balance sheet](docs/balance-sheet.md) · [implementation plan](docs/implementation-plan.md) · [decision log](docs/decisions.md)

Sections mark what is **prototype** scope and what is **post-prototype**. If they conflict, prototype scope wins until the decision point.

## Overview

Defense in Depth is a 2D tower defense game where you are the security lead of a growing company, defending its network against waves of cyberattacks with a limited budget.

| Item | Decision |
| --- | --- |
| Genre | Tower defense |
| Engine | Godot 4.7.2 standard build, GDScript (C# can't export to web on official Godot 4.7) |
| View | Prototype: flat 2D network map. Post-prototype: 2D isometric-feel map (2.5D), flat UI |
| Platforms | Web export (itch.io) first, then Windows/Linux |
| Session length | 8–10 minutes per level, about 90 minutes per campaign |
| Audience | Casual strategy players, students, people new to security |
| Team | Solo |
| Prototype budget | About 30 hours (10 hours/week for 3 weeks), Godot beginner |

**Goal priority** (the higher goal wins any conflict)

1. Learn Godot and build a reusable core for Root Access.
2. Produce a portfolio-worthy demo of defensive thinking.
3. A commercial release or large audience is not a goal.

**Design pillars**

1. **Right control for the right threat.** Raw power doesn't win; matching defenses to attack types does.
2. **Budget is the real enemy.** Every defense costs money and upkeep, like a real security budget.
3. **Attacks adapt.** Attackers route around strong defenses (e.g. phishing ignores firewalls entirely).
4. **Learn by losing.** Every breach shows what would have stopped it.

**Elevator pitch:** Kingdom Rush in a server room. Your firewall is great until someone clicks the phishing link.

**What the prototype must prove:** a player who loses to an attack that bypasses their defenses understands why, and changes their build on the next try.

## Core loop, waves and economy

Each level is a company network under attack for 6–8 waves of 60–75 seconds each.

**Level loop**

1. **Briefing:** threat intel shows which attack families are coming and a rough size, never exact counts or routes.
2. **Build phase (15 s):** place defenses on valid slots. The player can start the wave early.
3. **Wave (45–60 s):** attacks travel toward valuable assets. Pause is always available.
4. **Breach or block:** blocked attacks give bounty; breaches drain **Data Integrity** (your health).
5. **Wave end:** a one-line toast. Full reports appear only as described under [Educational design](#educational-design).

**Building during waves:** allowed. A defense placed during a wave takes 3 seconds of game time to deploy, and pausing doesn't skip that time.

**Game speed:** the player can choose x1, x2, x4 or x8 at any time, and the choice carries across levels and retries. Speed never changes the outcome, only how long it takes to watch. Session lengths in this document are at x1.

**Win and lose:** survive every wave with Integrity above 0. A lost level restarts immediately, with the report offered first. The long-term goal is finishing each level at 100 Integrity: the best result per level is saved and shown in the menu, with 100 marked as perfect.

**Economy**

| Resource | Source | Spent on / effect |
| --- | --- | --- |
| Budget ($) | Start of level + quarterly income every 3 waves + bounties | Placing defenses |
| License upkeep | Charged at the start of each wave | The nth copy of a defense type costs `base × n` per wave |
| Data Integrity | Starts at 100 each level | Lost on breaches; 0 = level lost |

License upkeep replaces flat per-tower upkeep. First copies stay cheap and duplicates get expensive, so the budget penalizes mono-builds and rewards layered defense.

**Prototype cuts:** tower upgrades, active abilities, segmentation, events, codex and Reputation all wait until after the decision point.

**Game modes (built):** a main menu offers story mode, level select for any unlocked level, and infinite play.

- **Story mode:** 10 levels of growing networks. Levels 4-10 currently reuse the three existing attacks and four defenses on larger maps, and have names but no written story.
- **Infinite play:** offered after level 10 and from the menu. Randomly generated networks get harder until one beats the player, and the deepest level reached is saved. A loss ends the run.

**Future campaign content:** the table below is the longer-term plan for introducing the remaining attacks and defenses. Only levels 1-3 match it today.

| Level | New attack | New defense | Status |
| --- | --- | --- | --- |
| 1 | Port scanner bots | Firewall | Prototype |
| 2 | Phishing | Email Filter | Prototype |
| 3 | Ransomware | EDR, Backups | Prototype |
| 4 | Brute force | MFA Gate, Firewall rate-limiter upgrade | Post-prototype |
| 5 | DDoS swarm | CDN / Scrubber | Post-prototype |
| 6 | Malware worm | Honeypot, Security Training | Post-prototype |
| 7 | Insider threat | SIEM, Access Control | Post-prototype |
| 8 | Vendor compromise | Segmentation | Post-prototype |
| 9 | None: mixed exam of everything so far | None | Post-prototype |
| 10 | Zero-day (boss) | Emergency Patch ability | Post-prototype |

**Meta-progression (post-prototype, pick one):** policy cards after the campaign (e.g. "Bug bounty program: zero-days arrive 1 wave earlier but are weaker"), or Reputation buying permanent campaign upgrades if policy cards don't ship. Level order stays fixed because it teaches concepts in sequence. This is not a run-based roguelite.

**Not planned:** leaderboards.

## Mechanics

The twist on classic tower defense: attacks don't all walk the same path. Each attack type has its own route and its own counter.

### Network layout

- The map is a network graph: **Internet edge → perimeter → internal zones → critical assets**.
- Network attacks travel along cables (classic TD lanes).
- Social attacks travel social edges from the mail server to **employees** (people icons on workstations), skipping the perimeter.
- Supply-chain attacks (post-prototype) spawn *inside* the network from a trusted vendor node.

### Placement

Defenses go only on valid graph slots, and each type is restricted to a slot type.

| Slot | Defenses |
| --- | --- |
| Link | Firewall, CDN / Scrubber, Segmentation |
| Node | EDR Agent, Honeypot |
| Login server | MFA Gate |
| Mail server or workstation | Email Filter (on the server it screens all email; on a workstation, only that workstation's) |
| Asset | Backups, Access Control |
| Global (no slot) | SIEM, Security Training |

### Attack adaptation

At the start of each wave, cable attackers pick routes with an added cost for each defended link, so they drift toward weaker paths. Routes don't change during a wave.

### Counter model

Every defense has a **strong, weak or none** rating per attack family. "None" is used only where it is true in real security. No single defense is enough, so the player has to layer them. Slot restrictions decide which units a defense can touch: MFA is rated strong against the network family, but only brute force goes to login servers.

| Defense | Network | Social | Malware | Insider | Notes |
| --- | --- | --- | --- | --- | --- |
| Firewall | Strong | None | Weak | None | Rate-limiter upgrade adds weak damage to brute force at login servers |
| Email Filter | None | Strong | None | None | About 60% catch chance per email, shown to the player |
| EDR Agent | None | None | Strong | None | Also cleans compromised workstations in range |
| Backups | None | None | None | None | Restores about 75% of a ransomware loss after about 10 s; never prevents the hit |
| MFA Gate | Strong | None | None | None | Login servers only |
| CDN / Scrubber | Weak | None | None | None | Prevents DDoS overload on its link |
| Security Training | None | Weak | None | None | Global; lowers phishing success |
| SIEM | None | None | None | Weak | Global; reveals stealthy units |
| Honeypot | None | None | None | None | Decoy that lures and slows cable attackers |
| Access Control | None | None | None | Strong | Slows and damages insiders at the asset |

Segmentation is a link upgrade, not a damage dealer: see below.

### Attacks (enemies)

| Attack | Family | Path | Behavior | Main counters | Status |
| --- | --- | --- | --- | --- | --- |
| Port scanner bots | Network | Cables | Fast, weak | Firewall | Prototype |
| Phishing email | Social | Social edge | Ignores firewalls; compromises a workstation | Email Filter, then EDR | Prototype |
| Ransomware | Malware | Cables to data stores | Encrypts an asset for a large Integrity loss | EDR (stop), Backups (recover) | Prototype |
| Brute-force login | Network | Cables to login servers | Tanky, slow | MFA, rate limiter | Post-prototype |
| DDoS swarm | Network | Cables, many units | Overloads a node, disabling its defenses temporarily | CDN / Scrubber | Post-prototype |
| Malware worm | Malware | Spreads node to node | Splits when it infects a node | EDR | Post-prototype |
| Insider threat | Insider | Spawns inside | Slow, stealthy, goes for the crown jewels | Access Control, SIEM | Post-prototype |
| Vendor compromise | Insider | Spawns at the vendor node | Trusted entry point inside the network | Segmentation, SIEM | Post-prototype |
| Zero-day (boss) | Boss | Any | Immune to all defenses for a few seconds | Emergency Patch + layered defense | Post-prototype |

### Phishing and compromised workstations

1. An email leaves the mail server. The Email Filter rolls its visible catch chance; a caught email pays bounty.
2. An uncaught email travels a social edge to a random uncompromised workstation. A filter on that workstation rolls again on arrival.
3. If it gets through, the workstation is compromised after about 3 seconds and starts spawning **intruders** (malware family) on the cable network.
4. It keeps spawning until EDR in range cleans it or the wave ends.

Rolls use a seeded RNG, so a level replays the same way.

### Breach rules

- A unit reaching an asset costs Integrity equal to its damage, then disappears.
- Ransomware encrypts the asset for a large loss. With Backups, about 75% of that loss returns after about 10 seconds. If Integrity hits 0 before the restore arrives, the level is lost.

### Segmentation (post-prototype)

A purchasable link upgrade. A segmented link adds a large route cost and slows units crossing it, but reduces quarterly income from the zones it separates. It never fully blocks a path, which prevents the classic sealed-route exploit.

### Active abilities (post-prototype)

- **Emergency Patch:** removes zero-day immunity in an area.
- **Isolate Node:** cut a node off for 10 s to stop spread (blocks your own traffic too, costs income).
- **Incident Response:** temporary damage boost everywhere.

### Events (post-prototype)

Random mid-level events: budget cut, new remote office opens (new entry point), CEO clicks a link (instant phishing spawn), vendor compromised (triggers the Vendor compromise attack).

## Educational design

Players learn defense-in-depth by failing with a single strong defense, never by reading a lecture.

- **Mechanics mirror reality.** Firewalls really don't stop phishing; backups really are the answer to ransomware. The "aha" moments are real security lessons.
- **Incident reports.** A full one-screen report appears the first time each attack type breaches and on losing a level: what got in, which path, which defense would have stopped it. Other wave ends get a one-line toast. Written like a real postmortem, short and plain.
- **Threat codex (post-prototype).** Each new attack and defense unlocks a codex card with a 3-line real-world explanation (what it is, a famous fictionalized example, how companies defend).
- **Fictional company and attackers.** No real brands, no technical attack details. Defense in Depth and Root Access share a fictional company and attacker group at the level of names and codex flavor only, with no story or save links.
- **Portfolio angle:** a playable demo of defensive thinking, relevant for security roles (e.g. a cybersecurity academy application).

## Art, audio and 2D / 2.5D direction

**Prototype:** simple SVG icons for network equipment and defenses in `art/icons/`, colored dots for attacks, a few sound effects, and readable color coding. The test doesn't depend on art.

**Post-prototype:** an isometric server-room map gives depth and charm while gameplay stays fully 2D.

| Screen | Dimension | Approach |
| --- | --- | --- |
| Level map | 2.5D | Isometric tiles (Godot TileMapLayer, isometric mode) as decoration over the graph: server racks, desks, cables, cloud islands |
| Units and towers | 2D sprites in iso view | Small readable icons with clear silhouettes and color by type |
| HUD, shop, reports | 2D | Clean flat UI styled like a security dashboard |
| Campaign map | 2D | Company org chart / office floor plan growing over time |

**Visual style:** friendly and bright, closer to Kingdom Rush or Mini Metro than to hacker noir. This keeps it distinct from Root Access and approachable for non-gamers.

**Readability rules:**

- One color per attack family (network = red, social = purple, malware = green, insider = yellow, boss = white).
- Range circles and attack paths shown on hover.
- Effects (shields, packet hits) kept small so the map stays readable at 30+ units.

**Art production:** isometric asset packs (Kenney has suitable office/tech sets) plus custom icons. Low art cost.

**Audio:** upbeat electronic music; distinct sound per attack family so players can "hear" what's coming; an alarm on breaches.

## Godot technical architecture and reuse for Root Access

The network is a graph, not a tilemap path, so attacks pathfind on nodes and links. Full detail is in the [technical design](docs/technical-design.md).

**Core systems:** `LevelSim`, `NetworkGraph`, `Economy`, `IntegrityTracker`, `Workstation`, `Content`. Scenes only draw state and forward input.

**Root Access reuse:** Root Access is only a planned game, so `core/` stays an internal folder with no addon or shared API built up front. Extraction happens at the decision point.

**Performance:** target 60 fps with 100 units on web export. Units are drawn directly, not as nodes, so the prototype needs no object pooling.

## Prototype scope, roadmap, risks

The prototype is 3 playable levels in about 30 hours, then a decision: expand Defense in Depth or move the core into Root Access.

**Prototype contents:** 3 levels, 3 attacks (scanner bots, phishing, ransomware) plus intruders spawned by compromised workstations, 4 defenses (Firewall, Email Filter, EDR, Backups), budget + license upkeep, incident reports, web export.

**Cut order if time runs short:** level 3 (with ransomware, EDR and Backups) goes first.

**Roadmap:** see the [implementation plan](docs/implementation-plan.md) for milestones and acceptance checks.

**Decision point:** at least 5 watched sessions with people outside security.

| Check | Pass |
| --- | --- |
| Explains in their own words why the firewall failed against phishing | At least 4 of 5 |
| Changes their build after losing level 2, and clears it within 3 tries | At least 4 of 5 |
| Chooses to replay or asks for more without being prompted | At least 3 of 5 |
| Web build holds 60 fps at 100 units on a mid-range laptop | Pass or fail |

- **All checks pass:** build the campaign.
- **Only the learning checks pass:** one round of feel fixes, capped at 10 hours, then retest.
- **Otherwise:** extract `core/` and start Root Access.

**Risks and mitigations**

| Risk | Mitigation |
| --- | --- |
| Feels like generic TD with labels | The prototype centers on phishing bypass and compromised workstations |
| Counters become a lookup table | Partial counters and license upkeep force layered, budget-limited builds |
| Too easy to cheese with one tower type | License upkeep escalates; level 2 is tuned so firewall-only almost always loses |
| 30 hours is too few for a Godot beginner | Fixed cut order, placeholder art, tests only on pure logic |
| Web performance misses target | Stress scene built in from the start; units are drawn directly, not as nodes |
| Teaching feels preachy | Lessons only in short incident reports and the optional codex |
