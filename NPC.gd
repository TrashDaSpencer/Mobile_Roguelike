# NPC.gd - Fixed with proper experience awarding
extends CharacterBody3D
class_name NPC

signal npc_died
signal died

# Basic stats
@export var health = 50
@export var max_health = 50
@export var move_speed = 2.0
@export var coin_drop_amount = 10
@export var exp_drop_amount = 25

# Combat stats
@export var attack_damage = 15
@export var melee_attack_range = 3.0
@export var range_attack_range = 13.0
@export var attack_cooldown = 1.5
@export var detection_range = 30.0

# NPC type and behavior
enum NPCType { MELEE, RANGED_AGGRESSIVE, RANGED_DEFENSIVE, BOSS }
enum MeleeAttackType { SWEEP, STAB, KICK }

@export var npc_type: NPCType = NPCType.MELEE
@export var melee_attack_type: MeleeAttackType = MeleeAttackType.SWEEP
@export var is_boss: bool = false

# State management
enum NPCState { IDLE, MOVING, ATTACKING, COOLDOWN }
var current_state: NPCState = NPCState.IDLE

# References
var player: CharacterBody3D
var health_bar: Node3D
var is_dead = false

# Combat variables
var last_attack_time = 0.0
var attack_delay_timer = 0.0
var can_attack = true

# Movement variables
var target_position: Vector3
var rotation_speed = 5.0
var min_distance_defensive = 4.0  # For defensive ranged NPCs

# Drop chances
@export var item_drop_chance = 0.3
@export var health_drop_chance = 0.4

func _ready():
	print("NPC spawned - Type: ", NPCType.keys()[npc_type], ", Boss: ", is_boss)
	print("Stats - Health: ", max_health, ", Damage: ", attack_damage, ", Exp: ", exp_drop_amount, ", Coins: ", coin_drop_amount)
	
	# Apply boss visual modifiers (scaling is handled by factory)
	if is_boss:
		apply_boss_visual_modifiers()
	
	# Find player
	find_player()
	
	# Setup appearance and health bar
	setup_appearance()
	create_health_bar()
	
	# Set initial state
	current_state = NPCState.IDLE

func apply_boss_visual_modifiers():
	# Boss visual effects only (stats are handled by factory)
	scale = Vector3(2.0, 2.0, 2.0)

func find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Main/Player")
	
	if player:
		print("NPC found player: ", player.name)
	else:
		print("Warning: NPC could not find player!")

func setup_appearance():
	var mesh_instance = get_node_or_null("NPCMesh")
	if not mesh_instance:
		return
	
	var material = StandardMaterial3D.new()
	
	# Color based on type and boss status
	if is_boss:
		# Boss colors (darker versions)
		match npc_type:
			NPCType.MELEE:
				material.albedo_color = Color(0.5, 0.0, 0.0)  # Dark red
			NPCType.RANGED_AGGRESSIVE:
				material.albedo_color = Color(0.0, 0.0, 0.5)  # Dark blue
			NPCType.RANGED_DEFENSIVE:
				material.albedo_color = Color(0.5, 0.5, 0.0)  # Dark yellow
		
		# Add boss glow effect
		material.emission = material.albedo_color * 0.3
	else:
		# Regular NPC colors (lighter versions)
		match npc_type:
			NPCType.MELEE:
				material.albedo_color = Color(1.0, 0.5, 0.5)  # Light red
			NPCType.RANGED_AGGRESSIVE:
				material.albedo_color = Color(0.5, 0.5, 1.0)  # Light blue
			NPCType.RANGED_DEFENSIVE:
				material.albedo_color = Color(1.0, 1.0, 0.5)  # Light yellow
	
	mesh_instance.set_surface_override_material(0, material)

