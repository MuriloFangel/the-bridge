<!-- Bridge-Delivery-ID: TB-20261103T034700Z-BDEF6180 -->
<!-- Bridge-Base-Commit: edaf906bd4395b78f1e2e0c152b3446dff4a2941 -->
# Consoles locais

Duas janelas somente de leitura, sem iniciar/parar Java, bots ou ponte. Fechar as duas encerra apenas o visualizador. Ver consoles reexibe as janelas existentes na mesma sessao; nao cria outro controlador.

Servidor: ultimas 200 linhas e stderr recente. Bots: acumula blocos observados; a API retorna somente os 10 blocos mais recentes compartilhados com Java. Pode haver lacunas, inclusive historico anterior indisponivel. Consulta em segundo plano, 5 segundos apos cada resposta; falhas aguardam 15 segundos. Sem comandos interativos neste lote.

A integracao abre consoles ao exibir o painel e ao iniciar ambiente. O painel ja aberto nao e fechado ou substituido em memoria: o novo botao aparece quando ele for reaberto normalmente. Uma tarefa separada abre os consoles agora na sessao interativa. Prontidao e demais testes ficam pendentes; nada neste lote muda seus criterios.
