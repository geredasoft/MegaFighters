extends RefCounted

## Aplica el traslado del portal y evita invertir el input sostenido.
var _jugador: CharacterBody2D
var _sprite: AnimatedSprite2D
var _input


func _init(jugador: CharacterBody2D, sprite: AnimatedSprite2D, controlador_input) -> void:
	_jugador = jugador
	_sprite = sprite
	_input = controlador_input


func aplicar_efecto(nueva_posicion: Vector2, nueva_velocidad: Vector2) -> void:
	_jugador.global_position = nueva_posicion
	_jugador.velocity = nueva_velocidad
	var input_actual: float = _input.obtener_input_horizontal_sin_bloqueo()
	if not is_zero_approx(input_actual):
		_input.establecer_bloqueo_portal(input_actual)
		_sprite.flip_h = (-input_actual) < 0.0
	else:
		_input.limpiar_bloqueo_portal()
		_sprite.flip_h = not _sprite.flip_h
