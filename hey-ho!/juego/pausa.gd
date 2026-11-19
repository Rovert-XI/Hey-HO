extends Control
## Menú de pausa. Lo abre y cierra el HUD con Esc; aquí solo se emiten señales.

signal continuar
signal reiniciar
signal volver_al_menu

@onready var boton_continuar: Button = %BotonContinuar
@onready var boton_reiniciar: Button = %BotonReiniciar
@onready var boton_menu: Button = %BotonMenu


func _ready() -> void:
	boton_continuar.pressed.connect(func() -> void: continuar.emit())
	boton_reiniciar.pressed.connect(func() -> void: reiniciar.emit())
	boton_menu.pressed.connect(func() -> void: volver_al_menu.emit())
	boton_continuar.grab_focus()
