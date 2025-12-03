extends Node

const SAVE_PATH := "user://save.cfg" # where saves data
const SECTION := "scores" # scores setion

# vars
const KEY_HIGH_SCORE  := "high_score" 
const KEY_TOTAL_COINS := "total_coins"
var high_score: int = 0
var total_coins: int = 0


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)

	if err == OK: # if the files loaded exist store
		high_score  = int(cfg.get_value(SECTION, KEY_HIGH_SCORE, 0))
		total_coins = int(cfg.get_value(SECTION, KEY_TOTAL_COINS, 0))
	else:
		high_score  = 0 # if not def 0 
		total_coins = 0


func save_data() -> void: # save the data
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_HIGH_SCORE,  high_score)
	cfg.set_value(SECTION, KEY_TOTAL_COINS, total_coins)
	cfg.save(SAVE_PATH)


func set_high_score(value: int) -> void:  #updates highest
	high_score = max(high_score, value)
	save_data()


func add_coins(amount: int) -> void: # adds coins
	total_coins += amount
	save_data()
