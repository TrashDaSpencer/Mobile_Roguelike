extends Control
signal joystick_moved(direction: Vector2)

@onready var joystick_base = $VirtualJoystick/JoystickBase
@onready var joystick_knob = $VirtualJoystick/JoystickKnob

var is_dragging = false
var joystick_center: Vector2
var max_distance = 50.0

func _ready():
	# Add to group for easier finding
	add_to_group("touch_controls")
	
	# Make sure this Control node can receive input
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Set up joystick visuals
	call_deferred("setup_joystick")

func setup_joystick():
	# Make sure we have the nodes
	if not joystick_base or not joystick_knob:
		print("Warning: Joystick nodes not found, creating simple joystick")
		create_simple_joystick()
		return
	
	# Position joystick in bottom left
	var viewport_size = get_viewport().get_visible_rect().size
	joystick_base.position = Vector2(100, viewport_size.y - 150)
	joystick_base.size = Vector2(100, 100)
	joystick_center = joystick_base.position + joystick_base.size / 2
	
	# Create simple circular base
	joystick_base.modulate = Color(1, 1, 1, 0.3)  # Semi-transparent
	
	# Set up knob
	joystick_knob.position = joystick_center - Vector2(25, 25)
	joystick_knob.size = Vector2(50, 50)
	joystick_knob.modulate = Color(1, 1, 1, 0.7)

# Fixed the function name - it was missing underscores
func _gui_input(event):
	print("GUI Input received: ", event)
	
	if event is InputEventScreenTouch:
		var touch_pos = event.position
		var distance_to_base = touch_pos.distance_to(joystick_center)
		
		print("Touch event - Position: ", touch_pos, " Distance to base: ", distance_to_base)
		
		# Only activate if touching near the joystick
		if distance_to_base <= max_distance * 1.5:
			if event.pressed:
				print("Starting drag")
				is_dragging = true
				update_knob_position(touch_pos)
			else:
				print("Ending drag")
				is_dragging = false
				reset_knob()
	
	elif event is InputEventScreenDrag and is_dragging:
		print("Drag event: ", event.position)
		update_knob_position(event.position)
	
	# Also handle mouse events for desktop testing
	elif event is InputEventMouseButton:
		var mouse_pos = event.position
		var distance_to_base = mouse_pos.distance_to(joystick_center)
		
		if distance_to_base <= max_distance * 1.5:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				print("Starting mouse drag")
				is_dragging = true
				update_knob_position(mouse_pos)
			elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				print("Ending mouse drag")
				is_dragging = false
				reset_knob()
	
	elif event is InputEventMouseMotion and is_dragging:
		print("Mouse motion: ", event.position)
		update_knob_position(event.position)

func update_knob_position(touch_pos: Vector2):
	var direction = touch_pos - joystick_center
	var distance = direction.length()
	
	# Clamp to max distance
	if distance > max_distance:
		direction = direction.normalized() * max_distance
	
	# Update knob position (only if we have the knob node)
	if joystick_knob:
		joystick_knob.position = joystick_center + direction - joystick_knob.size / 2
	
	# Emit normalized direction
	var normalized_direction = direction / max_distance
	print("Emitting direction: ", normalized_direction)
	joystick_moved.emit(normalized_direction)

func reset_knob():
	# Return knob to center
	if joystick_knob:
		joystick_knob.position = joystick_center - joystick_knob.size / 2
	print("Resetting joystick")
	joystick_moved.emit(Vector2.ZERO)

# Create a simple joystick if the scene nodes don't exist
func create_simple_joystick():
	print("Creating simple joystick")
	
	# Remove any existing VirtualJoystick container
	var existing = get_node_or_null("VirtualJoystick")
	if existing:
		existing.queue_free()
	
	# Create base
	var base = ColorRect.new()
	base.name = "JoystickBase"
	base.color = Color(0.5, 0.5, 0.5, 0.3)
	base.size = Vector2(100, 100)
	var viewport_size = get_viewport().get_visible_rect().size
	base.position = Vector2(50, viewport_size.y - 150)
	add_child(base)
	
	# Create knob
	var knob = ColorRect.new()
	knob.name = "JoystickKnob"
	knob.color = Color(0.8, 0.8, 0.8, 0.7)
	knob.size = Vector2(40, 40)
	knob.position = Vector2(30, 30)  # Centered in base
	base.add_child(knob)
	
	# Update references
	joystick_base = base
	joystick_knob = knob
	joystick_center = base.global_position + base.size / 2
	
	print("Simple joystick created at: ", joystick_center)
