extends "res://scripts/strategies/spawn_point_strategy.gd"

func seleccionar(puntos: Array[Marker2D], cantidad: int) -> Array[Marker2D]:
	var candidatos: Array[Marker2D] = puntos.duplicate()
	candidatos.shuffle()

	var resultado: Array[Marker2D] = []
	var cantidad_final := mini(maxi(cantidad, 0), candidatos.size())
	for indice: int in range(cantidad_final):
		resultado.append(candidatos[indice])

	return resultado
