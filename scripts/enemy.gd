extends Danable

# =========================================================
# VELOCIDADES Y FÍSICAS
# =========================================================

const VELOCIDAD_TROTE: float = 120.0
const VELOCIDAD_CARRERA: float = 220.0
const ACELERACION: float = 850.0
const DESACELERACION: float = 1100.0

const FUERZA_SALTO: float = -490.0
const GRAVEDAD: float = 1200.0

# =========================================================
# PARÁMETROS TÁCTICOS Y DETECCIÓN
# =========================================================

const DISTANCIA_ATAQUE: float = 50.0
const DISTANCIA_DETECCION: float = 380.0
const DIFERENCIA_VERTICAL_MAXIMA: float = 130.0

const DISTANCIA_PATRULLA: float = 160.0
const TIEMPO_ESPERA_PATRULLA: float = 1.6

const TIEMPO_VIENTO_ATAQUE: float = 0.22
const TIEMPO_RECUPERACION_ATAQUE: float = 0.85

const DISTANCIA_RADAR_PLATAFORMA: float = 220.0
const COOLDOWN_REINTENTO_PLATAFORMA: float = 4.0

# =========================================================
# CONFIGURACIÓN EXPORTADA
# =========================================================

@export_category("IA")
@export var perseguir_jugador: bool = true
@export var mascara_terreno: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# =========================================================
# ESTADOS
# =========================================================

enum Estado {
	PATRULLANDO,
	ESPERA_PATRULLA,
	PERSEGUIR,
	ANTICIPANDO_ATAQUE,
	ATACANDO,
	RECUPERACION,
	INTERCEPTANDO_PLATAFORMA,
	EN_PLATAFORMA,
	MUERTO,
}

var estado: Estado = Estado.PATRULLANDO
var jugador: CharacterBody2D = null

# Timers internos
var timer_patrulla: float = 0.0
var timer_ataque: float = 0.0
var timer_cooldown: float = 0.0

var direccion_patrulla: float = 1.0
var punto_origen_x: float = 0.0

# Inercia post-portal
var timer_inercia_portal: float = 0.0
const DURACION_INERCIA_PORTAL: float = 0.45

# Navegación con plataforma móvil
var plataforma_objetivo: AnimatableBody2D = null
var timer_cooldown_plataforma: float = 0.0

# Físicas
var gravedad_actual = GRAVEDAD
var damping_entorno = 0.0
var posicion_inicial = 0.0


# =========================================================
# CICLO PRINCIPAL
# =========================================================

func _ready() -> void:
	add_to_group("enemy")
	platform_on_leave = PlatformOnLeave.PLATFORM_ON_LEAVE_ADD_VELOCITY
	punto_origen_x = global_position.x
	sprite.scale = Vector2(2.0, 2.0)
	sprite.play("standing")

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
		
	posicion_inicial = global_position

	buscar_jugador()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad_actual * delta

	if timer_cooldown > 0.0:
		timer_cooldown -= delta

	if timer_inercia_portal > 0.0:
		timer_inercia_portal -= delta

	if timer_cooldown_plataforma > 0.0:
		timer_cooldown_plataforma -= delta

	if jugador == null or not is_instance_valid(jugador):
		buscar_jugador()
	

	evaluar_transiciones()
	procesar_comportamiento(delta)
	
	velocity *= exp(-damping_entorno * delta)

	move_and_slide()


# =========================================================
# EFECTO DE PORTAL
# =========================================================

func aplicar_efecto_portal(nueva_posicion: Vector2, nueva_velocidad: Vector2) -> void:
	global_position = nueva_posicion
	velocity = nueva_velocidad

	if estado in [Estado.ANTICIPANDO_ATAQUE, Estado.ATACANDO]:
		estado = Estado.PATRULLANDO

	if nueva_velocidad.x != 0.0:
		direccion_patrulla = signf(nueva_velocidad.x)
		sprite.flip_h = direccion_patrulla < 0.0
	else:
		direccion_patrulla *= -1.0
		sprite.flip_h = not sprite.flip_h

	punto_origen_x = global_position.x
	timer_inercia_portal = DURACION_INERCIA_PORTAL


