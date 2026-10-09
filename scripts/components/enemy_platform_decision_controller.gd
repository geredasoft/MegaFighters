extends RefCounted


var _agente: CharacterBody2D
var _sensor_entorno
var _controlador_plataformas


func _init(
	agente: CharacterBody2D,
	sensor_entorno,
	controlador_plataformas
) -> void:
	_agente = agente
	_sensor_entorno = sensor_entorno
	_controlador_plataformas = controlador_plataformas


func decidir_intercepcion(
	puede_ver: bool,
	jugador: CharacterBody2D,
	direccion_patrulla: float,
	distancia_radar: float,
	diferencia_vertical_maxima: float,
	probabilidad: float
) -> Dictionary:
	var resultado := {
		"plataforma": null,
		"rechazada_por_azar": false
	}
	var plataforma: AnimatableBody2D = (
		_controlador_plataformas.buscar_plataforma_cercana(
			distancia_radar,
			diferencia_vertical_maxima
		) as AnimatableBody2D
	)
	if plataforma == null:
		return resultado

	var diferencia_x: float = plataforma.global_position.x - _agente.global_position.x
	var direccion_plataforma: float = signf(diferencia_x)
	if is_zero_approx(direccion_plataforma):
		return resultado

	var hay_suelo_delante: bool = bool(
		_sensor_entorno.hay_suelo(direccion_patrulla, 25.0)
	)
	var hay_abismo: bool = not hay_suelo_delante
	var necesita_cruzar: bool = (
		hay_abismo
		and direccion_plataforma == direccion_patrulla
	)
	var persigue_hacia_plataforma: bool = false

	if puede_ver and jugador != null and is_instance_valid(jugador):
		var direccion_jugador: float = signf(
			jugador.global_position.x - _agente.global_position.x
		)
		persigue_hacia_plataforma = direccion_jugador == direccion_plataforma

	if not necesita_cruzar and not persigue_hacia_plataforma:
		return resultado

	if randf() < probabilidad:
		resultado["plataforma"] = plataforma
	else:
		resultado["rechazada_por_azar"] = true

	return resultado


func obtener_direcciones_desembarco(
	posicion_agente: Vector2,
	posicion_jugador: Vector2,
	jugador_visible: bool
) -> Array[float]:
	var direcciones: Array[float] = [1.0, -1.0]
	if not jugador_visible:
		return direcciones

	var direccion_jugador: float = signf(
		posicion_jugador.x - posicion_agente.x
	)
	if is_zero_approx(direccion_jugador):
		return direcciones

	return [direccion_jugador, -direccion_jugador]


func seleccionar_desembarco(
	direcciones: Array[float],
	alcance: float,
	profundidad: float,
	alcance_salto: float,
	profundidad_salto: float
) -> Dictionary:
	var resultado := {
		"encontrado": false,
		"direccion": 0.0,
		"necesita_salto": false
	}

	for direccion: float in direcciones:
		var tiene_suelo: bool = bool(
			_sensor_entorno.hay_suelo_estatico(
				direccion,
				alcance,
				profundidad
			)
		)
		if tiene_suelo:
			resultado["encontrado"] = true
			resultado["direccion"] = direccion
			return resultado

		var tiene_suelo_con_salto: bool = bool(
			_sensor_entorno.hay_suelo_estatico(
				direccion,
				alcance_salto,
				profundidad_salto
			)
		)
		if tiene_suelo_con_salto:
			resultado["encontrado"] = true
			resultado["direccion"] = direccion
			resultado["necesita_salto"] = true
			return resultado

	return resultado


func decidir_maniobra_intercepcion(
	plataforma: AnimatableBody2D,
	fuerza_salto: float,
	velocidad_carrera: float,
	velocidad_trote: float
) -> Dictionary:
	var velocidad_plataforma: Vector2 = _controlador_plataformas.obtener_velocidad(
		plataforma
	)
	var posicion_proyectada: Vector2 = (
		plataforma.global_position + velocidad_plataforma * 0.25
	)
	var diferencia: Vector2 = posicion_proyectada - _agente.global_position
	var distancia_x: float = absf(diferencia.x)
	var direccion_x: float = signf(diferencia.x)
	var debe_saltar: bool = false
	var impulso_salto: float = 0.0

	var plataforma_arriba: bool = (
		diferencia.y < -20.0
		and diferencia.y > -110.0
		and distancia_x < 130.0
		and _agente.is_on_floor()
	)
	if plataforma_arriba:
		debe_saltar = true
		impulso_salto = fuerza_salto
	elif _agente.is_on_floor():
		var hay_borde: bool = not bool(
			_sensor_entorno.hay_suelo(direccion_x, 22.0)
		)
		if hay_borde and distancia_x < 130.0:
			debe_saltar = true
			impulso_salto = fuerza_salto * 0.85

	var velocidad_objetivo: float = (
		velocidad_carrera
		if distancia_x > 90.0
		else velocidad_trote
	)
	var resultado := {
		"direccion": direccion_x,
		"debe_saltar": debe_saltar,
		"impulso_salto": impulso_salto,
		"velocidad_objetivo": velocidad_objetivo
	}
	return resultado
