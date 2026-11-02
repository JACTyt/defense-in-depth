class_name DefenseData
extends RefCounted

var display_name: String
var slot: GameTypes.SlotType
var cost: int
var base_upkeep: int
var damage := 0.0
var shots_per_second := 0.0
var range_px := 0.0
var ratings: Dictionary = {}  # GameTypes.Family -> GameTypes.Rating
var catch_chance := 0.0
var restore_fraction := 0.0
var restore_delay := 0.0
var clean_seconds := 0.0


func rating_against(family: GameTypes.Family) -> GameTypes.Rating:
	return ratings.get(family, GameTypes.Rating.NONE)
