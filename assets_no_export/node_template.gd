#region basic info
#region class annotations
#@tool, @icon, @static_unload, @abstract...
#endregion
#region class name
class_name CustomNodeExample
#endregion
#region extends from class
extends Node
#endregion
#region doc description
## Short doc class desc
##
## Long doc class desc
#endregion
#endregion

#region class members
#region signals
## signal doc desc
signal your_signal_name
#endregion
#region enums
## enum doc desc
enum EnumName { 
	## enum member doc desc
	ENUM_MEMBER_NAME, 
	}
#endregion
#region constants
## const doc desc
const SUPER_HOT = true
#endregion
#region static variables
## static var doc desc
static var static_var = 20
#endregion
#region @export variables
## export var doc desc
@export var export_variable = true
#endregion
#region regular variables
## regular var doc desc
var regular = "variable"
#endregion
#region @onready variables
## @onready var doc desc
@onready var node = "node_path"
#endregion
#endregion

#region class methods
#region _static_init()
## _static_init method doc desc
static func _static_init() -> void: pass
#endregion
#region static methods
#region public static methods
## static public method doc desc
static func static_public_func() -> void: pass
#endregion
#region private static methods
## static private method doc desc
static func _static_private_func() -> void: pass
#endregion
#endregion
#region overriden virtual methods
#region _init()
## _init method doc desc
func _init() -> void: pass
#endregion
#region _enter_tree()
## _enter_tree method doc desc
func _enter_tree() -> void : pass
#endregion
#region _ready()
## _ready method doc desc
func _ready() -> void:pass
#endregion
#region _process()
## _process method doc desc
func _process(delta: float) -> void: pass
#endregion
#region _physics_process()
## _physics_process method doc desc
func _physics_process(delta: float) -> void: pass
#endregion
#region remaining virtual methods
## _exit_tree method doc desc (example of remaining virutal methods)
func _exit_tree() -> void: pass
#endregion
#endregion
#region overriden custom methods
#region overriden public methods
## overridable_public_function method desc
func overridable_public_function() -> void: pass
#endregion
#region overriden private methods
## _overridable_private_function method desc
func _overridable_private_function() -> void: pass
#endregion
#endregion
#region other methods
#region other public methods
## public_method method desc
func public_method() -> void: pass
#endregion
#region other private methods
## _private_method method desc
func _private_method() -> void: pass
#endregion
#endregion
#endregion

#region inner classes
## InnerClass doc desc
class InnerClass:
	## InnerClass's var doc desc 
	var inner_var = 1
	## InnerClass's _init method doc desc
	func _init() -> void: # _init() of InnerClass
		print("InnerClass initialized")
#endregion
