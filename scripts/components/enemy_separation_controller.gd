extends RefCounted

var _agente: Node2D


func _init(agente: Node2D) -> void:
	_agente = agente


func obtener_enemigos_cercanos(distancia_maxima: float) -> Array[Node2D]:
	var enemigos: Array[Node2D] = []
	for nodo in _agente.get_tree().get_nodes_in_group("enemy"):
		if nodo == _agente:
			continue
		if not nodo is Node2D or not is_instance_valid(nodo):
			continue
		if nodo.has_method("esta_muerto") and nodo.esta_muerto():
			continue
		if _agente.global_position.distance_to(nodo.global_position) <= distancia_maxima:
			enemigos.append(nodo)

	return enemigos


func calcular_separacion(
	distancia_maxima: float,
	fuerza_separacion: float
) -> Vector2:
	var separacion := Vector2.ZERO
	for enemigo in obtener_enemigos_cercanos(distancia_maxima):
		var diferencia := _agente.global_position - enemigo.global_position
		var distancia := diferencia.length()
		if distancia <= 0.01:
			continue

		var fuerza := 1.0 - distancia / distancia_maxima
		separacion += diferencia.normalized() * fuerza * fuerza_separacion

	return separacion
