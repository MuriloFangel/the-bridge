# Bridge-Delivery-ID: TB-20261103T034700Z-BDEF6180
# Bridge-Base-Commit: edaf906bd4395b78f1e2e0c152b3446dff4a2941
#requires -Version 7.2
[CmdletBinding()]
param([switch]$SelfTest,[string]$InspectionReceipt='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Consoles requerem sessao interativa'}
[Windows.Forms.Application]::EnableVisualStyles()
$script:consoleUi=@{};$script:consoleClosing=$false;$script:consolePending=$null;$script:consoleNext=[DateTime]::MinValue;$script:consoleReceipt=$InspectionReceipt
$script:consoleSeen=[Collections.Generic.HashSet[string]]::new();$script:consoleKeys=[Collections.Generic.Queue[string]]::new();$script:consoleBotText='';$script:consoleContext=[Windows.Forms.ApplicationContext]::new()
$area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea;$width=[math]::Max(320,[int](($area.Width-30)/2));$height=[math]::Max(300,[math]::Min(700,$area.Height-80))
foreach($kind in @('server','bots')){
 $f=[Windows.Forms.Form]::new();$f.Text=$(if($kind -eq 'server'){'The Bridge - Console servidor (leitura)'}else{'The Bridge - Console bots (leitura)'});$f.StartPosition='Manual';$x=$area.Left+10;if($kind -eq 'bots'){$x+=$width+10};$f.SetBounds($x,($area.Top+35),$width,$height)
 $top=[Windows.Forms.Panel]::new();$top.Dock='Top';$top.Height=100
 $status=[Windows.Forms.Label]::new();$status.SetBounds(8,5,($width-35),35);$status.Text='Conectando apenas para ler logs...';$status.Anchor='Top,Left,Right';$top.Controls.Add($status)
 $note=[Windows.Forms.Label]::new();$note.SetBounds(8,42,($width-35),30);$note.Anchor='Top,Left,Right';$note.Text=$(if($kind -eq 'server'){'Ultimas 200 linhas. Porta aberta nao comprova prontidao.'}else{'Ultimos blocos disponiveis; pode haver lacunas. Nao e historico completo.'});$top.Controls.Add($note)
 $follow=[Windows.Forms.CheckBox]::new();$follow.Text='Seguir novas mensagens';$follow.Checked=$true;$follow.SetBounds(8,75,260,22);$top.Controls.Add($follow)
 $box=[Windows.Forms.TextBox]::new();$box.Multiline=$true;$box.ReadOnly=$true;$box.WordWrap=$false;$box.ScrollBars='Both';$box.Dock='Fill';$box.Font=[Drawing.Font]::new('Consolas',10);$box.BackColor=[Drawing.Color]::FromArgb(20,20,20);$box.ForeColor=[Drawing.Color]::Gainsboro
 $f.Controls.Add($box);$f.Controls.Add($top)
 $f.Add_FormClosing({param($sender,$event) if(-not $script:consoleClosing){$event.Cancel=$true;$sender.Hide();if(@($script:consoleUi.Values | Where-Object {$_.form.Visible}).Count -eq 0){$script:consoleClosing=$true;$script:consoleContext.ExitThread()}}})
 $script:consoleUi[$kind]=@{form=$f;box=$box;status=$status;follow=$follow}
}
function Clean-ConsoleText([string]$Text){return [regex]::Replace($Text,'\x1b\[[0-?]*[ -/]*[@-~]','')}
function Set-ConsoleText($Ui,[string]$Text){if($Ui.form.IsDisposed){return};if($Text.Length -gt 200000){$Text=$Text.Substring($Text.Length-150000)};if($Ui.box.Text -cne $Text){$position=$Ui.box.SelectionStart;$Ui.box.Text=$Text;if($Ui.follow.Checked){$Ui.box.SelectionStart=$Ui.box.TextLength;$Ui.box.ScrollToCaret()}else{$Ui.box.SelectionStart=[math]::Min($position,$Ui.box.TextLength)}}}
function Show-ConsoleSnapshot($Snapshot){
 $server=Clean-ConsoleText (@($Snapshot.logs.lines) -join "`r`n")
 $errors=@($Snapshot.logs.runtime | Where-Object {$_.source -eq 'java-error'} | ForEach-Object {'['+[string]$_.at+'] '+(Clean-ConsoleText ([string]$_.text))})
 if($errors.Count){$server+="`r`n--- stderr recente capturado pela ponte ---`r`n"+($errors -join "`r`n")}
 Set-ConsoleText $script:consoleUi.server $server
 foreach($entry in @($Snapshot.logs.runtime | Where-Object {$_.source -in @('bots','bots-error')})){
  $key=[string]$entry.at+'|'+[string]$entry.source+'|'+[string]$entry.text
  if($script:consoleSeen.Add($key)){$script:consoleKeys.Enqueue($key);$script:consoleBotText+='['+[string]$entry.at+'] '+(Clean-ConsoleText ([string]$entry.text)).TrimEnd()+"`r`n"}
 }
 while($script:consoleKeys.Count -gt 1000){[void]$script:consoleSeen.Remove($script:consoleKeys.Dequeue())}
 if($script:consoleBotText.Length -gt 200000){$script:consoleBotText=$script:consoleBotText.Substring($script:consoleBotText.Length-150000)}
 Set-ConsoleText $script:consoleUi.bots $(if($script:consoleBotText){$script:consoleBotText}else{'Nenhuma mensagem de bots na janela recente. Isso nao prova controlador parado.'})
 $script:consoleUi.server.status.Text='Porta aberta: '+$Snapshot.status.server_listening+' | Java da ponte: '+$Snapshot.status.java_owned+' | '+(Get-Date -Format 'HH:mm:ss')
 $script:consoleUi.bots.status.Text='Controlador da ponte: '+$Snapshot.status.bots_owned+' | Atualizacao a cada 5 s; sem comandos de escrita.'
}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=500
if($SelfTest){
 $sample=@{logs=@{lines=@('SERVER_TEST');runtime=@(@{at='TEST';source='bots';text='BOT_TEST'})};status=@{server_listening=$true;java_owned=$true;bots_owned=$true}}
 Show-ConsoleSnapshot $sample;Show-ConsoleSnapshot $sample
 if($script:consoleUi.Count -ne 2 -or -not $script:consoleUi.server.box.ReadOnly -or -not $script:consoleUi.bots.box.ReadOnly -or -not $script:consoleUi.server.box.Text.Contains('SERVER_TEST') -or [regex]::Matches($script:consoleBotText,'BOT_TEST').Count -ne 1){throw 'Teste offline dos consoles falhou'}
 $timer.Dispose();foreach($u in $script:consoleUi.Values){$u.form.Dispose()};$script:consoleContext.Dispose();[pscustomobject]@{windows=2;read_only=$true;rendering_passed=$true;duplicate_filter_passed=$true;network_used=$false;components_started=$false} | ConvertTo-Json -Compress;return
}
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeConsoleViews');$owned=$false
try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
if(-not $owned){try{$signal=[Threading.EventWaitHandle]::OpenExisting('Local\TheBridgeConsoleViews-Show');[void]$signal.Set();$signal.Dispose()}catch{};$mutex.Dispose();foreach($u in $script:consoleUi.Values){$u.form.Dispose()};$timer.Dispose();$script:consoleContext.Dispose();return}
$signal=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\TheBridgeConsoleViews-Show')
$runspace=[runspacefactory]::CreateRunspace();$runspace.ApartmentState='STA';$runspace.ThreadOptions='ReuseThread';$runspace.Open()
$module=Join-Path $PSScriptRoot 'Bridge-Environment.ps1'
$work={param($module) . $module;try{$logs=Invoke-BridgeLocalTool 'get_server_log' @{lines=200};$status=Invoke-BridgeLocalTool 'get_status' @{};return @{logs=$logs;status=$status}}catch{return @{error=$_.Exception.Message}}}
$timer.Add_Tick({
 if($signal.WaitOne(0)){foreach($u in $script:consoleUi.Values){$u.form.Show();if($u.form.WindowState -eq 'Minimized'){$u.form.WindowState='Normal'};$u.form.BringToFront()}}
 if($script:consoleReceipt -and @($script:consoleUi.Values | Where-Object {$_.form.Visible}).Count -eq 2){
  try{$proof=[IO.Path]::GetFullPath($script:consoleReceipt);if(-not $proof.StartsWith('F:\srv\TheBridge-Remote-v2\backups\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($proof) -cne 'consoles-visible.json'){throw 'Destino de evidencia recusado'}
   if(-not(Test-Path -LiteralPath $proof)){$e=@{pid=$PID;session_id=[Diagnostics.Process]::GetCurrentProcess().SessionId;server_visible=$script:consoleUi.server.form.Visible;bots_visible=$script:consoleUi.bots.form.Visible;server_handle=$script:consoleUi.server.form.Handle.ToInt64();bots_handle=$script:consoleUi.bots.form.Handle.ToInt64();read_only=$true;utc=[DateTime]::UtcNow.ToString('o')};$b=[Text.UTF8Encoding]::new($false).GetBytes(($e | ConvertTo-Json -Compress));$stream=[IO.File]::Open($proof,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$stream.Write($b,0,$b.Length)}finally{$stream.Dispose()}}
  }catch{$script:consoleUi.server.status.Text='Janela aberta; falha ao registrar evidencia privada.'};$script:consoleReceipt=''
 }
 if($script:consolePending -and $script:consolePending.handle.IsCompleted){$p=$script:consolePending;try{$r=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors -or $r.Count -ne 1){throw 'Consulta de logs incompleta'};if($r[0].error){throw ([string]$r[0].error)};Show-ConsoleSnapshot $r[0];$script:consoleNext=[DateTime]::UtcNow.AddSeconds(5)}catch{foreach($u in $script:consoleUi.Values){$u.status.Text='Leitura indisponivel: '+$_.Exception.Message};$script:consoleNext=[DateTime]::UtcNow.AddSeconds(15)}finally{$p.ps.Dispose();$script:consolePending=$null}}
 if(-not $script:consolePending -and [DateTime]::UtcNow -ge $script:consoleNext){$ps=[PowerShell]::Create();$ps.Runspace=$runspace;[void]$ps.AddScript($work.ToString()).AddArgument($module);$script:consolePending=@{ps=$ps;handle=$ps.BeginInvoke()}}
})
try{foreach($u in $script:consoleUi.Values){$u.form.Show()};$timer.Start();[Windows.Forms.Application]::Run($script:consoleContext)}finally{$timer.Stop();$timer.Dispose();if($script:consolePending){try{$script:consolePending.ps.Stop()}catch{};$script:consolePending.ps.Dispose()};$runspace.Dispose();foreach($u in $script:consoleUi.Values){$u.form.Dispose()};$script:consoleContext.Dispose();$signal.Dispose();if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}