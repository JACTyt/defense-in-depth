class_name Content
## All game values. Keep in step with docs/balance-sheet.md.

const LEVEL_COUNT := 10
const STORY_WAVES := 8
## Story levels 4-10: name, briefing, routes, hops, workstations per route, difficulty.
const LATER_LEVELS := [
	["Branch office", "Threat intel: a new branch doubles the people who can click a bad link.", 2, 2, 2, 1],
	["Cloud migration", "Threat intel: new connections mean more routes for attackers to try.", 3, 2, 1, 2],
	["Remote workforce", "Threat intel: staff working from home are being targeted with phishing.", 3, 1, 2, 3],
	["The merger", "Threat intel: two networks are joining, and attackers noticed the announcement.", 4, 1, 1, 4],
	["Data center", "Threat intel: ransomware crews are looking for your backups and your data.", 3, 3, 2, 5],
	["Holiday freeze", "Threat intel: attackers expect a skeleton crew. Everything arrives at once.", 4, 2, 2, 6],
	["Global enterprise", "Threat intel: you're now a headline target. This is everything they have.", 4, 3, 3, 7],
]
const BUILD_SECONDS := 15.0
const DEPLOY_SECONDS := 3.0
const ATTACK_SECONDS := 50.0
const SPAWN_WINDOW := 40.0
const NODE := GameTypes.NodeKind.ROUTER

static var _cache: Dictionary = {}


static func scanner() -> AttackData:
	if not _cache.has("scanner"):
		var a := AttackData.new()
		a.display_name = "Port scanner bots"
		a.family = GameTypes.Family.NETWORK
		a.path = GameTypes.PathType.CABLE
		a.hp = 20.0
		a.speed = 120.0
		a.breach_damage = 2.0
		a.bounty = 5
		a.counter_text = "A Firewall on the route it used."
		a.lesson_text = "Automated scanners probe everything facing the internet. Firewalls drop this traffic before it reaches anything valuable."
		_cache["scanner"] = a
	return _cache["scanner"]


static func phishing() -> AttackData:
	if not _cache.has("phishing"):
		var a := AttackData.new()
		a.display_name = "Phishing email"
		a.family = GameTypes.Family.SOCIAL
		a.path = GameTypes.PathType.SOCIAL
		a.speed = 90.0
		a.bounty = 10
		a.counter_text = "An Email Filter on the mail server. Firewalls never see it."
		a.lesson_text = "Phishing targets people, not ports. The email arrives as normal mail, so the perimeter has nothing to block."
		_cache["phishing"] = a
	return _cache["phishing"]


static func intruder() -> AttackData:
	if not _cache.has("intruder"):
		var a := AttackData.new()
		a.display_name = "Intruder"
		a.family = GameTypes.Family.MALWARE
		a.path = GameTypes.PathType.INTERNAL
		a.hp = 30.0
		a.speed = 70.0
		a.breach_damage = 5.0
		a.bounty = 5
		a.counter_text = "An Email Filter prevents most compromises, and Firewalls on its route weaken intruders. EDR, unlocked in level 3, cleans the workstation."
		a.lesson_text = "A compromised workstation is already inside your perimeter, so it attacks from where your defenses are thinnest."
		_cache["intruder"] = a
	return _cache["intruder"]


static func ransomware() -> AttackData:
	if not _cache.has("ransomware"):
		var a := AttackData.new()
		a.display_name = "Ransomware"
		a.family = GameTypes.Family.MALWARE
		a.path = GameTypes.PathType.CABLE
		a.hp = 340.0
		a.speed = 50.0
		a.breach_damage = 40.0
		a.bounty = 40
		a.encrypts = true
		a.counter_text = "EDR to stop it on the way, and Backups to recover what it encrypts."
		a.lesson_text = "Backups don't prevent ransomware; they make it survivable. Stopping it takes a different control."
		_cache["ransomware"] = a
	return _cache["ransomware"]


static func firewall() -> DefenseData:
	if not _cache.has("firewall"):
		var d := DefenseData.new()
		d.display_name = "Firewall"
		d.slot = GameTypes.SlotType.LINK
		d.cost = 100
		d.base_upkeep = 5
		d.damage = 15.0
		d.shots_per_second = 2.0
		d.range_px = 120.0
		d.ratings = {GameTypes.Family.NETWORK: GameTypes.Rating.STRONG, GameTypes.Family.MALWARE: GameTypes.Rating.WEAK}
		_cache["firewall"] = d
	return _cache["firewall"]


static func email_filter() -> DefenseData:
	if not _cache.has("email_filter"):
		var d := DefenseData.new()
		d.display_name = "Email Filter"
		d.slot = GameTypes.SlotType.MAILBOX
		d.cost = 150
		d.base_upkeep = 10
		d.catch_chance = 0.6
		d.ratings = {GameTypes.Family.SOCIAL: GameTypes.Rating.STRONG}
		_cache["email_filter"] = d
	return _cache["email_filter"]


