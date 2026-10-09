extends RefCounted

## Construye enemigos a partir de una escena configurable.
## Mantiene la validación del tipo de raíz fuera del spawner.
static func crear(escena: PackedScene) -> CharacterBody2D:
	if escena == null:
		push_error("EnemyFactory: no se asignó una escena de enemigo.")
		return null

	var instancia: Node = escena.instantiate()
	var enemigo := instancia as CharacterBody2D
	if enemigo == null:
		push_error("EnemyFactory: la raíz de la escena debe ser CharacterBody2D.")
		instancia.queue_free()
		return null

	return enemigo
