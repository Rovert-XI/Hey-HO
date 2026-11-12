class_name Loro
extends Node3D
## Loro ladrón con animación completa:
##   aviso (sombra + graznido) -> entra volando desde fuera de la pantalla -> aterriza en el gancho
##   -> picotea y se lleva la prenda -> se va volando con ella.
## Si lo espantan con una piedra (o se retira la prenda) se va sin la prenda.
##
## Tiempos del concepto (contados desde que se tiende la prenda):
##   11 s aviso · 20 s el loro LLEGA al gancho · 23 s se lleva la prenda.
## El vuelo de entrada ocupa los 1,6 s anteriores a la llegada (empieza a los 18,4 s).

signal aviso_graznido(gancho: int)
signal loro_se_acerca(gancho: int)   # entra a la pantalla (por si quieren sonido de alas)
signal loro_llego(gancho: int)       # aterriza en el gancho (20 s)
signal prenda_robada(gancho: int)    # agarra la prenda (23 s)
signal loro_huyo(gancho: int)        # lo espantaron con una piedra

enum Estado { INACTIVO, ACERCANDO, POSADO, ROBANDO, HUYENDO }

const T_AVISO := 11.0
const T_LLEGADA := 20.0
const T_ROBO := 3.0
const T_VUELO := 1.6        # duración del vuelo de entrada
const T_PICOTAZO := 0.25    # el picotazo termina justo a los 3 s
const T_SALIDA := 1.2
const T_SOMBRA := 3.0
const ROJO := Color("#D63A3A")
const ROJO_ALA := Color("#A52F2F")
const CREMA := Color("#F6E7B0")

@export var posiciones_gancho: Array[Vector3] = [
	Vector3(5, 0.9, 2.9), Vector3(6, 0.9, 2.9), Vector3(7, 0.9, 2.9)]
## Punto fuera de la pantalla por donde entra el loro (con cámara ortogonal Size 9 en 16:9 se ve hasta x ≈ 10,5).
@export var origen_vuelo := Vector3(15.0, 3.5, 3.5)
@export var modo_prueba := true

var estado := Estado.INACTIVO
var edad := {}
var avisado := {}
var a_salvo := {}
var en_gancho := -1
var t_en_gancho := 0.0

var ave: Node3D
var ala_izq: Node3D
var ala_der: Node3D
var cabeza: Node3D
var prenda: MeshInstance3D
var marca_aviso: MeshInstance3D
var sombra_vuelo: MeshInstance3D
var _mat_sombra: StandardMaterial3D

var _tween: Tween
var _id_marca := 0
var _t := 0.0
var _y_posado := 0.0
var _aleteo_amp := 0.0
var _aleteo_freq := 20.0
var _pliegue := 1.0         # 1 = alas plegadas (posado), 0 = abiertas (volando)


func _ready() -> void:
	_crear_visual()
	if modo_prueba:
		aviso_graznido.connect(func(g): print("graznido: gancho ", g))
		loro_se_acerca.connect(func(g): print("el loro entra volando hacia el gancho ", g))
		loro_llego.connect(func(g): print("el loro aterrizó en el gancho ", g))
		prenda_robada.connect(func(g): print("prenda robada del gancho ", g))
		loro_huyo.connect(func(g): print("loro espantado en el gancho ", g))


# ------------------------------------------------------------------ API para el resto del juego
func prenda_tendida(gancho: int) -> void:
	edad[gancho] = 0.0
	avisado[gancho] = false
	a_salvo[gancho] = false


func prenda_retirada(gancho: int) -> void:
	edad.erase(gancho)
	if en_gancho == gancho and (estado == Estado.ACERCANDO or estado == Estado.POSADO):
		_huir(false, false)   # la prenda ya no está: se va tranquilo, sin llevarse nada


func piedra_acerto() -> void:
	if estado != Estado.ACERCANDO and estado != Estado.POSADO:
		return
	var g := en_gancho
	a_salvo[g] = true
	loro_huyo.emit(g)
	_huir(false, true)        # espantado: sale rápido


func reiniciar() -> void:
	if _tween:
		_tween.kill()
	edad.clear()
	avisado.clear()
	a_salvo.clear()
	en_gancho = -1
	estado = Estado.INACTIVO
	ave.visible = false
	prenda.visible = false
	sombra_vuelo.visible = false
	marca_aviso.visible = false


