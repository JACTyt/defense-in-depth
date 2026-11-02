class_name Economy
extends RefCounted

var budget: int
var _quarterly_income: int
var _copies: Dictionary = {}  # DefenseData -> int


func _init(start_budget: int, quarterly_income: int) -> void:
	budget = start_budget
	_quarterly_income = quarterly_income


func can_afford(cost: int) -> bool:
	return budget >= cost


func buy(defense: DefenseData) -> bool:
	if not can_afford(defense.cost):
		return false
	budget -= defense.cost
	_copies[defense] = _copies.get(defense, 0) + 1
	return true


func sell(defense: DefenseData) -> void:
	if _copies.get(defense, 0) == 0:
		return
	_copies[defense] -= 1
	budget += defense.cost / 2


## The nth copy of a defense type costs base × n per wave.
func upkeep_due() -> int:
	var total := 0
	for defense: DefenseData in _copies:
		var n: int = _copies[defense]
		total += defense.base_upkeep * n * (n + 1) / 2
	return total


func start_wave() -> void:
	budget -= upkeep_due()


func end_wave(wave_number: int) -> void:
	if wave_number % 3 == 0:
		budget += _quarterly_income


func add_bounty(amount: int) -> void:
	budget += amount
