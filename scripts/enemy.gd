extends Danable


# =========================================================
# ENEMY
# IA, MOVIMIENTO, COMBATE, PLATAFORMAS, PORTALES Y ENTORNO
# =========================================================
#
# RESPONSABILIDADES:
#
# 1. Movimiento y física
# 2. IA y máquina de estados
# 3. Percepción del Player
# 4. Patrulla
# 5. Persecución
# 6. Posicionamiento de combate
# 7. Ataque
# 8. Hitbox / Hurtbox
# 9. Knockback
# 10. Plataformas móviles
# 11. Portales
# 12. Detección de entorno
# 13. Animaciones
# 14. Ciclo de vida
# 15. Integración con agua / damping
#
# PRINCIPIOS:
#
# - El Enemy solamente ataca al Player.
# - Los Enemy no pueden golpearse entre ellos.
# - El combate utiliza Hitbox + Hurtbox.
# - El ataque posee una ventana activa por frames.
# - El Enemy intenta mantener una distancia razonable.
# - Evita precipicios y paredes.
# - Puede saltar obstáculos.
# - Puede utilizar plataformas móviles.
# - Respeta portales.
# - Conserva compatibilidad con agua / damping.
#
# =========================================================



# =========================================================
# 01. CONFIGURACIÓN - MOVIMIENTO
# =========================================================

const VELOCIDAD_TROTE: float = 120.0
const VELOCIDAD_CARRERA: float = 220.0

const ACELERACION: float = 850.0
const DESACELERACION: float = 1100.0

const FUERZA_SALTO: float = -490.0
const GRAVEDAD: float = 1200.0


# =========================================================
# 02. CONFIGURACIÓN - IA / DETECCIÓN
# =========================================================

const DISTANCIA_DETECCION: float = 380.0
const DIFERENCIA_VERTICAL_MAXIMA: float = 130.0

const DISTANCIA_ATAQUE: float = 58.0
const DISTANCIA_COMBATE_MINIMA: float = 42.0
const DISTANCIA_RETROCESO: float = 25.0


# =========================================================
# SEPARACIÓN ENTRE ENEMIGOS
# =========================================================

const DISTANCIA_SEPARACION_ENEMY: float = 48.0
const DISTANCIA_SEPARACION_MINIMA: float = 32.0

const FUERZA_SEPARACION_ENEMY: float = 180.0


# =========================================================
# 03. CONFIGURACIÓN - PATRULLA
# =========================================================

const DISTANCIA_PATRULLA: float = 160.0
const TIEMPO_ESPERA_PATRULLA: float = 1.2


# =========================================================
# 04. CONFIGURACIÓN - DECISIONES DE IA
# =========================================================

const TIEMPO_RECUPERACION_ATAQUE: float = 0.75
const TIEMPO_VIENTO_ATAQUE: float = 0.18
const TIEMPO_PERDIDA_JUGADOR: float = 1.0

const DISTANCIA_SALTO_HORIZONTAL: float = 100.0


# =========================================================
# 05. CONFIGURACIÓN - ATAQUE
# =========================================================

const FRAME_ATAQUE_INICIO: int = 2
const FRAME_ATAQUE_FIN: int = 3

const IMPULSO_ATAQUE: float = 85.0
const FRENADO_ATAQUE: float = 900.0

const FUERZA_EMPUJE_ATAQUE: float = 1.0
const FUERZA_EMPUJE_VERTICAL: float = -120.0

const HITBOX_OFFSET_X: float = 20.0
const HITBOX_OFFSET_Y: float = -2.0


# =========================================================
# 06. CONFIGURACIÓN - PLATAFORMAS MÓVILES
# =========================================================

const DISTANCIA_RADAR_PLATAFORMA: float = 220.0
const DISTANCIA_VERTICAL_PLATAFORMA: float = 130.0

const COOLDOWN_REINTENTO_PLATAFORMA: float = 3.0

const ALCANCE_DESEMBARCO: float = 75.0
const ALCANCE_SALTO_DESEMBARCO: float = 110.0

const PROFUNDIDAD_DESEMBARCO: float = 45.0
const PROFUNDIDAD_SALTO_DESEMBARCO: float = 95.0


# =========================================================
# 07. CONFIGURACIÓN - PORTAL
# =========================================================

const DURACION_INERCIA_PORTAL: float = 0.45


# =========================================================
# 08. CONFIGURACIÓN - KNOCKBACK
# =========================================================

const FUERZA_KNOCKBACK_HORIZONTAL: float = 320.0
const FUERZA_KNOCKBACK_VERTICAL: float = -180.0

# =========================================================
# 09. CONFIGURACIÓN EXPORTADA
# =========================================================

@export_category("IA")

@export var perseguir_jugador: bool = true

@export_flags_2d_physics var mascara_terreno: int = 1


# =========================================================
# 10. REFERENCIAS DE NODOS
# =========================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var hitbox_ataque: Area2D = $HitboxAtaque

@onready var collision_hitbox: CollisionShape2D = (
	$HitboxAtaque/CollisionShape2D
)


# =========================================================
# 11. MÁQUINA DE ESTADOS
# =========================================================

enum Estado {
	PATRULLANDO,
	ESPERA_PATRULLA,
	PERSEGUIR,
	POSICIONARSE,
	ANTICIPANDO_ATAQUE,
	ATACANDO,
	RECUPERACION,
	INTERCEPTANDO_PLATAFORMA,
	EN_PLATAFORMA,
	MUERTO
}

var estado: Estado = Estado.PATRULLANDO


# =========================================================
# 12. REFERENCIA AL PLAYER
# =========================================================

var jugador: CharacterBody2D = null


# =========================================================
# 13. TIMERS / CONTADORES
# =========================================================

var timer_patrulla: float = 0.0
var timer_ataque: float = 0.0
var timer_cooldown_ataque: float = 0.0

var timer_inercia_portal: float = 0.0
var timer_cooldown_plataforma: float = 0.0

var timer_perdida_jugador: float = 0.0


# =========================================================
# 14. DATOS DE PATRULLA
# =========================================================

var direccion_patrulla: float = 1.0
var punto_origen_x: float = 0.0


# =========================================================
# 15. DATOS DE PLATAFORMAS
# =========================================================

