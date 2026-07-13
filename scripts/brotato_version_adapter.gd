extends Node

# Caches stable method/signal capability checks for long-lived runtime objects
# such as the GodotSteam singleton. Dynamic scene-node compatibility checks stay
# local because their scripts and lifetimes can change between scenes.

var _method_cache_by_instance = {}
var _signal_cache_by_instance = {}


func has_method_cached(target, method_name: String) -> bool:
	if target == null or not is_instance_valid(target) or method_name == "":
		return false
	var key = str(target.get_instance_id())
	if not _method_cache_by_instance.has(key):
		_method_cache_by_instance[key] = {}
	var cache = _method_cache_by_instance[key]
	if not cache.has(method_name):
		cache[method_name] = target.has_method(method_name)
	return bool(cache[method_name])


func has_signal_cached(target, signal_name: String) -> bool:
	if target == null or not is_instance_valid(target) or signal_name == "":
		return false
	var key = str(target.get_instance_id())
	if not _signal_cache_by_instance.has(key):
		_signal_cache_by_instance[key] = {}
	var cache = _signal_cache_by_instance[key]
	if not cache.has(signal_name):
		cache[signal_name] = target.has_signal(signal_name)
	return bool(cache[signal_name])


func clear_object(target) -> void:
	if target == null or not is_instance_valid(target):
		return
	var key = str(target.get_instance_id())
	_method_cache_by_instance.erase(key)
	_signal_cache_by_instance.erase(key)
