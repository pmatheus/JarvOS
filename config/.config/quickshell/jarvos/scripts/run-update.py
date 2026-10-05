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
os.environ["NO_COLOR"] = "1"
# JARVOS_UPDATE_TRANSCRIPT is deliberately NOT set here: it is jarvos-update's
# recursion guard for its own `exec script`, so presetting it suppressed the
# very transcript it names and left a GUI-launched update with no post-mortem.
TRANSCRIPT = "/tmp/jarvos-update.log"
os.environ.pop("JARVOS_UPDATE_TRANSCRIPT", None)

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
    # The toolchain list lives in jarvos-update-devtools, shared with the daily
    # timer, so the panel button and the automatic run cannot drift apart.
    cmd = ["jarvos-update-devtools"]
    if not shutil.which("jarvos-update-devtools"):
        local_bin = os.path.expanduser("~/.local/bin/jarvos-update-devtools")
        if not os.path.exists(local_bin):
            emit("log", line="jarvos-update-devtools não encontrado")
            return 1
        cmd = [local_bin]
    return run_cmd(cmd, "devtools", "Atualizando ferramentas de desenvolvimento (rust, uv, bun, npm, flutter)...")


SYSTEM_OUTCOMES = {
    "ok": None,
    "partial": "O sistema foi atualizado, mas algo ficou para trás (AUR ou checkout).",
    "rolled-back": "A atualização falhou e o sistema foi revertido ao snapshot anterior.",
    "offline": "Sem conexão com os espelhos de pacotes; nada foi alterado.",
    "failed": "A atualização falhou e não pôde ser revertida automaticamente.",
}


def report_system_outcome():
    path = os.path.join(
        os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
        "jarvos", "reports", "last-update.json",
    )
    try:
        with open(path, encoding="utf-8") as fh:
            report = json.load(fh)
    except (OSError, ValueError):
        return
    message = SYSTEM_OUTCOMES.get(report.get("outcome"))
    if message:
        problems = ", ".join(report.get("problems") or [])
        emit("log", line=message + (f" ({problems})" if problems else ""))


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
            emit("log", line=f"Falha na atualização do sistema (código {rc_sys}). Transcrição: {TRANSCRIPT}")
        report_system_outcome()

    # Not gated on the system update: the two halves are independent, and a
    # failed AUR build must not silently cost the devtools their pass.
    if mode in ("--devtools", "--all"):
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