var plataforma_actual: AnimatableBody2D = null
var plataforma_objetivo: AnimatableBody2D = null


# =========================================================
# 16. DATOS DE FÍSICA / ENTORNO
# =========================================================

var gravedad_actual: float = GRAVEDAD
var damping_entorno: float = 0.0

var posicion_inicial: Vector2 = Vector2.ZERO


# =========================================================
# 17. DATOS DE KNOCKBACK
# =========================================================

var velocidad_knockback: float = 0.0


# =========================================================
# 18. DATOS DE COMBATE
# =========================================================

var ataque_hitbox_activo: bool = false

# El Enemy solamente almacena Players golpeados.
var objetivos_golpeados: Array[Node2D] = []


# =========================================================
# DATOS DE SEPARACIÓN
# =========================================================

var separacion_enemigos: Vector2 = Vector2.ZERO

var impulso_ataque_aplicado: bool = false

# =========================================================
# 19. CICLO DE VIDA - READY
# =========================================================

func _ready() -> void:

	_configurar_grupo_enemy()
	_configurar_plataformas()
	_configurar_posicion_inicial()
	_configurar_sprite()
	_configurar_animaciones()
	_configurar_senales()
	_configurar_hitbox()
	buscar_jugador()


# =========================================================
# 20. CONFIGURACIÓN INICIAL
# =========================================================

func _configurar_grupo_enemy() -> void:

	add_to_group("enemy")


func _configurar_plataformas() -> void:

	platform_on_leave = (
		PlatformOnLeave.PLATFORM_ON_LEAVE_ADD_VELOCITY
	)


func _configurar_posicion_inicial() -> void:

	posicion_inicial = global_position
	punto_origen_x = global_position.x


func _configurar_sprite() -> void:

	sprite.scale = Vector2(2.0, 2.0)

	reproducir_animacion("standing")


func _configurar_animaciones() -> void:

	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("attack"):

		sprite.sprite_frames.set_animation_loop(
			"attack",
			false
		)

	if sprite.sprite_frames.has_animation("fall_on_ground"):

		sprite.sprite_frames.set_animation_loop(
			"fall_on_ground",
			false
		)


func _configurar_senales() -> void:

	if not sprite.animation_finished.is_connected(
		_on_animation_finished
	):

		sprite.animation_finished.connect(
			_on_animation_finished
	)

	if not hitbox_ataque.area_entered.is_connected(
		_on_hitbox_ataque_area_entered
	):

		hitbox_ataque.area_entered.connect(
			_on_hitbox_ataque_area_entered
	)


func _configurar_hitbox() -> void:

	desactivar_hitbox_ataque()
	actualizar_direccion_hitbox()


# =========================================================
# 21. PHYSICS PROCESS
# =========================================================

func _physics_process(delta: float) -> void:

	_actualizar_timers(delta)
	_aplicar_gravedad(delta)
	_procesar_knockback(delta)

	# -----------------------------------------------------
	# KNOCKBACK
	# -----------------------------------------------------

	if _esta_recibiendo_knockback():

		_aplicar_damping(delta)
		move_and_slide()

		return

	# -----------------------------------------------------
	# BUSCAR PLAYER
	# -----------------------------------------------------

	if jugador == null or not is_instance_valid(jugador):

		buscar_jugador()

	# -----------------------------------------------------
	# IA
	# -----------------------------------------------------

	if estado != Estado.MUERTO:

		evaluar_transiciones()
		procesar_comportamiento(delta)

	# -----------------------------------------------------
	# DAMPING
	# -----------------------------------------------------

	_aplicar_damping(delta)

	# -----------------------------------------------------
	# MOVIMIENTO FÍSICO
	# -----------------------------------------------------

	move_and_slide()


# =========================================================
# 22. TIMERS
# =========================================================

func _actualizar_timers(delta: float) -> void:

	timer_cooldown_ataque = maxf(
		timer_cooldown_ataque - delta,
		0.0
	)

	timer_inercia_portal = maxf(
		timer_inercia_portal - delta,
		0.0
	)

	timer_cooldown_plataforma = maxf(
		timer_cooldown_plataforma - delta,
		0.0
	)

	if timer_perdida_jugador > 0.0:

		timer_perdida_jugador = maxf(
			timer_perdida_jugador - delta,
			0.0
		)


# =========================================================
# 23. FÍSICA - GRAVEDAD
# =========================================================

func _aplicar_gravedad(delta: float) -> void:

	if not is_on_floor():

		velocity.y += gravedad_actual * delta


# =========================================================
# 24. FÍSICA - DAMPING
# =========================================================

func _aplicar_damping(delta: float) -> void:

	if damping_entorno <= 0.0:
		return

	velocity *= exp(
		-damping_entorno * delta
	)


# =========================================================
# 25. KNOCKBACK - PROCESAMIENTO
# =========================================================

func _procesar_knockback(delta: float) -> void:

	if not _esta_recibiendo_knockback():
		return

	velocity.x = velocidad_knockback

	velocidad_knockback = move_toward(
		velocidad_knockback,
		0.0,
		DESACELERACION * delta
	)


func _esta_recibiendo_knockback() -> bool:

	return absf(velocidad_knockback) > 0.1


# =========================================================
# 26. PORTAL
# =========================================================

func aplicar_efecto_portal(
	nueva_posicion: Vector2,
	nueva_velocidad: Vector2
) -> void:

	global_position = nueva_posicion
	velocity = nueva_velocidad

	plataforma_actual = null
	plataforma_objetivo = null

	velocidad_knockback = 0.0

	timer_ataque = 0.0
	timer_cooldown_ataque = 0.0

	desactivar_hitbox_ataque()

	estado = Estado.PATRULLANDO

	punto_origen_x = global_position.x

	if not is_zero_approx(nueva_velocidad.x):

		direccion_patrulla = signf(
			nueva_velocidad.x
		)

		sprite.flip_h = (
			direccion_patrulla < 0.0
		)

	else:

		direccion_patrulla *= -1.0

		sprite.flip_h = not sprite.flip_h

	timer_inercia_portal = (
		DURACION_INERCIA_PORTAL
	)

	reproducir_animacion("standing")


