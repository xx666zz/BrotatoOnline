# Brotato Online

**简体中文** | [English](README.en.md)

Brotato Online 是一个为《Brotato》添加远程联机支持的模组。

该模组通过 Steam 大厅和网络同步，让玩家可以和 Steam 好友一起进行游戏。它会同步选人、选武器、菜单流程、战斗状态、玩家输入、部分战斗事件，并提供联机大厅、好友邀请、快捷聊天、本机角色描边等功能。

## 功能

- 支持 Steam 好友联机

- 同步角色选择、武器选择、难度、区域和游戏流程

- 同步战斗中的玩家输入、血量、敌人、掉落物和关键状态

- 支持继续游戏时创建或恢复联机大厅

- 支持快捷聊天轮盘

- 支持本机控制角色描边，方便区分自己控制的角色

- 提供简单 API，方便其他模组接入 Brotato Online 的联机状态和网络消息系统

## 安装

在 Steam 创意工坊中订阅。

## 基本同步模型

Brotato Online 使用 Host 权威模型。

通常情况下：

- Host 负责主要游戏流程、波次推进、关键战斗状态和最终结果；

- Client 负责本地输入、部分表现层预测和远程状态展示；

- 菜单阶段由 Host 广播当前选择、页面状态和运行配置；

- 战斗阶段通过快照、事件和必要的兼容补丁维持客户端状态；

- 第三方模组应避免在 Client 上直接执行会改变真实游戏结果的逻辑。

对于第三方模组，建议遵循以下原则：

```gdscript
if bo_api == null or bo_api.should_run_authoritative_logic():
    # 离线或 Host 执行真实逻辑
    run_real_gameplay_logic()
else:
    # Client 只执行本地表现、请求或 UI 逻辑
    run_client_visual_or_request_logic()
```

## 项目结构

```text
six666-BrotatoOnline/
├─ manifest.json
├─ mod_main.gd
├─ scripts/
│  ├─ steam_lobby_manager.gd
│  ├─ menu_sync_manager.gd
│  ├─ online_player_slot_manager.gd
│  ├─ online_input_manager.gd
│  ├─ battle_replica_manager.gd
│  ├─ state_snapshot.gd
│  ├─ net_id_registry.gd
│  ├─ runtime_locator.gd
│  ├─ online_mod_settings_manager.gd
│  ├─ quick_chat_wheel.gd
│  └─ brotato_online_api.gd
├─ extensions/
│  ├─ main_safe_pool_exit.gd
│  ├─ entity_spawner_online_player_count_guard.gd
│  ├─ player_local_outline.gd
│  ├─ player_safe_room_cleanup.gd
│  ├─ stats_manager_safe_queues.gd
│  └─ ...
└─ translations/
   ├─ brotato_online_en.txt
   └─ brotato_online_zh.txt
```

主要模块说明：

| 模块                               | 说明                                     |
| -------------------------------- | -------------------------------------- |
| `steam_lobby_manager.gd`         | Steam 大厅、P2P 消息、加入/邀请、Host/Client 状态管理 |
| `menu_sync_manager.gd`           | 选人、选武器、难度、商店、升级等菜单流程同步                 |
| `online_player_slot_manager.gd`  | 本地玩家、远程玩家占位、玩家索引和输入设备映射                |
| `online_input_manager.gd`        | 客户端输入采集和 Host 侧输入应用                    |
| `battle_replica_manager.gd`      | 战斗内实体、玩家、敌人、掉落物和表现事件同步                 |
| `state_snapshot.gd`              | 战斗状态快照构建和应用                            |
| `net_id_registry.gd`             | 运行时实体网络 ID 管理                          |
| `runtime_locator.gd`             | 查找当前游戏场景中的运行时节点                        |
| `online_mod_settings_manager.gd` | Brotato Online 设置项和本地显示选项              |
| `quick_chat_wheel.gd`            | 快捷聊天轮盘                                 |
| `brotato_online_api.gd`          | 对第三方模组暴露的简化 API                        |

`extensions/` 目录中的脚本主要用于修补原版逻辑在联机场景下的边界问题，例如对象提前释放、玩家数量不一致、客户端清理房间、延迟队列访问失效节点等。

## 开发者 API

Brotato Online 提供了一个简单 API，供其他模组判断当前是否处于联机状态、当前机器是否为主机、某个玩家是否归属于本机，以及发送自定义网络消息。

完整 API 文档见：

```text
docs/API.md
```

最小使用方式：

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
```

如果 `bo_api == null`，说明 Brotato Online 没有启用，其他模组应按普通离线逻辑运行。

## 网络消息建议

第三方模组通过 Brotato Online API 发送消息时，建议遵守以下约定：

- `mod_id` 使用稳定且唯一的字符串，例如 `"author_mod_name"`；

- `route` 使用短字符串区分消息类型，例如 `"request_spawn"`、`"sync_state"`、`"play_fx"`；

- `payload` 只放必要数据，避免发送大型对象、节点引用或不可序列化内容；

- 战斗内消息使用 `scope = "battle"`；

- 菜单或设置同步使用 `scope = "menu"`；

- 关键状态使用可靠发送；

- 高频表现事件可以使用非可靠发送。

不要依赖其他模组直接访问 Brotato Online 的内部 manager 节点。优先使用 `BrotatoOnlineAPI` 暴露的接口。

## 兼容性

- 游戏版本：Brotato 1.1.15.4

- ModLoader：6.2.0

- 联机方式：Steam

## 兼容性说明

Brotato Online 对原版流程做了较多运行时扩展，因此与其他模组的兼容性取决于它们修改的范围。

## 文档

- [`README.md`](README.md)：项目说明、开发者接入入口和兼容性说明；
- [`README.en.md`](README.en.md)：英文项目说明；
- [`docs/API.md`](docs/API.md)：完整 Brotato Online API 文档；
- [`docs/API.en.md`](docs/API.en.md)：英文 API 文档；
- [`scripts/brotato_online_api.gd`](scripts/brotato_online_api.gd)：实际暴露给第三方模组的 API 节点。
