@abstract
extends Resource

## Devuelve hasta `cantidad` puntos sin repetirlos.
@abstract
func seleccionar(puntos: Array[Marker2D], cantidad: int) -> Array[Marker2D]
