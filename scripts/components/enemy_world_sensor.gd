extends RefCounted

var _agente: Node2D
var _mascara_terreno: int


func _init(agente: Node2D, mascara_terreno: int) -> void:
	_agente = agente
	_mascara_terreno = mascara_terreno


func puede_ver_objetivo(
	objetivo: Node2D,
	distancia_maxima: float,
	diferencia_vertical_maxima: float
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false

	var diferencia := objetivo.global_position - _agente.global_position
	if diferencia.length() > distancia_maxima:
		return false
	if absf(diferencia.y) > diferencia_vertical_maxima:
		return false

	var origen := _agente.global_position + Vector2(0.0, -12.0)
	var destino := objetivo.global_position + Vector2(0.0, -12.0)
	return _consultar_rayo(origen, destino).is_empty()


func buscar_jugador(arbol: SceneTree) -> CharacterBody2D:
	var objetivo: Node = arbol.get_first_node_in_group("Player")
	if objetivo == null:
		objetivo = arbol.get_first_node_in_group("player")
	if objetivo is CharacterBody2D:
		return objetivo
	return null


func hay_suelo(direccion: float, avance: float) -> bool:
	if is_zero_approx(direccion):
		return true

	var origen := _agente.global_position + Vector2(direccion * avance, 5.0)
	var destino := origen + Vector2(0.0, 38.0)
	return not _consultar_rayo(origen, destino).is_empty()


func hay_suelo_estatico(
	direccion: float,
	avance: float,
	profundidad: float = 38.0
) -> bool:
	var origen := _agente.global_position + Vector2(direccion * avance, 5.0)
	var destino := origen + Vector2(0.0, profundidad)
	var colision := _consultar_rayo(origen, destino)
	if colision.is_empty():
		return false

	var objeto: Object = colision.collider
	return not (
		objeto is AnimatableBody2D
		and objeto.is_in_group("plataforma_movil")
	)


func hay_pared(direccion: float, distancia: float) -> bool:
	if is_zero_approx(direccion):
		return false

	var origen := _agente.global_position + Vector2(0.0, -12.0)
	var destino := origen + Vector2(direccion * distancia, 0.0)
	return not _consultar_rayo(origen, destino).is_empty()


func hay_espacio_para_saltar(direccion: float) -> bool:
	if is_zero_approx(direccion):
		return false

	var origen := _agente.global_position + Vector2(0.0, -15.0)
	var destino := origen + Vector2(direccion * 20.0, -55.0)
	return _consultar_rayo(origen, destino).is_empty()


func _consultar_rayo(origen: Vector2, destino: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [_agente]
	query.collision_mask = _mascara_terreno
	return _agente.get_world_2d().direct_space_state.intersect_ray(query)
