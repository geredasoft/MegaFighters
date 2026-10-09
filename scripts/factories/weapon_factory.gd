extends RefCounted

## Crea una instancia de arma sin decidir dónde ni cuándo aparecerá.
static func crear(escena: PackedScene) -> Node2D:
	if escena == null:
		push_error("WeaponFactory: no se asignó una escena de arma.")
		return null

	var instancia: Node = escena.instantiate()
	var arma := instancia as Node2D
	if arma == null:
		push_error("WeaponFactory: la raíz de la escena debe ser Node2D.")
		instancia.queue_free()
		return null

	return arma
