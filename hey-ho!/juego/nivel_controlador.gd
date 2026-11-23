class_name NivelControlador
extends Node
## CONTROLADOR DEL NIVEL: el "director" que junta todas las piezas de un nivel real.
##   - Lleva el tiempo, los pedidos (clientes) y el oro del día.
##   - Usa el sol, las sogas y el loro del mapa, y conecta el HUD de Kevin a ellos.
##   - Crea la lavadora y el tendedero (EstacionesRopa) y los conecta con el loro, el HUD y la entrega.
##   - Dibuja las ZONAS del piso: el pirata tiene que caminar hasta cada una para usarla.
##   - Al terminar (se acaba el tiempo, pasan todos los clientes o se suelta una base) guarda el
##     resultado y va a la pantalla de Resultado.
##
## CONTROLES REALES (no hay teclas de prueba):
##   A / D ........ caminar (script del pirata)          P ... tomar prenda del canasto (Isabella)
##   1 / 2 / 3 .... equipar items (Isabella)              clic . apuntar y soltar la resortera
##   C ............ dejar la prenda en la lavadora o el tendedero (hay que estar en su zona)
##   E (mantener) . sacar de la lavadora / tendedero (1 s) o entregar el pedido en el despacho
##   F (mantener) . la CAÑA: rescata una prenda del agua (2 s, cerca de la lavadora o del tendedero)
##   R (mantener) . reparar la soga de la zona donde estás parado
##
## Lo que viene de otros compañeros entra por los métodos PÚBLICOS de la sección "API pública":
##   lanzar(lado, x, estado) <- la resortera de Isabella (se llama sola desde _contar_tiro)
##   piedra_acerto()         <- la piedra de Isabella, cuando le pegue al loro

# ---------------------------------------------------------------- Ajustes (se cambian en el Inspector)
## Segundos que espera cada cliente antes de irse sin pagar.
@export var paciencia := 60.0
@export var prendas_por_pedido := 2
## Mitad del ancho (en x) de cada zona: qué tan cerca debe estar la mano del pirata para usar la estación.
@export var alcance_x := 1.2

# ---------------------------------------------------------------- Constantes del mapa (posiciones en x)
## Separa la lavadora (izquierda) del tendedero (derecha): el centro entre las anclas de sus sogas.
const LIMITE_LADOS := 3.25
# Posiciones (en x) en el mapa de Isabella: lavadoras en x 2.06 y 3.98, ganchos en x 5 a 7, despacho en x -0.8.
const X_LAVADORA := 3.0
const X_TENDEDERO := 6.0
const X_DESPACHO := -0.8
const X_AGUA_LAVADORA := 3.0
const X_AGUA_TENDEDERO := 6.0
const ORO_UNA_PRENDA := 10                 # pago si solo entrega 1 de las 2 prendas

## Zonas del piso: nombre -> centro en x, color del marcador y rótulo (con la ayuda que sale al entrar).
const ZONAS := {"lavadora": X_LAVADORA, "tendedero": X_TENDEDERO, "despacho": X_DESPACHO}
const COLOR_ZONA := {
	"lavadora": Color(0.35, 0.7, 1.0), "tendedero": Color(0.5, 0.9, 0.5), "despacho": Color(1.0, 0.8, 0.3)}
const TITULO_ZONA := {"lavadora": "LAVADORA", "tendedero": "TENDEDERO", "despacho": "DESPACHO"}
const AYUDA_ZONA := {
	"lavadora": "C: dejar prenda sucia\nE: sacar lavada",
	"tendedero": "C: dejar prenda lavada\nE: sacar seca",
	"despacho": "E: entregar pedido"}

# ---------------------------------------------------------------- Piezas del nivel
@onready var hud: HudHeyHo = %Hud                                  # el HUD de Kevin
@onready var sistema_sol: SistemaSol = $Mapa/SistemaSol
@onready var sogas: SistemaSogas = $Mapa/SistemaSogas
@onready var loro: Loro = $Mapa/Loro
## Piezas de la resortera de Isabella (si el mapa las trae). Si no existen, quedan en null.
@onready var _equipo: Node = get_node_or_null("Mapa/EquipmentManager")
@onready var _municion: Node = get_node_or_null("Mapa/MunicionManager")
@onready var _punto_mano: Node3D = get_node_or_null("Mapa/PlayerPirata/CharacterBody3D/PuntoMano")

