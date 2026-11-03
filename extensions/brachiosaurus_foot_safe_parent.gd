extends "res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus_foot/brachiosaurus_foot.gd"

const OWNER_META = "brotato_online_brachiosaurus_owner"

func _online_refresh_brachiosaurus_owner() -> bool:
	var scene = get_tree().current_scene if is_inside_tree() else null
	if is_instance_valid(scene) and scene.has_meta(OWNER_META):
		var pending = scene.get_meta(OWNER_META)
		if not is_instance_valid(pending) or pending.is_queued_for_deletion() or pending.dead:
			return false
		var previous = get_meta(OWNER_META) if has_meta(OWNER_META) else null
		if is_instance_valid(previous) and previous != pending:
			for event in ["died", "tree_exiting"]:
				if previous.is_connected(event, self, "_on_online_brachiosaurus_lost"):
					previous.disconnect(event, self, "_on_online_brachiosaurus_lost")
		dino_mom = pending
		set_meta(OWNER_META, pending)
		if not pending.is_connected("died", self, "_on_online_brachiosaurus_lost"):
			pending.connect("died", self, "_on_online_brachiosaurus_lost")
		if not pending.is_connected("tree_exiting", self, "_on_online_brachiosaurus_lost"):
			pending.connect("tree_exiting", self, "_on_online_brachiosaurus_lost")
	elif has_meta(OWNER_META):
		dino_mom = get_meta(OWNER_META)
	return is_instance_valid(dino_mom) and not dino_mom.is_queued_for_deletion() and not dino_mom.dead

func shoot() -> void:
	# Vanilla _ready() calls shoot() before its next parent dereference.
	# The replica spawner supplies the exact owner synchronously, before add_child().
	if _online_refresh_brachiosaurus_owner():
		set_physics_process(true)
		.shoot()

func respawn() -> void:
	if _online_refresh_brachiosaurus_owner():
		.respawn()

func hide_parent() -> void:
	if _online_refresh_brachiosaurus_owner():
		.hide_parent()

func take_damage(value: int, args: TakeDamageArgs) -> Array:
	if not _online_refresh_brachiosaurus_owner():
		return [0, 0, false]
	return .take_damage(value, args)

func _on_online_brachiosaurus_lost(_entity = null, _args = null) -> void:
	# Freeze before the owner's native pointers become stale. Godot 3 lifecycle
	# callbacks run through the inheritance chain, so an override cannot guard its base.
	hide()
	_hitbox.disable()
	_hurtbox.disable()
	_collision.set_deferred("disabled", true)
	set_physics_process(false)
