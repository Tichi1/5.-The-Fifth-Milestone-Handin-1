extends Node


# i preloaded the scenes to refer them easier
var barrel_scene = preload("res://scenes/barrel.tscn")
var wolf_scene = preload("res://scenes/wolf.tscn")
const COIN_SCENE := preload("res://scenes/coin.tscn")  
var eagle_scene = preload("res://scenes/eagle.tscn")
const MEAT_SCENE := preload("res://scenes/meat.tscn")
var obstacles_types := [barrel_scene, wolf_scene]
var obstacles: Array = []
var eagle_offsets := [120,200]


# this helps me to disappear object when eagles appears
var eagle_active: bool = false
var current_eagle: Node = null

# variables 
const CHICKEN_START_POS := Vector2i(150,285)
const CAM_START_POS := Vector2i(576,324)
var difficulty
var MAX_DIFFICULTY:int = 1
var score: int
const SCORE_MODIFIER : int = 10
var bonus_score: int = 0  # helps me with the hud score when chicken eats meat
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

@onready var chicken := $Chicken
@onready var coin_timer := $CoinTimer  # for random coins

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
	# make randomness work for coins and obstacles
	randomize()
	
	# cache screen/ground metrics and restart
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node('Button').pressed.connect(new_game)

	# init HUD values safely
	if _high_label:
		_high_label.text = 'HIGH SCORE: ' + str((high_score if high_score > 0 else 0) / SCORE_MODIFIER)
	if _new_high_label:
		_new_high_label.visible = false

	# start the coin timer (only when game running)
	coin_timer.start()
	
	new_game()
	
func new_game():
	
	# reset variables -  unpause -  start at easiest difficulty
	score = 0
	bonus_score = 0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	
	# remove old obstacles whenever we start a new game
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	eagle_active = false
	current_eagle = null
	last_obs = null  

	
	# put positions back 
	$Chicken.position = CHICKEN_START_POS
	$Chicken.velocity = Vector2i(0,0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0,0)
	

	
	# show prompt to start and hide game over ui
	if _press_play: _press_play.show()     
	if _jump_hint: _jump_hint.show()      
	if _crouch_hint: _crouch_hint.show()  

	$GameOver.hide() # show restart only when lose

	# reset popup and refresh high text
	_new_high_shown = false
	if _new_high_label: _new_high_label.visible = false
	if _high_label:
		_high_label.text = 'HIGH SCORE: ' + str(high_score)


func _process(delta):

	if game_running:
		# increase speed, update difficulty and generate obstacles
		speed = START_SPEED + score / SPEED_MODIFIFER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		adjust_difficulty()
		generate_obs()
		
		# scroll world and accumulate speed 
		$Chicken.position.x += speed
		$Camera2D.position.x += speed
		score += speed
		show_score()  # show score when playing
		
		check_high_score()  # message for new record
		
		# if eagle is active and has reached the screen, clear other obstacles
		if eagle_active and current_eagle != null:
			# has the eagle been deleted?
			if not is_instance_valid(current_eagle):
				eagle_active = false # clean eagle
				current_eagle = null
			else:
				# set position of eagle
				var eagle_screen_x = current_eagle.position.x
				var camera_left = $Camera2D.position.x - screen_size.x * 0.5
				var camera_right = $Camera2D.position.x + screen_size.x * 0.5

				# when eagle in camera view, remove all the obstacles
				if eagle_screen_x > camera_left and eagle_screen_x < camera_right:
					for obs in obstacles.duplicate():
						if obs != current_eagle:
							remove_obs(obs)
		
		# fake endless run
		if $Camera2D.position.x - $Ground.position.x > screen_size.x *1.5:
			$Ground.position.x += screen_size.x
		
		# clean up obstacles that are outside camer
		for obs in obstacles.duplicate():
			if not is_instance_valid(obs):
				obstacles.erase(obs)
				continue
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)


	else:
		# wait for start state - input
		if Input.is_action_pressed('ui_up') or Input.is_action_pressed('ui_accept'):
			game_running = true
			if _press_play: _press_play.hide()  
			if _jump_hint: _jump_hint.hide()     
			if _crouch_hint: _crouch_hint.hide() 
			
		  
	
