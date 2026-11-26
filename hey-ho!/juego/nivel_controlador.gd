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
## CONTROLES REALES (acordados por el equipo; no hay teclas de prueba):
##   A / D ........ caminar (script del pirata)
##   P ............ coger el canasto y la ropa (Isabella)
##   1 ............ resortera: apuntar con clic sostenido y soltar. La prenda llega a la lavadora
##                  (tiro a la izquierda) o al tendedero (a la derecha). Es la ÚNICA forma de que la ropa llegue.
##   2 ............ piedra: se equipa con el 2 y sirve para espantar al loro (Isabella)
##   3 ............ caña (la de Isabella): clic para lanzar la boya, otro clic para recogerla.
##                  Con la boya sobre la lavadora o el tendedero recoge la prenda lista (1 s);
##                  con la boya en el agua rescata una prenda caída (2 s). Hay que estar en la zona.
##   E ............ entregar el pedido en el despacho (con prendas secas en la mano)
##   R (mantener) . reparar la soga de la zona donde estás parado
##
## Las teclas de ESTE script (E y R) están en las constantes TECLA_* de abajo. Las de Isabella (P, 1, 2, 3)
## las lee su propio código; aquí solo se listan para que las ayudas en pantalla digan siempre lo mismo.
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

# ---------------------------------------------------------------- Teclas (única fuente de verdad)
## Las que lee este script.
const TECLA_ENTREGAR: Key = KEY_E
const TECLA_REPARAR: Key = KEY_R
## Las que lee el código de Isabella (aquí solo sirven para escribir las ayudas con la tecla correcta).
const TECLA_CANASTO: Key = KEY_P
const TECLA_RESORTERA: Key = KEY_1
const TECLA_PIEDRA: Key = KEY_2
const TECLA_CANA: Key = KEY_3
const ESCENA_PAUSA: PackedScene = preload("res://juego/pausa.tscn")

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

# ---------------------------------------------------------------- Piezas del nivel
@onready var hud: HudHeyHo = %Hud                                  # el HUD de Kevin
@onready var sistema_sol: SistemaSol = $Mapa/SistemaSol
@onready var sogas: SistemaSogas = $Mapa/SistemaSogas
@onready var loro: Loro = $Mapa/Loro
## Piezas de la resortera y la caña de Isabella (si el mapa las trae). Si no existen, quedan en null.
@onready var _equipo: Node = get_node_or_null("Mapa/EquipmentManager")
@onready var _municion: Node = get_node_or_null("Mapa/MunicionManager")
## La mano del pirata se busca por nombre, así no importa cómo se llame el CharacterBody3D de Isabella.
@onready var _punto_mano: Node3D = _buscar_mano()

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
var _entrega_hecha := false                # ya se entregó con esta pulsación de E (hay que soltar E para entregar otra)
var _e_antes := false                      # E estaba pulsada / la boya estaba lanzada en el fotograma anterior
var _boya_antes := false
var _r_antes := false
var _item_hud := -1                        # herramienta que el HUD de Kevin tiene marcada (para no repetir)
var _zonas := {}                           # nombre -> {"mat": material del marcador, "texto": Label3D}
var _ayuda_zona := {}                      # nombre de zona -> ayuda con las teclas (se arma en _ready)
var _aviso_equipo := {}                    # herramienta -> mensaje al equiparla (se arma en _ready)
var _ultimo_aviso := ""
var _t_aviso := 0.0
var _menu_pausa: MenuPausa


