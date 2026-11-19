class_name HudHeyHo
extends CanvasLayer
## HUD de ¡Hey HO! Se instancia dentro de la escena del nivel y se maneja con métodos y señales.
## Colores = funciones del juego (ver UITema): CREMA lo que vale · VERDE acierto · ROJO peligro · MADERA sogas.
##
## API principal (la usa la lógica del nivel):
##   iniciar_nivel(n) · set_oro(v) · set_tiempo(s) · set_reparacion(oro) · set_piedras(n) · equipar("resortera"|"piedra"|"cana")
##   agregar_pedido(id, titulo, paciencia, prendas) · actualizar_pedido(id, restante) · quitar_pedido(id, entregado)
##   set_franja(ini, fin) · set_carga(t) · mostrar_carga(bool) · mostrar_pago(cantidad) · mostrar_aviso(texto, tipo)
##   conectar_sogas(nodo_sistema_sogas) · conectar_loro(nodo_loro)

const FILA_SOGA := preload("res://componentes/fila_soga.tscn")
const BARRA_PACIENCIA := preload("res://componentes/barra_paciencia.tscn")
const PAUSA := preload("res://juego/pausa.tscn")
const CARGA_MAX := 1.2   # segundos que cubre la barra de carga de la resortera

@onready var raiz: Control = %Raiz
@onready var oro: Label = %Oro
@onready var barra_oro: ProgressBar = %BarraOro
@onready var marca_minimo: ColorRect = %MarcaMinimo
@onready var texto_minimo: Label = %TextoMinimo
@onready var tiempo: Label = %Tiempo
@onready var dia: Label = %Dia
@onready var barra_reparacion: ProgressBar = %BarraReparacion
@onready var texto_reparacion: Label = %TextoReparacion
@onready var lista_sogas: VBoxContainer = %ListaSogas
@onready var lista_pedidos: VBoxContainer = %ListaPedidos
@onready var contenedor_carga: Control = %ContenedorCarga
@onready var franja: ColorRect = %Franja
@onready var relleno: ColorRect = %Relleno
@onready var extra_piedra: Label = %ExtraPiedra
@onready var aviso: Label = %AvisoTexto
@onready var flotantes: Control = %Flotantes
@onready var borde_alerta: Panel = %BordeAlerta
@onready var pista_pausa: Label = %PistaPausa
@onready var slots := {
	"resortera": %SlotResortera as PanelContainer,
	"piedra": %SlotPiedra as PanelContainer,
	"cana": %SlotCana as PanelContainer,
}

signal pausa_cambiada(activa: bool)

var _filas := {}
var _pedidos := {}
var _minimo := 0
var _franja := Vector2(0.7, 1.0)
var _tiempo_en_peligro := false
var _pausa: Control = null
var _tween_aviso: Tween
var _tween_borde: Tween


func _ready() -> void:
	for p: String in EstadoJuego.PLATAFORMAS:
		var fila: FilaSoga = FILA_SOGA.instantiate()
		lista_sogas.add_child(fila)
		fila.configurar(p, EstadoJuego.NOMBRES_PLATAFORMA[p])
		_filas[p] = fila
	aviso.modulate.a = 0.0
	borde_alerta.modulate.a = 0.0
	mostrar_carga(false)
	set_franja(0.7, 1.0)
	set_carga(0.0)
	equipar("resortera")
	set_piedras(3)
	aplicar_pistas()
	iniciar_nivel(EstadoJuego.nivel_actual)


# ---------------------------------------------------------------- Nivel, oro, tiempo, reparación
func iniciar_nivel(n: int) -> void:
	var d := EstadoJuego.datos_nivel(n)
	dia.text = "Día %d" % n
	_minimo = d.minimo
	barra_oro.max_value = d.oro_max
	var ratio := float(d.minimo) / float(d.oro_max)
	marca_minimo.anchor_left = ratio
	marca_minimo.anchor_right = ratio
	texto_minimo.text = "Mínimo %d oro" % d.minimo
	set_oro(0)
	set_tiempo(float(d.duracion))
	set_reparacion(EstadoJuego.oro_total)


