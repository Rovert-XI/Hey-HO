class_name EstacionesRopa
extends Node3D
## LAVADORA (izquierda) y TENDEDERO (derecha) del nivel.
##
## El recorrido de una prenda:
##   sucia --lanzar a la izquierda--> lavadora (6 s) --jalar con E 1 s--> lavada (vuelve a la munición)
##   lavada --lanzar a la derecha--> tendedero (15 s) --jalar con E 1 s si ya está seca--> seca --> despacho
##
## El ESTADO de cada prenda (sucia/lavada/seca) lo trae la cola de munición de Isabella
## (PrendaProyectil.EstadoPrenda); el controlador se lo pasa a recibir_en_lavadora / recibir_en_tendedero.
##
## Si la estación está llena (o la prenda va al sitio equivocado) cae al agua: hay 8 s para
## rescatarla con F mantenida 2 s; si no, se pierde.
##
## Esta clase NO lee teclas ni sabe dónde está el jugador: el NivelControlador la maneja con los
## métodos públicos (recibir_*, jalar, rescatar, entregar). Por eso se puede probar sin abrir el juego.

# ---------------------------------------------------------------- Señales (otros scripts se enganchan a ellas)
signal prenda_lavando(slot: int)           # entró una prenda a la lavadora
signal prenda_lavada(slot: int)            # terminó el lavado (destello verde)
signal prenda_tendida(gancho: int)         # entró al tendedero (aquí arranca el reloj del loro)
signal prenda_seca(gancho: int)            # ya se puede sacar del tendedero
signal prenda_retirada(gancho: int)        # el jugador la sacó del tendedero (o se la robaron)
signal prenda_al_agua(estado: int)         # cayó al agua (estado: 0 sucia, 1 lavada, 2 seca)
signal prenda_rescatada(estado: int)
signal prenda_perdida(estado: int)         # pasaron los 8 s sin rescatarla
signal mano_cambio(secas: int)             # cambió cuántas prendas secas lleva el pirata para el despacho

# ---------------------------------------------------------------- Números del juego (del documento de concepto)
const CAPACIDAD_LAVADORA := 2
const GANCHOS := 3
const T_LAVADO := 6.0                      # segundos que lava la lavadora
const T_SECADO := 15.0                     # segundos que tarda en secarse en el tendedero
const T_RESCATE := 8.0                     # segundos que dura el anillo en el agua
const HOLD_JALAR := 1.0                    # E mantenida para recoger una prenda
const HOLD_RESCATE := 2.0                  # F mantenida para rescatar del agua

# Colores: sucia = marrón, mojada = oscura, seca = crema, lista = verde.
const COLOR_SUCIA := Color("8B5A2B")
const COLOR_MOJADA := Color(0.18, 0.2, 0.3)
const COLOR_SECA := Color("F2E6C8")
const COLOR_LISTO := Color("6FCF6F")

# Estados de la prenda: son los mismos números del enum PrendaProyectil.EstadoPrenda de Isabella.
const SUCIA := 0
const LAVADA := 1
const SECA := 2

# ---------------------------------------------------------------- Dónde se dibujan (se pueden mover en el Inspector)
# Las lavadoras del mapa de Isabella están en x = 2.06 y x = 3.98 (z = -2.9); los ganchos en x = 5, 6, 7 (z = 2.9).
@export var pos_lavadora: Array[Vector3] = [Vector3(2.06, 0.75, -2.9), Vector3(3.98, 0.75, -2.9)]
@export var pos_ganchos: Array[Vector3] = [Vector3(5, 0.35, 2.9), Vector3(6, 0.35, 2.9), Vector3(7, 0.35, 2.9)]
@export var pos_agua_lavadora := Vector3(3.0, -0.9, -1.9)
@export var pos_agua_tendedero := Vector3(6.0, -0.9, 3.9)
## Para demos: 2.0 = lavar y secar al doble de rápido (no cambia los tiempos de rescate ni de jalar).
@export var velocidad_proceso := 1.0

# ---------------------------------------------------------------- Estado
## Prendas secas que lleva el pirata hacia el despacho (las sucias y lavadas viajan en la cola de munición).
var secas := 0

var lavadora: Array = [null, null]           # cada espacio: null (libre) o {t, listo, nodo, barra}
var tendedero: Array = [null, null, null]    # cada gancho: null (libre) o {t, seca, nodo, barra}
var charcos: Array = []                      # prendas en el agua: {t, estado, nodo}

