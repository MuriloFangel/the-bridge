# Registro de testes

Nenhum teste local foi executado pelo gerador deste pacote.

| Data | Commit testado | Caso/roteiro | Resultado | Evidência/observação |
|---|---|---|---|---|

Registrar o SHA do código efetivamente no servidor. Salvar/push não significa reload; reload não significa teste completo de gameplay.

<!-- BEGIN BRIDGE DOC TB-20261102T064922Z-06ED614E -->
### Carregamentos relatados — 3.2

02/11/2026, horários locais (-03): às 03:36, a versão TB-20261102T063453Z-D791EED4 teve erro no evento nativo de arraste. Às 03:41:45, após TB-20261102T064126Z-C48C588D, e às 03:44:25, após TB-20261102T064403Z-D6BD7F68, os logs do administrador reportaram 17 scripts, 52 triggers e 13 comandos sem erros; Guardian 17/17 e 34/34.

São relatos de carregamento, não testes de menus, arraste, som ou gameplay. O commit exato nos instantes dos reloads não foi capturado. A main 159c3a592dcbe9310295f3bec379ffc2d1b4f4a3 e os hashes atuais foram consultados depois; não provam retroativamente o commit testado nem ausência de edição intermediária. Nenhum reload foi executado por este registro. Gameplay e passagem física de flechas por aliados permanecem pendentes.
<!-- END BRIDGE DOC TB-20261102T064922Z-06ED614E -->

<!-- BEGIN BRIDGE DOC TB-20261103T031042Z-CB189BA7 -->
### Bloco 3 — roteiro de aceitacao de gameplay

STATUS: ROTEIRO PROPOSTO; NENHUM CASO EXECUTADO POR ESTE REGISTRO. Todos os resultados permanecem PENDENTES. Nao declara implementacao, carregamento, aprovacao nem regressao confirmada.

Base documental consultada: ec3e622e20408b0ea797662699da010f1349ae4e (README.md, DECISOES.md, TESTES.md e ESTADO-ATUAL.md). Decisoes posteriores prevalecem sobre o contrato inicial. Este roteiro verifica requisitos; nao constitui auditoria integral dos scripts. O SHA efetivamente carregado no servidor continua NAO CONFIRMADO.

Preparacao: usar arena de teste ja cadastrada, sem apagar dados, recadastrar mapas ou sobrescrever schematic. Comecar em 1v1; usar 2v2 para aliados e maiorias. Marcar casos sem participantes/condicoes como BLOQUEADOS. Antes da execucao, identificar arquivos ativos e versao realmente carregada; registrar SHA, data, participantes e mapa. Se a base mudar, rever sobreposicao. Nao executar reload/restart ou mudar configuracao automaticamente. Usar comandos/botoes existentes e documentados na versao carregada; divergencia ou comando indisponivel deve ser registrada, nao contornada com comando inventado.

#### Casos, na ordem sugerida

