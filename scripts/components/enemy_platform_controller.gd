extends RefCounted

var _agente: CharacterBody2D


func _init(agente: CharacterBody2D) -> void:
	_agente = agente


func buscar_plataforma_cercana(
	distancia_maxima: float,
	diferencia_vertical_maxima: float
) -> AnimatableBody2D:
	var plataforma_mas_cercana: AnimatableBody2D = null
	var distancia_minima := distancia_maxima

	for nodo in _agente.get_tree().get_nodes_in_group("plataforma_movil"):
		if not nodo is AnimatableBody2D:
			continue

		var plataforma := nodo as AnimatableBody2D
		var diferencia := plataforma.global_position - _agente.global_position
		if absf(diferencia.y) > diferencia_vertical_maxima:
			continue

		var distancia := diferencia.length()
		if distancia < distancia_minima:
			distancia_minima = distancia
			plataforma_mas_cercana = plataforma

	return plataforma_mas_cercana


func detectar_plataforma_bajo_agente(mascara_terreno: int) -> AnimatableBody2D:
	if not _agente.is_on_floor():
		return null

	var encontrada: AnimatableBody2D = null
	var colision := _agente.get_last_slide_collision()
	if colision != null:
		var collider := colision.get_collider()
		if _es_plataforma_movil(collider):
			encontrada = collider as AnimatableBody2D

	if encontrada != null:
		return encontrada

	var origen := _agente.global_position + Vector2(0.0, 2.0)
	var destino := _agente.global_position + Vector2(0.0, 35.0)
	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [_agente]
	query.collision_mask = mascara_terreno

	var resultado := _agente.get_world_2d().direct_space_state.intersect_ray(query)
	if resultado.is_empty() or not _es_plataforma_movil(resultado.collider):
		return null

	return resultado.collider as AnimatableBody2D


func obtener_velocidad(plataforma: AnimatableBody2D) -> Vector2:
	if plataforma == null or not is_instance_valid(plataforma):
		return Vector2.ZERO

	var velocidad: Variant = plataforma.get("velocidad_lineal_calculada")
	if velocidad is Vector2:
		return velocidad as Vector2

	return Vector2.ZERO


func _es_plataforma_movil(objeto: Object) -> bool:
	return (
		objeto is AnimatableBody2D
		and objeto.is_in_group("plataforma_movil")
	)
