# Player.gd - Fixed with proper health bar display
extends CharacterBody3D

# Player properties
@export var speed = 10.0
@export var current_health = 100
@export var max_health = 100
var health_bar: Node3D 

# Shooting properties
@export var shoot_range = 50.0
@export var shoot_damage = 5
@export var shoot_cooldown = 0.4
@export var bullet_speed = 15.0

# Rotation speeds
@export var player_rotation_speed = 6.0  # Slow body rotation (radians/sec)
@export var aim_rotation_speed = 10.0    # Fast aim rotation (radians/sec)
@export var stationary_rotation_speed = 4.0  # Rotation speed when stationary towards enemy

# Aim constraint
@export var max_aim_angle = 90.0  # Maximum degrees from PlayerMesh forward
@export var auto_fire_angle = 45.0  # Auto-fire when target is within this angle of AimingDirection

var move_direction = Vector2.ZERO
var joystick_direction = Vector2.ZERO
var shoot_timer = 0.0
var current_target: NPC = null
var alternate_shot = false
var is_stationary = true

# Store last movement direction for persistent rotation
var last_movement_direction = Vector3.FORWARD  # Start facing -Z

# References to nodes
@onready var player_mesh = find_child("PlayerMesh")
@onready var aiming_direction = find_child("AimingDirection") 
@onready var left_gun_point = find_child("LeftGunPoint")
@onready var right_gun_point = find_child("RightGunPoint")

# Target rotations
var target_player_rotation: float = 0.0
var target_aim_rotation: float = 0.0

# Preload bullet scene
var bullet_scene = preload("res://Bullet.tscn")

func _ready():
	setup_camera()
	add_to_group("player")
	call_deferred("connect_touch_controls")
	create_health_bar()

func setup_camera():
	$Camera3D.position = Vector3(0, 15, 5)
	$Camera3D.rotate_x(-75.0)

func connect_touch_controls():
	var touch_controls = get_tree().get_first_node_in_group("touch_controls")
	if touch_controls and touch_controls.has_signal("joystick_moved"):
		touch_controls.joystick_moved.connect(_on_joystick_moved)

func _on_joystick_moved(direction: Vector2):
	joystick_direction = direction

func _physics_process(delta):
	handle_input()
	handle_movement(delta)
	# handle_shooting(delta) Turned off to test NPC attacks
	handle_rotations(delta)
	move_and_slide()

func handle_input():
	var keyboard_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if keyboard_input != Vector2.ZERO:
		move_direction = keyboard_input
	else:
		move_direction = joystick_direction

func handle_movement(delta):
	var move_vector = Vector3(move_direction.x, 0, move_direction.y)
	velocity = move_vector * speed
	
	# Check if player is stationary
	is_stationary = velocity.length_squared() < 0.01
	
	# Update last movement direction when moving
	if not is_stationary:
		last_movement_direction = velocity.normalized() * -1.0
		# Convert to angle for PlayerMesh rotation (always update when moving)
		target_player_rotation = atan2(last_movement_direction.x, last_movement_direction.z)

func handle_rotations(delta):
	# Smoothly rotate player mesh (body) - with null check
	if player_mesh:
		# Determine rotation speed based on whether player is stationary
		var rotation_speed = player_rotation_speed if not is_stationary else stationary_rotation_speed
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, target_player_rotation, rotation_speed * delta)
	
	# Quickly rotate aiming direction - with null check
	if aiming_direction and player_mesh:
		# Clamp the target aim rotation to stay within max_aim_angle from PlayerMesh
		var clamped_aim_rotation = clamp_aim_to_player_forward(target_aim_rotation, player_mesh.rotation.y)
		aiming_direction.rotation.y = lerp_angle(aiming_direction.rotation.y, clamped_aim_rotation, aim_rotation_speed * delta)

func clamp_aim_to_player_forward(aim_angle: float, player_angle: float) -> float:
	# Calculate the difference between aim and player angles
	var angle_diff = wrapf(aim_angle - player_angle, -PI, PI)
	
	# Convert max_aim_angle to radians
	var max_angle_rad = deg_to_rad(max_aim_angle)
	
	# Clamp the difference to stay within the allowed range
	angle_diff = clamp(angle_diff, -max_angle_rad, max_angle_rad)
	
	# Return the clamped angle
	return player_angle + angle_diff

func handle_shooting(delta):
	shoot_timer -= delta
	
	# Find targets differently based on whether we're moving or stationary
	var nearest_enemy: NPC = null
	
	if is_stationary:
		# When stationary, find ANY nearest enemy to rotate towards
		nearest_enemy = find_nearest_enemy()
	else:
		# When moving, only target enemies in front hemisphere
		nearest_enemy = find_nearest_enemy_in_front_hemisphere()
	
	if nearest_enemy:
		# Aim at the enemy
		var direction_to_enemy = (nearest_enemy.global_position - global_position).normalized()
		direction_to_enemy.y = 0
		direction_to_enemy = direction_to_enemy * -1.0
		var desired_aim_rotation = atan2(direction_to_enemy.x, direction_to_enemy.z)
		
		# If stationary, rotate player body towards the target
		if is_stationary:
			target_player_rotation = desired_aim_rotation
		
		# Check if the desired aim is within the allowed range
		if player_mesh:
			var angle_diff = abs(wrapf(desired_aim_rotation - player_mesh.rotation.y, -PI, PI))
			if angle_diff <= deg_to_rad(max_aim_angle):
				# Target is within aim range, aim at it
				target_aim_rotation = desired_aim_rotation
			else:
				# Target is outside aim range, aim at the limit towards the target
				target_aim_rotation = clamp_aim_to_player_forward(desired_aim_rotation, player_mesh.rotation.y)
		else:
			target_aim_rotation = desired_aim_rotation
		
		# Auto-fire if target is within auto_fire_angle of AimingDirection
		if is_target_in_auto_fire_range(nearest_enemy) and shoot_timer <= 0:
			shoot_at_enemy(nearest_enemy)
			shoot_timer = shoot_cooldown
	else:
		# No target found, aim in same direction as body
		target_aim_rotation = target_player_rotation

