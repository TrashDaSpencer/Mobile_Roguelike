extends RigidBody3D

# Debug settings
@export var debug_player_damage = false
@export var debug_enemy_damage = false

var damage = 0
var shooter = ""
var direction = Vector3.ZERO
var speed = 15.0
var lifetime = 3.0
@onready var area = $BulletArea  # Reference to child BulletArea

func _ready():
	# Set up bullet physics
	gravity_scale = 0  # No gravity for bullets
	linear_damp = 0    # No air resistance
	
	# Set up collision detection through BulletArea
	if area:
		area.body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func setup_bullet(dir: Vector3, bullet_speed: float, bullet_damage: int, bullet_shooter: String):
	direction = dir
	speed = bullet_speed
	damage = bullet_damage
	shooter = bullet_shooter
	
	# Set collision layers based on shooter
	if shooter == "player":
		collision_layer = 8  
		collision_mask = 6   
	elif shooter == "enemy":
		collision_layer = 16 
		collision_mask = 5   
	
	# Apply velocity
	linear_velocity = direction * speed
	
	# Rotate bullet to face direction
	direction.y = 0
	direction = direction.normalized()
	look_at(global_position + direction, Vector3.UP)

func _on_body_entered(body):
	if shooter == "player" and body is NPC:
		# Player bullet hit enemy
		if debug_enemy_damage:
			print("Bullet from ", shooter, " hit: ", body.name, " (", body.get_class(), ")")
			print("Body groups: ", body.get_groups())
			print("Hit at position: ", global_position)
			print("Bullet damage: ", damage)
			print("Dealing ", damage, " damage to enemy")
		body.take_damage(damage)
		queue_free()
		
	elif shooter == "enemy" and body.name == "Player":
		# Enemy bullet hit player
		if debug_player_damage:
			print("Bullet from ", shooter, " hit: ", body.name, " (", body.get_class(), ")")
			print("Body groups: ", body.get_groups())
			print("Hit at position: ", global_position)
			print("Bullet damage: ", damage)
			print("Dealing ", damage, " damage to player")
		body.take_damage(damage)
		queue_free()
		
	elif body.is_in_group("walls"):
		# Hit wall - only print if either debug is enabled
		if debug_player_damage or debug_enemy_damage:
			print("Bullet from ", shooter, " hit wall, destroying bullet")
		queue_free()
		
	elif shooter == "player" and body.name == "Player":
		# ignore
		if debug_player_damage:
			print("Player bullet hit player - ignoring")
		
	else:
		# Hit something else - only print if either debug is enabled
		if debug_player_damage or debug_enemy_damage:
			print("Bullet from ", shooter, " hit something else: ", body.name, " - destroying bullet")
		queue_free()
