# GameManager.gd - Fixed with experience system integration
extends Node3D

var current_level_scene: Node3D
var current_level_number = 1
var player: CharacterBody3D
var experience_system: Control  # Reference to the experience bar
var boss_ui_health: Control  # Reference to the boss UI health bar

func _ready():
	print("=== GAME MANAGER INITIALIZING ===")
	# Add GameManager to group for easy finding by NPCs
	add_to_group("game_manager")
	
	# Find the player in the main scene
	player = get_node("../Player") # Adjust path as needed
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("Player found: ", player.name)
	else:
		print("Warning: Player not found!")
	
	# Find or create experience system
	setup_experience_system()
	
	# Find or create boss UI health bar
	setup_boss_ui_health()
	
	await load_level(current_level_number)

func setup_experience_system():
	# Try to find existing experience bar
	experience_system = get_tree().get_first_node_in_group("experience_bar")
	
	if not experience_system:
		# Create experience bar if it doesn't exist
		var experience_bar_scene = preload("res://ExperienceBar.gd")  # Adjust path as needed
		experience_system = Control.new()
		experience_system.set_script(experience_bar_scene)
		experience_system.add_to_group("experience_bar")
		
		# Add to the main scene's UI layer
		var main_scene = get_tree().current_scene
		if main_scene.has_node("UI"):
			main_scene.get_node("UI").add_child(experience_system)
		else:
			# Create UI layer if it doesn't exist
			var ui_layer = CanvasLayer.new()
			ui_layer.name = "UI"
			main_scene.add_child(ui_layer)
			ui_layer.add_child(experience_system)
		
		print("Experience system created and added to scene")
	else:
		print("Experience system found: ", experience_system.name)

func setup_boss_ui_health():
	# Try to find existing boss UI health bar
	boss_ui_health = get_tree().get_first_node_in_group("boss_ui_health")
	
	if not boss_ui_health:
		# Create boss UI health bar if it doesn't exist
		var boss_health_bar_scene = preload("res://BossUIHealthBar.gd")  # Adjust path as needed
		boss_ui_health = Control.new()
		boss_ui_health.set_script(boss_health_bar_scene)
		boss_ui_health.add_to_group("boss_ui_health")
		
		# Add to the main scene's UI layer
		var main_scene = get_tree().current_scene
		if main_scene.has_node("UI"):
			main_scene.get_node("UI").add_child(boss_ui_health)
		else:
			# Create UI layer if it doesn't exist
			var ui_layer = CanvasLayer.new()
			ui_layer.name = "UI"
			main_scene.add_child(ui_layer)
			ui_layer.add_child(boss_ui_health)
		
		print("Boss UI health bar created and added to scene")
	else:
		print("Boss UI health bar found: ", boss_ui_health.name)

func add_experience(amount: int):
	# Public method for NPCs to call when they die
	if experience_system and experience_system.has_method("add_experience"):
		experience_system.add_experience(amount)
		print("GameManager: Added ", amount, " experience to player")
	else:
		print("Warning: Experience system not found or doesn't have add_experience method")

func load_level(_level_number: int):
	print("=== LOADING LEVEL ", _level_number, " ===")
	var is_boss_level = (_level_number % 10 == 0)
	print("*** BOSS LEVEL ***" if is_boss_level else "Regular Level")
	
	# Safety check
	if not is_inside_tree():
		print("GameManager not in tree - cannot load level")
		return
	
	var tree = get_tree()
	if not tree:
		print("Scene tree is null - cannot load level")
		return
	
	# Remove current level if it exists
	if current_level_scene:
		print("Removing previous level...")
		if is_instance_valid(current_level_scene):
			remove_child(current_level_scene)
			current_level_scene.queue_free()
		current_level_scene = null
	
	# Wait one frame to ensure cleanup
	await tree.process_frame
	
	# Load new level (for now, just use the same scene)
	var level_scene = preload("res://Level.tscn")
	current_level_scene = level_scene.instantiate()
	current_level_scene.name = "CurrentLevel"
	add_child(current_level_scene)
	
	# Set level number for difficulty scaling
	if current_level_scene.has_method("set_level_number"):
		current_level_scene.set_level_number(_level_number)
	
	print("Level instantiated: ", current_level_scene.name)
	
	# Connect level signals
	if current_level_scene.has_signal("all_npcs_defeated"):
		current_level_scene.all_npcs_defeated.connect(_on_all_npcs_defeated)
		print("Connected to all_npcs_defeated signal")
	else:
		print("Warning: Level doesn't have all_npcs_defeated signal")
		
	if current_level_scene.has_signal("exit_reached"):
		current_level_scene.exit_reached.connect(_on_exit_reached)
		print("Connected to exit_reached signal")
	else:
		print("Warning: Level doesn't have exit_reached signal")
	
	# Position and orient player at spawn point
	setup_player_spawn()
	
	# Setup boss UI if this is a boss level
	setup_boss_level_ui()
	
	print("Level ", _level_number, " loaded successfully")
	print("================================")

