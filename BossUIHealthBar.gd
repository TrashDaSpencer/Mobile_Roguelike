# BossUIHealthBar.gd
# Attach this to a Control node in your UI scene for boss health display
extends Control

@onready var boss_health_bar: ProgressBar
@onready var boss_name_label: Label
@onready var boss_panel: Panel

var current_boss: NPC = null
var max_health: float = 100
var current_health: float = 100

func _ready():
	setup_ui()
	hide_boss_bar()  # Start hidden

func setup_ui():
	# Set up the main container at top of screen
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 80)
	position.y = 60  # Below experience bar
	
	# Create background panel
	boss_panel = Panel.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(boss_panel)
	
	# Style the background with boss theme
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.3, 0.0, 0.0, 0.9)  # Dark red background
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(1.0, 0.0, 0.0, 1.0)  # Red border
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	boss_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create vertical container for layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)
	
	# Add top margin
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(top_spacer)
	
	# Boss name label
	boss_name_label = Label.new()
	boss_name_label.text = "BOSS"
	boss_name_label.add_theme_font_size_override("font_size", 24)
	boss_name_label.add_theme_color_override("font_color", Color.WHITE)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(boss_name_label)
	
	# Health bar container with margins
	var health_container = HBoxContainer.new()
	health_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(health_container)
	
	# Left margin
	var left_spacer = Control.new()
	left_spacer.custom_minimum_size = Vector2(50, 0)
	health_container.add_child(left_spacer)
	
	# Boss health bar
	boss_health_bar = ProgressBar.new()
	boss_health_bar.min_value = 0
	boss_health_bar.max_value = 100
	boss_health_bar.value = 100
	boss_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_health_bar.custom_minimum_size = Vector2(0, 20)
	health_container.add_child(boss_health_bar)
	
	# Right margin
	var right_spacer = Control.new()
	right_spacer.custom_minimum_size = Vector2(50, 0)
	health_container.add_child(right_spacer)
	
	# Style the boss health bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.1, 0.1, 0.1, 1.0)  # Dark background
	progress_bg.corner_radius_top_left = 6
	progress_bg.corner_radius_top_right = 6
	progress_bg.corner_radius_bottom_left = 6
	progress_bg.corner_radius_bottom_right = 6
	progress_bg.border_width_left = 2
	progress_bg.border_width_right = 2
	progress_bg.border_width_top = 2
	progress_bg.border_width_bottom = 2
	progress_bg.border_color = Color.BLACK
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(1.0, 0.0, 0.0, 1.0)  # Red fill for boss
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	
	boss_health_bar.add_theme_stylebox_override("background", progress_bg)
	boss_health_bar.add_theme_stylebox_override("fill", progress_fill)
	
	# Add bottom margin
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bottom_spacer)

func show_boss_health(boss: NPC):
	if not boss or not boss.is_boss:
		print("Warning: Trying to show boss health for non-boss NPC")
		return
	
	current_boss = boss
	max_health = boss.max_health
	current_health = boss.health
	
	# Set boss name
	var boss_type = ""
	match boss.npc_type:
		NPC.NPCType.MELEE:
			boss_type = "MELEE BOSS"
		NPC.NPCType.RANGED_AGGRESSIVE:
			boss_type = "AGGRESSIVE BOSS"
		NPC.NPCType.RANGED_DEFENSIVE:
			boss_type = "DEFENSIVE BOSS"
		_:
			boss_type = "BOSS"
	
	boss_name_label.text = boss_type
	
	# Update health bar
	boss_health_bar.max_value = max_health
	boss_health_bar.value = current_health
	
	# Show the UI
	visible = true
	
	# Connect to boss health changes
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)
	
	print("Boss health bar shown for: ", boss_type)

func hide_boss_bar():
	visible = false
	current_boss = null
	print("Boss health bar hidden")

func _on_boss_health_changed(new_health: float):
	update_boss_health(new_health)

func update_boss_health(new_health: float):
	current_health = clamp(new_health, 0, max_health)
	
	if boss_health_bar:
		boss_health_bar.value = current_health
	
	# Update color based on health percentage
	var health_percent = current_health / max_health
	var fill_style = boss_health_bar.get_theme_stylebox("fill").duplicate()
	
	if health_percent > 0.6:
		fill_style.bg_color = Color(1.0, 0.0, 0.0, 1.0)  # Red
	elif health_percent > 0.3:
		fill_style.bg_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange
	else:
		fill_style.bg_color = Color(0.5, 0.0, 0.0, 1.0)   # Dark red
	
	boss_health_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Hide when boss dies
	if current_health <= 0:
		hide_boss_bar()

func _process(_delta):
	# Monitor boss health if we have one
	if current_boss and is_instance_valid(current_boss):
		if current_boss.health != current_health:
			update_boss_health(current_boss.health)
	elif current_boss:
		# Boss is no longer valid, hide the bar
		hide_boss_bar()
