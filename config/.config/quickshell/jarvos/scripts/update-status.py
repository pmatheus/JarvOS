#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
EXTRA_PATHS = [
    os.path.expanduser("~/.cargo/bin"),
    os.path.expanduser("~/.bun/bin"),
    os.path.expanduser("~/go/bin"),
    os.path.expanduser("~/.local/bin"),
    os.path.expanduser("~/.pub-cache/bin"),
    "/opt/flutter/bin",
    "/opt/android-sdk/cmdline-tools/latest/bin",
    "/opt/android-sdk/platform-tools",
    "/opt/android-sdk/emulator",
    "/usr/local/bin",
    "/usr/bin",
]
os.environ["PATH"] = ":".join([path for path in EXTRA_PATHS if path]) + ":" + os.environ.get("PATH", "")
os.environ.setdefault("ANDROID_HOME", "/opt/android-sdk")
os.environ.setdefault("ANDROID_SDK_ROOT", "/opt/android-sdk")
os.environ.setdefault("JAVA_HOME", "/usr/lib/jvm/java-26-openjdk")


def have(command):
    return shutil.which(command) is not None


def clean(text):
    return ANSI_RE.sub("", text or "").strip()


def run(command, timeout=20, cwd=None):
    try:
        proc = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "NO_COLOR": "1"},
        )
        return proc.returncode, clean(proc.stdout), clean(proc.stderr)
    except subprocess.TimeoutExpired:
        return 124, "", f"Timed out after {timeout}s"
    except Exception as exc:
        return 1, "", str(exc)


def lines(text):
    return [line.strip() for line in clean(text).splitlines() if line.strip()]


def group(id_, name, icon, items=None, status="ok", error=""):
    visible_items = items or []
    return {
        "id": id_,
        "name": name,
        "icon": icon,
        "count": len(visible_items),
        "status": status,
        "items": visible_items[:80],
        "error": error,
    }


def missing(id_, name, icon):
    return group(id_, name, icon, [], "missing", "Command not installed")


def pacman_updates():
    if not have("checkupdates"):
        return missing("pacman", "Pacman", "deployed_code_update")
    rc, out, err = run(["checkupdates", "--nocolor"], timeout=45)
    if rc != 0 and "Cannot fetch updates" in err:
        rc, out, err = run(["pacman", "-Qu", "--color", "never"], timeout=20)
    found = [line for line in lines(out) if "[ignored]" not in line]
    if found:
        return group("pacman", "Pacman", "deployed_code_update", found, "updates")
    if rc in (0, 2):
        return group("pacman", "Pacman", "deployed_code_update", [], "ok")
    return group("pacman", "Pacman", "deployed_code_update", [], "error", err or out)


def aur_updates():
    if not have("yay"):
        return missing("aur", "AUR", "package_2")
    rc, out, err = run(["yay", "-Qua", "--color", "never"], timeout=60)
    found = lines(out)
    if found:
        return group("aur", "AUR", "package_2", found, "updates")
    if rc in (0, 1) and not out and not err:
        return group("aur", "AUR", "package_2", [], "ok")
    return group("aur", "AUR", "package_2", [], "error", err or out)


def system_status():
    items = []

    rc, out, _ = run(["systemctl", "is-enabled", "sysupdate.timer"], timeout=5)
    items.append(f"sysupdate.timer: {'enabled' if rc == 0 and out == 'enabled' else 'disabled'}")

    rc, out, _ = run(["systemctl", "--user", "is-enabled", "system-update.timer"], timeout=5)
    items.append(f"user system-update.timer: {'enabled' if rc == 0 and out == 'enabled' else 'disabled'}")

    rc, out, _ = run(["systemctl", "--user", "is-enabled", "system-updater.service"], timeout=5)
    items.append(f"user system-updater.service: {'enabled' if rc == 0 and out == 'enabled' else 'disabled'}")

    rc, kernel, _ = run(["uname", "-r"], timeout=5)
    if rc == 0 and kernel and not os.path.isdir(f"/usr/lib/modules/{kernel}"):
        items.append("reboot recommended: running kernel modules are no longer installed")

    rc, out, _ = run(["pacman", "-Q", "hyprland"], timeout=5)
    if rc == 0 and out:
        items.append(out)

    try:
        with open("/etc/pacman.conf", "r", encoding="utf-8") as conf:
            ignored = [
                line.split("=", 1)[1].strip()
                for line in conf
                if line.strip().startswith("IgnorePkg") and "=" in line
            ]
        if ignored:
            items.append(f"IgnorePkg: {', '.join(ignored)}")
    except OSError:
        pass

    return group("system", "System", "settings_suggest", items, "info")


