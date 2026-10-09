extends RefCounted

## Decide transiciones tácticas sin asumir la implementación del enum del actor.
var _agente: CharacterBody2D
var _sensor
var _config: Dictionary


func _init(agente: CharacterBody2D, sensor, config: Dictionary) -> void:
	_agente = agente
	_sensor = sensor
	_config = config


func evaluar(
	estado_actual: String,
	jugador: CharacterBody2D,
	perseguir: bool,
	timer_portal: float,
	timer_perdida: float,
	plataforma_actual: AnimatableBody2D,
	cooldown_ataque: float
) -> Dictionary:
	var resultado: Dictionary = {
		"estado": "",
		"timer_perdida": timer_perdida,
		"reiniciar_origen": false,
		"preparar_ataque": false
	}
	if estado_actual in ["anticipando", "atacando", "recuperacion"]:
		return resultado
	if timer_portal > 0.0:
		return resultado
	if plataforma_actual != null:
		resultado["estado"] = "en_plataforma"
		return resultado
	var puede_ver: bool = _sensor.puede_ver_objetivo(
		jugador,
		_config["distancia_deteccion"],
		_config["diferencia_vertical_maxima"]
	)
	if puede_ver:
		resultado["timer_perdida"] = _config["tiempo_perdida"]
	elif timer_perdida <= 0.0 and estado_actual in ["perseguir", "posicionarse"]:
		resultado["estado"] = "patrullando"
		resultado["reiniciar_origen"] = true
		return resultado
	else:
		return resultado
	if not perseguir or jugador == null or not is_instance_valid(jugador):
		return resultado
	var diferencia_x: float = jugador.global_position.x - _agente.global_position.x
	var diferencia_y: float = jugador.global_position.y - _agente.global_position.y
	var distancia_x: float = absf(diferencia_x)
	if (
		distancia_x <= _config["distancia_ataque"]
		and absf(diferencia_y) <= _config["diferencia_ataque"]
		and cooldown_ataque <= 0.0
		and _agente.is_on_floor()
	):
		resultado["preparar_ataque"] = true
		return resultado
	if distancia_x < _config["distancia_combate_minima"]:
		resultado["estado"] = "posicionarse"
	else:
		resultado["estado"] = "perseguir"
	return resultado
