"""Run the identity regressions with an unmodified Godot 3 engine.

Usage: python tests/identity/run.py PATH_TO_GODOT_3
Only a temporary project and its private user directory are written. No game
installation, Steam client, or real player save is opened by this harness.
"""
from pathlib import Path
import re
import csv
import json
import shutil
import subprocess
import sys
import tempfile
import os

ROOT = Path(__file__).resolve().parents[2]
TESTS = Path(__file__).resolve().parent


def functions(path, names):
    source = path.read_text(encoding="utf-8")
    result = []
    for name in names:
        match = re.search(r"^func " + re.escape(name) + r"\(.*?(?=^func |\Z)", source, re.M | re.S)
        if not match:
            raise RuntimeError(f"Missing production function: {name}")
        result.append(match.group())
    return "\n".join(result)


def main():
    if len(sys.argv) not in (2, 4):
        raise SystemExit(__doc__)
    engine = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="brotato-identity-") as name:
        project = Path(name)
        scripts = project / "scripts"
        scripts.mkdir()
        for filename in ["player_identity_registry.gd", "player_identity_manager.gd"]:
            shutil.copyfile(ROOT / "scripts" / filename, scripts / filename)
        for filename in ["session_manager.gd", "online_player_slot_manager.gd", "player_removal_manager.gd", "lan_transport.gd"]:
            shutil.copyfile(ROOT / "scripts" / filename, scripts / filename)
        shutil.copyfile(ROOT / "mod_main.gd", project / "mod_main.gd")
        shutil.copyfile(ROOT / "extensions/progress_data_removed_players.gd", project / "progress_extension.gd")
        for path in TESTS.glob("*.gd"):
            shutil.copyfile(path, project / path.name)
        # Exercise production transport/admission functions against fake transport
        # endpoints; the tests do not reimplement their decision logic.
        session_functions = functions(ROOT / "scripts/session_manager.gd", [
            "_register_remote_connection", "_connection_lookup_key",
            "_get_identity_manager", "commit_resume_peer_order",
            "_refresh_player_connection", "_remove_player_connection",
            "_on_transport_peer_connected", "_on_transport_peer_disconnected",
            "_on_transport_packet_received", "_handle_transport_identity",
            "_challenge_lan_identity", "refresh_lan_identities_for_run",
            "_official_continue_players_ready",
            "_remote_connection_rejection_reason", "refresh_resume_candidates",
            "_handle_transport_welcome", "_fail_lan_handshake",
            "_drop_pending_p2p_sends_for_target", "_refresh_lobby_members",
            "leave_lobby", "_poll_official_continue_auto_lobby",
            "_is_host_in_official_coop_continue_resume_scene",
            "_can_create_lobby_from_current_scene", "create_session",
            "create_lobby_and_invite", "_handle_host_session_creation_failed",
            "_poll_join_request_timeout", "_on_lobby_created",
            "_accept_client_protocol", "_is_lobby_protocol_compatible",
        ])
        session_functions = session_functions.replace(
            "func _handle_transport_welcome(", "func _apply_transport_welcome(")
        with (project / "session.gd").open("a", encoding="utf-8") as out:
            out.write("\n" + session_functions)
        slot_functions = functions(ROOT / "scripts/online_player_slot_manager.gd", [
            "apply_resume_identity_layout", "_get_next_remote_placeholder_device_from_lists",
            "get_local_player_indices", "is_remote_player_index", "get_remote_steam_id",
            "get_player_index_for_steam_id",
            "online_reset_to_offline",
        ])
        with (project / "slots.gd").open("a", encoding="utf-8") as out:
            out.write("\n" + slot_functions)
        (project / "extensions").mkdir()
        shutil.copyfile(ROOT / "extensions/coop_resume_player_identity.gd", project / "extensions/coop_resume_player_identity.gd")
        singletons = project / "singletons"
        singletons.mkdir()
        (singletons / "progress_data.gd").write_text('extends Node\nfunc save() -> void:\n\tpass\nfunc get_run_state(_a=[],_b=[],_c=[],_d=[],_e=[],_f=[]) -> Dictionary:\n\treturn {"has_run_state": true, "players_data": RunData.players_data.duplicate()}\n', encoding="utf-8")
        with (ROOT / "translations/brotato_online_zh.txt").open(encoding="utf-8-sig", newline="") as table:
            translations = dict(list(csv.reader(table))[1:])
        (project / "zh.json").write_text(json.dumps(translations, ensure_ascii=False), encoding="utf-8")
        font = Path("C:/Windows/Fonts/msyh.ttc")
        if font.exists():
            shutil.copyfile(font, project / "preview_font.ttc")
        (project / "project.godot").write_text('''config_version=4
[application]
config/name="Brotato Identity Regression"
run/main_scene="res://test.tscn"
config/use_custom_user_dir=true
config/custom_user_dir="identity-tests"
[autoload]
CoopService="*res://coop.gd"
RunData="*res://run_data.gd"
ProgressData="*res://progress.gd"
ItemService="*res://globals.gd"
ZoneService="*res://globals.gd"
Utils="*res://globals.gd"
UIService="*res://globals.gd"
MenuData="*res://globals.gd"
MusicManager="*res://globals.gd"
ModLoaderMod="*res://globals.gd"
ModLoaderLog="*res://globals.gd"
TempStats="*res://globals.gd"
LinkedStats="*res://globals.gd"
Text="*res://globals.gd"
Keys="*res://globals.gd"
[display]
window/size/width=1280
window/size/height=720
[rendering]
quality/driver/driver_name="GLES2"
''', encoding="utf-8")
        (project / "test.tscn").write_text('[gd_scene load_steps=2 format=2]\n[ext_resource path="res://test.gd" type="Script" id=1]\n[node name="IdentityTests" type="Node"]\nscript = ExtResource( 1 )\n', encoding="utf-8")
        # Keep ConfigFile credentials in the temporary directory as well.
        manager = scripts / "player_identity_manager.gd"
        manager.write_text(manager.read_text(encoding="utf-8").replace(
            '"user://mod_data/six666-BrotatoOnline"', '"res://private-identity"').replace(
            '"user://brotato_online_identity.cfg"', '"res://legacy_identity.cfg"'), encoding="utf-8")
        log = project / "engine.log"
        command = [str(engine), "--no-window", "--path", str(project), "--log-file", str(log)]
        test_env = os.environ.copy()
        test_env.update(APPDATA=str(project / "appdata"), XDG_DATA_HOME=str(project / "appdata"))
        if len(sys.argv) == 4 and sys.argv[2] == "--preview":
            command += ["--", "--preview", str(Path(sys.argv[3]).resolve())]
        try:
            result = subprocess.run(command,
                                    capture_output=True, text=True, timeout=45, env=test_env)
        except subprocess.TimeoutExpired as error:
            for captured in [error.stdout, error.stderr]:
                print(captured.decode(errors="replace") if isinstance(captured, bytes) else captured or "", end="")
            if log.exists():
                print(log.read_text(encoding="utf-8", errors="replace"))
            raise
        output = result.stdout + result.stderr
        if log.exists():
            output += log.read_text(encoding="utf-8", errors="replace")
        print(output, end="")
        marker = "IDENTITY TESTS PASSED" if len(sys.argv) == 2 else "IDENTITY UI PREVIEW SAVED"
        if result.returncode or marker not in output or "SCRIPT ERROR" in output or "ERROR:" in output:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
