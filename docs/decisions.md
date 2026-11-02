# Decision Log

Settled Oct 31, 2026 during the GDD review.

## Project

| # | Decision | Why |
| --- | --- | --- |
| 1 | Goal order: Godot and shared core, then portfolio demo; commercial release is not a goal | Justifies tight scope and asset packs |
| 2 | Plan for about 30 hours as a Godot beginner | Sets the scope cut |
| 3 | `core/` stays internal; no shared addon until the decision point | Root Access doesn't exist yet |
| 4 | GDD is the design source of truth; numbers and build detail live in `docs/` | Keeps the GDD readable |
| 5 | GUT tests cover pure logic only; scenes and UI use manual checklists | Best protection per hour during balancing |

## Prototype

| # | Decision | Why |
| --- | --- | --- |
| 6 | The prototype tests one claim: a player who loses to a bypass understands why and changes their build | Separates the game from generic TD |
| 7 | 3 attacks (scanner, phishing, ransomware), 4 defenses (Firewall, Email Filter, EDR, Backups), 3 levels | Brute force tests nothing new |
| 8 | Cut isometric art, upgrades, abilities, segmentation, events, codex, Reputation, saves | Not needed to test the claim |
| 9 | If time runs short, cut level 3 first | Level 2 is the core test |
| 10 | Decision point uses measurable checks from at least 5 watched sessions | "Fun" alone can't be tested |

## Game rules

| # | Decision | Why |
| --- | --- | --- |
| 11 | 6–8 waves of 60–75 s; 8–10 minute levels; about 90 minute campaign | The original numbers contradicted each other |
| 12 | Building allowed during waves, with a 3 s deploy delay | Reaction is possible but preparation is rewarded |
| 13 | Defenses go only on typed graph slots | Fits the graph and makes topology the decision |
| 14 | License upkeep: nth copy costs `base × n` per wave | Flat upkeep punished defense-in-depth |
| 15 | Strong, weak or none rating per family; "none" only where true in reality | Prevents a lookup-table game |
| 16 | Phishing compromises a workstation, which spawns internal units until cleaned or wave end | Makes the bypass visible and reuses cable pathing |
| 17 | Backups restore about 75% of a ransomware loss after about 10 s and never prevent it | The real lesson; EDR has a distinct job |
| 18 | Routes add cost per defended link, recalculated at wave start only | Delivers "Attacks adapt" with one cost function |
| 19 | Briefing shows families and rough size only; scanner "reveal" behavior removed | Route costs already cover it |
| 20 | Toast per wave; full report on first breach per attack type and on a loss | Per-wave reports don't fit 60–75 s waves |
| 21 | Win by surviving with Integrity above 0; immediate restart; no difficulty settings or stars | Level 2 must fail reliably and let the player retry fast |

## Post-prototype

| # | Decision | Why |
| --- | --- | --- |
| 22 | Rate limiter becomes a Firewall upgrade; antivirus removed; Access Control and CDN / Scrubber added, for 10 defenses | Every named counter can be built |
| 23 | Vendor compromise is a real attack, countered by Segmentation and revealed by SIEM | Gives Segmentation a purpose |
| 24 | Segmentation adds route cost, slows units and reduces income; never fully blocks | Avoids the sealed-route exploit |
| 25 | Levels 1–8 add one attack each, level 9 is a mixed exam, level 10 is the Zero-day boss | Keeps the teaching order |
| 26 | Genre is "Tower defense"; policy cards or Reputation, not both; no run-based roguelite | Fixed teaching order conflicts with randomized runs |
| 27 | No endless mode or leaderboard unless the campaign ships and players ask | Serves none of the goals |
| 28 | Shared universe with Root Access: names and codex flavor only | Cheap, adds no dependency |

## Defaults filled in while writing the docs

Not discussed in the review, chosen as the simplest option consistent with the above. Change freely.