# =========================================================
# TOMA DE DECISIONES
# =========================================================

func evaluar_transiciones() -> void:
	if estado in [Estado.ANTICIPANDO_ATAQUE, Estado.ATACANDO, Estado.RECUPERACION]:
		return

	if timer_inercia_portal > 0.0:
		return

	# Detección: ¿estamos parados sobre una plataforma móvil?
	var colisionador_piso := get_last_slide_collision()
	var sobre_plataforma := false
	if is_on_floor() and colisionador_piso != null:
		var collider = colisionador_piso.get_collider()
		if collider is AnimatableBody2D and collider.is_in_group("plataforma_movil"):
			sobre_plataforma = true
			plataforma_objetivo = collider

	if sobre_plataforma:
		if estado != Estado.EN_PLATAFORMA:
			estado = Estado.EN_PLATAFORMA
		return

	if estado == Estado.EN_PLATAFORMA and not is_on_floor():
		return

	var puede_ver := puede_ver_al_jugador()

	if puede_ver and perseguir_jugador:
		var dist_x: float = abs(jugador.global_position.x - global_position.x)
		var dist_y: float = abs(jugador.global_position.y - global_position.y)

		if dist_x <= DISTANCIA_ATAQUE and dist_y <= 40.0 and timer_cooldown <= 0.0 and is_on_floor():
			preparar_ataque()
			return

		estado = Estado.PERSEGUIR
	else:
		if estado == Estado.PERSEGUIR:
			estado = Estado.PATRULLANDO
			punto_origen_x = global_position.x

	# Decidir si subirse a una plataforma móvil (sólo bajo condiciones específicas, no siempre)
	if estado in [Estado.PATRULLANDO, Estado.PERSEGUIR] and is_on_floor() and timer_cooldown_plataforma <= 0.0:
		var plat_cercana := buscar_plataforma_cercana()
		if plat_cercana != null:
			var borde_frente := not hay_suelo(direccion_patrulla, 25.0)
			var dist_plat_x: float = plat_cercana.global_position.x - global_position.x
			var dir_hacia_plat := signf(dist_plat_x)

			# Solo sube si hay un abismo adelante o si persigue activamente al jugador en esa dirección
			var necesita_cruzar := borde_frente and dir_hacia_plat == direccion_patrulla
			var persigue_hacia_plataforma := puede_ver and signf(jugador.global_position.x - global_position.x) == dir_hacia_plat

			if necesita_cruzar or persigue_hacia_plataforma:
				# 60% de probabilidad para evitar subirse obligatoriamente en cada encuentro
				if randf() < 0.6:
					plataforma_objetivo = plat_cercana
					estado = Estado.INTERCEPTANDO_PLATAFORMA
				else:
					timer_cooldown_plataforma = COOLDOWN_REINTENTO_PLATAFORMA


func procesar_comportamiento(delta: float) -> void:
	match estado:
		Estado.PATRULLANDO:
			ejecutar_patrulla(delta)
		Estado.ESPERA_PATRULLA:
			ejecutar_espera_patrulla(delta)
		Estado.PERSEGUIR:
			ejecutar_persecucion(delta)
		Estado.ANTICIPANDO_ATAQUE:
			ejecutar_anticipacion(delta)
		Estado.ATACANDO, Estado.RECUPERACION:
			velocity.x = move_toward(velocity.x, 0.0, DESACELERACION * delta)
		Estado.INTERCEPTANDO_PLATAFORMA:
			ejecutar_intercepcion_plataforma(delta)
		Estado.EN_PLATAFORMA:
			ejecutar_en_plataforma(delta)
		Estado.MUERTO:
			pass


# =========================================================
# COMPORTAMIENTOS ESPECÍFICOS
# =========================================================

