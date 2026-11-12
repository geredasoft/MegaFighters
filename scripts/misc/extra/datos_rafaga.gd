class_name DatosRafaga
extends DatosProyectilBase

@export var numero: int
@export var sub_cadencia_ms: int

func _init(numero: int = 0, sub_cadencia_ms: int = 0) -> void:
	self.numero = numero
	self.sub_cadencia_ms = sub_cadencia_ms