var progreso_jalar := 0.0                    # cuánto lleva la E mantenida (0 a HOLD_JALAR)
var progreso_rescate := 0.0                  # cuánto lleva la F mantenida (0 a HOLD_RESCATE)
var _jalar_hecho := false                    # evita recoger otra prenda sin soltar la tecla
var _rescate_hecho := false


func _process(delta: float) -> void:
	avanzar(delta)


# ---------------------------------------------------------------- Relojes
## Avanza los relojes: el lavado, el secado y el tiempo del agua. Los tests lo llaman a mano.
func avanzar(delta: float) -> void:
	var dp := delta * velocidad_proceso
	# Lavadora: cada prenda suma tiempo; al llegar a 6 s queda lista (verde y un poco más grande).
	for i in CAPACIDAD_LAVADORA:
		var s = lavadora[i]
		if s == null or s.listo:
			continue
		s.t += dp
		_barra(s, s.t / T_LAVADO)
		if s.t >= T_LAVADO:
			s.listo = true
			s.nodo.scale = Vector3.ONE * 1.25
			_pintar(s.nodo, COLOR_LISTO)
			_quitar_barra(s)
			prenda_lavada.emit(i)
	# Tendedero: igual, pero a los 15 s la prenda pasa de oscura (mojada) a crema (seca).
	for g in GANCHOS:
		var s = tendedero[g]
		if s == null or s.seca:
			continue
		s.t += dp
		_barra(s, s.t / T_SECADO)
		if s.t >= T_SECADO:
			s.seca = true
			_pintar(s.nodo, COLOR_SECA)
			_quitar_barra(s)
			prenda_seca.emit(g)
	# Agua: el anillo se va encogiendo; a los 8 s la prenda se pierde.
	for c in charcos.duplicate():
		c.t += delta
		var u: float = 1.0 - c.t / T_RESCATE
		if is_instance_valid(c.nodo):
			c.nodo.scale = Vector3(1, 1, 1) * maxf(0.2, u + 0.2)
		if c.t >= T_RESCATE:
			_quitar_charco(c)
			prenda_perdida.emit(c.estado)


# ---------------------------------------------------------------- Reparto de prendas
## Tiro a la IZQUIERDA con una prenda en `estado`. Devuelve true si la lavadora la aceptó.
## Solo se lava lo que no está seco; si la lavadora está llena (o la prenda ya está seca) cae al agua.
func recibir_en_lavadora(estado: int = SUCIA) -> bool:
	var libre := lavadora.find(null)          # primer espacio libre, o -1 si está llena
	if libre == -1 or estado == SECA:
		_al_agua(estado, pos_agua_lavadora)
		return false
	lavadora[libre] = _nueva(libre, pos_lavadora, COLOR_SUCIA)
	prenda_lavando.emit(libre)
	return true


## Tiro a la DERECHA con una prenda en `estado`. Solo se tienden prendas LAVADAS:
## una sucia, una ya seca, o con el tendedero lleno, cae al agua.
func recibir_en_tendedero(estado: int = LAVADA) -> bool:
	var libre := tendedero.find(null)
	if estado != LAVADA or libre == -1:
		_al_agua(estado, pos_agua_tendedero)
		return false
	tendedero[libre] = _nueva(libre, pos_ganchos, COLOR_MOJADA)
	prenda_tendida.emit(libre)                # el NivelControlador avisa al loro con esto
	return true


# ---------------------------------------------------------------- Recoger prendas (E mantenida)
## ¿Hay alguna prenda lista para recoger en esa estación? ("lavadora" o "tendedero")
func hay_para_jalar(sitio: String) -> bool:
	var lista := lavadora if sitio == "lavadora" else tendedero
	for s in lista:
		if s != null and (s.listo if sitio == "lavadora" else s.seca):
			return true
	return false


## Se llama cada fotograma con E mantenida junto a la estación. Devuelve true cuando recoge una prenda.
func jalar(sitio: String, delta: float) -> bool:
	if _jalar_hecho or not hay_para_jalar(sitio):
		progreso_jalar = 0.0
		return false
	progreso_jalar += delta
	if progreso_jalar < HOLD_JALAR:
		return false                         # todavía no completa 1 s
	progreso_jalar = 0.0
	_jalar_hecho = true                      # hasta soltar la tecla, no recoge otra
	if sitio == "lavadora":
		for i in CAPACIDAD_LAVADORA:
			if lavadora[i] != null and lavadora[i].listo:
				_liberar(lavadora, i)
				break                         # el controlador agrega la prenda LAVADA a la munición
	else:
		for g in GANCHOS:
			if tendedero[g] != null and tendedero[g].seca:
				_liberar(tendedero, g)
				secas += 1
				prenda_retirada.emit(g)       # avisa al loro: ya no hay prenda en ese gancho
				break
	_avisar_mano()
	return true


