# Bridge-Delivery-ID: TB-20261103T034700Z-BDEF6180
# Bridge-Base-Commit: edaf906bd4395b78f1e2e0c152b3446dff4a2941
#requires -Version 7.2
[CmdletBinding()]
param([string]$ProjectPath='F:\srv\vibecoding',[switch]$AutoStart,[switch]$SelfTest,[switch]$ReplaceLegacyPanel,[string]$InspectionReceipt='')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Bridge-Environment.ps1')
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Painel requer sessao interativa; use start.bat no desktop ou o atalho de login'}
$script:legacyClosed=$false;$script:legacyConfigEquivalent=$true
if($ReplaceLegacyPanel -and -not $SelfTest){
 $legacyPath=Join-Path $ProjectPath 'painel.ps1';$pattern='(?i)-File\s+"?'+[regex]::Escape($legacyPath)+'"?(\s|$)'
 $legacy=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.SessionId -eq [Diagnostics.Process]::GetCurrentProcess().SessionId -and $_.CommandLine -match $pattern})
 if($legacy.Count -gt 1){throw 'Mais de uma janela legada; nenhuma foi fechada'}
 if($legacy.Count -eq 1){
  $entry=$legacy[0];$process=Get-Process -Id $entry.ProcessId -ErrorAction Stop
  if($process.MainWindowTitle -cne 'Minecraft Server Launcher'){throw 'Titulo da janela legada inesperado; nao fechar'}
  $config=Join-Path $ProjectPath 'painel_config.json';$before=[IO.File]::ReadAllText($config) | ConvertFrom-Json -AsHashtable
  $again=Get-CimInstance Win32_Process -Filter ('ProcessId='+$entry.ProcessId)
  if($again.CreationDate -ne $entry.CreationDate -or $again.CommandLine -cne $entry.CommandLine){throw 'Identidade legada mudou'}
  if(-not $process.CloseMainWindow() -or -not $process.WaitForExit(10000)){throw 'Janela antiga nao encerrou normalmente; nenhum processo foi forcado'}
  $after=[IO.File]::ReadAllText($config) | ConvertFrom-Json -AsHashtable
  $keys=@(@($before.Keys)+@($after.Keys) | Sort-Object -Unique)
  $different=@($keys | Where-Object {($before[$_] | ConvertTo-Json -Depth 8 -Compress) -cne ($after[$_] | ConvertTo-Json -Depth 8 -Compress)})
  if($different.Count){throw ('Configuracao mudou ao fechar a GUI antiga; nao restaurei por cima: '+($different -join ', '))}
  $script:legacyClosed=$true
 }
}
[Windows.Forms.Application]::EnableVisualStyles()
$form=[Windows.Forms.Form]::new();$form.Text='The Bridge - Ambiente';$form.Size=[Drawing.Size]::new(660,490);$form.StartPosition='CenterScreen';$form.Font=[Drawing.Font]::new('Segoe UI',10);$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$title=[Windows.Forms.Label]::new();$title.Text='The Bridge | inicio e encerramento';$title.SetBounds(20,15,600,28);$form.Controls.Add($title)
$count=[Windows.Forms.Label]::new();$count.SetBounds(20,48,600,28);$form.Controls.Add($count)
$log=[Windows.Forms.TextBox]::new();$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Vertical';$log.SetBounds(20,175,600,250);$form.Controls.Add($log)
$existing=[Windows.Forms.CheckBox]::new();$existing.Text='Incluir servidor preexistente no encerramento (stop normal)';$existing.SetBounds(20,140,600,28);$form.Controls.Add($existing)
$buttons=@{};$labels=@{Start='Iniciar ambiente';Cancel='Cancelar nesta sessao';Stop='Encerrar ambiente';Status='Atualizar estado';Recover='Recuperar ponte';Consoles='Ver consoles'};$i=0
foreach($name in @('Start','Cancel','Stop','Status','Recover','Consoles')){$b=[Windows.Forms.Button]::new();$b.Text=$labels[$name];$b.Tag=$name;$b.SetBounds((20+($i%3)*200),(80+[math]::Floor($i/3)*30),190,28);$form.Controls.Add($b);$buttons[$name]=$b;$i++}
$script:pending=$null;$script:cancelled=(-not $AutoStart);$script:clock=[Diagnostics.Stopwatch]::new();$script:closeAfter=$false;$script:allowClose=$false
function Start-PanelOperation([string]$Action){
 if($script:pending){return};if($Action -eq 'Start'){Show-BridgeConsoles};$script:cancelled=$true;$buttons.Cancel.Enabled=$false;$include=$existing.Checked
 $runspace=[runspacefactory]::CreateRunspace();$runspace.ApartmentState='STA';$runspace.ThreadOptions='ReuseThread';$runspace.Open();$ps=[PowerShell]::Create();$ps.Runspace=$runspace
 $work={param($module,$root,$action,$include) . $module;$state=Read-BridgePanelState $root
 try{switch($action){'Start'{$r=Start-BridgeEnvironment -Root $root -State $state};'Stop'{$r=Stop-BridgeEnvironment -Root $root -State $state -IncludeExistingServer $include};'Status'{$s=Invoke-BridgeLocalTool 'get_status' @{};$r=@{messages=@('Servidor na porta: '+$s.server_listening,'Java da ponte: '+$s.java_owned,'Bots da ponte: '+$s.bots_owned)}};'Recover'{$r=Invoke-BridgePanelRecovery};default{throw 'Acao invalida'}};return $r}catch{return @{messages=@('Operacao interrompida: '+$_.Exception.Message);failed=$true}}finally{Save-BridgePanelState $root $state}}
 [void]$ps.AddScript($work.ToString()).AddArgument((Join-Path $PSScriptRoot 'Bridge-Environment.ps1')).AddArgument($ProjectPath).AddArgument($Action).AddArgument($include)
 $script:pending=@{ps=$ps;runspace=$runspace;handle=$ps.BeginInvoke();action=$Action};$log.AppendText("Operacao: $Action`r`n")
}
$buttons.Cancel.Add_Click({$script:cancelled=$true;$count.Text='Inicio automatico cancelado nesta sessao. Nenhum novo componente sera iniciado.'})
$buttons.Start.Add_Click({if([Windows.Forms.MessageBox]::Show('Iniciar servidor se necessario, aguardar prontidao, iniciar controlador conforme a configuracao local, CMPack e pastas?','Iniciar ambiente','YesNo','Question') -eq 'Yes'){Start-PanelOperation 'Start'}})
$buttons.Stop.Add_Click({if([Windows.Forms.MessageBox]::Show(('Encerrar componentes iniciados pelo ambiente? Incluir servidor preexistente: '+$existing.Checked+'. Nao havera finalizacao forcada.'),'Encerrar ambiente','YesNo','Question') -eq 'Yes'){Start-PanelOperation 'Stop'}})
$buttons.Status.Add_Click({Start-PanelOperation 'Status'})
$buttons.Recover.Add_Click({if([Windows.Forms.MessageBox]::Show('Solicitar reinicio somente do agente, com guardas, ou iniciar a tarefa existente se estiver parada? Nao sera encerrada a arvore de processos.','Recuperar ponte','YesNo','Question') -eq 'Yes'){Start-PanelOperation 'Recover'}})
$timer=[Windows.Forms.Timer]::new();$timer.Interval=200
$timer.Add_Tick({
 if($script:pending -and $script:pending.handle.IsCompleted){$p=$script:pending;try{$r=@($p.ps.EndInvoke($p.handle));foreach($x in $r){foreach($m in @($x.messages)){$log.AppendText([string]$m+"`r`n")};if($x.failed -or $x.pending){$script:closeAfter=$false}};if($p.ps.HadErrors){$log.AppendText("Falha interna; consulte estado antes de repetir.`r`n");$script:closeAfter=$false}}catch{$log.AppendText("Falha de operacao; nao houve repeticao automatica.`r`n");$script:closeAfter=$false}finally{$p.ps.Dispose();$p.runspace.Dispose();$script:pending=$null}
 if($script:closeAfter){$script:closeAfter=$false;$script:allowClose=$true;$form.Close();return}}
 foreach($name in @('Start','Stop','Status','Recover')){$buttons[$name].Enabled=($null -eq $script:pending)}
 if(-not $script:cancelled){$remaining=[math]::Max(0,[math]::Ceiling(30-$script:clock.Elapsed.TotalSeconds));$count.Text="Inicio automatico em $remaining segundos. Cancelar nao fecha o painel.";if((Get-BridgeCountdownAction $script:clock.Elapsed.TotalSeconds $script:cancelled ($null -ne $script:pending)) -eq 'START'){$script:cancelled=$true;Start-PanelOperation 'Start'}}
})
$form.Add_Shown({$script:clock.Start();$timer.Start();if($script:cancelled){$count.Text='Modo manual. Nenhum componente sera iniciado sem sua acao.'}})
$form.Add_FormClosing({param($sender,$event)
 if($script:allowClose){return};if($script:pending){$event.Cancel=$true;[void][Windows.Forms.MessageBox]::Show('Aguarde a operacao terminar; nao interromper o controle no meio.');return}
 $script:cancelled=$true;$choice=[Windows.Forms.MessageBox]::Show('Sim: solicitar encerramento. Nao: fechar apenas o painel e preservar componentes. Cancelar: continuar aqui.','Fechar painel','YesNoCancel','Question')
 if($choice -eq 'Cancel'){$event.Cancel=$true}elseif($choice -eq 'Yes'){$event.Cancel=$true;$script:closeAfter=$true;Start-PanelOperation 'Stop'}else{$timer.Stop()}
})
$form.Add_Shown({
 if($InspectionReceipt){
  $file=[IO.Path]::GetFullPath($InspectionReceipt);$allowed='F:\srv\TheBridge-Remote-v2\backups\'
  if(-not $file.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($file) -cne 'panel-visible.json'){throw 'Destino de evidencia recusado'}
  if(-not(Test-Path -LiteralPath $file)){
   $proof=@{session_id=[Diagnostics.Process]::GetCurrentProcess().SessionId;pid=$PID;visible=$form.Visible;window_handle=$form.Handle.ToInt64();title=$form.Text;auto_start=[bool]$AutoStart;legacy_closed=$script:legacyClosed;config_semantically_preserved=$script:legacyConfigEquivalent;utc=[DateTime]::UtcNow.ToString('o')}
   $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($proof | ConvertTo-Json -Depth 5 -EscapeHandling EscapeNonAscii));$stream=[IO.File]::Open($file,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
   try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
  }
 }
})
function Show-BridgeConsoles {
 if($SelfTest){return}
 try{$viewer=Join-Path $PSScriptRoot 'Bridge-Consoles.ps1';if(-not(Test-Path -LiteralPath $viewer -PathType Leaf)){throw 'Visualizador ausente'};$null=Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList ('-NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$viewer+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden}catch{$log.AppendText("Nao foi possivel abrir os consoles: "+$_.Exception.Message+"`r`n")}
}
$buttons.Consoles.Add_Click({Show-BridgeConsoles})
$form.Add_Shown({Show-BridgeConsoles})
if($SelfTest){if($buttons.Count -ne 6 -or $timer.Interval -ne 200){throw 'Estrutura da GUI invalida'};$timer.Dispose();$form.Dispose();[pscustomobject]@{gui_constructed=$true;buttons=6;components_started=$false} | ConvertTo-Json -Compress;return}
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeEnvironmentPanel');$owned=$false
try{try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true};if(-not $owned){return};[void]$form.ShowDialog()}finally{$timer.Dispose();$form.Dispose();if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}