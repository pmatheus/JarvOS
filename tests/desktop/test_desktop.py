import base64
import importlib.util
import json
import os
from pathlib import Path
from subprocess import CompletedProcess

import pytest

SPEC = importlib.util.spec_from_file_location(
    "desktop", Path(__file__).parents[2] / "lib/desktop.py"
)
assert SPEC and SPEC.loader
desktop = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(desktop)


@pytest.fixture
def state(tmp_path, monkeypatch):
    monkeypatch.setenv("JARVOS_DESKTOP_STATE", str(tmp_path / "state"))
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    return tmp_path / "state"


def test_preview_does_not_write_state_or_run_wallpaper(state, tmp_path, monkeypatch):
    pic = tmp_path / "wallpaper.png"
    pic.write_bytes(
        base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jKf0AAAAASUVORK5CYII="
        )
    )
    monkeypatch.setattr(
        desktop,
        "generate",
        lambda *args: {"name": "dynamic", "colours": {"primary": "abcdef"}},
    )
    result = desktop.wallpaper(pic, preview=True)
    assert result["colours"]["primary"] == "abcdef"
    assert not state.exists()


def test_failed_wallpaper_application_keeps_saved_state(state, tmp_path, monkeypatch):
    state.mkdir()
    previous = {"name": "dynamic", "colours": {}, "test_preserved": True}
    (state / "scheme.json").write_text(json.dumps(previous))
    pic = tmp_path / "wallpaper.png"
    pic.write_bytes(b"test_image")
    monkeypatch.setattr(
        desktop, "generate", lambda *args: {"name": "dynamic", "colours": {}}
    )
    calls = []

    def fail_display(cmd, **kwargs):
        calls.append(cmd)
        if cmd[0] == "file":
            return "image/png"
        raise RuntimeError("display unavailable")

    monkeypatch.setattr(desktop, "run", fail_display)
    with pytest.raises(RuntimeError):
        desktop.wallpaper(pic)
    assert calls[-1][0] == "awww"
    assert json.loads((state / "scheme.json").read_text()) == previous
    assert not (state / "wallpaper/path.txt").exists()


def test_ipc_preserves_literal_arguments(monkeypatch):
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return CompletedProcess(cmd, 0, "ok\n", "")

    monkeypatch.setattr(desktop.subprocess, "run", fake_run)
    desktop.ipc(["drawers", "toggle", "literal $(false)"])
    assert calls[0][-3:] == ["drawers", "toggle", "literal $(false)"]


def test_ipc_rejects_zero_exit_unknown_target(monkeypatch):
    monkeypatch.setattr(
        desktop.subprocess,
        "run",
        lambda cmd, **kwargs: CompletedProcess(cmd, 0, "Target not found.\n", ""),
    )
    with pytest.raises(RuntimeError):
        desktop.ipc(["missing", "open"])


def test_invalid_scheme_name_does_not_write(state):
    with pytest.raises(ValueError):
        desktop.select_scheme(name="../escape")
    assert not state.exists()


def test_native_palette_has_the_shell_contract(state):
    result = desktop.generate(None, "tonalspot", "dark", "mocha", seed="#bace9a")
    for key in ("primary", "onPrimary", "surfaceContainer", "onSurface"):
        assert len(result["colours"][key]) == 6
        int(result["colours"][key], 16)
    assert result["name"] == "dynamic"


def test_recorder_does_not_claim_an_unrelated_process(state):
    state.mkdir()
    (state / "recorder.json").write_text(
        json.dumps({"pid": os.getpid(), "start_ticks": "wrong"})
    )
    assert desktop.record_status()["running"] is False


def test_saved_action_migration_preserves_preferences_and_backup(state, monkeypatch):
    config = Path.home() / ".config"
    monkeypatch.setenv("XDG_CONFIG_HOME", str(config))
    target = config / "caelestia/shell.json"
    target.parent.mkdir(parents=True)
    prefs = {
        "bar": {"height": 33},
        "launcher": {
            "actions": [
                {"command": ["caelestia", "shell", "controlCenter", "open"]},
                {"command": ["custom-command", "literal argument"]},
            ]
        },
    }
    original = json.dumps(prefs)
    target.write_text(original)
    desktop.migrate_preferences()
    changed = json.loads(target.read_text())
    assert changed["bar"] == prefs["bar"]
    assert changed["launcher"]["actions"][0]["command"] == [
        "jarvos-desktop",
        "shell",
        "controlCenter",
        "open",
    ]
    assert changed["launcher"]["actions"][1] == prefs["launcher"]["actions"][1]
    desktop.migrate_preferences()
    assert target.with_name("shell.pre-jarvos-desktop.json").read_text() == original