func ejecutar_patrulla(delta: float) -> void:
	if timer_inercia_portal > 0.0:
		velocity.x = move_toward(velocity.x, direccion_patrulla * VELOCIDAD_TROTE, ACELERACION * delta)
		sprite.flip_h = direccion_patrulla < 0.0
		actualizar_animacion_movimiento(false)
		return

	var distancia_desplazada: float = global_position.x - punto_origen_x
	var llego_al_limite: bool = abs(distancia_desplazada) >= DISTANCIA_PATRULLA and signf(distancia_desplazada) == direccion_patrulla
	var borde_cercano: bool = not hay_suelo(direccion_patrulla, 22.0)
	var obstaculo_bloqueante: bool = hay_pared(direccion_patrulla, 18.0)

	if llego_al_limite or borde_cercano or obstaculo_bloqueante:
		estado = Estado.ESPERA_PATRULLA
		timer_patrulla = TIEMPO_ESPERA_PATRULLA
		return

	velocity.x = move_toward(velocity.x, direccion_patrulla * VELOCIDAD_TROTE, ACELERACION * delta)
	sprite.flip_h = direccion_patrulla < 0.0
	actualizar_animacion_movimiento(false)


func ejecutar_espera_patrulla(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DESACELERACION * delta)
	sprite.play("standing")

	timer_patrulla -= delta
	if timer_patrulla <= 0.0:
		direccion_patrulla *= -1.0
		punto_origen_x = global_position.x
		estado = Estado.PATRULLANDO


func ejecutar_persecucion(delta: float) -> void:
	var dir_x: float = signf(jugador.global_position.x - global_position.x)
	var dist_x: float = abs(jugador.global_position.x - global_position.x)

	var suelo_al_frente: bool = hay_suelo(dir_x, 24.0)
	var obstaculo_enfrente: bool = hay_pared(dir_x, 22.0)
	var jugador_mas_alto: bool = (jugador.global_position.y < global_position.y - 25.0)

	if is_on_floor() and (obstaculo_enfrente or (jugador_mas_alto and dist_x < 90.0)):
		if hay_espacio_para_saltar(dir_x):
			velocity.y = FUERZA_SALTO
			sprite.play("jump")

	if not suelo_al_frente and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, DESACELERACION * delta)
	else:
		var vel_deseada: float = VELOCIDAD_CARRERA if dist_x > DISTANCIA_ATAQUE * 1.5 else VELOCIDAD_TROTE
		velocity.x = move_toward(velocity.x, dir_x * vel_deseada, ACELERACION * delta)

	if dir_x != 0.0:
		sprite.flip_h = dir_x < 0.0

	actualizar_animacion_movimiento(true)


func ejecutar_intercepcion_plataforma(delta: float) -> void:
	if plataforma_objetivo == null or not is_instance_valid(plataforma_objetivo):
		estado = Estado.PATRULLANDO
		return

	var vel_plat: Vector2 = plataforma_objetivo.get("velocidad_lineal_calculada") if plataforma_objetivo.get("velocidad_lineal_calculada") != null else Vector2.ZERO
	var pos_proyectada: Vector2 = plataforma_objetivo.global_position + (vel_plat * 0.25)

	var dif_x: float = pos_proyectada.x - global_position.x
	var dist_x: float = abs(dif_x)
	var dir_x: float = signf(dif_x)
	var dif_y: float = pos_proyectada.y - global_position.y

	if dir_x != 0.0:
		sprite.flip_h = dir_x < 0.0

	# 1. Plataforma en altura: salto de alcance
	if dif_y < -20.0 and dif_y > -110.0 and dist_x < 130.0 and is_on_floor():
		velocity.y = FUERZA_SALTO
		velocity.x = dir_x * (VELOCIDAD_CARRERA if dist_x > 70.0 else VELOCIDAD_TROTE)
		sprite.play("jump")
		return

	# 2. En el suelo: aproximarse o saltar borde
	if is_on_floor():
		var borde_suelo := not hay_suelo(dir_x, 22.0)

		if borde_suelo and dist_x < 130.0:
			velocity.y = FUERZA_SALTO * 0.85
			velocity.x = dir_x * VELOCIDAD_CARRERA
			sprite.play("jump")
			return

		var vel_target: float = VELOCIDAD_CARRERA if dist_x > 90.0 else VELOCIDAD_TROTE
		velocity.x = move_toward(velocity.x, dir_x * vel_target, ACELERACION * delta)
		actualizar_animacion_movimiento(vel_target == VELOCIDAD_CARRERA)
	else:
		velocity.x = move_toward(velocity.x, dir_x * VELOCIDAD_TROTE, ACELERACION * delta)