static func edr() -> DefenseData:
	if not _cache.has("edr"):
		var d := DefenseData.new()
		d.display_name = "EDR Agent"
		d.slot = GameTypes.SlotType.NODE
		d.cost = 175
		d.base_upkeep = 10
		d.damage = 25.0
		d.shots_per_second = 1.0
		d.range_px = 160.0
		d.clean_seconds = 4.0
		d.ratings = {GameTypes.Family.MALWARE: GameTypes.Rating.STRONG}
		_cache["edr"] = d
	return _cache["edr"]


static func backups() -> DefenseData:
	if not _cache.has("backups"):
		var d := DefenseData.new()
		d.display_name = "Backups"
		d.slot = GameTypes.SlotType.ASSET
		d.cost = 125
		d.base_upkeep = 5
		d.restore_fraction = 0.75
		d.restore_delay = 10.0
		_cache["backups"] = d
	return _cache["backups"]


static func level(index: int) -> LevelData:
	var cache_key := "level_%d" % index
	if not _cache.has(cache_key):
		match index:
			0:
				_cache[cache_key] = _build_level_1()
			1:
				_cache[cache_key] = _build_level_2()
			2:
				_cache[cache_key] = _build_level_3()
			_:
				var c: Array = LATER_LEVELS[index - 3]
				_cache[cache_key] = LevelLayout.build(c[0], c[1], c[2], c[3], c[4], c[5], STORY_WAVES, 1000 + index)
	return _cache[cache_key]


static func wave(scanners: int, emails: int, ransoms: int, ransom_gap: float, entry: int, target: int, mail: int) -> LevelData.WaveData:
	var entries: Array[LevelData.SpawnEntry] = [
		_spread(scanner(), scanners, entry, target),
		_emails(emails, mail),
		LevelData.SpawnEntry.new(ransomware(), ransoms, entry, target, 5.0, ransom_gap),
	]
	return LevelData.WaveData.new(entries, ATTACK_SECONDS)


static func _build_level_1() -> LevelData:
	var l := LevelData.new()
	l.display_name = "Startup"
	l.start_budget = 250
	l.quarterly_income = 100
	l.rng_seed = 101
	l.allowed_defenses = [firewall()]
	l.briefing = "Threat intel: network scanners, growing in number. They will pick the least defended route."
	l.nodes = [
		LevelData.NodeDef.new(0, GameTypes.NodeKind.INTERNET, "Internet", Vector2(80, 360)),
		LevelData.NodeDef.new(1, NODE, "Modem", Vector2(260, 360)),
		LevelData.NodeDef.new(2, NODE, "Web zone", Vector2(480, 170)),
		LevelData.NodeDef.new(3, NODE, "App zone", Vector2(480, 550)),
		LevelData.NodeDef.new(4, NODE, "Web servers", Vector2(740, 170)),
		LevelData.NodeDef.new(5, NODE, "App servers", Vector2(740, 550)),
		LevelData.NodeDef.new(6, NODE, "Core switch", Vector2(960, 360)),
		LevelData.NodeDef.new(7, GameTypes.NodeKind.ASSET, "Database", Vector2(1160, 360)),
	]
	l.links = [
		_cable(0, 1, false), _cable(1, 2), _cable(2, 4), _cable(4, 6),
		_cable(1, 3), _cable(3, 5), _cable(5, 6), _cable(6, 7, false),
	]
	for count: int in [6, 8, 10, 12, 14, 16]:
		var entries: Array[LevelData.SpawnEntry] = [_spread(scanner(), count, 0, 7)]
		l.waves.append(LevelData.WaveData.new(entries, ATTACK_SECONDS))
	return l


