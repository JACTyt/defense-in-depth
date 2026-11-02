class_name Combat

const WEAK_MULTIPLIER := 0.35


static func damage(base: float, rating: GameTypes.Rating) -> float:
	match rating:
		GameTypes.Rating.STRONG:
			return base
		GameTypes.Rating.WEAK:
			return base * WEAK_MULTIPLIER
	return 0.0
