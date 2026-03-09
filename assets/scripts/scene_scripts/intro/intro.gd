#region basic info
#/# #region class annotations #endregion
#/# #region class name #endregion
#region extends from class 
extends Control
#endregion
#/# #region doc description #endregion
#endregion

#region class members
#/# #region signals #endregion
#/# #region enums #endregion
#region constants
## [LabelSettings] used by [member waitb_label], [member blok_label] and [member abez_label] [Label]s.
const LABEL_SETTINGS_GAME_CREATORS:LabelSettings = preload("uid://xrdh07m44hh5")
## [LabelSettings] used by [member game_title_label] [Label].
const LABEL_SETTINGS_GAME_TITLE:LabelSettings = preload("uid://b24rx1uypyr6y")
## [LabelSettings] used by [member presents_label] [Label].
const LABEL_SETTINGS_PRESENTS:LabelSettings = preload("uid://bg10yf8jf0lue")
#endregion
#/# #region static variables #endregion
#/# #region @export variables #endregion
#region regular variables 
var vbox:VBoxContainer
var hbox:HBoxContainer
var waitb_label:Label
var blok_label:Label
var abez_label:Label
var presents_label:Label
var game_title_label:Label
var tween:Tween
#endregion
#/# #region @onready variables #endregion
#endregion

#region class methods
#/# #region _static_init() #endregion
#/# #region static methods
#/#/# #region public static methods #endregion
#/#/# #region private static methods #endregion
#/# #endregion
#/# #region overriden virtual methods
#/#/# #region _init() #endregion
#/#/# #region _enter_tree() #endregion
#region _ready() 
func _ready() -> void:
	_init_intro()
	_start_intro()
#endregion
#/#/# #region _process() #endregion
#/#/# #region _physics_process() #endregion
#region remaining virtual methods 
func _unhandled_key_input(event: InputEvent) -> void:
	if Input.is_anything_pressed():
		if tween.custom_step(5) == true:
			tween.kill()
		_end_intro()
#endregion
#/# #endregion
#/# #region overriden custom methods
#/#/# #region overriden public methods #endregion
#/#/# #region overriden private methods #endregion
#/# #endregion
#region other methods
#/#/# #region other public methods #endregion
#region other private methods 
func _init_intro() -> void : 
	# Vertical Box Container
	vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	
	# Horizontal Box Container
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation",16)
	
	# Waitb text
	waitb_label = Label.new()
	waitb_label.text = tr("INTRO_WAITB")
	waitb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waitb_label.label_settings = LABEL_SETTINGS_GAME_CREATORS
	
	# Blocker text
	blok_label = Label.new()
	blok_label.text = tr("INTRO_BLOKER")
	blok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blok_label.label_settings = LABEL_SETTINGS_GAME_CREATORS
	
	# Abez text
	abez_label = Label.new()
	abez_label.text = tr("INTRO_ABEZ")
	abez_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abez_label.label_settings = LABEL_SETTINGS_GAME_CREATORS
	
	# "Presents" text
	presents_label = Label.new()
	presents_label.text = tr_n("INTRO_PRESENT","INTRO_PRESENTS",2)
	presents_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents_label.label_settings = LABEL_SETTINGS_PRESENTS
	
	# Game Title text
	game_title_label = Label.new()
	game_title_label.text = ProjectSettings.get_setting("application/config/name","String")
	game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title_label.label_settings = LABEL_SETTINGS_GAME_TITLE
	
	# Adding person labels to hbox
	hbox.add_child(waitb_label)
	hbox.add_child(blok_label)
	hbox.add_child(abez_label)
	
	# Adding "Presents" label and hbox to vbox
	vbox.add_child(hbox)
	vbox.add_child(presents_label)
	vbox.add_child(game_title_label)
	
	# Changing opacity of hbox
	hbox.modulate = Color(1,1,1,0)
	
	# Changing opacity of "Presents" label
	presents_label.modulate = Color(1,1,1,0)
	
	# Changing opacity of Game Title label
	game_title_label.modulate = Color(1,1,1,0)
	
	# Adding vbox as child of scene
	self.add_child(vbox)

func _start_intro() -> void :
	tween = get_tree().create_tween()
	tween.tween_property(hbox,"modulate",Color(1,1,1,1),1)
	tween.tween_property(presents_label,"modulate",Color(1,1,1,1),1)
	tween.tween_property(game_title_label,"modulate",Color(1,1,1,1),1)
	await tween.finished
	_end_intro()

func _end_intro() -> void:
	#TODO: Code to call a method that will start scene transition to main menu scene
	pass
#endregion
#endregion
#endregion

# #region inner classes #endregion
