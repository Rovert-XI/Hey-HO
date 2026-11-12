extends Control
## Pantalla de resultado del día. Lee EstadoJuego.ultimo (lo llena EstadoJuego.terminar_nivel).

@onready var titulo: Label = %Titulo
@onready var subtitulo: Label = %Subtitulo
@onready var oro_ganado: Label = %OroGanado
@onready var barra: ProgressBar = %BarraResultado
@onready var marca_minimo: ColorRect = %MarcaMinimo
@onready var texto_minimo: Label = %TextoMinimo
@onready var estado: Label = %Estado
@onready var detalles: Label = %Detalles
@onready var boton_siguiente: Button = %BotonSiguiente
@onready var boton_reintentar: Button = %BotonReintentar
@onready var boton_menu: Button = %BotonMenu

var _datos: Dictionary


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	_datos = EstadoJuego.ultimo
	if _datos.is_empty():   # abierta sin jugar: datos de ejemplo
		_datos = EstadoJuego.terminar_nivel(1, 60, 3, 3)
	var n: int = _datos.nivel
	var paso: bool = _datos.paso
	var perdido: bool = _datos.perdido_por_sogas

	titulo.text = "DÍA %d COMPLETADO" % n if paso else "DÍA %d PERDIDO" % n
	titulo.add_theme_color_override("font_color", UITema.CREMA if paso else UITema.ROJO)
	if perdido:
		subtitulo.text = "Las dos sogas de una plataforma se rompieron."
	elif paso:
		subtitulo.text = "El capitán suma monedas para el barco."
	else:
		subtitulo.text = "No llegaste al mínimo de oro del día."
	barra.max_value = _datos.oro_max
	marca_minimo.anchor_left = float(_datos.minimo) / float(_datos.oro_max)
	marca_minimo.anchor_right = marca_minimo.anchor_left
	texto_minimo.text = "Mínimo para pasar: %d oro" % _datos.minimo
	detalles.text = "Clientes atendidos: %d / %d" % [_datos.atendidos, _datos.total_clientes]
	if paso:
		detalles.text += "   ·   Oro ahorrado: +%d (total %d)" % [_datos.ahorrado, EstadoJuego.oro_total]

	estado.modulate.a = 0.0
	estado.text = "¡APROBADO!" if paso else ("¡LA BASE SE SOLTÓ!" if perdido else "NO APROBADO")
	estado.theme_type_variation = &"LabelExito" if paso else &"LabelPeligro"
	_configurar_botones(paso, n)

	# El oro sube contando; al terminar aparece el veredicto.
	var t := create_tween()
	t.tween_method(_mostrar_oro, 0, int(_datos.oro), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(estado, "modulate:a", 1.0, 0.3)


func _mostrar_oro(valor: int) -> void:
	oro_ganado.text = str(valor)
	barra.value = valor
	barra.theme_type_variation = &"BarraVerde" if valor >= int(_datos.minimo) else &"BarraCrema"


func _configurar_botones(paso: bool, n: int) -> void:
	boton_reintentar.pressed.connect(func() -> void:
		EstadoJuego.nivel_actual = n
		Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL))
	boton_menu.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.MENU))

	var hay_siguiente := n < EstadoJuego.NIVELES_JUGABLES
	if not paso:
		boton_siguiente.visible = false
		boton_reintentar.theme_type_variation = &"BotonPrimario"
		boton_reintentar.grab_focus()
		return
	if n >= EstadoJuego.TOTAL_NIVELES or not hay_siguiente:
		# Último día jugable: si el oro ahorrado alcanza, se repara el barco.
		if EstadoJuego.oro_total >= EstadoJuego.COSTO_REPARACION:
			boton_siguiente.text = "REPARAR EL BARCO"
			boton_siguiente.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.FINAL))
		else:
			boton_siguiente.visible = false
			detalles.text += "\nTe faltan %d oro para reparar el barco." % (EstadoJuego.COSTO_REPARACION - EstadoJuego.oro_total)
	else:
		boton_siguiente.text = "IR AL TALLER"
		boton_siguiente.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.TIENDA))
	if boton_siguiente.visible:
		boton_siguiente.grab_focus()
	else:
		boton_reintentar.grab_focus()
