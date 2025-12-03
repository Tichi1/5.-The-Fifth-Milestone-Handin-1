extends Control

@onready var label: Label = $Label

func _ready() -> void:
	EventController.connect("coin_collected", _on_event_coin_collected)
	# show the saved total coins when thegame
	_on_event_coin_collected(SaveData.total_coins)


func _on_event_coin_collected(value: int) -> void:
	label.text = str(value) # show values
