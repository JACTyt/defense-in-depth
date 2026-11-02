class_name Progress
extends RefCounted
## Saved results: best Data Integrity per story level and the deepest infinite run.

var _path: String
var _best: Dictionary = {}  # level index -> int
var _infinite_best := 0


func _init(path: String) -> void:
	_path = path
	_load()


func best(index: int) -> int:
	return _best.get(index, -1)


func is_unlocked(index: int) -> bool:
	return index == 0 or _best.has(index - 1)


func infinite_best() -> int:
	return _infinite_best


func record_level(index: int, integrity: float) -> void:
	_best[index] = maxi(best(index), roundi(integrity))
	_save()


func record_infinite(depth: int) -> void:
	_infinite_best = maxi(_infinite_best, depth)
	_save()


func _save() -> void:
	var levels := {}
	for index: int in _best:
		levels[str(index)] = _best[index]
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save progress to %s" % _path)
		return
	file.store_string(JSON.stringify({"best": levels, "infinite": _infinite_best}))


func _load() -> void:
	if not FileAccess.file_exists(_path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	var levels: Variant = data.get("best", {})
	if levels is Dictionary:
		for key: String in levels:
			_best[key.to_int()] = int(levels[key])
	_infinite_best = int(data.get("infinite", 0))