# ---------------------------------------------------------------- Estado del nivel
var estaciones: EstacionesRopa
var _n := 1                       # número de nivel
var _datos: Dictionary            # clientes, duración, etc. de este nivel
var _tiempo := 0.0                # segundos que quedan
var _oro := 0
var _atendidos := 0
var _creados := 0                 # clientes que ya llegaron
var _hasta_proximo := 0.0         # segundos para el siguiente cliente
var _siguiente_id := 1
var _pedidos := {}                # id del pedido -> segundos de paciencia que le quedan
var _terminado := false
var _ultima_velocidad := Vector3.ZERO     # velocidad del último disparo (para saber dónde cae)
var _prendas_antes := -1
var _frente_antes := -1                    # estado de la prenda que iba primera en la cola de munición
var _dejando := false                      # true mientras se deja una prenda a mano (no cuenta como tiro)
var _e_antes := false                      # E / F / R estaban pulsadas en el fotograma anterior (para avisar una vez)
var _f_antes := false
var _r_antes := false
var _cana_en_hud := false                  # la caña está marcada en la barra de herramientas del HUD
var _zonas := {}                           # nombre -> {"mat": material del marcador, "texto": Label3D}
var _ultimo_aviso := ""
var _t_aviso := 0.0


## Arranque: carga el nivel actual, conecta sol, sogas, loro, HUD y estaciones, y llega el primer cliente.
func _ready() -> void:
	EstadoJuego.asegurar_carga()
	_n = EstadoJuego.nivel_actual
	_datos = EstadoJuego.datos_nivel(_n)
	_tiempo = float(_datos.duracion)

	sogas.modo_prueba = false         # sin teclas de prueba: manda este controlador
	loro.modo_prueba = false
	# Por si la escena del mapa no los enlazó: las sogas avisan al sol y el sol mueve el cielo del fondo.
	if sogas.sistema_sol == null:
		sogas.sistema_sol = sistema_sol
	var cielo := get_node_or_null("Mapa/Cielo") as CieloAtardecer
	if sistema_sol.cielo == null and cielo != null:
		sistema_sol.cielo = cielo
	_conectar_resortera()
	_crear_estaciones()
	_crear_zonas()
	_mostrar_controles()
	hud.iniciar_nivel(_n)
	hud.conectar_sogas(sogas)
	hud.conectar_loro(loro)
	sogas.nivel_perdido.connect(_on_base_suelta)
	sogas.reparacion_cobrada.connect(_on_reparacion_cobrada)

	sogas.cargar(EstadoJuego.sogas)       # las sogas pasan de un día a otro (y las que compró en el taller)
	sistema_sol.poner_nivel(_n, false)    # el sol a la hora de este nivel
	_hasta_proximo = 0.0                  # el primer cliente llega de inmediato


## Cada fotograma: baja el reloj, avanza los pedidos, lee E/F/R, resalta la zona y revisa si el nivel terminó.
func _process(delta: float) -> void:
	if _terminado:
		return
	_tiempo -= delta
	hud.set_tiempo(_tiempo)
	_avanzar_pedidos(delta)
	_leer_teclas_estaciones(delta)
	_actualizar_zonas()
	_leer_reparacion(delta)
	if _tiempo <= 0.0:
		terminar(false)
	elif _creados >= int(_datos.clientes) and _pedidos.is_empty():
		terminar(false)                   # ya pasaron todos los clientes


# ---------------------------------------------------------------- Resortera de Isabella
## Cada prenda lanzada desgasta la soga de la plataforma donde cae y entra a la lavadora o al tendedero.
## EquipmentManager avisa el tiro (disparo_soltado) y MunicionManager descuenta la prenda: solo cuenta
## si de verdad se gastó una prenda.
func _conectar_resortera() -> void:
	if _equipo and _equipo.has_signal("disparo_soltado"):
		_equipo.disparo_soltado.connect(func(velocidad: Vector3, _tipo: int) -> void: _ultima_velocidad = velocidad)
	if _municion and _municion.has_signal("cantidad_prendas_cambiada"):
		_prendas_antes = int(_municion.get("cantidad_prendas"))
		_frente_antes = _estado_siguiente()
		_municion.cantidad_prendas_cambiada.connect(_on_prendas_cambiaron)