| # | Default | Reason |
| --- | --- | --- |
| A | Intruder is a separate malware-family unit; Firewall rates weak against it | Lets Firewall + Email Filter win level 2 without EDR, which unlocks at level 3 |
| B | The filter rolls when the email leaves the mail server | One roll per email, simple to show |
| C | Budget may go negative from upkeep; this blocks purchases but never disables defenses | Avoids a death spiral |
| D | Selling refunds 50% and stops upkeep immediately | Lets players correct a build mid-level |
| E | Level 3 introduces two defenses, relaxing "one new defense per level" | Ransomware's lesson needs both |
| F | Godot `AStar2D` lacks per-link weights, so link costs use a `_compute_cost` override | The GDD's "link weights" wouldn't work as written |

## Decided during the build

| # | Decision | Why | Cost if wrong |
| --- | --- | --- | --- |
| 29 | Standard Godot + GDScript, chosen over .NET + C# | Official Godot 4.7 can't export C# to web, and web is the first platform | Rewrite in C# if tooling becomes the bigger problem |
| 30 | All rules, including a whole-level `LevelSim`, live in `core/` | Tests can play levels and check tuning without a window | Slightly more indirection in scenes |
| 31 | Attacks, defenses and levels in `content.gd`, not `.tres` | One reviewable file, directly usable in tests | No inspector editing; a conversion later |
| 32 | Signals on `LevelSim` instead of an `EventBus` autoload; no `GameState` or `AudioManager` autoloads | One scene and one simulation need no global state | Add autoloads when the campaign needs them |
| 33 | Main-scene flow gets automated smoke tests, beyond the original "pure logic only" | Cheap, and catches broken game flow | Some test upkeep as the UI changes |
| 34 | Placeholder sounds are synthesized in code | No asset files to manage | Replace for any polished release |
| 35 | Game speed x1, x2, x4, x8, using a fixed simulation step | Reduces waiting without changing the balance | Playtesters at x8 may miss what's teaching them; check during sessions |
| 36 | Game renamed from "Patch Notes" to "Defense in Depth" | "Patch Notes" suggests a changelog and patching isn't in the prototype; the new name is exactly what the game teaches | The name may read as dry to casual players, so the store page needs a friendly tagline |
| 37 | Map uses SVG icons; "Edge router" is labelled "Modem". IDS and IPS icons are drawn but not used | IDS and IPS have no mechanics yet, and showing a defense that does nothing would teach something false | Adding them later needs design and balance work |
| 38 | UI redesigned as network hardware: ink-blue panels, chamfered corners, cable yellow for the main action, Space Grotesk and JetBrains Mono (both OFL, bundled in `art/fonts/`) | The default look undersold the game | Needs a real-player check for readability |
| 39 | Selecting a defense always shows where it goes; Intruder advice says EDR unlocks in level 3 | Playtesting showed Email Filter placement wasn't obvious, and the report recommended a defense Level 2 doesn't have | None |
| 40 | Starts fullscreen and scales the 1280x720 layout evenly to 1920x1080; other shapes expand with the map centered; F11 switches to a 1600x900 window | Full HD is the main target, and bars would waste 16:10 screens | Very wide screens show more empty map |
| 41 | Email Filters also fit on workstations, with a second catch roll; license upkeep still applies | Gives players a way toward a perfect run | Could make phishing too easy; check in playtests |
| 42 | Saved best Integrity per level, with 100 marked perfect. Replaces decision 21's "no stars" and decision 8's "no saves" | Players want a reason to replay for 100 | None |
| 43 | Ten story levels, with 4-10 reusing the existing attacks and defenses on larger maps. Replaces decision 25 for now | Far cheaper than building the other attacks now; the later levels add scale, not new lessons | Levels 4-10 may feel repetitive |
| 44 | Infinite play with generated levels; a loss ends the run. Replaces decision 27 | Gives replay value after the story | Later levels are hard but not hand-tuned |
| 45 | Built ahead of the playtest decision point at the user's request | The user chose to expand now | Effort spent before the core lesson is tested with players |
