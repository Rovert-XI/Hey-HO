extends Control
## Opciones: volumen general, pantalla completa, pistas de teclas y borrar progreso.

@onready var slider_volumen: HSlider = %SliderVolumen
@onready var valor_volumen: Label = %ValorVolumen
@onready var check_pantalla: CheckButton = %CheckPantalla
@onready var check_pistas: CheckButton = %CheckPistas
@onready var boton_borrar: Button = %BotonBorrar
@onready var boton_volver: Button = %BotonVolver

var _confirmando := false


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	slider_volumen.value = EstadoJuego.volumen
	check_pantalla.button_pressed = EstadoJuego.pantalla_completa
	check_pistas.button_pressed = EstadoJuego.pistas_teclas
	_mostrar_volumen()

	slider_volumen.value_changed.connect(_volumen_cambio)
	check_pantalla.toggled.connect(_pantalla_cambio)
	check_pistas.toggled.connect(_pistas_cambio)
	boton_borrar.pressed.connect(_borrar)
	boton_volver.pressed.connect(_volver)
	slider_volumen.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_volver()


func _volumen_cambio(valor: float) -> void:
	EstadoJuego.volumen = valor
	EstadoJuego.aplicar_ajustes()
	_mostrar_volumen()


func _mostrar_volumen() -> void:
	valor_volumen.text = "%d %%" % roundi(slider_volumen.value * 100.0)


func _pantalla_cambio(activo: bool) -> void:
	EstadoJuego.pantalla_completa = activo
	EstadoJuego.aplicar_ajustes()


func _pistas_cambio(activo: bool) -> void:
	EstadoJuego.pistas_teclas = activo


## Borrar progreso pide un segundo clic para evitar accidentes.
func _borrar() -> void:
	if not _confirmando:
		_confirmando = true
		boton_borrar.text = "¿SEGURO? PULSA DE NUEVO"
		get_tree().create_timer(3.0).timeout.connect(_cancelar_confirmacion)
		return
	EstadoJuego.borrar_progreso()
	_cancelar_confirmacion()
	boton_borrar.text = "PROGRESO BORRADO"


func _cancelar_confirmacion() -> void:
	if not _confirmando:
		return
	_confirmando = false
	boton_borrar.text = "BORRAR PROGRESO"


func _volver() -> void:
	EstadoJuego.guardar()
	Navegador.ir_a(self, Navegador.MENU)