# =========================================================
# 27. IA - TRANSICIONES
# =========================================================

func evaluar_transiciones() -> void:

	# -----------------------------------------------------
	# ESTADOS NO INTERRUMPIBLES
	# -----------------------------------------------------

	if estado in [
		Estado.ANTICIPANDO_ATAQUE,
		Estado.ATACANDO
	]:

		return

	# -----------------------------------------------------
	# RECUPERACIÓN
	# -----------------------------------------------------

	if estado == Estado.RECUPERACION:

		return

	# -----------------------------------------------------
	# INERCIA DEL PORTAL
	# -----------------------------------------------------

	if timer_inercia_portal > 0.0:
		return

	# -----------------------------------------------------
	# PLATAFORMA ACTUAL
	# -----------------------------------------------------

	actualizar_plataforma_actual()

	if plataforma_actual != null:

		estado = Estado.EN_PLATAFORMA

		return

	# -----------------------------------------------------
	# PLAYER
	# -----------------------------------------------------

	var puede_ver := puede_ver_al_jugador()

	if puede_ver:

		timer_perdida_jugador = TIEMPO_PERDIDA_JUGADOR

	else:

		if timer_perdida_jugador <= 0.0:

			if estado in [
				Estado.PERSEGUIR,
				Estado.POSICIONARSE
			]:

				estado = Estado.PATRULLANDO
				punto_origen_x = global_position.x

		return

	# -----------------------------------------------------
	# PLAYER VISIBLE
	# -----------------------------------------------------

	if not perseguir_jugador:
		return

	var diferencia_x := (
		jugador.global_position.x
		- global_position.x
	)

	var diferencia_y := (
		jugador.global_position.y
		- global_position.y
	)

	var distancia_x := absf(diferencia_x)

	# -----------------------------------------------------
	# ATAQUE
	# -----------------------------------------------------

	if (
		distancia_x <= DISTANCIA_ATAQUE
		and absf(diferencia_y) <= 45.0
		and timer_cooldown_ataque <= 0.0
		and is_on_floor()
	):

		preparar_ataque()

		return

	# -----------------------------------------------------
	# MUY CERCA
	# -----------------------------------------------------

	if distancia_x < DISTANCIA_COMBATE_MINIMA:

		estado = Estado.POSICIONARSE

		return

	# -----------------------------------------------------
	# PERSEGUIR
	# -----------------------------------------------------

	estado = Estado.PERSEGUIR


# =========================================================
# 28. IA - COMPORTAMIENTO PRINCIPAL
# =========================================================

func procesar_comportamiento(delta: float) -> void:

	match estado:

		Estado.PATRULLANDO:
			ejecutar_patrulla(delta)

		Estado.ESPERA_PATRULLA:
			ejecutar_espera_patrulla(delta)

		Estado.PERSEGUIR:
			ejecutar_persecucion(delta)

		Estado.POSICIONARSE:
			ejecutar_posicionamiento(delta)

		Estado.ANTICIPANDO_ATAQUE:
			ejecutar_anticipacion(delta)

		Estado.ATACANDO:
			ejecutar_ataque(delta)

		Estado.RECUPERACION:
			ejecutar_recuperacion(delta)

		Estado.INTERCEPTANDO_PLATAFORMA:
			ejecutar_intercepcion_plataforma(delta)

		Estado.EN_PLATAFORMA:
			ejecutar_en_plataforma(delta)

		Estado.MUERTO:
			pass


# =========================================================
# 29. IA - PATRULLA
# =========================================================

func ejecutar_patrulla(delta: float) -> void:

	var distancia_desplazada := (
		global_position.x - punto_origen_x
	)

	var llego_al_limite := (
		absf(distancia_desplazada)
		>= DISTANCIA_PATRULLA
		and signf(distancia_desplazada)
		== direccion_patrulla
	)

	var borde_cercano := not hay_suelo(
		direccion_patrulla,
		24.0
	)

	var pared := hay_pared(
		direccion_patrulla,
		20.0
	)

	if (
		llego_al_limite
		or borde_cercano
		or pared
	):

		estado = Estado.ESPERA_PATRULLA

		timer_patrulla = (
			TIEMPO_ESPERA_PATRULLA
		)

		velocity.x = move_toward(
			velocity.x,
			0.0,
			DESACELERACION * delta
		)

		reproducir_animacion("standing")

		return

	velocity.x = move_toward(
		velocity.x,
		direccion_patrulla * VELOCIDAD_TROTE,
		ACELERACION * delta
	)

	sprite.flip_h = direccion_patrulla < 0.0

	actualizar_animacion_movimiento(false)


# =========================================================
# 30. IA - ESPERA DE PATRULLA
# =========================================================

func ejecutar_espera_patrulla(delta: float) -> void:

	velocity.x = move_toward(
		velocity.x,
		0.0,
		DESACELERACION * delta
	)

	reproducir_animacion("standing")

	timer_patrulla -= delta

	if timer_patrulla <= 0.0:

		direccion_patrulla *= -1.0
		punto_origen_x = global_position.x

		estado = Estado.PATRULLANDO

# =========================================================
# SEPARACIÓN - OBTENER ENEMIGOS CERCANOS
# =========================================================

func obtener_enemigos_cercanos() -> Array[Node2D]:

	var enemigos: Array[Node2D] = []

	for nodo in get_tree().get_nodes_in_group("enemy"):

		if nodo == self:
			continue

		if not nodo is Node2D:
			continue

		if not is_instance_valid(nodo):
			continue

		if nodo.has_method("esta_muerto") and nodo.esta_muerto():
			continue

		var distancia := global_position.distance_to(
			nodo.global_position
		)

		if distancia <= DISTANCIA_SEPARACION_ENEMY:
			enemigos.append(nodo)

	return enemigos
	
# =========================================================
# SEPARACIÓN - CALCULAR FUERZA
# =========================================================

func calcular_separacion_enemigos() -> Vector2:

	var separacion := Vector2.ZERO

	for enemigo in obtener_enemigos_cercanos():

		var diferencia := (
			global_position
			- enemigo.global_position
		)

		var distancia := diferencia.length()

		if distancia <= 0.01:
			continue

		var fuerza := (
			1.0
			- distancia / DISTANCIA_SEPARACION_ENEMY
		)

		separacion += (
			diferencia.normalized()
			* fuerza
			* FUERZA_SEPARACION_ENEMY
		)

	return separacion

