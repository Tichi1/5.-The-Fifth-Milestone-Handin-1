extends Node2D

@export var value:int = 1 # value of coin
var picked_up: bool = false

func _on_area_2d_body_entered(body: Node2D) -> void: 
	if picked_up: # just so it triggers ones
		return

	if body is CharacterBody2D: # if touched chicken
		picked_up = true

		# stop triggering
		$Area2D.monitoring = false

		# hide the coin - had to do it like this because i had lag
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.visible = false


		# play sound
		$CoinSound.play()

		# give the coin right away
		GameController.coin_collected(value)

		# wait until sound finishes, THEN delete node
		await $CoinSound.finished
		queue_free()