# Check if target is within auto-fire angle of AimingDirection
func is_target_in_auto_fire_range(target: NPC) -> bool:
	if not aiming_direction or not target:
		return false
	
	# Since we're using inverted rotations, we need -Z as forward
	var aim_forward = -aiming_direction.global_transform.basis.z.normalized()
	aim_forward.y = 0
	aim_forward = aim_forward.normalized()
	
	var direction_to_target = (target.global_position - global_position).normalized()
	direction_to_target.y = 0
	direction_to_target = direction_to_target.normalized()
	
	# Calculate the angle between aim direction and target
	var dot_product = aim_forward.dot(direction_to_target)
	var angle_to_target_rad = acos(clamp(dot_product, -1.0, 1.0))
	var angle_to_target_deg = rad_to_deg(angle_to_target_rad)
	
	# Auto-fire if within the specified angle
	return angle_to_target_deg <= auto_fire_angle

# Find nearest enemy regardless of direction (for stationary rotation)
func find_nearest_enemy() -> NPC:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: NPC = null
	var nearest_dist_sq = shoot_range * shoot_range
	
	for enemy in enemies:
		if enemy is NPC and not enemy.is_dead:
			var direction_to_enemy = (enemy.global_position - global_position)
			direction_to_enemy.y = 0  # Ignore vertical difference
			var dist_sq = direction_to_enemy.length_squared()
			
			if dist_sq < nearest_dist_sq:
				nearest = enemy
				nearest_dist_sq = dist_sq
	
	return nearest

# Find enemies in the front hemisphere of the PlayerMesh
func find_nearest_enemy_in_front_hemisphere() -> NPC:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: NPC = null
	var nearest_dist_sq = shoot_range * shoot_range

	if not player_mesh:
		return null
	
	# Since we're using inverted rotations, we need -Z as forward
	var player_forward = -player_mesh.global_transform.basis.z.normalized()
	player_forward.y = 0  # Ignore vertical component
	player_forward = player_forward.normalized()

	for enemy in enemies:
		if enemy is NPC and not enemy.is_dead:
			var direction_to_enemy = (enemy.global_position - global_position)
			direction_to_enemy.y = 0  # Ignore vertical difference
			var dist_sq = direction_to_enemy.length_squared()

			if dist_sq < nearest_dist_sq:
				var normalized_direction = direction_to_enemy.normalized()
				# Check if enemy is in front hemisphere (dot product > 0)
				if player_forward.dot(normalized_direction) > 0:
					nearest = enemy
					nearest_dist_sq = dist_sq
	
	current_target = nearest
	return nearest

# Check if aiming direction is close enough to target for shooting (legacy function, kept for compatibility)
func is_aiming_at_target(target: NPC) -> bool:
	if not aiming_direction or not target:
		return false
	
	# Since we're using inverted rotations, we need -Z as forward
	var aim_forward = -aiming_direction.global_transform.basis.z.normalized()
	aim_forward.y = 0
	aim_forward = aim_forward.normalized()
	
	var direction_to_target = (target.global_position - global_position).normalized()
	direction_to_target.y = 0
	direction_to_target = direction_to_target.normalized()
	
	# Shoot when aiming within ~30 degrees of target (dot product > 0.866)
	return aim_forward.dot(direction_to_target) > 0.866

func shoot_at_enemy(enemy: NPC):
	if not enemy:
		return
		
	var gun_point = right_gun_point if alternate_shot else left_gun_point
	if not gun_point: 
		return
	
	var bullet_direction = (enemy.global_position - gun_point.global_position).normalized()
	
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = gun_point.global_position
	bullet.setup_bullet(bullet_direction, bullet_speed, shoot_damage, "player")
	
	alternate_shot = !alternate_shot

func create_health_bar():
	var health_bar_scene = preload("res://BillboardHealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.initialize(self, max_health, 3.0, true)  # is_player = true
	
	# Start with health bar hidden since player is at full health
	health_bar.hide_health_bar()

func take_damage(amount: int):
	current_health = max(0, current_health - amount)
	
	# Update health bar
	if health_bar:
		health_bar.update_health(current_health)
	
	print("Player health: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	
	# Update health bar
	if health_bar:
		health_bar.update_health(current_health)
	
	print("Player healed. Health: ", current_health, "/", max_health)

func die():
	print("Player died!")
	# Handle player death logic
