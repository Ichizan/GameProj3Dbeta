extends CharacterBody2D
## Generic enemy controller. Faction determines stats + behavior profile.
## Factions: UNDEAD (horde, melee swarm), ELF (ranged, fast, kiting),
## ORC (slow, tanky, heavy melee/elite).

enum Faction { UNDEAD, ELF, ORC }

@export var faction: Faction = Faction.UNDEAD
@export var enemy_name: String = "Skeleton"
@export var bullet_scene: PackedScene  # used by ranged factions (elf)

var max_health: int = 30
var current_health: int
var move_speed: float = 90.0
var attack_damage: int = 8
var attack_range: float = 40.0
var attack_cooldown: float = 1.0
var is_ranged: bool = false
var xp_value: int = 5

var _attack_timer: float = 0.0
var _player: Node2D = null

signal died(enemy: Node)


# Faction stat presets: horde (fast/weak/many), elf (ranged/fast/fragile),
# orc (slow/tanky/heavy hitting, elite).
const FACTION_STATS := {
	Faction.UNDEAD: {
		"max_health": 25, "move_speed": 110.0, "attack_damage": 6,
		"attack_range": 36.0, "attack_cooldown": 0.8, "is_ranged": false, "xp_value": 4,
	},
	Faction.ELF: {
		"max_health": 22, "move_speed": 150.0, "attack_damage": 9,
		"attack_range": 260.0, "attack_cooldown": 1.4, "is_ranged": true, "xp_value": 7,
	},
	Faction.ORC: {
		"max_health": 90, "move_speed": 55.0, "attack_damage": 22,
		"attack_range": 55.0, "attack_cooldown": 1.6, "is_ranged": false, "xp_value": 15,
	},
}


func _ready() -> void:
	_apply_faction_stats()
	current_health = max_health
	add_to_group("enemies")
	add_to_group(_faction_group_name())
	call_deferred("_find_player")


func _apply_faction_stats() -> void:
	var stats: Dictionary = FACTION_STATS.get(faction, FACTION_STATS[Faction.UNDEAD])
	max_health = stats["max_health"]
	move_speed = stats["move_speed"]
	attack_damage = stats["attack_damage"]
	attack_range = stats["attack_range"]
	attack_cooldown = stats["attack_cooldown"]
	is_ranged = stats["is_ranged"]
	xp_value = stats["xp_value"]


func _faction_group_name() -> String:
	match faction:
		Faction.UNDEAD: return "faction_undead"
		Faction.ELF: return "faction_elf"
		Faction.ORC: return "faction_orc"
	return "faction_unknown"


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		call_deferred("_find_player")
		return

	_attack_timer -= delta
	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()

	if distance > attack_range:
		velocity = to_player.normalized() * move_speed
		look_at(_player.global_position)
	else:
		velocity = Vector2.ZERO
		look_at(_player.global_position)
		if _attack_timer <= 0.0:
			_attack()
			_attack_timer = attack_cooldown

	move_and_slide()


func _attack() -> void:
	if is_ranged and bullet_scene:
		var bullet := bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.rotation = rotation
		if bullet.has_method("setup"):
			bullet.setup(rotation, attack_damage, self)
	else:
		if _player and is_instance_valid(_player) and _player.has_method("take_damage"):
			if global_position.distance_to(_player.global_position) <= attack_range + 10.0:
				_player.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		die()


func die() -> void:
	died.emit(self)
	queue_free()
