extends Reference

# Callback ownership can change after Steam initialization. Query SceneTree on
# every callback polling cycle so automatic and manual drivers never overlap.


func should_run_manual(tree, steam) -> bool:
	if tree == null or steam == null or not tree.has_method("is_connected"):
		return true
	if steam.has_method("run_callbacks") and tree.is_connected("idle_frame", steam, "run_callbacks"):
		return false
	if steam.has_method("runCallbacks") and tree.is_connected("idle_frame", steam, "runCallbacks"):
		return false
	return true
