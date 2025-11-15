extends CharacterBody2D

const GRAVITY : int = 4200          # downward force applied constantly
const JUMP_SPEED : int = -1800      # upward velocity when jumping

func _physics_process(delta):
	# apply gravity every frame while in the air or on ground
	velocity.y += GRAVITY * delta
	
	# check if the chicken is touching the ground
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
	
	# apply movement and collision response
	move_and_slide()