# =========================================================
# 31. IA - PERSECUCIÓN
# =========================================================

func ejecutar_persecucion(delta: float) -> void:

	if jugador == null:

		estado = Estado.PATRULLANDO

		return

	var diferencia_x := (
		jugador.global_position.x
		- global_position.x
	)

	var distancia_x := absf(diferencia_x)

	var direccion_x := signf(diferencia_x)

	if is_zero_approx(direccion_x):

		velocity.x = move_toward(
			velocity.x,
			0.0,
			DESACELERACION * delta
		)

		reproducir_animacion("standing")

		return

	sprite.flip_h = direccion_x < 0.0
	actualizar_direccion_hitbox()

	# -----------------------------------------------------
	# SUELO
	# -----------------------------------------------------

	var suelo_al_frente := hay_suelo(
		direccion_x,
		28.0
	)

	# -----------------------------------------------------
	# PARED
	# -----------------------------------------------------

	var pared := hay_pared(
		direccion_x,
		24.0
	)

	# -----------------------------------------------------
	# PLAYER MÁS ALTO
	# -----------------------------------------------------

	var jugador_mas_alto := (
		jugador.global_position.y
		< global_position.y - 25.0
	)

	# -----------------------------------------------------
	# SALTO
	# -----------------------------------------------------

	if (
		is_on_floor()
		and (
			pared
			or (
				jugador_mas_alto
				and distancia_x
				<= DISTANCIA_SALTO_HORIZONTAL
			)
		)
	):

		if hay_espacio_para_saltar(direccion_x):

			velocity.y = FUERZA_SALTO

			velocity.x = (
				direccion_x
				* VELOCIDAD_TROTE
			)

			reproducir_animacion("jump")

			return

	# -----------------------------------------------------
	# ABISMO
	# -----------------------------------------------------

	if not suelo_al_frente and is_on_floor():

		velocity.x = move_toward(
			velocity.x,
			0.0,
			DESACELERACION * delta
		)

		reproducir_animacion("standing")

		_intentar_interceptar_plataforma(true)

		return

	# -----------------------------------------------------
	# VELOCIDAD
	# -----------------------------------------------------

	var velocidad_objetivo := (
		VELOCIDAD_CARRERA
		if distancia_x > 140.0
		else VELOCIDAD_TROTE
	)


	# =====================================================
	# SEPARACIÓN ENTRE ENEMIGOS
	# =====================================================

	separacion_enemigos = calcular_separacion_enemigos()

	var velocidad_persecucion := (
		direccion_x * velocidad_objetivo
	)

	# Aplicar separación horizontal.

	velocidad_persecucion += separacion_enemigos.x

	velocity.x = move_toward(
		velocity.x,
		velocidad_persecucion,
		ACELERACION * delta
	)

	actualizar_animacion_movimiento(
		velocidad_objetivo == VELOCIDAD_CARRERA
	)

# =========================================================
# 32. IA - POSICIONAMIENTO DE COMBATE
# =========================================================

func ejecutar_posicionamiento(delta: float) -> void:

	if jugador == null or not is_instance_valid(jugador):

		estado = Estado.PATRULLANDO

		return

	var diferencia_x := (
		jugador.global_position.x
		- global_position.x
	)

	var diferencia_y := (
		jugador.global_position.y
		- global_position.y
	)

	var distancia_x := absf(diferencia_x)

	var direccion_x := signf(diferencia_x)

	if is_zero_approx(direccion_x):

		velocity.x = move_toward(
			velocity.x,
			0.0,
			DESACELERACION * delta
		)

		reproducir_animacion("standing")

		return

	# -----------------------------------------------------
	# SI EL PLAYER SE ALEJÓ
	# -----------------------------------------------------

	if distancia_x > DISTANCIA_ATAQUE:

		estado = Estado.PERSEGUIR

		return

	# -----------------------------------------------------
	# PLAYER DEMASIADO LEJOS PARA POSICIONARSE
	# -----------------------------------------------------

	if distancia_x > DISTANCIA_COMBATE_MINIMA:

		estado = Estado.PERSEGUIR

		return

	# -----------------------------------------------------
	# MIRAR AL PLAYER
	# -----------------------------------------------------

	sprite.flip_h = direccion_x < 0.0
	actualizar_direccion_hitbox()

	# -----------------------------------------------------
	# ATAQUE
	# -----------------------------------------------------

	if (
		distancia_x <= DISTANCIA_ATAQUE
		and absf(diferencia_y) <= 45.0
		and timer_cooldown_ataque <= 0.0
		and is_on_floor()
	):

		preparar_ataque()

		return

	# -----------------------------------------------------
	# PLAYER DEMASIADO CERCA
	# -----------------------------------------------------

	if distancia_x < DISTANCIA_RETROCESO:

		velocity.x = move_toward(
			velocity.x,
			-direccion_x * VELOCIDAD_TROTE * 0.45,
			DESACELERACION * delta
		)

		actualizar_animacion_movimiento(false)

		return

	# -----------------------------------------------------
	# ZONA DE COMBATE
	# -----------------------------------------------------

	velocity.x = move_toward(
		velocity.x,
		0.0,
		DESACELERACION * delta
	)

	reproducir_animacion("standing")

# =========================================================
# 33. COMBATE - PREPARACIÓN DE ATAQUE
# =========================================================

func preparar_ataque() -> void:

	if jugador == null:
		return

	if timer_cooldown_ataque > 0.0:
		return

	estado = Estado.ANTICIPANDO_ATAQUE

	timer_ataque = TIEMPO_VIENTO_ATAQUE

	velocity.x = 0.0

	var direccion := signf(
		jugador.global_position.x
		- global_position.x
	)

	if not is_zero_approx(direccion):

		sprite.flip_h = direccion < 0.0
		actualizar_direccion_hitbox()

	reproducir_animacion("standing")


# =========================================================
# 34. COMBATE - ANTICIPACIÓN
# =========================================================

