# Brotato Online API — Quick Reference

Brotato Online provides a simple API that allows other mods to detect the current multiplayer state, determine host authority, and send custom network messages.

---

## Accessing the API

Brotato Online provides a node named:

```gdscript
BrotatoOnlineAPI
```

The node is added to the following group:

```gdscript
"brotato_online_api"
```

Retrieve the API node from your mod as follows:

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
```

If `bo_api == null`, Brotato Online is not enabled. Your mod should continue using its normal offline behavior.

---

## Basic State API

```gdscript
func get_api_version() -> int

func is_online() -> bool
func is_host() -> bool
func is_client() -> bool
func is_offline_or_host() -> bool
```

Descriptions:

```gdscript
is_online()          # Returns whether Brotato Online multiplayer is active
is_host()            # Returns whether this machine is the host
is_client()          # Returns whether this machine is a client
is_offline_or_host() # Returns true when offline or running as the host
```

---

## Phase API

```gdscript
func get_phase() -> String
```

Possible return values:

```gdscript
"offline"
"lobby"
"selection"
"shop"
"progression"
"battle"
"run_end"
"unknown"
```

| Phase           | Description                             |
| --------------- | --------------------------------------- |
| `"offline"`     | Offline mode                            |
| `"lobby"`       | Multiplayer lobby                       |
| `"selection"`   | Character or weapon selection           |
| `"shop"`        | Shop                                    |
| `"progression"` | Upgrade, crate, or consumable selection |
| `"battle"`      | Active combat                           |
| `"run_end"`     | End-of-run screen                       |
| `"unknown"`     | Unknown state                           |

---

## Context API

```gdscript
func get_context() -> Dictionary
```

Example return value:

```gdscript
{
    "api_version": 1,
    "online": true,
    "role": "host",
    "phase": "battle",
    "wave": 6,
    "local_player_indices": [0],
    "battle_id": 12
}
```

| Field                  | Description                                  |
| ---------------------- | -------------------------------------------- |
| `api_version`          | Current API version                          |
| `online`               | Whether Brotato Online multiplayer is active |
| `role`                 | `"offline"`, `"host"`, or `"client"`         |
| `phase`                | Current game phase                           |
| `wave`                 | Current wave number                          |
| `local_player_indices` | Player indices owned by the current machine  |
| `battle_id`            | Identifier for the current battle            |

`battle_id` prevents delayed network packets from a previous battle from affecting the current battle.

---

## Player Ownership API

```gdscript
func get_local_player_indices() -> Array
func owns_player(player_index: int) -> bool
```

Example:

```gdscript
if bo_api == null or bo_api.owns_player(player_index):
    show_local_ui(player_index)
```

`get_local_player_indices()` returns the player indices controlled by the current machine.

`owns_player(player_index)` returns whether the specified player belongs to the current machine.

---

## Authoritative Logic API

```gdscript
func should_run_authoritative_logic() -> bool
```

Returns `true` when running offline or as the host. Returns `false` when running as a client.

It is equivalent to:

```gdscript
return !is_online() or is_host()
```

Authoritative gameplay logic should use the following pattern:

```gdscript
if bo_api == null or bo_api.should_run_authoritative_logic():
    spawn_real_entity()
```

This prevents clients from independently executing logic that changes the authoritative game state.

---

## Local Visual API

```gdscript
func should_run_local_visual_only() -> bool
```

Returns `true` on multiplayer clients.

Use this function for effects, previews, animations, or other local presentation logic that should not affect the authoritative game state.

```gdscript
if bo_api != null and bo_api.should_run_local_visual_only():
    spawn_preview_effect()
