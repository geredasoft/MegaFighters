extends RefCounted

## Coordina limpieza de muerte y restauración del enemigo.
var _enemigo: Danable
var _posicion_inicial: Vector2 = Vector2.ZERO
var _callbacks: Dictionary


func _init(enemigo: Danable, callbacks: Dictionary) -> void:
	_enemigo = enemigo
	_callbacks = callbacks


func establecer_posicion_inicial(posicion: Vector2) -> void:
	_posicion_inicial = posicion


func morir() -> void:
	if bool(_callbacks["esta_muerto"].call()):
		return
	_callbacks["cambiar_estado"].call("muerto")
	_enemigo.velocity = Vector2.ZERO
	_callbacks["limpiar_knockback"].call()
	_callbacks["limpiar_plataformas"].call()
	_callbacks["limpiar_objetivos"].call()
	_callbacks["desactivar_hitbox"].call()
	_callbacks["reproducir_animacion"].call("fall_on_ground")


func reiniciar() -> void:
	_enemigo.global_position = _posicion_inicial
	_enemigo.velocity = Vector2.ZERO
	_callbacks["cambiar_estado"].call("patrulla")
	_callbacks["restaurar_datos"].call()
	_callbacks["limpiar_plataformas"].call()
	_callbacks["limpiar_objetivos"].call()
	_callbacks["actualizar_origen_patrulla"].call()
	_callbacks["reiniciar_vida"].call()
	_callbacks["desactivar_hitbox"].call()
	_callbacks["reproducir_animacion"].call("standing")