func generate_obs():
	# if an eagle is currently on screen, don't spawn more obstacles
	if eagle_active:
		return

	# spawn a cluster of ground obstacles when none exist or certain space is met
	if obstacles.is_empty() or last_obs == null or not is_instance_valid(last_obs) \
		or last_obs.position.x < score + randi_range(300, 500):
		# decide first if we will spawn an eagle instead of ground obstacles
		var spawn_eagle: bool = (difficulty == MAX_DIFFICULTY and randi() % 2 == 0)

		var obs_type = obstacles_types[randi() % obstacles_types.size()]
		var obs
		var max_obs = difficulty + 1
		var ground_obs_x_positions: Array = []  # track ground x positions - helps woth eagle

		# only create ground obstacles if we are not spamming eagles
		if not spawn_eagle:
			# create 1..max_obs ground obstacles placed
			for i in range(randi() % max_obs + 1):
				obs = obs_type.instantiate()
				var sprite = obs.get_node("Sprite2D")
				var obs_height = sprite.texture.get_height() # get heights
				var obs_scale = sprite.scale
				var obs_x = camera.global_position.x + screen_size.x + 100 + (i * 100) # position on the right
				var obs_y: int = screen_size.y - ground_height - (obs_height * obs_scale.y / 2) + 5 # floor
				last_obs = obs
				add_obs(obs, obs_x, obs_y)
				ground_obs_x_positions.append(obs_x)  # remember ground positions for eagle 

		# at max difficulty, optionally add an eagle
		if spawn_eagle:
			var eagle_x: float = camera.global_position.x + float(screen_size.x) + 100.0
			var safe = false # spots where the eagle can be placed
			var max_attempts = 10
			var attempt = 0

			while not safe and attempt < max_attempts:
				safe = true
				for x in ground_obs_x_positions:
					if abs(eagle_x - x) < 150: # if eagle too close to ground obstacles
						safe = false # dont make it appear
						eagle_x += 50  # shift eagle right
						break
				attempt += 1

			var eagle = eagle_scene.instantiate()# Instantiates the eagle
			# y position
			var eagle_y: int = screen_size.y - ground_height - eagle_offsets[randi() % eagle_offsets.size()]
			add_obs(eagle, eagle_x, eagle_y) # add to scene

			# mark eagle as active (obstacles will clear)
			current_eagle = eagle
			eagle_active = true



		
func add_obs(obs,x,y):
	# place obstacle, 
	obs.position = Vector2i(x,y)
	obs.body_entered.connect(hit_obs) 
	add_child(obs)
	obstacles.append(obs)  # add to obstacles arr

func remove_obs(obs):
	# erase obstacles
	if obs == current_eagle:
		eagle_active = false
		current_eagle = null
	if obs == last_obs:            
		last_obs = null
	obs.queue_free()
	obstacles.erase(obs)

	
func hit_obs(body):
	# collisions with the chicken end the run
	if body.name == 'Chicken':
		game_over()

func show_score(): # show score
	if _score_label:
		_score_label.text = 'SCORE: ' + str(get_current_points()) 


	
func check_high_score():
	var current_points := get_current_points()

	if current_points > high_score: # update highest
		high_score = current_points

		if _high_label: # update the hud label
			_high_label.text = 'HIGH SCORE: ' + str(high_score)
		
		if not _new_high_shown: # check if new score
			_new_high_shown = true
			_show_new_high_popup()


	


func adjust_difficulty():
	# modify diff
	difficulty = score /SPEED_MODIFIFER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY 

func game_over():
	# record high score, pause, and show restart ui
	check_high_score()
	get_tree().paused = true
	game_running  = false
	$GameOver.show() # show game over hud

# set function for new high score
func _show_new_high_popup() -> void:
	# make sure the label is visible, i unchecked the visible feature
	_new_high_label.visible = true
	# set its transparency to 0  before starting the fade
	_new_high_label.modulate.a = 0.0
	# move it slightly down so it will float later
	_new_high_label.position.y += 12
	# create a new tween to animate the label
	var t := create_tween()
	# fade the label in from invisible to fully visible over 0.35 seconds
	t.tween_property(_new_high_label, "modulate:a", 1.0, 0.35)
	# move label 20 pixels for smoothness
	t.parallel().tween_property(_new_high_label, "position:y", _new_high_label.position.y - 20, 0.35)
	# wait a second till fades
	t.tween_interval(1)
	# wait until the tween finishes
	await t.finished
	_new_high_label.visible = false # hide label


func _on_coin_timer_timeout() -> void:
	#called every x seconds by node CoinTimer in main
	if game_running:
		spawn_coin()


# function to spawn coins
func spawn_coin() -> void:
	var coin := COIN_SCENE.instantiate() 
	add_child(coin)

	# spawn a bit ahead of the camera
	var x_offset: float = float(screen_size.x) + 150.0
	var x_pos: float = float(camera.global_position.x) + x_offset

	# random height 
	var min_y: float = float(chicken.position.y) - 40
	var max_y: float = float(chicken.position.y) - 15
	var y_pos: float = randf_range(min_y, max_y)

	coin.position = Vector2(x_pos, y_pos)



func _on_score_collectable_timer_timeout() -> void:
	if game_running: # spawn meat if running
		spawn_meat()

func spawn_meat() -> void:
	# same as coin but with the meat
	var meat = MEAT_SCENE.instantiate() 
	add_child(meat)

	# spawn farther than the coin
	var x_offset: float = float(screen_size.x) + 300.0
	var x_pos: float = float(camera.global_position.x) + x_offset

	# spawn different than the coin range
	var min_y: float = float(chicken.position.y) - 160.0
	var max_y: float = float(chicken.position.y) - 120.0
	var y_pos: float = randf_range(min_y, max_y)

	meat.position = Vector2(x_pos, y_pos)
	
func add_score_from_meat(amount: int) -> void:
	# amount is directly how many points the HUD should go up
	bonus_score += amount
	show_score()

func get_current_points() -> int: # fucntion to get the current points, used in show score
	var distance_points: int = int(score / SCORE_MODIFIER)
	var shown_score: int = distance_points + bonus_score
	return shown_score
