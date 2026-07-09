# Brotato Online API 简版 README

Brotato Online 提供一个简单 API，供其他模组判断联机状态、主机权限，并发送自定义网络消息。

---

## 获取 API

Brotato Online 会提供一个节点：

```gdscript
BrotatoOnlineAPI
```

并加入 group：

```gdscript
"brotato_online_api"
```

模组中这样获取：

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
```

如果 `bo_api == null`，说明没有启用 Brotato Online，按普通离线逻辑运行。

---

## 基础状态接口

```gdscript
func get_api_version() -> int

func is_online() -> bool
func is_host() -> bool
func is_client() -> bool
func is_offline_or_host() -> bool
```

说明：

```gdscript
is_online()          # 是否处于 Brotato Online 联机状态
is_host()            # 当前是否是主机
is_client()          # 当前是否是客户端
is_offline_or_host() # 离线或主机时返回 true
```

---

## 阶段接口

```gdscript
func get_phase() -> String
```

可能返回：

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

说明：

| phase           | 含义              |
| --------------- | --------------- |
| `"offline"`     | 离线              |
| `"lobby"`       | 联机大厅            |
| `"selection"`   | 选人 / 选武器        |
| `"shop"`        | 商店              |
| `"progression"` | 升级 / 箱子 / 消耗品选择 |
| `"battle"`      | 战斗内             |
| `"run_end"`     | 本局结束            |
| `"unknown"`     | 未知状态            |

---

## 上下文接口

```gdscript
func get_context() -> Dictionary
```

返回示例：

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

字段说明：

| 字段                     | 含义                                  |
| ---------------------- | ----------------------------------- |
| `api_version`          | API 版本                              |
| `online`               | 是否联机                                |
| `role`                 | `"offline"` / `"host"` / `"client"` |
| `phase`                | 当前阶段                                |
| `wave`                 | 当前波次                                |
| `local_player_indices` | 当前机器拥有的玩家索引                         |
| `battle_id`            | 当前战斗编号                              |

`battle_id` 用于避免上一场战斗的旧网络包影响当前战斗。

---

## 玩家归属接口

```gdscript
func get_local_player_indices() -> Array
func owns_player(player_index: int) -> bool
```

示例：

```gdscript
if bo_api == null or bo_api.owns_player(player_index):
    show_local_ui(player_index)
```

---

## 权威逻辑接口

```gdscript
func should_run_authoritative_logic() -> bool
```

离线或主机返回 `true`，客户端返回 `false`。

等价于：

```gdscript
return !is_online() or is_host()
```

真实游戏逻辑应该这样写：

```gdscript
if bo_api == null or bo_api.should_run_authoritative_logic():
    spawn_real_entity()
```

---

## 本地视觉接口

```gdscript
func should_run_local_visual_only() -> bool
```

联机客户端返回 `true`，用于只播放本地视觉效果。

```gdscript
if bo_api != null and bo_api.should_run_local_visual_only():
    spawn_preview_effect()
```

---

## 网络发送接口

第一版只提供三个发送接口。

```gdscript
func send_to_host(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

```gdscript
func send_to_player(
    player_index: int,
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

```gdscript
func broadcast(
    mod_id: String,
    route: String,
    payload: Dictionary,
    options: Dictionary = {}
) -> bool
```

---

## options

```gdscript
{
    "scope": "battle",
    "reliable": true
}
```

字段：

| 字段         | 可选值                   | 说明     |
| ---------- | --------------------- | ------ |
| `scope`    | `"menu"` / `"battle"` | 消息作用域  |
| `reliable` | `true` / `false`      | 是否可靠发送 |

`scope = "battle"` 时，Brotato Online 会自动带上 `battle_id`，旧战斗消息会被丢弃。

---

## 发送示例

### 客户端发给主机

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

### 主机广播给客户端

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

### 发给指定玩家

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

## 事件

```gdscript
signal phase_changed(old_phase, new_phase, context)
signal slot_layout_changed(context)
signal mod_message_received(mod_id, route, payload, meta)
```

---

## 阶段变化事件

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

---

## 槽位变化事件

```gdscript
func _ready():
    if bo_api != null:
        bo_api.connect("slot_layout_changed", self, "_on_slot_layout_changed")

func _on_slot_layout_changed(context):
    var local_players = context.get("local_player_indices", [])
```

---

## 接收网络消息

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

`meta` 示例：

```gdscript
{
    "from_player_index": 1,
    "from_role": "client",
    "scope": "battle"
}
```

---

## 内部网络包格式

第三方模组不用处理内部格式。

Brotato Online 内部会统一封装为：

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

---

## 完整 API 列表

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

func send_to_host(mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool
func send_to_player(player_index: int, mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool
func broadcast(mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool
```

---

## 最小使用模板

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
        bo_api.connect("mod_message_received", self, "_on_mod_message_received")

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
