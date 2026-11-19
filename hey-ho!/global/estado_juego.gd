class_name EstadoJuego
extends RefCounted
## Estado compartido entre escenas SIN autoload: todo es estático.
## Así no hay que tocar project.godot y cualquier escena puede leerlo.
##
## Reglas que implementa (del Documento de concepto del equipo):
##  - Un nivel se aprueba con el 60 % del oro posible (3 clientes x 30 oro = 90 -> mínimo 54).
##  - El oro de los niveles aprobados se ahorra para reparar el barco (300 oro) o reforzar sogas.
##  - Reforzar una soga cuesta 20 oro, suma 25 (máximo 100) y solo se ofrece si está bajo 75.

## >>> CAMBIAR por la escena real del nivel cuando el equipo la tenga.
const RUTA_NIVEL := "res://ui/juego/demo_nivel.tscn"
const RUTA_GUARDADO := "user://hey_ho.cfg"

const TOTAL_NIVELES := 5
## Cuántos niveles están construidos. Los demás se muestran como "PRÓXIMAMENTE".
## (Para la entrega con un solo nivel jugable, poner 1.)
const NIVELES_JUGABLES := 5

const COSTO_REPARACION := 300
const PORCENTAJE_MINIMO := 0.6
const ORO_POR_CLIENTE := 30
const COSTO_SOGA := 20
const REFUERZO_SOGA := 25.0
const SOGA_MAX := 100.0
const UMBRAL_TIENDA := 75.0

const PLATAFORMAS := ["lavadora", "tendedero", "despacho"]
const NOMBRES_PLATAFORMA := {"lavadora": "Lavadora", "tendedero": "Tendedero", "despacho": "Despacho"}
const CLIENTES := [3, 6, 9, 12, 15]
const DURACION := [120, 180, 240, 300, 360]

static var nivel_actual := 1
static var nivel_max_desbloqueado := 1
static var oro_total := 0
static var mejor_oro: Array[int] = [0, 0, 0, 0, 0]
static var sogas := {"lavadora": [100.0, 100.0], "tendedero": [100.0, 100.0], "despacho": [100.0, 100.0]}
static var ultimo := {}
static var volumen := 0.8
static var pantalla_completa := false
static var pistas_teclas := true
static var _cargado := false


## Datos de un nivel: clientes, duración (s), llegada entre barcos (s), oro máximo y oro mínimo.
static func datos_nivel(n: int) -> Dictionary:
	var i := clampi(n - 1, 0, TOTAL_NIVELES - 1)
	var clientes: int = CLIENTES[i]
	var duracion: int = DURACION[i]
	var oro_max := clientes * ORO_POR_CLIENTE
	return {
		"clientes": clientes,
		"duracion": duracion,
		"llegada": (duracion - 60.0) / (clientes - 1),
		"oro_max": oro_max,
		"minimo": int(round(oro_max * PORCENTAJE_MINIMO)),
	}


@warning_ignore("integer_division")
static func formato_tiempo(segundos: float) -> String:
	var s := maxi(0, int(ceil(segundos)))
	return "%d:%02d" % [s / 60, s % 60]


## Llamar cuando termina un nivel. Guarda el resultado en `ultimo` y devuelve el diccionario.
static func terminar_nivel(n: int, oro: int, atendidos: int, total_clientes: int,
		perdido_por_sogas := false) -> Dictionary:
	var d := datos_nivel(n)
	var paso := (not perdido_por_sogas) and oro >= int(d.minimo)
	var ahorrado := 0
	if paso:
		# Solo cuenta lo que mejora el mejor resultado aprobado (no se puede "cultivar" oro repitiendo).
		ahorrado = maxi(0, oro - mejor_oro[n - 1])
		oro_total += ahorrado
		mejor_oro[n - 1] = maxi(mejor_oro[n - 1], oro)
		if n < TOTAL_NIVELES:
			nivel_max_desbloqueado = maxi(nivel_max_desbloqueado, n + 1)
	ultimo = {
		"nivel": n, "oro": oro, "minimo": d.minimo, "oro_max": d.oro_max, "paso": paso,
		"atendidos": atendidos, "total_clientes": total_clientes,
		"perdido_por_sogas": perdido_por_sogas, "ahorrado": ahorrado,
	}
	guardar()
	return ultimo


## Compra un refuerzo para una soga. Devuelve true si se pudo.
static func comprar_soga(plataforma: String, indice: int) -> bool:
	if oro_total < COSTO_SOGA:
		return false
	var actual: float = sogas[plataforma][indice]
	if actual >= UMBRAL_TIENDA:
		return false
	sogas[plataforma][indice] = minf(SOGA_MAX, actual + REFUERZO_SOGA)
	oro_total -= COSTO_SOGA
	guardar()
	return true


static func reiniciar_sogas() -> void:
	sogas = {"lavadora": [100.0, 100.0], "tendedero": [100.0, 100.0], "despacho": [100.0, 100.0]}


static func borrar_progreso() -> void:
	nivel_actual = 1
	nivel_max_desbloqueado = 1
	oro_total = 0
	mejor_oro = [0, 0, 0, 0, 0]
	ultimo = {}
	reiniciar_sogas()
	guardar()


static func aplicar_ajustes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volumen, 0.0001)))
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)


static func asegurar_carga() -> void:
	if _cargado:
		return
	_cargado = true
	cargar()
	aplicar_ajustes()


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "nivel_max", nivel_max_desbloqueado)
	cfg.set_value("progreso", "oro_total", oro_total)
	cfg.set_value("progreso", "mejor_oro", Array(mejor_oro))
	for p: String in PLATAFORMAS:
		cfg.set_value("sogas", p, sogas[p])
	cfg.set_value("ajustes", "volumen", volumen)
	cfg.set_value("ajustes", "pantalla_completa", pantalla_completa)
	cfg.set_value("ajustes", "pistas_teclas", pistas_teclas)
	cfg.save(RUTA_GUARDADO)


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_GUARDADO) != OK:
		return
	nivel_max_desbloqueado = clampi(int(cfg.get_value("progreso", "nivel_max", 1)), 1, TOTAL_NIVELES)
	oro_total = maxi(0, int(cfg.get_value("progreso", "oro_total", 0)))
	var mejores: Array = cfg.get_value("progreso", "mejor_oro", [])
	for i in mini(mejores.size(), TOTAL_NIVELES):
		mejor_oro[i] = int(mejores[i])
	for p: String in PLATAFORMAS:
		var v: Array = cfg.get_value("sogas", p, [100.0, 100.0])
		if v.size() == 2:
			sogas[p] = [float(v[0]), float(v[1])]
	volumen = clampf(float(cfg.get_value("ajustes", "volumen", 0.8)), 0.0, 1.0)
	pantalla_completa = bool(cfg.get_value("ajustes", "pantalla_completa", false))
	pistas_teclas = bool(cfg.get_value("ajustes", "pistas_teclas", true))
