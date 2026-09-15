# JarvOS — manual de socorro (recuperar sem reiniciar)

Quando a tela fica preta, congela ou o lockscreen trava: **não reinicie de
cara**. Troque para um TTY ou entre por SSH e use o `jarvos-rescue`.

## Entrar sem interface

- **TTY:** `Ctrl+Alt+F3` (F4, F5… se ocupado). Login `user` + senha.
- **SSH (Tailscale):** `ssh user@100.94.79.9` ou `ssh user@<ip>`.
- Para voltar à GUI: `Ctrl+Alt+F1` (Hyprland) ou F2 (greeter/Xorg do SDDM).

## Diagnóstico

```bash
jarvos-rescue            # hyprland, hyprlock, quickshell, GPU, kernel, reboot
```

## Recuperação, do menos ao mais invasivo

```bash
jarvos-rescue shell        # bar/shell sumiu: reinicia o quickshell
jarvos-rescue unlock       # lockscreen travado: mata o hyprlock e solta o lock
jarvos-rescue compositor   # Hyprland congelado: hyprctl dispatch exit (SDDM reabre)
jarvos-rescue session      # encerra a sessão; SDDM mostra o greeter
jarvos-rescue gpu          # erro "NVRM: API mismatch": recarrega os módulos NVIDIA
```

Sem o wrapper:

```bash
pkill -9 hyprlock                     # destrava o lock
loginctl unlock-session "$XDG_SESSION_ID"
hyprctl dispatch exit                 # derruba o compositor (SDDM relança)
loginctl terminate-session "$XDG_SESSION_ID"
systemctl --user restart quickshell-jarvos.service
sudo systemctl restart sddm           # reinicia greeter + sessão
```

Último recurso antes de reboot: `loginctl terminate-user user`.

## O crash do NVIDIA (o que te obrigava a reiniciar)

Um update pode trocar o userspace do driver (`nvidia-utils`, `libnvidia`) e o
módulo do kernel ficar na versão antiga em execução. Todo cliente GPU novo morre
com `NVRM: API mismatch` — inclusive o `hyprlock` (preto, sem resposta) e os
contextos Vulkan do quickshell (bar morta).

Recuperação sem reboot, quando o módulo do kernel em execução casa com o
userspace novo:

```bash
jarvos-rescue gpu
# equivale a:
sudo systemctl stop sddm
sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia
sudo modprobe nvidia
sudo systemctl start sddm
```

Se `modprobe nvidia` não carregar (kernel em execução sem módulo correspondente),
aí sim: reboot (ou boot no kernel novo / snapshot).

## Camadas de proteção

- `jarvos-gpu-ok` — retorna 1 se módulo ≠ userspace. O `lock.sh` recusa trancar
  sob mismatch e avisa por notificação; o `update-status.py` marca "reiniciar".
- `jarvos-hypr-safe` — snapshot + rollback para mudanças de config:

  ```bash
  jarvos-hypr-safe snapshot antes-do-teste
  jarvos-hypr-safe run -- <script-que-mexe-na-config>
  jarvos-hypr-safe verify
  jarvos-hypr-safe rollback            # volta o último snapshot
  ```

Snapshots em `~/.local/state/jarvos/hypr-snapshots` (últimos 10).
