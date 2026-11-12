class_name SistemaSogas
extends Node3D

signal soga_cambio(plataforma: String, indice: int, resistencia: float)
signal plataforma_desestabilizada(plataforma: String, desestabilizada: bool)
signal reparacion_progreso(plataforma: String, fraccion: float)
signal reparacion_cobrada(costo: int)
signal nivel_perdido

const RES_MAX := 100.0
const UMBRAL_PELIGRO := 30.0
const T_REPARAR := 2.0
const RES_REPARADA := 50.0
const COSTO_REPARACION := 20
const MADERA := Color("#8B5A2B")
const ROJO := Color("#D63A3A")

# Por plataforma: dónde está cada soga, su tamaño y el valor (x o z) con el que se elige cuál se desgasta
const SOGAS := {
	"lavadora": {"pos": [Vector3(0.0, 0.05, -1.375), Vector3(3.0, 0.05, -1.375)], "size": Vector3(0.12, 0.08, 1.25), "ancla": [0.0, 3.0]},
	"tendedero": {"pos": [Vector3(3.5, 0.05, 1.375), Vector3(6.0, 0.05, 1.375)], "size": Vector3(0.12, 0.08, 1.25), "ancla": [3.5, 6.0]},
	"despacho": {"pos": [Vector3(-0.6, 0.05, -0.4), Vector3(-0.6, 0.05, 0.4)], "size": Vector3(1.2, 0.08, 0.12), "ancla": [-0.4, 0.4]},
}

@export var sistema_sol: SistemaSol
@export var desgaste_por_lanzamiento := 2.0
@export var desgaste_por_pedido := 4.0
@export var modo_prueba := true

var sogas := {
	"lavadora": [RES_MAX, RES_MAX],
	"tendedero": [RES_MAX, RES_MAX],
	"despacho": [RES_MAX, RES_MAX],
}
var progreso := {"lavadora": 0.0, "tendedero": 0.0, "despacho": 0.0}
var desestab := {"lavadora": false, "tendedero": false, "despacho": false}
var visuales := {}
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

func registrar_lanzamiento(lado: String, x := NAN) -> void:
	var p := "lavadora" if lado == "izquierda" else "tendedero"
	_desgastar(p, x, desgaste_por_lanzamiento)

func registrar_pedido(z := NAN) -> void:
	_desgastar("despacho", z, desgaste_por_pedido)

func reparar(p: String, delta: float) -> bool:
	if perdido:
		return false
	var i := 0 if sogas[p][0] <= sogas[p][1] else 1
	var actual: float = sogas[p][i]
	if actual >= RES_MAX:
		return false
	progreso[p] += delta
	reparacion_progreso.emit(p, clampf(progreso[p] / T_REPARAR, 0.0, 1.0))
	if progreso[p] >= T_REPARAR:
		progreso[p] = 0.0
		var estaba_rota := actual <= 0.0
		_poner(p, i, RES_REPARADA if estaba_rota else actual + RES_REPARADA)
		if estaba_rota:
			reparacion_cobrada.emit(COSTO_REPARACION)
		return true
	return false

func soltar_reparar(p: String) -> void:
	if progreso[p] > 0.0:
		progreso[p] = 0.0
		reparacion_progreso.emit(p, 0.0)

func reiniciar() -> void:
	perdido = false
	reparacion_bloqueada = false
	for p: String in sogas.keys():
		sogas[p] = [RES_MAX, RES_MAX]
		progreso[p] = 0.0
		desestab[p] = false
		for i in 2:
			_pintar(p, i)
	if sistema_sol:
		sistema_sol.reiniciar_luz()

func _desgastar(p: String, coord: float, cantidad: float) -> void:
	if perdido:
		return
	var i := _soga_a_desgastar(p, coord)
	_poner(p, i, sogas[p][i] - cantidad)

func _soga_a_desgastar(p: String, coord: float) -> int:
	if is_nan(coord):
		return 0 if sogas[p][0] >= sogas[p][1] else 1
	var anclas: Array = SOGAS[p]["ancla"]
	return 0 if absf(coord - float(anclas[0])) <= absf(coord - float(anclas[1])) else 1

func _poner(p: String, i: int, valor: float) -> void:
	sogas[p][i] = clampf(valor, 0.0, RES_MAX)
	soga_cambio.emit(p, i, sogas[p][i])
	_pintar(p, i)
	_revisar(p)

func _revisar(p: String) -> void:
	var inestable: bool = sogas[p][0] <= 0.0 or sogas[p][1] <= 0.0
	if inestable != desestab[p]:
		desestab[p] = inestable
		plataforma_desestabilizada.emit(p, inestable)
	if sogas[p][0] <= 0.0 and sogas[p][1] <= 0.0 and not perdido:
		perdido = true
		nivel_perdido.emit()
		if sistema_sol:
			sistema_sol.anunciar_derrota()
	elif sistema_sol and not perdido:
		sistema_sol.poner_peligro(resistencia_minima())

func _crear_visuales() -> void:
	for p: String in SOGAS.keys():
		var posiciones: Array = SOGAS[p]["pos"]
		var tam: Vector3 = SOGAS[p]["size"]
		for i in 2:
			var m := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = tam
			m.mesh = caja
			m.material_override = StandardMaterial3D.new()
			m.position = posiciones[i]
			add_child(m)
			visuales[p + str(i)] = m
			_pintar(p, i)

func _pintar(p: String, i: int) -> void:
	var r: float = sogas[p][i]
	var m: MeshInstance3D = visuales[p + str(i)]
	m.visible = r > 0.0
	(m.material_override as StandardMaterial3D).albedo_color = MADERA.lerp(ROJO, SistemaSol.peligro_soga(r))

func _mas_danada() -> String:
	var peor := "lavadora"
	var menor := RES_MAX + 1.0
	for p: String in sogas.keys():
		for r: float in sogas[p]:
			if r < menor:
				menor = r
				peor = p
	return peor

func _process(delta: float) -> void:
	if not modo_prueba:
		return
	if Input.is_key_pressed(KEY_R):
		if not reparacion_bloqueada:
			var objetivo := plataforma_cercana if plataforma_cercana != "" else _mas_danada()
			if reparar(objetivo, delta):
				reparacion_bloqueada = true
	else:
		reparacion_bloqueada = false
		for p: String in sogas.keys():
			soltar_reparar(p)

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
