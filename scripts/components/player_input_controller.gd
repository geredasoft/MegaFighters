extends RefCounted

var _manteniendo_tecla_portal: bool = false
var _direccion_bloqueada_portal: float = 0.0


func obtener_input_horizontal() -> float:
	var input_real := obtener_input_horizontal_sin_bloqueo()

	if _manteniendo_tecla_portal:
		if (
			input_real == 0.0
			or sign(input_real) != sign(_direccion_bloqueada_portal)
		):
			limpiar_bloqueo_portal()
		else:
			return -_direccion_bloqueada_portal

	return input_real


func obtener_input_horizontal_sin_bloqueo() -> float:
	var input_real := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		input_real = -1.0
	elif Input.is_key_pressed(KEY_D):
		input_real = 1.0

	return input_real


func presiono_salto() -> bool:
	return (
		Input.is_action_just_pressed("ui_up")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_W)
	)


func mantiene_subir() -> bool:
	return Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)


func mantiene_bajar() -> bool:
	return Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)


func presiono_ataque() -> bool:
	return Input.is_action_just_pressed("attack")




func esta_atacando() -> bool:
	return Input.is_action_pressed("attack")


func esta_agachado() -> bool:
	return Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")


func esta_corriendo() -> bool:
	return Input.is_key_pressed(KEY_Z)


func establecer_bloqueo_portal(direccion: float) -> void:
	_manteniendo_tecla_portal = not is_zero_approx(direccion)
	_direccion_bloqueada_portal = direccion if _manteniendo_tecla_portal else 0.0


func limpiar_bloqueo_portal() -> void:
	_manteniendo_tecla_portal = false
	_direccion_bloqueada_portal = 0.0
