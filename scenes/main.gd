extends Node

# preload obstacle scenes and keep simple lists 
var barrel_scene = preload("res://scenes/barrel.tscn")
var wolf_scene = preload("res://scenes/wolf.tscn")
var eagle_scene = preload("res://scenes/eagle.tscn")
var obstacles_types := [barrel_scene, wolf_scene]
var obstacles: Array
var eagle_offsets := [120,200]

# variables (positions, difficulty, speed, scoring)
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
		
func add_obs(obs,x,y):
	# place obstacle, connect hit callback, add to scene and tracking list
	obs.position = Vector2i(x,y)
	obs.body_entered.connect(hit_obs) 
	add_child(obs)
	obstacles.append(obs) 

func remove_obs(obs):
	# erase obstacles
	obs.queue_free()
	obstacles.erase(obs)
	
func hit_obs(body):
	# collisions with the chicken end the run
	if body.name == 'Chicken':
		game_over()

func show_score(): 
	# push scaled score to the hud
	if _score_label:
		_score_label.text = 'SCORE: ' + str(score / SCORE_MODIFIER)
	
func check_high_score():
	# update and display high score when beaten
	if score > high_score:
		high_score = score
		if _high_label:
			_high_label.text = 'HIGH SCORE: ' + str(score / SCORE_MODIFIER)

		# show popup once per run
		if not _new_high_shown:
			_new_high_shown = true
			_show_new_high_popup()

func adjust_difficulty():
	# map score to difficulty tier and clamp to max
	difficulty = score /SPEED_MODIFIFER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY 

func game_over():
	# record high score, pause, and show restart ui
	check_high_score()
	get_tree().paused = true
	game_running  = false
	$GameOver.show()

# set function for new high score
func _show_new_high_popup() -> void:
	# check if the label exists -  if not, print a message and stop
	if _new_high_label == null:
		print("NewHighScore label not found under HUD")
		return

	# make sure the label is visible, i unchecked the visible feature
	_new_high_label.visible = true

	# set its transparency to 0  before starting the fade
	_new_high_label.modulate.a = 0.0
	
	# move it slightly down so it will float upward later
	_new_high_label.position.y += 12

	# create a new tween to animate the label
	var t := create_tween()

	# fade the label in from invisible to fully visible over 0.35 seconds
	t.tween_property(_new_high_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)

	# at the same time, move the label up by 20 pixels for a smooth floating effect
	t.parallel().tween_property(_new_high_label, "position:y", _new_high_label.position.y - 20, 0.35)

	# wait half a second while it stays fully visible before fading out
	t.tween_interval(0.5)

	# fade the label out again (alpha 1 → 0) over 0.6 seconds
	t.tween_property(_new_high_label, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

	# wait until the tween finishes, then hide the label
	await t.finished
	_new_high_label.visible = false
