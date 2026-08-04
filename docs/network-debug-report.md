# Brotato Online 网络问题调查与修复报告

日期：2026-08-02

## 1. 调查范围

本次调查读取了用户提供的压缩日志：

`logs/logs-闪退、重连后只能看到队友操作，队友无法看到重连者的动作、无法准备.rar`

归档 SHA-256：`35292a17b729cdf35a19cb2be4b788c4ad76e1e6f8610ba056b22258d20bb01b`

归档内包含 5 份 Godot 日志和 ModLoader 日志。实测日志全部来自同一个客户端 Steam ID `76561199001540670`，Host 为 `76561198359667458`；没有 Host 端对应日志，因此“单向可见”只能从客户端日志和代码路径交叉推断，不能伪造双端时间线。

## 2. 日志证据

| 日志 | 行数 | 网络慢/突发诊断 | 关键消息计数 |
|---|---:|---:|---|
| `godot.log` | 280 | 153 | `run_page_action_sync` 49，`menu_scene_state` 9 |
| `godot2026-08-02T10.55.29.log` | 2,642 | 2,082 | `run_page_action_sync` 185，`battle_reliable_events` 418，`menu_scene_state` 28，`game_start_prepare` 26 |
| `godot2026-08-02T11.12.42.log` | 691 | 464 | `run_page_action_sync` 94，`menu_scene_state` 12，`game_start_prepare` 12 |
| `godot2026-08-02T12.39.59.log` | 7,450 | 5,615 | `run_page_action_sync` 1,023，`battle_reliable_events` 410，`menu_scene_state` 88，`game_start_prepare` 82 |
| `godot2026-08-02T13.34.13.log` | 4,029 | 3,129 | `run_page_action_sync` 890，`battle_reliable_events` 128，`menu_scene_state` 58，`game_start_prepare` 36 |

主要证据：

- 5 份 Godot 日志都出现同一个错误：`Signal "idle_frame" ... is already connected ... "run_callbacks"`。这证明 Steam 回调存在重复所有者/重复连接。
- `godot.log` 中出现 `run_page_action_sync` 14 分片、581,871 bytes；`menu_scene_state` 12 分片、501,930 bytes；一次 `menu_scene_state` 处理耗时 384,561 µs，总耗时 423,591 µs。
- `11.12.42` 中 `host_character_setup` 处理耗时 269,411 µs / 34,555 bytes，另一次 57,724 µs / 51,070 bytes；`menu_scene_state` 达到 719,939 µs 总耗时 / 70,976 bytes。
- `12.39.59` 中 `game_start_prepare` 达到 714,211 µs / 144,657 bytes，`menu_scene_state` 达到 955,463 µs / 187,878 bytes。
- `shop_focus` 包通常只有约 508–525 bytes，但仍频繁出现 12–26 ms 处理；`shop_discard_weapon` 曾达到约 87,992 bytes。问题不是单纯“网络带宽不足”，而是大状态包反序列化、场景/槽位重建和可靠队列共同造成的主线程停顿。
- 运行时资源错误还包括 `res://tests/partial_doubles/pd_player.gd` 和 `res://dlcs/dlc_1/projectiles/bullet_harpoon/bullet_harpoon.gd` 缺失。当前仓库没有这些路径或引用，它们属于运行中的游戏/DLC 内容缺失，不能由本 Mod 的网络代码直接修复；它们仍可能独立导致资源加载失败或崩溃，需补齐游戏安装内容后单独验证。

槽位日志显示同一组成员的本地布局可能是 `[[1,1],[7,0],[2,1]]` 或 `[[1,1],[2,1],[7,0]]`，并同时记录 `mirror_idx=1/2`。因此 Steam ID、设备 ID、RunData 玩家索引不能用数组位置临时猜测，必须以 Host 发来的映射为准。

## 3. 原有状态/消息路径与根因

修复前的有效路径是：

1. lobby 层只有一个 `_online_session_generation`，没有每个 Steam peer 的连接代次。
2. 客户端发送 `hello` 后，Host 直接推送角色/武器/场景/选择状态；客户端收到任意一类 Host 状态就停止 Hello 重试，没有“已完成全量同步”的确认。
3. Host 的去重键、已发送缓存和客户端已见缓存主要按 Steam ID 建立。同一 Steam ID 断线重连后，旧缓存可能把新连接误判为重复。
4. `_pending_p2p_chunk_sends` 是跨 peer 的单一 FIFO，原先每帧只发送一个 chunk。一个 peer 的 Steam 发送缓冲阻塞时，会拖住其他 peer 和后续小消息。
5. 菜单动作序列此前按 origin 共用，`shop_focus`、购买、升级等不同 stream 可能互相污染 stale 判断。
6. `steamInitEx(..., true)` 与手动 `run_callbacks()` 的所有权没有明确化；日志已确认重复 `idle_frame` 连接。

这解释了三类现象：

- 重连者能收到队友状态，但 Host 仍把其输入当成旧会话/未注册会话；反方向动作因此不可见。
- 大量可靠状态包在 UI 主线程处理，造成周期性长卡，可靠队列继续积压，最终表现为无响应或退出。
- Steam P2P session 失败后只有底层 session 重置，没有应用层双向重建和权威状态 ACK，客户端可能停在“看似已加入、实际未 ready”。

