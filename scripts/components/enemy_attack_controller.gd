extends RefCounted

## Máquina de fases del ataque; el actor conserva el enum público de estados.
var _agente: CharacterBody2D
var _sprite: AnimatedSprite2D
var _procesador_golpes
var _combate
var _estado: Callable
var _animacion: Callable
var _actualizar_hitbox: Callable
var _timer_ataque: float = 0.0
var _cooldown: float = 0.0
var _impulso_aplicado: bool = false
var _config: Dictionary


func _init(agente: CharacterBody2D, sprite: AnimatedSprite2D, procesador_golpes, combate, callbacks: Dictionary, config: Dictionary) -> void:
	_agente = agente
	_sprite = sprite
	_procesador_golpes = procesador_golpes
	_combate = combate
	_estado = callbacks["cambiar_estado"]
	_animacion = callbacks["reproducir_animacion"]
	_actualizar_hitbox = callbacks["actualizar_hitbox"]
	_config = config


func actualizar_timers(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func obtener_cooldown() -> float:
	return _cooldown


func preparar(jugador: CharacterBody2D) -> void:
	if jugador == null or not is_instance_valid(jugador) or _cooldown > 0.0:
		return
	_estado.call("anticipando")
	_timer_ataque = _config["windup"]
	_agente.velocity.x = 0.0
	var direccion: float = signf(jugador.global_position.x - _agente.global_position.x)
	if not is_zero_approx(direccion):
		_sprite.flip_h = direccion < 0.0
		_actualizar_hitbox.call()
	_animacion.call("standing")


func ejecutar_anticipacion(delta: float, desaceleracion: float, jugador: CharacterBody2D) -> void:
	_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, desaceleracion * delta)
	_timer_ataque -= delta
	if _timer_ataque <= 0.0:
		iniciar(jugador)


func iniciar(jugador: CharacterBody2D) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	_estado.call("atacando")
	_agente.velocity.x = 0.0
	_procesador_golpes.limpiar_objetivos()
	_combate.desactivar_hitbox_ataque()
	_impulso_aplicado = false
	_sprite.frame = 0
	_animacion.call("attack")


func ejecutar_ataque(delta: float) -> void:
	var direccion: float = -1.0 if _sprite.flip_h else 1.0
	if not _impulso_aplicado:
		_agente.velocity.x = direccion * _config["impulso"]
		_impulso_aplicado = true
	else:
		_agente.velocity.x = move_toward(
			_agente.velocity.x, 0.0, _config["frenado"] * delta
		)
	_combate.actualizar_ventana_ataque()


func ejecutar_recuperacion(delta: float, desaceleracion: float, jugador: CharacterBody2D, puede_ver: bool) -> void:
	_agente.velocity.x = move_toward(_agente.velocity.x, 0.0, desaceleracion * delta)
	_animacion.call("standing")
	_timer_ataque -= delta
	if _timer_ataque > 0.0:
		return
	if jugador != null and is_instance_valid(jugador) and puede_ver:
		_estado.call("perseguir")
	else:
		_estado.call("patrulla")


func finalizar_animacion_ataque(tiempo_recuperacion: float) -> void:
	_combate.desactivar_hitbox_ataque()
	_procesador_golpes.limpiar_objetivos()
	_impulso_aplicado = false
	_estado.call("recuperacion")
	_cooldown = tiempo_recuperacion
	_timer_ataque = tiempo_recuperacion
	_animacion.call("standing")


func cancelar_por_golpe() -> void:
	_combate.desactivar_hitbox_ataque()
	_estado.call("recuperacion")
	_cooldown = 0.5
	_timer_ataque = 0.5


func reiniciar() -> void:
	_timer_ataque = 0.0
	_cooldown = 0.0
	_impulso_aplicado = false
