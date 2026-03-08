#region basic info
# #region class annotations #endregion
#region extends from class
extends Node
#endregion
#region doc description
## Autoload for loading [PackedScene] files. 
## 
## Autoload for loading [PackedScene] files, which additionally allows for checking the progress of the loading with referenced [Array] and placing instanced [PackedScene] as a child of specified [Node].
#endregion
#endregion



#region class members
#region signals
## Emitted when [method _collect] sucessfully returns [PackedScene] at [param from] path.
signal packed_scene_collected(from:String)

## Emitted when [PackedScene] found at [param from] is sucessfully returned by [method get_packed_scene] or [method get_packed_scene_deferred] where [param by_deferred_method] specifies if the signal was emitted as result of deferred method.
signal packed_scene_returned(from:String, by_deferred_method:bool)
#endregion
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
# #region overriden virtual methods
#/# #region _init() #endregion
#/# #region _enter_tree() #endregion
#/# #region _ready() #endregion
#/# #region _process() #endregion
#/# #region _physics_process() #endregion
#/# #region remaining virtual methods #endregion
# #endregion
# #region overriden custom methods
#/# #region overriden public methods #endregion
#/# #region overriden private methods #endregion
# #endregion
#region other methods
#region other public methods 
## @experimental: This method uses non deferred loading method of [ResourceLoader], which could cause performance reductions or game freezing when loading more complex scenes. Use [method get_packed_deferred] for heavier and more complex scenes.
## Returns [PackedScene] with usage of [method ResourceLoader.load].[br]
## [br]
## Parameters:[br]
## [param path] - [String] path to the [PackedScene].[br]
## [br]
## Returns:[br]
## [PackedScene] - If method finishes sucessfully.[br]
## [code]null[/code] - If method fails to complete sucessfully.[br]
## [br]
## Emits:[br]
## [signal packed_scene_returned] - If method finishes sucessfully.
func get_packed_scene(path:String) -> PackedScene :
	if !ResourceLoader.exists(path,"PackedScene"):
		push_error("SceneManager.get_packed_scene() -> Parameter(path) doesn't lead to PackedScene")
		return null
	var packed_scene:PackedScene = ResourceLoader.load(path,"PackedScene")
	if packed_scene == null:
		push_error("SceneManager.get_packed_scene() -> ResourceLoader.load() returned null")
		return null
	packed_scene_returned.emit(path,false)
	return packed_scene

## Returns [PackedScene] with usage of [method ResourceLoader.load_threaded_get].[br]
## [br]
## Parameters:[br]
## [param path] - [String] path to the [PackedScene].[br]
## [param progress_collector] - [Array] reference that will store [float] representing progress of loading the desired [PackedScene]. Default: [ ][br]
## [br]
## Returns:[br]
## [PackedScene] - If method finishes sucessfully.[br]
## [code]null[/code] - If method fails to complete sucessfully.[br]
## [br]
## Emits:[br]
## [signal packed_scene_returned] - If method finishes sucessfully.
func get_packed_scene_deferred(path:String, progress_collector:Array=[]) -> PackedScene :
	if !ResourceLoader.exists(path,"PackedScene"):
		push_error("SceneManager.get_packed_scene_deferred() -> Parameter(path) doesn't lead to PackedScene")
		return null
	var request = ResourceLoader.load_threaded_request(path,"PackedScene")
	if request != OK:
		push_error("SceneManager.get_packed_scene_deferred() -> ResourceLoader.load_threaded_request() failed")
		return null
	var packed_scene:PackedScene = await _collect(path, progress_collector)
	if packed_scene == null:
		push_error("SceneManager.get_packed_scene_deferred() -> SceneManager._collect() returned null")
		return null
	packed_scene_returned.emit(path,true)
	return packed_scene
#endregion
#region other private methods 
## @experimental: This is a private method, which only checks progress or collects ready to collect [PackedScene]. Calling this method without calling [method ResourceLoader.load_threaded_request] may cause major logic problems or software crash.
## Tries to collect [PackedScene] with usage of [method ResourceLoader.load_threaded_get] when it's loading finishes.[br]
## [br]
## Parameters:[br]
## [param path] - [String] path to the [PackedScene].[br]
## [param progress_collector] - [Array] reference that will store [float] representing progress of loading the desired [PackedScene]. Default: [ ][br]
## [br]
## Returns:[br]
## [PackedScene] - If method finishes sucessfully.[br]
## [code]null[/code] - If method fails to complete sucessfully.[br]
func _collect(path:String, progress_collector:Array=[]) -> PackedScene:
	while true:
		var check = ResourceLoader.load_threaded_get_status(path,progress_collector)
		match check:
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
				packed_scene_collected.emit(path)
				return ResourceLoader.load_threaded_get(path)
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
				push_error("SceneManger._collect() -> Deffered loading of \"",path,"\" returned invalid resource")
				return null
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
				push_error("SceneManger._collect() -> Deffered loading of \"",path,"\" failed")
				return null
		await get_tree().create_timer(0.0002).timeout
	return null
#endregion
#endregion
#endregion

# #region inner classes #endregion
