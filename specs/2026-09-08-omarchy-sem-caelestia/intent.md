# Intent: terminar o JarvOS com elementos do Omarchy e sem Caelestia

Author: usuário da máquina. Status: approved em 2026-09-08.

## Problem

"Terminar minha custom Arch build. O sistema dessa máquina. Incorporar os
elementos do Omarchy, mas não perder nossa característica. Abandonar o
Caelestia."

A solicitação trata da instalação em uso e do repositório que a mantém.
Uma ISO nova não foi solicitada. O usuário aprovou adotar a shell Omarchy
com identidade e integrações JarvOS: "ótima escolha pode mandar bala".

## Proposed outcome

O JarvOS funciona nesta máquina sem depender dos pacotes `caelestia-shell`
e `caelestia-cli`. Os recursos escolhidos do Omarchy ficam integrados ao
desktop, com identidade JarvOS e atualizações que preservem as personalizações.

## Affected users and systems

O usuário desta estação Arch Linux, seu desktop Hyprland e o repositório
`/home/user/JarvOS`. A configuração ativa fica em `/home/user/.config`.

## Constraints

- C1. Preservar dados, aplicativos de trabalho e o acesso à sessão.
- C2. Preservar a marca JarvOS. A seleção visual final depende do usuário.
- C3. Tratar a tela Hyprlock com estratagemas, os atalhos, a disposição dos
  monitores e as integrações de agentes como itens a preservar até esclarecer
  as preferências.
- C4. Preparar backup e rollback antes de substituir a shell ou remover
  pacotes. Não executar o instalador completo do Omarchy sobre esta máquina
  sem revisar seus efeitos.
- C5. Validar as funções substituídas no desktop real antes de remover suas
  dependências. Manter apenas um responsável por notificações e bloqueio.
- C6. Preservar os avisos de licença dos componentes reutilizados.

## Evidence collected

- F1. A remoção já começou. A busca por `import Caelestia` não retornou
  ocorrências nos arquivos QML da shell, tanto no repositório quanto na cópia
  ativa. As duas cópias não apresentaram diferenças em `diff -rq`.
- F2. A CLI continua necessária no código atual. `services/Colours.qml`,
  `services/Wallpapers.qml`, `services/Recorder.qml` e os serviços do launcher
  ainda chamam `caelestia`. Os manifestos de pacotes ainda incluem suas
  dependências. O serviço inicia `qs -c caelestia` por um alias para `jarvos`.
- F3. A tela observada usa a configuração `config/.config/hypr/hyprlock.conf`,
  que chama `hyprlock/proverb.sh`. Essa identidade não depende de manter o
  plugin Caelestia.
- F4. O Omarchy consultado na branch `quattro` documenta uma shell QuickShell
  com barra, painéis, notificações e plugins externos. O comportamento ainda
  não foi executado nesta máquina. A revisão upstream deve ser fixada antes
  da implementação.
- R1. O port do visualizador precisa de verificação de integração se for
  preservado. `services/Audio.qml` declara `cavaProc` sem `command` e tenta
  iniciá-lo. Os testes de parser não demonstram captura de áudio funcionando.

Fontes locais: `docs/decisions/2026-08-25-drop-caelestia-plugin.md`,
`docs/decisions/2026-08-25-workspace-job-contexts.md` e
`config/.config/quickshell/jarvos/`. A decisão sobre manter `ServiceRef`,
de 2026-09-04, antecede o port presente no código e não descreve seu estado atual.

Fontes upstream: [shell e plugins](https://github.com/omacom/omarchy/tree/quattro/shell),
[barra](https://github.com/omacom/omarchy/blob/quattro/manual/05-the-top-bar.md) e
[branding](https://github.com/omacom/omarchy/blob/quattro/manual/41-branding.md).

## Baseline verification

Em 2026-09-08, `tests/run-all.sh` terminou com exit code 0. Trecho observado:

```text
Totals: 167 passed, 0 failed, 0 skipped, 0 blacklisted, 172ms
== shellcheck
  ok   no findings
```

O total acima corresponde à etapa QML. A execução completa também percorreu
as suites Bash. `hyprctl configerrors` retornou vazio e o serviço da shell
estava ativo. O trecho consultado do log apresentou avisos D-Bus de tray.
A sessão estava bloqueada, portanto launcher, áudio, gravação e painéis não
receberam validação funcional nesta etapa. Nenhuma configuração ativa foi alterada.

## Decisions

- D1. Adotar a shell do Omarchy com personalizações JarvOS separadas.
- D2. Preservar marca, Hyprlock com estratagemas, monitores, atalhos de
  aplicativos e integrações JarvOS. Usar o desenho da shell upstream como base.

A aprovação foi recebida no chat. A execução da migração está autorizada.
