extends Control
## Menú principal: JUGAR / ELEGIR DÍA / OPCIONES / CRÉDITOS / SALIR.
## Teclado y mando: el primer botón toma el foco; flechas arriba/abajo y Enter.

@onready var boton_jugar: Button = %BotonJugar
@onready var boton_niveles: Button = %BotonNiveles
@onready var boton_opciones: Button = %BotonOpciones
@onready var boton_creditos: Button = %BotonCreditos
@onready var boton_salir: Button = %BotonSalir
@onready var titulo: Label = %Titulo


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	var hay_progreso := EstadoJuego.nivel_max_desbloqueado > 1 or EstadoJuego.oro_total > 0
	if hay_progreso:
		boton_jugar.text = "CONTINUAR · DÍA %d" % EstadoJuego.nivel_max_desbloqueado

	boton_jugar.pressed.connect(_jugar)
	boton_niveles.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.NIVELES))
	boton_opciones.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.OPCIONES))
	boton_creditos.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.CREDITOS))
	boton_salir.pressed.connect(func() -> void: Navegador.salir(self))
	boton_jugar.grab_focus()
	_entrada_animada()


func _jugar() -> void:
	EstadoJuego.nivel_actual = mini(EstadoJuego.nivel_max_desbloqueado, EstadoJuego.NIVELES_JUGABLES)
	Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL)


func _entrada_animada() -> void:
	titulo.modulate.a = 0.0
	create_tween().tween_property(titulo, "modulate:a", 1.0, 0.5)
	var botones: Array[Button] = [boton_jugar, boton_niveles, boton_opciones, boton_creditos, boton_salir]
	for i in botones.size():
		botones[i].modulate.a = 0.0
		create_tween().tween_property(botones[i], "modulate:a", 1.0, 0.35).set_delay(0.2 + i * 0.08)
