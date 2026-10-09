extends RefCounted

var _etiqueta: RichTextLabel


func _init(etiqueta: RichTextLabel) -> void:
	_etiqueta = etiqueta


func mostrar_derrota() -> void:
	_etiqueta.text = "Juego terminado\n\nPresiona R para reiniciar."
	_etiqueta.show()


func mostrar_victoria(mensaje: String) -> void:
	_etiqueta.text = mensaje
	_etiqueta.show()


func ocultar() -> void:
	_etiqueta.hide()


func esta_visible() -> bool:
	return _etiqueta.visible
