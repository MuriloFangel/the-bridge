#requires -Version 7.2
[CmdletBinding()]
param([switch]$SelfTest,[string]$Root='F:\srv\vibecoding')
$ErrorActionPreference='Stop'
function Test-NextConsoleCommand([string]$Text){return (-not [string]::IsNullOrWhiteSpace($Text) -and $Text.Length -le 300 -and $Text -notmatch '[\x00-\x1f\x7f]')}
Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Console requer sessao interativa'}
[Windows.Forms.Application]::EnableVisualStyles()
$form=[Windows.Forms.Form]::new();$form.Text='2 - Console | servidor Minecraft';$form.ClientSize=[Drawing.Size]::new(1100,740);$form.MinimumSize=[Drawing.Size]::new(800,520)
$table=[Windows.Forms.TableLayoutPanel]::new();$table.Dock='Fill';$table.ColumnCount=1;$table.RowCount=5;$table.Padding=[Windows.Forms.Padding]::new(6);[void]$table.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
foreach($k in @('AutoSize','AutoSize','Percent','AutoSize','AutoSize')){if($k -eq 'Percent'){[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent,100))}else{[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))}}
$status=[Windows.Forms.Label]::new();$status.AutoSize=$true;$status.MaximumSize=[Drawing.Size]::new(740,0);$status.Text='Consultando canal local...'
$bar=[Windows.Forms.FlowLayoutPanel]::new();$bar.AutoSize=$true;$bar.Dock='Fill';$bar.WrapContents=$true
$runs=[Windows.Forms.ComboBox]::new();$runs.Width=420;$runs.DropDownStyle='DropDownList';$runs.DisplayMember='Label'
$refresh=[Windows.Forms.Button]::new();$refresh.Text='Execucoes';$refresh.AutoSize=$true
$more=[Windows.Forms.Button]::new();$more.Text='Mais execucoes';$more.AutoSize=$true;$more.Enabled=$false
$followRun=[Windows.Forms.CheckBox]::new();$followRun.Text='Seguir execucao ativa';$followRun.Checked=$true;$followRun.AutoSize=$true
foreach($c in @($runs,$refresh,$more,$followRun)){$bar.Controls.Add($c)}
$output=[Windows.Forms.RichTextBox]::new();$output.Dock='Fill';$output.ReadOnly=$true;$output.WordWrap=$false;$output.MaxLength=[int]::MaxValue;$output.Font=[Drawing.Font]::new('Consolas',10);$output.BackColor=[Drawing.Color]::FromArgb(20,20,20);$output.ForeColor=[Drawing.Color]::Gainsboro
$bottom=[Windows.Forms.FlowLayoutPanel]::new();$bottom.AutoSize=$true;$bottom.Dock='Fill';$bottom.WrapContents=$true
$entry=[Windows.Forms.TextBox]::new();$entry.Width=460;$entry.MaxLength=300
$send=[Windows.Forms.Button]::new();$send.Text='Enviar';$send.AutoSize=$true
$receipt=[Windows.Forms.Button]::new();$receipt.Text='Consultar ultimo envio';$receipt.AutoSize=$true
$scroll=[Windows.Forms.CheckBox]::new();$scroll.Text='Rolar com a saida';$scroll.AutoSize=$true;$scroll.Checked=$true
foreach($c in @($entry,$send,$receipt,$scroll)){$bottom.Controls.Add($c)}
$note=[Windows.Forms.Label]::new();$note.AutoSize=$true;$note.MaximumSize=[Drawing.Size]::new(740,0);$note.Text='Enter envia diretamente ao Minecraft, nao ao Windows. Saida e acrescentada, nao substituida por paginas. Trocar manualmente a execucao limpa apenas a visualizacao.'
$table.Controls.Add($status,0,0);$table.Controls.Add($bar,0,1);$table.Controls.Add($output,0,2);$table.Controls.Add($bottom,0,3);$table.Controls.Add($note,0,4);$form.Controls.Add($table)
if($SelfTest){if(-not(Test-NextConsoleCommand 'list') -or (Test-NextConsoleCommand "list`nstop") -or (Test-NextConsoleCommand '') -or (Test-NextConsoleCommand ('a'*301))){throw 'Validacao de comando falhou'};foreach($w in @(800,1280,1920)){$form.ClientSize=[Drawing.Size]::new($w,700);$form.PerformLayout();$table.PerformLayout();foreach($p in @($bar,$bottom)){$p.PerformLayout();foreach($c in $p.Controls){if($c.Left -lt 0 -or $c.Right -gt $p.ClientSize.Width){throw 'Controle fora da largura'}}}};$form.Dispose();@{console_tests=7;network_used=$false;windows_shown=$false}|ConvertTo-Json -Compress;return}
$client=Join-Path $Root 'Bridge-ConsoleClient.ps1'
if((Get-FileHash -LiteralPath $client -Algorithm SHA256).Hash.ToLowerInvariant() -cne '3dada801a64dbf910b746b29a680eb6e5269cf4b537805eb2fd55a959145ae50'){throw 'Cliente local mudou; revisar'}
$script:pending=$null;$script:job=$null;$script:info=$null;$script:infoAt=[datetime]::MinValue;$script:session='';$script:cursor=@{segment=0;offset=0};$script:generation=0;$script:loading=$false;$script:sessionOffset=0;$script:lastSend=$null;$script:nextInfo=[datetime]::MinValue;$script:nextRead=[datetime]::MinValue;$script:history=[Collections.Generic.List[string]]::new();$script:historyAt=0;$script:draft=''
function Add-NextConsoleOutput([string]$Text){$output.AppendText($Text+"`r`n");if($scroll.Checked){$output.SelectionStart=$output.TextLength;$output.ScrollToCaret()}}
function Select-NextConsoleRun([string]$Id,[bool]$Clear){if(-not $Id -or $script:session -ceq $Id){return};$script:generation++;$script:session=$Id;$script:cursor=@{segment=0;offset=0};$script:nextRead=[datetime]::MinValue;if($Clear){$output.Clear();$script:history.Clear();$script:historyAt=0};Add-NextConsoleOutput ('--- Execucao '+$Id+' ---')}
function Queue-NextConsoleJob([hashtable]$Job){if($script:pending -or $script:job){throw 'Operacao em andamento; nenhum novo envio foi enfileirado'};$Job.generation=$script:generation;$script:job=$Job}
function Submit-NextConsoleLine {
 if(-not(Test-NextConsoleCommand $entry.Text)){throw 'Use ate 300 caracteres em uma linha'}
 if(-not $script:info -or ([datetime]::UtcNow-$script:infoAt).TotalSeconds -gt 10){$script:nextInfo=[datetime]::MinValue;throw 'Estado desatualizado; aguardando consulta, sem envio'}
 $active=$script:info.channels.server;if(-not $active.active -or $active.session -cne $script:session){throw 'Execucao arquivada ou servidor parado: somente leitura'}
 if($active.capture_fault -or $script:info.service_fault){throw 'Falha de captura/canal; comando bloqueado'}
 $j=@{kind='send';session=$script:session;command=$entry.Text.Trim();request=[guid]::NewGuid().ToString()};Queue-NextConsoleJob $j;$script:lastSend=$j;$script:history.Add($j.command);$script:historyAt=$script:history.Count;$entry.Clear();Add-NextConsoleOutput ('> '+$j.command+' | '+$j.request)
}
$send.Add_Click({try{Submit-NextConsoleLine}catch{Add-NextConsoleOutput $_.Exception.Message}})
$receipt.Add_Click({try{if(-not $script:lastSend){throw 'Nenhum envio nesta janela'};Queue-NextConsoleJob @{kind='outcome';session=$script:lastSend.session;request=$script:lastSend.request}}catch{Add-NextConsoleOutput $_.Exception.Message}})
$refresh.Add_Click({try{Queue-NextConsoleJob @{kind='sessions';offset=0}}catch{Add-NextConsoleOutput $_.Exception.Message}})
$more.Add_Click({try{Queue-NextConsoleJob @{kind='sessions';offset=$script:sessionOffset}}catch{Add-NextConsoleOutput $_.Exception.Message}})
$runs.Add_SelectedIndexChanged({if(-not $script:loading -and $runs.SelectedItem){$followRun.Checked=$false;Select-NextConsoleRun ([string]$runs.SelectedItem.Id) $true}})
$entry.Add_KeyDown({param($sender,$e) switch([string]$e.KeyCode){'Enter'{$e.SuppressKeyPress=$true;try{Submit-NextConsoleLine}catch{Add-NextConsoleOutput $_.Exception.Message}};'Up'{$e.SuppressKeyPress=$true;if($script:historyAt -eq $script:history.Count){$script:draft=$entry.Text};if($script:historyAt -gt 0){$script:historyAt--;$entry.Text=$script:history[$script:historyAt]}};'Down'{$e.SuppressKeyPress=$true;if($script:historyAt -lt $script:history.Count){$script:historyAt++};$entry.Text=$(if($script:historyAt -eq $script:history.Count){$script:draft}else{$script:history[$script:historyAt]})}}})
$worker=[runspacefactory]::CreateRunspace();$worker.Open()
$work={param($client,$job) try{. $client;switch($job.kind){'info'{$value=Invoke-LocalConsole @{op='info'}};'sessions'{$value=Invoke-LocalConsole @{op='sessions';channel='server';offset=$job.offset;limit=50}};'read'{$value=Invoke-LocalConsole @{op='read';channel='server';session=$job.session;cursor=$job.cursor;limit=100}};'send'{$value=Invoke-LocalConsole @{op='send';channel='server';session=$job.session;request_id=$job.request;command=$job.command;confirmed=$true}};'outcome'{$value=Invoke-LocalConsole @{op='outcome';channel='server';session=$job.session;request_id=$job.request}};default{throw 'Operacao invalida'}};return @{ok=$true;value=$value}}catch{return @{ok=$false;error=$_.Exception.Message}}}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=250
$timer.Add_Tick({try{
 if($script:pending -and $script:pending.handle.IsCompleted){$p=$script:pending;try{$items=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors -or $items.Count -ne 1){throw 'Resposta incompleta'};$reply=$items[0];if(-not $reply.ok){throw $reply.error};$v=$reply.value
  switch($p.job.kind){
   'info'{$script:info=$v;$script:infoAt=[datetime]::UtcNow;$a=$v.channels.server;$status.Text='Ativo: '+$a.active+' | PID: '+$a.pid+' | Recuperacao: '+$v.status.server_recovery.phase+' | Tentativas: '+$v.status.server_recovery.attempts;if($a.capture_fault){$status.Text+=' | FALHA: '+$a.capture_fault};if($followRun.Checked -and $a.session){Select-NextConsoleRun ([string]$a.session) $false};if(-not $runs.Items.Count -and -not $script:job){$script:job=@{kind='sessions';offset=0;generation=$script:generation}}}
   'sessions'{$script:loading=$true;try{if($p.job.offset -eq 0){$runs.Items.Clear()};foreach($r in @($v.entries)){[void]$runs.Items.Add([pscustomobject]@{Id=[string]$r.session;Label=([string]$r.started_at+' | PID '+$r.pid+' | '+$r.session)})};$script:sessionOffset=[int]$v.next_offset;$more.Enabled=[bool]$v.more;for($i=0;$i -lt $runs.Items.Count;$i++){if($runs.Items[$i].Id -ceq $script:session){$runs.SelectedIndex=$i;break}}}finally{$script:loading=$false}}
   'read'{if($p.job.generation -eq $script:generation -and $p.job.session -ceq $script:session){foreach($r in @($v.entries)){Add-NextConsoleOutput ('['+$r.at+'] ['+$r.kind+'] '+[regex]::Replace([string]$r.text,'\x1b\[[0-?]*[ -/]*[@-~]','').TrimEnd());if($r.kind -eq 'command'){$script:history.Add(([string]$r.text).Trim())}};$script:cursor=$v.cursor;if(-not $entry.Text){$script:historyAt=$script:history.Count};if($v.more){$script:nextRead=[datetime]::MinValue}}}
   'send'{Add-NextConsoleOutput ('Recibo: '+$v.record.phase+'; retorno de transporte nao prova conclusao.');$script:nextInfo=[datetime]::MinValue}
   'outcome'{Add-NextConsoleOutput ('Resultado consultado: '+$v.phase+'; sem reenvio.')}
  }
 }catch{Add-NextConsoleOutput ('Falha em '+$p.job.kind+': '+$_.Exception.Message+$(if($p.job.kind -eq 'send'){' | Resultado pode ser incerto. Consulte o recibo, nao reenvie automaticamente.'}else{''}));if($p.job.kind -eq 'info'){$script:info=$null}}
 finally{$p.ps.Dispose();$script:pending=$null}}
 $idle=(-not $script:pending -and -not $script:job);$fresh=($script:info -and ([datetime]::UtcNow-$script:infoAt).TotalSeconds -le 10);$a=$script:info.channels.server;$send.Enabled=($idle -and $fresh -and $a.active -and $a.session -ceq $script:session -and -not $a.capture_fault);$receipt.Enabled=($idle -and $null -ne $script:lastSend)
 if($idle){if([datetime]::UtcNow -ge $script:nextInfo){$script:job=@{kind='info';generation=$script:generation};$script:nextInfo=[datetime]::UtcNow.AddSeconds(5)}elseif($script:session -and [datetime]::UtcNow -ge $script:nextRead){$script:job=@{kind='read';session=$script:session;cursor=$script:cursor;generation=$script:generation};$script:nextRead=[datetime]::UtcNow.AddSeconds(1)}}
 if(-not $script:pending -and $script:job){$j=$script:job;$script:job=$null;$ps=[PowerShell]::Create();$ps.Runspace=$worker;[void]$ps.AddScript($work.ToString()).AddArgument($client).AddArgument($j);$script:pending=@{ps=$ps;job=$j;handle=$ps.BeginInvoke()}}
}catch{Add-NextConsoleOutput ('Erro da interface: '+$_.Exception.Message)}})
$form.Add_FormClosing({param($sender,$e) if($script:pending -and $script:pending.job.kind -eq 'send'){$e.Cancel=$true;Add-NextConsoleOutput 'Aguarde o envio terminar antes de fechar.'}})
try{$timer.Start();[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();if($script:pending){try{$script:pending.ps.Stop()}catch{};$script:pending.ps.Dispose()};$worker.Dispose();$form.Dispose()}