func ejecutar_anticipacion(delta: float) -> void:

	velocity.x = move_toward(
		velocity.x,
		0.0,
		DESACELERACION * delta
	)

	timer_ataque -= delta

	if timer_ataque <= 0.0:

		iniciar_ataque()


# =========================================================
# 35. COMBATE - INICIAR ATAQUE
# =========================================================

func iniciar_ataque() -> void:

	if estado == Estado.MUERTO:
		return

	if jugador == null:
		return

	estado = Estado.ATACANDO

	velocity.x = 0.0

	objetivos_golpeados.clear()

	desactivar_hitbox_ataque()

	impulso_ataque_aplicado = false

	sprite.frame = 0

	reproducir_animacion("attack")


# =========================================================
# 36. COMBATE - EJECUTAR ATAQUE
# =========================================================

func ejecutar_ataque(delta: float) -> void:

	# =====================================================
	# DIRECCIÓN DEL ATAQUE
	# =====================================================

	var direccion := (
		-1.0
		if sprite.flip_h
		else 1.0
	)

	# =====================================================
	# PEQUEÑO IMPULSO INICIAL
	# =====================================================

	if not impulso_ataque_aplicado:

		velocity.x = direccion * IMPULSO_ATAQUE

		impulso_ataque_aplicado = true

	# =====================================================
	# FRENAR DESPUÉS DEL IMPULSO
	# =====================================================

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			FRENADO_ATAQUE * delta
		)

	# =====================================================
	# HITBOX
	# =====================================================

	_actualizar_ventana_ataque()


# =========================================================
# 37. COMBATE - VENTANA DE ATAQUE
# =========================================================

func _actualizar_ventana_ataque() -> void:

	if sprite.animation != "attack":

		desactivar_hitbox_ataque()

		return

	var frame_actual := sprite.frame

	var golpe_activo := (
		frame_actual >= FRAME_ATAQUE_INICIO
		and frame_actual <= FRAME_ATAQUE_FIN
	)

	if golpe_activo:

		activar_hitbox_ataque()

		_procesar_hurtboxes_dentro_del_hitbox()

	else:

		desactivar_hitbox_ataque()


# =========================================================
# 38. COMBATE - HITBOX
# =========================================================

func activar_hitbox_ataque() -> void:

	if ataque_hitbox_activo:
		return

	ataque_hitbox_activo = true

	hitbox_ataque.set_deferred(
		"monitoring",
		true
	)

	collision_hitbox.set_deferred(
		"disabled",
		false
	)


func desactivar_hitbox_ataque() -> void:

	if not ataque_hitbox_activo:

		hitbox_ataque.set_deferred(
			"monitoring",
			false
		)

		collision_hitbox.set_deferred(
			"disabled",
			true
		)

		return

	ataque_hitbox_activo = false

	hitbox_ataque.set_deferred(
		"monitoring",
		false
	)

	collision_hitbox.set_deferred(
		"disabled",
		true
	)


# =========================================================
# 39. COMBATE - DIRECCIÓN HITBOX
# =========================================================

func actualizar_direccion_hitbox() -> void:

	if collision_hitbox == null:
		return

	if sprite.flip_h:

		collision_hitbox.position.x = (
			-HITBOX_OFFSET_X
		)

	else:

		collision_hitbox.position.x = (
			HITBOX_OFFSET_X
		)

	collision_hitbox.position.y = HITBOX_OFFSET_Y


# =========================================================
# 40. COMBATE - DETECCIÓN DE HURTBOX
# =========================================================

func _on_hitbox_ataque_area_entered(
	area: Area2D
) -> void:

	if not ataque_hitbox_activo:
		return

	procesar_hurtbox_player(area)


func procesar_hurtbox_player(area: Area2D) -> void:

	if area == null:
		return

	if not is_instance_valid(area):
		return

	# -----------------------------------------------------
	# SOLAMENTE PLAYER HURTBOX
	# -----------------------------------------------------

	if not area.is_in_group("player_hurtbox"):
		return

	# -----------------------------------------------------
	# OBTENER PLAYER
	# -----------------------------------------------------

	var objetivo := area.get_parent()

	if objetivo == null:
		return

	if not objetivo.is_in_group("Player"):

		if not objetivo.is_in_group("player"):
			return

	# -----------------------------------------------------
	# EVITAR GOLPES REPETIDOS
	# -----------------------------------------------------

	if objetivos_golpeados.has(objetivo):
		return

	objetivos_golpeados.append(objetivo)

	# -----------------------------------------------------
	# DIRECCIÓN DEL EMPUJE
	# -----------------------------------------------------

	var direccion_empuje := 1.0

	if sprite.flip_h:

		direccion_empuje = -1.0

	# -----------------------------------------------------
	# APLICAR DAÑO / EMPUJE
	# -----------------------------------------------------

	if objetivo.has_method("recibir_empuje"):

		objetivo.recibir_empuje(
			direccion_empuje
			* FUERZA_EMPUJE_ATAQUE,
			FUERZA_EMPUJE_VERTICAL
		)


# =========================================================
# 41. COMBATE - OVERLAPS EXISTENTES
# =========================================================

func _procesar_hurtboxes_dentro_del_hitbox() -> void:

	if not ataque_hitbox_activo:
		return

	if not hitbox_ataque.monitoring:
		return

	var areas := (
		hitbox_ataque.get_overlapping_areas()
	)

	for area in areas:

		if area is Area2D:

			procesar_hurtbox_player(
				area
			)


# =========================================================
# 42. COMBATE - RECUPERACIÓN
# =========================================================

func ejecutar_recuperacion(delta: float) -> void:

	velocity.x = move_toward(
		velocity.x,
		0.0,
		DESACELERACION * delta
	)

	reproducir_animacion("standing")

	timer_ataque -= delta

	if timer_ataque > 0.0:
		return

	if jugador != null and is_instance_valid(jugador):

		if puede_ver_al_jugador():

			estado = Estado.PERSEGUIR

		else:

			estado = Estado.PATRULLANDO
			punto_origen_x = global_position.x

	else:

		estado = Estado.PATRULLANDO
		punto_origen_x = global_position.x

# =========================================================
# 43. COMBATE - FIN DE ANIMACIÓN
# =========================================================

