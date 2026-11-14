class_name DatosParticulas
extends DatosProyectilBase

@export var tiempo_vida_ms: int
@export var velocidad: float

func _init(tiempo_vida_ms: int = 0, velocidad: float = 0.0) -> void:
	self.tiempo_vida_ms = tiempo_vida_ms
	self.velocidad = velocidad
