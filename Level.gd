extends Node3D

# Signals to communicate with GameManager
signal all_npcs_defeated
signal exit_reached

# Level components
var exit_door: Node3D
var floor_mesh: Node3D
var npc_container: Node3D
var spawn_points: Node3D

# NPC management
var npc_scene = null  # We'll use the factory instead
var npcs_alive = 0
var total_npcs_spawned = 0
var npcs_to_spawn = 5 # Default, can be overridden
# var boss_spawn_chance = 0.15  # 15% chance for boss per level

# Level-based spawn settings
var current_level_number = 1
var boss_spawn_chance = 0.0  # Will be calculated based on level
var is_boss_level = false

# NPC spawning margins (units from edge)
var spawn_margin = 2.0  # Distance from arena edges to keep NPCs away

# Level identification (for duplicate detection)
var level_id: String
var is_main_instance = false

func _ready():
	# Generate unique level ID
	level_id = "Level_" + str(randi())
	print("=== LEVEL INITIALIZING ===")
	print("Level ID: ", level_id)
	print("Scene file path: ", scene_file_path)
	
	# Check for duplicates
	if check_for_duplicates():
		return
	
	is_main_instance = true
	print("This is the main level instance")
	
	# Initialize level
	setup_level()
	spawn_npcs()
	lock_exit()
	
	# Start checking for dead NPCs every second as backup
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_check_npc_status)
	timer.autostart = true
	add_child(timer)

func check_for_duplicates() -> bool:
	# Check if another level instance already exists
	var levels = get_tree().get_nodes_in_group("levels")
	var active_levels = []
	
	for level in levels:
		if level != self and level.is_main_instance:
			active_levels.append(level)
	
	if active_levels.size() > 0:
		print("*** DUPLICATE LEVEL DETECTED - REMOVING ***")
		print("--- Debugging process stopped ---")
		queue_free()
		return true
	
	# Add self to levels group for tracking
	add_to_group("levels")
	return false

func setup_level():
	print("=== Level Setup Debug ===")
	
	# Find level components
	exit_door = find_child("ExitDoor", true, false)
	floor_mesh = find_child("FloorMesh", true, false)
	spawn_points = find_child("SpawnPoints", true, false)
	npc_container = find_child("NPCContainer", true, false)
	
	# Create NPC container if it doesn't exist
	if not npc_container:
		npc_container = Node3D.new()
		npc_container.name = "NPCContainer"
		add_child(npc_container)
	
	# Debug output
	print("ExitDoor found: ", exit_door != null)
	print("FloorMesh found: ", floor_mesh != null)
	print("SpawnPoints found: ", spawn_points != null)
	print("Spawn margin set to: ", spawn_margin, " units")
	
	if not exit_door:
		print("Warning: ExitDoor not found!")
	if not spawn_points:
		print("Warning: SpawnPoints not found!")

func spawn_npcs():
	print("=== NPC Spawning ===")
	print("Spawning NPCs for level ", current_level_number)
	print("Boss level: ", is_boss_level)
	
	if not floor_mesh:
		print("Cannot spawn NPCs: FloorMesh not found!")
		return
	
	# Get floor bounds with margins for safe spawning
	var safe_bounds = get_safe_spawn_bounds()
	
	# Check if safe bounds are valid
	if safe_bounds.size.x <= 0 or safe_bounds.size.z <= 0:
		print("Warning: Safe spawn area too small! Using default bounds.")
		safe_bounds = AABB(Vector3(-8, 0, -8), Vector3(16, 2, 16))
	
	print("Safe spawn bounds: ", safe_bounds)
	
	if is_boss_level:
		# Boss levels: spawn 1 boss + some regular NPCs
		spawn_npc_advanced(1, safe_bounds, true)  # Spawn boss
		
		# Spawn 2-3 regular NPCs with boss
		var regular_npcs = 2 + (current_level_number / 20)  # More regular NPCs at higher levels
		for i in range(regular_npcs):
			spawn_npc_advanced(i + 2, safe_bounds, false)
		
		npcs_to_spawn = regular_npcs + 1
	else:
		# Regular levels: spawn normal NPCs
		for i in range(npcs_to_spawn):
			spawn_npc_advanced(i + 1, safe_bounds, false)
	
	print("Total NPCs spawned: ", total_npcs_spawned)
	print("NPCs alive counter: ", npcs_alive)
	print("Container children: ", npc_container.get_child_count())
	print("========================")

func get_floor_bounds() -> AABB:
	# Get the floor mesh bounds for NPC spawning
	if floor_mesh and floor_mesh.has_method("get_aabb"):
		return floor_mesh.get_aabb()
	else:
		# Default bounds if we can't get floor size
		return AABB(Vector3(-10, 0, -10), Vector3(20, 2, 20))

func get_safe_spawn_bounds() -> AABB:
	# Get floor bounds and apply margins for safe NPC spawning
	var floor_bounds = get_floor_bounds()
	
	# Apply margins to all sides
	var safe_position = Vector3(
		floor_bounds.position.x + spawn_margin,
		floor_bounds.position.y,
		floor_bounds.position.z + spawn_margin
	)
	
	var safe_size = Vector3(
		max(0, floor_bounds.size.x - (spawn_margin * 2)),
		floor_bounds.size.y,
		max(0, floor_bounds.size.z - (spawn_margin * 2))
	)
	
	return AABB(safe_position, safe_size)