func _on_animation_finished() -> void:

	match sprite.animation:

		"attack":

			desactivar_hitbox_ataque()

			objetivos_golpeados.clear()

			impulso_ataque_aplicado = false

			estado = Estado.RECUPERACION

			timer_cooldown_ataque = (
				TIEMPO_RECUPERACION_ATAQUE
			)

			timer_ataque = (
				TIEMPO_RECUPERACION_ATAQUE
			)

			reproducir_animacion("standing")

# =========================================================
# 45. PLATAFORMAS - INTERCEPCIÓN
# =========================================================

func _intentar_interceptar_plataforma(
	puede_ver: bool
) -> void:

	if estado not in [
		Estado.PATRULLANDO,
		Estado.PERSEGUIR
	]:

		return

	if not is_on_floor():
		return

	if timer_cooldown_plataforma > 0.0:
		return

	var plataforma := buscar_plataforma_cercana()

	if plataforma == null:
		return

	var diferencia_x := (
		plataforma.global_position.x
		- global_position.x
	)

	var direccion_plataforma := signf(
		diferencia_x
	)

	if is_zero_approx(
		direccion_plataforma
	):

		return

	var hay_abismo := not hay_suelo(
		direccion_patrulla,
		25.0
	)

	var necesita_cruzar := (
		hay_abismo
		and direccion_plataforma
		== direccion_patrulla
	)

	var persigue_hacia_plataforma := false

	if puede_ver and jugador != null:

		var direccion_jugador := signf(
			jugador.global_position.x
			- global_position.x
		)

		persigue_hacia_plataforma = (
			direccion_jugador
			== direccion_plataforma
		)

	if not (
		necesita_cruzar
		or persigue_hacia_plataforma
	):

		return

	if randf() < 0.65:

		plataforma_objetivo = plataforma

		estado = (
			Estado.INTERCEPTANDO_PLATAFORMA
		)

	else:

		timer_cooldown_plataforma = (
			COOLDOWN_REINTENTO_PLATAFORMA
		)


# =========================================================
# 46. PLATAFORMAS - INTERCEPTAR
# =========================================================

func ejecutar_intercepcion_plataforma(
	delta: float
) -> void:

	if (
		plataforma_objetivo == null
		or not is_instance_valid(
			plataforma_objetivo
		)
	):

		plataforma_objetivo = null

		estado = Estado.PERSEGUIR

		return

	var velocidad_plataforma := (
		obtener_velocidad_plataforma(
			plataforma_objetivo
		)
	)

	var posicion_proyectada := (
		plataforma_objetivo.global_position
		+ velocidad_plataforma * 0.25
	)

	var diferencia := (
		posicion_proyectada
		- global_position
	)

	var distancia_x := absf(
		diferencia.x
	)

	var direccion_x := signf(
		diferencia.x
	)

	if not is_zero_approx(direccion_x):

		sprite.flip_h = (
			direccion_x < 0.0
		)

		actualizar_direccion_hitbox()

	# -----------------------------------------------------
	# PLATAFORMA ARRIBA
	# -----------------------------------------------------

	if (
		diferencia.y < -20.0
		and diferencia.y > -110.0
		and distancia_x < 130.0
		and is_on_floor()
	):

		velocity.y = FUERZA_SALTO

		velocity.x = (
			direccion_x
			* VELOCIDAD_CARRERA
		)

		reproducir_animacion("jump")

		return

	# -----------------------------------------------------
	# BORDE
	# -----------------------------------------------------

	if is_on_floor():

		var borde := not hay_suelo(
			direccion_x,
			22.0
		)

		if (
			borde
			and distancia_x < 130.0
		):

			velocity.y = (
				FUERZA_SALTO * 0.85
			)

			velocity.x = (
				direccion_x
				* VELOCIDAD_CARRERA
			)

			reproducir_animacion("jump")

			return

	# -----------------------------------------------------
	# DESPLAZAMIENTO
	# -----------------------------------------------------

	var velocidad_objetivo := (
		VELOCIDAD_CARRERA
		if distancia_x > 90.0
		else VELOCIDAD_TROTE
	)

	velocity.x = move_toward(
		velocity.x,
		direccion_x * velocidad_objetivo,
		ACELERACION * delta
	)

	actualizar_animacion_movimiento(
		velocidad_objetivo
		== VELOCIDAD_CARRERA
	)


# =========================================================
# 47. PLATAFORMAS - EN PLATAFORMA
# =========================================================

func ejecutar_en_plataforma(
	delta: float
) -> void:

	if plataforma_actual == null:

		estado = (
			Estado.PERSEGUIR
			if _puede_perseguir_jugador()
			else Estado.PATRULLANDO
		)

		return

	var velocidad_plataforma := (
		obtener_velocidad_plataforma(
			plataforma_actual
		)
	)

	# -----------------------------------------------------
	# BUSCAR DESEMBARCO
	# -----------------------------------------------------

	var direcciones := (
		obtener_direcciones_desembarco()
	)

	var encontrado := false
	var direccion_desembarco := 0.0
	var necesita_salto := false

	for direccion in direcciones:

		if hay_suelo_estatico(
			direccion,
			ALCANCE_DESEMBARCO,
			PROFUNDIDAD_DESEMBARCO
		):

			encontrado = true
			direccion_desembarco = direccion
			necesita_salto = false

			break

		if hay_suelo_estatico(
			direccion,
			ALCANCE_SALTO_DESEMBARCO,
			PROFUNDIDAD_SALTO_DESEMBARCO
		):

			encontrado = true
			direccion_desembarco = direccion
			necesita_salto = true

			break

	# -----------------------------------------------------
	# DESEMBARCAR
	# -----------------------------------------------------

	if is_on_floor() and encontrado:

		sprite.flip_h = (
			direccion_desembarco < 0.0
		)

		actualizar_direccion_hitbox()

		if necesita_salto:

			velocity.y = (
				FUERZA_SALTO * 0.85
			)

			velocity.x = (
				direccion_desembarco
				* VELOCIDAD_CARRERA
				+ velocidad_plataforma.x
			)

			reproducir_animacion("jump")

		else:

			velocity.x = (
				direccion_desembarco
				* VELOCIDAD_CARRERA
				+ velocidad_plataforma.x
			)

			actualizar_animacion_movimiento(true)

		plataforma_actual = null
		plataforma_objetivo = null

		timer_cooldown_plataforma = (
			COOLDOWN_REINTENTO_PLATAFORMA
		)

		punto_origen_x = global_position.x

		estado = (
			Estado.PERSEGUIR
			if _puede_perseguir_jugador()
			else Estado.PATRULLANDO
		)

		return

	# -----------------------------------------------------
	# PERMANECER EN PLATAFORMA
	# -----------------------------------------------------

	if is_on_floor():

		velocity.x = move_toward(
			velocity.x,
			velocidad_plataforma.x,
			DESACELERACION * delta
		)

		reproducir_animacion("standing")

	else:

		actualizar_animacion_movimiento(false)