## Al soltar la E se reinicia el progreso y se permite recoger otra.
func soltar_jalar() -> void:
	progreso_jalar = 0.0
	_jalar_hecho = false


# ---------------------------------------------------------------- Rescate del agua (F mantenida)
## Se llama cada fotograma con F mantenida junto al agua. Devuelve true cuando rescata una prenda.
func rescatar(delta: float) -> bool:
	if _rescate_hecho or charcos.is_empty():
		progreso_rescate = 0.0
		return false
	progreso_rescate += delta
	if progreso_rescate < HOLD_RESCATE:
		return false
	progreso_rescate = 0.0
	_rescate_hecho = true
	var c = charcos[0]                       # la que lleva más tiempo (la que se pierde primero)
	_quitar_charco(c)
	prenda_rescatada.emit(c.estado)         # el controlador la devuelve a la munición con su estado
	return true


func soltar_rescate() -> void:
	progreso_rescate = 0.0
	_rescate_hecho = false


# ---------------------------------------------------------------- Loro y entrega
## El loro se llevó la prenda de ese gancho: desaparece del tendedero.
func robar(gancho: int) -> bool:
	if gancho < 0 or gancho >= GANCHOS or tendedero[gancho] == null:
		return false
	_liberar(tendedero, gancho)
	prenda_retirada.emit(gancho)
	return true


## Entrega en el despacho. Devuelve cuántas prendas secas se llevó (máximo `maximo`).
func entregar(maximo: int) -> int:
	var n := mini(secas, maximo)
	secas -= n
	_avisar_mano()
	return n


## Deja todo vacío (para empezar un nivel limpio).
func reiniciar() -> void:
	for i in CAPACIDAD_LAVADORA:
		if lavadora[i] != null:
			_liberar(lavadora, i)
	for g in GANCHOS:
		if tendedero[g] != null:
			_liberar(tendedero, g)
	for c in charcos.duplicate():
		_quitar_charco(c)
	secas = 0
	soltar_jalar()
	soltar_rescate()
	_avisar_mano()


## Cuántas prendas hay ahora en cada estación.
func en_lavadora() -> int:
	return CAPACIDAD_LAVADORA - lavadora.count(null)


func en_tendedero() -> int:
	return GANCHOS - tendedero.count(null)


# ---------------------------------------------------------------- Interno: dibujo y limpieza
func _avisar_mano() -> void:
	mano_cambio.emit(secas)


## Crea la prenda (una caja plana de color) en su espacio y devuelve sus datos.
func _nueva(i: int, posiciones: Array[Vector3], color: Color) -> Dictionary:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.5, 0.45, 0.08)
	m.mesh = caja
	m.position = posiciones[i]
	add_child(m)
	_pintar(m, color)
	return {"t": 0.0, "listo": false, "seca": false, "nodo": m, "barra": null}


## Quita la prenda de su espacio (y su barra) y deja el espacio libre.
func _liberar(lista: Array, i: int) -> void:
	var s = lista[i]
	if s == null:
		return
	_quitar_barra(s)
	if is_instance_valid(s.nodo):
		s.nodo.queue_free()
	lista[i] = null


## Pone una prenda en el agua: dibuja un anillo amarillo que se encoge durante 8 s.
func _al_agua(estado: int, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 0.6
	d.bottom_radius = 0.6
	d.height = 0.03
	m.mesh = d
	m.position = pos
	add_child(m)
	_pintar(m, Color(1.0, 0.85, 0.2, 0.7))
	charcos.append({"t": 0.0, "estado": estado, "nodo": m})
	prenda_al_agua.emit(estado)


func _quitar_charco(c: Dictionary) -> void:
	if is_instance_valid(c.nodo):
		c.nodo.queue_free()
	charcos.erase(c)


## Barra de progreso amarilla sobre la prenda (lavado o secado); `u` va de 0 a 1.
func _barra(s: Dictionary, u: float) -> void:
	if s.barra == null:
		var b := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.5, 0.06, 0.06)
		b.mesh = caja
		s.nodo.add_child(b)
		b.position = Vector3(0, 0.4, 0)
		_pintar(b, Color("F2C94C"))
		s.barra = b
	s.barra.scale.x = clampf(u, 0.02, 1.0)


func _quitar_barra(s: Dictionary) -> void:
	if s.barra != null and is_instance_valid(s.barra):
		s.barra.queue_free()
	s.barra = null


## Le pone color a una malla (con transparencia si el color la trae).
func _pintar(m: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
