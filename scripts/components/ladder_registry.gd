extends RefCounted

var _escaleras_cercanas: Array[Area2D] = []


func registrar(escalera: Area2D) -> void:
	if escalera != null and not _escaleras_cercanas.has(escalera):
		_escaleras_cercanas.append(escalera)


func desregistrar(escalera: Area2D) -> void:
	if escalera != null:
		_escaleras_cercanas.erase(escalera)


func tiene_cercanas() -> bool:
	return not _escaleras_cercanas.is_empty()


func obtener(escalera_activa: Area2D) -> Area2D:
	if escalera_activa != null:
		return escalera_activa
	if _escaleras_cercanas.is_empty():
		return null

	return _escaleras_cercanas.back()