# =========================================================
# 48. PLATAFORMAS - DIRECCIONES DE DESEMBARCO
# =========================================================

func obtener_direcciones_desembarco() -> Array[float]:

	var direcciones: Array[float] = [
		1.0,
		-1.0
	]

	if (
		jugador != null
		and puede_ver_al_jugador()
	):

		var direccion_jugador := signf(
			jugador.global_position.x
			- global_position.x
		)

		if not is_zero_approx(
			direccion_jugador
		):

			direcciones = [
				direccion_jugador,
				-direccion_jugador
			]

	return direcciones


# =========================================================
# 49. PLATAFORMAS - VELOCIDAD
# =========================================================

func obtener_velocidad_plataforma(
	plataforma: AnimatableBody2D
) -> Vector2:

	if plataforma == null:
		return Vector2.ZERO

	if not is_instance_valid(plataforma):
		return Vector2.ZERO

	var valor: Variant = plataforma.get(
		"velocidad_lineal_calculada"
	)

	if valor is Vector2:
		return valor as Vector2

	return Vector2.ZERO


# =========================================================
# 50. PLATAFORMAS - DETECTAR ACTUAL
# =========================================================

func actualizar_plataforma_actual() -> void:

	var encontrada: AnimatableBody2D = null

	# -----------------------------------------------------
	# COLISIÓN
	# -----------------------------------------------------

	if is_on_floor():

		var collision := (
			get_last_slide_collision()
		)

		if collision != null:

			var collider := (
				collision.get_collider()
			)

			if (
				collider is AnimatableBody2D
				and collider.is_in_group(
					"plataforma_movil"
				)
			):

				encontrada = collider

	# -----------------------------------------------------
	# RAYCAST
	# -----------------------------------------------------

	if encontrada == null and is_on_floor():

		var espacio := (
			get_world_2d()
			.direct_space_state
		)

		var origen := (
			global_position
			+ Vector2(0.0, 2.0)
		)

		var destino := (
			global_position
			+ Vector2(0.0, 35.0)
		)

		var query := (
			PhysicsRayQueryParameters2D.create(
				origen,
				destino
			)
		)

		query.exclude = [self]
		query.collision_mask = mascara_terreno

		var resultado := (
			espacio.intersect_ray(query)
		)

		if not resultado.is_empty():

			var collider = (
				resultado.collider
			)

			if (
				collider is AnimatableBody2D
				and collider.is_in_group(
					"plataforma_movil"
				)
			):

				encontrada = collider

	plataforma_actual = encontrada


# =========================================================
# 51. PLATAFORMAS - BUSCAR CERCANA
# =========================================================

func buscar_plataforma_cercana() -> AnimatableBody2D:

	var plataformas := (
		get_tree().get_nodes_in_group(
			"plataforma_movil"
		)
	)

	var plataforma_mas_cercana: AnimatableBody2D = null

	var distancia_minima := (
		DISTANCIA_RADAR_PLATAFORMA
	)

	for nodo in plataformas:

		if not nodo is AnimatableBody2D:
			continue

		var plataforma := (
			nodo as AnimatableBody2D
		)

		var diferencia := (
			plataforma.global_position
			- global_position
		)

		if (
			absf(diferencia.y)
			> DISTANCIA_VERTICAL_PLATAFORMA
		):

			continue

		var distancia := (
			diferencia.length()
		)

		if distancia < distancia_minima:

			distancia_minima = distancia

			plataforma_mas_cercana = (
				plataforma
			)

	return plataforma_mas_cercana


# =========================================================
# 52. PERCEPCIÓN - PLAYER
# =========================================================

func puede_ver_al_jugador() -> bool:

	if jugador == null:
		return false

	if not is_instance_valid(jugador):
		return false

	var diferencia := (
		jugador.global_position
		- global_position
	)

	if diferencia.length() > DISTANCIA_DETECCION:
		return false

	if (
		absf(diferencia.y)
		> DIFERENCIA_VERTICAL_MAXIMA
	):

		return false

	var espacio := (
		get_world_2d()
		.direct_space_state
	)

	var origen := (
		global_position
		+ Vector2(0.0, -12.0)
	)

	var destino := (
		jugador.global_position
		+ Vector2(0.0, -12.0)
	)

	var query := (
		PhysicsRayQueryParameters2D.create(
			origen,
			destino
		)
	)

	query.exclude = [self]
	query.collision_mask = mascara_terreno

	var colision := (
		espacio.intersect_ray(query)
	)

	return colision.is_empty()


# =========================================================
# 53. ENTORNO - SUELO
# =========================================================

func hay_suelo(
	direccion: float,
	avance: float
) -> bool:

	if is_zero_approx(direccion):
		return true

	var espacio := (
		get_world_2d()
		.direct_space_state
	)

	var origen := (
		global_position
		+ Vector2(
			direccion * avance,
			5.0
		)
	)

	var destino := (
		origen
		+ Vector2(0.0, 38.0)
	)

	var query := (
		PhysicsRayQueryParameters2D.create(
			origen,
			destino
		)
	)

	query.exclude = [self]
	query.collision_mask = mascara_terreno

	return not (
		espacio.intersect_ray(query)
	).is_empty()


# =========================================================
# 54. ENTORNO - SUELO ESTÁTICO
# =========================================================