## Estado (0 sucia, 1 lavada, 2 seca) de la prenda que va primera en la cola de munición, o -1 si no hay.
func _estado_siguiente() -> int:
	if _municion and _municion.has_method("obtener_siguiente_estado"):
		return int(_municion.obtener_siguiente_estado())
	return -1


## Si la cantidad de prendas bajó, es que se disparó una: la que iba primera en la cola.
## Si la bajó dejar_prenda() (a mano), no es un tiro y no se cuenta aquí.
func _on_prendas_cambiaron(cantidad: int) -> void:
	var gasto := cantidad < _prendas_antes
	_prendas_antes = cantidad
	var disparada := _frente_antes            # estado de la prenda que salió
	_frente_antes = _estado_siguiente()       # y la nueva primera de la cola
	if gasto and not _dejando:
		_contar_tiro.call_deferred(disparada)  # deja que EquipmentManager termine de avisar el tiro


## Calcula dónde cayó el tiro y lo manda a lanzar(): izquierda = lavadora, derecha = tendedero.
func _contar_tiro(estado: int) -> void:
	var origen := _punto_mano.global_position if _punto_mano else Vector3.ZERO
	var x := x_de_caida(origen, _ultima_velocidad)
	lanzar("izquierda" if x < LIMITE_LADOS else "derecha", x, estado)


## x donde cae una prenda lanzada desde `origen` con `velocidad` (tiro parabólico, suelo en y = 0).
static func x_de_caida(origen: Vector3, velocidad: Vector3) -> float:
	var g := 9.8
	var t := (velocidad.y + sqrt(velocidad.y * velocidad.y + 2.0 * g * maxf(origen.y, 0.0))) / g
	return origen.x + velocidad.x * t


# ---------------------------------------------------------------- API pública
## Un tiro: desgasta la soga y la prenda entra a la lavadora (izquierda) o al tendedero (derecha).
## `estado` es el de la prenda lanzada (0 sucia, 1 lavada, 2 seca); sin él se asume la correcta para ese lado.
func lanzar(lado: String, x := NAN, estado := -1) -> void:
	if _terminado:
		return
	sogas.registrar_lanzamiento(lado, x)
	if lado == "izquierda":
		estaciones.recibir_en_lavadora(estado if estado >= 0 else EstacionesRopa.SUCIA)
	else:
		estaciones.recibir_en_tendedero(estado if estado >= 0 else EstacionesRopa.LAVADA)


## Deja a mano una prenda (tecla C). Hay que estar en la zona de la lavadora (se deja una prenda SUCIA)
## o del tendedero (una LAVADA). La busca en toda la cola: no importa en qué orden las recogiste.
## Si no hay de ese tipo, o la estación está llena, avisa y no se gasta nada.
func dejar_prenda() -> void:
	if _terminado:
		return
	var sitio := _sitio_cercano()
	if sitio != "lavadora" and sitio != "tendedero":
		_avisar("Camina hasta la lavadora o el tendedero para dejar la prenda")
		return
	if _municion == null or not _municion.tiene_prendas():
		_avisar("No llevas ninguna prenda")
		return
	var estado := EstacionesRopa.SUCIA if sitio == "lavadora" else EstacionesRopa.LAVADA
	if sitio == "lavadora" and estaciones.en_lavadora() >= EstacionesRopa.CAPACIDAD_LAVADORA:
		_avisar("La lavadora está llena")
		return
	if sitio == "tendedero" and estaciones.en_tendedero() >= EstacionesRopa.GANCHOS:
		_avisar("El tendedero está lleno")
		return
	if not _traer_al_frente(estado):
		_avisar("No llevas ninguna prenda %s" % ("sucia" if estado == EstacionesRopa.SUCIA else "lavada"))
		return
	_dejando = true                           # que no cuente como un tiro de resortera
	_municion.consumir_siguiente_prenda()
	_dejando = false
	lanzar("izquierda" if sitio == "lavadora" else "derecha", X_LAVADORA if sitio == "lavadora" else X_TENDEDERO, estado)


