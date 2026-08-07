extends "res://ui/menus/shop/shop_item.gd"

# Event bridge for Brotato's two lock input paths.
# Mouse activation reaches ShopItem through LockButton.toggled, while keyboard/gamepad
# select in BaseShop._input() calls change_lock_status() directly. Observing the mutation
# here catches both paths without polling every shop slot.

signal bo_lock_status_changed(button_pressed, shop_item)


func change_lock_status(button_pressed: bool) -> void:
	var was_locked = bool(locked)
	.change_lock_status(button_pressed)
	var is_locked = bool(locked)
	if is_locked != was_locked:
		emit_signal("bo_lock_status_changed", is_locked, self)
