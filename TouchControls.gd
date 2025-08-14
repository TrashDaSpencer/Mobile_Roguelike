extends Control
signal joystick_moved(direction: Vector2)

@onready var joystick_base = $VirtualJoystick/JoystickBase
@onready var joystick_knob = $VirtualJoystick/JoystickKnob

var is_dragging = false
var joystick_center: Vector2
var max_distance = 150.0
var joystick_visible = false

# Debug Touch Controls
var print_debug_initialize = false
var print_debug_runtime = false

func _ready():
	# Add to group for easier finding
	add_to_group("touch_controls")
	
	# Make the control fill the entire screen to catch all touches
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
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
	
	# Position joystick at bottom center of screen
	var viewport_size = get_viewport().get_visible_rect().size
	var bottom_center = Vector2(viewport_size.x / 2, viewport_size.y * 0.85)  # 15% from bottom
	show_joystick_at_position(bottom_center)

func _gui_input(event):
	if event is InputEventScreenTouch:
		var touch_pos = event.position
		
		if event.pressed:
			# Check if touch is near existing joystick or anywhere on screen
			var distance_to_joystick = touch_pos.distance_to(joystick_center)
			
			if distance_to_joystick <= max_distance * 3 or not joystick_visible:
				# If touching near joystick OR joystick is hidden, activate at touch position
				show_joystick_at_position(touch_pos)
				is_dragging = true
				update_knob_position(touch_pos)
		else:
			# Hide joystick when touch ends
			hide_joystick()
			is_dragging = false
			reset_joystick()
	
	elif event is InputEventScreenDrag and is_dragging:
		update_knob_position(event.position)
	
	# Also handle mouse events for desktop testing
	elif event is InputEventMouseButton:
		var mouse_pos = event.position
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var distance_to_joystick = mouse_pos.distance_to(joystick_center)
			
			if distance_to_joystick <= max_distance * 3 or not joystick_visible:
				show_joystick_at_position(mouse_pos)
				is_dragging = true
				update_knob_position(mouse_pos)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_joystick()
			is_dragging = false
			reset_joystick()
	
	elif event is InputEventMouseMotion and is_dragging:
		update_knob_position(event.position)

func show_joystick_at_position(pos: Vector2):
	joystick_center = pos
	joystick_visible = true
	
	if joystick_base and joystick_knob:
		# Position the base at the touch point
		joystick_base.position = joystick_center - joystick_base.size / 2
		joystick_base.visible = true
		
		# Center the knob
		joystick_knob.position = joystick_center - joystick_knob.size / 2
		joystick_knob.visible = true
	
	if print_debug_runtime == true:
		print("Joystick shown at: ", joystick_center)

func hide_joystick():
	joystick_visible = false
	
	if joystick_base:
		joystick_base.visible = false
	if joystick_knob:
		joystick_knob.visible = false
	
	if print_debug_runtime == true:
		print("Joystick hidden")

func update_knob_position(touch_pos: Vector2):
	var direction = touch_pos - joystick_center
	var distance = direction.length()
	
	# Clamp to max distance
	if distance > max_distance:
		direction = direction.normalized() * max_distance
	
	# Update knob position (only if we have the knob node)
	if joystick_knob and joystick_visible:
		joystick_knob.position = joystick_center + direction - joystick_knob.size / 2
	
	# Emit normalized direction
	var normalized_direction = direction / max_distance
	joystick_moved.emit(normalized_direction)

func reset_joystick():
	# Emit zero direction when joystick is released
	joystick_moved.emit(Vector2.ZERO)
	
	# Return joystick to bottom center position for next use
	var viewport_size = get_viewport().get_visible_rect().size
	var bottom_center = Vector2(viewport_size.x / 2, viewport_size.y * 0.85)
	joystick_center = bottom_center

# Create a simple joystick if the scene nodes don't exist
func create_simple_joystick():
	
	if print_debug_initialize == true:
		print("Creating simple joystick")
	
	# Remove any existing VirtualJoystick container
	var existing = get_node_or_null("VirtualJoystick")
	if existing:
		existing.queue_free()
	
	# Create a container for the joystick
	var container = Control.new()
	container.name = "VirtualJoystick"
	add_child(container)
	
	# Create base
	var base = ColorRect.new()
	base.name = "JoystickBase"
	base.color = Color(0.5, 0.5, 0.5, 0.3)
	base.size = Vector2(100, 100)
	base.visible = true  # Start visible
	container.add_child(base)
	
	# Create knob
	var knob = ColorRect.new()
	knob.name = "JoystickKnob"
	knob.color = Color(0.8, 0.8, 0.8, 0.7)
	knob.size = Vector2(40, 40)
	knob.visible = true  # Start visible
	container.add_child(knob)
	
	# Update references
	joystick_base = base
	joystick_knob = knob
	
	# Position at bottom center
	var viewport_size = get_viewport().get_visible_rect().size
	var bottom_center = Vector2(viewport_size.x / 2, viewport_size.y * 0.85)
	show_joystick_at_position(bottom_center)
	
	if print_debug_initialize == true:
		print("Simple joystick created at bottom center")
