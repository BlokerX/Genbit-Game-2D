#region basic info
# #region class annotations #endregion
# #region class name #endregion
#region extends from class
extends Node
#endregion
#region doc description
## Main [Node] of the game.
##
## Main [Node] of the game, which is a parent to all non Autoload [Node]s are children of.
#endregion
#endregion

#region class members
# #region signals #endregion
# #region enums #endregion
# #region constants #endregion
# #region static variables #endregion
#region @export variables 
@export_group("Transition Defaults","transition_")
## Defines the [Color] of the transition.
@export_color_no_alpha var transition_color:Color = Color(0,0,0)
## Defines the duration of the transition's fade in and fade out animation.
@export_range(0.0,1.0,0.0005,"or_greater","suffix:s") var transition_anim_duration: float = 0.5
## Uses [enum Tween.TransitionType] to define interpolation function of the transition.
@export var transition_trans_type:Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR
## Uses [enum Tween.EaseType] to define easing interpolation of the transition.
@export var transition_ease_type:Tween.EaseType = Tween.EaseType.EASE_IN
#endregion
# #region regular variables #endregion
#region @onready variables 
@onready var node_background = $Background
#endregion
#endregion

#region class methods
# #region _static_init() #endregion
# #region static methods
#/# #region public static methods #endregion
#/# #region private static methods #endregion
# #endregion
#region overriden virtual methods
#/# #region _init() #endregion
#/# #region _enter_tree() #endregion
#region _ready() 
func _ready() -> void: 
	transition_replace_scene("uid://bvu5h2wtjx3jk",node_background)
#endregion
#/# #region _process() #endregion
#/# #region _physics_process() #endregion
#/# #region remaining virtual methods #endregion
#endregion
# #region overriden custom methods
#/# #region overriden public methods #endregion
#/# #region overriden private methods #endregion
# #endregion
#region other methods
#region other public methods 
## @experimental: This method uses main thread for loading [PackedScene], which could result in lower framerate or game freezes. Do not use this method for loading complex scenes. Additionally, this method doesn't hide the background of Main scene before the added scene is fully loaded.
## Loads [PackedScene] from [param path] and places it as child of this node.[br]
## [br]
## Parameters:[br]
## [param path] - [String] path to the [PackedScene].
func fast_add_scene(path:String) -> void :
	if ResourceLoader.exists(path,"PackedScene"):
		var packed_scene:PackedScene = SceneCollectionManager.get_packed_scene(path)
		self.add_child(packed_scene.instantiate())
	else:
		push_error("Main.fast_add_scene() -> Argument path (",path,") doesn't lead to PackedScene")

## @experimental: This method uses main thread for loading [PackedScene], which could result in lower framerate or game freezes. Do not use this method for loading complex scenes. Additionally, this method doesn't hide the background of Main scene if this method was called to replace the only single child of Main.
## Loads [PackedScene] from [param path], places it as child of this node and then queues [param replaces] to be removed.[br]
## [br]
## Parameters:[br]
## [param path] - [String] path to the [PackedScene].[br]
## [param replaces] - [Node] that will be affected by [method Node.queue_free].
func fast_replace_scene(path:String,replaces:Node) -> void :
	if ResourceLoader.exists(path,"PackedScene"):
		var packed_scene:PackedScene = SceneCollectionManager.get_packed_scene(path)
		self.add_child(packed_scene.instantiate())
		if replaces != null:
			replaces.queue_free()
		else:
			push_warning("Main.fast_replace_scene() -> Argument replaces (",replaces,") is null")
	else:
		push_error("Main.fast_replace_scene() -> Argument path (",path,") doesn't lead to PackedScene")

func transition_add_scene(path:String) -> void:
	if ResourceLoader.exists(path,"PackedScene"): 
		# Init Curtain
		var curtain:Curtain = Curtain.new(transition_color,transition_anim_duration,transition_trans_type,transition_ease_type)
		add_child(curtain)
		
		# Preparing Curtain for transition
		curtain.prepare_transition()
		
		# Curtain fade in anim
		curtain.fade_in()
		await curtain.fade_in_finished
		
		# Adding scene to SceneTree
		var packed_scene:PackedScene = await SceneCollectionManager.get_packed_scene_deferred(path)
		self.add_child(packed_scene.instantiate())
		
		# Curtain fade out anim
		curtain.fade_out()
		await curtain.fade_out_finished
		
		# Removing Curtain
		curtain.queue_free()
	else:
		push_error("Main.transition_add_scene() -> Argument path (",path,") doesn't lead to PackedScene")

func transition_replace_scene(path:String, replaces:Node) -> void:
	if ResourceLoader.exists(path,"PackedScene"): 
		# Init Curtain
		var curtain:Curtain = Curtain.new(transition_color,transition_anim_duration,transition_trans_type,transition_ease_type)
		add_child(curtain)
		
		# Preparing Curtain for transition
		curtain.prepare_transition()
		
		# Curtain fade in anim
		curtain.fade_in()
		await curtain.fade_in_finished
		
		# Adding scene to SceneTree
		var packed_scene:PackedScene = await SceneCollectionManager.get_packed_scene_deferred(path)
		self.add_child(packed_scene.instantiate())
		if replaces != null:
			replaces.queue_free()
		else:
			push_warning("Main.transition_replace_scene() -> Argument replaces (",replaces,") is null")
		
		# Curtain fade out anim
		curtain.fade_out()
		await curtain.fade_out_finished
		
		# Removing Curtain
		curtain.queue_free()
	else:
		push_error("Main.transition_add_scene() -> Argument path (",path,") doesn't lead to PackedScene")
#endregion
#region other private methods 

#endregion
#endregion
#endregion

#region inner classes 
class Curtain extends ColorRect:
	## An [ColorRect] specialized in hiding scene addition/swapping.
	##
	## An [ColorRect] specialized in hiding scene addition/swapping.
	
	## Emits when [method fade_in] finishes.
	signal fade_in_finished
	## Emits when [method fade_out] finishes.
	signal fade_out_finished
	
	## Duration of fade in and fade out animations.
	var duration_per_anim:float = 0.5
	
	## An [enum Twenn.TransitionType] used for interpolation function of animations.
	var trans_type:Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR
	
	## An [enum Twenn.EaseType] used for easing interpolation of animations.
	var ease_type:Tween.EaseType = Tween.EaseType.EASE_IN
	
	func _init(new_color:Color=Color(0,0,0,1), new_anim_duration:float=0.5, new_trans:Tween.TransitionType=Tween.TRANS_LINEAR, new_ease:Tween.EaseType=Tween.EASE_IN) -> void:
		name = "Curtain"
		color = new_color
		trans_type = new_trans
		ease_type = new_ease
		duration_per_anim = new_anim_duration
	
	## Set ups [ColorRect]
	func prepare_transition() -> void:
		color = Color(color,0)
		z_index = 100
		set_anchors_preset(Control.PRESET_FULL_RECT)
	
	## Initiates fade in animation.
	func fade_in() -> void:
		var tween = get_tree().create_tween()
		tween.set_trans(trans_type).set_ease(ease_type)
		tween.tween_property(self,"color",Color(color,1),duration_per_anim)
		await tween.finished
		fade_in_finished.emit()
	
	## Initiates fade out animation.
	func fade_out() -> void:
		var tween = get_tree().create_tween()
		tween.set_trans(trans_type).set_ease(ease_type)
		tween.tween_property(self,"color",Color(color,0),duration_per_anim)
		await tween.finished
		fade_out_finished.emit()
#endregion
