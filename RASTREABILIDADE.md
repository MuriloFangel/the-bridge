<!-- Bridge-Delivery-ID: TB-20261101T042032Z-817D9FCD -->
<!-- Bridge-Base-Commit: c8c885abe4700d57c6dbd846699eb59b6f078840 -->
# Rastreabilidade de entregas — protocolo v1

## Referências e separação

- main: conteúdo realmente salvo no PC e enviado pelo sincronizador.
- ai-deliveries: registros de arquivos GERADOS. Não é código instalado nem branch de desenvolvimento.
- ai-deliveries/entregas/<ID>.json: registro imutável de proposta. Nunca alterar o mesmo ID para corrigir uma entrega.
- main/RASTREABILIDADE/recebidas/<ID>.json: cópia opcional salva pelo administrador junto da entrega; fallback quando a IA não puder gravar o ledger.
- main/RASTREABILIDADE/observacoes/<fingerprint>-<ocorrencia>.json: retrato produzido LOCALMENTE, antes de um commit, sem inventar validação.
- .git/bridge-trace/: cache e recibo local de push, não versionados.

O GitHub não consulta o PC sozinho. A IA não monitora entre mensagens. O sincronizador faz a observação quando está rodando. O acesso de outra IA ao repositório precisa existir; instrução não concede permissão.

## IDs e arquivos

Formato TB-AAAAMMDDTHHMMSSZ-XXXXXXXX, UTC com segundos e sufixo de oito dígitos hexadecimais aleatórios. Não atribuir IDs retroativos a arquivos antigos sem registro: permanecem de origem não identificada.

Arquivos alterados com suporte a comentários recebem Bridge-Delivery-ID e Bridge-Base-Commit. Arquivos intactos mantêm seus IDs. JSON e formatos de terceiros não recebem comentários/campos extras: o manifesto associa os caminhos. Não modificar o jogo só para etiquetar sete módulos.

## Hash normativo: utf8-lf-no-bom-v1

Ler os bytes, exigir UTF-8 válido, remover apenas BOM UTF-8 inicial, normalizar CRLF e CR para LF, reencodar UTF-8 sem BOM e calcular SHA-256 hexadecimal minúsculo. Não aparar espaços, não mudar acentos, não remover newline final. O cabeçalho faz parte do hash. Se não for UTF-8 válido, não declarar correspondência normalizada. O relatório também guarda hash bruto dos bytes do índice.

A IA deve calcular após FINALIZAR os arquivos. Alterar o código depois de calcular invalida o manifesto. Campos ilustrativos ou hashes inventados não são aceitos.

## Esquema de manifesto v1

Campos obrigatórios para o verificador: schema_version=1; delivery_id; status="GERADA"; created_at; base_commit (SHA completo); objective; hash_algorithm="utf8-lf-no-bom-v1"; files (array não vazio de {path, sha256_normalized_utf8_lf}).

Campos descritivos que a IA deve preencher: changes, must_preserve, dependencies, tests_performed, tests_pending, relates_to. Paths são relativos ao repositório, com /, sem .., sem drive e sem .git. Não incluir o próprio manifesto na lista a hashear.

Registro GERADA é uma alegação da origem, não prova de que usuário recebeu ou aplicou. Não inserir applied_commit fictício. Se registro remoto falhou, entregar JSON e declarar pendência. A escrita remota exige ferramenta e confirmação; o prompt não contorna essa exigência.

## Resultados de observação

- CORRESPONDENCIA_INTEGRAL: todos os arquivos declarados no manifesto estão no índice com hashes iguais.
- CORRESPONDENCIA_PARCIAL: somente parte dos arquivos coincide.
- ID_COM_CONTEUDO_DIVERGENTE: há cabeçalho daquele ID, mas nem todos os arquivos correspondem.
- SEM_CORRESPONDENCIA: nenhum arquivo coincide e nenhum cabeçalho do ID foi identificado.

Correspondência é de conteúdo. Não significa reload, adoção consciente, ausência de bugs ou teste. JSON idêntico pode corresponder a múltiplas propostas; não inventar uma origem única. Manifesto não é assinatura criptográfica nem mecanismo de autorização.

Arquivos sem registro permanecem sincronizáveis; o sistema registra a lacuna, sem falsificar metadados. Entregas parciais/divergentes são informadas; esta versão NÃO bloqueia automaticamente todo commit por isso. Para entrega de vários módulos, pare o sincronizador, salve todos e o manifesto e reinicie; quiet time não é transação de arquivos.

## Associação ao commit, sem autorreferência

A observação é produzida a partir do ÍNDICE Git e entra no mesmo commit que o snapshot. Seu campo base_commit_at_observation é HEAD ANTES desse commit, não o SHA resultante. A observação não contém seu próprio commit final (isso seria autorreferência).

A IA identifica a observação na árvore do commit e confere os arquivos naquele SHA. Para localizar quando um registro apareceu: histórico Git do caminho da observação. Depois de push, o helper salva .git/bridge-trace/ultimo-envio.json com o SHA real. Esse recibo é local e não gera outro commit, evitando loop de autosave.

O cache de fingerprint ignora a pasta de observações: gerar observação não gera observação infinita. Timestamp só muda quando o snapshot ou ledger efetivamente muda. Voltar a um snapshot antigo cria nova ocorrência, preservando a linha do tempo da reversão.

## Histórico/testes

A geração cria um registro imutável. A aplicação é verificada pela árvore e hashes. Teste só por relato/log e roteiro ligado ao commit exato. Registrar em TESTES.md: ID, SHA, casos, resultado (inclusive parcial) e evidência. Não inferir do push nem modificar registro original para dizer que foi testado.

Não usar registros para aplicar código automaticamente. Se a main avançar, conferir sobreposição antes de entregar. Regressão exige comparar comportamento/código anterior e novo, não só comentários de ID.

## Instalação e operação

O instalador adiciona helper, protocolo e prompt; integra dois hooks no sincronizador existente, sem substituí-lo inteiro e sem mudar .gitignore ou scripts do Minecraft. Confere o blob esperado do sincronizador e a igualdade local/main remota. Preserva backups em .git. Requer monitor parado.

Durante a instalação, com confirmação, cria a branch ai-deliveries se ausente usando um repositório temporário separado. Se já existe, acrescenta apenas novo registro e preserva os anteriores. Não troca checkout da pasta do servidor e não escreve código na main remotamente. O registro inicial fica GERADA, ainda sem alegar envio do código.

Arquivos locais novos entram na main pelo sincronizador normal. O README ganha uma nota sem substituir gameplay. O verificador busca ledger no máximo uma vez por minuto; outras alterações podem levar esse tempo para aparecer. Fetch/cache desatualizado é informado, não chamado de informação ao vivo. Os registros locais recebidos ajudam quando há falha de acesso. Registros malformados fazem o verificador parar para revisão, não inventar campos.

A versão 1 registra evidência estática, não certificação. Não foram realizados testes em Windows/Minecraft pelo gerador deste pacote. Os testes anexados cobrem regras de hash/classificação e fluxo Git em ambiente temporário, não execução PowerShell real.
