class_name LevelGenerator
## Random networks for infinite play. The same seed and depth always build the same level.

const MAX_WAVES := 10
const BASE_WAVES := 6


static func generate(run_seed: int, depth: int) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, depth])
	var routes := rng.randi_range(2, 4)
	var hops := rng.randi_range(1, 3)
	var workstations := rng.randi_range(1, 3)
	var wave_count := mini(BASE_WAVES + depth / 2, MAX_WAVES)
	var briefing := "Threat intel: attackers keep coming, and each network is tougher than the last. How far can you go?"
	return LevelLayout.build("Network %d" % depth, briefing, routes, hops, workstations, depth, wave_count, rng.randi())
