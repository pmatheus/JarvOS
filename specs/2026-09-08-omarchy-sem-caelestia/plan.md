# Migração da shell

Status: migração aplicada em 2026-09-08. Aceitação visual pendente de desbloqueio.

## Files and order

- A1. Guardar a configuração ativa e o inventário de pacotes. Fixar upstream.
- A2. Criar o comando `jarvos-shell`, sua configuração, os adaptadores de
  sessão e a instalação repetível. Verificar contratos do CLI com fixtures.
- A3. Instalar a extensão visual e as entradas JarvOS. Redirecionar os
  atalhos da shell e manter os demais atalhos e o Hyprlock.
- A4. Trocar o serviço com rollback disponível. Verificar no compositor real.
- A5. Remover os pacotes Caelestia quando não forem mais usados. Atualizar os
  manifestos e registrar o procedimento de manutenção.

## Risks

R2. Compatibilidade do Omarchy alpha com esta instalação e múltiplos monitores.
R3. Comandos upstream pressupõem uwsm e podem aplicar configurações de uma
instalação Omarchy completa. Usar adaptadores e menus compatíveis com JarvOS.

## Verification

- [x] CLI: argumentos preservados, erros retornados e ausência de efeitos em help.
- [x] Instalação: backup, revisão fixada, reaplicação sem perda de preferências.
- [x] Rollback em HOME temporário, inclusive após falha ao reiniciar o serviço.
- [x] Shell: IPC responde, plugins JarvOS carregam e há uma barra por monitor.
- [x] Launcher e painéis criam superfícies no monitor focado e fecham via IPC.
- [ ] Launcher abre aplicativos por interação visual na sessão desbloqueada.
- [x] Notificações recebidas pelo processo novo. Tema e wallpaper aplicados.
- [ ] Seleção visual nos pickers de clipboard, tema e wallpaper.
- [x] Hyprlock, monitores e atalhos pessoais idênticos aos backups. Hyprland sem erros.
- [ ] Aparência da barra e acionamento físico dos atalhos com sessão desbloqueada.
- [x] Pacotes Caelestia removidos. A shell iniciou novamente sem eles.
- [x] `tests/run-all.sh` passa. Pytest do adaptador: sete testes passam. Ruff e ty passam.
- [x] Revisão independente final registrada em `review.md`, com tratamento dos apontamentos.

Backup inicial:
`~/.local/state/jarvos/omarchy-migration/20260908-121254/desktop-before.tar.gz`.

Evidência: `/tmp/jarvos-omarchy-tests-final.log`, encerrado com exit code 0.

```text
Totals: 167 passed, 0 failed, 0 skipped, 0 blacklisted, 209ms
== shellcheck
  ok   no findings
7 passed in 0.03s
All checks passed!
```

Os 167 testes são da etapa QML legada. As suites Bash também passaram,
incluindo os novos contratos de CLI, instalador e primeiro login. Os sete
testes Python validam a integração do `hypr-box`.

O serviço reiniciou após a remoção, com `MainPID=2438961`, `NRestarts=0`
e IPC `ok`. O proprietário D-Bus de notificações foi o mesmo PID.
A gravação real produziu `/tmp/jarvos-record-validation/screenrecording-2026-09-08_12-36-01.mp4`,
com 12,666667 segundos e 264117 bytes verificados por ffprobe.

Após os ajustes de revisão, o serviço reiniciou com `MainPID=2496322` e IPC
`ok`. O painel weather passou a responder. O PATH desse processo resolve
`jarvos-shell` e `jarvos-agent-pick` dentro do checkout JarvOS.

Os itens em aberto dependem da sessão desbloqueada. Foi solicitado o desbloqueio
no chat. Não foi tentado contornar a tela de bloqueio. O procedimento de
manutenção, limitações e rollback está em `docs/omarchy-shell.md`.
