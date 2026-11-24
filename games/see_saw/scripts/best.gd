class_name SSBest
## Saves the best score (highest level reached) on this device.

const PATH := "user://see_saw.cfg"


static func get_best() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("score", "best_level", 0))


## Saves the score if it beats the best. Returns true if it's a new best.
static func submit(level: int) -> bool:
	if level <= get_best():
		return false
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("score", "best_level", level)
	cf.save(PATH)
	return true


static func reset() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("score", "best_level", 0)
	cf.save(PATH)
