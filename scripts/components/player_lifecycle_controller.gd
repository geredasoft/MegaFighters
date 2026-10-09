extends RefCounted

## Centraliza muerte y reinicio conservando las señales del Player.
var _jugador: CharacterBody2D
var _cambiar_estado: Callable
var _esta_muerto: Callable
var _terminar_ataque: Callable
var _limpiar_knockback: Callable
var _animar: Callable
var _reiniciar_vida: Callable
var _limpiar_input_portal: Callable
var _notificar_muerte: Callable
var _posicion_inicial: Vector2 = Vector2.ZERO


func _init(jugador: CharacterBody2D, callbacks: Dictionary) -> void:
	_jugador = jugador
	_cambiar_estado = callbacks["cambiar_estado"]
	_esta_muerto = callbacks["esta_muerto"]
	_terminar_ataque = callbacks["terminar_ataque"]
	_limpiar_knockback = callbacks["limpiar_knockback"]
	_animar = callbacks["reproducir_animacion"]
	_reiniciar_vida = callbacks["reiniciar_vida"]
	_limpiar_input_portal = callbacks["limpiar_input_portal"]
	_notificar_muerte = callbacks["notificar_muerte"]


func establecer_posicion_inicial(posicion: Vector2) -> void:
	_posicion_inicial = posicion


func morir() -> void:
	if _esta_muerto.call():
		return
	_terminar_ataque.call()
	_cambiar_estado.call("muerto")
	_limpiar_knockback.call()
	_jugador.velocity = Vector2.ZERO
	_animar.call("fall_on_ground")
	_notificar_muerte.call()


func reiniciar() -> void:
	_terminar_ataque.call()
	_limpiar_knockback.call()
	_jugador.global_position = _posicion_inicial
	_jugador.velocity = Vector2.ZERO
	_cambiar_estado.call("normal")
	_reiniciar_vida.call()
	_limpiar_input_portal.call()
	_animar.call("standing")
