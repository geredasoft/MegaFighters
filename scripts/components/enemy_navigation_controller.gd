extends RefCounted

## Ejecuta navegación táctica; el actor conserva la máquina de estados.
var _agente: CharacterBody2D
var _sprite: AnimatedSprite2D
var _sensor
var _separacion
var _animar_movimiento: Callable
var _reproducir_animacion: Callable
var _actualizar_hitbox: Callable
var _cambiar_estado: Callable
var _preparar_ataque: Callable
var _intentar_interceptar: Callable
var _config: Dictionary


func _init(
	agente: CharacterBody2D,
	sprite: AnimatedSprite2D,
	sensor,
	separacion,
	callbacks: Dictionary,
	config: Dictionary
) -> void:
	_agente = agente
	_sprite = sprite
	_sensor = sensor
	_separacion = separacion
	_animar_movimiento = callbacks["animar_movimiento"]
	_reproducir_animacion = callbacks["reproducir_animacion"]
	_actualizar_hitbox = callbacks["actualizar_hitbox"]
	_cambiar_estado = callbacks["cambiar_estado"]
	_preparar_ataque = callbacks["preparar_ataque"]
	_intentar_interceptar = callbacks["intentar_interceptar"]
	_config = config


func ejecutar_patrulla(
	delta: float,
	direccion: float,
	origen_x: float,
	tiempo_espera: float
) -> Dictionary:
	var desplazamiento: float = _agente.global_position.x - origen_x
	var llego_al_limite: bool = (
		absf(desplazamiento) >= _config["distancia_patrulla"]
		and signf(desplazamiento) == direccion
	)
	var borde: bool = not _sensor.hay_suelo(direccion, 24.0)
	var pared: bool = _sensor.hay_pared(direccion, 20.0)
	if llego_al_limite or borde or pared:
		_agente.velocity.x = move_toward(
			_agente.velocity.x, 0.0, _config["desaceleracion"] * delta
		)
		_reproducir_animacion.call("standing")
		return {
			"estado": "espera",
			"timer": _config["tiempo_espera"]
		}
	_agente.velocity.x = move_toward(
		_agente.velocity.x,
		direccion * _config["velocidad_trote"],
		_config["aceleracion"] * delta
	)
	_sprite.flip_h = direccion < 0.0
	_animar_movimiento.call(false)
	return {"estado": "" , "timer": tiempo_espera}


func ejecutar_espera(delta: float, timer: float, origen_x: float, direccion: float) -> Dictionary:
	_agente.velocity.x = move_toward(
		_agente.velocity.x, 0.0, _config["desaceleracion"] * delta
	)
	_reproducir_animacion.call("standing")
	timer -= delta
	if timer <= 0.0:
		direccion *= -1.0
		origen_x = _agente.global_position.x
		return {"estado": "patrulla", "timer": timer, "origen_x": origen_x, "direccion": direccion}
	return {"estado": "", "timer": timer, "origen_x": origen_x, "direccion": direccion}


func ejecutar_persecucion(delta: float, jugador: CharacterBody2D) -> void:
	if jugador == null or not is_instance_valid(jugador):
		_cambiar_estado.call("patrulla")
		return
	var diferencia_x: float = jugador.global_position.x - _agente.global_position.x
	var distancia_x: float = absf(diferencia_x)
	var direccion_x: float = signf(diferencia_x)
	if is_zero_approx(direccion_x):
		_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, _config["desaceleracion"] * delta)
		_reproducir_animacion.call("standing")
		return
	_sprite.flip_h = direccion_x < 0.0
	_actualizar_hitbox.call()
	var suelo_delante: bool = _sensor.hay_suelo(direccion_x, 28.0)
	var pared: bool = _sensor.hay_pared(direccion_x, 24.0)
	var jugador_mas_alto: bool = jugador.global_position.y < _agente.global_position.y - 25.0
	if _agente.is_on_floor() and (pared or (jugador_mas_alto and distancia_x <= _config["distancia_salto"])):
		if _sensor.hay_espacio_para_saltar(direccion_x):
			_agente.velocity.y = _config["fuerza_salto"]
			_agente.velocity.x = direccion_x * _config["velocidad_trote"]
			_reproducir_animacion.call("jump")
			return
	if not suelo_delante and _agente.is_on_floor():
		_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, _config["desaceleracion"] * delta)
		_reproducir_animacion.call("standing")
		_intentar_interceptar.call(true)
		return
	var velocidad_objetivo: float = _config["velocidad_carrera"] if distancia_x > 140.0 else _config["velocidad_trote"]
	var fuerza_separacion: Vector2 = _separacion.calcular_separacion(
		_config["distancia_separacion"], _config["fuerza_separacion"]
	)
	var velocidad_persecucion: float = direccion_x * velocidad_objetivo + fuerza_separacion.x
	_agente.velocity.x = move_toward(_agente.velocity.x, velocidad_persecucion, _config["aceleracion"] * delta)
	_animar_movimiento.call(velocidad_objetivo == _config["velocidad_carrera"])


func ejecutar_posicionamiento(delta: float, jugador: CharacterBody2D, cooldown_ataque: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		_cambiar_estado.call("patrulla")
		return
	var diferencia_x: float = jugador.global_position.x - _agente.global_position.x
	var diferencia_y: float = jugador.global_position.y - _agente.global_position.y
	var distancia_x: float = absf(diferencia_x)
	var direccion_x: float = signf(diferencia_x)
	if is_zero_approx(direccion_x):
		_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, _config["desaceleracion"] * delta)
		_reproducir_animacion.call("standing")
		return
	if distancia_x > _config["distancia_ataque"] or distancia_x > _config["distancia_combate_minima"]:
		_cambiar_estado.call("perseguir")
		return
	_sprite.flip_h = direccion_x < 0.0
	_actualizar_hitbox.call()
	if distancia_x <= _config["distancia_ataque"] and absf(diferencia_y) <= 45.0 and cooldown_ataque <= 0.0 and _agente.is_on_floor():
		_preparar_ataque.call()
		return
	if distancia_x < _config["distancia_retroceso"]:
		_agente.velocity.x = move_toward(
			_agente.velocity.x,
			-direccion_x * _config["velocidad_trote"] * 0.45,
			_config["desaceleracion"] * delta
		)
		_animar_movimiento.call(false)
		return
	_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, _config["desaceleracion"] * delta)
	_reproducir_animacion.call("standing")