func ejecutar_en_plataforma(delta: float) -> void:
	# Prioridad absoluta: buscar de inmediato suelo firme en ambas direcciones
	var direcciones_escaneo: Array[float] = [1.0, -1.0]
	
	# Si ve al jugador, priorizar escanear hacia su dirección primero
	if jugador != null and puede_ver_al_jugador():
		var dir_jugador := signf(jugador.global_position.x - global_position.x)
		if dir_jugador != 0.0:
			direcciones_escaneo = [dir_jugador, -dir_jugador]

	var desembarco_encontrado := false
	var dir_desembarco := 0.0
	var metodo_salto := false

	for dir in direcciones_escaneo:
		# Escanear suelo horizontal directo (hasta 90px)
		if hay_suelo_estatico(dir, 75.0, 45.0):
			desembarco_encontrado = true
			dir_desembarco = dir
			metodo_salto = false
			break
		# Escanear suelo inferior o saltos largos (hasta 120px de alcance horizontal y 90px de caída)
		elif hay_suelo_estatico(dir, 100.0, 95.0):
			desembarco_encontrado = true
			dir_desembarco = dir
			metodo_salto = true
			break

	# Salir de inmediato al suelo si fue encontrado
	if is_on_floor() and desembarco_encontrado:
		sprite.flip_h = dir_desembarco < 0.0
		if metodo_salto:
			velocity.y = FUERZA_SALTO * 0.85
			velocity.x = dir_desembarco * VELOCIDAD_CARRERA
			sprite.play("jump")
		else:
			velocity.x = dir_desembarco * VELOCIDAD_CARRERA

		timer_cooldown_plataforma = COOLDOWN_REINTENTO_PLATAFORMA
		plataforma_objetivo = null
		estado = Estado.PERSEGUIR if (jugador != null and puede_ver_al_jugador()) else Estado.PATRULLANDO
		punto_origen_x = global_position.x
		return

	# Si aún no hay suelo disponible: mantenerse quieto sobre la plataforma sin brincos aleatorios
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, DESACELERACION * delta)
		sprite.play("standing")
	else:
		# En el aire (conserva inercia pura de despegue sin frenado forzado)
		actualizar_animacion_movimiento(false)


func preparar_ataque() -> void:
	estado = Estado.ANTICIPANDO_ATAQUE
	timer_ataque = TIEMPO_VIENTO_ATAQUE
	sprite.flip_h = (jugador.global_position.x - global_position.x) < 0.0
	sprite.play("standing")


func ejecutar_anticipacion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DESACELERACION * delta)
	timer_ataque -= delta
	if timer_ataque <= 0.0:
		estado = Estado.ATACANDO
		sprite.play("attack")

# =========================================================
# PERCEPCIÓN ESPACIAL (RAYCASTS)
# =========================================================

func buscar_plataforma_cercana() -> AnimatableBody2D:
	var plataformas := get_tree().get_nodes_in_group("plataforma_movil")
	var mas_cercana: AnimatableBody2D = null
	var min_dist := DISTANCIA_RADAR_PLATAFORMA

	for plat in plataformas:
		if plat is AnimatableBody2D:
			var d := global_position.distance_to(plat.global_position)
			if d < min_dist:
				min_dist = d
				mas_cercana = plat

	return mas_cercana


