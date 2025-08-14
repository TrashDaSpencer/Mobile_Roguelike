# SlidingCamera.gd - FIXED VERSION
extends Node3D

# Node references
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

# Target tracking
@export var target: Node3D  # Drag the Player here in inspector
@export var follow_speed: float = 5.0

# Sliding constraints
@export var slide_axis: Vector3 = Vector3.FORWARD  # Which axis to slide on (X, Y, or Z)
@export var slide_min: float = 0 # Minimum slide position
@export var slide_max: float = 0  # Maximum slide position

# Camera settings
@export var camera_height: float = 15.0
@export var camera_distance: float = 20.0
@export var camera_angle: float = -80.0
@export var camera_fov: float = 65.0

# Internal tracking
var current_slide_position: float = 0.0
var base_position: Vector3  # Store the base position to slide from

# Debug sliding camera
var print_hit_camera_bounds = false
var print_camera_initialize = false

func _ready():
	setup_camera()
	add_to_group("camera_controller")  # For GameManager to find
	
	# Store the initial base position
	base_position = global_position

func setup_camera():
	if not spring_arm or not camera:
		print("Warning: SpringArm3D or Camera3D not found!")
		return
	
	# Configure SpringArm3D
	spring_arm.spring_length = camera_distance
	
	# Configure camera
	camera.fov = camera_fov
	
	# Set camera angle
	spring_arm.rotation_degrees.x = camera_angle
	
	if print_camera_initialize == true:
		print("Sliding camera system initialized")

func _process(delta):
	if not target:
		return
	
	follow_target(delta)
	
func follow_target(delta):
	# Calculate target position on the slide axis
	var target_slide_pos = get_slide_position_from_target()
	
	# Smoothly move to target position
	current_slide_position = lerp(current_slide_position, target_slide_pos, follow_speed * delta)
	
	# Clamp to min/max bounds - THIS IS THE KEY FIX
	var old_position = current_slide_position
	current_slide_position = clamp(current_slide_position, slide_min, slide_max)
	
	# Debug output when hitting bounds
	if old_position != current_slide_position:
		if print_hit_camera_bounds == true:
			print("Camera hit bounds: clamped ", old_position, " to ", current_slide_position, " (bounds: ", slide_min, " to ", slide_max, ")")
	
	# Apply position
	apply_slide_position()

func get_slide_position_from_target() -> float:
	# Project target position onto the slide axis
	var target_pos = target.global_position
	
	if slide_axis == Vector3.RIGHT:  # X-axis
		return target_pos.x
	elif slide_axis == Vector3.UP:  # Y-axis
		return target_pos.y
	elif slide_axis == Vector3.FORWARD:  # Z-axis
		return target_pos.z
	else:
		# Custom axis - dot product with normalized axis
		return target_pos.dot(slide_axis.normalized())

func apply_slide_position():
	# FIXED: Properly update only the sliding component while preserving others
	var new_position = base_position
	
	if slide_axis == Vector3.RIGHT:  # X-axis
		new_position.x = current_slide_position
	elif slide_axis == Vector3.UP:  # Y-axis
		new_position.y = current_slide_position
	elif slide_axis == Vector3.FORWARD:  # Z-axis
		new_position.z = current_slide_position
	else:
		# Custom axis - project the slide position onto the axis
		var slide_offset = slide_axis.normalized() * current_slide_position
		new_position = base_position + slide_offset
	
	# Always maintain the camera height
	new_position.y = camera_height
	
	global_position = new_position

# Public methods for GameManager/Level to call
func set_slide_bounds(min_pos: float, max_pos: float):
	slide_min = min_pos
	slide_max = max_pos
	if print_camera_initialize == true:
		print("Camera slide bounds set: ", min_pos, " to ", max_pos)
	
	# Immediately clamp current position to new bounds
	var old_pos = current_slide_position
	current_slide_position = clamp(current_slide_position, slide_min, slide_max)
	if old_pos != current_slide_position:
		if print_camera_initialize == true:
			print("Camera position adjusted to new bounds: ", old_pos, " -> ", current_slide_position)
		apply_slide_position()

func set_slide_axis(axis: Vector3):
	slide_axis = axis.normalized()
	if print_camera_initialize == true:
		print("Camera slide axis set to: ", slide_axis)

func set_target(new_target: Node3D):
	target = new_target
	if target && print_camera_initialize == true:
		print("Camera target set to: ", target.name)

func get_slide_bounds() -> Vector2:
	return Vector2(slide_min, slide_max)

func reset_to_center():
	current_slide_position = (slide_min + slide_max) / 2.0
	apply_slide_position()

func snap_to_target():
	if target:
		current_slide_position = get_slide_position_from_target()
		current_slide_position = clamp(current_slide_position, slide_min, slide_max)
		apply_slide_position()
		if print_camera_initialize == true:
			print("Camera snapped to target at position: ", current_slide_position)

# Camera control methods
func set_camera_distance(distance: float):
	camera_distance = distance
	if spring_arm:
		spring_arm.spring_length = distance

func set_camera_height(height: float):
	camera_height = height
	# Update position to reflect new height
	apply_slide_position()

func set_camera_angle(angle: float):
	camera_angle = angle
	if spring_arm:
		spring_arm.rotation_degrees.x = angle

# Debug method to check current state
func debug_camera_state():
	print("=== CAMERA DEBUG ===")
	print("Target: ", target.name if target else "None")
	print("Current slide position: ", current_slide_position)
	print("Slide bounds: ", slide_min, " to ", slide_max)
	print("Slide axis: ", slide_axis)
	print("Global position: ", global_position)
	print("Base position: ", base_position)
	if target:
		print("Target position: ", target.global_position)
		print("Target slide pos: ", get_slide_position_from_target())
	print("==================")

# Optional: Add this to see bounds in action
func _draw_debug_info():
	if not Engine.is_editor_hint() and target:
		var target_slide = get_slide_position_from_target()
		if target_slide < slide_min or target_slide > slide_max:
			print("Target outside bounds! Target: ", target_slide, " Bounds: ", slide_min, " to ", slide_max)
