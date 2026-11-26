class_name SistemaSogas
extends Node3D
## Sogas de las tres plataformas (lavadora, tendedero y despacho), dos por plataforma.
## El desgaste se VE sobre la propia soga: pasa de su color original (madera) a rojo a medida que se gasta.
##   Desgaste total (resistencia 0) -> la soga queda CRÍTICA: parpadea en rojo y tiene T_ROTURA (30 s) para repararse.
##   Reparada a tiempo              -> no cuesta nada.
##   Pasan los 30 s sin repararla   -> la soga se ROMPE y la plataforma queda DESESTABILIZADA. Repararla ya cuesta
##                                     COSTO_REPARACION (5 monedas).
##   Las dos sogas rotas            -> la plataforma se suelta y se PIERDE el nivel.
##   Bajo 30 de resistencia         -> la franja de la resortera se angosta (0,3 s -> 0,15 s) y el sol se pone en alerta.
## Reparar: mantener una tecla 2 s con el personaje JUNTO A LA SOGA (a menos de ALCANCE_REPARACION en x). Cada soga
## se repara por separado. La tecla la lee quien controla al jugador (el controlador del nivel).
##
## DISTRIBUCIÓN (vista desde arriba, igual que el esquema del equipo; coordenadas del mapa de Isabella):
##   La plataforma CENTRAL (donde camina el pirata) queda en medio y cada plataforma cuelga de ella con 2 sogas:
##     LAVADORA (arriba)    -> 2 sogas en el hueco entre la lavadora y la central
##     TENDEDERO (abajo)    -> 2 sogas en el hueco entre la central y el tendedero
##     DESPACHO (izquierda) -> 2 sogas en el hueco entre el despacho y la central

signal soga_cambio(plataforma: String, indice: int, resistencia: float)
signal plataforma_desestabilizada(plataforma: String, desestabilizada: bool)
signal reparacion_progreso(plataforma: String, fraccion: float)
signal reparacion_cobrada(costo: int)
signal soga_en_peligro(plataforma: String, indice: int)   # el desgaste llegó al máximo: empiezan los 30 s
signal soga_rota(plataforma: String, indice: int)         # pasaron los 30 s sin repararla
signal nivel_perdido

const RES_MAX := 100.0
const UMBRAL_PELIGRO := 30.0
const T_REPARAR := 2.0
const RES_REPARADA := 50.0
## Segundos que tiene el jugador para reparar una soga con el desgaste al máximo antes de que se rompa.
const T_ROTURA := 30.0
## Lo que cuesta reparar una soga YA ROTA (si se repara antes de romperse, no cuesta nada).
const COSTO_REPARACION := 5
const MADERA := Color("#8B5A2B")
const ROJO := Color("#D63A3A")
const ROJO_VIVO := Color("#FF2A2A")      # fase clara del parpadeo
const ROJO_OSCURO := Color("#4A0D0D")    # fase oscura del parpadeo
## A cuántos metros (en x) de la soga tiene que estar la mano del pirata para poder repararla.
const ALCANCE_REPARACION := 1.0

# Por plataforma y para cada una de sus 2 sogas:
#   pos   = centro de la soga EN COORDENADAS DEL MUNDO (el hueco entre la plataforma y la central)
#   size  = tamaño de la soga (el largo es lo que mide el hueco)
#   x     = en qué x del mundo hay que estar parado para repararla
#   ancla = valor (x del tiro; z en el despacho) con el que se elige qué soga se desgasta
const SOGAS := {
	"lavadora": {
		"pos": [Vector3(2.0, 0.07, -0.935), Vector3(5.6, 0.07, -0.935)], "size": Vector3(0.14, 0.14, 2.13),
		"x": [2.0, 5.6], "ancla": [2.0, 3.2]},
	"tendedero": {
		"pos": [Vector3(3.2, 0.07, 2.667), Vector3(6.7, 0.07, 2.667)], "size": Vector3(0.14, 0.14, 2.07),
		"x": [3.2, 6.7], "ancla": [5.0, 7.0]},
	"despacho": {
		"pos": [Vector3(0.72, 0.07, 0.4), Vector3(0.72, 0.07, 1.35)], "size": Vector3(1.48, 0.14, 0.14),
		"x": [0.72, 0.72], "ancla": [0.4, 1.35]},
}

@export var sistema_sol: SistemaSol
@export var desgaste_por_lanzamiento := 2.0
@export var desgaste_por_pedido := 4.0
## Multiplica todo el desgaste. Útil para DEMOSTRAR la mecánica sin jugar el nivel entero (por ejemplo 10).
@export var multiplicador_desgaste := 1.0
@export var modo_prueba := false

