extends Area3D

var is_unlocked = false
var status_label: Label3D

func _ready():
	body_entered.connect(_on_body_entered)
	
	print("=== EXIT DOOR DEBUG ===")
	print("Door initialized, locked status: ", not is_unlocked)
	
	# Set up door appearance
	var mesh_instance = get_node_or_null("DoorMesh")
	if not mesh_instance:
		print("Warning: DoorMesh not found as child of ExitDoor!")
		# Try to find it recursively
		mesh_instance = find_child("DoorMesh", true, false)
		if mesh_instance:
			print("Found DoorMesh recursively")
		else:
			print("DoorMesh not found anywhere - door appearance won't work")
	else:
		print("DoorMesh found successfully")
	
	# Set initial locked appearance
	update_door_appearance()
	
	# Create status label
	create_status_label()
	
	print("Door setup complete")
	print("========================")

func _on_body_entered(body):
	print("Body entered door area: ", body.name)
	print("Door unlocked status: ", is_unlocked)
	
	if body.name == "Player" and is_unlocked:
		print("Player entered unlocked door - loading next level")
		load_next_level()
	elif body.name == "Player" and not is_unlocked:
		print("Player tried to enter locked door")
	else:
		print("Non-player entity entered door area")

func lock():
	print("Door locked")
	is_unlocked = false
	update_door_appearance()

func unlock():
	print("Door unlocked!")
	is_unlocked = true
	update_door_appearance()

func update_door_appearance():
	var mesh_instance = get_node_or_null("DoorMesh")
	if not mesh_instance:
		mesh_instance = find_child("DoorMesh", true, false)
	
	if mesh_instance:
		var material = StandardMaterial3D.new()
		
		if is_unlocked:
			# Greenish blue when unlocked
			material.albedo_color = Color(0.0, 0.8, 0.6)  # Teal/greenish blue
			print("Door appearance updated to UNLOCKED (teal)")
		else:
			# Very dark red when locked
			material.albedo_color = Color(0.3, 0.0, 0.0)  # Dark red
			print("Door appearance updated to LOCKED (dark red)")
		
		mesh_instance.set_surface_override_material(0, material)
	else:
		print("Cannot update door appearance - DoorMesh not found")
	
	# Update status label
	if status_label:
		if is_unlocked:
			status_label.text = "UNLOCKED"
			status_label.modulate = Color(0.0, 1.0, 0.7)  # Bright greenish blue
			print("Status label updated to UNLOCKED")
		else:
			status_label.text = "LOCKED"
			status_label.modulate = Color(1.0, 0.3, 0.3)  # Light red
			print("Status label updated to LOCKED")
	else:
		print("Cannot update status label - label not found")

func create_status_label():
	# Create a Label3D node for the status text
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	add_child(status_label)
	
	# Position the label above the door
	status_label.position = Vector3(0, 2.0, 0)  # 2 units above door center
	
	# Set up label properties
	status_label.text = "LOCKED"
	status_label.font_size = 24
	status_label.modulate = Color(1.0, 0.3, 0.3)  # Light red for locked
	
	# Make it billboard so it always faces the camera
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Optional: Add outline for better visibility
	status_label.outline_size = 2
	status_label.outline_modulate = Color.BLACK
	
	print("Status label created and positioned at: ", status_label.position)

func load_next_level():
	print("Loading next level...")
	# Emit signal to let level manager handle this
	if get_parent().has_signal("exit_reached"):
		get_parent().exit_reached.emit()
	
	# For now, just reload current scene
	get_tree().reload_current_scene()
