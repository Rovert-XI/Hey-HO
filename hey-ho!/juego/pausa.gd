class_name MenuPausa
extends Control
## Menú de pausa del nivel.

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


func mostrar_menu() -> void:
	show()
	boton_continuar.grab_focus()
