extends RefCounted

var _character: CharacterBody2D


func _init(character: CharacterBody2D) -> void:
	_character = character


func aplicar_gravedad(delta: float, gravedad: float, omitir: bool = false) -> void:
	if omitir or _character.is_on_floor():
		return

	_character.velocity.y += gravedad * delta


func aplicar_damping(delta: float, intensidad: float) -> void:
	if intensidad <= 0.0:
		return

	_character.velocity *= exp(-intensidad * delta)


func esta_recibiendo_knockback(velocidad_knockback: float) -> bool:
	return absf(velocidad_knockback) > 0.1


func procesar_knockback(
	velocidad_knockback: float,
	desaceleracion: float,
	delta: float
) -> float:
	_character.velocity.x = velocidad_knockback
	return move_toward(velocidad_knockback, 0.0, desaceleracion * delta)


func iniciar_knockback(
	direccion: float,
	fuerza_horizontal: float,
	fuerza_vertical: float
) -> float:
	var direccion_segura: float = signf(direccion)
	if is_zero_approx(direccion_segura):
		return 0.0
	_character.velocity.y = fuerza_vertical
	return direccion_segura * fuerza_horizontal
