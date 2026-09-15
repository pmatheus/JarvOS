#!/usr/bin/env python3
import concurrent.futures
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


def reboot_status():
    reboot_required = False
    reasons = []

    rc, kernel, _ = run(["uname", "-r"], timeout=5)
    if rc == 0 and kernel and not os.path.isdir(f"/usr/lib/modules/{kernel}"):
        reboot_required = True
        reasons.append(f"Módulos do kernel ({kernel}) foram removidos após atualização do pacote linux.")

    for pkg in ["linux", "linux-lts", "linux-zen", "linux-hardened"]:
        rc, out, _ = run(["pacman", "-Q", pkg], timeout=5)
        if rc == 0 and out.strip():
            parts = out.strip().split()
            if len(parts) == 2:
                pkg_ver = parts[1]
                norm_pkg = pkg_ver.replace(".", "-").replace("_", "-")
                norm_run = (kernel or "").replace(".", "-").replace("_", "-")
                if norm_pkg != norm_run and not norm_run.startswith(norm_pkg):
                    reboot_required = True
                    reasons.append(f"Novo pacote de kernel instalado: {parts[0]} {pkg_ver} (em execução: {kernel}).")

    for marker in ["/run/reboot-required", "/var/run/reboot-required"]:
        if os.path.exists(marker):
            reboot_required = True
            reasons.append(f"Sinalizador {marker} presente.")

    # NVIDIA driver half-applied: userspace updated while the running kernel
    # still holds the old module. Every GPU client then dies with "NVRM: API
    # mismatch" (hyprlock included), so flag the reboot before locking.
    nvram = "/proc/driver/nvidia/version"
    if os.path.exists(nvram):
        try:
            with open(nvram, encoding="utf-8", errors="ignore") as f:
                text = f.read()
            match = re.search(r"NVRM version:.*?([0-9]+\.[0-9]+\.[0-9]+)", text)
            module_version = match.group(1) if match else ""
            rc, out, _ = run(["pacman", "-Q", "nvidia-utils"], timeout=5)
            parts = out.split()
            userspace_version = parts[1].rsplit("-", 1)[0] if rc == 0 and len(parts) >= 2 else ""
            if module_version and userspace_version and module_version != userspace_version:
                reboot_required = True
                reasons.append(
                    f"Driver NVIDIA atualizado ({userspace_version}) mas o módulo em execução é "
                    f"{module_version}; reinicie antes de trancar a tela."
                )
        except Exception:
            pass

    state_dir = os.environ.get("JARVOS_STATE", os.path.expanduser("~/.local/state/jarvos"))
    if os.path.isdir(state_dir):
        for f in os.listdir(state_dir):
            if f.startswith("restart-") and f.endswith("-required"):
                srv = f[len("restart-"):-len("-required")]
                reboot_required = True
                reasons.append(f"Serviço '{srv}' requer reinicialização.")

    scheduled = False
    scheduled_time = ""
    scheduled_mode = ""
    scheduled_msg = ""
    scheduled_seconds_left = 0

    sched_file = "/run/systemd/shutdown/scheduled"
    if os.path.exists(sched_file):
        try:
            with open(sched_file, "r", encoding="utf-8") as f:
                sched_data = {}
                for line in f:
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        sched_data[k] = v
                if "USEC" in sched_data:
                    usec = int(sched_data["USEC"])
                    target_epoch = usec / 1_000_000
                    now_epoch = datetime.now().timestamp()
                    seconds_left = max(0, int(target_epoch - now_epoch))
                    dt = datetime.fromtimestamp(target_epoch)
                    scheduled_time = dt.strftime("%H:%M:%S")
                    scheduled_seconds_left = seconds_left
                    scheduled = True
                scheduled_mode = sched_data.get("MODE", "reboot")
                raw_msg = sched_data.get("WALL_MESSAGE", "")
                scheduled_msg = raw_msg.encode("utf-8").decode("unicode_escape", errors="ignore")
        except Exception:
            pass

    return {
        "required": reboot_required,
        "reasons": reasons,
        "scheduled": scheduled,
        "scheduled_time": scheduled_time,
        "scheduled_mode": scheduled_mode,
        "scheduled_message": scheduled_msg,
        "scheduled_seconds_left": scheduled_seconds_left,
    }


def main():
    if "--reboot-only" in sys.argv:
        print(json.dumps({"reboot": reboot_status()}, ensure_ascii=False))
        return

    check_funcs = [
        pacman_updates,
        aur_updates,
        system_status,
        flutter_updates,
        dart_status,
        python_updates,
        rust_updates,
        bun_updates,
        npm_updates,
        uv_status,
    ]

    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(check_funcs)) as executor:
        futures = {executor.submit(fn): fn for fn in check_funcs}
        for future in concurrent.futures.as_completed(futures):
            fn = futures[future]
            try:
                results[fn] = future.result()
            except Exception as exc:
                results[fn] = group(fn.__name__, fn.__name__, "error", [], "error", str(exc))

    groups = [results[fn] for fn in check_funcs]
    reboot = reboot_status()

    payload = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "groups": groups,
        "total": sum(g["count"] for g in groups if g["status"] == "updates"),
        "reboot": reboot,
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
