extends RefCounted

const AttackHitboxControllerScript = preload(
	"res://scripts/components/attack_hitbox_controller.gd"
)

var _player: Danable
var _sprite: AnimatedSprite2D
var _collision_hitbox: CollisionShape2D
var _input_controller
var _hit_processor
var _hitbox_controller
var _set_normal_state: Callable
var _set_attack_state: Callable
var _play_animation: Callable

var _hitbox_active: bool = false
var _attack_held: bool = false
var _frame_start: int
var _frame_end: int
var _attack_speed: float
var _ground_acceleration: float
var _ground_friction: float
var _jump_force: float
var _damage: int
var _horizontal_knockback: float
var _vertical_knockback: float
var _hitbox_offset_x: float


func _init(
	player: Danable,
	sprite: AnimatedSprite2D,
	hitbox: Area2D,
	collision_hitbox: CollisionShape2D,
	input_controller,
	hit_processor,
	set_normal_state: Callable,
	set_attack_state: Callable,
	play_animation: Callable,
	config: Dictionary
) -> void:
	_player = player
	_sprite = sprite
	_collision_hitbox = collision_hitbox
	_input_controller = input_controller
	_hit_processor = hit_processor
	_hitbox_controller = AttackHitboxControllerScript.new(
		hitbox,
		collision_hitbox
	)
	_set_normal_state = set_normal_state
	_set_attack_state = set_attack_state
	_play_animation = play_animation
	_frame_start = int(config["frame_start"])
	_frame_end = int(config["frame_end"])
	_attack_speed = float(config["attack_speed"])
	_ground_acceleration = float(config["ground_acceleration"])
	_ground_friction = float(config["ground_friction"])
	_jump_force = float(config["jump_force"])
	_damage = int(config["damage"])
	_horizontal_knockback = float(config["horizontal_knockback"])
	_vertical_knockback = float(config["vertical_knockback"])
	_hitbox_offset_x = float(config["hitbox_offset_x"])


func procesar_estado_ataque(delta: float) -> void:
	_attack_held = bool(_input_controller.call("esta_atacando"))

	if bool(_input_controller.call("presiono_salto")) and _player.is_on_floor():
		terminar_ataque()
		_set_normal_state.call()
		_player.velocity.y = _jump_force
		return

	if bool(_input_controller.call("esta_agachado")):
		terminar_ataque()
		_set_normal_state.call()
		_play_animation.call("ducking")
		return

	var direccion: float = float(
		_input_controller.call("obtener_input_horizontal")
	)
	if direccion != 0.0:
		_player.velocity.x = move_toward(
			_player.velocity.x,
			direccion * _attack_speed,
			_ground_acceleration * delta
		)
		_sprite.flip_h = direccion < 0.0
		actualizar_direccion_hitbox()
	else:
		_player.velocity.x = move_toward(
			_player.velocity.x,
			0.0,
			_ground_friction * delta
		)

	_actualizar_ventana_ataque()


func _actualizar_ventana_ataque() -> void:
	if _sprite.animation != "attack":
		desactivar_hitbox_ataque()
		return

	var golpe_activo: bool = (
		_sprite.frame >= _frame_start
		and _sprite.frame <= _frame_end
	)
	if golpe_activo != _hitbox_active:
		print("ATAQUE | Frame: ", _sprite.frame, " | Hitbox: ", golpe_activo)

	if golpe_activo:
		activar_hitbox_ataque()
	else:
		desactivar_hitbox_ataque()


func activar_hitbox_ataque() -> void:
	if _hitbox_active:
		return

	_hitbox_active = true
	_hitbox_controller.activar()


func desactivar_hitbox_ataque() -> void:
	if not _hitbox_active:
		return

	_hitbox_active = false
	_hitbox_controller.desactivar()


func iniciar_ataque() -> void:
	_set_attack_state.call()
	_player.velocity.x = 0.0
	_attack_held = true
	_hit_processor.limpiar_objetivos()
	desactivar_hitbox_ataque()
	_sprite.frame = 0
	_play_animation.call("attack")
	print("⚔️ ATAQUE INICIADO")


func terminar_ataque() -> void:
	desactivar_hitbox_ataque()
	_attack_held = false
	_hit_processor.limpiar_objetivos()


func actualizar_direccion_hitbox() -> void:
	_collision_hitbox.position.x = (
		-_hitbox_offset_x if _sprite.flip_h else _hitbox_offset_x
	)
	_collision_hitbox.position.y = -2.0


func procesar_golpe(area: Area2D, esta_en_ataque: bool) -> void:
	if not esta_en_ataque or not _hitbox_active or _collision_hitbox.disabled:
		return

	var direccion_empuje: float = -1.0 if _sprite.flip_h else 1.0
	_hit_processor.procesar_golpe(
		area,
		_player,
		"enemy_hurtbox",
		PackedStringArray(["enemy"]),
		_damage,
		_horizontal_knockback,
		_vertical_knockback,
		direccion_empuje,
		true,
		_sprite.frame
	)