def flutter_updates():
    if not have("flutter"):
        return missing("flutter", "Flutter", "flutter")
    rc, out, err = run(["flutter", "upgrade", "--verify-only"], timeout=90)
    found = lines(out)
    if rc == 0:
        if any("available" in line.lower() or "upgrade" in line.lower() for line in found):
            return group("flutter", "Flutter", "flutter", found[-12:], "updates")
        return group("flutter", "Flutter", "flutter", [], "ok")
    return group("flutter", "Flutter", "flutter", [], "error", err or out)


def dart_status():
    if not have("dart"):
        return missing("dart", "Dart", "data_object")
    rc, out, err = run(["dart", "pub", "global", "list"], timeout=20)
    if rc == 0:
        installed = lines(out)
        label = f"{len(installed)} global package(s); Dart has no global outdated check"
        return group("dart", "Dart", "data_object", [label] + installed[:20], "info")
    return group("dart", "Dart", "data_object", [], "error", err or out)


def python_updates():
    if not have("python"):
        return missing("python", "Python/pip", "python")
    rc, out, err = run(
        [sys.executable, "-m", "pip", "list", "--outdated", "--format=json", "--disable-pip-version-check"],
        timeout=60,
    )
    if rc != 0:
        return group("python", "Python/pip", "python", [], "error", err or out)
    try:
        data = json.loads(out or "[]")
    except json.JSONDecodeError:
        return group("python", "Python/pip", "python", lines(out), "updates" if out else "ok")
    found = [f"{p['name']} {p['version']} -> {p['latest_version']}" for p in data]
    return group("python", "Python/pip", "python", found, "updates" if found else "ok")


def rust_updates():
    if not have("rustup"):
        return missing("rust", "Rust", "deployed_code")
    rc, out, err = run(["rustup", "check", "--no-self-update"], timeout=45)
    found = [line for line in lines(out) if "Update available" in line or "update available" in line.lower()]
    if rc == 100 or found:
        return group("rust", "Rust", "deployed_code", found or lines(out), "updates")
    if rc == 0:
        return group("rust", "Rust", "deployed_code", [], "ok")
    return group("rust", "Rust", "deployed_code", [], "error", err or out)


def bun_updates():
    if not have("bun"):
        return missing("bun", "Bun", "bakery_dining")
    rc, out, err = run(["bun", "outdated", "--global", "--no-progress"], timeout=45)
    found = []
    for line in lines(out):
        if not line.startswith("|") or "---" in line or "Package" in line:
            continue
        parts = [part.strip() for part in line.strip("|").split("|")]
        if len(parts) >= 4 and parts[0]:
            found.append(f"{parts[0]} {parts[1]} -> {parts[3]}")
    if found:
        return group("bun", "Bun", "bakery_dining", found, "updates")
    if rc == 0:
        return group("bun", "Bun", "bakery_dining", [], "ok")
    return group("bun", "Bun", "bakery_dining", [], "error", err or out)


def npm_updates():
    if not have("npm"):
        return missing("npm", "npm", "javascript")
    rc, out, err = run(["npm", "outdated", "-g", "--depth=0", "--json"], timeout=45)
    if rc not in (0, 1):
        return group("npm", "npm", "javascript", [], "error", err or out)
    try:
        data = json.loads(out or "{}")
    except json.JSONDecodeError:
        return group("npm", "npm", "javascript", lines(out), "updates" if out else "ok")
    found = [f"{name} {meta.get('current', '?')} -> {meta.get('latest', '?')}" for name, meta in data.items()]
    return group("npm", "npm", "javascript", found, "updates" if found else "ok")


def uv_status():
    if not have("uv"):
        return missing("uv", "uv", "speed")
    rc, out, err = run(["uv", "tool", "list"], timeout=30)
    if rc != 0:
        return group("uv", "uv", "speed", [], "error", err or out)
    installed = lines(out)
    label = f"{len(installed)} uv tool(s); uv exposes upgrade, not a read-only outdated check"
    return group("uv", "uv", "speed", [label] + installed[:30], "info")


def main():
    groups = [
        pacman_updates(),
        aur_updates(),
        system_status(),
        flutter_updates(),
        dart_status(),
        python_updates(),
        rust_updates(),
        bun_updates(),
        npm_updates(),
        uv_status(),
    ]
    payload = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "groups": groups,
        "total": sum(g["count"] for g in groups if g["status"] == "updates"),
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
