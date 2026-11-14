class_name DatosDispersion
extends DatosProyectilBase

@export var perdigones: int
@export var dispersion: float

func _init(perdigones: int = 0, dispersion: float = 0.0) -> void:
	self.perdigones = perdigones
	self.dispersion = dispersion
