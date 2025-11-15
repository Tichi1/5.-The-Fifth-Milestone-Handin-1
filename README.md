In this assignment, I didn’t make any big structural changes because my previous version was already pretty complete. Instead, I focused on smaller aspects. I added more detail to the overall setup, organized my scripts better, and commented the code to make it easier to read.

The main new feature I implemented was a high score system. Now, whenever the player breaks the record, a message appears on the screen to celebrate the achievement. This small addition makes the game feel more rewarding and gives the player a sense of progress.
Here, there are some snippets of my game and the main scripts

PART OF THE MAIN SCRIPT
const CHICKEN_START_POS := Vector2i(150,285)
const CAM_START_POS := Vector2i(576,324)
var difficulty
var MAX_DIFFICULTY:int = 2
var score: int
const SCORE_MODIFIER : int =10
var speed :float
var high_score :int
const START_SPEED: float = 6
const MAX_SPEED: int = 12
const SPEED_MODIFIFER: int = 9500
var screen_size: Vector2i
var ground_height: int
var game_running :bool 
var last_obs
@onready var camera := $Camera2D

# reference the instanced HUD root in Main - it helped me to call each nodde
@onready var _score_label: Label    = get_node("HUD/ScoreLabel")          
@onready var _high_label: Label     = get_node("HUD/HighestScore")          
@onready var _new_high_label: Label = get_node("HUD/NewHighScore")         
@onready var _press_play: Control   = get_node("HUD/PressPlay")
@onready var _jump_hint: Control    = get_node("HUD/Jump")
@onready var _crouch_hint: Control  = get_node("HUD/Crouch")

# track if we've already shown the popup in this run
var _new_high_shown: bool = false


func _ready():
	# cache screen/ground metrics and restart
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node('Button').pressed.connect(new_game)

	# init HUD values safely
	if _high_label:
		_high_label.text = 'HIGH SCORE: ' + str((high_score if high_score > 0 else 0) / SCORE_MODIFIER)
	if _new_high_label:
		_new_high_label.visible = false

	new_game()
	
func new_game():
	# reset run state and counter -  unpause -  start at easiest difficulty
	score = 0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	
	# remove old obstacles whenever we start a new game
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	
	# snap everything back to spawn positions
	$Chicken.position = CHICKEN_START_POS
	$Chicken.velocity = Vector2i(0,0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0,0)
	

	
	# show prompt to start and hide game over ui
	if _press_play: _press_play.show()     
	if _jump_hint: _jump_hint.show()      
	if _crouch_hint: _crouch_hint.show()  

	$GameOver.hide() # show restart only when lose

	# reset popup & refresh high text
	_new_high_shown = false
	if _new_high_label: _new_high_label.visible = false
	if _high_label:
		_high_label.text = 'HIGH SCORE: ' + str((high_score if high_score > 0 else 0) / SCORE_MODIFIER)
	

func _process(delta):

	if game_running:
		# Increase speed, update difficulty, and try to spawn obstacles
		speed = START_SPEED + score / SPEED_MODIFIFER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		adjust_difficulty()
		generate_obs()
		
		# scroll world and accumulate speed 
		$Chicken.position.x += speed
		$Camera2D.position.x += speed
		score += speed
		show_score()
		
		# so high score is not shown when is equal to 0
		if high_score==0:
			pass 
		else:
			check_high_score()
			
		
		# fake endless run
		if $Camera2D.position.x - $Ground.position.x > screen_size.x *1.5:
			$Ground.position.x += screen_size.x
		
		# clean up obstacles are outside camera
		for obs in obstacles:
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)
	else:
		# wait for start state: begin when input
		if Input.is_action_pressed('ui_up') or Input.is_action_pressed('ui_accept'):
			game_running = true
			if _press_play: _press_play.hide()  
			if _jump_hint: _jump_hint.hide()     
			if _crouch_hint: _crouch_hint.hide() 
			
		  
	
func generate_obs():
	# spawn a cluster of ground obstacles when none exist or certain space is met
	if obstacles.is_empty() or last_obs.position.x < score + randi_range(300, 500):
		var obs_type = obstacles_types[randi() % obstacles_types.size()]
		var obs 
		var max_obs = difficulty + 1
		var ground_obs_x_positions: Array = []  # track ground x positions to avoid eagle overlap

		# create 1..max_obs ground obstacles placed just off the right edge
		for i in range(randi() % max_obs + 1):
			obs = obs_type.instantiate()
			var sprite = obs.get_node("Sprite2D")
			var obs_height = sprite.texture.get_height()
			var obs_scale = sprite.scale
			var obs_x = camera.global_position.x + screen_size.x + 100 + (i * 100)
			var obs_y: int = screen_size.y - ground_height - (obs_height * obs_scale.y / 2) + 5
			last_obs = obs
			add_obs(obs, obs_x, obs_y)
			ground_obs_x_positions.append(obs_x)  # remember ground positions for eagle 

		# at max difficulty, optionally add an eagle and put it right until it clears ground obstacles
		if difficulty == MAX_DIFFICULTY:
			if randi() % 2 == 0:
				var eagle_x: float = camera.global_position.x + float(screen_size.x) + 100.0
				var safe = false
				var max_attempts = 10
				var attempt = 0

				while not safe and attempt < max_attempts:
					safe = true
					for x in ground_obs_x_positions:
						if abs(eagle_x - x) < 150:
							safe = false
							eagle_x += 50  # shift eagle right
							break
					attempt += 1

				var eagle = eagle_scene.instantiate()
				var eagle_y: int = screen_size.y - ground_height - eagle_offsets[randi() % eagle_offsets.size()]
				add_obs(eagle, eagle_x, eagle_y)


CHICKEN SCRIPT

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


The rest of the scripts are in the scenes folder.


Snippets of the game

<img width="322" height="195" alt="Screenshot 2025-11-15 at 2 27 13 PM" src="https://github.com/user-attachments/assets/c05c5bc1-86f3-43c5-9eb9-a36a73b17ccd" />
<img width="322" height="195" alt="Screenshot 2025-11-15 at 2 18 30 PM" src="https://github.com/user-attachments/assets/577f2a4a-8165-4b90-b78c-4230b0f82c20" />
<img width="322" height="195
" alt="Screenshot 2025-11-15 at 2 28 49 PM" src="https://github.com/user-attachments/assets/e169aa16-2204-4218-a01d-154b8c91a702" />


Looking forward, I think what the game still needs to feel like a more complete and engaging product is some form of  coin system. That would give the player an extra goal beyond just surviving, and a reason to keep playing to improve their score.

