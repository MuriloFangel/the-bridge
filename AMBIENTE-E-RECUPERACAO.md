<!-- Bridge-Delivery-ID: TB-20261103T020722Z-E7DF76B7 -->
<!-- Bridge-Base-Commit: 7a523837c6c38f48fd61662fa5dfda09adc0d58b -->
# Ambiente The Bridge — operacao e recuperacao

Esta revisao descreve o painel; presenca dos arquivos nao comprova verificacao de uso. Painel de usuario e ponte sao separados: ponte observada na sessao 0; Explorer na sessao 1. Nao iniciar a GUI na sessao 0 e alegar que apareceu no desktop.

## Operacao proposta
- Atalho no login inicia painel com -AutoStart: contagem de 30 segundos; Cancelar impede inicio nesta sessao. Nenhum servidor, bot, launcher ou pasta e aberto antes do fim.
- Abertura manual por start.bat nao tem inicio automatico.
- O painel usa MCP autenticado somente em 127.0.0.1, lendo a chave do arquivo privado local. Nao copia nem registra credenciais no Git.
- Java, JAR, memoria e flags continuam em painel_config.json, usado pela ponte. Nao ha migracao de dependencias nem um novo iniciador de Java.
- Aguarda resposta de prontidao antes dos bots. O controlador usa a quantidade definida na configuracao local; nao executa partidas automaticamente.
- CMPack abre o launcher normal, sem argumentos inventados de versao. Processos preexistentes e filhos nao identificados nao sao assumidos.
- Pastas: F:\srv, F:\srv\vibecoding e plugins\Skript\scripts. Somente novas janelas identificadas e marcadas podem ser fechadas; nunca todos os explorer.exe.
- Encerrar usa exit dos bots e stop normal do servidor, sem matar Java/node. Componentes preexistentes sao preservados por padrao. Parar servidor preexistente exige opcao e confirmacao explicitas.
- Fechar a janela oferece encerrar ou somente fechar o painel, preservando componentes. Estado de propriedade fica privado em .git/bridge-panel e e descartado para novo boot, sem adotar PIDs antigos.

## Recuperacao
Ponte saudavel: reinicio apenas do agente, sujeito as guardas de Java/bots/tarefas. Ponte inacessivel: o painel so pode iniciar a tarefa existente se estiver Ready e nao houver processos da ponte; nunca Stop-ScheduledTask/Restart de uma arvore em execucao. Supervisor em execucao com falha de acesso exige diagnostico, nao encerramento forcado.

Tarefa historica ec8b7a69-2858-4924-8988-85a9308f6296: diretorio, script e task.json ausentes na consulta 46aa9ab3-75dc-4cd0-a171-b720f9a8c396. Causa nao determinada. Nao executar, repetir ou reconstruir sob o mesmo ID. Se o trabalho ainda for necessario, preparar tarefa nova a partir de conteudo e base reconferidos, com aprovacao propria. Tarefas posteriores preservam metadados consultaveis; isso nao prova persistencia universal.

Configuracao observada da ponte: tarefa TheBridge-Remote-v2, BootTrigger, LogonType Password, sessao 0. Nao modificar essa tarefa por conveniencia. A GUI tera entrada de login interativa separada. Evidencia de retorno apos o reboot e de reinicio do agente ja existe; nao repetir indiscriminadamente nem atribuir causa ao desaparecimento antigo.

## Evidencias e confirmacoes
O pacote teve verificacoes com substitutos e construcao de GUI sem exibir. A instalacao configura TheBridge-Ambiente.lnk no Startup do usuario Administrator e uma tarefa separada TheBridge-Painel-Manual, com token interativo e sem gatilho. Essa tarefa abre a GUI sem AutoStart e pode coordenar o fechamento normal da unica janela legada identificada, sem parar o Java por isso.

A ativacao manual grava evidencia privada de sessao, janela visivel e preservacao semantica da configuracao. Isso nao equivale a avaliacao visual do administrador nem a testes reais de inicio/parada. Consulte o manifesto, os registros de verificacao e o commit remoto.

Confirmacao do inicio no login fica para o proximo login/reinicio normal. Nao fazer reboot apenas para testar. Testes de controles reais exigem aprovacao propria. A causa da tarefa historica desaparecida permanece nao determinada; nao foi feita reinstalacao para mascarar essa incerteza. Launcher que cria outros processos nao concede propriedade desses filhos ao painel.
