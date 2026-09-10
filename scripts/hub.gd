extends CanvasLayer

@export var jugador: Danable
@onready var barra_player: ProgressBar = $Control/MarginContainerPlayer/HBoxContainer/ProgressBarPlayer
@onready var contenedor_barras: VBoxContainer = $Control/MarginContainerEnemigos/ContenedorBarrasEnemigos

# Diccionario para asociar cada enemigo con su contenedor de fila: { enemigo: hbox }
var barras_enemigos: Dictionary = {}
var contador_enemigos: int = 0

func _ready() -> void:
	if jugador:
		barra_player.max_value = jugador.vida_maxima
		barra_player.value = jugador.vida_actual
		jugador.vida_cambiada.connect(_on_jugador_vida_cambiada)

func _process(_delta: float) -> void:
	_actualizar_barras_enemigos()

func _on_jugador_vida_cambiada(actual: int, maxima: int) -> void:
	barra_player.max_value = maxima
	barra_player.value = actual

func _actualizar_barras_enemigos() -> void:
	var enemigos_actuales := get_tree().get_nodes_in_group("enemy")
	
	# 1. Crear la fila (HBoxContainer con Label y ProgressBar) para los nuevos enemigos
	for nodo in enemigos_actuales:
		if nodo is Danable:
			if not barras_enemigos.has(nodo):
				contador_enemigos += 1
				
				# Contenedor horizontal para la etiqueta y la barra
				var fila_contenedor = HBoxContainer.new()
				fila_contenedor.add_theme_constant_override("separation", 10)
				
				# Etiqueta del enemigo
				var etiqueta = Label.new()
				etiqueta.text = "Enemy " + str(contador_enemigos)
				etiqueta.add_theme_font_size_override("font_size", 12)
				
				# Barra de vida del enemigo
				var nueva_barra = ProgressBar.new()
				nueva_barra.custom_minimum_size = Vector2(110, 14) # Altura para que se vea bien el porcentaje
				nueva_barra.max_value = nodo.vida_maxima
				nueva_barra.value = nodo.vida_actual
				nueva_barra.show_percentage = true # Asegura que muestre el porcentaje
				
				nueva_barra.add_theme_font_size_override("font_size", 10)
				
				# Creamos los estilos visuales idénticos a los del player (Fondo gris oscuro y Relleno verde)
				var estilo_fondo = StyleBoxFlat.new()
				estilo_fondo.bg_color = Color("#2a2a2a") # Gris oscuro
				nueva_barra.add_theme_stylebox_override("background", estilo_fondo)
				
				var estilo_relleno = StyleBoxFlat.new()
				estilo_relleno.bg_color = Color("#0e6900") # Verde neón inicial
				nueva_barra.add_theme_stylebox_override("fill", estilo_relleno)
				
				# Añadimos los elementos a la fila y al contenedor principal
				fila_contenedor.add_child(etiqueta)
				fila_contenedor.add_child(nueva_barra)
				contenedor_barras.add_child(fila_contenedor)
				
				barras_enemigos[nodo] = fila_contenedor
				
				# Conectar la señal de vida
				nodo.vida_cambiada.connect(_on_enemigo_vida_cambiada.bind(nodo))
		
	# 2. Limpiar del diccionario las filas de enemigos destruidos
	var enemigos_a_remover := []
	for enemigo in barras_enemigos.keys():
		if not is_instance_valid(enemigo):
			enemigos_a_remover.append(enemigo)
			
	for enemigo in enemigos_a_remover:
		var fila = barras_enemigos[enemigo]
		if is_instance_valid(fila):
			fila.queue_free()
		barras_enemigos.erase(enemigo)

func _on_enemigo_vida_cambiada(actual: int, maxima: int, enemigo: Danable) -> void:
	if barras_enemigos.has(enemigo):
		var fila = barras_enemigos[enemigo]
		if is_instance_valid(fila):
			var barra: ProgressBar = fila.get_child(1) as ProgressBar
			if barra:
				barra.max_value = maxima
				barra.value = actual
				
				# Lógica dinámica: Cambiar a gris oscuro si la vida llega a 0, o verde si tiene vida
				var relleno: StyleBoxFlat = barra.get_theme_stylebox("fill") as StyleBoxFlat
				if relleno:
					if actual <= 0:
						relleno.bg_color = Color("#2a2a2a") # Gris oscuro cuando muere/llega a 0%
					else:
						relleno.bg_color = Color("#0e6900") # Verde mientras tenga vida
