# Retry scene reload regression

Install this checkout at `<Godot project>/mods-unpacked/six666-BrotatoOnline`, including `tests`, then run:

```powershell
./tests/Test-RetryReload.ps1 -ProjectPath E:/github/BrotatoMod/RecoveredProject
```

Requires the recovered Brotato project and GodotSteam 3.6 (override `-Godot` as needed). The runner isolates user data, disables saving, verifies the deployed dispatcher hash, and writes timestamped logs and screenshots beside the project under `logs/retry-reload-regression`.

This is a controlled runtime regression using actual battle scenes and the unmodified production scene dispatcher. It constructs a failed-wave UI state, supplies the retry message at the menu-sync boundary, and checks scene instance IDs. A test subclass isolates network roster lookup and RunData deserialization. It does not claim to exercise natural combat deaths, Steam/LAN delivery, or the full host/client ready handshake.

Coverage: a new retry within the previous 12-second flight window; repeated requests before/after scene creation; ordinary scene refresh; successive generations with identical path/config; late duplicate and stale generations after natural window expiry; session reset allowing start IDs to restart. Old duplicate/stale retries must not reapply RunData.

## Automatic late-client recovery

```powershell
./tests/Test-RetryReload.ps1 -ProjectPath E:/github/BrotatoMod/RecoveredProject -Suite recovery
```

The recovery suite runs host and client session state machines in one Godot process, with controlled message delivery. It drops the first start commit, forces the host ready deadline to expire, and verifies that a retry brings the client into a real new battle scene. It then drops the first ready ACK and verifies recovery without another scene reload. Other checks cover resend rate limits, queued-message backpressure, wrong-peer/stale ACKs, stale prepare/commit messages, finished battles, generation changes, session reset, and the reliable entity plus current-snapshot catchup packets.

The test substitutes transport delivery, host scene execution (the shared SceneTree belongs to the client), inventory deserialization and snapshot contents. Production recovery, timeout, commit, ACK, scene dispatch and catchup serialization execute unchanged. This is not a two-computer LAN/Steam or natural-combat test.
