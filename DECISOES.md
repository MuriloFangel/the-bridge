# Decisões de gameplay

## Confirmadas no histórico usado para o README

- Ausente retorna no spawn do time com kit, não na posição avançada de saída.
- Presentes congelados por ausência ficam no local e aguardam contagem sem liberação antecipada; não vão às cages nem respawnam por causa da ausência.
- Kit normal de respawn não é vantagem indevida por si; evitar abuso de posição.
- Pausa solicitada exige SIM interno de ambos os times; não maioria global.
- Ponte não é resetada entre pontos.
- Referência posterior de retorno explícito: /retornar e botão clicável; conferir implementação.

## Decisões posteriores

Adicionar data, decisão exata, substituição de regra anterior e commit de implementação quando conhecido. Não inventar decisão para preencher lacuna.

### 2026-11-01 — Conclusão obrigatória quando a votação estiver decidida

Decisão explícita do administrador, posterior à especificação inicial do README:

- QUALQUER votação do projeto deve concluir e executar seu resultado assim que ele estiver matematicamente definido segundo o critério específico daquela votação. Isso inclui aprovação e rejeição quando efetivamente determinadas.
- A janela padrão de 30 segundos é um prazo máximo, não uma espera obrigatória. Não aguardar o timer se o resultado já estiver definido; também não exigir genericamente que todos tenham votado.
- Preservar os critérios distintos do README: equilíbrio inicial e redistribuição usam mais SIM que NÃO entre votantes, com empate/nenhum voto rejeitando; pausa solicitada e gol de ouro exigem SIM de pelo menos metade dos presentes de CADA time e aprovação dos DOIS times; voltar da pausa exige mais da metade dos presentes do time solicitante.
- A checagem deve ocorrer ao registrar votos e ao mudar a presença elegível, respeitando a sessão e a votação correspondentes. Offline e participante ausente por /l não são presentes elegíveis.
- A implementação precisa tratar coerentemente votos restantes, alteração de votos e mudança de eleitorado. Não introduzir voto livremente mutável como justificativa para tornar toda janela obrigatória; não presumir resultado irrevogável sem definir essa política. Resultado concluído não é reaberto por uma mudança posterior.
- No 1v1, o pedido de pausa já registra SIM do solicitante; quando o adversário também votar SIM, a pausa deve começar imediatamente, sem aguardar o restante do prazo, após as validações de fase e cota.

Esta decisão torna obrigatória para todas as votações a conclusão antecipada que o README descrevia de forma condicional. Substitui a política de janela completa obrigatória introduzida na entrega de pausas da conversa. É requisito; não constitui evidência de implementação ou teste.

### 2026-11-01 — Pedido de pausa não suspende o tempo nem a jogada

- Enquanto houver apenas um pedido de pausa em votação, o relógio regulamentar continua correndo e a jogada continua normalmente. O pedido, por si só, não ativa pausa, congelamento ou cages.
- Somente a pausa efetivamente aprovada e iniciada suspende o relógio por esse motivo. Outras causas válidas e independentes, como cages normais, ausência crítica ou votação de gol de ouro, mantêm suas próprias regras de suspensão.
- Pedidos sucessivos, rejeitados ou expirados não podem prolongar o tempo regulamentar. Não consumir cota por pedido rejeitado, expirado ou cancelado.
- Se o tempo regulamentar acabar durante um pedido ainda pendente, aplicar normalmente o encerramento por placar ou o fluxo de gol de ouro; o pedido não pode estender a partida.
- Motivo explicitado pelo administrador: impedir que pedidos de pausa sejam usados para parar o tempo enquanto o combate continua, especialmente em uma partida empatada.

Esta decisão reforça a regra já presente nas seções de relógio e pausa do README. A publicação deste texto não altera o Core, não executa reload e não aprova testes.

<!-- BEGIN BRIDGE DOC TB-20261102T064922Z-06ED614E -->
### Entregas — decisão do administrador em 02/11/2026