func setup_player_spawn():
	if not player or not current_level_scene:
		print("Cannot setup player spawn - missing player or level")
		return
	
	var spawn_point = current_level_scene.get_node_or_null("SpawnPoints/PlayerSpawn")
	if not spawn_point:
		# Try alternative paths
		var spawn_points = current_level_scene.find_child("SpawnPoints", true, false)
		if spawn_points:
			spawn_point = spawn_points.get_node_or_null("PlayerSpawn")
	
	var exit_door = current_level_scene.find_child("ExitDoor", true, false)
	
	if spawn_point:
		player.global_position = spawn_point.global_position
		print("Player positioned at spawn point: ", spawn_point.global_position)
		
		# Make player face the exit door
		if exit_door:
			var direction = (exit_door.global_position - player.global_position).normalized()
			# Remove Y component to only rotate on horizontal plane
			direction.y = 0
			direction = direction.normalized()
			
			if direction.length() > 0:
				player.look_at(player.global_position + direction, Vector3.UP)
				print("Player oriented toward exit door")
		else:
			print("Warning: Exit door not found for player orientation")
	else:
		print("Warning: PlayerSpawn not found - player position not set")

func setup_boss_level_ui():
	var is_boss_level = (current_level_number % 10 == 0)
	
	if is_boss_level and boss_ui_health:
		# Find the boss in the current level
		await get_tree().process_frame  # Wait for NPCs to spawn
		var bosses = []
		if current_level_scene:
			var npc_container = current_level_scene.find_child("NPCContainer", true, false)
			if npc_container:
				for child in npc_container.get_children():
					if child is NPC and child.is_boss:
						bosses.append(child)
		
		if bosses.size() > 0:
			var boss = bosses[0]  # Use first boss found
			if boss_ui_health.has_method("show_boss_health"):
				boss_ui_health.show_boss_health(boss)
				print("Boss UI health bar activated for boss")
			else:
				print("Warning: Boss UI health bar missing show_boss_health method")
		else:
			print("Warning: Boss level but no boss found")
	elif boss_ui_health and boss_ui_health.has_method("hide_boss_bar"):
		boss_ui_health.hide_boss_bar()

func _on_all_npcs_defeated():
	print("=== GameManager: All NPCs defeated! ===")
	print("Collecting items and unlocking exit...")
	
	# Unlock the exit door
	if current_level_scene and current_level_scene.has_method("unlock_exit"):
		current_level_scene.unlock_exit()
		print("Exit unlocked by GameManager")
	else:
		print("Warning: Cannot unlock exit - level missing unlock_exit method")
	
	# Collect all drops
	collect_all_drops()
	
	print("Post-defeat actions complete")
	print("===================================")

func _on_exit_reached():
	print("=== Exit reached! Loading next level... ===")
	
	# Check if we're still in a valid state
	if not is_inside_tree():
		print("GameManager not in tree - cannot load next level")
		return
	
	var tree = get_tree()
	if not tree:
		print("Scene tree is null - cannot load next level")
		return
	
	# Add a small delay to ensure all signals are processed
	await tree.process_frame
	
	current_level_number += 1
	await load_level(current_level_number)

func collect_all_drops():
	print("Collecting all drops...")
	# Find all drops and pull them to player
	var drops = get_tree().get_nodes_in_group("drops")
	print("Found ", drops.size(), " drops to collect")
	
	for drop in drops:
		if drop.has_method("pull_to_player"):
			drop.pull_to_player()
			print("Pulling drop to player: ", drop.name)
