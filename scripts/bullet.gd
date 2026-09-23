extends Area2D
## Simple magic projectile. Moves forward along its rotation, damages the
## first valid target it hits, and self-destructs after a lifetime or hit.

@export var speed: float = 700.0
@export var lifetime: float = 2.0

var damage: int = 10
var _shooter: Node = null
var _age: float = 0.0


func setup(dir_rotation: float, dmg: int, shooter: Node) -> void:
	rotation = dir_rotation
	damage = dmg
	_shooter = shooter


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Node) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	if target == _shooter:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()