REQUISITO: um script alterado = somente o .sk completo no artefato. Vários scripts = um único ZIP contendo somente os .sk. Não anexar manifesto, documentação, relatório ou diff. Correções curtas podem ser entregues em bloco pronto de PowerShell, com hash da base, backup fora da árvore carregável e sem reload/restart automático; não pedir edição manual de trechos.

Manifestos/registros/propostas documentais vão diretamente para ai-deliveries após a validação combinada, com as confirmações exigidas. Impedimentos são declarados, sem gerar anexos documentais automaticamente. Esta decisão posterior prevalece sobre instruções anteriores de ZIP opcional ou anexar JSON.

Testes de gameplay ficam para o administrador ao final dos fechamentos; carregamento não é gameplay validado. Flechas atravessarem aliados continuam pendentes. A edição da fonte canônica PROMPT-NOVO-CHAT.md e sua reprodução no README ainda está pendente do fluxo de gestão; este registro não afirma alteração desses arquivos.
<!-- END BRIDGE DOC TB-20261102T064922Z-06ED614E -->

<!-- BEGIN BRIDGE DOC TB-20261103T044205Z-FB185E98 -->
### 2026-11-03 — Decisões de party anteriores à implementação

REQUISITO do administrador. Registro documental: não declara implementação, carregamento ou teste. Prioridade: party antes do modo de times; R1/R2 continuam pendentes. Não antecipar 2v2, party vs party, split, equilíbrio, redistribuição ou cages dinâmicas. Preservar gameplay e separar estado de votos da party dos votos da partida.

#### Vínculos e liderança
- Um jogador não integra duas parties. Membro offline mantém vínculo enquanto o grupo existir; reconexão não altera antiguidade, definida pela ordem de entrada.
- Se todos ficarem offline, dissolver e apagar a party e seus vínculos/processos. Preservar dados em reinício/reload, sem confundir recuperação técnica com saídas voluntárias para apagar todos os grupos. Party de uma pessoa é válida; sem membros, apagar.
- Líder desconectado tem 30s para retornar; retornando antes mantém liderança, salvo mudança válida concluída. Após substituição, retorna como membro comum. Nova desconexão inicia nova espera; timer invalidado não pode executar sucessão depois nem afetar outra party.
- Havendo outro líder conectado, após 30s retirar apenas a liderança do ausente, sem preencher vaga automaticamente. Quando não restar líder conectado após as esperas aplicáveis, assumir o integrante mais antigo conectado.
- Saída voluntária de líder não espera 30s: sucessão imediata pelo mais antigo conectado quando necessária, preservando os demais líderes.
- Comandos de transferir e adicionar liderança. Até três líderes com os mesmos poderes. Transferência somente para membro online; quem transfere continua como membro comum. Não altera antiguidade.
- Líder pode dissolver por comando, apagando o grupo e removendo todos, inclusive offline. Pode expulsar membro comum online/offline. Líderes não podem expulsar uns aos outros.

#### Convites, troca e publicidade
- Convites duram 60s; repetição avisa sem renovar prazo. Pode convidar jogador conectado já em outra party, mas não a si próprio nem jogador offline.
- Avisar destinatário já vinculado de que aceitar troca sua party. Validar destino antes de remover vínculo anterior; nunca vínculo duplo ou troca parcial.
- Pode receber convites de vários grupos; aceitar um cancela os demais. Mudança de liderança cancela convites anteriores e avisa membros. Aceite permitido com líder offline se a party existir e não houver bloqueio de votação.
- Validar novamente estado ao concluir ações simultâneas; mensagens/timers antigos não autorizam entrada em grupo dissolvido ou recriado.
- Líder pode divulgar no chat, tornando a party pública, com entrada clicável; pode torná-la privada, mantendo convites. Entrada por divulgação estando em outra party exige confirmação explícita da troca. Divulgação antiga perde validade ao privatizar/dissolver.
- Avisar membros conectados sobre convites emitidos, entradas, saídas, expulsões, liderança, acesso e consultas. Usar mensagens explicativas, cliques, timers e avisos no padrão do projeto.

