# Brotato Online

[简体中文](README.md) | **English**

Brotato Online is a mod that adds remote multiplayer support to *Brotato*.

The mod uses Steam lobbies and network synchronization to allow players to play together with their Steam friends. It synchronizes character selection, weapon selection, menu flow, combat state, player input, and selected combat events. It also provides multiplayer lobbies, Steam friend invitations, a quick-chat wheel, local-player outlines, and other online features.

## Features

- Steam friend multiplayer support

- Synchronization of character selection, weapon selection, difficulty, zone, and overall game flow

- Synchronization of player input, health, enemies, pickups, and important combat states

- Multiplayer lobby creation and restoration when continuing a saved run

- Quick-chat wheel support

- Optional outline for locally controlled characters, making it easier to identify which character you control

- A simple API that allows other mods to access Brotato Online multiplayer state and network messaging

## Installation

Subscribe to the mod through the Steam Workshop.

## Basic Synchronization Model

Brotato Online uses a host-authoritative networking model.

In general:

- The host controls the main game flow, wave progression, important combat state, and final results.

- Clients handle local input, selected presentation-layer prediction, and remote state display.

- During menu phases, the host broadcasts the current selections, page state, and run configuration.

- During combat, clients are kept synchronized through snapshots, events, and compatibility patches where necessary.

- Third-party mods should avoid executing logic on clients that directly changes authoritative gameplay results.

Third-party mods are encouraged to follow this pattern:

```gdscript
if bo_api == null or bo_api.should_run_authoritative_logic():
    # Run real gameplay logic offline or on the host
    run_real_gameplay_logic()
else:
    # Clients should only run local visuals, requests, or UI logic
    run_client_visual_or_request_logic()
```

## Project Structure

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

Main modules:

| Module                           | Description                                                                                           |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `steam_lobby_manager.gd`         | Manages Steam lobbies, P2P messages, joining, invitations, and host/client state                      |
| `menu_sync_manager.gd`           | Synchronizes character selection, weapon selection, difficulty, shops, upgrades, and other menu flows |
| `online_player_slot_manager.gd`  | Manages local players, remote player placeholders, player indices, and input-device mappings          |
| `online_input_manager.gd`        | Captures client input and applies it on the host                                                      |
| `battle_replica_manager.gd`      | Synchronizes combat entities, players, enemies, pickups, and presentation events                      |
| `state_snapshot.gd`              | Builds and applies combat-state snapshots                                                             |
| `net_id_registry.gd`             | Manages network IDs for runtime entities                                                              |
| `runtime_locator.gd`             | Locates runtime nodes in the active game scene                                                        |
| `online_mod_settings_manager.gd` | Manages Brotato Online settings and local display options                                             |
| `quick_chat_wheel.gd`            | Implements the quick-chat wheel                                                                       |
| `brotato_online_api.gd`          | Exposes a simplified API to third-party mods                                                          |

Scripts in the `extensions/` directory mainly patch edge cases in the original game logic that become problematic in multiplayer. These include prematurely freed objects, inconsistent player counts, client-side room cleanup, and delayed queues referencing invalid nodes.

## Developer API

Brotato Online provides a simple API that allows other mods to determine whether the game is currently online, whether the local machine is the host, whether a player belongs to the local machine, and to send custom network messages.

The complete API documentation is available here:

- [Brotato Online API Documentation](docs/API.en.md)

Minimal setup:

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
```

If `bo_api == null`, Brotato Online is not enabled. Other mods should then continue using their normal offline behavior.

## Network Messaging Guidelines

When sending messages through the Brotato Online API, third-party mods should follow these conventions:

- Use a stable and unique string for `mod_id`, such as `"author_mod_name"`.

- Use short strings for `route` to distinguish message types, such as `"request_spawn"`, `"sync_state"`, or `"play_fx"`.

- Include only necessary data in `payload`. Avoid sending large objects, node references, or non-serializable values.

- Use `scope = "battle"` for combat-related messages.

- Use `scope = "menu"` for menu or settings synchronization.

- Use reliable delivery for important state changes.

- High-frequency presentation events may use unreliable delivery.

Third-party mods should not directly access Brotato Online's internal manager nodes. Use the interfaces exposed by `BrotatoOnlineAPI` whenever possible.

## Compatibility

- Game version: Brotato 1.1.15.4

- ModLoader version: 6.2.0

- Multiplayer platform: Steam

## Compatibility Notes

Brotato Online applies several runtime extensions to the original game flow. Compatibility with other mods therefore depends on which parts of the game those mods modify.

## Documentation

- README.md: Chinese project overview, developer integration entry point, and compatibility information

- README.en.md: English project overview

- docs/API.md: Complete Chinese Brotato Online API documentation

- docs/API.en.md: Complete English Brotato Online API documentation

- scripts/brotato_online_api.gd: API node exposed to third-party mods
