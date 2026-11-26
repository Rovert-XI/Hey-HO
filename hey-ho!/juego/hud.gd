extends Control
## Script auxiliar del HUD compacto (nodo "Raiz").
## No toca la lógica de hud.gd: solo atenúa la barra inferior (carga + inventario)
## cuando el jugador lleva unos segundos sin pulsar nada, para que no tape
## la isla/balsa en la vista 2.5D. Al pulsar cualquier tecla o botón vuelve a 100 %.

@export var segundos_inactividad: float = 3.0
@export_range(0.0, 1.0, 0.05) var opacidad_reposo: float = 0.5
@export var duracion_fade: float = 0.35

var _tiempo: float = 0.0
var _en_reposo: bool = false
var _tween: Tween

@onready var _inferior: Control = get_node_or_null("Inferior") as Control


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		_tiempo = 0.0
		if _en_reposo:
			_en_reposo = false
			_fundir(1.0)


func _process(delta: float) -> void:
	if _inferior == null or _en_reposo:
		return
	_tiempo += delta
	if _tiempo >= segundos_inactividad:
		_en_reposo = true
		_fundir(opacidad_reposo)


func _fundir(alfa: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_inferior, "modulate:a", alfa, duracion_fade)
