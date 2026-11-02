<!-- Bridge-Delivery-ID: TB-20261102T061136Z-1D382738 -->
<!-- Bridge-Base-Commit: e59f1c54454a5e3294bb83c83337f31866387aa3 -->
# Importador documental — fluxo e operacao

Esta revisao descreve os componentes e o protocolo de incorporacao. Presenca dos arquivos nao comprova fluxo real: confira registro, recibo e commit remoto.

## Operario
Publique registros novos e imutaveis em ai-deliveries/documentacao/<ID>.json, mediante autorizacao. Nunca atualize main remotamente. O administrador continua salvando somente os .sk necessarios no fluxo normal. Nao ha transporte manual adicional de documentacao.

Campos obrigatorios: schema_version="bridge-docs-v1", delivery_id, created_at UTC, base_commit, requires e updates. O ID deve corresponder ao nome e ao segundo UTC de created_at.

requires: lista completa dos .sk dos quais a alegacao de implementacao depende, com path relativo e sha256_normalized_utf8_lf. A primeira versao aceita apenas .sk diretamente em plugins/Skript/scripts/. Para requisito independente de codigo, requires pode ser vazio; isso nao comprova implementacao.

updates: de um a tres itens distintos, com path, base_sha256_normalized_utf8_lf, content e content_sha256_normalized_utf8_lf. Destinos: ESTADO-ATUAL.md, DECISOES.md e TESTES.md. O hash-base deve ser o do documento no base_commit realmente consultado. Conteudo e acrescentado em bloco identificado, sem apagar o texto anterior.

Hashes seguem utf8-lf-no-bom-v1: UTF-8 valido, remover somente BOM inicial, normalizar CRLF/CR para LF, preservar espacos e newline final. O registro tem limite de 256 KiB, cada conteudo de 64 KiB e ate 128 dependencias.

Antes de publicar, compare novamente a base. Se os documentos mudaram, refaca a proposta em nova base, sem reetiquetar silenciosamente. Registro incorreto recebe novo ID; registros gerados nao sao editados para fingir aplicacao. Os campos narrativos dos manifestos antigos nao sao importados automaticamente.

Identifique requisito, proposta, implementacao observada, relato de teste e pendencia no proprio texto. TESTES.md deve indicar evidencia e SHA efetivamente testado; o importador nao verifica a verdade de uma narrativa e nao promove uma entrega a aprovada.

## Incorporacao
O hook roda antes do stage, preservando os hooks existentes. Consulta ai-deliveries no maximo uma vez por minuto, independentemente de um novo salvamento. Fetch falho e informado; nao e apresentado como consulta ao vivo.

Base desconhecida, dependencia incompleta e conflito documental ficam pendentes, sem sobrescrever. Registro invalido e identificado. Reutilizacao de ID com outro blob nao e aplicada.

Cache, trava, backups e diarios ficam em .git/bridge-docs. Recibos em RASTREABILIDADE/documentacao/<ID>.json registram INCORPORADA_LOCALMENTE, origem e hashes. Nao possuem commit final autorreferente. Publicacao exige conferir a arvore do commit remoto; recibo nao significa reload ou teste.

## Recuperacao
O runner nao remove trava antiga nem repete automaticamente transacao interrompida. Bloqueia antes do stage quando existe diario incompleto, diario ausente ou recibo inconsistente. Nao encerre processos por nome generico.

Com o sincronizador coordenadamente parado e sem outra incorporacao, o gerente deve conferir processo/trava, fonte e hashes e consultar Bridge-DocsStore.recover(root,id). A consulta distingue ORIGINAL, APPLIED e CONFLICT. A conclusao recover(root,id,{complete:true}) e uma escrita separada que exige aprovacao exata, somente quando backups/propostas e arquivos atuais continuam correspondentes. Conflito humano exige revisao; nao ha rollback destrutivo automatico.

A trava coordena este importador, nao editores externos nem todos os processos do Windows. As comparacoes antes da substituicao reduzem riscos, mas nao constituem sandbox nem trava universal do sistema.

## Organizacao vigente
Entrega 1: A+B (fluxo documental e rastreabilidade). Entrega 2: C+D (painel de inicio/encerramento e recuperacao). Entrega 3: E (consolidacao final). WhatsApp retirado dos planos. Verificacoes essenciais durante implementacao, sem rodada geral repetida. Confirmacao de inicio automatico no proximo login/reinicio normal do administrador.

## Evidencia operacional
Confirme o registro em ai-deliveries, o bloco no documento e o recibo no commit publicado da main. Resultados de testes temporarios sao evidencias da implementacao, nao testes de gameplay nem confirmacao automatica da instalacao.