## Pone al frente de la cola la primera prenda con ese estado: las que están delante se pasan al final
## (la cola solo se puede sacar por delante). Devuelve false si no hay ninguna de ese estado.
func _traer_al_frente(estado: int) -> bool:
	var encontrada := false
	_dejando = true
	for i in int(_municion.cantidad_prendas):
		if _estado_siguiente() == estado:
			encontrada = true
			break
		var e: int = _municion.consumir_siguiente_prenda()   # la de adelante pasa al final de la cola
		_municion.agregar_prendas(1, e)
	_dejando = false
	return encontrada


## Paga un pedido. Con `prendas` (entrega real): 2 prendas pagan +30 oro y 1 prenda paga +10.
func entregar_pedido(prendas := -1) -> void:
	if _terminado or _pedidos.is_empty():
		return
	var pago := EstadoJuego.ORO_POR_CLIENTE
	if prendas >= 0 and prendas < prendas_por_pedido:
		pago = ORO_UNA_PRENDA
	var id: int = _pedidos.keys()[0]       # el cliente que más tiempo lleva esperando
	_pedidos.erase(id)
	hud.quitar_pedido(id, true)
	_oro += pago
	_atendidos += 1
	hud.set_oro(_oro)
	hud.mostrar_pago(pago)
	sogas.registrar_pedido()               # entregar también desgasta la soga del despacho


## Entrega REAL en el despacho: usa las prendas secas que lleva el pirata.
func entregar_en_despacho() -> bool:
	if _terminado or _pedidos.is_empty() or estaciones.secas <= 0:
		return false
	var n := estaciones.entregar(prendas_por_pedido)
	entregar_pedido(n)
	return true


## La piedra de Isabella le pegó al loro: se va asustado.
func piedra_acerto() -> void:
	loro.piedra_acerto()


## Reparar una soga: llamar cada fotograma MIENTRAS el jugador mantiene la tecla.
func reparar(delta: float, plataforma := "") -> void:
	if _terminado:
		return
	sogas.mantener_reparacion(plataforma if plataforma != "" else sogas.plataforma_mas_danada(), delta)


func dejar_de_reparar() -> void:
	sogas.soltar_reparacion()


## Fin del nivel: guarda oro y sogas, muestra "Fin del día" y pasa a la pantalla de Resultado.
func terminar(perdido_por_sogas: bool, forzar_paso := false) -> void:
	if _terminado:
		return
	_terminado = true
	if forzar_paso:
		_oro = maxi(_oro, int(_datos.minimo))
	EstadoJuego.terminar_nivel(_n, _oro, _atendidos, int(_datos.clientes), perdido_por_sogas)
	EstadoJuego.sogas = sogas.datos()       # lo que queda de las sogas viaja al taller
	EstadoJuego.guardar()
	hud.mostrar_aviso("Fin del día", "info")
	await get_tree().create_timer(2.0 if perdido_por_sogas else 1.0).timeout   # deja ver el sol apagarse
	Navegador.ir_a(self, Navegador.RESULTADO)


# ---------------------------------------------------------------- Pedidos (clientes)
## Hace llegar clientes cada cierto tiempo y gasta la paciencia de los que esperan.
func _avanzar_pedidos(delta: float) -> void:
	if _creados < int(_datos.clientes):
		_hasta_proximo -= delta
		if _hasta_proximo <= 0.0:
			_nuevo_pedido()
			_hasta_proximo = float(_datos.llegada)
	for id: int in _pedidos.keys():
		_pedidos[id] -= delta
		hud.actualizar_pedido(id, _pedidos[id])
		if _pedidos[id] <= 0.0:            # se acabó la paciencia: el cliente se va sin pagar
			_pedidos.erase(id)
			hud.quitar_pedido(id, false)
			hud.mostrar_pago(0)


## Llega un cliente: aparece en el HUD. Las prendas sucias las entrega el canasto de clientes de Isabella
## (se recogen con P y entran a la cola de munición), así no se duplican.
func _nuevo_pedido() -> void:
	var id := _siguiente_id
	_siguiente_id += 1
	_creados += 1
	_pedidos[id] = paciencia
	hud.agregar_pedido(id, "Barco %d" % id, paciencia, prendas_por_pedido)


