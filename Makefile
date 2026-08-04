.PHONY: test test-godot verify package

test:
	./tools/run_tests.sh

test-godot:
	./tools/run_tests.sh --godot-only

verify: test
	python3 tools/build_release.py --check

package:
	python3 tools/build_release.py
