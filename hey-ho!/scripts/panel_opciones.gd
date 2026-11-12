# Panel de opciones del menu: dos deslizadores de volumen que se guardan en disco.
# Requiere dos buses de audio llamados 'Musica' y 'Efectos' (pestana Audio del editor).
class_name PanelOpciones
extends PanelContainer

signal cerrado

const ARCHIVO: String = 'user://ajustes.cfg'
const VOLUMEN_INICIAL: float = 0.8

@export var slider_musica: HSlider
@export var slider_efectos: HSlider
@export var boton_cerrar: Button

# Volumen lineal (0 a 1) -> decibelios. 1.0 -> 0 dB; 0.5 -> -6,02 dB; 0 -> -80 dB
static func lineal_a_db(lineal: float) -> float:
	return linear_to_db(maxf(lineal, 0.0001))

func _ready() -> void:
	_configurar(slider_musica)
	_configurar(slider_efectos)
	_cargar()
	slider_musica.value_changed.connect(func(v: float) -> void: _aplicar('Musica', v))
	slider_efectos.value_changed.connect(func(v: float) -> void: _aplicar('Efectos', v))
	boton_cerrar.pressed.connect(cerrar)

func abrir() -> void:
	visible = true
	slider_musica.grab_focus()

func cerrar() -> void:
	_guardar()
	visible = false
	cerrado.emit()

func _configurar(slider: HSlider) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05

func _aplicar(bus: String, lineal: float) -> void:
	var indice: int = AudioServer.get_bus_index(bus)
	if indice < 0:
		return
	AudioServer.set_bus_volume_db(indice, lineal_a_db(lineal))
	AudioServer.set_bus_mute(indice, lineal <= 0.0)

func _cargar() -> void:
	var cfg := ConfigFile.new()
	var musica: float = VOLUMEN_INICIAL
	var efectos: float = VOLUMEN_INICIAL
	if cfg.load(ARCHIVO) == OK:
		musica = cfg.get_value('audio', 'musica', VOLUMEN_INICIAL)
		efectos = cfg.get_value('audio', 'efectos', VOLUMEN_INICIAL)
	slider_musica.set_value_no_signal(musica)
	slider_efectos.set_value_no_signal(efectos)
	_aplicar('Musica', musica)
	_aplicar('Efectos', efectos)

func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value('audio', 'musica', slider_musica.value)
	cfg.set_value('audio', 'efectos', slider_efectos.value)
	cfg.save(ARCHIVO)
