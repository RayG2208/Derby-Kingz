# Main Game Scene Script
extends Node2D

# Game variables
var current_round = 1
var max_rounds = 5
var round_time = 120.0  # 2 minutes in seconds
var time_remaining = round_time
var homeruns_this_round = 0
var total_homeruns = 0
var game_state = "playing"  # playing, round_end, game_over

# Ball mechanics
var current_ball = null
var ball_speed = 800
var pitch_timer = 0.0
var pitch_interval = 3.0  # Time between pitches

# Audio References
@onready var background_music = $BackgroundMusic

# UI References
@onready var ui_layer = $UILayer
@onready var hud = $UILayer/HUD
@onready var round_label = $UILayer/HUD/RoundLabel
@onready var time_label = $UILayer/HUD/TimeLabel
@onready var homerun_label = $UILayer/HUD/HomerunLabel
@onready var total_label = $UILayer/HUD/TotalLabel
@onready var power_bar = $UILayer/HUD/PowerBar
@onready var round_end_panel = $UILayer/RoundEndPanel
@onready var game_over_panel = $UILayer/GameOverPanel

# Player mechanics
var swing_power = 0.0
var is_charging = false
var swing_window = false
var swing_timer = 0.0

# Field elements
@onready var background = $Background
@onready var batter = $Batter
@onready var pitcher_mound = $PitcherMound
@onready var homerun_fence = $HomerunFence

func _ready():
	setup_game()
	setup_audio()
	start_round()

func setup_game():
	# Hide end panels
	round_end_panel.visible = false
	game_over_panel.visible = false
	
	# Initialize UI
	update_ui()

func setup_audio():
	# Load and play background music
	# Replace "res://audio/background_music.ogg" with your actual music file path
	var music_stream = preload("res://music/retro-game-music-245230.mp3")
	# Set up looping BEFORE assigning to player
	if music_stream is AudioStreamOggVorbis:
		music_stream.loop = true
	elif music_stream is AudioStreamMP3:
		music_stream.loop = true
	elif music_stream is AudioStreamWAV:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	background_music.stream = music_stream
	background_music.volume_db = -10  # Adjust volume (negative values make it quieter)
	background_music.autoplay = true
	background_music.play()  # Explicitly start playing

func start_round():
	time_remaining = round_time
	homeruns_this_round = 0
	game_state = "playing"
	pitch_timer = 0.0
	update_ui()

func _process(delta):
	if game_state == "playing":
		# Update timers
		time_remaining -= delta
		pitch_timer += delta
		
		# Handle pitching
		if pitch_timer >= pitch_interval and current_ball == null:
			pitch_ball()
			pitch_timer = 0.0
		
		# Handle player input
		handle_input(delta)
		
		# Update UI
		update_ui()
		
		# Check round end
		if time_remaining <= 0:
			end_round()

func handle_input(delta):
	# Charging swing power
	if Input.is_action_pressed("swing") and not is_charging and current_ball != null:
		is_charging = true
		swing_power = 0.0
	
	if is_charging:
		swing_power = min(swing_power + delta * 2.0, 1.0)  # Charge up to 100%
		power_bar.value = swing_power * 100
	
	# Release swing
	if Input.is_action_just_released("swing") and is_charging:
		swing_bat()
		is_charging = false
		power_bar.value = 0
	
	# Optional: Toggle music with M key
	if Input.is_action_just_pressed("toggle_music"):
		toggle_music()

func toggle_music():
	if background_music.playing:
		background_music.stop()
	else:
		background_music.play()

func pitch_ball():
	if current_ball != null:
		current_ball.queue_free()
	
	# Create new ball
	current_ball = RigidBody2D.new()
	current_ball.position = pitcher_mound.position
	
	# Add ball sprite
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	texture.set_image(image)
	sprite.texture = texture
	current_ball.add_child(sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	current_ball.add_child(collision)
	
	# Set physics properties (top-down view)
	current_ball.gravity_scale = 0  # No gravity for top-down
	current_ball.linear_velocity = Vector2(0, ball_speed)  # Ball moves toward batter
	
	add_child(current_ball)
	
	# Connect collision signal
	current_ball.body_entered.connect(_on_ball_collision)

func swing_bat():
	if current_ball == null:
		return
	
	# Check if ball is in swing range
	var ball_pos = current_ball.position
	var batter_pos = batter.position
	var distance = ball_pos.distance_to(batter_pos)
	
	if distance < 80:  # Swing range
		hit_ball()
	else:
		# Miss - reset for next pitch
		current_ball.queue_free()
		current_ball = null

func hit_ball():
	if current_ball == null:
		return
	
	# Calculate hit power and angle based on swing power (top-down)
	var hit_force = swing_power * 1200 + 400
	var angle = -90 + (randf() - 0.5) * 60  # Hit toward outfield with variation
	
	# Apply force to ball
	var force_vector = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle))) * hit_force
	current_ball.linear_velocity = force_vector
	current_ball.gravity_scale = 0  # Keep no gravity for top-down
	
	# Reset swing power
	swing_power = 0.0
	
	# Start a timer to check for homerun
	var homerun_timer = Timer.new()
	add_child(homerun_timer)
	homerun_timer.wait_time = 2.0
	homerun_timer.one_shot = true
	homerun_timer.timeout.connect(check_homerun)
	homerun_timer.start()
	