func spawn_npc_advanced(npc_number: int, bounds: AABB, is_boss: bool = false):
	# Get NPC type based on level progression
	var npc_type = NPCSpawner.get_weighted_random_npc_type(current_level_number)
	
	# Create NPC using factory with level scaling
	var npc = NPCSpawner.create_npc_with_scaling(npc_type, is_boss, current_level_number)
	npc_container.add_child(npc)
	
	# Random position within safe bounds
	var x = randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
	var z = randf_range(bounds.position.z, bounds.position.z + bounds.size.z)
	var y = bounds.position.y + bounds.size.y * 0.5 # Middle of floor height
	
	var spawn_pos = Vector3(x, y, z)
	npc.global_position = spawn_pos
	
	var type_name = npc_type + (" (BOSS)" if is_boss else "")
	print("NPC ", npc_number, " spawned: ", type_name, " at: ", spawn_pos)
	
	# Connect NPC death signal with better error checking
	if npc.has_signal("died"):
		npc.died.connect(_on_npc_died)
		print("Connected death signal for NPC ", npc_number)
	else:
		print("WARNING: NPC ", npc_number, " does not have 'died' signal!")
		# Try alternative signal names
		if npc.has_signal("npc_died"):
			npc.npc_died.connect(_on_npc_died)
			print("Connected 'npc_died' signal for NPC ", npc_number)
		else:
			print("No death signal found for NPC ", npc_number)
	
	npcs_alive += 1
	total_npcs_spawned += 1

# Keep old spawn_npc for compatibility, but mark as deprecated
func spawn_npc(npc_number: int, bounds: AABB):
	print("Warning: spawn_npc is deprecated, use spawn_npc_advanced instead")
	spawn_npc_advanced(npc_number, bounds, false)

func _on_npc_died():
	npcs_alive -= 1
	print("NPC died. NPCs remaining: ", npcs_alive)
	
	if npcs_alive <= 0:
		print("All NPCs defeated!")
		# Let GameManager handle unlocking - don't do it here
		all_npcs_defeated.emit()  # Signal GameManager to unlock and collect drops

func lock_exit():
	print("Exit door locked")
	if exit_door and exit_door.has_method("lock"):
		exit_door.lock()

func unlock_exit():
	print("Exit door unlocked")
	if exit_door and exit_door.has_method("unlock"):
		exit_door.unlock()

func _on_exit_door_player_entered():
	# Connect this to your exit door's area detection
	print("Player reached exit!")
	exit_reached.emit()

func set_level_number(level_num: int):
	current_level_number = level_num
	is_boss_level = (level_num % 10 == 0)  # Every 10th level is a boss level
	
	print("=== LEVEL CONFIGURATION ===")
	print("Level: ", level_num)
	print("Boss level: ", is_boss_level)
	print("Scaling tier: ", get_scaling_tier(level_num))
	print("============================")
	
	# Adjust NPC count based on level (but not for boss levels)
	if not is_boss_level:
		if level_num <= 5:
			npcs_to_spawn = 5
		elif level_num <= 15:
			npcs_to_spawn = 6 + (level_num / 5)
		else:
			npcs_to_spawn = 8 + (level_num / 10)

func get_scaling_tier(level: int) -> int:
	# Each boss defeated (every 10 levels) increases the tier
	return (level - 1) / 10  # Level 1-10 = tier 0, 11-20 = tier 1, etc.

func set_npc_count(count: int):
	npcs_to_spawn = count

func set_spawn_margin(margin: float):
	# Allow adjusting spawn margin at runtime
	spawn_margin = margin
	print("Spawn margin updated to: ", spawn_margin, " units")

func get_spawn_point(spawn_name: String) -> Vector3:
	if spawn_points:
		var spawn = spawn_points.find_child(spawn_name, true, false)
		if spawn:
			return spawn.global_position
	return global_position

func get_exit_door_position() -> Vector3:
	if exit_door:
		return exit_door.global_position
	return global_position

func _check_npc_status():
	# Backup method: manually check if NPCs are still alive
	if not npc_container:
		return
	
	var current_alive_count = 0
	var children = npc_container.get_children()
	
	for child in children:
		# Check if the NPC still exists and isn't queued for deletion
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			# You might need to adjust this check based on your NPC script
			# Check if NPC has health or is_dead property
			if child.has_method("is_alive"):
				if child.is_alive():
					current_alive_count += 1
			elif child.has_method("get") and child.get("health") != null:
				if child.health > 0:
					current_alive_count += 1
			elif not (child.has_method("get") and child.get("is_dead") == true):
				# If no health system, assume alive if not marked dead
				current_alive_count += 1
	
	# Update our count if it changed
	if current_alive_count != npcs_alive:
		print("NPC count mismatch detected! Stored: ", npcs_alive, ", Actual: ", current_alive_count)
		npcs_alive = current_alive_count
		
		if npcs_alive <= 0:
			print("All NPCs defeated (detected by backup check)!")
			all_npcs_defeated.emit()

func _exit_tree():
	# Clean up when level is removed
	if is_in_group("levels"):
		remove_from_group("levels")
