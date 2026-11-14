class_name DatosExplosion
extends DatosProyectilBase

@export var radio: float
@export var empuje: float
@export var velocidad: float

func _init(radio: float = 0.0, empuje: float = 0.0, velocidad: float = 0.0) -> void:
	self.radio = radio
	self.empuje = empuje
	self.velocidad = velocidad
