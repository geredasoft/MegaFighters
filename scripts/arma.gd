class_name Arma
extends Area2D

@export var dos_manos: bool
@export var municion: int
@export var proyectil: ArmaParams.TipoProyectil
@export var dano: int
@export var cadencia_ms: int
@export var datos: DatosProyectilBase = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# Lógica para sumar el arma al inventario o estadísticas del jugador
		var params = ArmaParams.crear(
			dos_manos,
			$Sprite2D.texture,
			municion,
			proyectil,
			dano,
			cadencia_ms,
			datos,
		)
		
		assert(params != null, 
		"""Por favor, revise los parámetros de este recurso:
			proyectil: %s
			datos: %s""" % [
				ArmaParams.TipoProyectil.keys()[proyectil],
				type_string(typeof(datos))
			])
		
		body.equipar_arma(params)

		# Eliminar el objeto de la escena al ser recogido
		queue_free()
