#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_IMAGE="${GODOT_IMAGE:-robpc/godot-headless:3.5.3-linux}"

if [[ "$#" -gt 0 ]]; then
	case "$1" in
		--godot-only)
			shift
			;;
		--help|-h)
			echo "Usage: $0 [--godot-only]"
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 2
			;;
	esac
fi
if [[ "$#" -gt 0 ]]; then
	echo "Unexpected arguments: $*" >&2
	exit 2
fi

run_godot_tests() {
	echo "== Godot 3 headless tests =="
	local test_project
	test_project="$(mktemp -d -t brotato-online-godot-tests.XXXXXX)"
	trap 'rm -rf -- "$test_project"' RETURN
	mkdir -p "$test_project/scripts"
	cp -a "$ROOT_DIR/tests/godot/." "$test_project/"
	cp "$ROOT_DIR/scripts/network_session_state.gd" "$test_project/scripts/network_session_state.gd"
	cp "$ROOT_DIR/scripts/network_send_scheduler.gd" "$test_project/scripts/network_send_scheduler.gd"
	cp "$ROOT_DIR/scripts/steam_callback_driver.gd" "$test_project/scripts/steam_callback_driver.gd"
	cp "$ROOT_DIR/scripts/network_protocol_config.gd" "$test_project/scripts/network_protocol_config.gd"
	cp "$ROOT_DIR/scripts/steam_lobby_manager.gd" "$test_project/scripts/steam_lobby_manager.gd"
	cp "$ROOT_DIR/scripts/menu_sync_manager.gd" "$test_project/scripts/menu_sync_manager.gd"
	cp "$ROOT_DIR/scripts/public_lobby_browser.gd" "$test_project/scripts/public_lobby_browser.gd"
	cp "$ROOT_DIR/scripts/online_input_manager.gd" "$test_project/scripts/online_input_manager.gd"
	cp "$ROOT_DIR/scripts/battle_replica_manager.gd" "$test_project/scripts/battle_replica_manager.gd"
	cp "$ROOT_DIR/scripts/focus_control_guard.gd" "$test_project/scripts/focus_control_guard.gd"
	cp "$ROOT_DIR/scripts/online_slot_layout.gd" "$test_project/scripts/online_slot_layout.gd"
	mkdir -p "$test_project/mods-unpacked/six666-BrotatoOnline/scripts"
	cp "$ROOT_DIR/scripts/network_protocol_config.gd" "$test_project/mods-unpacked/six666-BrotatoOnline/scripts/network_protocol_config.gd"
	cp "$ROOT_DIR/scripts/focus_control_guard.gd" "$test_project/mods-unpacked/six666-BrotatoOnline/scripts/focus_control_guard.gd"
	cp "$ROOT_DIR/scripts/online_slot_layout.gd" "$test_project/mods-unpacked/six666-BrotatoOnline/scripts/online_slot_layout.gd"
	sed -i '1r tests/godot/parser_globals.gdinc' "$test_project/scripts/steam_lobby_manager.gd"
	sed -i '1r tests/godot/parser_globals.gdinc' "$test_project/scripts/menu_sync_manager.gd"
	sed -i '1r tests/godot/parser_globals.gdinc' "$test_project/scripts/public_lobby_browser.gd"
	sed -i '1r tests/godot/parser_globals.gdinc' "$test_project/scripts/online_input_manager.gd"
	sed -i '1r tests/godot/parser_globals.gdinc' "$test_project/scripts/battle_replica_manager.gd"
	local godot_output
	godot_output="$test_project/godot-output.log"
	set +e
	docker run --rm \
		--init \
		--network none \
		-v "$test_project:/workspace:ro" \
		-w /workspace \
		--entrypoint /bin/sh \
		"$GODOT_IMAGE" \
		-lc '
		set -eu
		BO_SOURCE_ROOT=/workspace /usr/local/bin/godot \
			--path /workspace \
			--headless \
			--script /workspace/godot_test_runner.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/steam_lobby_manager.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/menu_sync_manager.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/public_lobby_browser.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/network_session_state.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/network_send_scheduler.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/steam_callback_driver.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/network_protocol_config.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/online_input_manager.gd
		/usr/local/bin/godot --path /workspace --headless --check-only --script /workspace/scripts/battle_replica_manager.gd
		' 2>&1 | tee "$godot_output"
	local docker_status="${PIPESTATUS[0]}"
	set -e
	if [[ "$docker_status" -ne 0 ]]; then
		return "$docker_status"
	fi
	if grep -Eq 'SCRIPT ERROR:|Parse Error:' "$godot_output"; then
		echo "Godot emitted a script error" >&2
		return 1
	fi
	for marker in \
		protocol_attempt_identity_and_handshake \
		protocol_envelope_and_stream_invariants \
		network_send_scheduler_behavior \
		steam_callback_driver_switching \
		protocol_config \
		focus_control_guard \
		shop_focus_target_fallback_policy \
		online_slot_reset_preserves_local_layout \
		host_proxy_death_cleanup_policy; do
		if ! grep -Fq "[BO_TEST_CASE_COMPLETE] $marker" "$godot_output"; then
			echo "Missing Godot test completion marker: $marker" >&2
			return 1
		fi
	done
	if ! grep -Fq '[BO_TEST_SUITE_COMPLETE]' "$godot_output"; then
		echo "Missing Godot suite completion marker" >&2
		return 1
	fi
}

run_godot_tests

echo "All tests passed"
