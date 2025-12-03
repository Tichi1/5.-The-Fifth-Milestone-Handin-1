extends Area2D

# handle meat script

@export var score_value: int = 100 # value of meat
var picked_up: bool = false

@onready var sound := $MeatSound # get the meat sound

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if picked_up: # just t0o make sure the player touches it once
		return

	if body is CharacterBody2D: # if touches chicken
		picked_up = true
		monitoring = false # cant be triggered again

		# hide meat visual
		if has_node("AnimatedSprite2D"): 
			$AnimatedSprite2D.visible = false
	

		# add score
		var main := get_tree().get_current_scene()
		if main and main.has_method("add_score_from_meat"):
			main.add_score_from_meat(score_value)

		# play sound
		if sound:
			sound.play()
			await sound.finished

		queue_free()