static func _build_level_2() -> LevelData:
	var l := LevelData.new()
	l.display_name = "Growing office"
	l.start_budget = 450
	l.quarterly_income = 250
	l.rng_seed = 202
	l.allowed_defenses = [firewall(), email_filter()]
	l.briefing = "Threat intel: network scanners, plus employees reporting strange emails."
	l.nodes = [
		LevelData.NodeDef.new(0, GameTypes.NodeKind.INTERNET, "Internet", Vector2(80, 360)),
		LevelData.NodeDef.new(1, NODE, "Modem", Vector2(240, 360)),
		LevelData.NodeDef.new(2, NODE, "Office north", Vector2(500, 180)),
		LevelData.NodeDef.new(3, NODE, "Office south", Vector2(500, 540)),
		LevelData.NodeDef.new(4, NODE, "Core switch", Vector2(900, 360)),
		LevelData.NodeDef.new(5, GameTypes.NodeKind.ASSET, "Database", Vector2(1140, 360)),
		LevelData.NodeDef.new(6, GameTypes.NodeKind.MAIL_SERVER, "Mail server", Vector2(240, 110)),
	]
	l.links = [
		_cable(0, 1, false), _cable(1, 2), _cable(1, 3), _cable(2, 4), _cable(3, 4), _cable(4, 5, false),
	]
	for i in 6:
		var hub := 2 if i < 3 else 3
		var y := 60 if i < 3 else 660
		_add_workstation(l, 7 + i, hub, 6, Vector2(400 + (i % 3) * 100, y))
	var scanners: Array[int] = [6, 6, 8, 8, 8, 10]
	var emails: Array[int] = [0, 2, 3, 4, 4, 5]
	for i in scanners.size():
		var entries: Array[LevelData.SpawnEntry] = [_spread(scanner(), scanners[i], 0, 5), _emails(emails[i], 6)]
		l.waves.append(LevelData.WaveData.new(entries, ATTACK_SECONDS))
	return l


static func _build_level_3() -> LevelData:
	var l := LevelData.new()
	l.display_name = "Enterprise"
	l.start_budget = 650
	l.quarterly_income = 200
	l.rng_seed = 303
	l.allowed_defenses = [firewall(), email_filter(), edr(), backups()]
	l.briefing = "Threat intel: everything from before. Peers report ransomware encrypting their data stores."
	l.nodes = [
		LevelData.NodeDef.new(0, GameTypes.NodeKind.INTERNET, "Internet", Vector2(70, 360)),
		LevelData.NodeDef.new(1, NODE, "Modem", Vector2(220, 360)),
		LevelData.NodeDef.new(2, NODE, "North gateway", Vector2(420, 140), true),
		LevelData.NodeDef.new(3, NODE, "Center gateway", Vector2(420, 360), true),
		LevelData.NodeDef.new(4, NODE, "South gateway", Vector2(420, 580), true),
		LevelData.NodeDef.new(5, NODE, "Core switch", Vector2(960, 360), true),
		LevelData.NodeDef.new(6, GameTypes.NodeKind.ASSET, "Database", Vector2(1170, 360)),
		LevelData.NodeDef.new(7, GameTypes.NodeKind.MAIL_SERVER, "Mail server", Vector2(220, 90)),
		LevelData.NodeDef.new(11, NODE, "North office", Vector2(700, 140), true),
		LevelData.NodeDef.new(12, NODE, "Center office", Vector2(700, 360), true),
		LevelData.NodeDef.new(13, NODE, "South office", Vector2(700, 580), true),
	]
	l.links = [
		_cable(0, 1, false), _cable(5, 6, false),
		_cable(1, 2), _cable(2, 11), _cable(11, 5),
		_cable(1, 3), _cable(3, 12), _cable(12, 5),
		_cable(1, 4), _cable(4, 13), _cable(13, 5),
	]
	_add_workstation(l, 8, 11, 7, Vector2(700, 50))
	_add_workstation(l, 9, 12, 7, Vector2(700, 450))
	_add_workstation(l, 10, 13, 7, Vector2(700, 670))
	var scanners: Array[int] = [6, 6, 8, 8, 8, 10, 10, 12]
	var emails: Array[int] = [1, 1, 2, 2, 2, 2, 3, 3]
	var ransoms: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3]
	for i in scanners.size():
		var entries: Array[LevelData.SpawnEntry] = [
			_spread(scanner(), scanners[i], 0, 6),
			_emails(emails[i], 7),
			LevelData.SpawnEntry.new(ransomware(), ransoms[i], 0, 6, 5.0, 6.0),
		]
		l.waves.append(LevelData.WaveData.new(entries, ATTACK_SECONDS))
	return l


static func _cable(a: int, b: int, has_slot := true) -> LevelData.LinkDef:
	return LevelData.LinkDef.new(a, b, false, has_slot)


static func _add_workstation(l: LevelData, id: int, hub: int, mail: int, position: Vector2) -> void:
	l.nodes.append(LevelData.NodeDef.new(id, GameTypes.NodeKind.WORKSTATION, "Workstation", position))
	l.links.append(LevelData.LinkDef.new(id, hub))
	l.links.append(LevelData.LinkDef.new(mail, id, true))


static func _spread(attack: AttackData, count: int, entry: int, target: int) -> LevelData.SpawnEntry:
	return LevelData.SpawnEntry.new(attack, count, entry, target, 0.0, maxf(1.0, SPAWN_WINDOW / count))


static func _emails(count: int, mail: int) -> LevelData.SpawnEntry:
	return LevelData.SpawnEntry.new(phishing(), count, mail, -1, 3.0, 5.0)