## Arranque: carga el nivel actual, conecta sol, sogas, loro, HUD y estaciones, y llega el primer cliente.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_menu_pausa()
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
	_armar_textos()
	_conectar_resortera()
	_crear_estaciones()
	_crear_zonas()
	_mostrar_controles()
	hud.iniciar_nivel(_n)
	hud.conectar_sogas(sogas)
	hud.conectar_loro(loro)
	if _equipo and _equipo.has_signal("tension_cambiada"):
		_equipo.tension_cambiada.connect(hud.set_carga)
	if _equipo and _equipo.has_signal("piedras_cambiadas"):
		_equipo.piedras_cambiadas.connect(hud.set_piedras)
		hud.set_piedras(int(_equipo.get("piedras_disponibles")))
	sogas.nivel_perdido.connect(_on_base_suelta)
	sogas.reparacion_cobrada.connect(_on_reparacion_cobrada)

	sogas.cargar(EstadoJuego.sogas)       # las sogas pasan de un día a otro (y las que compró en el taller)
	sistema_sol.poner_nivel(_n, false)    # el sol a la hora de este nivel
	_hasta_proximo = 0.0                  # el primer cliente llega de inmediato


## Cada fotograma: baja el reloj, avanza los pedidos, lee E/caña/R, resalta la zona y revisa si el nivel terminó.
func _process(delta: float) -> void:
	if _terminado or get_tree().paused:
		return
	_tiempo -= delta
	hud.set_tiempo(_tiempo)
	_avanzar_pedidos(delta)
	_leer_entrega()
	_leer_cana(delta)
	_actualizar_zonas()
	_leer_reparacion(delta)
	_sincronizar_hud()
	if _tiempo <= 0.0:
		terminar(false)
	elif _creados >= int(_datos.clientes) and _pedidos.is_empty():
		terminar(false)                   # ya pasaron todos los clientes


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _terminado:
		return

	if get_tree().paused:
		_reanudar_desde_pausa()
	else:
		_abrir_pausa()
	get_viewport().set_input_as_handled()


func _montar_menu_pausa() -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaPausa"
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)

	_menu_pausa = ESCENA_PAUSA.instantiate() as MenuPausa
	_menu_pausa.hide()
	capa.add_child(_menu_pausa)
	_menu_pausa.continuar.connect(_reanudar_desde_pausa)
	_menu_pausa.reiniciar.connect(_reiniciar_desde_pausa)
	_menu_pausa.volver_al_menu.connect(_volver_al_menu_desde_pausa)


func _abrir_pausa() -> void:
	_menu_pausa.mostrar_menu()
	get_tree().paused = true


func _reanudar_desde_pausa() -> void:
	get_tree().paused = false
	_menu_pausa.hide()


func _reiniciar_desde_pausa() -> void:
	get_tree().paused = false
	Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL)


func _volver_al_menu_desde_pausa() -> void:
	get_tree().paused = false
	Navegador.ir_a(self, Navegador.MENU)


## Busca la mano del pirata (nodo "PuntoMano") dentro de PlayerPirata, con el nombre que tenga su cuerpo.
func _buscar_mano() -> Node3D:
	var pirata := get_node_or_null("Mapa/PlayerPirata")
	if pirata == null:
		return null
	return pirata.find_child("PuntoMano", true, false) as Node3D


# ---------------------------------------------------------------- Textos con las teclas
## Nombre de la tecla tal como se escribe en pantalla ("E", "1", "P"...).
static func _tecla(k: Key) -> String:
	return OS.get_keycode_string(k)


