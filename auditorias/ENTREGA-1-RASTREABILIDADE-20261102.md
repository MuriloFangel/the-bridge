# Entrega 1 — regularizacao e analise de rastreabilidade

## Escopo e evidencias
Snapshot analisado: main ecb022e16184c356f7864fac313af4db0fab347b; ledger 39798f539e570abbb2a53bf1b4483d05b4ebbff4. Observacao: RASTREABILIDADE/observacoes/8d1b94e32f8c4f9b66c74f37696d93f7f98ffef366a4583fcb831b97badd9e9d-20261102T043903656Z-82bc5c05.json.

A analise consultou ate 40 alteracoes historicas por caminho, comparando SHA-256 utf8-lf-no-bom-v1 ao manifesto. Execucao comprovada da tarefa 55194f65-33b9-439b-81a4-8805f3d2f89c: succeeded, exit_code 0. Encontrou 9 dos 15 pares divergentes no historico; 6 nao foram encontrados nas versoes consultadas. Isso nao e teste de gameplay nem prova de instalacao no servidor.

## Conteudos encontrados em ancestrais publicados
| Entrega | Arquivo | Commit correspondente |
|---|---|---|
| TB-20261101T042032Z-817D9FCD | PROMPT-NOVO-CHAT.md | 7629c073a52d283a1ed445e9e403ec759d03b3f3 |
| TB-20261101T042032Z-817D9FCD | README.md | 7629c073a52d283a1ed445e9e403ec759d03b3f3 |
| TB-20261101T042032Z-817D9FCD | Sincronizar-GitHub.ps1 | 7629c073a52d283a1ed445e9e403ec759d03b3f3 |
| TB-20261101T060313Z-3982FC66 | README.md | 57f3a58f67ea82ea5e5c4db5a01856383e847627 |
| TB-20261101T061211Z-F615A3D1 | plugins/Skript/scripts/Bridge-Core.sk | 6d82b9c79fd77fead21a096cae72eda2754e80ea |
| TB-20261101T061211Z-F615A3D1 | plugins/Skript/scripts/Bridge-Loadout.sk | 6d82b9c79fd77fead21a096cae72eda2754e80ea |
| TB-20261101T062635Z-2B1B2E53 | plugins/Skript/scripts/Bridge-Core.sk | ea6d6772f2207506406beda0b6a680c30f420dc6 |
| TB-20261101T062635Z-2B1B2E53 | plugins/Skript/scripts/Bridge-Guardian.sk | ea6d6772f2207506406beda0b6a680c30f420dc6 |
| TB-20261101T062635Z-2B1B2E53 | plugins/Skript/scripts/Bridge-Setup.sk | ea6d6772f2207506406beda0b6a680c30f420dc6 |

A divergencia atual desses pares nao significa que nunca foram publicados. O README do operario recebeu posteriormente a ligacao do gerente. Nao restaurar versoes antigas apenas para obter correspondencia integral.

## Aplicacao exata nao comprovada pela busca
- TB-20261101T042032Z-817D9FCD: tools/Bridge-Rastreabilidade.ps1. A correcao posterior TB-20261101T051722Z-E97261CF corresponde ao helper do snapshot; isso nao comprova aplicacao da proposta original.
- TB-20261101T054400Z-145278BA: PROMPT-NOVO-CHAT.md. Proposta exata nao localizada; prompt posterior deve ser analisado por sua propria entrega.
- TB-20261101T063604Z-7CFA5B2B: Bridge-Core.sk e Bridge-Guardian.sk. Bridge-Rounds.sk correspondia no snapshot, mas nao basta para declarar o conjunto aplicado.
- TB-20261101T064731Z-37E2A4B1: Bridge-Core.sk e Bridge-Guardian.sk. Bridge-Participation.sk correspondia no snapshot, mas nao basta para declarar o conjunto aplicado.

Esses seis pares permanecem nao comprovados nesta analise, nao classificados automaticamente como perda, regressao ou bug. Nao alterar gameplay para regularizar registros.

## Regularizacao documental
Esta publicacao acrescenta ao ledger cinco manifestos antes disponiveis apenas como fallback local e o manifesto da instalacao TB-20261102T061136Z-1D382738. Preserva todos os campos originais; somente a formatacao JSON foi compactada. Os cinco registros ja existentes no ledger nao sao modificados.

Campos antigos como remote_record_status=PENDENTE, registration_note e tests_pending descrevem o momento da geracao e permanecem imutaveis. Sua presenca nao significa que a copia continua ausente apos esta publicacao; tambem nao autoriza promover o registro GERADA a aprovado/testado.

A instalacao documental foi publicada pelo sincronizador na main 3d80b0a6a016170d377a2cfe8a8e6590fb85498d, sem alteracoes de gameplay nesse commit. O registro documentacao/TB-20261102T061143Z-66F753A8.json serve a verificacao real do importador. Sua publicacao no ledger ainda nao comprova incorporacao, recibo ou commit resultante na main.

## Pendencias residuais e limites
Conferir no commit resultante a incorporacao do registro real e seu recibo; manter explicitos os seis pares sem aplicacao comprovada e a ausencia de testes de gameplay nesta manutencao. Painel, encerramento e recuperacao da ponte pertencem a entrega 2; consolidacao final pertence a entrega 3. WhatsApp retirado dos planos.
