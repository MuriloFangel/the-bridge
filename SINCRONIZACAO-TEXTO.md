# Sincronização textual — política vigente

O repositório guarda código (.sk e ferramentas), configurações textuais e documentação, preservando os caminhos relativos do servidor. Extensão não certifica ausência de segredo: configurações novas precisam de revisão.

Não sincronizar JARs, mundos, bancos binários, logs/cache/libs, dados de jogadores, CSV runtime, backups e cópias históricas em plugins/Skript/scripts/deepseek/. Mundos existentes são reconhecidos pela presença de level.dat e excluídos inteiros. Novos mundos podem precisar de regra específica; pastas de região/playerdata/stats já são bloqueadas.

server.properties real fica local, com suas credenciais. O exemplo versionado deve ter senha RCON vazia. Não substituir automaticamente a configuração real pelo exemplo.

CSV de variáveis mistura estado e cadastro de arenas. Exportação declarativa revisada é uma tarefa futura; não publicar todo runtime por conveniência nem assumir que a instalação final já sabe reconstruir esses dados.

A migração foi feita por commit normal: retira arquivos da árvore atual, NÃO apaga esses arquivos do PC nem do histórico anterior. Clones ainda podem baixar os blobs históricos. Eventual redução do histórico exige decisão e procedimento separado; não fazer reset ou force push automático.

A IA deve consultar README, este documento, estado/decisões/testes e SHA atual antes de trabalhar. Arquivo ausente do Git não significa que foi apagado do servidor. Sync não equivale a reload, aprovação nem teste.

## Distribuição futura — proposta, não implementada

Release com launcher de caminhos relativos, configs de exemplo e manifesto de versões/origens/destinos/SHA-256. Baixar plugins de fontes autorizadas conforme licenças e condições; instalação manual quando automação não for permitida. Mapas próprios/autorizados podem vir do Drive ou assets de releases. Downloads temporários, hash e extração segura antes de instalar. Não sobrescrever dados sem aprovação/backup. Credenciais e token de túnel só locais. Interface opcional para iniciar/parar/console. Minecraft Java usa TCP; não expor RCON/admin. Revisar autenticação e EULA antes de distribuição/acesso público.
