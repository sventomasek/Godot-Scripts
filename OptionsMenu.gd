## Need to install the PlayerPrefs plugin from the AssetLib!

extends Control

@export var masterSlider: Slider
const masterPref = "MasterVolume"
@onready var masterBus = AudioServer.get_bus_index("Master")

@export var godotSprite: TextureRect
@export var godotSpriteButton: OptionButton
const godotSpritePref = "GodotSprite"

func _ready():
	load_prefs()
	
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): visible = !visible
	
func load_prefs():
	_on_master_slider_value_changed(PlayerPrefs.get_pref(masterPref, 0.5))
	_on_godot_button_item_selected(PlayerPrefs.get_pref(godotSpritePref, 0))
	
func _on_master_slider_value_changed(value):
	AudioServer.set_bus_volume_db(masterBus, linear_to_db(value))
	masterSlider.value = value
	PlayerPrefs.set_pref(masterPref, value)
	
func _on_godot_button_item_selected(index):
	match index:
		0: godotSprite.visible = false
		1: godotSprite.visible = true
		
	godotSpriteButton.selected = index
	PlayerPrefs.set_pref(godotSpritePref, index)
