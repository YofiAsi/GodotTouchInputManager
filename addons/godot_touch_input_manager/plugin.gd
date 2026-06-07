@tool
extends EditorPlugin
## Registers the GestureManager autoload and the settings-path project setting
## when the plugin is enabled, and tears the autoload down when disabled.

const AUTOLOAD_NAME := "GestureManager"
const AUTOLOAD_PATH := "res://addons/godot_touch_input_manager/gesture_manager.gd"
const SETTINGS_PATH_SETTING := "godot_touch_input_manager/settings_path"


func _enter_tree() -> void:
	# Guard against double-registration when project.godot already declares it.
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_register_settings_path()


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


## Adds a project setting so users can point the manager at a custom
## GestureSettings resource without writing code. Left in place on disable.
func _register_settings_path() -> void:
	if ProjectSettings.has_setting(SETTINGS_PATH_SETTING):
		return
	ProjectSettings.set_setting(SETTINGS_PATH_SETTING, "")
	ProjectSettings.set_initial_value(SETTINGS_PATH_SETTING, "")
	ProjectSettings.add_property_info({
		"name": SETTINGS_PATH_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	})
	ProjectSettings.save()