func check_homerun():
	if current_ball == null:
		return
	
	# Check if ball passed homerun fence (top-down view)
	if current_ball.position.y < homerun_fence.position.y:
		score_homerun()

func score_homerun():
	homeruns_this_round += 1
	total_homeruns += 1
	
	# Visual feedback
	show_homerun_text()
	
	# Clean up ball
	if current_ball != null:
		current_ball.queue_free()
		current_ball = null

func show_homerun_text():
	var homerun_font = preload("res://fonts/arcadeclassic/ARCADECLASSIC.TTF")
	var homerun_text = Label.new()
	homerun_text.text = "HOME RUN!"
	homerun_text.position = Vector2(540, 260)
	homerun_text.add_theme_font_override("font", homerun_font)
	homerun_text.add_theme_font_size_override("font_size", 48)
	homerun_text.add_theme_color_override("font_color", Color.YELLOW)
	add_child(homerun_text)
	
	# Animate and remove
	var tween = create_tween()
	tween.tween_property(homerun_text, "modulate:a", 0.0, 2.0)
	tween.tween_callback(homerun_text.queue_free)

func _on_ball_collision(_body):
	# Handle ball hitting ground or going out of bounds
	if current_ball != null and current_ball.position.y > 500:
		current_ball.queue_free()
		current_ball = null

func update_ui():
	round_label.text = "Round: " + str(current_round) + "/" + str(max_rounds)
	time_label.text = "Time: " + str(int(time_remaining))
	homerun_label.text = "Home Runs: " + str(homeruns_this_round)
	total_label.text = "Total: " + str(total_homeruns)

func end_round():
	game_state = "round_end"
	
	# Clean up current ball
	if current_ball != null:
		current_ball.queue_free()
		current_ball = null
	
	# Show round end panel
	round_end_panel.visible = true
	var round_end_label = round_end_panel.get_node("RoundEndLabel")
	var round_stats = round_end_panel.get_node("RoundStats")
	
	round_end_label.text = "Round " + str(current_round) + " Complete!"
	round_stats.text = "Home Runs This Round: " + str(homeruns_this_round) + "\nTotal Home Runs: " + str(total_homeruns)
	
	# Auto-advance after 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	if current_round < max_rounds:
		next_round()
	else:
		end_game()

func next_round():
	current_round += 1
	round_end_panel.visible = false
	start_round()

func end_game():
	game_state = "game_over"
	round_end_panel.visible = false
	game_over_panel.visible = true
	
	# Optional: Change music for game over
	# background_music.stop()
	# play_game_over_music()
	
	var final_score = game_over_panel.get_node("FinalScore")
	var performance = game_over_panel.get_node("Performance")
	
	final_score.text = "Final Score: " + str(total_homeruns) + " Home Runs"
	
	# Performance rating
	var rating = ""
	if total_homeruns >= 50:
		rating = "LEGENDARY!"
	elif total_homeruns >= 30:
		rating = "EXCELLENT!"
	elif total_homeruns >= 20:
		rating = "GREAT!"
	elif total_homeruns >= 10:
		rating = "GOOD!"
	else:
		rating = "KEEP PRACTICING!"
	
	performance.text = rating

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	get_tree().quit()

# Scene structure setup function (call this in editor or create scenes manually)
func setup_scene_structure():
	# This function shows the scene structure you need to create
	# Main Scene (Node2D)
	# ├── BackgroundMusic (AudioStreamPlayer)  # NEW
	# ├── Batter (Sprite2D)
	# ├── PitcherMound (Sprite2D)  
	# ├── HomerunFence (Sprite2D)
	# └── UILayer (CanvasLayer)
	#     ├── HUD (Control)
	#     │   ├── RoundLabel (Label)
	#     │   ├── TimeLabel (Label)
	#     │   ├── HomerunLabel (Label)
	#     │   ├── TotalLabel (Label)
	#     │   └── PowerBar (ProgressBar)
	#     ├── RoundEndPanel (Panel)
	#     │   ├── RoundEndLabel (Label)
	#     │   └── RoundStats (Label)
	#     └── GameOverPanel (Panel)
	#         ├── FinalScore (Label)
	#         ├── Performance (Label)
	#         ├── RestartButton (Button)
	#         └── QuitButton (Button)
	pass
