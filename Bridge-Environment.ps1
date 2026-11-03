# Bridge-Delivery-ID: TB-20261103T020722Z-E7DF76B7
# Bridge-Base-Commit: 7a523837c6c38f48fd61662fa5dfda09adc0d58b
#requires -Version 7.2
function Invoke-BridgeLocalTool {
 param([string]$Tool,[hashtable]$Arguments=@{})
 $allowed=@('get_status','get_bridge_recovery_info','get_server_log','send_server_command','start_server','stop_server','start_bot_controller','stop_bot_controller','request_bridge_restart')
 if($Tool -notin $allowed){throw 'Ferramenta local fora do escopo'}
 if($Tool -eq 'send_server_command' -and $Arguments.command -cne 'list'){throw 'Somente list e permitido para prontidao'}
 $c=[IO.File]::ReadAllText('F:\srv\TheBridge-Remote-v2\connection.json') | ConvertFrom-Json
 if($c.project -ine 'F:\srv\vibecoding' -or [int]$c.port -lt 1 -or [int]$c.port -gt 65535 -or [string]$c.key -notmatch '^[A-Za-z0-9_-]{40,}$'){throw 'Configuracao privada inesperada'}
 $body=@{jsonrpc='2.0';id=[guid]::NewGuid().ToString();method='tools/call';params=@{name=$Tool;arguments=$Arguments}} | ConvertTo-Json -Depth 10 -Compress
 try{$r=Invoke-RestMethod -Uri ('http://127.0.0.1:'+([int]$c.port)+'/mcp') -Method Post -Headers @{Authorization=('Bearer '+$c.key)} -ContentType 'application/json' -Body $body -NoProxy -MaximumRedirection 0 -TimeoutSec 45}catch{throw 'Falha na ponte local; consulte estado antes de repetir uma operacao'}
 if($r.error){throw 'Resposta RPC de erro; nenhuma repeticao automatica'}
 if($r.result.isError){throw (([string]$r.result.content[0].text).Replace([string]$c.key,'[REDACTED]'))}
 return ([string]$r.result.content[0].text | ConvertFrom-Json -AsHashtable)
}
function New-BridgePanelState {
 @{boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');owner=[guid]::NewGuid().ToString('N');server=@{owned=$false;identity=$null;agent=$null;stop_requested=$false};bots=@{owned=$false;identity=$null;agent=$null;stop_requested=$false};desktop=@{client=$null;folders=@()}}
}
function Get-BridgePanelDirectory([string]$Root){
 foreach($p in @($Root,(Join-Path $Root '.git'))){$i=Get-Item -LiteralPath $p -Force;if(-not $i.PSIsContainer -or ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Raiz ou .git via link recusada'}}
 $p=Join-Path $Root '.git/bridge-panel';if(Test-Path -LiteralPath $p){if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Estado via link recusado'}}else{[void][IO.Directory]::CreateDirectory($p)};return $p
}
function Save-BridgePanelState([string]$Root,[hashtable]$State){
 $p=Join-Path (Get-BridgePanelDirectory $Root) 'state.json';$tmp=$p+'.tmp-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($tmp,(($State | ConvertTo-Json -Depth 12)+"`n"),[Text.UTF8Encoding]::new($false))
 if(Test-Path -LiteralPath $p){if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Estado via link recusado'};[IO.File]::Replace($tmp,$p,$p+'.bak')}else{[IO.File]::Move($tmp,$p)}
}
function Read-BridgePanelState([string]$Root){
 $p=Join-Path (Get-BridgePanelDirectory $Root) 'state.json';$fresh=New-BridgePanelState
 if(-not(Test-Path -LiteralPath $p)){return $fresh}
 $s=[IO.File]::ReadAllText($p) | ConvertFrom-Json -AsHashtable
 if(-not $s.server -or -not $s.bots -or -not $s.desktop){throw 'Estado do painel invalido; nao assumir processos'}
 if($s.boot -cne $fresh.boot){return $fresh};return $s
}
function Invoke-BridgeIdentity([string]$Mode,$Value){
 try{if($Mode -eq 'Capture'){$p=Get-Process -Id ([int]$Value) -ErrorAction Stop;return @{pid=$p.Id;born=$p.StartTime.ToUniversalTime().ToString('o');exe=$p.MainModule.FileName}}
 if(-not $Value){return $false};$p=Get-Process -Id ([int]$Value.pid) -ErrorAction Stop
 return ($p.StartTime.ToUniversalTime().ToString('o') -ceq $Value.born -and $p.MainModule.FileName -ieq $Value.exe)}catch{return $false}
}
function Get-BridgeCountdownAction([double]$Elapsed,[bool]$Cancelled,[bool]$Busy){if($Cancelled){return 'CANCELLED'};if($Busy){return 'WAIT'};if($Elapsed -ge 30){return 'START'};return 'WAIT'}
function Initialize-BridgeWindowTags {
 if(-not ('BridgePanelWindowTag' -as [type])){Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BridgePanelWindowTag {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool SetProp(IntPtr h,string n,IntPtr d);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr h,string n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr RemoveProp(IntPtr h,string n);
}
'@
}
}
function Get-BridgeFolderWindows {
 $shell=New-Object -ComObject Shell.Application
 foreach($w in @($shell.Windows())){try{$uri=[uri]$w.LocationURL;if($uri.IsFile){[pscustomobject]@{handle=[long]$w.HWND;path=$uri.LocalPath.TrimEnd('\');window=$w}}}catch{}}
}
function Invoke-BridgeDesktop([string]$Mode,[hashtable]$State,[string]$Root){
 Initialize-BridgeWindowTags;$messages=[Collections.Generic.List[string]]::new();$tag='TheBridge-'+$State.owner
 if($Mode -eq 'Start'){
  $exe='C:\Users\Administrator\AppData\Local\Programs\cmlauncher\CMCLIENT.exe'
  $existing=@(Get-CimInstance Win32_Process -Filter "Name='CMCLIENT.exe'" | Where-Object {$_.ExecutablePath -ieq $exe})
  if(-not $existing.Count){if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'CMPack ausente'};$p=Start-Process -FilePath $exe -PassThru;$State.desktop.client=Invoke-BridgeIdentity 'Capture' $p.Id;Save-BridgePanelState $Root $State;$messages.Add('Launcher CMPack solicitado')}else{$messages.Add('CMPack existente preservado')}
  foreach($folder in @('F:\srv','F:\srv\vibecoding','F:\srv\vibecoding\plugins\Skript\scripts')){
   $before=@(Get-BridgeFolderWindows);if(@($before | Where-Object {$_.path -ieq $folder}).Count){continue}
   $shell=New-Object -ComObject Shell.Application;$shell.Explore($folder);$end=[DateTime]::UtcNow.AddSeconds(4)
   do{Start-Sleep -Milliseconds 200;$new=@(Get-BridgeFolderWindows | Where-Object {$_.path -ieq $folder -and $_.handle -notin @($before.handle)});if($new.Count){break}}while([DateTime]::UtcNow -lt $end)
   foreach($w in $new){if([BridgePanelWindowTag]::SetProp([intptr]$w.handle,$tag,[intptr]1)){$State.desktop.folders+=@(@{handle=$w.handle;path=$folder;tag=$tag})}}
   Save-BridgePanelState $Root $State
  }
 }else{
  $windows=@(Get-BridgeFolderWindows)
  foreach($f in @($State.desktop.folders)){$w=@($windows | Where-Object {$_.handle -eq $f.handle -and $_.path -ieq $f.path});if($w.Count -eq 1 -and [BridgePanelWindowTag]::GetProp([intptr]$f.handle,[string]$f.tag) -eq [intptr]1){$null=[BridgePanelWindowTag]::RemoveProp([intptr]$f.handle,[string]$f.tag);$w[0].window.Quit()}}
  $State.desktop.folders=@()
  if($State.desktop.client){if(Invoke-BridgeIdentity 'Matches' $State.desktop.client){$p=Get-Process -Id ([int]$State.desktop.client.pid);if($p.CloseMainWindow()){$messages.Add('Fechamento normal do launcher solicitado')}else{$messages.Add('Launcher sem janela propria identificada; preservado')}}else{$messages.Add('Launcher original ausente; processos filhos nao foram assumidos')};$State.desktop.client=$null}
  Save-BridgePanelState $Root $State
 }
 return @($messages)
}
function Test-BridgeReadyReply($Reply,[datetimeoffset]$ProbeAt){
 if($Reply.transport -eq 'local-rcon' -and -not [string]::IsNullOrWhiteSpace([string]$Reply.response)){return $true}
 if($Reply.transport -ne 'owned-java-stdin' -or -not $Reply.command_sent){return $false}
 return (@($Reply.log.runtime | Where-Object {$_.source -eq 'java' -and [datetimeoffset]::Parse([string]$_.at) -ge $ProbeAt -and $_.text -match 'There are|players online|Online players|jogadores'}).Count -gt 0)
}
function Wait-BridgeServerReady([scriptblock]$Rpc){
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do{$s=& $Rpc 'get_status' @{};if($s.server_listening){$probeAt=[datetimeoffset]::UtcNow;try{$reply=& $Rpc 'send_server_command' @{command='list'};if(Test-BridgeReadyReply $reply $probeAt){return}}catch{}}
 Start-Sleep -Seconds 1}while($clock.Elapsed.TotalSeconds -lt 120)
 throw 'Prontidao nao comprovada; bots e desktop nao foram iniciados'
}
function Start-BridgeEnvironment {
 param([string]$Root,[hashtable]$State,[scriptblock]$Rpc={param($t,$a) Invoke-BridgeLocalTool $t $a},[scriptblock]$Desktop={param($m,$s,$r) Invoke-BridgeDesktop $m $s $r},[scriptblock]$Identity={param($m,$v) Invoke-BridgeIdentity $m $v})
 $messages=[Collections.Generic.List[string]]::new();$info=& $Rpc 'get_bridge_recovery_info' @{};$status=& $Rpc 'get_status' @{}
 if(-not $status.server_listening -and -not $status.java_owned){$r=& $Rpc 'start_server' @{};if($r.started){$State.server=@{owned=$true;agent=$info.supervisor.agent_pid;identity=(& $Identity 'Capture' $r.pid);stop_requested=$false};Save-BridgePanelState $Root $State;$messages.Add('Java iniciado pela ponte')}}else{$messages.Add('Servidor ja existente; nenhum Java duplicado')}
 Wait-BridgeServerReady $Rpc
 $status=& $Rpc 'get_status' @{}
 if(-not $status.bots_owned){$r=& $Rpc 'start_bot_controller' @{};if($r.started){$State.bots=@{owned=$true;agent=$info.supervisor.agent_pid;identity=(& $Identity 'Capture' $r.pid);stop_requested=$false};Save-BridgePanelState $Root $State;$messages.Add('Controlador iniciado; controlador usa a configuracao local de bots')}}else{$messages.Add('Controlador existente nao foi assumido')}
 foreach($message in @(& $Desktop 'Start' $State $Root)){$messages.Add([string]$message)};Save-BridgePanelState $Root $State
 return @{messages=@($messages);state=$State}
}
function Stop-BridgeEnvironment {
 param([string]$Root,[hashtable]$State,[bool]$IncludeExistingServer=$false,[scriptblock]$Rpc={param($t,$a) Invoke-BridgeLocalTool $t $a},[scriptblock]$Desktop={param($m,$s,$r) Invoke-BridgeDesktop $m $s $r},[scriptblock]$Identity={param($m,$v) Invoke-BridgeIdentity $m $v})
 $messages=[Collections.Generic.List[string]]::new();$info=& $Rpc 'get_bridge_recovery_info' @{};$status=& $Rpc 'get_status' @{}
 if($State.bots.owned -and $status.bots_owned){
  if($State.bots.agent -ne $info.supervisor.agent_pid -or -not (& $Identity 'Matches' $State.bots.identity)){throw 'Identidade do controlador mudou; nao foi encerrado'}
  if(-not $State.bots.stop_requested){$State.bots.stop_requested=$true;Save-BridgePanelState $Root $State;$null=& $Rpc 'stop_bot_controller' @{}}
  $end=[DateTime]::UtcNow.AddSeconds(15);do{$status=& $Rpc 'get_status' @{};if(-not $status.bots_owned){break};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $end)
  if($status.bots_owned){throw 'Saida dos bots pendente; nenhuma finalizacao forcada'}
 }
 if(-not $status.bots_owned){$State.bots.owned=$false;$State.bots.stop_requested=$false}
 $canStop=$false
 if($IncludeExistingServer){$canStop=$true}elseif($State.server.owned -and ($status.java_owned -or $status.server_listening)){if($State.server.agent -ne $info.supervisor.agent_pid -or -not (& $Identity 'Matches' $State.server.identity)){throw 'Identidade do Java mudou; nao foi encerrado'};$canStop=$true}
 if($canStop -and ($status.server_listening -or $status.java_owned)){
  if(-not $State.server.stop_requested){$State.server.stop_requested=$true;Save-BridgePanelState $Root $State;$r=& $Rpc 'stop_server' @{};if(-not $r.stopped){$messages.Add('Stop solicitado; salvamento/saida ainda pendente')}}
  $status=& $Rpc 'get_status' @{};if($status.server_listening -or $status.java_owned){Save-BridgePanelState $Root $State;return @{messages=@($messages)+@('Aguarde e atualize o estado; stop nao sera repetido automaticamente');state=$State;pending=$true}}
  $State.server.owned=$false;$State.server.stop_requested=$false;$messages.Add('Servidor encerrado normalmente')
 }elseif($status.server_listening){$messages.Add('Servidor preexistente preservado; opcao explicita nao selecionada')}else{$State.server.owned=$false;$State.server.stop_requested=$false}
 foreach($message in @(& $Desktop 'Stop' $State $Root)){$messages.Add([string]$message)};Save-BridgePanelState $Root $State
 return @{messages=@($messages);state=$State}
}
function Invoke-BridgePanelRecovery {
 try{$info=Invoke-BridgeLocalTool 'get_bridge_recovery_info' @{}}catch{
  $task=Get-ScheduledTask -TaskName 'TheBridge-Remote-v2' -ErrorAction Stop
  if([string]$task.State -ne 'Ready'){throw 'Supervisor nao esta parado; nao encerrei nem reiniciei sua arvore'}
  $active=@(Get-CimInstance Win32_Process -Filter "Name='node.exe' OR Name='pwsh.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains('F:\srv\TheBridge-Remote-v2')})
  if($active.Count){throw 'Processos da ponte ainda existem; revisao necessaria, sem duplicacao'}
  if($task.Actions.Count -ne 1 -or $task.Actions[0].WorkingDirectory -ine 'F:\srv\TheBridge-Remote-v2'){throw 'Tarefa configurada mudou'}
  Start-ScheduledTask -InputObject $task;return @{messages=@('Inicio da tarefa existente solicitado; confira a saude depois')}
 }
 if($info.managed_java -or $info.managed_bots -or @($info.running_tasks).Count){throw 'Ponte possui processos/tarefas gerenciados; reinicio recusado'}
 $null=Invoke-BridgeLocalTool 'request_bridge_restart' @{};return @{messages=@('Reinicio somente do agente solicitado; nao equivale a saude confirmada')}
}