var sogas := {
	"lavadora": [RES_MAX, RES_MAX],
	"tendedero": [RES_MAX, RES_MAX],
	"despacho": [RES_MAX, RES_MAX],
}
var progreso := {"lavadora": 0.0, "tendedero": 0.0, "despacho": 0.0}
var desestab := {"lavadora": false, "tendedero": false, "despacho": false}
var visuales := {}
## Segundos que le quedan a cada soga CRÍTICA antes de romperse (-1 = no está crítica).
var tiempo_rotura := {
	"lavadora": [-1.0, -1.0],
	"tendedero": [-1.0, -1.0],
	"despacho": [-1.0, -1.0],
}
## Sogas ya rotas (repararlas cuesta COSTO_REPARACION).
var rotas := {
	"lavadora": [false, false],
	"tendedero": [false, false],
	"despacho": [false, false],
}
var barras_reparacion := {}                # plataforma -> barrita 3D que se llena mientras se repara
var _indice_reparando := {"lavadora": -1, "tendedero": -1, "despacho": -1}   # soga que se está reparando
var perdido := false
var plataforma_cercana := ""
var reparacion_bloqueada := false


func _ready() -> void:
	_crear_visuales()
	if modo_prueba:
		soga_cambio.connect(func(p, i, r): print("soga ", p, " ", i, ": ", snappedf(r, 0.1)))
		plataforma_desestabilizada.connect(func(p, d): print("plataforma ", p, " desestabilizada: ", d))
		nivel_perdido.connect(func(): print("nivel perdido"))
		reparacion_cobrada.connect(func(c): print("cobro de reparación: ", c))


# ------------------------------------------------------------------ Consultas
static func ancho_franja(resistencia: float) -> float:
	return 0.15 if resistencia < UMBRAL_PELIGRO else 0.3


func resistencia_minima_de(p: String) -> float:
	return minf(sogas[p][0], sogas[p][1])


func resistencia_minima() -> float:
	var m := RES_MAX
	for p: String in sogas.keys():
		for r: float in sogas[p]:
			m = minf(m, r)
	return m


## La plataforma con la soga más dañada (la que se repara si no se indica otra).
func plataforma_mas_danada() -> String:
	var peor := "lavadora"
	var menor := RES_MAX + 1.0
	for p: String in sogas.keys():
		for r: float in sogas[p]:
			if r < menor:
				menor = r
				peor = p
	return peor


## La soga DAÑADA más urgente que está al alcance de esa x (la de menor resistencia): {"p": plataforma, "i": índice}.
## Devuelve {} si no hay ninguna dañada cerca.
func soga_cercana(x: float, alcance := ALCANCE_REPARACION) -> Dictionary:
	var mejor := {}
	var peor := RES_MAX
	for p: String in SOGAS.keys():
		var xs: Array = SOGAS[p]["x"]
		for i in 2:
			if absf(x - float(xs[i])) > alcance:
				continue
			var r: float = sogas[p][i]
			if r < peor:
				peor = r
				mejor = {"p": p, "i": i}
	return mejor


## ¿Hay alguna soga (sana o dañada) al alcance de esa x?
func hay_soga_cerca(x: float, alcance := ALCANCE_REPARACION) -> bool:
	for p: String in SOGAS.keys():
		for xs: float in SOGAS[p]["x"]:
			if absf(x - xs) <= alcance:
				return true
	return false


## Copia de las resistencias, para guardarlas entre niveles (por ejemplo en EstadoJuego.sogas).
func datos() -> Dictionary:
	return sogas.duplicate(true)


# ------------------------------------------------------------------ Desgaste
func registrar_lanzamiento(lado: String, x := NAN) -> void:
	var p := "lavadora" if lado == "izquierda" else "tendedero"
	_desgastar(p, x, desgaste_por_lanzamiento)


func registrar_pedido(z := NAN) -> void:
	_desgastar("despacho", z, desgaste_por_pedido)


