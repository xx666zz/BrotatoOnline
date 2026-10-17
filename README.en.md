# Brotato Online

[简体中文](README.md) | **English**

> Remote and LAN multiplayer support for *Brotato*, using a host-led hybrid synchronization model.

![Brotato](https://img.shields.io/badge/Brotato-1.1.15.4-6c5ce7)
![ModLoader](https://img.shields.io/badge/ModLoader-6.2.0-0984e3)
![Players](https://img.shields.io/badge/Players-1--4-00b894)
![License](https://img.shields.io/badge/License-GPL--3.0-f39c12)

Brotato Online is a mod that adds multiplayer support to *Brotato*. It currently supports Steam friend lobbies, Steam public lobbies, and LAN sessions while synchronizing the main flow from character and weapon selection through combat, upgrades, shops, and continued runs.

The goal is not to replace Brotato's original co-op flow with a completely different multiplayer mode. Instead, the project tries to preserve the vanilla co-op experience and mod compatibility while allowing players on different machines to share the same run.

## Usage

### Steam

1. Install and enable Brotato Online for every player.
2. The host creates a lobby in-game.
3. Invite friends through Steam or make the lobby public.
4. Clients join through the Steam invite or the in-game lobby browser.
5. Once everyone is in the same session, use the normal co-op character, weapon, and run flow.

### LAN

LAN sessions can be used directly without Steam lobby discovery.

- Prefer automatic LAN discovery in the lobby browser.
- If broadcast discovery is unavailable, use **Direct Connect (LAN)** with the host IP and port.
- The default game port is `27462`; LAN discovery uses `27463`.

> Steam public lobbies and discovered LAN rooms appear in the same lobby browser.

### Saved runs and reconnection

The mod stores each character's owner in a separate identity file, associated with the exact vanilla run-file contents and profile. It adds no identity fields to vanilla saves. Remote players may join in any order. Once the saved owners complete their handshake, the host restores input slots in saved character order, preserving character, gear, currency, and shop indices.

- Older saves require a one-time assignment on the host's **Player ownership** page. Select a player for each character and confirm; subsequent resumes use the saved ownership.
- To replace a player, change computers, or switch between Steam and LAN, the host first opens **Reassign characters**, then admits and assigns the replacement. A new identity never automatically takes the first disconnected slot. During an active shop/battle, only the original owner can reconnect; replacement remains available through explicit reassignment on Continue.
- P1 remains host local player 1. Additional host local players can own other slots; join the required local inputs when resuming. Local ordinals follow their local join order.
- LAN installation identity and private resume tokens live in `mod_data/six666-BrotatoOnline/client_identity.cfg` in the game's user directory (the previous credential file is imported automatically). Preserve it for automatic recognition, or use explicit host reassignment after moving a save to another computer.
- Ownership tables live alongside credentials in `saved_identities.cfg`. Back up both files when moving saves; a missing or changed checkpoint falls back to explicit assignment.
- LAN uses handshake version 3 and Steam uses protocol `5.0.0`; update all peers. The browser and direct Steam joins reject older hosts, and the host rejects incompatible client hellos before they can play.

If room creation fails, retry or choose “Continue local co-op”. The ownership panel also offers local continuation; this closes the online session and keeps already joined local inputs in their saved character slots while collecting inputs for the missing slots. Waiting messages identify missing connections, handshakes, local player counts, or LAN resume proofs. Steam members are rechecked when reassignment opens; LAN newcomers rejected earlier must reconnect.

### Developer validation

Run with Godot 3.6 or a compatible Godot 3 engine:

```powershell
python tests/identity/run.py "C:/path/to/Godot_v3.6-stable_win64.exe"
```

The harness uses a temporary project and isolated identity file, never real game saves. It covers all six remote join orders, missing/unready owners, simultaneous disconnects and reverse reconnection, duplicate identities, spoofed senders, legacy migration, mixed host local/remote slots, removal and retry checkpoints, and per-run credential rotation in an existing room. Recovery checks cover synchronous/asynchronous creation failures, local continuation without losing saved characters, late Steam creation callbacks, reassignment refresh, specific waiting reasons, LAN handshake timeout, and rotation without restarting the joined flow. Real ENet loopback connections exercise disconnect/reconnect with changing peer IDs and delivery of refusal reasons before disconnection. Modified production scripts are also compiled by Godot.

For live acceptance, install the same build on multiple machines, save a run, quit, and rejoin in reverse order. Check each player's character, gear, currency, and locked shop items. Disconnect two clients together during battle/shop and reconnect in reverse order. Automated checks pass; full Steam multiplayer and actual loss/jitter conditions still require this live check.

Actual-game validation for this revision used Brotato 1.1.15.4, its custom Godot 3.7 executable, compiled vanilla scripts, and ModLoader 6.2. An isolated host and two full game clients saved a four-player mixed local/LAN layout, restarted, rejoined in reverse order, and entered the shop and battle with the same owners and currency. Offline continuation preserved the nonadjacent local controller slot while filling the remote slots. Inputs were driven by a test mod; the test-only loader profile loaded local ZIPs instead of Workshop subscriptions. Steam account sessions, physical controller input, and multi-machine loss/jitter remain unverified.

## Features

### Sessions and lobbies

- Up to 4 players
- Steam friend lobbies and friend invitations
- Steam public lobby browser
- Public lobby host, player count, phase, and latency display
- View the host's loaded mod list before joining
- Automatic LAN lobby discovery
- Manual LAN connection by IP and port
- Shared session logic across Steam and LAN transports
- Clear errors for version/protocol mismatch, full rooms, stale lobbies, and other join failures

### Game-flow synchronization

- Character and weapon selection
- Difficulty, zone, and run configuration
- Game start and scene transitions
- Wave progression and important combat state
- Player HP, death, and failed-wave flow
- Upgrades, item boxes, and shop progression
- Ready/cancel-ready and other online menu actions
- Continuing vanilla co-op saves
- Reserved in-run slots and reconnect flow for continued runs

### Combat synchronization

Brotato Online is not a fully host-authoritative simulation. Different kinds of state use different synchronization strategies. The Host leads shared progression and critical state, while Clients still simulate substantial parts of the game locally so Brotato's original logic can be reused without replicating everything at high frequency.

### Multiplayer UX

- Quick-chat wheel
- Custom quick-chat phrases, up to 20 characters each
- Option to disable custom quick chat and accept only built-in phrases
- Selectable local multiplayer input device
- Keyboard/mouse and gamepad support
- Optional outline for locally controlled characters
- Safe return to the main menu when the host disconnects unexpectedly
- Chinese and English UI text

## Installation

### Steam Workshop

If you use the Workshop build, subscribe to Brotato Online and enable it in ModLoader.

### Manual/development build

Install the project as a ModLoader-compatible Godot mod and keep the expected mod directory name:

```text
six666-BrotatoOnline
```

Current compatibility:

| Component                       | Version    |
| ------------------------------- | ---------- |
| Brotato                         | `1.1.15.4` |
| ModLoader                       | `6.2.0`    |
| Brotato Online network protocol | `4.0.0`    |
| Maximum players                 | `4`        |

## Network Architecture

```mermaid
flowchart TD
    A[Steam Lobby / SteamNetworkingMessages] --> S[SessionManager]
    B[LAN Discovery / ENet] --> S

    S --> M[MenuSyncManager]
    S --> I[OnlineInputManager]
    S --> R[BattleReplicaManager]

    M --> G[Vanilla Brotato co-op flow]
    I --> G
    R --> G

    S --> API[BrotatoOnlineAPI]
    API --> MOD[Third-party mods]
```

The central rule is simple: **SessionManager owns session state, Host/Client roles, and message routing; Steam/LAN only provide transport; menu, input, and combat each use synchronization suited to their own state.**

This keeps gameplay logic independent from a single networking backend and allows combat synchronization to evolve without rewriting lobby/session handling.

## Main Modules

```text
six666-BrotatoOnline/
├─ manifest.json
├─ mod_main.gd
├─ scripts/
│  ├─ session_manager.gd
│  ├─ steam_transport.gd
│  ├─ lan_transport.gd
│  ├─ lan_discovery.gd
│  ├─ public_lobby_browser.gd
│  ├─ menu_sync_manager.gd
│  ├─ online_player_slot_manager.gd
│  ├─ online_input_manager.gd
│  ├─ battle_replica_manager.gd
│  ├─ state_snapshot.gd
│  ├─ upgrade_runtime_sync.gd
│  ├─ online_mod_settings_manager.gd
│  ├─ quick_chat_wheel.gd
│  ├─ brotato_online_api.gd
│  └─ ...
├─ extensions/
│  └─ ...
├─ docs/
│  ├─ API.md
│  └─ API.en.md
└─ translations/
   ├─ brotato_online_zh.txt
   └─ brotato_online_en.txt
```

| Module                           | Role                                                                                         |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| `session_manager.gd`             | Session ownership, host/client roles, connections, disconnect/reconnect, and message routing |
| `steam_transport.gd`             | Steam lobby callbacks and SteamNetworkingMessages transport                                  |
| `lan_transport.gd`               | LAN/ENet connections and data transport                                                      |
| `lan_discovery.gd`               | LAN lobby broadcast discovery                                                                |
| `public_lobby_browser.gd`        | Steam public lobbies, LAN rooms, latency probing, and host mod information                   |
| `menu_sync_manager.gd`           | Character, weapon, upgrade, shop, and other menu-phase synchronization                       |
| `online_player_slot_manager.gd`  | Player slots, remote placeholders, and input-device mapping                                  |
| `online_input_manager.gd`        | Client input capture and host-side input application                                         |
| `battle_replica_manager.gd`      | Client combat-state application, entity presentation, and battle-end coordination            |
| `state_snapshot.gd`              | Host combat snapshots, important state, and event serialization                              |
| `upgrade_runtime_sync.gd`        | Runtime upgrade-state synchronization                                                        |
| `online_mod_settings_manager.gd` | Input device, player outline, quick-chat, and multiplayer settings                           |
| `brotato_online_api.gd`          | Stable integration API for third-party mods                                                  |

Scripts under `extensions/` handle vanilla edge cases exposed by cross-machine multiplayer, including invalid node access, player-count differences, scene exit, shop interaction, pause-menu focus, and combat cleanup timing.

## Third-party Mod API

Brotato Online exposes a public API so other mods do not need to depend on internal manager nodes.

Full documentation: [`docs/API.en.md`](docs/API.en.md)

### Get the API

```gdscript
var bo_api = null

func _ready():
    var apis = get_tree().get_nodes_in_group("brotato_online_api")
    if apis.size() > 0:
        bo_api = apis[0]
```

### Helper for one-owner gameplay logic in third-party mods

```gdscript
if bo_api == null or bo_api.should_run_authoritative_logic():
    # Offline or host: mutate the real game state
    run_gameplay_logic()
else:
    # Client: local visuals/UI or a request to the host only
    run_client_visual_logic()
```

The API also exposes:

- Online/host/client state
- Current multiplayer phase and context
- Local player indices and ownership checks
- Client-to-host custom messages
- Host broadcast and per-player messages
- Phase, slot-layout, and third-party message events

`should_run_authoritative_logic()` is a safe default helper for third-party mods: if custom logic changes shared game state and must only run once, it should usually run offline or on the Host. The function name does **not** mean that all internal Brotato Online combat simulation is host-authoritative.

Third-party mods should use `BrotatoOnlineAPI` instead of reaching into Brotato Online's internal managers directly.

## Mod Compatibility

Brotato Online tries to preserve vanilla co-op behavior, but online play requires a clear separation between host and client responsibilities.

Mods that are usually easier to support:

- Content mods that only add characters, weapons, or similar data and are installed by all players
- Content additions that do not replace vanilla online menus or critical synchronization flows
- Mods that explicitly integrate through the Brotato Online API

Mods that are more likely to conflict:

- Mods that alter character selection, weapon selection, upgrades, shops, or other UI interactions; button presses, focus, and page state may no longer synchronize correctly between host and clients
- Heavy rewrites of enemies, shops, upgrades, battle-end logic, or scene transitions
- Replacing vanilla co-op player slots or input mapping

Adding new content and replacing an existing flow are very different compatibility cases. A newly added character or weapon can usually reuse Brotato Online's existing selection and synchronization path. A UI mod, however, may replace buttons, focus handling, or page-transition logic and can therefore break synchronized clicks even when it looks purely cosmetic.

The public lobby browser can show the host's mod list before joining, but **matching mod lists do not guarantee compatibility, and different mod lists do not automatically mean the session cannot work**. Compatibility depends on what those mods actually change. 

## Documentation

- [`README.md`](README.md): 中文README
- [`docs/API.md`](docs/API.md): Chinese API documentation
- [`docs/API.en.md`](docs/API.en.md): English API documentation
- [`scripts/brotato_online_api.gd`](scripts/brotato_online_api.gd): API implementation exposed to other mods

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
