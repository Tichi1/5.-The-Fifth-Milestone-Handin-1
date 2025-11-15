# this is the file path to save the data for the new score
const SAVE_PATH := "user://save.cfg"
const SECTION := "scores"
# this is the key used to store the high score value
const KEY := "high_score"
# set variable of high score
var high_score: int = 0


func _ready() -> void:
	# when the node starts, load the saved high score from the file
	load_high_score()
func load_high_score() -> void:
	# create a new config file object
	var cfg := ConfigFile.new()
	# try to open the save file
	var err := cfg.load(SAVE_PATH)
	# if the file exists and loaded correctly
	if err == OK:
		# read the saved value - if not possibel  default to 0
		high_score = int(cfg.get_value(SECTION, KEY, 0))
	else:
		# if there was an error, just set high score to 0
		high_score = 0


func set_high_score(value: int) -> void:
	# update high_score only if the new value is higher than the current one
	high_score = max(high_score, value)
	# create a new config file object to save the updated value
	var cfg := ConfigFile.new()
	# write the high_score value into the file under our section and key
	cfg.set_value(SECTION, KEY, high_score)
	cfg.save(SAVE_PATH) # save it