## Arma todas las ayudas con las constantes TECLA_*: si una tecla cambia, cambia en todos los textos.
func _armar_textos() -> void:
	var res := _tecla(TECLA_RESORTERA)
	var cana := _tecla(TECLA_CANA)
	_ayuda_zona = {
		"lavadora": "%s resortera: lanzar prenda sucia\n%s caña: recoger lavada" % [res, cana],
		"tendedero": "%s resortera: lanzar prenda lavada\n%s caña: recoger seca" % [res, cana],
		"despacho": "%s: entregar pedido\n%s: coger canasto y ropa" % [_tecla(TECLA_ENTREGAR), _tecla(TECLA_CANASTO)],
	}
	_aviso_equipo = {
		"resortera": "Resortera (%s): mantén clic para apuntar y suelta para lanzar" % res,
		"piedra": "Piedra (%s): úsala para espantar al loro" % _tecla(TECLA_PIEDRA),
		"cana": "Caña (%s): clic para lanzar la boya, otro clic para recogerla" % cana,
	}


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
func _on_prendas_cambiaron(cantidad: int) -> void:
	var gasto := cantidad < _prendas_antes
	_prendas_antes = cantidad
	var disparada := _frente_antes            # estado de la prenda que salió
	_frente_antes = _estado_siguiente()       # y la nueva primera de la cola
	if gasto:
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
	estaciones.prenda_lavada.connect(func(_i: int) -> void: hud.mostrar_aviso("¡Prenda lavada! Recógela con la caña (3)", "exito"))
	estaciones.prenda_seca.connect(func(_g: int) -> void: hud.mostrar_aviso("Prenda seca: recógela con la caña (3)", "exito"))
	estaciones.prenda_al_agua.connect(func(_e: int) -> void: hud.mostrar_aviso("¡Cayó al agua! Lanza la caña al agua para rescatarla", "peligro"))
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
## Zona ("lavadora", "tendedero", "despacho") que contiene esa x, o "" si ninguna.
func _zona_en_x(x: float) -> String:
	var mejor := ""
	var d_mejor := alcance_x
	for nombre: String in ZONAS:
		var d := absf(x - float(ZONAS[nombre]))
		if d <= d_mejor:
			d_mejor = d
			mejor = nombre
	return mejor


## En qué zona está la mano del pirata o "" si en ninguna.
## (Si el mapa no trae jugador, devuelve la estación que sirva ahora, para poder probar el nivel solo.)
func _sitio_cercano() -> String:
	if _punto_mano == null:
		if estaciones.secas > 0:
			return "despacho"
		for s in ["lavadora", "tendedero"]:
			if estaciones.hay_para_jalar(s):
				return s
		return ""
	return _zona_en_x(_punto_mano.global_position.x)


## ¿Esa x está sobre el agua de la lavadora o del tendedero?
func _x_en_agua(x: float) -> bool:
	return absf(x - X_AGUA_LAVADORA) <= alcance_x or absf(x - X_AGUA_TENDEDERO) <= alcance_x


func _cerca_del_agua() -> bool:
	if _punto_mano == null:
		return true
	return _x_en_agua(_punto_mano.global_position.x)


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
		texto.text = TITULO_ZONA[nombre] + ("\n" + _ayuda_zona[nombre] if dentro else "")


## Mensaje corto en el HUD; no repite el mismo texto seguido (por si se mantiene la tecla).
func _avisar(texto: String, tipo := "info") -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if texto == _ultimo_aviso and ahora - _t_aviso < 2.0:
		return
	_ultimo_aviso = texto
	_t_aviso = ahora
	hud.mostrar_aviso(texto, tipo)


# ---------------------------------------------------------------- Entrega (E) y caña (3)
## E (TECLA_ENTREGAR): entrega el pedido (un toque) cuando el pirata está en la zona DESPACHO.
func _leer_entrega() -> void:
	var e := Input.is_key_pressed(TECLA_ENTREGAR)
	if e:
		if _sitio_cercano() == "despacho":
			if not _entrega_hecha:
				if entregar_en_despacho():
					_entrega_hecha = true
				elif not _e_antes:
					_avisar("Para entregar (%s) necesitas un pedido y una prenda seca en la mano" % _tecla(TECLA_ENTREGAR))
		elif not _e_antes:
			_avisar("%s sirve en el despacho para entregar el pedido" % _tecla(TECLA_ENTREGAR))
	else:
		_entrega_hecha = false
	_e_antes = e


## La caña de Isabella (CanaPescar) si está equipada (TECLA_CANA, la 3) o null.
func _cana_equipada() -> CanaPescar:
	if _equipo == null:
		return null
	var c: Variant = _equipo.get("instancia_cana")
	return c as CanaPescar if is_instance_valid(c) else null


