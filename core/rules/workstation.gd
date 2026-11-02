class_name Workstation
extends RefCounted

const COMPROMISE_DELAY := 3.0
const SPAWN_INTERVAL := 8.0
const SPAWNS_PER_WAVE := 4

var is_compromised := false
var _timer := 0.0
var _spawned := 0


func compromise() -> void:
	is_compromised = true
	_timer = COMPROMISE_DELAY


## Returns how many intruders to spawn this tick.
func tick(delta: float) -> int:
	if not is_compromised:
		return 0
	_timer -= delta
	var due := 0
	while _timer <= 0.0 and _spawned < SPAWNS_PER_WAVE:
		_spawned += 1
		due += 1
		_timer += SPAWN_INTERVAL
	return due


func clean() -> void:
	is_compromised = false


func reset_for_wave() -> void:
	is_compromised = false
	_spawned = 0
