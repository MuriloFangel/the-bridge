#requires -Version 7.2
[CmdletBinding()]
param([string]$ProjectPath='F:\srv\vibecoding',[switch]$AutoStart,[switch]$SelfTest,[switch]$ReplaceLegacyPanel,[string]$InspectionReceipt='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Abra o painel na sessao interativa'}
[Windows.Forms.Application]::EnableVisualStyles()
$form=[Windows.Forms.Form]::new();$form.Text='The Bridge - Ambiente';$form.ClientSize=[Drawing.Size]::new(850,560);$form.MinimumSize=[Drawing.Size]::new(760,500);$form.StartPosition='CenterScreen'
$table=[Windows.Forms.TableLayoutPanel]::new();$table.Dock='Fill';$table.ColumnCount=1;$table.RowCount=4;$table.Padding=[Windows.Forms.Padding]::new(8);[void]$table.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
foreach($s in @('AutoSize','AutoSize','Percent','AutoSize')){if($s -eq 'Percent'){[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent,100))}else{[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))}}
$label=[Windows.Forms.Label]::new();$label.AutoSize=$true
$bar=[Windows.Forms.FlowLayoutPanel]::new();$bar.Dock='Fill';$bar.AutoSize=$true;$bar.WrapContents=$true
$script:buttons=@{}
foreach($spec in @(@('StartEnv','Iniciar ambiente'),@('StopEnv','Encerrar ambiente'),@('StartServer','Iniciar servidor'),@('StopServer','Parar servidor da ponte'),@('StartBots','Iniciar bots'),@('StopBots','Parar bots'),@('Status','Atualizar estado'),@('Cancel','Cancelar contagem'),@('Console','2 - Console'),@('Bots','1 - Bots'))){$b=[Windows.Forms.Button]::new();$b.AutoSize=$true;$b.Text=$spec[1];$b.Tag=$spec[0];$bar.Controls.Add($b);$script:buttons[$spec[0]]=$b;$b.Add_Click({param($sender,$e) try{switch([string]$sender.Tag){'Cancel'{if($script:pending -and $script:pending.action -eq 'StartEnv'){$script:pending.cancel.Cancel();$log.AppendText("Cancelamento da espera solicitado; acoes ja concluidas nao sao desfeitas.`r`n")}else{$script:cancelled=$true;$label.Text='Inicio automatico cancelado; modo manual.'}};'Console'{Open-BridgeNextWindow 'Bridge-Console2.ps1'};'Bots'{Open-BridgeNextWindow 'Bridge-Bots.ps1'};default{Start-BridgeNextOperation ([string]$sender.Tag)}}}catch{$log.AppendText($_.Exception.Message+"`r`n")}})}
$desktop=[Windows.Forms.CheckBox]::new();$desktop.Text='No fluxo de ambiente, abrir/fechar CMPack e pastas gerenciadas';$desktop.AutoSize=$true;$desktop.Checked=$true;$bar.Controls.Add($desktop)
$log=[Windows.Forms.TextBox]::new();$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Both';$log.WordWrap=$false;$log.Dock='Fill'
$note=[Windows.Forms.Label]::new();$note.AutoSize=$true;$note.MaximumSize=[Drawing.Size]::new(700,0);$note.Text='Iniciar bots e independente de Iniciar ambiente e pode conectar os bots configurados. Fechar o painel preserva componentes. Stop desarma a recuperacao do Java.'
$table.Controls.Add($label,0,0);$table.Controls.Add($bar,0,1);$table.Controls.Add($log,0,2);$table.Controls.Add($note,0,3);$form.Controls.Add($table)
if($SelfTest){foreach($w in @(760,1280,1920)){$form.ClientSize=[Drawing.Size]::new($w,600);$form.PerformLayout();$table.PerformLayout();$bar.PerformLayout();foreach($b in $script:buttons.Values){if($b.Left -lt 0 -or $b.Right -gt $bar.ClientSize.Width){throw 'Botao fora da largura'}}};if($script:buttons.Count -ne 10){throw 'Botoes incompletos'};$form.Dispose();@{panel_tests=4;network_used=$false;windows_shown=$false}|ConvertTo-Json -Compress;return}
$script:pending=$null;$script:cancelled=(-not $AutoStart);$clock=[Diagnostics.Stopwatch]::StartNew()
function Open-BridgeNextWindow([string]$File){$null=Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList ('-NoLogo -NoProfile -STA -File "'+(Join-Path $ProjectPath $File)+'"') -WorkingDirectory $ProjectPath}
function Start-BridgeNextOperation([string]$Action){
 if($script:pending){throw 'Operacao em andamento; nao houve novo disparo'}
 $script:cancelled=$true;$label.Text='Contagem encerrada. Operacao: '+$Action;$script:buttons.Cancel.Enabled=$false
 $rs=[runspacefactory]::CreateRunspace();$rs.ApartmentState='STA';$rs.Open();$ps=[PowerShell]::Create();$ps.Runspace=$rs
 $cancel=[Threading.CancellationTokenSource]::new()
 $work={param($file,$root,$action,$desktop,$token) . $file -Root $root;$script:BridgeNextCancellation=$token;try{return @{ok=$true;result=(Invoke-BridgeNextAction $action $desktop)}}catch{return @{ok=$false;error=$_.Exception.Message}}}
 [void]$ps.AddScript($work.ToString()).AddArgument((Join-Path $ProjectPath 'Bridge-NextRuntime.ps1')).AddArgument($ProjectPath).AddArgument($Action).AddArgument($desktop.Checked).AddArgument($cancel.Token)
 $script:pending=@{ps=$ps;runspace=$rs;handle=$ps.BeginInvoke();action=$Action;informationAt=0;cancel=$cancel};$log.AppendText('Operacao: '+$Action+"`r`n")
}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=250
$timer.Add_Tick({
 if($script:pending){$p=$script:pending;while($p.informationAt -lt $p.ps.Streams.Information.Count){$log.AppendText([string]$p.ps.Streams.Information[$p.informationAt].MessageData+"`r`n");$p.informationAt++}
  if($p.handle.IsCompleted){try{$results=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors){throw 'Falha interna: consulte o resultado antes de repetir'};foreach($r in $results){if($r.ok){$log.AppendText(($r.result|ConvertTo-Json -Depth 9)+"`r`n")}else{$log.AppendText('Operacao nao concluida: '+$r.error+"`r`n")}};$label.Text='Operacao encerrada; consulte resultado e Atualizar estado.'}catch{$log.AppendText($_.Exception.Message+"`r`n")}finally{$p.ps.Dispose();$p.runspace.Dispose();$p.cancel.Dispose();$script:pending=$null}}
 }
 foreach($k in @('StartEnv','StopEnv','StartServer','StopServer','StartBots','StopBots','Status')){$script:buttons[$k].Enabled=($null -eq $script:pending)}
 $script:buttons.Cancel.Enabled=((-not $script:cancelled -and $null -eq $script:pending) -or ($script:pending -and $script:pending.action -eq 'StartEnv'));$script:buttons.Cancel.Text=$(if($script:pending -and $script:pending.action -eq 'StartEnv'){'Cancelar espera'}else{'Cancelar contagem'})
 if(-not $script:cancelled){$remaining=[math]::Max(0,[math]::Ceiling(30-$clock.Elapsed.TotalSeconds));$label.Text='Inicio automatico em '+$remaining+' segundos.';if($remaining -le 0){Start-BridgeNextOperation 'StartEnv'}}
})
$form.Add_FormClosing({param($sender,$e) if($script:pending){$e.Cancel=$true;$log.AppendText("Aguarde a operacao terminar antes de fechar.`r`n")}})
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeEnvironmentPanel');$owned=$false
try{try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true};if(-not $owned){throw 'Outro painel Ambiente esta aberto. Feche-o preservando os componentes.'};if($script:cancelled){$label.Text='Modo manual. Nenhum componente iniciado ao abrir.'};$timer.Start();[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();if($script:pending){try{$script:pending.ps.Stop()}catch{};$script:pending.ps.Dispose();$script:pending.runspace.Dispose();$script:pending.cancel.Dispose()};if($owned){$mutex.ReleaseMutex()};$mutex.Dispose();$form.Dispose()}