| ID | Acao | Resultado esperado / criterio |
|---|---|---|
| T01 | Registrar carregamento autorizado e log; abrir fluxo de partida. | Distinguir carregamento sem erro de gameplay; erro de parser/runtime impede aprovar casos dependentes. |
| T02 | Abrir menus disponiveis; clicar, shift-clicar, usar tecla numerica, arrastar e fechar/reabrir. | Fluxo coerente, sem duplicar/perder itens ou retirar itens de interface indevidamente. Validar permissoes de cada tela; regra indefinida vira lacuna, nao aprovacao. |
| T03 | Iniciar 1v1 e observar kit, cores, cages, contagem e liberacao. | Times/bases corretos; cage inicial com contagem de 5 s; kit completo sem acumulo. Layout individual somente se houver implementacao confirmada. |
| T04 | Cair no void e repetir o respawn. | Retorno ao proprio time, vida/kit renovados, sem tela de morte, residuos ou kit acumulado; protecao de respawn coerente. |
| T05 | Construir/quebrar na ponte, testar limites e tentar alterar cenario/base. | Somente ponte original e argilas da sessao quebraveis; limites configurados respeitados; cenario/base protegidos. |
| T06 | Entrar no portal adversario e repetir contato; depois entrar no proprio. | Um ponto por gol valido; portal proprio apenas respawna, sem ponto ou viagem ao End. |
| T07 | Colocar/quebrar argila, marcar ponto e observar o proximo round. | Ponte e alteracoes permanecem entre pontos; cages e kits renovados; nenhum reset intermediario. |
| T08 | Testar fome, queda, dano permitido e protecao apos respawn. | Sem fome/fall damage; dano/feedback somente para ataque permitido, respeitando protecao e instancia. |
| T09 | Em 2v2, atacar aliado e atirar com aliado entre atirador e adversario. | Sem fogo amigo; flecha atravessa fisicamente o aliado e continua podendo atingir adversario valido. Cancelar dano isoladamente NAO aprova atravessamento. |
| T10 | Atirar, aguardar reposicao de 3,5 s e repetir incluindo respawn no intervalo. | Uma flecha, sem acumulo; tarefa da vida/sessao anterior nao altera o novo kit. |
| T11 | Com dano, consumir primeira e segunda maca na mesma vida; repetir apos respawn. | Cura completa, sem regeneracao; primeira concede 2 coracoes de absorcao, seguintes nao adicionam extras nem removem indevidamente o restante; respawn renova direito. |
| T12 | Em 1v1, pedir pausa durante jogada e aguardar sem voto adversario; repetir com SIM adversario. | Pedido sozinho nao congela nem para relogio. SIM de ambos inicia pausa assim que decidida, sem esperar todo o prazo, respeitando fase/cota. |
| T13 | Rejeitar/deixar expirar pedido; repetir pedidos permitidos. | Sem consumo de cota por pedido rejeitado/expirado/cancelado; sem prolongar partida; fim do tempo segue fluxo normal mesmo com pedido pendente. |
| T14 | Em 2v2, testar pausa/gol de ouro e retorno da pausa com metade exata. | Pausa/gol de ouro: pelo menos metade dos presentes de CADA time e SIM dos dois times. Retorno: mais da metade dos presentes do time solicitante; metade exata nao basta. |
| T15 | Testar votos digitados/clicaveis, presenca alterada e conclusao definida. | Ausentes por /l e offline nao contam como presentes; reavaliar quorum sem misturar sessoes. Qualquer votacao conclui ao ficar matematicamente definida sob sua politica; nao reabrir resultado concluido. Equilibrio/redistribuicao usam mais SIM que NAO entre votantes; empate/nenhum voto rejeita. |
| T16 | Tornar jogador ausente; retornar pelo fluxo existente (/retornar/botao, se implementado). | Retorno no spawn do time com kit, nao em posicao avancada. Presentes congelados por ausencia ficam no local e aguardam contagem, sem cages/respawn por esse motivo ou liberacao antecipada. |
| T17 | Deixar relogio chegar a zero com lider; repetir empatado, aprovando/rejeitando gol de ouro. | Lider vence no tempo; empate segue voto por time. Aprovado: 0:00 e proximo gol vence; rejeitado: empate final. Pedido de pausa pendente nao adia encerramento. |
| T18 | Encerrar partida e iniciar outra na instancia reutilizada. | Resultado/estatisticas uma vez; reset apenas no fim, restaurando quebrados e removendo colocados; liberar instancia somente pronta; tarefas antigas nao afetam nova sessao. |
| T19 | Com jogadores suficientes, executar duas partidas simultaneas. | Pontos, dano, projeteis, timers, blocos e reset isolados entre instancias. Falta de participantes = BLOQUEADO, nao aprovado. |

#### Evidencia e aprovacao

Para cada caso registrar: ID, SHA realmente carregado, data/hora, mapa/instancia, participantes, passos efetivos, esperado, observado, resultado (PASSOU/FALHOU/BLOQUEADO/NAO EXECUTADO) e log/video/relato correspondente. Em falha, registrar reproducao minima e impacto antes de seguir; nao atribuir regressao sem comparacao com versao anterior testada.

Prioridade inicial: T09 (atravessamento de aliados), T12-T15 (votacoes/relogio), T16 (ausencia) e T18 (reset/sessao). Nao dispensar preparacao e casos basicos para chegar a essas prioridades. Casos restantes nao executados continuam pendentes, sem aprovacao geral por amostragem. Nenhuma acao de jogo, reload ou restart foi executada ao preparar este roteiro.
<!-- END BRIDGE DOC TB-20261103T031042Z-CB189BA7 -->