## La caña, con la boya lanzada. Mientras la boya esté sobre una estación se va llenando la barra:
##   - boya en el agua con una prenda caída: la rescata (2 s). Va primero porque se pierde a los 8 s.
##   - boya sobre la lavadora o el tendedero con una prenda lista: la recoge (1 s).
## Siempre con el pirata parado en esa zona. Al recoger la boya (otro clic) se reinicia el progreso.
func _leer_cana(delta: float) -> void:
	var cana := _cana_equipada()
	var lanzada := cana != null and cana.linea_lanzada
	var x_boya := cana.bobber.global_position.x if lanzada else 0.0
	var sitio := _sitio_cercano()
	var zona_boya := _zona_en_x(x_boya) if lanzada else ""
	var en_agua := lanzada and _cerca_del_agua() and _x_en_agua(x_boya) and not estaciones.charcos.is_empty()
	var en_estacion := lanzada and (sitio == "lavadora" or sitio == "tendedero") \
		and zona_boya == sitio and estaciones.hay_para_jalar(sitio)
	if en_agua:
		estaciones.soltar_jalar()
		estaciones.rescatar(delta)
	elif en_estacion:
		estaciones.soltar_rescate()
		if estaciones.jalar(sitio, delta) and sitio == "lavadora":
			_municion_mas(1, EstacionesRopa.LAVADA)   # la prenda lavada vuelve a la munición para lanzarla al tendedero
	else:
		estaciones.soltar_jalar()
		estaciones.soltar_rescate()
		# Un aviso cuando acaba de caer la boya y no pasó nada (la boya tarda unos instantes en llegar).
		if lanzada and not _boya_antes:
			_avisar("Pon la boya sobre la lavadora, el tendedero o el agua, estando en esa zona")
	_boya_antes = lanzada


## La barra de herramientas de Kevin marca la herramienta que Isabella tiene equipada (1, 2 o 3).
func _sincronizar_hud() -> void:
	if _equipo == null:
		return
	var item := int(_equipo.get("item_actual"))
	if item == _item_hud:
		return
	var primera_vez := _item_hud == -1        # al empezar el nivel no se avisa, solo cuando el jugador cambia
	_item_hud = item
	var herramienta := ""
	match item:
		1: herramienta = "resortera"
		2: herramienta = "piedra"
		3: herramienta = "cana"
	if herramienta == "":
		return
	hud.equipar(herramienta)
	if not primera_vez:
		_avisar(_aviso_equipo[herramienta])


# ---------------------------------------------------------------- Sogas
## R (TECLA_REPARAR) mantenida: repara la soga de la plataforma de la zona donde está el pirata (lavadora, tendedero o despacho).
## Fuera de las zonas no hace nada y avisa.
func _leer_reparacion(delta: float) -> void:
	var r := Input.is_key_pressed(TECLA_REPARAR)
	if r:
		var sitio := _sitio_cercano()
		if sitio != "":
			reparar(delta, sitio)
		else:
			dejar_de_reparar()
			if not _r_antes:
				_avisar("Camina hasta una zona y mantén %s para reparar su soga" % _tecla(TECLA_REPARAR))
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


## Recordatorio fijo con los controles del nivel (abajo a la izquierda, en dos líneas cortas para no tapar
## el inventario del HUD, que va centrado). Respeta el ajuste "pistas de teclas" del menú de opciones.
func _mostrar_controles() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	capa.visible = EstadoJuego.pistas_teclas
	var l := Label.new()
	l.text = "A/D mover · %s canasto y ropa · %s reparar soga\n%s resortera · %s piedra · %s caña · %s entregar" % [
		_tecla(TECLA_CANASTO), _tecla(TECLA_REPARAR),
		_tecla(TECLA_RESORTERA), _tecla(TECLA_PIEDRA), _tecla(TECLA_CANA), _tecla(TECLA_ENTREGAR)]
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.1, 0.9))
	capa.add_child(l)
	add_child(capa)
