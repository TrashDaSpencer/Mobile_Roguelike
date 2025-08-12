# BillboardHealthBar.gd
# This creates a 2D health bar that always faces the camera
extends Node3D

var health_bar: ProgressBar
var background_panel: Panel
var target_character: Node  # The character this health bar belongs to
var max_health: float = 100
var current_health: float = 100
var bar_width: float = 100
var bar_height: float = 12
var y_offset: float = 2.5  # How high above character to show

# Colors
var health_color = Color.GREEN
var damage_color = Color.RED
var background_color = Color(0, 0, 0, 0.7)

func _ready():
	setup_health_bar()

func setup_health_bar():
	# Create a SubViewport for 2D UI in 3D space
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(int(bar_width), int(bar_height + 4))
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub_viewport)
	
	# Create the 2D UI inside the viewport
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_viewport.add_child(control)
	
	# Background panel
	background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(background_panel)
	
	# Style background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = background_color
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color.BLACK
	background_panel.add_theme_stylebox_override("panel", bg_style)
	
	# Health bar
	health_bar = ProgressBar.new()
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.add_theme_constant_override("outline_size", 0)
	control.add_child(health_bar)
	
	# Style health bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color.TRANSPARENT
	
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = health_color
	bar_fill.corner_radius_top_left = 1
	bar_fill.corner_radius_top_right = 1
	bar_fill.corner_radius_bottom_left = 1
	bar_fill.corner_radius_bottom_right = 1
	
	health_bar.add_theme_stylebox_override("background", bar_bg)
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	
	# Create a MeshInstance3D to display the viewport as a texture
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position.y = y_offset
	add_child(mesh_instance)
	
	# Create a quad mesh
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(bar_width / 50.0, bar_height / 50.0)  # Scale down for 3D world
	mesh_instance.mesh = quad_mesh
	
	# Create material with the viewport texture
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.flags_unshaded = true
	material.flags_do_not_receive_shadows = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_texture = sub_viewport.get_texture()
	mesh_instance.material_override = material
	
	# Set initial values
	update_health_bar()

func initialize(character: Node, max_hp: float, height_offset: float = 2.5):
	target_character = character
	max_health = max_hp
	current_health = max_hp
	y_offset = height_offset
	
	# Position above character
	if target_character:
		global_position = target_character.global_position + Vector3(0, y_offset, 0)
	
	update_health_bar()
	print("Health bar initialized for ", character.name, " with ", max_hp, " HP")

func _process(_delta):
	# Keep health bar positioned above the character
	if target_character and is_instance_valid(target_character):
		global_position = target_character.global_position + Vector3(0, y_offset, 0)
	elif target_character == null or not is_instance_valid(target_character):
		# Character is gone, remove health bar
		queue_free()

func update_health(new_health: float):
	current_health = clamp(new_health, 0, max_health)
	update_health_bar()
	
	# Hide health bar when at full health (optional)
	if current_health >= max_health:
		visible = false
	else:
		visible = true

func update_health_bar():
	if not health_bar:
		return
		
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Update color based on health percentage
	var health_percent = current_health / max_health
	var fill_style = health_bar.get_theme_stylebox("fill").duplicate()
	
	if health_percent > 0.6:
		fill_style.bg_color = health_color  # Green
	elif health_percent > 0.3:
		fill_style.bg_color = Color.YELLOW  # Yellow
	else:
		fill_style.bg_color = damage_color   # Red
	
	health_bar.add_theme_stylebox_override("fill", fill_style)

func set_health_bar_size(width: float, height: float):
	bar_width = width
	bar_height = height
	# You'd need to recreate the viewport and mesh with new size

func hide_health_bar():
	visible = false

func show_health_bar():
	visible = true
