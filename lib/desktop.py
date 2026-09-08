"""JarvOS desktop operations. Legacy state paths preserve existing preferences."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import secrets
import select
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "share/jarvos"
if not ASSETS.is_dir():
    ASSETS = Path("/usr/share/jarvos")
VARIANTS = {
    name: "scheme-" + suffix
    for name, suffix in (
        ("tonalspot", "tonal-spot"),
        ("fruitsalad", "fruit-salad"),
        *[
            (name, name)
            for name in (
                "vibrant",
                "expressive",
                "fidelity",
                "content",
                "rainbow",
                "neutral",
                "monochrome",
            )
        ],
    )
}


def state_dir() -> Path:
    return Path(
        os.environ.get(
            "JARVOS_DESKTOP_STATE",
            str(
                Path(
                    os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
                )
                / "caelestia"
            ),
        )
    )


def run(args: list[str], **kwargs) -> str:
    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        timeout=kwargs.pop("timeout", 30),
        check=False,
        **kwargs,
    )
    if result.returncode:
        raise RuntimeError(
            result.stderr.strip() or f"{args[0]} exited with {result.returncode}"
        )
    return result.stdout.strip()


def atomic(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as tmp:
        tmp.write(value)
        name = tmp.name
    os.replace(name, path)


def current_scheme() -> dict:
    path = state_dir() / "scheme.json"
    if path.is_file():
        return json.loads(path.read_text())
    return json.loads((ASSETS / "schemes/jarvos/default/dark.json").read_text())


def current_wallpaper() -> Path:
    path = state_dir() / "wallpaper/path.txt"
    if not path.is_file():
        raise ValueError("Select a wallpaper first.")
    return Path(path.read_text().strip()).expanduser()


def migrate_preferences() -> None:
    """Translate saved launcher commands without replacing user preferences."""
    config = (
        Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
        / "caelestia/shell.json"
    )
    if not config.is_file():
        return
    original = config.read_text()
    prefs = json.loads(original)
    changed = False
    for action in prefs.get("launcher", {}).get("actions", []):
        command = action.get("command", [])
        if (
            len(command) > 1
            and command[0] == "caelestia"
            and command[1] in ("scheme", "wallpaper", "record", "shell")
        ):
            command[0] = "jarvos-desktop"
            changed = True
    if changed:
        backup = config.with_name("shell.pre-jarvos-desktop.json")
        if not backup.exists():
            atomic(backup, original)
        atomic(config, json.dumps(prefs, indent=2) + "\n")


def generate(
    image: Path | None,
    variant: str,
    mode: str,
    flavour: str,
    *,
    seed: str | None = None,
) -> dict:
    if variant not in VARIANTS or mode not in ("dark", "light"):
        raise ValueError("Unsupported palette variant or mode.")
    generator = (
        ROOT / "config/.config/quickshell/scripts/colors/generate_colors_material.py"
    )
    if not generator.is_file():
        generator = (
            ASSETS
            / "config/.config/quickshell/scripts/colors/generate_colors_material.py"
        )
    cmd = [
        "uv",
        "run",
        "--no-project",
        "--python",
        "/usr/bin/python3",
        str(generator),
        "--mode",
        mode,
        "--scheme",
        VARIANTS[variant],
    ]
    cmd += ["--color", seed] if seed else ["--path", str(image)]
    output = run(cmd)
    # Preserve extra terminal/accent tokens not produced by the M3 generator.
    colours = dict(current_scheme()["colours"])
    generated = dict(
        re.findall(r"^\$([\w]+): #([0-9A-Fa-f]{6});$", output, re.MULTILINE)
    )
    if not {"primary", "surface", "onSurface"} <= generated.keys():
        raise RuntimeError(
            "The palette generator did not return the shell colour contract."
        )
    colours.update({key: value.lower() for key, value in generated.items()})
    return {
        "name": "dynamic",
        "flavour": flavour,
        "mode": mode,
        "variant": variant,
        "colours": colours,
    }


def catalog() -> dict:
    result = {}
    for path in sorted((ASSETS / "schemes").glob("*/*/*.json")):
        scheme = json.loads(path.read_text())
        result.setdefault(scheme["name"], {}).setdefault(
            scheme["flavour"], scheme["colours"]
        )
    result["dynamic"] = {
        current_scheme().get("flavour", "mocha"): current_scheme()["colours"]
    }
    return result


def select_scheme(name=None, flavour=None, mode=None, variant=None) -> dict:
    previous = current_scheme()
    name = name or previous["name"]
    flavour = flavour or previous.get("flavour", "mocha")
    mode = mode or previous.get("mode", "dark")
    variant = variant or previous.get("variant", "tonalspot")
    if any(not re.fullmatch(r"[a-z0-9_-]+", value) for value in (name, flavour)):
        raise ValueError("Invalid palette name.")
    if name == "dynamic":
        scheme = generate(current_wallpaper(), variant, mode, flavour)
    else:
        candidates = sorted((ASSETS / "schemes" / name / flavour).glob("*.json"))
        requested = ASSETS / "schemes" / name / flavour / f"{mode}.json"
        if not candidates:
            raise ValueError(f"Unknown palette: {name}/{flavour}")
        scheme = json.loads(
            (requested if requested.is_file() else candidates[0]).read_text()
        )
        if scheme["mode"] != mode:
            generated = generate(
                None, variant, mode, flavour, seed="#" + scheme["colours"]["primary"]
            )
            scheme["colours"] = generated["colours"]
        scheme.update(mode=mode, variant=variant)
    atomic(state_dir() / "scheme.json", json.dumps(scheme))
    return scheme


def wallpaper(path: Path, preview=False) -> dict:
    path = path.expanduser().resolve(strict=True)
    if not run(["file", "-b", "--mime-type", "--", str(path)]).startswith("image/"):
        raise ValueError("Wallpaper must be an image.")
    previous = current_scheme()
    scheme = generate(
        path,
        previous.get("variant", "tonalspot"),
        previous.get("mode", "dark"),
        previous.get("flavour", "mocha"),
    )
    if preview:
        return scheme
    run(["awww", "img", "--transition-type", "fade", "--", str(path)])
    if previous["name"] == "dynamic":
        atomic(state_dir() / "scheme.json", json.dumps(scheme))
    atomic(state_dir() / "wallpaper/path.txt", str(path))
    target = Path.home() / ".cache/hyprlock-wallpaper"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + "." + secrets.token_hex(6))
    temporary.symlink_to(path)
    temporary.replace(target)
    return scheme


def ipc(args: list[str]) -> str:
    config = os.environ.get(
        "JARVOS_SHELL_PATH", str(Path.home() / ".config/quickshell/jarvos/shell.qml")
    )
    output = run(["qs", "-p", config, "ipc", "call", "--", *args], timeout=5)
    if (
        output.startswith(
            (
                "Target not found",
                "Function not found",
                "Too few arguments",
                "Too many arguments",
                "Not ready",
            )
        )
        or output == "unknown"
    ):
        raise RuntimeError(output)
    return output


def process_ticks(pid: int) -> str:
    return Path(f"/proc/{pid}/stat").read_text().rpartition(")")[2].split()[19]


def record_status() -> dict:
    path = state_dir() / "recorder.json"
    if path.is_file():
        saved = json.loads(path.read_text())
        pid = saved.get("pid", 0)
        try:
            if Path(f"/proc/{pid}/exe").resolve(
                strict=True
            ).name == "gpu-screen-recorder" and process_ticks(pid) == saved.get(
                "start_ticks"
            ):
                end = saved.get("paused_at") or time.monotonic()
                return {
                    **saved,
                    "running": True,
                    "elapsed": max(
                        0, end - saved["started"] - saved.get("paused_seconds", 0)
                    ),
                }
        except (OSError, IndexError):
            pass
    return {"running": False, "paused": False, "elapsed": 0}


def record(stop=False, pause=False, region=False, sound=False) -> dict:
    saved = record_status()
    if saved["running"]:
        fd = os.pidfd_open(saved["pid"])
        try:
            if process_ticks(saved["pid"]) != saved["start_ticks"]:
                raise RuntimeError("The recorder process changed.")
            signal.pidfd_send_signal(fd, signal.SIGUSR2 if pause else signal.SIGINT)
            if pause:
                saved["paused"] = not saved.get("paused", False)
                now = time.monotonic()
                if saved["paused"]:
                    saved["paused_at"] = now
                else:
                    saved["paused_seconds"] = (
                        saved.get("paused_seconds", 0) + now - saved.pop("paused_at")
                    )
                atomic(state_dir() / "recorder.json", json.dumps(saved))
            else:
                if not select.select([fd], [], [], 10)[0]:
                    raise RuntimeError("Recorder is still finalizing the output.")
        finally:
            os.close(fd)
        return record_status()
    if stop or pause:
        return saved
    # Avoid two owners and never signal somebody else's recorder.
    if (
        subprocess.run(
            ["pidof", "gpu-screen-recorder"], capture_output=True, check=False
        ).returncode
        == 0
    ):
        raise RuntimeError("A recorder outside JarvOS is already running.")
    cmd = ["gpu-screen-recorder", "-c", "mp4", "-f", "60", "-k", "h264"]
    if region:
        result = subprocess.run(
            ["slurp", "-f", "%wx%h+%x+%y"], capture_output=True, text=True, check=False
        )
        if result.returncode or not result.stdout.strip():
            return saved
        geometry = result.stdout.strip()
        if not re.fullmatch(r"\d+x\d+\+-?\d+\+-?\d+", geometry):
            raise ValueError("Invalid capture geometry.")
        cmd += ["-w", "region", "-region", geometry]
    else:
        monitors = json.loads(run(["hyprctl", "-j", "monitors"]))
        focused = next(
            (monitor for monitor in monitors if monitor.get("focused")), monitors[0]
        )
        cmd += ["-w", focused["name"]]
    if sound:
        cmd += ["-a", "default_output"]
    directory = Path(
        os.environ.get("JARVOS_RECORDINGS_DIR")
        or os.environ.get("CAELESTIA_RECORDINGS_DIR")
        or str(
            Path(os.environ.get("XDG_VIDEOS_DIR", str(Path.home() / "Videos")))
            / "Recordings"
        )
    ).expanduser()
    directory.mkdir(parents=True, exist_ok=True)
    output = directory / (
        "recording_"
        + time.strftime("%Y-%m-%d_%H-%M-%S")
        + "_"
        + secrets.token_hex(3)
        + ".mp4"
    )
    state_dir().mkdir(parents=True, exist_ok=True)
    with (state_dir() / "recorder.log").open("ab") as log:
        child = subprocess.Popen(
            [*cmd, "-o", str(output)], stdout=log, stderr=log, start_new_session=True
        )
    try:
        child.wait(timeout=0.3)
    except subprocess.TimeoutExpired:
        saved = {
            "pid": child.pid,
            "start_ticks": process_ticks(child.pid),
            "started": time.monotonic(),
            "paused": False,
            "paused_seconds": 0,
            "file": str(output),
        }
        atomic(state_dir() / "recorder.json", json.dumps(saved))
        return record_status()
    raise RuntimeError(f"Recording failed. See {state_dir() / 'recorder.log'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    scheme = sub.add_parser("scheme")
    schemes = scheme.add_subparsers(dest="operation", required=True)
    schemes.add_parser("list")
    get = schemes.add_parser("get")
    get.add_argument("-n", action="store_true")
    get.add_argument("-f", action="store_true")
    get.add_argument("-v", action="store_true")
    set_parser = schemes.add_parser("set")
    set_parser.add_argument("-n", "--name")
    set_parser.add_argument("-f", "--flavour")
    set_parser.add_argument("-v", "--variant", choices=list(VARIANTS))
    set_parser.add_argument("-m", "--mode", choices=["dark", "light"])
    set_parser.add_argument("--notify", action="store_true")
    wall = sub.add_parser("wallpaper")
    wall.add_argument("-f", "--file", type=Path)
    wall.add_argument("-p", "--preview", type=Path)
    wall.add_argument("-r", "--random", action="store_true")
    wall.add_argument("--no-smart", action="store_true")
    shell = sub.add_parser("shell")
    shell.add_argument("args", nargs=argparse.REMAINDER)
    rec = sub.add_parser("record")
    rec.add_argument("--status", action="store_true")
    rec.add_argument("--stop", action="store_true")
    rec.add_argument("-p", "--pause", action="store_true")
    rec.add_argument("-r", "--region", action="store_true")
    rec.add_argument("-s", "--sound", action="store_true")
    args = parser.parse_args()
    if args.command == "init":
        migrate_preferences()
        state_dir().mkdir(parents=True, exist_ok=True)
        if not (state_dir() / "scheme.json").exists():
            atomic(state_dir() / "scheme.json", json.dumps(current_scheme()))
    elif args.command == "shell":
        print(ipc(args.args))
    elif args.command == "scheme":
        if args.operation == "list":
            print(json.dumps(catalog()))
        elif args.operation == "get":
            current = current_scheme()
            fields = [
                key
                for flag, key in (
                    (args.n, "name"),
                    (args.f, "flavour"),
                    (args.v, "variant"),
                )
                if flag
            ]
            print(
                "\n".join(current.get(key, "tonalspot") for key in fields)
                if fields
                else json.dumps(current)
            )
        else:
            select_scheme(args.name, args.flavour, args.mode, args.variant)
    elif args.command == "wallpaper":
        path = args.preview or args.file
        if args.random:
            config = (
                Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
                / "caelestia/shell.json"
            )
            prefs = json.loads(config.read_text()) if config.is_file() else {}
            directory = Path(
                prefs.get("paths", {}).get(
                    "wallpaperDir", str(Path.home() / "Pictures/Wallpapers")
                )
            ).expanduser()
            choices = [
                file
                for file in directory.rglob("*")
                if file.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
                and file.is_file()
            ]
            if not choices:
                raise ValueError("No wallpapers found.")
            path = secrets.choice(choices)
        if not path:
            raise ValueError("Provide a wallpaper file.")
        result = wallpaper(path, bool(args.preview))
        if args.preview:
            print(json.dumps(result))
    elif args.command == "record":
        if args.status:
            result = record_status()
        else:
            state_dir().mkdir(parents=True, exist_ok=True)
            with (state_dir() / "recorder.lock").open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                result = record(args.stop, args.pause, args.region, args.sound)
        print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"jarvos-desktop: {error}", file=sys.stderr)
        sys.exit(1)
