extends RefCounted

var _player: CharacterBody2D
var _sprite: AnimatedSprite2D
var _input_controller
var _procesar_escalera: Callable
var _iniciar_ataque: Callable
var _actualizar_hitbox: Callable
var _actualizar_animacion: Callable
var _reproducir_animacion: Callable
var _set_normal_state: Callable
var _set_roll_state: Callable

var _velocidad_agachado: float
var _velocidad_trote: float
var _velocidad_carrera: float
var _aceleracion_suelo: float
var _aceleracion_aire: float
var _friccion_suelo: float
var _friccion_aire: float
var _fuerza_salto: float
var _velocidad_roll: float
var _fuerza_roll: float
var _friccion_roll: float
var _tiempo_max_roll: float

var _direccion_roll: float = 1.0
var _animacion_roll_terminada: bool = false
var _tiempo_roll: float = 0.0


func _init(
	player: CharacterBody2D,
	sprite: AnimatedSprite2D,
	input_controller,
	procesar_escalera: Callable,
	iniciar_ataque: Callable,
	actualizar_hitbox: Callable,
	actualizar_animacion: Callable,
	reproducir_animacion: Callable,
	set_normal_state: Callable,
	set_roll_state: Callable,
	config: Dictionary
) -> void:
	_player = player
	_sprite = sprite
	_input_controller = input_controller
	_procesar_escalera = procesar_escalera
	_iniciar_ataque = iniciar_ataque
	_actualizar_hitbox = actualizar_hitbox
	_actualizar_animacion = actualizar_animacion
	_reproducir_animacion = reproducir_animacion
	_set_normal_state = set_normal_state
	_set_roll_state = set_roll_state
	_velocidad_agachado = float(config["velocidad_agachado"])
	_velocidad_trote = float(config["velocidad_trote"])
	_velocidad_carrera = float(config["velocidad_carrera"])
	_aceleracion_suelo = float(config["aceleracion_suelo"])
	_aceleracion_aire = float(config["aceleracion_aire"])
	_friccion_suelo = float(config["friccion_suelo"])
	_friccion_aire = float(config["friccion_aire"])
	_fuerza_salto = float(config["fuerza_salto"])
	_velocidad_roll = float(config["velocidad_roll"])
	_fuerza_roll = float(config["fuerza_roll"])
	_friccion_roll = float(config["friccion_roll"])
	_tiempo_max_roll = float(config["tiempo_max_roll"])


func procesar_estado_normal(delta: float) -> void:
	if _procesar_escalera.call():
		return

	var direccion: float = float(
		_input_controller.call("obtener_input_horizontal")
	)
	var agachado: bool = bool(_input_controller.call("esta_agachado"))
	var corriendo: bool = bool(_input_controller.call("esta_corriendo"))

	if agachado and _player.is_on_floor() and bool(
		_input_controller.call("presiono_salto")
	):
		iniciar_roll_dive(direccion)
		return

	if bool(_input_controller.call("presiono_ataque")) and _player.is_on_floor():
		_iniciar_ataque.call()
		return

	if (
		_player.is_on_floor()
		and not agachado
		and bool(_input_controller.call("presiono_salto"))
	):
		_player.velocity.y = _fuerza_salto

	_procesar_movimiento_horizontal(direccion, agachado, corriendo, delta)
	_actualizar_animacion.call(direccion, agachado, corriendo)


func _procesar_movimiento_horizontal(
	direccion: float,
	agachado: bool,
	corriendo: bool,
	delta: float
) -> void:
	if direccion != 0.0:
		var velocidad_objetivo: float = _velocidad_trote
		if agachado:
			velocidad_objetivo = _velocidad_agachado
		elif corriendo:
			velocidad_objetivo = _velocidad_carrera

		velocidad_objetivo *= direccion
		var aceleracion: float = (
			_aceleracion_suelo
			if _player.is_on_floor()
			else _aceleracion_aire
		)
		_player.velocity.x = move_toward(
			_player.velocity.x,
			velocidad_objetivo,
			aceleracion * delta
		)
		_sprite.flip_h = direccion < 0.0
		_actualizar_hitbox.call()
	else:
		var friccion: float = (
			_friccion_suelo
			if _player.is_on_floor()
			else _friccion_aire
		)
		_player.velocity.x = move_toward(
			_player.velocity.x,
			0.0,
			friccion * delta
		)


func procesar_estado_roll_dive(delta: float) -> void:
	_tiempo_roll += delta
	_player.velocity.x = move_toward(
		_player.velocity.x,
		0.0,
		_friccion_roll * delta
	)

	if (
		_animacion_roll_terminada and _player.is_on_floor()
	) or _tiempo_roll >= _tiempo_max_roll:
		finalizar_roll_dive()


func iniciar_roll_dive(direccion: float) -> void:
	_set_roll_state.call()
	_animacion_roll_terminada = false
	_tiempo_roll = 0.0
	_direccion_roll = (
		signf(direccion)
		if direccion != 0.0
		else (-1.0 if _sprite.flip_h else 1.0)
	)
	_sprite.flip_h = _direccion_roll < 0.0
	_player.velocity.x = _direccion_roll * _velocidad_roll
	_player.velocity.y = _fuerza_roll
	_sprite.stop()
	_reproducir_animacion.call("roll_dive")


func finalizar_roll_dive() -> void:
	_animacion_roll_terminada = false
	_tiempo_roll = 0.0
	_player.velocity.x = 0.0
	_set_normal_state.call()
	_reproducir_animacion.call("standing")


func marcar_animacion_roll_terminada() -> void:
	_animacion_roll_terminada = true