func set_oro(valor: int) -> void:
	var subio := oro.text != "" and valor > int(oro.text)
	oro.text = str(valor)
	barra_oro.value = valor
	# CREMA = lo que vale; pasa a VERDE al alcanzar el mínimo (acierto).
	barra_oro.theme_type_variation = &"BarraVerde" if valor >= _minimo else &"BarraCrema"
	if subio:
		oro.pivot_offset = oro.size / 2.0
		var t := create_tween()
		t.tween_property(oro, "scale", Vector2(1.3, 1.3), 0.08)
		t.tween_property(oro, "scale", Vector2.ONE, 0.12)


func set_tiempo(segundos: float) -> void:
	tiempo.text = EstadoJuego.formato_tiempo(segundos)
	var peligro := segundos <= 10.0
	if peligro != _tiempo_en_peligro:
		_tiempo_en_peligro = peligro
		tiempo.theme_type_variation = &"LabelTiempoPeligro" if peligro else &"LabelTiempo"


func set_reparacion(oro_ahorrado: int) -> void:
	barra_reparacion.max_value = EstadoJuego.COSTO_REPARACION
	barra_reparacion.value = mini(oro_ahorrado, EstadoJuego.COSTO_REPARACION)
	texto_reparacion.text = "Barco %d / %d" % [oro_ahorrado, EstadoJuego.COSTO_REPARACION]


# ---------------------------------------------------------------- Inventario
func equipar(herramienta: String) -> void:
	for nombre: String in slots:
		var slot: PanelContainer = slots[nombre]
		slot.theme_type_variation = &"PanelSlotActivo" if nombre == herramienta else &"PanelSlot"


func set_piedras(cantidad: int) -> void:
	extra_piedra.text = "x%d" % cantidad
	slots["piedra"].modulate.a = 1.0 if cantidad > 0 else 0.45


func aplicar_pistas() -> void:
	for nodo in get_tree().get_nodes_in_group("pista_tecla"):
		nodo.visible = EstadoJuego.pistas_teclas
	pista_pausa.visible = EstadoJuego.pistas_teclas


# ---------------------------------------------------------------- Barra de carga de la resortera
## Segundos de inicio y fin de la franja verde (0,7 a 1,0 s en el concepto; se angosta a 0,15 s con sogas bajo 30).
func set_franja(inicio: float, fin: float) -> void:
	_franja = Vector2(inicio, fin)
	franja.anchor_left = clampf(inicio / CARGA_MAX, 0.0, 1.0)
	franja.anchor_right = clampf(fin / CARGA_MAX, 0.0, 1.0)


func set_carga(t: float) -> void:
	relleno.anchor_right = clampf(t / CARGA_MAX, 0.0, 1.0)
	var en_franja := t >= _franja.x and t <= _franja.y
	relleno.color = UITema.VERDE if en_franja else UITema.CELESTE


func mostrar_carga(visible_: bool) -> void:
	contenedor_carga.visible = visible_


# ---------------------------------------------------------------- Pedidos (barcos clientes)
func agregar_pedido(id: int, titulo: String, paciencia_max: float, prendas := 2) -> BarraPaciencia:
	var barra: BarraPaciencia = BARRA_PACIENCIA.instantiate()
	lista_pedidos.add_child(barra)
	barra.configurar(titulo, paciencia_max, prendas)
	_pedidos[id] = barra
	return barra


func actualizar_pedido(id: int, restante: float) -> void:
	if _pedidos.has(id):
		(_pedidos[id] as BarraPaciencia).actualizar(restante)


func quitar_pedido(id: int, entregado := true) -> void:
	if _pedidos.has(id):
		(_pedidos[id] as BarraPaciencia).cerrar(entregado)
		_pedidos.erase(id)


# ---------------------------------------------------------------- Mensajes y efectos
## Monedas CREMA que suben junto al contador. Con 0 se muestra "sin pago" en ROJO (el barco se va).
func mostrar_pago(cantidad: int) -> void:
	var l := Label.new()
	l.theme_type_variation = &"LabelOro"
	l.text = "+%d" % cantidad if cantidad > 0 else "Sin pago"
	if cantidad <= 0:
		l.add_theme_color_override("font_color", UITema.ROJO)
	flotantes.add_child(l)
	l.global_position = oro.global_position + Vector2(70.0, 6.0)
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 56.0, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


