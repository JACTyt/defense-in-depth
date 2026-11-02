class_name PhishingRules


static func is_caught(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() < chance


static func pick_target(rng: RandomNumberGenerator, uncompromised: Array[int]) -> int:
	if uncompromised.is_empty():
		return -1
	return uncompromised[rng.randi_range(0, uncompromised.size() - 1)]
