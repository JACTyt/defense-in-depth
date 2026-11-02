class_name LevelLayout
## Builds a network of parallel routes and its waves. Used by story levels 4-10 and infinite play.

const INTERNET := 0
const MODEM := 1
const CORE := 2
const DATABASE := 3
const MAIL := 4
const FIRST_FREE_ID := 5
const ROUTE_TOP := 110.0
const ROUTE_BOTTOM := 570.0
const HOPS_LEFT := 420.0
const HOPS_RIGHT := 780.0
const WORKSTATION_REACH := 72.0
const WORKSTATION_REACH_BELOW := 96.0  # clears the office label, which sits under the office
const WORKSTATION_SPACING := 78.0
const MAX_FUNDED_DIFFICULTY := 7  # past this, budgets stop growing and ransomware bunches up
const RANSOM_GAP := 6.0
const MIN_RANSOM_GAP := 1.0
const RANSOM_GAP_SHRINK := 0.4


static func build(title: String, briefing: String, routes: int, hops: int, workstations: int, difficulty: int, wave_count: int, rng_seed: int) -> LevelData:
	var l := LevelData.new()
	l.display_name = title
	l.briefing = briefing
	l.rng_seed = rng_seed
	var funded := mini(difficulty, MAX_FUNDED_DIFFICULTY)
	l.start_budget = 850 + funded * 110
	l.quarterly_income = 320 + funded * 45
	l.allowed_defenses = [Content.firewall(), Content.email_filter(), Content.edr(), Content.backups()]
	var router := GameTypes.NodeKind.ROUTER
	l.nodes = [
		LevelData.NodeDef.new(INTERNET, GameTypes.NodeKind.INTERNET, "Internet", Vector2(70, 360)),
		LevelData.NodeDef.new(MODEM, router, "Modem", Vector2(220, 360)),
		LevelData.NodeDef.new(CORE, router, "Core switch", Vector2(960, 360), true),
		LevelData.NodeDef.new(DATABASE, GameTypes.NodeKind.ASSET, "Database", Vector2(1170, 360)),
		LevelData.NodeDef.new(MAIL, GameTypes.NodeKind.MAIL_SERVER, "Mail server", Vector2(220, 90)),
	]
	l.links = [LevelData.LinkDef.new(INTERNET, MODEM), LevelData.LinkDef.new(CORE, DATABASE)]
	var next_id := FIRST_FREE_ID
	for route in routes:
		var y := 360.0 if routes == 1 else lerpf(ROUTE_TOP, ROUTE_BOTTOM, float(route) / (routes - 1))
		var previous := MODEM
		var hub := MODEM
		for hop in hops:
			var x := HOPS_LEFT if hops == 1 else lerpf(HOPS_LEFT, HOPS_RIGHT, float(hop) / (hops - 1))
			var label := "Zone %d" % (route + 1)
			if hop == hops - 1:
				label = "Office %d" % (route + 1)
			elif hop == 0:
				label = "Gateway %d" % (route + 1)
			l.nodes.append(LevelData.NodeDef.new(next_id, router, label, Vector2(x, y), true))
			l.links.append(LevelData.LinkDef.new(previous, next_id, false, true))
			previous = next_id
			hub = next_id
			next_id += 1
		l.links.append(LevelData.LinkDef.new(previous, CORE, false, true))
		var reach := -WORKSTATION_REACH if y < 360.0 else WORKSTATION_REACH_BELOW
		for i in workstations:
			var offset := Vector2((i - (workstations - 1) / 2.0) * WORKSTATION_SPACING, reach)
			var position := l.node_def(hub).position + offset
			l.nodes.append(LevelData.NodeDef.new(next_id, GameTypes.NodeKind.WORKSTATION, "Workstation", position))
			l.links.append(LevelData.LinkDef.new(next_id, hub))
			l.links.append(LevelData.LinkDef.new(MAIL, next_id, true))
			next_id += 1
	for w in wave_count:
		var progress := float(w) / maxi(wave_count - 1, 1)
		var scanners := 6 + roundi(6.0 * progress) + difficulty
		var emails := roundi(1.0 + difficulty * 0.3 + (2.0 + difficulty * 0.2) * progress)
		var ransoms := 0 if w < 2 else roundi(progress * (1.0 + difficulty * 0.3))
		var gap := maxf(MIN_RANSOM_GAP, RANSOM_GAP - maxi(difficulty - MAX_FUNDED_DIFFICULTY, 0) * RANSOM_GAP_SHRINK)
		l.waves.append(Content.wave(scanners, emails, ransoms, gap, INTERNET, DATABASE, MAIL))
	return l
