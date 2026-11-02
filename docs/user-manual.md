# Defense in Depth: User Manual

You are the security lead of a growing company. Attackers want your database, and your budget is limited. Stop them by putting the right defense in the right place.

## Start the game

**Windows:** double-click `runner.bat`. The game opens fullscreen. Press **F11** to switch to a window.

If Windows shows "Windows protected your PC", select **More info**, then **Run anyway**. Windows shows this because the game isn't code-signed.

**If you see "the game file is missing":** the `builds` folder must stay next to `runner.bat`. Download and unzip the full game folder again.

## Main menu

- **Play story** starts your next unfinished level.
- **Infinite play** starts a run of random networks. The button shows your deepest level so far.
- **Story levels** lists all 10 levels and your best result on each. Click any unlocked level to replay it.
- **Quit** closes the game.

Finishing a story level unlocks the next one.

## How a level works

1. **Read the briefing.** It says what kinds of attack to expect, but not exact numbers or routes.
2. **Place defenses.** You have 15 seconds before each wave. Click **Start wave** to begin sooner, or pause to take your time.
3. **Survive the wave.** You can keep building during a wave, but new defenses take 3 seconds to deploy.
4. **Repeat** until you've survived every wave.

The level is lost if **Data Integrity** reaches 0. It starts at 100 on each level.

**The real goal is to finish with 100.** Any result above 0 wins, but only a level finished with no permanent damage counts as a perfect defense.

## Screen guide

| Area | What it shows |
| --- | --- |
| Top bar | Level, wave progress, budget, upkeep, Data Integrity, game speed, pause and menu |
| Map | Your network, with attackers moving toward the database |
| Right panel | The attacks in this level and a live log of events |
| Bottom bar | Defenses you can buy, and the button to start the next wave |

Hover over a defense to see its range. Hover over an attacker to see its name and route.

## Controls

| Input | Action |
| --- | --- |
| Left-click a defense card, then a green spot | Place a defense |
| Right-click a placed defense | Sell it for half its price |
| **Q**, **W**, **E**, **R** | Pick a defense |
| **Esc** | Cancel your selection |
| **Space** | Pause or resume (you can still place defenses while paused) |
| **1**, **2**, **3**, **4** | Game speed x1, x2, x4, x8 |
| **F11** | Switch between fullscreen and a window |
| **F3** | Show frames per second |

Game speed changes how long you wait, not what happens. The same placements give the same result at every speed.

## Money

- **Budget** starts at a set amount on each level.
- **Bounties** pay you for each attacker you stop.
- **Income** arrives after every third wave.
- **Upkeep** is charged at the start of each wave.

Upkeep rises with each extra copy of the same defense. Your second Firewall costs $10 per wave, your third costs $15, and so on. One of each type is cheaper than many of one type.

Budget can go below zero. Your defenses keep working, but you can't buy anything until it recovers.

## Attacks

| Attack | Looks like | What it does | What stops it |
| --- | --- | --- | --- |
| Port scanner bots | Red circle | Fast and weak; follows cables to the database | Firewalls |
| Phishing email | Envelope | Skips the cables and heads straight for a workstation | Email Filters |
| Intruder | Green triangle | Comes from a compromised workstation, already past your outer defenses | EDR; Firewalls also weaken it |
| Ransomware | Large green diamond with a health bar | Tough and slow; a hit costs 40 Data Integrity | EDR stops it; Backups recover most of the damage |

Attackers notice your Firewalls. At the start of each wave, those on cables choose routes that avoid defended links where they can, so one Firewall on one route won't be enough.

### What phishing does

A phishing email that gets through compromises a workstation, which turns green with a warning sign. About 3 seconds later it starts sending intruders, up to 4 per wave, until EDR cleans it or the wave ends.

## Defenses

| Defense | Key | Cost | Upkeep | Where it goes | What it does |
| --- | --- | --- | --- | --- | --- |
| Firewall | Q | $100 | $5 | A green spot on a cable | Strong against network traffic, weak against malware, useless against phishing |
| Email Filter | W | $150 | $10 | The mail server or a workstation | Catches 60% of phishing emails |
| EDR Agent | E | $175 | $10 | A green network device | Damages malware and cleans compromised workstations in range |
| Backups | R | $125 | $5 | The database | Restores 75% of a ransomware loss after 10 seconds, but doesn't prevent the hit |

Defenses unlock as you progress. Level 1 has Firewalls, Level 2 adds Email Filters, and Level 3 adds EDR and Backups.

**Mail server or workstation?** A filter on the mail server screens every email. A filter on a workstation screens only that workstation's email, as a second chance after the server's.

Each spot holds one defense. To change one, right-click to sell it first.

## Tips

- **Read the incident reports.** They name the attack, its path and what would have stopped it.
- **Cover every route.** Firewalls on the cables going into the Core switch catch traffic from each route.
- **Level 2 needs an Email Filter.** Firewalls alone will lose.
- **Put EDR where attackers actually go.** The Core switch is on every route, so start there.
- **Remember what Backups do.** They limit the damage from ransomware but don't stop it, so a perfect score needs EDR strong enough to stop it first.
- **Replay for 100.** More money comes later in a level, so the order you buy in matters.

## Infinite play

Each network is randomly generated and harder than the last. Data Integrity resets to 100 for each new network, and a loss ends the run. Your deepest level is saved.

## Your progress

Progress saves automatically when you finish a level, and it stays on your computer.

To start over, close the game and delete this file:

```
%APPDATA%\Godot\app_userdata\Defense in Depth\progress.json
```

Leaving a level through **Menu** abandons that attempt. Only finished levels are saved.