# ------------------------------------------------------------------ Reparación
## Un paso de reparación. Devuelve true cuando se completa.
## Repara la soga `indice` de la plataforma (sin indicarlo, la más urgente: la de menor resistencia).
## Si estaba ROTA, cobra COSTO_REPARACION; si todavía no se había roto (aunque estuviera parpadeando), no cobra nada.
func reparar(p: String, delta: float, indice := -1) -> bool:
	if perdido:
		return false
	var i := indice if indice >= 0 else (0 if sogas[p][0] <= sogas[p][1] else 1)
	var actual: float = sogas[p][i]
	if actual >= RES_MAX:
		return false
	if _indice_reparando[p] != i:         # cambió de soga a mitad de la reparación: se empieza de cero
		progreso[p] = 0.0
		_indice_reparando[p] = i
	progreso[p] += delta
	reparacion_progreso.emit(p, clampf(progreso[p] / T_REPARAR, 0.0, 1.0))
	if progreso[p] >= T_REPARAR:
		progreso[p] = 0.0
		var estaba_rota: bool = rotas[p][i]
		rotas[p][i] = false
		tiempo_rotura[p][i] = -1.0           # deja de estar crítica: se reinicia la cuenta de los 30 s
		_poner(p, i, RES_REPARADA if actual <= 0.0 else actual + RES_REPARADA)
		if estaba_rota:
			reparacion_cobrada.emit(COSTO_REPARACION)
		return true
	return false


func soltar_reparar(p: String) -> void:
	_indice_reparando[p] = -1
	if progreso[p] > 0.0:
		progreso[p] = 0.0
		reparacion_progreso.emit(p, 0.0)


## Llamar cada fotograma MIENTRAS la tecla de reparar está presionada.
## Una reparación completa no se repite sola: hay que soltar la tecla y volver a mantenerla.
func mantener_reparacion(p: String, delta: float, indice := -1) -> void:
	if reparacion_bloqueada:
		return
	if reparar(p, delta, indice):
		reparacion_bloqueada = true


## Llamar cuando se suelta la tecla de reparar.
func soltar_reparacion() -> void:
	reparacion_bloqueada = false
	for p: String in sogas.keys():
		soltar_reparar(p)


# ------------------------------------------------------------------ Niveles
## Carga resistencias guardadas (formato de datos()) y deja TODO coherente: repinta las sogas 3D,
## avisa al HUD con soga_cambio, recalcula plataformas inestables y el peligro del sol.
func cargar(guardado: Dictionary) -> void:
	perdido = false
	reparacion_bloqueada = false
	for p: String in sogas.keys():
		progreso[p] = 0.0
		_indice_reparando[p] = -1
		desestab[p] = false
		var v: Array = guardado.get(p, [RES_MAX, RES_MAX])
		for i in 2:
			sogas[p][i] = clampf(float(v[i]), 0.0, RES_MAX)
			rotas[p][i] = sogas[p][i] <= 0.0      # una soga que terminó el día en 0 amanece rota
			tiempo_rotura[p][i] = -1.0
			soga_cambio.emit(p, i, sogas[p][i])
			if visuales.has(p + str(i)):
				_pintar(p, i)
		_revisar(p)


func reiniciar() -> void:
	cargar({})
	if sistema_sol:
		sistema_sol.reiniciar_luz()


# ------------------------------------------------------------------ Interno
func _desgastar(p: String, coord: float, cantidad: float) -> void:
	if perdido:
		return
	var i := _soga_a_desgastar(p, coord)
	if rotas[p][i]:
		i = 1 - i                    # la soga rota ya no trabaja: toda la carga la lleva la otra
		if rotas[p][i]:
			return
	_poner(p, i, sogas[p][i] - cantidad * multiplicador_desgaste)


func _soga_a_desgastar(p: String, coord: float) -> int:
	if is_nan(coord):
		return 0 if sogas[p][0] >= sogas[p][1] else 1
	var anclas: Array = SOGAS[p]["ancla"]
	return 0 if absf(coord - float(anclas[0])) <= absf(coord - float(anclas[1])) else 1


func _poner(p: String, i: int, valor: float) -> void:
	sogas[p][i] = clampf(valor, 0.0, RES_MAX)
	if sogas[p][i] > 0.0:
		tiempo_rotura[p][i] = -1.0
	elif not rotas[p][i] and tiempo_rotura[p][i] < 0.0:
		tiempo_rotura[p][i] = T_ROTURA       # desgaste al máximo: empieza la cuenta de 30 s
		soga_en_peligro.emit(p, i)
	soga_cambio.emit(p, i, sogas[p][i])
	_pintar(p, i)
	_revisar(p)


func _romper(p: String, i: int) -> void:
	tiempo_rotura[p][i] = -1.0
	rotas[p][i] = true
	soga_rota.emit(p, i)
	_pintar(p, i)
	_revisar(p)


func _revisar(p: String) -> void:
	var inestable: bool = rotas[p][0] or rotas[p][1]
	if inestable != desestab[p]:
		desestab[p] = inestable
		plataforma_desestabilizada.emit(p, inestable)
	if rotas[p][0] and rotas[p][1] and not perdido:
		perdido = true
		nivel_perdido.emit()
		if sistema_sol:
			sistema_sol.anunciar_derrota()
	elif sistema_sol and not perdido:
		sistema_sol.poner_peligro(resistencia_minima())


