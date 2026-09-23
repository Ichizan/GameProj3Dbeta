extends Node2D
## Controls wave spawning, mission progress, and extraction for one level.
## Attach to the level's root node. Configure via the exported fields
## in the Inspector (enemy_scene, faction, wave sizes, next_level_path).

signal wave_started(wave_index: int, total_waves: int)
signal wave_cleared(wave_index: int)
signal mission_complete
signal extraction_ready

@export var enemy_scene: PackedScene
@export var faction: int = 0  # matches Enemy.Faction enum (0=UNDEAD,1=ELF,2=ORC)
@export var waves: Array[int] = [5, 8, 12]  # enemies per wave
@export var spawn_interval: float = 0.8
@export var next_level_path: String = ""
@export var level_name: String = "Level"

@onready var spawn_points: Node = get_node_or_null("SpawnPoints")
@onready var extraction_point: Area2D = get_node_or_null("ExtractionPoint")

var _current_wave: int = 0
var _enemies_remaining: int = 0
var _enemies_to_spawn: int = 0
var _spawn_timer: float = 0.0
var _extraction_active: bool = false


func _ready() -> void:
	if extraction_point:
		extraction_point.monitoring = false
		extraction_point.visible = false
		if extraction_point.has_signal("body_entered"):
			extraction_point.body_entered.connect(_on_extraction_body_entered)
	call_deferred("_start_next_wave")


func _process(delta: float) -> void:
	if _enemies_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_one_enemy()
			_spawn_timer = spawn_interval


func _start_next_wave() -> void:
	if _current_wave >= waves.size():
		_activate_extraction()
		return
	_enemies_to_spawn = waves[_current_wave]
	_enemies_remaining = _enemies_to_spawn
	_spawn_timer = 0.0
	wave_started.emit(_current_wave, waves.size())


func _spawn_one_enemy() -> void:
	if enemy_scene == null:
		return
	var point := _get_random_spawn_point()
	var enemy := enemy_scene.instantiate()
	if "faction" in enemy:
		enemy.faction = faction
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = point
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	_enemies_to_spawn -= 1


func _get_random_spawn_point() -> Vector2:
	if spawn_points and spawn_points.get_child_count() > 0:
		var children := spawn_points.get_children()
		var chosen: Node2D = children[randi() % children.size()]
		return chosen.global_position
	return global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))


func _on_enemy_died(_enemy: Node) -> void:
	_enemies_remaining -= 1
	if _enemies_remaining <= 0 and _enemies_to_spawn <= 0:
		wave_cleared.emit(_current_wave)
		_current_wave += 1
		call_deferred("_start_next_wave")


func _activate_extraction() -> void:
	_extraction_active = true
	mission_complete.emit()
	extraction_ready.emit()
	if extraction_point:
		extraction_point.monitoring = true
		extraction_point.visible = true


func _on_extraction_body_entered(body: Node) -> void:
	if not _extraction_active:
		return
	if body.is_in_group("player"):
		_go_to_next_level()


func _go_to_next_level() -> void:
	if next_level_path != "":
		get_tree().change_scene_to_file(next_level_path)
	else:
		print("Campaign complete! No next_level_path set.")
