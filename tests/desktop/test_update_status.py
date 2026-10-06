import importlib.util
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "update_status",
    Path(__file__).parents[2] / "config/.config/quickshell/jarvos/scripts/update-status.py",
)
assert SPEC and SPEC.loader
update_status = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(update_status)


def stale(lines, monkeypatch, desktop_ids=("org.gnome.gitlab.somas.Apostrophe",)):
    """Run stale_status over jarvos-update-stale output given as tuples."""
    out = "\n".join("\t".join(fields) for fields in lines)
    monkeypatch.setattr(update_status, "jarvos_cmd", lambda name: "/fake/" + name)
    monkeypatch.setattr(update_status, "has_desktop_entry", lambda app_id: app_id in desktop_ids)
    monkeypatch.setattr(update_status, "run", lambda *a, **k: (0, out, ""))
    return update_status.stale_status()


def test_apps_are_named_by_what_the_user_launched(monkeypatch):
    g = stale(
        [
            ("user", "app-com.google.Chrome-443595.scope", "1", "chrome"),
            ("user", "kitty-442726-1.scope", "2", "kitty"),
            ("user", "kitty-442726-2.scope", "3", "fish"),
            ("user", "dbus-:1.1-org.gnome.gitlab.somas.Apostrophe@0.service", "4", "apostrophe"),
            ("user", "app-ferdium-440527.scope", "5", "electron"),
        ],
        monkeypatch,
    )
    apps = [i for i in g["items"] if i.startswith("reabrir: ")]
    assert apps == ["reabrir: Apostrophe", "reabrir: Chrome", "reabrir: ferdium", "reabrir: kitty"]


def test_user_services_are_listed_apart_from_apps(monkeypatch):
    g = stale(
        [
            ("user", "pipewire.service", "1", "pipewire"),
            ("user", "quickshell-jarvos.service", "2", "qs"),
            ("user", "dbus-broker.service", "3", "dbus-broker"),
            ("user", "init.scope", "4", "systemd"),
            # D-Bus activated, but no launcher entry: a background service.
            ("user", "dbus-:1.2-org.gnome.Identity@0.service", "5", "goa-identity-se"),
        ],
        monkeypatch,
    )
    assert "serviço do usuário: pipewire" in g["items"]
    assert "serviço do usuário: quickshell-jarvos" in g["items"]
    assert "serviço do usuário: dbus-broker" in g["items"]
    assert "serviço do usuário: systemd --user" in g["items"]
    assert "serviço do usuário: Identity" in g["items"]
    assert not any(i.startswith("reabrir: ") for i in g["items"])


def test_session_helpers_are_not_reported_as_apps(monkeypatch):
    g = stale(
        [
            ("session", "session-2.scope", "1", "Hyprland"),
            ("session", "session-2.scope", "2", "cat"),
            ("session", "session-2.scope", "3", "sh"),
            ("session", "session-2.scope", "4", "(sd-pam)"),
            ("session", "session-2.scope", "5", "nautilus"),
        ],
        monkeypatch,
    )
    apps = [i for i in g["items"] if i.startswith("reabrir: ")]
    assert apps == ["reabrir: Hyprland", "reabrir: nautilus"]


def test_stale_code_never_counts_as_pending_updates(monkeypatch):
    g = stale([("system", "sshd.service", "1", "sshd")], monkeypatch)
    assert g["status"] == "info"
    assert "serviço: sshd.service" in g["items"]


def test_nothing_stale_is_ok(monkeypatch):
    assert stale([], monkeypatch)["status"] == "ok"