func create_health_bar():
	var health_bar_scene = preload("res://BillboardHealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.initialize(self, max_health, 2.5, false)  # is_player = false		

func _physics_process(delta):
	if is_dead or not player:
		return
	
	update_timers(delta)
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if player is in detection range
	if distance_to_player > detection_range:
		current_state = NPCState.IDLE
		return
	
	# Handle behavior based on NPC type
	match npc_type:
		NPCType.MELEE:
			handle_melee_behavior(delta, distance_to_player)
		NPCType.RANGED_AGGRESSIVE:
			handle_ranged_aggressive_behavior(delta, distance_to_player)
		NPCType.RANGED_DEFENSIVE:
			handle_ranged_defensive_behavior(delta, distance_to_player)

func update_timers(delta):
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
		if attack_delay_timer <= 0:
			can_attack = true
			if current_state == NPCState.COOLDOWN:
				current_state = NPCState.IDLE

func handle_melee_behavior(delta, distance_to_player):
	if current_state == NPCState.ATTACKING or current_state == NPCState.COOLDOWN:
		return
	
	if distance_to_player <= melee_attack_range and can_attack:
		# In attack range - face player and attack
		rotate_towards_player(delta)
		perform_melee_attack()
	elif distance_to_player <= melee_attack_range * 1.1:
		# Close to attack range - face player but don't move
		rotate_towards_player(delta)
		# current_state = NPCState.IDLE
	else:
		# Too far - move toward player
		move_toward_player(delta)

func handle_ranged_aggressive_behavior(delta, distance_to_player):
	if current_state == NPCState.ATTACKING or current_state == NPCState.COOLDOWN:
		return
	
	var ideal_range = range_attack_range * 0.8  # Stay slightly back from max range
	
	if distance_to_player <= range_attack_range and can_attack:
		# In attack range - attack
		rotate_towards_player(delta)
		perform_ranged_attack()
	elif distance_to_player > ideal_range:
		# Too far - move closer
		move_toward_player(delta)
	else:
		# In good position - just face player
		rotate_towards_player(delta)
		current_state = NPCState.IDLE

func handle_ranged_defensive_behavior(delta, distance_to_player):
	if current_state == NPCState.ATTACKING or current_state == NPCState.COOLDOWN:
		return
	
	if distance_to_player < min_distance_defensive:
		# Too close - back away
		move_away_from_player(delta)
	elif distance_to_player <= range_attack_range and distance_to_player >= min_distance_defensive and can_attack:
		# Perfect range - attack
		rotate_towards_player(delta)
		perform_ranged_attack()
	elif distance_to_player > range_attack_range:
		# Too far - move closer but maintain minimum distance
		var target_distance = (range_attack_range + min_distance_defensive) / 2
		if distance_to_player > target_distance:
			move_toward_player(delta)
		else:
			rotate_towards_player(delta)
			current_state = NPCState.IDLE

func move_toward_player(delta):
	current_state = NPCState.MOVING
	var direction = (player.global_position - global_position).normalized()
	velocity = Vector3(direction.x, 0, direction.z) * move_speed
	
	# Rotate towards movement direction
	rotate_towards_direction(direction, delta)
	move_and_slide()

func move_away_from_player(delta):
	current_state = NPCState.MOVING
	var direction = (global_position - player.global_position).normalized()
	velocity = Vector3(direction.x, 0, direction.z) * move_speed
	
	# Rotate towards movement direction
	rotate_towards_direction(direction, delta)
	
	move_and_slide()

func rotate_towards_player(delta):
	var direction = (player.global_position - global_position).normalized()
	rotate_towards_direction(direction, delta)

func rotate_towards_direction(direction: Vector3, delta):
	if direction.length() > 0:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func perform_melee_attack():
	if not can_attack:
		return
	
	print("NPC performing melee attack: ", MeleeAttackType.keys()[melee_attack_type])
	current_state = NPCState.ATTACKING
	can_attack = false
	attack_delay_timer = attack_cooldown
	
	# Check if player is still in range and deal damage
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= melee_attack_range:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			print("Player hit for ", attack_damage, " damage!")
	
	# Different attack animations could be triggered here based on melee_attack_type
	match melee_attack_type:
		MeleeAttackType.SWEEP:
			# TODO: Play sweep animation
			pass
		MeleeAttackType.STAB:
			# TODO: Play stab animation
			pass
		MeleeAttackType.KICK:
			# TODO: Play kick animation
			pass
	
	current_state = NPCState.COOLDOWN

func perform_ranged_attack():
	if not can_attack:
		return
	
	print("NPC performing ranged attack")
	current_state = NPCState.ATTACKING
	can_attack = false
	attack_delay_timer = attack_cooldown
	
	# Create projectile or instant hit
	fire_projectile()
	
	current_state = NPCState.COOLDOWN

func fire_projectile():
	# Create and fire an actual bullet projectile
	var bullet_scene = preload("res://Bullet.tscn")  # Adjust path as needed
	var bullet = bullet_scene.instantiate()
	
	# Add bullet to the scene
	get_tree().current_scene.add_child(bullet)
	
	# Calculate direction to player
	var direction_to_player = (player.global_position - global_position).normalized()
	
	# Position bullet at NPC location (or at a gun point if you have one)
	bullet.global_position = global_position + Vector3(0, 1, 0) + direction_to_player # Slightly above NPC
	
	# Setup the bullet
	bullet.setup_bullet(direction_to_player, 10.0, attack_damage, "enemy")
	
	print("NPC fired projectile at player!")
	
func take_damage(amount):
	if is_dead:
		return
	
	print("NPC took ", amount, " damage. Health: ", health, " -> ", health - amount)
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	
	if health <= 0:
		die()

func die():
	if is_dead:
		return
	
	print("NPC dying...")
	is_dead = true
	
	# Hide health bar
	if health_bar:
		health_bar.queue_free()
	
	drop_items()
	
	# Award experience to player through GameManager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		# Try alternative paths
		game_manager = get_node_or_null("/root/Main/GameManager")
	
	if game_manager and game_manager.has_method("add_experience"):
		game_manager.add_experience(exp_drop_amount)
		print("Awarded ", exp_drop_amount, " experience through GameManager")
	else:
		print("Warning: GameManager not found for experience awarding")
	
	# Emit both signals for compatibility
	npc_died.emit()
	died.emit()
	
	print("NPC death signals emitted")
	queue_free()

func is_alive() -> bool:
	return not is_dead and health > 0

func drop_items():
	var drops = []
	
	# Always drop coins and exp
	drops.append({"type": "coin", "amount": coin_drop_amount})
	drops.append({"type": "exp", "amount": exp_drop_amount})
	
	# Chance for health drop
	if randf() < health_drop_chance:
		drops.append({"type": "health", "amount": 25})
	
	# Chance for item drop
	if randf() < item_drop_chance:
		drops.append({"type": "item", "item_id": "basic_weapon"})
	
	# Create actual drop objects
	for drop in drops:
		create_drop(drop)

func create_drop(drop_data):
	# For now, just print what would be dropped
	print("Would drop: ", drop_data)
	# Later: create actual drop scenes