```

---

## Network Sending API

The initial API version provides three message-sending methods.

### Send to the Host

```gdscript
func send_to_host(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

Sends a custom message from the current machine to the host.

### Send to a Player

```gdscript
func send_to_player(
    player_index: int,
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

Sends a custom message to the machine that owns the specified player index.

### Broadcast

```gdscript
func broadcast(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

Broadcasts a custom message to connected multiplayer participants.

---

## Message Options

Example:

```gdscript
{
    "scope": "battle",
    "reliable": true
}
```

| Field      | Allowed values         | Description                                |
| ---------- | ---------------------- | ------------------------------------------ |
| `scope`    | `"menu"` or `"battle"` | Defines the message scope                  |
| `reliable` | `true` or `false`      | Controls whether reliable delivery is used |

When `scope = "battle"`, Brotato Online automatically includes the current `battle_id`. Messages belonging to an older battle are discarded.

Use reliable delivery for important state changes, requests, confirmations, or messages that must not be lost.

Unreliable delivery may be used for frequent visual events where occasional packet loss is acceptable.

---

## Sending Examples

### Client to Host

```gdscript
bo_api.send_to_host(
    "my_mod",
    "request_spawn",
    {
        "position": position
    },
    {
        "scope": "battle",
        "reliable": true
    }
)
```

### Host Broadcast to Clients

```gdscript
bo_api.broadcast(
    "my_mod",
    "spawn_fx",
    {
        "position": position,
        "fx_id": "hit_flash"
    },
    {
        "scope": "battle",
        "reliable": false
    }
)
```

### Send to a Specific Player

```gdscript
bo_api.send_to_player(
    1,
    "my_mod",
    "show_hint",
    {
        "text": "Hello"
    },
    {
        "scope": "menu",
        "reliable": true
    }
)
```

---

## Signals

```gdscript
signal phase_changed(old_phase, new_phase, context)
signal slot_layout_changed(context)
signal mod_message_received(mod_id, route, payload, meta)
```

---

## Phase Change Signal

```gdscript
func _ready():
    if bo_api != null:
        bo_api.connect("phase_changed", self, "_on_phase_changed")

func _on_phase_changed(old_phase, new_phase, context):
    if new_phase == "battle":
        _prepare_battle()
    elif old_phase == "battle":
        _cleanup_battle()
```

The `phase_changed` signal is emitted when Brotato Online detects a transition between game phases.

The supplied `context` contains the current multiplayer and game-state information.

---

## Slot Layout Change Signal

```gdscript
func _ready():
    if bo_api != null:
        bo_api.connect("slot_layout_changed", self, "_on_slot_layout_changed")

func _on_slot_layout_changed(context):
    var local_players = context.get("local_player_indices", [])
```

The `slot_layout_changed` signal is emitted when player-slot ownership or layout changes.

This may occur when players join, leave, reconnect, or when local and remote player mappings are rebuilt.

---

## Receiving Network Messages

```gdscript
func _ready():
    if bo_api != null:
        bo_api.connect("mod_message_received", self, "_on_mod_message_received")

func _on_mod_message_received(mod_id, route, payload, meta):
    if mod_id != "my_mod":
        return

    if route == "spawn_fx":
        _spawn_fx(payload)
```

Always verify `mod_id` before handling a message. This prevents your mod from processing messages intended for another mod.

The `route` value should be used to distinguish between message types within your mod.

Example `meta` value:

```gdscript
{
    "from_player_index": 1,
    "from_role": "client",
    "scope": "battle"
}
```

| Field               | Description                                   |
| ------------------- | --------------------------------------------- |
| `from_player_index` | Player index associated with the sender       |
| `from_role`         | Sender role, such as `"host"` or `"client"`   |
| `scope`             | Message scope, such as `"menu"` or `"battle"` |

---

## Internal Network Packet Format

Third-party mods do not need to construct or process Brotato Online's internal packet format directly.

Brotato Online internally wraps custom messages in a structure similar to:

```gdscript
{
    "msg_type": "bo_mod_message",
    "api_version": 1,
    "mod_id": "some_mod",
    "route": "some_event",
    "scope": "battle",
    "battle_id": 12,
    "payload": {}
}
```

Third-party mods should use `send_to_host()`, `send_to_player()`, and `broadcast()` instead of sending this packet format directly.

---

## Complete API List

```gdscript
signal phase_changed(old_phase, new_phase, context)
signal slot_layout_changed(context)
signal mod_message_received(mod_id, route, payload, meta)

func get_api_version() -> int

func is_online() -> bool
func is_host() -> bool
func is_client() -> bool
func is_offline_or_host() -> bool

func get_phase() -> String
func get_context() -> Dictionary

func get_local_player_indices() -> Array
func owns_player(player_index: int) -> bool

func should_run_authoritative_logic() -> bool
func should_run_local_visual_only() -> bool

func send_to_host(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool

func send_to_player(
    player_index: int,
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool

func broadcast(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

---

## Minimal Integration Template

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
        bo_api.connect(
            "mod_message_received",
            self,
            "_on_mod_message_received"
        )

func spawn_something(position: Vector2):
    if bo_api == null or bo_api.should_run_authoritative_logic():
        spawn_real_entity(position)
    else:
        bo_api.send_to_host(
            "my_mod",
            "request_spawn",
            {"position": position},
            {"scope": "battle", "reliable": true}
        )

func _on_mod_message_received(mod_id, route, payload, meta):
    if mod_id != "my_mod":
        return

    if route == "spawn_fx":
        spawn_fx(payload)
```

In this example:

- Offline games and hosts execute the real spawn logic directly.

- Clients send a spawn request to the host.

- Custom messages belonging to other mods are ignored.

- The `"spawn_fx"` route is handled as a presentation event.
