# Shell Omarchy no JarvOS

Status: execução autorizada pelo usuário em 2026-09-08.

O desktop usa a shell Omarchy no commit
`7e8feb047d8e1989ba1ae1fe5d8faa38f3f5fe60`, versão `4.0.0.alpha`,
instalada separadamente em `~/.local/share/omarchy`. As personalizações
JarvOS vivem neste repositório e na configuração do usuário.

- S1. Barra, launcher, painéis, notificações, clipboard e OSD são do Omarchy.
- S2. Marca e acessos aos agentes são extensões JarvOS. O Hyprlock existente
  continua responsável pelo bloqueio. Desabilitar lock, idle e polkit do
  Omarchy para evitar concorrência com os serviços já instalados.
- S3. Manter monitores, aplicativos, workspaces e seus atalhos. Substituir
  os atalhos que dependem da shell antiga por ações equivalentes.
- S4. Oferecer seleção de temas e wallpapers sem executar o instalador,
  as migrações de sistema ou os hooks de configuração de agentes do Omarchy.
- S5. O serviço `quickshell-jarvos.service` inicia a nova shell com caminhos
  explícitos. O pacote Caelestia só sai depois da validação funcional.
- S6. Preparar backup recuperável. Preservar o código legado como referência,
  sem iniciá-lo na sessão migrada. Não recriar uma distro ou uma ISO nesta etapa.

R2. A branch upstream é alpha. O carregamento inicial funcionou no compositor
instalado. Foram observados avisos de IPC duplicado entre monitores, cuja
relevância deve ser verificada durante os testes dos painéis.