## tipo: "info" (CREMA), "exito" (VERDE) o "peligro" (ROJO).
func mostrar_aviso(texto: String, tipo := "info") -> void:
	aviso.text = texto
	var color := UITema.CREMA
	if tipo == "exito":
		color = UITema.VERDE
	elif tipo == "peligro":
		color = UITema.ROJO
	aviso.add_theme_color_override("font_color", color)
	if _tween_aviso:
		_tween_aviso.kill()
	aviso.modulate.a = 0.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(aviso, "modulate:a", 1.0, 0.15)
	_tween_aviso.tween_interval(1.6)
	_tween_aviso.tween_property(aviso, "modulate:a", 0.0, 0.4)


## Borde rojo que parpadea (alerta del loro, sogas por soltarse...).
func alerta_borde(segundos := 3.0) -> void:
	if _tween_borde:
		_tween_borde.kill()
	borde_alerta.modulate.a = 0.0
	_tween_borde = create_tween()
	for i in maxi(1, int(segundos / 0.5)):
		_tween_borde.tween_property(borde_alerta, "modulate:a", 1.0, 0.25)
		_tween_borde.tween_property(borde_alerta, "modulate:a", 0.15, 0.25)
	_tween_borde.tween_property(borde_alerta, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------- Sogas
func poner_soga(plataforma: String, indice: int, resistencia: float) -> void:
	if _filas.has(plataforma):
		(_filas[plataforma] as FilaSoga).poner_resistencia(indice, resistencia)


func poner_inestable(plataforma: String, inestable: bool) -> void:
	if _filas.has(plataforma):
		(_filas[plataforma] as FilaSoga).poner_inestable(inestable)
	if inestable:
		mostrar_aviso("¡Plataforma inestable: repárala!", "peligro")
		alerta_borde(2.0)


func poner_reparacion(plataforma: String, fraccion: float) -> void:
	if _filas.has(plataforma):
		(_filas[plataforma] as FilaSoga).poner_reparacion(fraccion)


## Conecta el SistemaSogas de la lógica del juego (sus señales llevan los mismos nombres).
func conectar_sogas(sistema: Node) -> void:
	sistema.connect("soga_cambio", poner_soga)
	sistema.connect("plataforma_desestabilizada", poner_inestable)
	sistema.connect("reparacion_progreso", poner_reparacion)
	sistema.connect("nivel_perdido", _on_nivel_perdido)
	if "sogas" in sistema:
		var datos: Dictionary = sistema.sogas
		for p: String in datos:
			for i in 2:
				poner_soga(p, i, float(datos[p][i]))


## Conecta el Loro de la lógica del juego.
func conectar_loro(loro: Node) -> void:
	loro.connect("aviso_graznido", func(_g: int) -> void:
		mostrar_aviso("¡Cuidado, un loro!", "peligro")
		alerta_borde(3.0))
	loro.connect("loro_llego", func(_g: int) -> void: mostrar_aviso("¡El loro está en el tendedero!", "peligro"))
	loro.connect("prenda_robada", func(_g: int) -> void: mostrar_aviso("¡Se llevó una prenda!", "peligro"))
	loro.connect("loro_huyo", func(_g: int) -> void: mostrar_aviso("¡Loro espantado!", "exito"))


func _on_nivel_perdido() -> void:
	mostrar_aviso("¡La base se soltó!", "peligro")
	alerta_borde(2.0)


# ---------------------------------------------------------------- Pausa (Esc)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _pausa == null:
			abrir_pausa()
		else:
			cerrar_pausa()


func abrir_pausa() -> void:
	if _pausa != null:
		return
	_pausa = PAUSA.instantiate()
	raiz.add_child(_pausa)
	_pausa.continuar.connect(cerrar_pausa)
	_pausa.reiniciar.connect(func() -> void: Navegador.ir_a(self, get_tree().current_scene.scene_file_path))
	_pausa.volver_al_menu.connect(func() -> void: Navegador.ir_a(self, Navegador.MENU))
	get_tree().paused = true
	pausa_cambiada.emit(true)


func cerrar_pausa() -> void:
	if _pausa != null:
		_pausa.queue_free()
		_pausa = null
	get_tree().paused = false
	pausa_cambiada.emit(false)