# ------------------------------------------------------------------ Lógica por fotograma
func _process(delta: float) -> void:
	_t += delta
	_animar_alas()
	for g: int in edad.keys():
		edad[g] += delta
		if not avisado[g] and edad[g] >= T_AVISO:
			avisado[g] = true
			_mostrar_marca(g)
			aviso_graznido.emit(g)
		if estado == Estado.INACTIVO and not a_salvo[g] and edad[g] >= T_LLEGADA - T_VUELO:
			_acercar(g)
	if estado == Estado.POSADO:
		t_en_gancho += delta
		ave.position.y = _y_posado + sin(_t * 3.0) * 0.015     # respira
		if t_en_gancho >= T_ROBO - T_PICOTAZO:
			_picotear()


# ------------------------------------------------------------------ Secuencia de animación
func _acercar(g: int) -> void:
	estado = Estado.ACERCANDO
	en_gancho = g
	t_en_gancho = 0.0
	var destino := posiciones_gancho[g]
	var ctrl := Vector3(destino.x + (origen_vuelo.x - destino.x) * 0.35, origen_vuelo.y + 0.5,
		destino.z + (origen_vuelo.z - destino.z) * 0.35)
	_mirar(destino.x - origen_vuelo.x)
	ave.visible = true
	ave.position = origen_vuelo
	cabeza.rotation.z = 0.0
	prenda.visible = false
	sombra_vuelo.visible = true
	_aleteo_amp = 0.9
	_aleteo_freq = 24.0
	_pliegue = 0.0
	loro_se_acerca.emit(g)
	_matar_tween()
	_tween = create_tween()
	_tween.tween_method(_volar.bind(origen_vuelo, ctrl, destino), 0.0, 1.0, T_VUELO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_posar.bind(g))


func _posar(g: int) -> void:
	estado = Estado.POSADO
	t_en_gancho = 0.0
	_y_posado = ave.position.y
	_matar_tween()
	_tween = create_tween().set_parallel()
	_tween.tween_property(ave, "rotation:z", 0.0, 0.2)
	_tween.tween_property(self, "_aleteo_amp", 0.1, 0.4)
	_tween.tween_property(self, "_aleteo_freq", 3.0, 0.4)
	_tween.tween_property(self, "_pliegue", 1.0, 0.35)
	loro_llego.emit(g)


func _picotear() -> void:
	estado = Estado.ROBANDO
	_matar_tween()
	_tween = create_tween()
	_tween.tween_property(cabeza, "rotation:z", -0.7, T_PICOTAZO).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_agarrar)


func _agarrar() -> void:
	var g := en_gancho
	edad.erase(g)
	prenda.visible = true             # ahora la lleva en las garras
	prenda_robada.emit(g)             # el juego quita la prenda del gancho en este instante
	_huir(true, false)


func _huir(con_prenda: bool, asustado: bool) -> void:
	_matar_tween()
	estado = Estado.HUYENDO
	en_gancho = -1
	prenda.visible = con_prenda
	var desde := ave.position
	var dir := signf(origen_vuelo.x - desde.x)
	if dir == 0.0:
		dir = 1.0
	var destino := Vector3(desde.x + dir * 12.0, desde.y + 4.5, desde.z + 1.5)
	var ctrl := Vector3(desde.x + dir * 1.5, desde.y + 2.8, desde.z)   # despega casi vertical
	_mirar(dir)
	cabeza.rotation.z = 0.0
	_aleteo_amp = 1.0
	_aleteo_freq = 28.0 if asustado else 22.0
	_pliegue = 0.0
	_tween = create_tween()
	_tween.tween_method(_volar.bind(desde, ctrl, destino), 0.0, 1.0, 0.9 if asustado else T_SALIDA) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_terminar_salida)


func _terminar_salida() -> void:
	ave.visible = false
	prenda.visible = false
	sombra_vuelo.visible = false
	estado = Estado.INACTIVO


# ------------------------------------------------------------------ Movimiento y detalles visuales
## Curva de Bézier cuadrática: el vuelo describe un arco, no una línea recta.
func _volar(u: float, a: Vector3, c: Vector3, b: Vector3) -> void:
	ave.position = a.lerp(c, u).lerp(c.lerp(b, u), u)
	var vel := (c - a) * (1.0 - u) + (b - c) * u
	ave.rotation.z = clampf(atan2(vel.y, absf(vel.x) + 0.001), -0.7, 0.7)   # morro arriba o abajo
	_actualizar_sombra()


func _mirar(dx: float) -> void:
	ave.rotation.y = 0.0 if dx >= 0.0 else PI


