class_name DatosArmaBlanca
extends DatosProyectilBase

@export var distancia: float
@export var multiplicador: float

func _init(distancia: float = 0.0, multiplicador: float = 1.0) -> void:
	self.distancia = distancia
	self.multiplicador = multiplicador
