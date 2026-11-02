class_name IntegrityTracker
extends RefCounted

const MAXIMUM := 100.0

var integrity := MAXIMUM
var _depleted := false
var _restores: Array[Dictionary] = []


func is_depleted() -> bool:
	return _depleted


func apply_breach(amount: float) -> void:
	if _depleted:
		return
	integrity = maxf(0.0, integrity - amount)
	_depleted = integrity <= 0.0


func apply_ransomware(amount: float, restore_fraction: float, restore_delay: float) -> void:
	apply_breach(amount)
	if restore_fraction > 0.0:
		_restores.append({"remaining": restore_delay, "amount": amount * restore_fraction})


func tick(delta: float) -> void:
	if _depleted:
		return
	for i in range(_restores.size() - 1, -1, -1):
		_restores[i]["remaining"] -= delta
		if _restores[i]["remaining"] <= 0.0:
			integrity = minf(MAXIMUM, integrity + _restores[i]["amount"])
			_restores.remove_at(i)
