extends RefCounted

const LadderRegistryScript = preload(
	"res://scripts/components/ladder_registry.gd"
)

var _player: CharacterBody2D
var _sprite: AnimatedSprite2D
var _input_controller
var _registro_escaleras = LadderRegistryScript.new()
var _cambiar_estado: Callable
var _reproducir_animacion: Callable
var _estado_normal: int
var _estado_escalando: int
var _velocidad_trote: float
var _velocidad_escalera: float
var _fuerza_salto: float
var _escala_normal: Vector2
var _escala_climb: Vector2
var _offset_climb: Vector2
var _escalera_actual: Area2D
var _direccion_escalera: float = 0.0
var _bloquear_reentrada: bool = false


func _init(
	player: CharacterBody2D,
	sprite: AnimatedSprite2D,
	input_controller,
	cambiar_estado: Callable,
	reproducir_animacion: Callable,
	estado_normal: int,
	estado_escalando: int,
	velocidad_trote: float,
	velocidad_escalera: float,
	fuerza_salto: float,
	escala_normal: Vector2,
	escala_climb: Vector2,
	offset_climb: Vector2
) -> void:
	_player = player
	_sprite = sprite
	_input_controller = input_controller
	_cambiar_estado = cambiar_estado
	_reproducir_animacion = reproducir_animacion
	_estado_normal = estado_normal
	_estado_escalando = estado_escalando
	_velocidad_trote = velocidad_trote
	_velocidad_escalera = velocidad_escalera
	_fuerza_salto = fuerza_salto
	_escala_normal = escala_normal
	_escala_climb = escala_climb
	_offset_climb = offset_climb


func procesar_entrada_escalera() -> bool:
	if _bloquear_reentrada:
		var horizontal: float = float(
			_input_controller.obtener_input_horizontal()
		)
		var vertical: float = _obtener_direccion_vertical()
		if is_zero_approx(horizontal) and is_zero_approx(vertical):
			_bloquear_reentrada = false
		else:
			return false

	if not _registro_escaleras.tiene_cercanas():
		return false

	var escalera := obtener_escalera()
	if escalera == null:
		return false

	var quiere_subir: bool = _input_controller.mantiene_subir()
	var quiere_bajar: bool = _input_controller.mantiene_bajar()

	if quiere_subir and escalera.get("permitir_subir"):
		iniciar_escalada(escalera)
		return true

	if quiere_bajar and escalera.get("permitir_bajar"):
		iniciar_escalada(escalera)
		return true

	return false


func procesar_estado_escalando(direccion_horizontal: float, presiono_salto: bool) -> void:
	if _escalera_actual == null:
		finalizar_escalada()
		return

	var direccion_vertical: float = _obtener_direccion_vertical()
	if not is_zero_approx(direccion_horizontal) and not is_zero_approx(direccion_vertical):
		_bloquear_reentrada = true
		finalizar_escalada()
		_player.velocity.x = direccion_horizontal * _velocidad_trote
		_sprite.flip_h = direccion_horizontal < 0.0
		if direccion_vertical < 0.0:
			_player.velocity.y = _fuerza_salto
		else:
			_player.velocity.y = 0.0
		return

	if presiono_salto:
		finalizar_escalada()
		_player.velocity.y = _fuerza_salto
		return

	if direccion_horizontal != 0.0:
		finalizar_escalada()
		_player.velocity.x = direccion_horizontal * _velocidad_trote
		_sprite.flip_h = direccion_horizontal < 0.0
		return

	_direccion_escalera = direccion_vertical

	_player.velocity.x = 0.0
	_player.velocity.y = _direccion_escalera * _velocidad_escalera

	if not _sprite.sprite_frames.has_animation("climb"):
		return

	if _direccion_escalera < 0.0:
		_reproducir_animacion.call("climb")
	elif _direccion_escalera > 0.0:
		_reproducir_animacion.call("climb", true)
	else:
		_sprite.pause()


func _obtener_direccion_vertical() -> float:
	if _input_controller.mantiene_subir():
		return -1.0
	if _input_controller.mantiene_bajar():
		return 1.0
	return 0.0


func iniciar_escalada(escalera: Area2D) -> void:
	if escalera == null:
		return

	_escalera_actual = escalera
	_cambiar_estado.call(_estado_escalando)
	_player.velocity = Vector2.ZERO
	_player.global_position.x = escalera.global_position.x
	_sprite.scale = _escala_climb
	_sprite.position = _offset_climb

	if _sprite.sprite_frames.has_animation("climb"):
		_reproducir_animacion.call("climb")
	else:
		_reproducir_animacion.call("standing")


func finalizar_escalada() -> void:
	_escalera_actual = null
	_direccion_escalera = 0.0
	_player.velocity.y = 0.0
	_sprite.scale = _escala_normal
	_sprite.position = Vector2.ZERO
	_cambiar_estado.call(_estado_normal)
	_reproducir_animacion.call("standing")


func obtener_escalera() -> Area2D:
	return _registro_escaleras.obtener(_escalera_actual)


func entrar_en_escalera(escalera: Area2D) -> void:
	_registro_escaleras.registrar(escalera)


func salir_de_escalera(escalera: Area2D) -> void:
	if escalera == null:
		return

	_registro_escaleras.desregistrar(escalera)
	if _escalera_actual == escalera:
		finalizar_escalada()
