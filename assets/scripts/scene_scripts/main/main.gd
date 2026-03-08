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
# #region @export variables #endregion
# #region regular variables #endregion
# #region @onready variables #endregion
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
func _ready() -> void: pass
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
			push_warning("Main.fast_replace_scene() -> Argument replaces (",replaces,") has value of null")
	else:
		push_error("Main.fast_replace_scene() -> Argument path (",path,") doesn't lead to PackedScene")
	
#endregion
#/# #region other private methods #endregion
#endregion
#endregion

# #region inner classes #endregion
