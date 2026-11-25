class_name SSBest
## Saves the best score (points remaining at the end of a run) on this device.

const PATH := "user://see_saw.cfg"


static func get_best() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("score", "best_points", 0))


## Saves the score if it beats the best. Returns true if it's a new best.
static func submit(points: int) -> bool:
	if points <= get_best():
		return false
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("score", "best_points", points)
	cf.save(PATH)
	return true


static func reset() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("score", "best_points", 0)
	cf.save(PATH)
