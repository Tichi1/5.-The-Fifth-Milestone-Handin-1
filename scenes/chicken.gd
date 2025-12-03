extends CharacterBody2D


const GRAVITY : int = 4200 # apply gravity
const JUMP_SPEED : int = -1800 # when jump reduce speed

func _physics_process(delta):
	# apply gravity always
	velocity.y += GRAVITY * delta
	
	# if chicken touching ground
	if is_on_floor():
		# idle animation when the game hasn't started yet
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
		else:
			# enable normal running collision
			$RunCol.disabled = false
			
			# jumping when the player presses accept
			if Input.is_action_pressed("ui_up"):
				velocity.y = JUMP_SPEED
				$JumpSound.play()
			
			# ducking when the player holds down
			elif Input.is_action_pressed("ui_down"):
				$AnimatedSprite2D.play("duck")
				$RunCol.disabled = true   # disable tall collider while ducking
			
			# default running animation
			else:
				$AnimatedSprite2D.play("run")
	
	# if not on ground, show jump animation
	else:
		$AnimatedSprite2D.play("jump")
	
	# movement/collision
	move_and_slide()