#### Expulsão e revolução
- Membro comum pode pedir voto para expulsar outro membro comum; líder não é alvo. Aprovado, expulsa sem consulta/veto do líder. Mudança de comando ocorre pela revolução.
- Membro comum pode propor revolução. Aprovada, abre eleição que substitui toda liderança; antigos líderes não eleitos ficam como membros comuns.
- Expulsão e aprovação da revolução: mais SIM que NÃO entre votantes; empate/nenhum voto rejeitam. Não usar metade de cada time.
- Eleitorado conectado na abertura da consulta; candidatos online na abertura da eleição. Chat com nicks clicáveis para votar, inclusive em si mesmo.
- Prazo máximo de 30s por consulta/turno; concluir antecipadamente quando matematicamente definido segundo sua política, sem reabrir resultado concluído.

#### Eleição
- Maioria absoluta: mais da metade dos votos válidos efetivamente dados a candidatos; abstenções fora do denominador. Elege no primeiro turno.
- Sem maioria absoluta, primeiro e segundo isolados vão ao segundo turno.
- Empate em primeiro: segundo turno entre empatados em primeiro.
- Primeiro isolado com empate no segundo: primeiro vence sem segundo turno, por decisão expressa do administrador.
- Empate após segundo turno: empatados viram líderes. Em qualquer turno, mais de três empatados são limitados a três pela antiguidade. Limite aplicado ao avanço para segundo turno ou aos eleitos finais, sem converter empate inicial em eleição direta; nunca mais de três líderes.

#### Exclusão mútua e pendências
- Uma consulta por party de cada vez, incluindo turnos. Bloquear ações de alteração da party durante votação; comandos de expulsão explicitamente bloqueados inclusive para líderes. Consulta e voto continuam disponíveis. Parties diferentes não compartilham trava.
- Desconexão real não pode ser bloqueada; todos offline dissolve e invalida processos.
- PENDENTE de definição operacional: enumeração final dos demais comandos bloqueados; mudanças de eleitorado/candidatos por desconexão; alteração de votos; zero votos na eleição; interação entre bloqueio e sucessão automática. Não inventar decisões para esses ramos.
- PENDENTE: sintaxes finais dos comandos, implementação e testes. Este registro independente de código não altera scripts nem autoriza reload/restart. Propostas não aprovadas sobre filas/partidas não são promovidas a requisitos por este registro.
<!-- END BRIDGE DOC TB-20261103T044205Z-FB185E98 -->

<!-- BEGIN BRIDGE DOC TB-20261103T045209Z-6E1F3E1E -->
### 2026-11-03 — Complemento aprovado: políticas das consultas de party

REQUISITO aprovado pelo administrador após TB-20261103T044205Z-FB185E98. Complementa as pendências daquele bloco; não declara implementação, carregamento ou teste.

- Primeiro voto válido é definitivo. Solicitante não recebe SIM automático: precisa votar.
- Quem desconecta perde elegibilidade e voto naquela consulta. Reconectar não o reinsere nela. Candidato desconectado é retirado; votos nele são anulados com aviso. Se não restar candidato, cancelar a eleição sem substituir a liderança pelo resultado eleitoral.
- Eleição encerrada sem votos válidos é cancelada; liderança anterior permanece, sujeita às regras normais de ausência. Não eleger com zero votos por antiguidade.
- Sucessão cujo prazo vence durante consulta fica pendente até seu encerramento, revalidando liderança e presença. Se todos ficarem offline, dissolver imediatamente.
- Durante consulta ficam disponíveis ajuda, consulta da lista e voto. Ações de alteração da composição, liderança e acesso ficam bloqueadas, incluindo expulsão, transferência/adição de líder, nova proposta, convite/aceite/troca/entrada pública, publicidade, saída voluntária e dissolução por comando. Desconexão real não é bloqueável.

Ainda não constitui evidência de aplicação de código. Votações da party não compartilham estado nem executam resultados das votações de partida. Implementação, carregamento e testes permanecem estados separados.
<!-- END BRIDGE DOC TB-20261103T045209Z-6E1F3E1E -->
