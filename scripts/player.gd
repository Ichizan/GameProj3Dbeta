extends CharacterBody2D
## Top-down magic shooter player controller (Helldivers-style).
## Movement: WASD. Aim/Shoot: Mouse. Stratagems: arrow-key sequences.

signal health_changed(current: int, max: int)
signal died

@export var move_speed: float = 260.0
@export var max_health: int = 100
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.18
@export var bullet_damage: int = 12

var current_health: int
var _fire_timer: float = 0.0

# --- Stratagem system -------------------------------------------------
# Each stratagem is a sequence of "ui_up"/"ui_down"/"ui_left"/"ui_right".
# Input buffer resets after STRATAGEM_INPUT_TIMEOUT seconds of inactivity.
const STRATAGEM_INPUT_TIMEOUT: float = 1.5
var _input_buffer: Array[String] = []
var _input_buffer_timer: float = 0.0

var stratagems: Dictionary = {
	"orbital_strike": {
		"code": ["ui_up", "ui_up", "ui_down", "ui_right"],
		"cooldown": 8.0,
	},
	"support_turret": {
		"code": ["ui_down", "ui_up", "ui_left", "ui_left"],
		"cooldown": 15.0,
	},
}
var _stratagem_cooldowns: Dictionary = {}

signal stratagem_called(stratagem_name: String)
signal stratagem_ready(stratagem_name: String)

@export var orbital_strike_scene: PackedScene
@export var turret_scene: PackedScene


func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	health_changed.emit(current_health, max_health)
	for key in stratagems.keys():
		_stratagem_cooldowns[key] = 0.0


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_aim()
	_handle_shooting(delta)
	_update_stratagem_cooldowns(delta)
	_update_input_buffer(delta)


func _handle_movement(_delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	move_and_slide()


func _handle_aim() -> void:
	# Rotate the player to face the mouse cursor (top-down aiming).
	var mouse_pos := get_global_mouse_position()
	look_at(mouse_pos)


func _handle_shooting(delta: float) -> void:
	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_fire_bullet()
		_fire_timer = fire_cooldown


func _fire_bullet() -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.rotation = rotation
	if bullet.has_method("setup"):
		bullet.setup(rotation, bullet_damage, self)


# --- Stratagem input handling ------------------------------------------

func _update_input_buffer(delta: float) -> void:
	var pressed_dir := ""
	if Input.is_action_just_pressed("ui_up"):
		pressed_dir = "ui_up"
	elif Input.is_action_just_pressed("ui_down"):
		pressed_dir = "ui_down"
	elif Input.is_action_just_pressed("ui_left"):
		pressed_dir = "ui_left"
	elif Input.is_action_just_pressed("ui_right"):
		pressed_dir = "ui_right"

	if pressed_dir != "":
		_input_buffer.append(pressed_dir)
		_input_buffer_timer = STRATAGEM_INPUT_TIMEOUT
		_check_stratagem_match()
		# Keep buffer bounded to the longest known code length.
		var max_len := 0
		for key in stratagems.keys():
			max_len = max(max_len, stratagems[key]["code"].size())
		while _input_buffer.size() > max_len:
			_input_buffer.pop_front()
	else:
		if _input_buffer_timer > 0.0:
			_input_buffer_timer -= delta
			if _input_buffer_timer <= 0.0:
				_input_buffer.clear()


func _check_stratagem_match() -> void:
	for key in stratagems.keys():
		var code: Array = stratagems[key]["code"]
		if _input_buffer.size() < code.size():
			continue
		var tail := _input_buffer.slice(_input_buffer.size() - code.size(), _input_buffer.size())
		if tail == code:
			_try_call_stratagem(key)
			_input_buffer.clear()


func _try_call_stratagem(stratagem_name: String) -> void:
	if _stratagem_cooldowns.get(stratagem_name, 0.0) > 0.0:
		return
	_stratagem_cooldowns[stratagem_name] = stratagems[stratagem_name]["cooldown"]
	stratagem_called.emit(stratagem_name)
	match stratagem_name:
		"orbital_strike":
			_call_orbital_strike()
		"support_turret":
			_call_support_turret()


func _update_stratagem_cooldowns(delta: float) -> void:
	for key in _stratagem_cooldowns.keys():
		if _stratagem_cooldowns[key] > 0.0:
			_stratagem_cooldowns[key] -= delta
			if _stratagem_cooldowns[key] <= 0.0:
				_stratagem_cooldowns[key] = 0.0
				stratagem_ready.emit(key)


func _call_orbital_strike() -> void:
	# Drops a magic bombardment centered on the mouse position after a short delay.
	var target_pos := get_global_mouse_position()
	if orbital_strike_scene:
		var fx := orbital_strike_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = target_pos
	else:
		call_deferred("_fallback_area_damage", target_pos, 120.0, 60)


func _call_support_turret() -> void:
	var spawn_pos := global_position + Vector2(0, -60).rotated(rotation)
	if turret_scene:
		var turret := turret_scene.instantiate()
		get_tree().current_scene.add_child(turret)
		turret.global_position = spawn_pos


func _fallback_area_damage(center: Vector2, radius: float, damage: int) -> void:
	for body in get_tree().get_nodes_in_group("enemies"):
		if body.global_position.distance_to(center) <= radius:
			if body.has_method("take_damage"):
				body.take_damage(damage)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()
		queue_free()
