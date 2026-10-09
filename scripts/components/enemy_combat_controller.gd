extends RefCounted

const AttackHitboxControllerScript = preload(
	"res://scripts/components/attack_hitbox_controller.gd"
)

var _enemy: Danable
var _sprite: AnimatedSprite2D
var _hitbox: Area2D
var _collision_shape: CollisionShape2D
var _hit_processor
var _hitbox_controller
var _hitbox_active: bool = false
var _frame_start: int
var _frame_end: int
var _damage: int
var _horizontal_knockback: float
var _vertical_knockback: float
var _hitbox_offset_x: float
var _hitbox_offset_y: float


func _init(
	enemy: Danable,
	sprite: AnimatedSprite2D,
	hitbox: Area2D,
	collision_shape: CollisionShape2D,
	hit_processor,
	config: Dictionary
) -> void:
	_enemy = enemy
	_sprite = sprite
	_hitbox = hitbox
	_collision_shape = collision_shape
	_hit_processor = hit_processor
	_hitbox_controller = AttackHitboxControllerScript.new(
		hitbox,
		collision_shape
	)
	_frame_start = int(config["frame_start"])
	_frame_end = int(config["frame_end"])
	_damage = int(config["damage"])
	_horizontal_knockback = float(config["horizontal_knockback"])
	_vertical_knockback = float(config["vertical_knockback"])
	_hitbox_offset_x = float(config["hitbox_offset_x"])
	_hitbox_offset_y = float(config["hitbox_offset_y"])


func actualizar_ventana_ataque() -> void:
	if _sprite.animation != "attack":
		desactivar_hitbox_ataque()
		return

	var golpe_activo: bool = (
		_sprite.frame >= _frame_start
		and _sprite.frame <= _frame_end
	)
	if golpe_activo:
		activar_hitbox_ataque()
		procesar_hurtboxes_superpuestas()
	else:
		desactivar_hitbox_ataque()


func activar_hitbox_ataque() -> void:
	if _hitbox_active:
		return
	_hitbox_active = true
	_hitbox_controller.activar()


func desactivar_hitbox_ataque() -> void:
	_hitbox_active = false
	_hitbox_controller.desactivar()


func esta_activo() -> bool:
	return _hitbox_active


func actualizar_direccion_hitbox() -> void:
	if _collision_shape == null:
		return
	_collision_shape.position.x = (
		-_hitbox_offset_x if _sprite.flip_h else _hitbox_offset_x
	)
	_collision_shape.position.y = _hitbox_offset_y


func procesar_hurtbox_player(area: Area2D) -> void:
	var direccion_empuje: float = -1.0 if _sprite.flip_h else 1.0
	_hit_processor.procesar_golpe(
		area,
		_enemy,
		"player_hurtbox",
		PackedStringArray(["Player", "player"]),
		_damage,
		_horizontal_knockback,
		_vertical_knockback,
		direccion_empuje
	)


func procesar_hurtboxes_superpuestas() -> void:
	if not _hitbox_active or not _hitbox.monitoring:
		return

	for area: Area2D in _hitbox.get_overlapping_areas():
		procesar_hurtbox_player(area)