## 4. 已实现的协议与生命周期修复

`scripts/network_session_state.gd` 是 Steam 管理器实际使用的生产协议核心，而不是测试模型。每个 Peer 独立保存 `connection_generation/session_epoch`、128-bit `connection_nonce`、Host 分配的 revision、动作 sequence window 和以下状态：

```text
DISCONNECTED → NEGOTIATING → SYNCING → READY
                                  ↘ FAILED
```

重连严格执行：

```text
Hello → Challenge → Confirm → FullStateBegin
      → 必需组件有序同步 → FullState marker → ACK → Complete/READY
```

关键约束：

- 仅 Hello 可不携带 Host 分配的 generation；新 nonce 才能创建新 attempt，旧 nonce 在 Peer 离开 lobby 前保持 retired。
- Challenge、Confirm、FullState、ACK 和 Complete 必须精确匹配同一 `generation + nonce + state_revision`。
- 重复 Hello 按当前阶段幂等处理：`NEGOTIATING` 重发 Challenge，`SYNCING` 重发 FullState，`READY` 重发 Complete。
- FullState 由生产状态核心 staging，发送层只有在当前消息被 Steam 接受或进入可靠队列后才推进；最大 48 分片组件不能被最终 marker 越过。
- 客户端应用完 FullStateBegin 声明的全部必需组件后才发送 ACK；Host 只在完全匹配的 ACK 后进入 READY，客户端只在匹配的 Complete 后开放操作。
- 普通选择、菜单和战斗状态只更新数据，不能改变 READY。
- Host/Client session failure、成员离开、退出、替换 lobby 和 generation 变化统一清理 Peer 队列、重组、sequence、动作去重、输入和战斗副本状态。
- 协议固定为 v2；大厅、邀请和所有在线 envelope 对 Mod 4.1.1、协议、lobby、Host、Sender、generation 和 nonce 做严格校验，不提供 v1 降级。

## 5. 队列与性能修复

`scripts/network_send_scheduler.gd` 是生产实际使用的按 Peer/Channel 调度器：

- 每帧全局最多发送 4 条，round-robin 服务 Peer；单 Peer 也可使用完整预算。
- Peer/Channel 内 FIFO；一个 Peer 当前 channel 失败时，本轮继续服务其他 Peer。
- 单 Peer 48、全局 192、TTL 15 秒；control/event/replaceable/transient 分级处理。
- control 预留先计算完整淘汰计划，再原子执行；预留失败不会删除无关 Peer 数据。
- FullState 组件按逻辑消息逐个排空，任何大组件都不会和后续组件或 marker 同时挤满物理队列。
- 接收端限制单消息 2 MiB/48 chunks、单 Peer 4 个和全局 12 个并发重组，并在保存首片前校验成员与连接身份。
- run-page action 使用显式 `origin_steam_id + action_stream + sequence`；`action_id` 仅用于幂等去重，Host relay sequence 在来源进程重启后保持连续。
- Steam callback owner 每轮动态检查；SceneTree 已自动驱动时不手动调用，没有 owner 时恰好手动调用一次。

## 6. 诊断日志

- `[BO_CONN]`：BOOT、状态、代次、nonce、握手和 session 生命周期。
- `[BO_EXIT]`：离开 lobby 的原因、Steam ID、lobby 和角色。
- `[BO_LAG][NET]`：`STALE_GENERATION`、`SESSION_NOT_READY`、`QUEUE_LIMIT`、`QUEUE_AGE_LIMIT`、`SEND_FAIL` 等结构化事件；不记录完整 payload。

## 7. 验证结果与限制

已执行的生产门禁：

- Docker 内 Godot 3.5.3 直接实例化生产协议核心、发送调度器和 callback driver，回归握手、重复 Hello、nonce 重放、revision、envelope、stream、分片上限、FIFO、公平、失败隔离、原子预留和 callback owner 切换。
- Godot `--check-only` 解析本次涉及的 9 个生产脚本；测试入口要求每组完成 marker，并在输出出现 `SCRIPT ERROR`/`Parse Error` 时失败，避免假绿。
- `git diff --check` 通过。
- 发布包固定为 Mod 4.1.1 / protocol 2、35 个运行时文件，执行可重复构建、CRC、清单、逐文件 SHA-256 校验；当前 SHA-256 为 `cc7b476530e3026fe6ae6d5e903d90b0632b3967b3684b0bd9ced70ed482f6e0`。
- 最终 ZIP 与有效 Steam Workshop 订阅目录中的实际加载文件哈希一致，ModLoader 已识别并初始化 `six666-BrotatoOnline`。

仍需真实双端人工验收：首次/重复邀请、客户端进程重启、Host 与 Client 分别断网恢复、Shop/战斗重连、ACK 丢失、退出重进，并核对双方日志是否在同一 generation/nonce/revision 下到达 READY、且没有 `SESSION_NOT_READY` 误丢合法输入。运行时资源缺失错误（`pd_player.gd`、DLC `bullet_harpoon.gd`）来自游戏/ModLoader 环境，和本次网络协议代码分开记录。
