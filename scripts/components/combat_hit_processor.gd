extends RefCounted

var _objetivos_golpeados: Array[Node2D] = []


func limpiar_objetivos() -> void:
	_objetivos_golpeados.clear()


func procesar_golpe(
	area: Area2D,
	atacante: Danable,
	grupo_hurtbox: String,
	grupos_objetivo: PackedStringArray,
	dano: int,
	fuerza_horizontal: float,
	fuerza_vertical: float,
	direccion: float,
	mostrar_debug: bool = false,
	frame: int = -1
) -> Danable:
	if area == null or not is_instance_valid(area):
		return null
	if not area.is_in_group(grupo_hurtbox):
		return null

	var objetivo := area.get_parent() as Danable
	if objetivo == null or not is_instance_valid(objetivo):
		return null

	var objetivo_valido := false
	for grupo in grupos_objetivo:
		if objetivo.is_in_group(grupo):
			objetivo_valido = true
			break
	if not objetivo_valido or _objetivos_golpeados.has(objetivo):
		return null

	_objetivos_golpeados.append(objetivo)

	if mostrar_debug:
		print("========================================")
		print("💥 GOLPE CONECTADO")
		print("Enemigo: ", objetivo.name)
		print("Frame: ", frame)
		print("Dirección: ", direccion)
		print("========================================")

	objetivo.recibir_dano(dano, atacante)
	objetivo.recibir_empuje(
		direccion * fuerza_horizontal,
		fuerza_vertical
	)

	return objetivo
