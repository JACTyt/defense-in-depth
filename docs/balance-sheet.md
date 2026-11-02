# Balance Sheet (Prototype)

Values live in `core/data/content.gd`; update this sheet when they change. Tuning results come from scripted builds in `tests/test_level_sim.gd`. **No human has played these numbers yet.**

## Global

| Setting | Value |
| --- | --- |
| Starting Integrity | 100 |
| Build phase | 15 s |
| Attack phase | 45–60 s |
| Deploy delay | 3 s |
| Weak rating multiplier | 0.35 |
| Strong rating multiplier | 1.0 |
| Route penalty per defended link | 150 (cost units = pixels) |
| Sell refund | 50% |

## Attacks

| Unit | Family | HP | Speed (px/s) | Breach damage | Bounty |
| --- | --- | --- | --- | --- | --- |
| Scanner | Network | 20 | 120 | 2 | $5 |
| Phishing email | Social | n/a | 90 | n/a | $10 when caught |
| Intruder | Malware | 30 | 70 | 5 | $5 |
| Ransomware | Malware | 340 | 50 | 40 | $40 |

**Compromised workstation:** compromise takes 3 s, then one intruder immediately and every 8 s after, up to 4 per workstation per wave. Resets at wave end. EDR in range cleans it in 4 s.

## Defenses

| Defense | Slot | Cost | Base upkeep | Damage | Shots/s | Range (px) | Special |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Firewall | Link | $100 | $5 | 15 | 2 | 120 | |
| Email Filter | Mail server | $150 | $10 | | | | 60% catch |
| EDR Agent | Node | $175 | $10 | 25 | 1 | 160 | Cleans workstations |
| Backups | Asset | $125 | $5 | | | | Restores 75% after 10 s |

## Levels

| Level | Waves | Start budget | Quarterly income | Layout |
| --- | --- | --- | --- | --- |
| 1 | 6 | $250 | $100 | 2 cable routes to Database; 8 nodes |
| 2 | 6 | $450 | $250 | 2 cable routes, mail server, 6 workstations; 13 nodes |
| 3 | 8 | $650 | $200 | 3 cable routes, mail server, 3 workstations, Database as data store; 14 nodes |

Income pays after every third wave. Upkeep is charged at each wave's start.

Levels 4-10 and infinite play use one formula in `core/data/level_layout.gd`, driven by difficulty `d` (story levels use 1-7; infinite uses its level number):

| Value | Formula |
| --- | --- |
| Start budget | $850 + $110 × `d`, with `d` capped at 7 |
| Quarterly income | $320 + $45 × `d`, with `d` capped at 7 |
| Scanners in a wave | 6 + 6 × wave progress + `d` |
| Emails in a wave | 1 + 0.3`d` + (2 + 0.2`d`) × wave progress |
| Ransomware in a wave | (1 + 0.3`d`) × wave progress, from wave 3 |
| Ransomware spacing | 6 s, shrinking 0.4 s per `d` above 7, to at least 1 s |

### Wave composition

| Wave | L1 scanners | L2 scanners | L2 phishing | L3 scanners | L3 phishing | L3 ransomware |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 6 | 6 | 0 | 6 | 1 | 0 |
| 2 | 8 | 6 | 2 | 6 | 1 | 0 |
| 3 | 10 | 8 | 3 | 8 | 2 | 0 |
| 4 | 12 | 8 | 4 | 8 | 2 | 1 |
| 5 | 14 | 8 | 4 | 8 | 2 | 1 |
| 6 | 16 | 10 | 5 | 10 | 2 | 2 |
| 7 | | | | 10 | 3 | 2 |
| 8 | | | | 12 | 3 | 3 |
| **Total** | **66** | **46** | **18** | **68** | **16** | **9** |

Spawn spacing: scanners spread over about 40 s (at least 1 s apart), emails 5 s apart from 3 s, ransomware 6 s apart from 5 s. Each attack phase lasts at least 50 s.

## Tuning results

Each row is a test that plays the full level with a scripted build, buying in the listed order as money allows.

| Level | Build | Target | Result |
| --- | --- | --- | --- |
| 1 | No defenses | Loses | Loses |
| 1 | 2 Firewalls | Wins | Wins |
| 2 | Firewalls only | Loses | Loses at wave 6 |
| 2 | Firewall, Email Filter, more Firewalls | Wins with damage | Wins with 100 Integrity using all 4 Firewall slots |
| 3 | Firewalls, Email Filter | Loses | Loses |
| 3 | Firewalls, Email Filter, Backups | Loses | Loses at wave 5 |
| 3 | Firewalls, Email Filter, 2 EDR | Loses | Loses at wave 8 |
| 3 | Firewalls, Email Filter, 2 EDR, Backups | Wins | Wins with 51 Integrity |

## Changes made because of the results

| Value | Was | Now | Why |
| --- | --- | --- | --- |
| Level 3 start budget | $450 | $650 | Upkeep starved the correct build before it could buy EDR |
| Level 3 quarterly income | $120 | $200 | Same |
| Ransomware HP | 220 | 340 | Two EDRs stopped everything, which made Backups pointless |
| Ransomware spacing | 14 s | 6 s | Groups overwhelm EDR, so some leak through for Backups to recover |
| Intruder HP | 40 | 30 | Firewalls dealt just under 40 per pass, so they never killed one and "weak" meant nothing |
| Intruder breach damage | 3 | 5 | With killable intruders, firewalls alone started winning Level 2 |

These results cover specific builds, not every possible one. Playtests may find a stronger EDR-heavy build. The next value to adjust if so is ransomware HP.