func hay_suelo_estatico(dir: float, avance: float, profundidad: float = 38.0) -> bool:
	var espacio := get_world_2d().direct_space_state
	var origen := global_position + Vector2(dir * avance, 5.0)
	var destino := origen + Vector2(0.0, profundidad)

	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [self]
	query.collision_mask = mascara_terreno

	var colision := espacio.intersect_ray(query)
	if not colision.is_empty():
		var col_obj = colision.collider
		return not (col_obj is AnimatableBody2D and col_obj.is_in_group("plataforma_movil"))
	return false


func puede_ver_al_jugador() -> bool:
	if jugador == null:
		return false

	var dif: Vector2 = jugador.global_position - global_position
	if dif.length() > DISTANCIA_DETECCION or abs(dif.y) > DIFERENCIA_VERTICAL_MAXIMA:
		return false

	var espacio := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -12), jugador.global_position + Vector2(0, -12))
	query.exclude = [self]
	query.collision_mask = mascara_terreno

	var colision := espacio.intersect_ray(query)
	return colision.is_empty()


func hay_suelo(dir: float, avance: float) -> bool:
	var espacio := get_world_2d().direct_space_state
	var origen := global_position + Vector2(dir * avance, 5.0)
	var destino := origen + Vector2(0.0, 38.0)

	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [self]
	query.collision_mask = mascara_terreno
	return not espacio.intersect_ray(query).is_empty()


func hay_pared(dir: float, distancia: float) -> bool:
	var espacio := get_world_2d().direct_space_state
	var origen := global_position + Vector2(0.0, -12.0)
	var destino := origen + Vector2(dir * distancia, 0.0)

	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [self]
	query.collision_mask = mascara_terreno
	return not espacio.intersect_ray(query).is_empty()


func hay_espacio_para_saltar(dir: float) -> bool:
	var espacio := get_world_2d().direct_space_state
	var origen := global_position + Vector2(0.0, -15.0)
	var destino := origen + Vector2(dir * 20.0, -55.0)

	var query := PhysicsRayQueryParameters2D.create(origen, destino)
	query.exclude = [self]
	query.collision_mask = mascara_terreno
	return espacio.intersect_ray(query).is_empty()


# =========================================================
# UTILIDADES Y ANIMACIÓN
# =========================================================

func buscar_jugador() -> void:
	var nodo := get_tree().get_first_node_in_group("player")
	if nodo is CharacterBody2D:
		jugador = nodo
	else:
		jugador = null


func actualizar_animacion_movimiento(corriendo: bool) -> void:
	if not is_on_floor():
		sprite.play("jump")
	elif abs(velocity.x) > 10.0:
		if corriendo and sprite.sprite_frames.has_animation("run"):
			sprite.play("run")
		else:
			sprite.play("trot")
	else:
		sprite.play("standing")


func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		estado = Estado.RECUPERACION
		timer_cooldown = TIEMPO_RECUPERACION_ATAQUE
		sprite.play("standing")

		get_tree().create_timer(TIEMPO_RECUPERACION_ATAQUE).timeout.connect(func():
			if estado == Estado.RECUPERACION:
				estado = Estado.PERSEGUIR
		)

# ==============================================
# INTERFAZ PÚBLICA
# ==============================================
func morir() -> void:
	estado = Estado.MUERTO
	sprite.play("fall_on_ground")


func esta_muerto() -> bool:
	return estado == Estado.MUERTO


func cambiar_gravedad(invertir: bool = true) -> void:
	gravedad_actual = -GRAVEDAD if invertir else GRAVEDAD


func aplicar_damping(x: float = 0.0) -> void:
	damping_entorno = x

func reiniciar() -> void:
	estado = Estado.PATRULLANDO
	global_position = posicion_inicial
	reiniciar_vida()
