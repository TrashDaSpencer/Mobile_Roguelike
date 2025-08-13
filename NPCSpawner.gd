# NPCSpawner.gd - Factory class for creating different NPC types
class_name NPCSpawner

# NPC configurations for different types
static var npc_configs = {
	"melee_sweep": {
		"npc_type": NPC.NPCType.MELEE,
		"melee_attack_type": NPC.MeleeAttackType.SWEEP,
		"health": 50,
		"move_speed": 2.5,
		"attack_damage": 20,
		"attack_range": 1.5,
		"attack_cooldown": 2.0
	},
	"melee_stab": {
		"npc_type": NPC.NPCType.MELEE,
		"melee_attack_type": NPC.MeleeAttackType.STAB,
		"health": 45,
		"move_speed": 3.0,
		"attack_damage": 25,
		"attack_range": 1.2,
		"attack_cooldown": 1.5
	},
	"melee_kick": {
		"npc_type": NPC.NPCType.MELEE,
		"melee_attack_type": NPC.MeleeAttackType.KICK,
		"health": 60,
		"move_speed": 2.0,
		"attack_damage": 15,
		"attack_range": 1.8,
		"attack_cooldown": 1.8
	},
	"ranged_aggressive": {
		"npc_type": NPC.NPCType.RANGED_AGGRESSIVE,
		"health": 35,
		"move_speed": 2.2,
		"attack_damage": 18,
		"attack_range": 4.0,
		"attack_cooldown": 1.2,
		"detection_range": 12.0
	},
	"ranged_defensive": {
		"npc_type": NPC.NPCType.RANGED_DEFENSIVE,
		"health": 40,
		"move_speed": 1.8,
		"attack_damage": 22,
		"attack_range": 5.0,
		"attack_cooldown": 1.0,
		"detection_range": 15.0
	}
}

static func create_npc_with_scaling(npc_key: String, is_boss: bool = false, level: int = 1) -> NPC:
	if not npc_configs.has(npc_key):
		print("Warning: Unknown NPC type: ", npc_key)
		npc_key = "melee_sweep"  # Default fallback
	
	var config = npc_configs[npc_key]
	var npc_scene = preload("res://NPC.tscn")  # Your NPC scene file
	var npc = npc_scene.instantiate()
	
	# Apply configuration with scaling
	apply_config_with_scaling(npc, config, is_boss, level)
	
	print("Created NPC: ", npc_key, " (Boss: ", is_boss, ", Level: ", level, ")")
	return npc

static func create_npc(npc_key: String, is_boss: bool = false) -> NPC:
	# Legacy method for compatibility
	return create_npc_with_scaling(npc_key, is_boss, 1)

static func apply_config_with_scaling(npc: NPC, config: Dictionary, is_boss: bool, level: int):
	# Set NPC type and properties
	npc.npc_type = config.get("npc_type", NPC.NPCType.MELEE)
	npc.is_boss = is_boss
	
	if config.has("melee_attack_type"):
		npc.melee_attack_type = config["melee_attack_type"]
	
	# Calculate scaling multipliers based on bosses defeated
	var scaling_tier = get_scaling_tier(level)
	var health_multiplier = pow(2.0, scaling_tier)  # 2x per tier
	var damage_multiplier = pow(2.0, scaling_tier)  # 2x per tier
	var exp_multiplier = pow(2.5, scaling_tier)     # 2.5x per tier
	var coin_multiplier = pow(1.5, scaling_tier)    # 1.5x per tier
	
	# Base item drop chance starts at 5% and increases 5% per tier
	var base_item_drop_chance = 0.05
	var item_drop_bonus = scaling_tier * 0.05
	
	print("Scaling tier: ", scaling_tier)
	print("Health multiplier: ", health_multiplier)
	print("Damage multiplier: ", damage_multiplier)
	print("Exp multiplier: ", exp_multiplier)
	print("Coin multiplier: ", coin_multiplier)
	print("Item drop chance: ", base_item_drop_chance + item_drop_bonus)
	
	# Apply base stats with scaling
	var base_health = config.get("health", 50)
	npc.health = int(base_health * health_multiplier)
	npc.max_health = npc.health
	
	npc.move_speed = config.get("move_speed", 2.0)  # Speed doesn't scale
	
	var base_damage = config.get("attack_damage", 15)
	npc.attack_damage = int(base_damage * damage_multiplier)
	
	npc.melee_attack_range = config.get("melee_attack_range", 1.5)
	npc.range_attack_range = config.get("range_attack_range", 10.0)
	npc.attack_cooldown = config.get("attack_cooldown", 1.5)
	npc.detection_range = config.get("detection_range", 50.0)
	
	# Apply scaled drop rewards
	npc.exp_drop_amount = int(25 * exp_multiplier)  # Base 25 exp
	npc.coin_drop_amount = int(10 * coin_multiplier)  # Base 10 coins
	
	# Update drop chances
	npc.item_drop_chance = min(base_item_drop_chance + item_drop_bonus, 0.95)  # Cap at 95%
	npc.health_drop_chance = min(0.4 + (item_drop_bonus * 0.5), 0.8)  # Health drops also improve slightly

static func get_scaling_tier(level: int) -> int:
	# Each boss defeated (every 10 levels) increases the tier
	return (level - 1) / 10  # Level 1-10 = tier 0, 11-20 = tier 1, etc.

static func get_random_npc_type() -> String:
	var types = npc_configs.keys()
	return types[randi() % types.size()]

static func get_weighted_random_npc_type(level_number: int) -> String:
	# Adjust spawn chances based on level
	var weights = {}
	
	if level_number <= 2:
		# Early levels: mostly melee
		weights = {
			"melee_sweep": 40,
			"melee_stab": 30,
			"melee_kick": 20,
			"ranged_aggressive": 10,
			"ranged_defensive": 0
		}
	elif level_number <= 5:
		# Mid levels: mixed
		weights = {
			"melee_sweep": 25,
			"melee_stab": 25,
			"melee_kick": 20,
			"ranged_aggressive": 20,
			"ranged_defensive": 10
		}
	else:
		# Later levels: more ranged
		weights = {
			"melee_sweep": 15,
			"melee_stab": 15,
			"melee_kick": 20,
			"ranged_aggressive": 25,
			"ranged_defensive": 25
		}
	
	# Calculate total weight
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	# Random selection
	var random_value = randi() % total_weight
	var current_weight = 0
	
	for npc_type in weights.keys():
		current_weight += weights[npc_type]
		if random_value < current_weight:
			return npc_type
	
	return "melee_sweep"  # Fallback
