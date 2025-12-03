extends Node

var score: int = 0
var total_coins: int = 0


func _ready() -> void:
	# load saved total once at start
	total_coins = SaveData.total_coins


func reset_run_score() -> void:
	score = 0 # reset 


func coin_collected(value: int) -> void:
	# per run
	score += value

	# always save coins
	SaveData.add_coins(value)
	total_coins = SaveData.total_coins

	# notify UIs of the changes
	EventController.emit_signal("coin_collected", total_coins)
	EventController.emit_signal("score_changed", score)

func add_score(amount: int) -> void:
	score += amount # add the amout
	EventController.emit_signal("score_changed", score)
