<!-- Bridge-Delivery-ID: TB-20261103T152122Z-2F392312 -->
<!-- Bridge-Base-Commit: 366ca28c8eddc28138ccc3cea5513a67f78995a0 -->
# Consoles locais com comandos e historico

Entrada local autenticada e separada da API remota. Cada envio mostra componente, PID, execucao e comando e exige confirmacao; nao ha shell do Windows nem reenvio automatico. Resultado delivered significa retorno do transporte, nao conclusao do comando. Consulte o recibo se houver incerteza.

Historico persistente por execucao, stdout/stderr em segmentos de 25 MiB, sem exclusao automatica. A captura comeca na nova ponte; mensagens antigas dos bots descartadas nao podem ser recuperadas. Falhas de captura sao exibidas e bloqueiam novos comandos naquela execucao. Linha sem terminador maior que 1 MiB produz falha explicita de captura; nao e garantia de captura ilimitada.

Use Inicio, Anterior, Proxima e Recarregar. Seguir acompanha as paginas atuais; navegar para tras desativa Seguir. Busca nesta revisao e por pagina, nao global. Setas recuperam ate 200 comandos carregados/confirmados na janela. Execucoes arquivadas sao somente leitura.

Fechar os consoles fecha apenas a visualizacao. Para migrar, feche normalmente as duas janelas antigas antes de abrir a nova interface. O argumento antigo InspectionReceipt e aceito apenas para compatibilidade; nao e evidencia visual nesta revisao.

Ativacao exige parada normal separadamente aprovada dos componentes controlados, validacao da nova ponte e instalacao da interface. A instalacao nao inicia servidor/bots nem altera prontidao. Retomada e testes reais exigem confirmacao propria. Configuracoes e dados do jogo nao fazem parte deste pacote.
