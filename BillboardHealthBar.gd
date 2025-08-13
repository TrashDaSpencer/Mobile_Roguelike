# BillboardHealthBar.gd (TextureProgressBar Version)
extends Node3D

# Node references
@onready var sub_viewport: SubViewport = $SubViewport
@onready var health_bar_ui: Control = $SubViewport/HealthBarUI
@onready var content_container: VBoxContainer = $SubViewport/HealthBarUI/ContentContainer
@onready var health_label: Label = $SubViewport/HealthBarUI/ContentContainer/HealthLabel
@onready var health_bar: TextureProgressBar = $SubViewport/HealthBarUI/ContentContainer/HealthBar
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Character tracking
var target_character: Node = null
var max_health: float = 100
var current_health: float = 100
var is_player: bool = true

# Appearance settings
var bar_width: float = 256
var bar_height: float = 64
var bar_y_offset: float = 2.5

# Health bar textures 
var health_bg_texture: Texture2D
var health_fill_texture: Texture2D
var low_health_tween: Tween = null

func _ready():
	add_to_group("health_bars")
	setup_health_textures()
	setup_scene_nodes()

func setup_health_textures():
	# Try to load existing textures, or create simple ones
	health_bg_texture = load("res://textures/health_bar_bg.png") 
	health_fill_texture = load("res://textures/health_bar_green.png")
	
func setup_scene_nodes():
	# Setup SubViewport
	if sub_viewport:
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sub_viewport.snap_2d_transforms_to_pixel = true
		sub_viewport.snap_2d_vertices_to_pixel = true
		sub_viewport.transparent_bg = true
		#sub_viewport.size.y = 8
	
	# Setup health label
	if health_label:
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		health_label.add_theme_font_size_override("font_size", 35)
		health_label.add_theme_color_override("font_color", Color.WHITE)
		# Add text outline for better visibility
		health_label.add_theme_color_override("font_outline_color", Color.BLACK)
		health_label.add_theme_constant_override("outline_size", 10)
	
	# Setup TextureProgressBar
	if health_bar:
		health_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		health_bar.min_value = 0
		health_bar.value = current_health
		
		# Set up nine-patch stretching to prevent border distortion
		health_bar.stretch_margin_left = 1
		health_bar.stretch_margin_right = 1
		health_bar.stretch_margin_top = 1
		health_bar.stretch_margin_bottom = 1
		
		# Make sure the texture progress bar scales properly
		health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		health_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
	# Setup mesh instance for billboard display
	if mesh_instance:
		
		var material = StandardMaterial3D.new()
		material.flags_transparent = true
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.no_depth_test = true
		
		if sub_viewport:
			material.albedo_texture = sub_viewport.get_texture()
		mesh_instance.material_override = material
		

func initialize(character: Node, max_hp: float, height_offset: float = 2.5, show_numbers: bool = true):
	target_character = character
	max_health = max_hp
	current_health = max_hp
	bar_y_offset = height_offset
	is_player = show_numbers
	
	# Show/hide health label
	if health_label:
		# health_label.visible = is_player
		if not is_player:
			health_label.text = ""
	
	# Adjust viewport size
	if sub_viewport:
		sub_viewport.size = Vector2(int(bar_width), bar_height)
	
	# Update mesh size
	if mesh_instance and mesh_instance.mesh is QuadMesh:
		var quad_mesh_player = mesh_instance.mesh as QuadMesh
		quad_mesh_player.size = Vector2(bar_width / 50.0, bar_height / 50.0)
	
	# Position above character
	if target_character:
		global_position = target_character.global_position + Vector3(0, bar_y_offset, 0)
	
	update_health_display()

func _process(_delta):
	if target_character and is_instance_valid(target_character):
		global_position = target_character.global_position + Vector3(0, bar_y_offset, 0)
	elif target_character == null or not is_instance_valid(target_character):
		queue_free()

func update_health(new_health: float):
	current_health = clamp(new_health, 0, max_health)
	update_health_display()
	# Hide when at full health for player only
	if is_player and current_health >= max_health:
		visible = false
	else:
		visible = true

func update_health_display():
	if not health_bar:
		print("HealthBar not detected")
		return
	
	# Update progress bar value
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Change texture based on health percentage
	var health_percent = current_health / max_health
	
	if health_percent > 0.6:
		health_bar.tint_progress = health_bar.tint_progress.from_rgba8(0,255,0,255)
	elif health_percent > 0.3:
		health_bar.tint_progress = health_bar.tint_progress.from_rgba8(255,255,0,255)
	else:
		health_bar.tint_progress = health_bar.tint_progress.from_rgba8(255,0,0,255)
	
	# Player only past this point
	if not is_player:
		return 
		
	# Update health label
	if is_player and health_label:
		health_label.text = str(int(current_health))
	
	# Optional: Add pulsing effect for low health
	if health_percent <= 0.3 and health_percent > 0:
		add_low_health_effect()
	else:
		remove_low_health_effect()

func add_low_health_effect():
	# Pulsing red effect for critical health
	if not health_bar.has_meta("pulsing"):
		health_bar.set_meta("pulsing", true)
		
		# Store the tween reference
		low_health_tween = create_tween()
		low_health_tween.set_loops()
		low_health_tween.tween_property(health_bar, "modulate:a", 0.0, 0.3)
		low_health_tween.tween_property(health_bar, "modulate:a", 1.0, 0.3)

func remove_low_health_effect():
	if health_bar.has_meta("pulsing"):
		health_bar.remove_meta("pulsing")
		
		# Kill the stored tween if it exists
		if low_health_tween and low_health_tween.is_valid():
			low_health_tween.kill()
			low_health_tween = null
		
		# Reset the alpha
		health_bar.modulate.a = 1.0

func hide_health_bar():
	visible = false

func show_health_bar():
	visible = true
