# Desktop JarvOS com Omarchy

A sessão desta máquina usa a shell QuickShell do Omarchy. JarvOS mantém sua
marca, paleta, ferramentas de agentes, configuração Hyprland e tela Hyprlock
com os estratagemas chineses. `caelestia-shell` e `caelestia-cli` foram removidos.

O upstream está fixado em `7e8feb047d8e1989ba1ae1fe5d8faa38f3f5fe60`,
versão `4.0.0.alpha` da branch `quattro`, em `~/.local/share/omarchy`.
Referência: [shell upstream](https://github.com/omacom/omarchy/tree/quattro/shell).
O instalador completo e as migrações de sistema do Omarchy não fazem parte
desta integração.

## Uso

| Ação | Atalho ou comando |
|---|---|
| Menu JarvOS | `Super` ou `jarvos-shell menu` |
| Aplicativos | `Super+Space` |
| Configurações do desktop | `Super+I` |
| Ferramentas JarvOS | `Super+Shift+U` |
| Histórico de notificações | `Super+N` |
| Clipboard e emoji | `Super+V` e `Super+.` |
| Tema | `Super+Ctrl+Alt+T` |
| Wallpaper | `Super+Ctrl+Alt+W` |
| Restaurar paleta JarvOS | `jarvos-shell theme jarvos` |
| Gravar ou parar gravação | `jarvos-shell record` |
| Módulos opcionais | `jarvos-setup` |
| Verificar ou reiniciar a shell | `jarvos-shell status` / `jarvos-shell restart` |

As escolhas de tema atingem apenas a shell. O wallpaper é mantido durante
a troca de tema. Escolher outro wallpaper também atualiza a imagem do Hyprlock.
Arquivos que não são imagens são recusados antes de alterar essa configuração.
Os temas dos editores, configurações dos agentes e cores do compositor continuam
sob controle do JarvOS. `Super+U` continua retirando a janela do grupo.

## Configuração e manutenção

| Arquivo | Responsabilidade |
|---|---|
| `~/.config/omarchy/shell.json` | Layout e plugins |
| `~/.config/omarchy/plugins/jarvos.*` | Marca e botão de agentes |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Menus JarvOS |
| `~/.config/omarchy/themes/jarvos/colors.toml` | Paleta JarvOS |
| `~/.config/hypr/hyprland/custom/zz-jarvos-omarchy.conf` | Substituições dos atalhos da shell |
| `~/.config/systemd/user/quickshell-jarvos.service` | Inicialização e recuperação do processo |

`jarvos-shell-install --prepare` prepara os arquivos e guarda backup.
`--activate` também reinicia a shell e recarrega o Hyprland. Uma falha de
ativação restaura o backup. Reaplicar preserva preferências existentes do
Omarchy, enquanto atualiza os plugins JarvOS e os arquivos de integração.

Nesta instalação por código-fonte, os comandos em `~/.local/bin` apontam para
`~/JarvOS/bin`. Mantenha esse checkout no lugar. O `hypr-box` está instalado
em modo editável e também usa o checkout. Os commits são locais até uma
publicação explícita, inclusive o commit do submódulo.

Atualizações de upstream exigem revisar a nova revisão, ajustar
`share/jarvos/omarchy/upstream.commit` e validar a compatibilidade. O comando
`omarchy-update` foi bloqueado pelo adaptador desta sessão porque executaria
a manutenção de uma instalação Omarchy completa.

## Validação nesta máquina

V1. A shell reiniciou depois da remoção dos pacotes Caelestia. IPC retornou
`ok`, `hypr-box panel status` retornou `quickshell_alive: true` e o Hyprland
não relatou erros de configuração. Há uma barra e um background em cada um
dos três monitores de 1920×1080.

V2. Os painéis e o launcher criaram suas superfícies no monitor focado. O
daemon de notificações pertence ao novo processo. Tema e wallpaper foram
aplicados e a gravação de tela produziu um MP4 válido de aproximadamente
12,67 segundos. Os testes automatizados cobrem argumentos, cancelamento,
instalação repetida, rollback e a adaptação do `hypr-box`.

V3. A sessão permaneceu bloqueada durante a migração. O Hyprlock foi observado
por captura de tela. A aparência final da barra, navegação pelos pickers e
abertura de aplicativos pelo launcher ainda precisam de validação com a
sessão desbloqueada. A criação das superfícies via IPC não substitui esse teste.

R2. Este upstream é alpha. Há avisos de registro IPC duplicado entre monitores
e de depreciação `Qt.atob` ao aplicar tema. Os painéis testados responderam.
Não foram observados erros QML de carregamento na instância final.

R4. O todo da sidebar antiga, o teclado virtual e os widgets de fundo antigos
não foram portados. O código legado permanece como referência. `hypr-box`
lista apenas as ações suportadas pela shell ativa e recusa as demais.

## Rollback da migração de 2026-09-08

O backup anterior à migração e os pacotes reinstaláveis estão em
`~/.local/state/jarvos/omarchy-migration/20260908-121254`.
Os arquivos dos pacotes foram reconstruídos a partir da instalação existente
e reconhecidos por `pacman -Qp`. Não são downloads oficiais.
A remoção também criou os snapshots Snapper `5422` e `5423`.

Para voltar à sessão anterior, execute no terminal desta máquina:

```bash
migration="$HOME/.local/state/jarvos/omarchy-migration"
original="$migration/20260908-121254"
sudo pacman -U "$original/packages/caelestia-cli-1.1.0-1-local.pkg.tar.gz" \
  "$original/packages/caelestia-shell-2.0.3-1-local.pkg.tar.gz"
jarvos-shell-install --rollback "$migration/20260908-122358-209942475"
tar -xzf "$original/desktop-before.tar.gz" -C "$HOME"
systemctl --user daemon-reload
systemctl --user restart quickshell-jarvos.service
hyprctl reload
```

O rollback arquiva a configuração substituída em `after-rollback` dentro do
backup. Ele restaura a sessão, sem reverter commits do repositório ou apagar
o checkout upstream. Para uma reaplicação posterior, use o procedimento de
ativação acima. Os testes de rollback usam um HOME temporário, sem trocar
o desktop real de volta durante a validação.