func _animar_alas() -> void:
	if not ave.visible:
		return
	var a := sin(_t * _aleteo_freq) * _aleteo_amp
	var base := _pliegue * 1.1            # plegadas: las puntas hacia abajo
	ala_izq.rotation.x = base - a
	ala_der.rotation.x = -base + a
	_actualizar_sombra()


func _actualizar_sombra() -> void:
	var h := ave.position.y
	sombra_vuelo.position = Vector3(ave.position.x, 0.03, ave.position.z)
	var esc := clampf(1.3 - h * 0.15, 0.4, 1.3)
	sombra_vuelo.scale = Vector3(esc, 1.0, esc)
	_mat_sombra.albedo_color.a = clampf(0.55 - h * 0.08, 0.1, 0.55)


func _mostrar_marca(g: int) -> void:
	var pos := posiciones_gancho[g]
	marca_aviso.position = Vector3(pos.x, 0.02, pos.z)
	marca_aviso.visible = true
	_id_marca += 1
	get_tree().create_timer(T_SOMBRA).timeout.connect(_ocultar_marca.bind(_id_marca))


func _ocultar_marca(id: int) -> void:
	if id == _id_marca:
		marca_aviso.visible = false


func _matar_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# ------------------------------------------------------------------ Modelo provisional (formas simples)
func _parte(padre: Node3D, nombre: String, malla: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nombre
	m.mesh = malla
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	padre.add_child(m)
	return m


func _caja(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


func _esfera(radio: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radio
	s.height = radio * 2.0
	return s


func _crear_visual() -> void:
	ave = Node3D.new()
	ave.name = "Ave"
	ave.visible = false
	add_child(ave)
	var torso := _parte(ave, "Torso", _esfera(0.24), ROJO, Vector3.ZERO)
	torso.scale = Vector3(1.25, 1.0, 0.9)
	_parte(ave, "Cola", _caja(Vector3(0.3, 0.05, 0.12)), ROJO_ALA, Vector3(-0.34, -0.04, 0.0))
	cabeza = Node3D.new()
	cabeza.name = "Cabeza"
	cabeza.position = Vector3(0.22, 0.17, 0.0)
	ave.add_child(cabeza)
	_parte(cabeza, "Craneo", _esfera(0.14), ROJO, Vector3.ZERO)
	_parte(cabeza, "Pico", _caja(Vector3(0.14, 0.07, 0.06)), CREMA, Vector3(0.15, -0.02, 0.0))
	ala_izq = Node3D.new()
	ala_izq.name = "AlaIzq"
	ala_izq.position = Vector3(0.0, 0.08, 0.14)
	ave.add_child(ala_izq)
	_parte(ala_izq, "Pluma", _caja(Vector3(0.36, 0.025, 0.3)), ROJO_ALA, Vector3(0.0, 0.0, 0.15))
	ala_der = Node3D.new()
	ala_der.name = "AlaDer"
	ala_der.position = Vector3(0.0, 0.08, -0.14)
	ave.add_child(ala_der)
	_parte(ala_der, "Pluma", _caja(Vector3(0.36, 0.025, 0.3)), ROJO_ALA, Vector3(0.0, 0.0, -0.15))
	prenda = _parte(ave, "Prenda", _caja(Vector3(0.2, 0.04, 0.2)), CREMA, Vector3(0.0, -0.3, 0.0))
	prenda.visible = false

	marca_aviso = _disco("MarcaAviso", 0.5, 0.6)
	_mat_sombra = (_disco("SombraVuelo", 0.3, 0.5)).material_override
	sombra_vuelo = get_node("SombraVuelo")


func _disco(nombre: String, radio: float, alfa: float) -> MeshInstance3D:
	var d := CylinderMesh.new()
	d.top_radius = radio
	d.bottom_radius = radio
	d.height = 0.02
	var m := MeshInstance3D.new()
	m.name = nombre
	m.mesh = d
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, alfa)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.visible = false
	add_child(m)
	return m


# ------------------------------------------------------------------ Teclas de prueba
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not modo_prueba or k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_6: prenda_tendida(0)
		KEY_7: prenda_retirada(0)
		KEY_8: piedra_acerto()
		KEY_K:   # adelanta el reloj para ver la entrada del loro sin esperar 18 s
			if edad.has(0):
				edad[0] = maxf(edad[0], T_LLEGADA - T_VUELO - 0.05)
		KEY_J: print("estado: ", Estado.keys()[estado], " | prendas: ", edad, " | gancho: ", en_gancho, " | t posado: ", snappedf(t_en_gancho, 0.1))
		KEY_0: reiniciar()
