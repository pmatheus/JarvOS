#!/usr/bin/env python3
import json
import os
import pty
import re
import select
import shutil
import subprocess
import sys
from datetime import datetime

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\([A-Za-z]")

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
os.environ["PATH"] = ":".join([p for p in EXTRA_PATHS if p]) + ":" + os.environ.get("PATH", "")
os.environ["JARVOS_ASSUME_YES"] = "1"
os.environ["JARVOS_UPDATE_TRANSCRIPT"] = "/tmp/jarvos-update.log"
os.environ["NO_COLOR"] = "1"

script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

try:
    from update_status import reboot_status
except ImportError:
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("update_status", os.path.join(script_dir, "update-status.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        reboot_status = mod.reboot_status
    except Exception:
        def reboot_status():
            return {"required": False, "reasons": [], "scheduled": False, "scheduled_time": "", "scheduled_mode": "", "scheduled_seconds_left": 0}


def emit(evt_type, **kwargs):
    payload = {"type": evt_type, **kwargs}
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def clean_line(text):
    return ANSI_RE.sub("", text or "").strip()


def run_cmd(cmd, phase_name, phase_desc):
    emit("phase", phase=phase_name, text=phase_desc)

    master, slave = pty.openpty()
    try:
        proc = subprocess.Popen(
            cmd,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
            env=os.environ,
        )
    finally:
        os.close(slave)

    buf = ""
    while True:
        try:
            r, _, _ = select.select([master], [], [], 0.2)
        except (ValueError, OSError):
            break

        if master in r:
            try:
                data = os.read(master, 2048)
                if not data:
                    break
                text = data.decode("utf-8", errors="replace")
                buf += text
                while "\n" in buf or "\r" in buf:
                    idx_n = buf.find("\n")
                    idx_r = buf.find("\r")
                    if idx_n != -1 and (idx_r == -1 or idx_n < idx_r):
                        line, buf = buf[:idx_n], buf[idx_n + 1 :]
                    else:
                        line, buf = buf[:idx_r], buf[idx_r + 1 :]

                    cl = clean_line(line)
                    if cl:
                        emit("log", line=cl)
            except OSError:
                break
        elif proc.poll() is not None:
            break

    try:
        os.close(master)
    except OSError:
        pass

    rc = proc.wait()
    if buf:
        cl = clean_line(buf)
        if cl:
            emit("log", line=cl)

    return rc


def update_system():
    cmd = ["jarvos-update", "-y"]
    if not shutil.which("jarvos-update"):
        local_bin = os.path.expanduser("~/.local/bin/jarvos-update")
        if os.path.exists(local_bin):
            cmd = [local_bin, "-y"]
    return run_cmd(cmd, "system", "Atualizando pacotes do sistema (pacman & AUR)...")


def update_devtools():
    tools = [
        ("rustup", ["rustup", "update"], "Rust (rustup)"),
        ("uv", ["uv", "tool", "upgrade", "--all"], "Python Tools (uv)"),
        ("flutter", ["flutter", "upgrade"], "Flutter SDK"),
        ("bun", ["bun", "upgrade"], "Bun Runtime"),
    ]

    total_rc = 0
    for name, cmd, label in tools:
        if shutil.which(name):
            rc = run_cmd(cmd, "devtools", f"Atualizando {label}...")
            if rc != 0:
                total_rc = rc
    return total_rc


def main():
    mode = "--system"
    for arg in sys.argv[1:]:
        if arg in ("--all", "--system", "--devtools"):
            mode = arg
            break

    emit("phase", phase="init", text="Iniciando atualização...")

    overall_success = True

    if mode in ("--system", "--all"):
        rc_sys = update_system()
        if rc_sys != 0:
            overall_success = False

    if mode in ("--devtools", "--all") and overall_success:
        rc_dev = update_devtools()
        if rc_dev != 0:
            overall_success = False

    # Check fresh reboot status after transaction
    try:
        reb = reboot_status()
        emit(
            "reboot",
            required=reb.get("required", False),
            reasons=reb.get("reasons", []),
            scheduled=reb.get("scheduled", False),
            scheduled_time=reb.get("scheduled_time", ""),
            scheduled_mode=reb.get("scheduled_mode", ""),
            scheduled_seconds_left=reb.get("scheduled_seconds_left", 0),
        )
    except Exception as exc:
        emit("log", line=f"Erro ao verificar reinício: {exc}")

    if overall_success:
        emit("phase", phase="done", text="Atualização concluída com sucesso!")
        emit("done", success=True)
    else:
        emit("phase", phase="error", text="A atualização encontrou avisos ou erros.")
        emit("done", success=False)


if __name__ == "__main__":
    main()