func hay_suelo_estatico(
	direccion: float,
	avance: float,
	profundidad: float = 38.0
) -> bool:

	var espacio := (
		get_world_2d()
		.direct_space_state
	)

	var origen := (
		global_position
		+ Vector2(
			direccion * avance,
			5.0
		)
	)

	var destino := (
		origen
		+ Vector2(
			0.0,
			profundidad
		)
	)

	var query := (
		PhysicsRayQueryParameters2D.create(
			origen,
			destino
		)
	)

	query.exclude = [self]
	query.collision_mask = mascara_terreno

	var colision := (
		espacio.intersect_ray(query)
	)

	if colision.is_empty():
		return false

	var objeto: Object = (
		colision.collider
	)

	return not (
		objeto is AnimatableBody2D
		and objeto.is_in_group(
			"plataforma_movil"
		)
	)


# =========================================================
# 55. ENTORNO - PARED
# =========================================================

func hay_pared(
	direccion: float,
	distancia: float
) -> bool:

	if is_zero_approx(direccion):
		return false

	var espacio := (
		get_world_2d()
		.direct_space_state
	)

	var origen := (
		global_position
		+ Vector2(0.0, -12.0)
	)

	var destino := (
		origen
		+ Vector2(
			direccion * distancia,
			0.0
		)
	)

	var query := (
		PhysicsRayQueryParameters2D.create(
			origen,
			destino
		)
	)

	query.exclude = [self]
	query.collision_mask = mascara_terreno

	return not (
		espacio.intersect_ray(query)
	).is_empty()


# =========================================================
# 56. ENTORNO - ESPACIO PARA SALTAR
# =========================================================

func hay_espacio_para_saltar(
	direccion: float
) -> bool:

	if is_zero_approx(direccion):
		return false

	var espacio := (
		get_world_2d()
		.direct_space_state
	)

	var origen := (
		global_position
		+ Vector2(0.0, -15.0)
	)

	var destino := (
		origen
		+ Vector2(
			direccion * 20.0,
			-55.0
		)
	)

	var query := (
		PhysicsRayQueryParameters2D.create(
			origen,
			destino
		)
	)

	query.exclude = [self]
	query.collision_mask = mascara_terreno

	return (
		espacio.intersect_ray(query)
	).is_empty()


# =========================================================
# 57. PLAYER - BÚSQUEDA
# =========================================================

func buscar_jugador() -> void:

	var nodo := (
		get_tree()
		.get_first_node_in_group("Player")
	)

	if nodo == null:

		nodo = (
			get_tree()
			.get_first_node_in_group("player")
		)

	if nodo is CharacterBody2D:

		jugador = nodo

	else:

		jugador = null


# =========================================================
# 58. PLAYER - VALIDAR PERSECUCIÓN
# =========================================================

func _puede_perseguir_jugador() -> bool:

	return (
		jugador != null
		and is_instance_valid(jugador)
		and perseguir_jugador
		and puede_ver_al_jugador()
	)


# =========================================================
# 59. ANIMACIONES - MOVIMIENTO
# =========================================================

func actualizar_animacion_movimiento(
	corriendo: bool
) -> void:

	if not is_on_floor():

		reproducir_animacion("jump")

	elif absf(velocity.x) > 10.0:

		if (
			corriendo
			and sprite.sprite_frames.has_animation(
				"run"
			)
		):

			reproducir_animacion("run")

		else:

			reproducir_animacion("trot")

	else:

		reproducir_animacion("standing")


# =========================================================
# 60. ANIMACIONES - REPRODUCIR
# =========================================================

func reproducir_animacion(
	nombre: String
) -> void:

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(
		nombre
	):

		return

	if (
		sprite.animation == nombre
		and sprite.is_playing()
	):

		return

	sprite.play(nombre)


# =========================================================
# 61. CICLO DE VIDA - MUERTE
# =========================================================

func morir() -> void:

	if esta_muerto():
		return

	estado = Estado.MUERTO

	velocity = Vector2.ZERO

	velocidad_knockback = 0.0

	plataforma_actual = null
	plataforma_objetivo = null

	objetivos_golpeados.clear()

	desactivar_hitbox_ataque()

	reproducir_animacion(
		"fall_on_ground"
	)


# =========================================================
# 62. CICLO DE VIDA - ESTADO MUERTO
# =========================================================

func esta_muerto() -> bool:

	return estado == Estado.MUERTO


# =========================================================
# 63. CICLO DE VIDA - REINICIO
# =========================================================

func reiniciar() -> void:

	estado = Estado.PATRULLANDO

	global_position = posicion_inicial

	velocity = Vector2.ZERO

	velocidad_knockback = 0.0

	gravedad_actual = GRAVEDAD

	timer_patrulla = 0.0
	timer_ataque = 0.0
	timer_cooldown_ataque = 0.0

	timer_inercia_portal = 0.0
	timer_cooldown_plataforma = 0.0
	timer_perdida_jugador = 0.0

	plataforma_actual = null
	plataforma_objetivo = null

	objetivos_golpeados.clear()

	punto_origen_x = global_position.x

	reiniciar_vida()

	desactivar_hitbox_ataque()

	reproducir_animacion("standing")


# =========================================================
# 64. KNOCKBACK - RECIBIR EMPUJE
# =========================================================

func recibir_empuje(
	direccion: float,
	fuerza_vertical: float = FUERZA_KNOCKBACK_VERTICAL
) -> void:

	if esta_muerto():
		return

	var direccion_segura := signf(
		direccion
	)

	if is_zero_approx(
		direccion_segura
	):

		return

	velocidad_knockback = (
		direccion_segura
		* FUERZA_KNOCKBACK_HORIZONTAL
	)

	velocity.y = fuerza_vertical

	if estado in [
		Estado.ATACANDO,
		Estado.ANTICIPANDO_ATAQUE
	]:

		desactivar_hitbox_ataque()

		estado = Estado.RECUPERACION

		timer_cooldown_ataque = 0.5
		timer_ataque = 0.5


# =========================================================
# 65. GRAVEDAD / DAMPING - API EXTERNA
# =========================================================

func cambiar_gravedad(
	invertir: bool = true
) -> void:

	if invertir:

		gravedad_actual = -GRAVEDAD

	else:

		gravedad_actual = GRAVEDAD


func aplicar_damping(
	x: float = 0.0
) -> void:

	damping_entorno = maxf(
		x,
		0.0
	)
