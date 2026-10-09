extends RefCounted

## Resuelve el traslado del enemigo y reinicia las maniobras incompatibles.
var _enemigo: CharacterBody2D
var _sprite: AnimatedSprite2D
var _ataque
var _callbacks: Dictionary
var _duracion_inercia: float


func _init(enemigo: CharacterBody2D, sprite: AnimatedSprite2D, ataque, callbacks: Dictionary, duracion_inercia: float) -> void:
	_enemigo = enemigo
	_sprite = sprite
	_ataque = ataque
	_callbacks = callbacks
	_duracion_inercia = duracion_inercia


func aplicar_efecto(nueva_posicion: Vector2, nueva_velocidad: Vector2, direccion_patrulla: float) -> float:
	_enemigo.global_position = nueva_posicion
	_enemigo.velocity = nueva_velocidad
	_callbacks["limpiar_plataformas"].call()
	_callbacks["limpiar_knockback"].call()
	_ataque.reiniciar()
	_callbacks["desactivar_hitbox"].call()
	_callbacks["cambiar_estado"].call("patrulla")
	_callbacks["actualizar_origen_patrulla"].call()
	if not is_zero_approx(nueva_velocidad.x):
		direccion_patrulla = signf(nueva_velocidad.x)
		_sprite.flip_h = direccion_patrulla < 0.0
	else:
		direccion_patrulla *= -1.0
		_sprite.flip_h = not _sprite.flip_h
	_callbacks["establecer_inercia"].call(_duracion_inercia)
	_callbacks["reproducir_animacion"].call("standing")
	return direccion_patrulla