# ---------------------------------------------------------------- Lavadora y tendedero
## Crea las estaciones dentro del mapa y las conecta: tendedero <-> loro, y avisos en el HUD.
func _crear_estaciones() -> void:
	estaciones = EstacionesRopa.new()
	estaciones.name = "EstacionesRopa"
	var mapa := get_node_or_null("Mapa")
	(mapa if mapa else self).add_child(estaciones)
	# Al tender, el loro empieza a contar sus 20 s; al retirar la prenda, deja de interesarse.
	estaciones.prenda_tendida.connect(func(g: int) -> void: loro.prenda_tendida(g))
	estaciones.prenda_retirada.connect(func(g: int) -> void: loro.prenda_retirada(g))
	loro.prenda_robada.connect(_on_prenda_robada)
	# Avisos del HUD en cada evento importante.
	estaciones.prenda_lavada.connect(func(_i: int) -> void: hud.mostrar_aviso("¡Prenda lavada! Jálala con E", "exito"))
	estaciones.prenda_seca.connect(func(_g: int) -> void: hud.mostrar_aviso("Prenda seca: sácala del tendedero", "exito"))
	estaciones.prenda_al_agua.connect(func(_e: int) -> void: hud.mostrar_aviso("¡Cayó al agua! Mantén F para rescatarla", "peligro"))
	estaciones.prenda_perdida.connect(func(_e: int) -> void: hud.mostrar_aviso("Se perdió una prenda", "peligro"))
	estaciones.prenda_rescatada.connect(func(e: int) -> void: _municion_mas(1, e))   # vuelve con su estado


## El loro agarró la prenda: se quita del gancho.
func _on_prenda_robada(gancho: int) -> void:
	if estaciones.robar(gancho):
		hud.mostrar_aviso("¡El loro se llevó una prenda!", "peligro")


## Suma prendas a la cola de munición de Isabella con ese estado (0 sucia, 1 lavada, 2 seca).
func _municion_mas(n: int, estado := 0) -> void:
	if _municion and _municion.has_method("agregar_prendas"):
		_municion.agregar_prendas(n, estado)


# ---------------------------------------------------------------- Zonas (dónde está parado el pirata)
## En qué zona está la mano del pirata ("lavadora", "tendedero", "despacho") o "" si en ninguna.
## (Si el mapa no trae jugador, devuelve la estación que sirva ahora, para poder probar el nivel solo.)
func _sitio_cercano() -> String:
	if _punto_mano == null:
		if estaciones.secas > 0:
			return "despacho"
		for s in ["lavadora", "tendedero"]:
			if estaciones.hay_para_jalar(s):
				return s
		return ""
	var x := _punto_mano.global_position.x
	var mejor := ""
	var d_mejor := alcance_x
	for nombre: String in ZONAS:
		var d := absf(x - float(ZONAS[nombre]))
		if d <= d_mejor:
			d_mejor = d
			mejor = nombre
	return mejor


func _cerca_del_agua() -> bool:
	if _punto_mano == null:
		return true
	var x := _punto_mano.global_position.x
	return absf(x - X_AGUA_LAVADORA) <= alcance_x or absf(x - X_AGUA_TENDEDERO) <= alcance_x


## Dibuja en el piso un rectángulo de color por zona y un rótulo encima (el rótulo muestra la ayuda al entrar).
func _crear_zonas() -> void:
	var padre: Node = get_node_or_null("Mapa")
	if padre == null:
		padre = self
	for nombre: String in ZONAS:
		var x: float = ZONAS[nombre]
		var caja := BoxMesh.new()
		caja.size = Vector3(alcance_x * 2.0, 0.02, 1.3)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(COLOR_ZONA[nombre], 0.2)
		var marca := MeshInstance3D.new()
		marca.name = "Zona_" + nombre
		marca.mesh = caja
		marca.material_override = mat
		marca.position = Vector3(x, 0.02, 0.0)
		padre.add_child(marca)
		var texto := Label3D.new()
		texto.text = TITULO_ZONA[nombre]
		texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		texto.no_depth_test = true
		texto.pixel_size = 0.008
		texto.font_size = 40
		texto.outline_size = 10
		texto.position = Vector3(x, 0.9, 0.9)   # bajo y hacia la cámara: no choca con el HUD de arriba
		padre.add_child(texto)
		_zonas[nombre] = {"mat": mat, "texto": texto}


