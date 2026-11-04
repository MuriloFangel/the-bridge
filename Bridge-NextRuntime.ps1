#requires -Version 7.2
param([string]$Root='F:\srv\vibecoding')
$script:BridgeNextRoot=$Root
function Invoke-BridgeNextRpc([string]$Name,[hashtable]$Arguments=@{}){
 if($Name -notin @('get_status','get_bridge_recovery_info','get_server_log','send_server_command','start_server','stop_server','start_bot_controller','stop_bot_controller','activate_bridge_update')){throw 'Operacao fora do painel'}
 if($Name -eq 'send_server_command' -and $Arguments.command -cne 'list'){throw 'A sondagem aceita somente list'}
 $c=[IO.File]::ReadAllText('F:\srv\TheBridge-Remote-v2\connection.json')|ConvertFrom-Json
 if($c.project -ine $script:BridgeNextRoot -or [int]$c.port -lt 1 -or [int]$c.port -gt 65535){throw 'Configuracao local inesperada'}
 $body=@{jsonrpc='2.0';id=[guid]::NewGuid().ToString();method='tools/call';params=@{name=$Name;arguments=$Arguments}}|ConvertTo-Json -Depth 10 -Compress
 try{$r=Invoke-RestMethod -Uri ('http://127.0.0.1:'+([int]$c.port)+'/mcp') -Method Post -ContentType 'application/json' -Headers @{Authorization=('Bearer '+$c.key)} -Body $body -TimeoutSec 65}catch{throw ('Resposta incerta em '+$Name+'; nao houve repeticao automatica')}
 if($r.error){throw ('Erro RPC em '+$Name)};if($r.result.isError){throw (([string]$r.result.content[0].text).Replace([string]$c.key,'[REDACTED]'))}
 return ([string]$r.result.content[0].text|ConvertFrom-Json -AsHashtable)
}
function Get-BridgeNextStamp($Value){if($Value -is [datetimeoffset]){return $Value.UtcDateTime.Ticks};if($Value -is [datetime]){return $Value.ToUniversalTime().Ticks};return ([datetimeoffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)).UtcDateTime.Ticks}
function Test-BridgeNextFreshReply($Log,[long]$Cutoff){foreach($row in @($Log.runtime)){if($row.source -eq 'java' -and (Get-BridgeNextStamp $row.at) -gt $Cutoff -and [string]$row.text -match 'There are\s+\d+|players online|Online players|jogadores'){return $true}};return $false}
function Wait-BridgeNextReady([int]$TimeoutSeconds=600){
 $until=[datetime]::UtcNow.AddSeconds($TimeoutSeconds)
 do{
  if($script:BridgeNextCancellation -and $script:BridgeNextCancellation.IsCancellationRequested){throw 'Espera cancelada; Java preservado e nenhum novo bot solicitado por esta etapa'}
  $state=Invoke-BridgeNextRpc 'get_status'
  if(-not $state.server_listening){Write-Information 'Servidor ainda sem porta aberta; aguardando o mesmo processo.' -InformationAction Continue;Start-Sleep -Seconds 5;continue}
  $log=Invoke-BridgeNextRpc 'get_server_log' @{lines=5};$cutoff=[long]0;foreach($row in @($log.runtime)){if($row.source -eq 'java'){$stamp=Get-BridgeNextStamp $row.at;if($stamp -gt $cutoff){$cutoff=$stamp}}}
  Write-Information 'Porta aberta; aguardando resposta nova ao list.' -InformationAction Continue
  try{$r=Invoke-BridgeNextRpc 'send_server_command' @{command='list'};if($r.transport -eq 'local-rcon' -and -not [string]::IsNullOrWhiteSpace([string]$r.response)){return};if($r.command_sent -and (Test-BridgeNextFreshReply $r.log $cutoff)){return}}catch{Write-Information $_.Exception.Message -InformationAction Continue}
  $pollUntil=[datetime]::UtcNow.AddSeconds(30)
  do{if($script:BridgeNextCancellation -and $script:BridgeNextCancellation.IsCancellationRequested){throw 'Espera cancelada; Java preservado'};$log=Invoke-BridgeNextRpc 'get_server_log' @{lines=10};if(Test-BridgeNextFreshReply $log $cutoff){return};Start-Sleep -Seconds 1}while([datetime]::UtcNow -lt $pollUntil -and [datetime]::UtcNow -lt $until)
 }while([datetime]::UtcNow -lt $until)
 throw 'Resposta nao comprovada no prazo. O Java foi preservado; atualize o estado, nao crie outro processo.'
}
function Wait-BridgeNextStopped([string]$Role,[int]$Seconds=120){$until=[datetime]::UtcNow.AddSeconds($Seconds);do{$s=Invoke-BridgeNextRpc 'get_status';$active=$(if($Role -eq 'bots'){$s.bots_owned}else{$s.java_owned});if(-not $active){return};Start-Sleep -Seconds 2}while([datetime]::UtcNow -lt $until);throw ('Saida normal ainda pendente: '+$Role+'. Nenhum processo foi forcado.')}
function Invoke-BridgeNextDesktop([string]$Mode){
 $module=Join-Path $script:BridgeNextRoot 'Bridge-Environment.ps1'
 . $module
 $state=Read-BridgePanelState $script:BridgeNextRoot
 $null=Invoke-BridgeDesktop $Mode $state $script:BridgeNextRoot
}
function Invoke-BridgeNextAction([string]$Action,[bool]$Desktop=$false){
 $s=Invoke-BridgeNextRpc 'get_status'
 switch($Action){
  'StartServer'{if(-not $s.java_owned -and -not $s.server_listening){$r=Invoke-BridgeNextRpc 'start_server';return @{message='Inicio do Java solicitado; prontidao deve ser conferida.';result=$r}};return @{message='Servidor existente preservado; nao criei outro Java.'}}
  'StopServer'{if($s.java_owned -or $s.server_recovery.enabled){$r=Invoke-BridgeNextRpc 'stop_server';Wait-BridgeNextStopped 'server';return @{message='Java da ponte parado normalmente; recuperacao automatica desarmada.';result=$r}};return @{message='Nenhum Java da ponte para parar. Servidor externo preservado.'}}
  'StartBots'{if(-not $s.bots_owned){$r=Invoke-BridgeNextRpc 'start_bot_controller';return @{message='Controlador iniciado; confira PRONTO para conexoes.';result=$r}};return @{message='Controlador da ponte ja ativo.'}}
  'StopBots'{if($s.bots_owned){$null=Invoke-BridgeNextRpc 'stop_bot_controller';Wait-BridgeNextStopped 'bots' 45};return @{message='Controlador da ponte encerrado ou ja ausente.'}}
  'StartEnv'{
   $null=Invoke-BridgeNextAction 'StartServer';Write-Information 'Aguardando resposta do servidor antes de iniciar bots.' -InformationAction Continue;Wait-BridgeNextReady
   if($script:BridgeNextCancellation -and $script:BridgeNextCancellation.IsCancellationRequested){throw 'Espera cancelada; Java preservado'}
   $r=Invoke-BridgeNextAction 'StartBots';if($Desktop){Invoke-BridgeNextDesktop 'Start'};return @{message='Fluxo de inicio concluido; confira conexoes na janela Bots.';result=$r}
  }
  'StopEnv'{$null=Invoke-BridgeNextAction 'StopBots';$null=Invoke-BridgeNextAction 'StopServer';if($Desktop){Invoke-BridgeNextDesktop 'Stop'};return @{message='Encerramento normal concluido; componentes externos preservados.'}}
  'Status'{return @{message=($s|ConvertTo-Json -Depth 8 -Compress);result=$s}}
  default{throw 'Acao desconhecida'}
 }
}