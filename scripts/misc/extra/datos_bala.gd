class_name DatosBala
extends DatosProyectilBase

@export var automatica: bool = false

func _init(automatica: bool = false) -> void:
	self.automatica = automatica
