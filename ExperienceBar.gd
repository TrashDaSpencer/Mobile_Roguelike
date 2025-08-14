# ExperienceBar.gd
# Attach this to a Control node in your UI scene
extends Control

@onready var experience_bar: ProgressBar
@onready var level_label: Label
@onready var exp_label: Label

# Experience system variables
var current_level = 1
var current_exp = 0
var exp_to_next_level = 100
var exp_multiplier = 1.5  # How much more exp needed each level

# Debug Experience Bar
var print_debug_experience = false

func _ready():
	# Create the UI elements
	setup_ui()
	update_display()

func setup_ui():
	# Set up the main container
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 60)
	
	# Create background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_panel)
	
	# Style the background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.2, 0.2, 0.2, 1.0)
	bg_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create horizontal container for layout
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	add_child(hbox)
	
	# Add left margin
	var left_spacer = Control.new()
	left_spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(left_spacer)
	
	# Level label
	level_label = Label.new()
	level_label.text = "Level 1"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(level_label)
	
	# Experience bar container
	var exp_container = VBoxContainer.new()
	exp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(exp_container)
	
	# Experience label
	exp_label = Label.new()
	exp_label.text = "0 / 100 EXP"
	exp_label.add_theme_font_size_override("font_size", 12)
	exp_label.add_theme_color_override("font_color", Color.WHITE)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_container.add_child(exp_label)
	
	# Experience progress bar
	experience_bar = ProgressBar.new()
	experience_bar.min_value = 0
	experience_bar.max_value = 100
	experience_bar.value = 0
	experience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exp_container.add_child(experience_bar)
	
	# Style the progress bar
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	progress_bg.corner_radius_top_left = 4
	progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4
	progress_bg.corner_radius_bottom_right = 4
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.0, 0.7, 1.0, 1.0)  # Blue
	progress_fill.corner_radius_top_left = 4
	progress_fill.corner_radius_top_right = 4
	progress_fill.corner_radius_bottom_left = 4
	progress_fill.corner_radius_bottom_right = 4
	
	experience_bar.add_theme_stylebox_override("background", progress_bg)
	experience_bar.add_theme_stylebox_override("fill", progress_fill)
	
	# Add right margin
	var right_spacer = Control.new()
	right_spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(right_spacer)

func add_experience(amount: int):
	if print_debug_experience == true:
		print("Adding ", amount, " experience")
	current_exp += amount
	
	# Check for level up
	while current_exp >= exp_to_next_level:
		level_up()
	
	update_display()

func level_up():
	current_exp -= exp_to_next_level
	current_level += 1
	exp_to_next_level = int(exp_to_next_level * exp_multiplier)
	
	if print_debug_experience == true:
		print("LEVEL UP! Now level ", current_level)
		print("Need ", exp_to_next_level, " exp for next level")
	
	# You can add level up effects here
	show_level_up_effect()

func show_level_up_effect():
	# Simple level up animation
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(level_label, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(level_label, "modulate", Color.WHITE, 0.2)

func update_display():
	if level_label:
		level_label.text = "Level " + str(current_level)
	
	if exp_label:
		exp_label.text = str(current_exp) + " / " + str(exp_to_next_level) + " EXP"
	
	if experience_bar:
		experience_bar.max_value = exp_to_next_level
		experience_bar.value = current_exp

func get_current_level() -> int:
	return current_level

func get_current_exp() -> int:
	return current_exp