func _crear_visuales() -> void:
	# Las posiciones de SOGAS están en coordenadas del mundo: se pasan a locales de este nodo.
	var origen := global_position if is_inside_tree() else position
	for p: String in SOGAS.keys():
		var posiciones: Array = SOGAS[p]["pos"]
		var tam: Vector3 = SOGAS[p]["size"]
		for i in 2:
			var m := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = tam
			m.mesh = caja
			var mat := StandardMaterial3D.new()
			mat.emission_energy_multiplier = 0.9
			m.material_override = mat
			m.position = (posiciones[i] as Vector3) - origen
			add_child(m)
			visuales[p + str(i)] = m
			_pintar(p, i)
		# Barrita que se llena mientras se repara; se coloca sobre la soga que se está reparando.
		var barra := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.06, 0.12)
		barra.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color("#6FCF6F")
		barra.material_override = bmat
		barra.visible = false
		add_child(barra)
		barras_reparacion[p] = barra
	reparacion_progreso.connect(_mostrar_barra_reparacion)


func _mostrar_barra_reparacion(p: String, fraccion: float) -> void:
	var barra := barras_reparacion.get(p) as MeshInstance3D
	if barra == null:
		return
	var i: int = _indice_reparando[p]
	if i >= 0:
		barra.position = (visuales[p + str(i)] as MeshInstance3D).position + Vector3(0.0, 0.5, 0.0)
	barra.visible = fraccion > 0.0
	barra.scale.x = maxf(fraccion, 0.001) * 1.2


## Color de la soga según su desgaste: madera cuando está sana y cada vez más roja hasta llegar al máximo.
static func color_por_desgaste(resistencia: float) -> Color:
	var desgaste := 1.0 - clampf(resistencia / RES_MAX, 0.0, 1.0)
	return MADERA.lerp(ROJO, pow(desgaste, 1.3))


func _pintar(p: String, i: int) -> void:
	var r: float = sogas[p][i]
	var m: MeshInstance3D = visuales[p + str(i)]
	var mat := m.material_override as StandardMaterial3D
	m.visible = not rotas[p][i]            # la soga rota desaparece
	mat.albedo_color = color_por_desgaste(r)
	mat.emission_enabled = false


## Parpadeo de las sogas críticas: cada vez más rápido a medida que se acaba el tiempo.
func _parpadear(p: String, i: int) -> void:
	var m: MeshInstance3D = visuales[p + str(i)]
	var mat := m.material_override as StandardMaterial3D
	var restante: float = tiempo_rotura[p][i]
	var urgencia := 1.0 - clampf(restante / T_ROTURA, 0.0, 1.0)
	var frecuencia := lerpf(2.0, 8.0, urgencia)                 # parpadeos por segundo
	var encendida := fmod(Time.get_ticks_msec() / 1000.0 * frecuencia, 1.0) < 0.5
	mat.albedo_color = ROJO_VIVO if encendida else ROJO_OSCURO
	mat.emission_enabled = encendida
	mat.emission = ROJO_VIVO


func _process(delta: float) -> void:
	if not perdido:
		for p: String in tiempo_rotura.keys():
			for i in 2:
				if tiempo_rotura[p][i] < 0.0:
					continue
				tiempo_rotura[p][i] -= delta
				if tiempo_rotura[p][i] <= 0.0:
					_romper(p, i)
				else:
					_parpadear(p, i)
	if not modo_prueba:
		return
	if Input.is_key_pressed(KEY_R):
		mantener_reparacion(plataforma_cercana if plataforma_cercana != "" else plataforma_mas_danada(), delta)
	else:
		soltar_reparacion()


# ------------------------------------------------------------------ Teclas de prueba (solo con modo_prueba)
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not modo_prueba or k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1: registrar_lanzamiento("izquierda", -1.0)
		KEY_2: registrar_lanzamiento("derecha", 7.5)
		KEY_3: _poner("lavadora", 0, 25.0)
		KEY_4: _poner("lavadora", 0, 0.0)
		KEY_5: _poner("lavadora", 1, 0.0)
		KEY_9: registrar_pedido(-0.4)
		KEY_U: _poner("despacho", 0, 0.0)
		KEY_I: _poner("despacho", 1, 0.0)
		KEY_H: print("sogas: ", sogas, " | perdido: ", perdido, " | bloqueada: ", reparacion_bloqueada)
		KEY_0: reiniciar()
