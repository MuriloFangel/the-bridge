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