## La zona donde está el pirata se ilumina y muestra qué teclas sirven ahí.
func _actualizar_zonas() -> void:
	var actual := _sitio_cercano() if _punto_mano != null else ""
	for nombre: String in _zonas:
		var dentro := nombre == actual
		var mat: StandardMaterial3D = _zonas[nombre].mat
		mat.albedo_color.a = 0.55 if dentro else 0.2
		var texto: Label3D = _zonas[nombre].texto
		texto.text = TITULO_ZONA[nombre] + ("\n" + AYUDA_ZONA[nombre] if dentro else "")


## Mensaje corto en el HUD; no repite el mismo texto seguido (por si se mantiene la tecla).
func _avisar(texto: String, tipo := "info") -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if texto == _ultimo_aviso and ahora - _t_aviso < 2.0:
		return
	_ultimo_aviso = texto
	_t_aviso = ahora
	hud.mostrar_aviso(texto, tipo)


# ---------------------------------------------------------------- Teclas reales: E y F
## E mantenida: recoge de la lavadora / tendedero (1 s) o entrega en el despacho (un toque).
## F mantenida: rescata del agua (2 s). Al soltar la tecla se reinicia el progreso.
## Solo funcionan dentro de la zona correspondiente.
func _leer_teclas_estaciones(delta: float) -> void:
	var e := Input.is_key_pressed(KEY_E)
	if e:
		var sitio := _sitio_cercano()
		if sitio == "despacho":
			if not estaciones._jalar_hecho:
				if entregar_en_despacho():
					estaciones._jalar_hecho = true
				elif not _e_antes:
					_avisar("Para entregar necesitas un pedido y una prenda seca en la mano")
		elif sitio != "":
			if estaciones.jalar(sitio, delta) and sitio == "lavadora":
				_municion_mas(1, EstacionesRopa.LAVADA)   # la prenda lavada vuelve a la munición para tenderla
			elif not _e_antes and not estaciones.hay_para_jalar(sitio):
				_avisar("Todavía no hay prendas listas aquí")
		else:
			estaciones.progreso_jalar = 0.0
			if not _e_antes:
				_avisar("Camina hasta la lavadora, el tendedero o el despacho")
	else:
		estaciones.soltar_jalar()
	_e_antes = e

	var f := Input.is_key_pressed(KEY_F)
	if f and _cerca_del_agua():
		estaciones.rescatar(delta)
		if not _f_antes and estaciones.charcos.is_empty():
			_avisar("No hay prendas en el agua")
	else:
		estaciones.soltar_rescate()
		if f and not _f_antes:
			_avisar("Camina hasta el agua de la lavadora o del tendedero")
	_f_antes = f
	# La barra de herramientas de Kevin marca la caña mientras se rescata, y vuelve a la resortera al soltar.
	var usando_cana := f and _cerca_del_agua() and not estaciones.charcos.is_empty()
	if usando_cana != _cana_en_hud:
		_cana_en_hud = usando_cana
		hud.equipar("cana" if usando_cana else "resortera")


# ---------------------------------------------------------------- Sogas
## R mantenida: repara la soga de la plataforma de la zona donde está el pirata (lavadora, tendedero o despacho).
## Fuera de las zonas no hace nada y avisa.
func _leer_reparacion(delta: float) -> void:
	var r := Input.is_key_pressed(KEY_R)
	if r:
		var sitio := _sitio_cercano()
		if sitio != "":
			reparar(delta, sitio)
		else:
			dejar_de_reparar()
			if not _r_antes:
				_avisar("Camina hasta una zona para reparar su soga")
	else:
		dejar_de_reparar()
	_r_antes = r


## Una plataforma quedó sin sus dos sogas: se pierde el nivel.
func _on_base_suelta() -> void:
	terminar(true)


## Reparar una soga cuesta oro: se descuenta del día.
func _on_reparacion_cobrada(costo: int) -> void:
	_oro = maxi(0, _oro - costo)
	hud.set_oro(_oro)


# ---------------------------------------------------------------- Tecla C
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_C:
		dejar_prenda()


## Línea fija con los controles del nivel (abajo a la izquierda).
func _mostrar_controles() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	var l := Label.new()
	l.text = "A/D mover · P canasto · C dejar prenda · E sacar/entregar · F rescatar · R reparar"
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	l.add_theme_font_size_override("font_size", 13)
	capa.add_child(l)
	add_child(capa)
