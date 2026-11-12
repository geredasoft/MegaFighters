class_name ArmaParams
extends Resource

enum TipoProyectil {
	BALA,
	EXPLOSION,
	DISPERSION,
	PARTICULAS,
	RAFAGA,
	ARMA_BLANCA,
}

@export var dos_manos: bool
@export var textura: Texture2D
@export var municion: int
@export var proyectil: TipoProyectil
@export var dano: int
@export var cadencia_ms: float

# Esta variable tiene distintos tipos dependiendo del valor de "proyectil":
# BALA -> null
# EXPLOSION -> DatosExplosion
# DISPERSION -> DatosDispersion
# PARTICULAS -> DatosParticulas
# RAFAGA -> DatosRafaga
# ARMA_BLANCA -> DatosArmaBlanca
@export var datos: DatosProyectilBase = null

static func crear(
	dos_manos: bool,
	textura: Texture2D,
	municion: int,
	proyectil: TipoProyectil,
	dano: int,
	cadencia_ms: float,
	datos: DatosProyectilBase = null,
) -> ArmaParams:
	match proyectil:
		TipoProyectil.BALA:
			if datos is not DatosBala:
				return null
		TipoProyectil.EXPLOSION:
			if datos is not DatosExplosion:
				return null
		TipoProyectil.DISPERSION:
			if datos is not DatosDispersion:
				return null
		TipoProyectil.PARTICULAS:
			if datos is not DatosParticulas:
				return null
		TipoProyectil.RAFAGA:
			if datos is not DatosRafaga:
				return null
		TipoProyectil.ARMA_BLANCA:
			if datos is not DatosArmaBlanca:
				return null
	
	return ArmaParams.new(
		dos_manos,
		textura,
		municion,
		proyectil,
		dano,
		cadencia_ms,
		datos
		)

func _init(
	dos_manos: bool,
	textura: Texture2D,
	municion: int = 0,
	proyectil: TipoProyectil = TipoProyectil.BALA,
	dano: int = 0,
	cadencia_ms: float = 0.0,
	datos: DatosProyectilBase = null,
) -> void:
	self.dos_manos = dos_manos
	self.textura = textura
	self.municion = municion
	self.proyectil = proyectil
	self.dano = dano
	self.cadencia_ms = cadencia_ms
	self.datos = datos
