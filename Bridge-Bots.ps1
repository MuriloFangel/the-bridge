#requires -Version 7.2
[CmdletBinding()]
param([switch]$SelfTest,[string]$Root='F:\srv\vibecoding')
$ErrorActionPreference='Stop'
function ConvertTo-BotCommand([string]$Action,[int]$Id,[int]$Count,[string]$Text){
 if($Action -in @('list','help','watch all','watch off','exit')){return $Action}
 if($Action -eq 'add'){if($Count -lt 1 -or $Count -gt 32){throw 'Quantidade: 1 a 32'};return "add $Count"}
 if($Action -in @('off','back','watch','say') -and $Id -lt 1){throw 'Informe um ID positivo'}
 if($Action -in @('say','all') -and ([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -gt 100 -or $Text -match '[\x00-\x1f\x7f]')){throw 'Mensagem: 1 a 100 caracteres em uma linha'}
 switch($Action){'off'{return "off $Id"};'back'{return "back $Id"};'watch'{return "watch $Id"};'say'{return "say $Id $Text"};'all'{return "all $Text"};default{throw 'Acao invalida'}}
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Abra na sessao interativa do Windows'}
[Windows.Forms.Application]::EnableVisualStyles()
$form=[Windows.Forms.Form]::new();$form.Text='1 - Bots';$form.ClientSize=[Drawing.Size]::new(1024,720);$form.MinimumSize=[Drawing.Size]::new(800,560);$form.StartPosition='CenterScreen'
$table=[Windows.Forms.TableLayoutPanel]::new();$table.Dock='Fill';$table.ColumnCount=1;$table.RowCount=5;$table.Padding=[Windows.Forms.Padding]::new(8)
[void]$table.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
foreach($kind in @('AutoSize','AutoSize','Percent','AutoSize','AutoSize')){if($kind -eq 'Percent'){[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent,100))}else{[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))}}
$status=[Windows.Forms.Label]::new();$status.AutoSize=$true;$status.Text='Aguardando ponte; abrir a janela nao inicia componentes.'
$toolbar=[Windows.Forms.FlowLayoutPanel]::new();$toolbar.Dock='Fill';$toolbar.AutoSize=$true;$toolbar.WrapContents=$true
function Add-BotFieldLabel([string]$Text){$label=[Windows.Forms.Label]::new();$label.Text=$Text;$label.AutoSize=$true;$label.Margin=[Windows.Forms.Padding]::new(4,7,2,2);$toolbar.Controls.Add($label)}
Add-BotFieldLabel 'ID:'
$botId=[Windows.Forms.NumericUpDown]::new();$botId.Minimum=1;$botId.Maximum=2147483647;$botId.Value=1;$botId.Width=65;$toolbar.Controls.Add($botId)
Add-BotFieldLabel 'Quantidade:'
$count=[Windows.Forms.NumericUpDown]::new();$count.Minimum=1;$count.Maximum=32;$count.Value=1;$count.Width=55;$toolbar.Controls.Add($count)
Add-BotFieldLabel 'Mensagem ou /comando:'
$message=[Windows.Forms.TextBox]::new();$message.Width=260;$message.MaxLength=100;$toolbar.Controls.Add($message)
$script:buttons=@{}
foreach($spec in @(@('start','Iniciar controlador'),@('list','Listar'),@('add','Adicionar'),@('off','Desconectar ID'),@('back','Reconectar ID'),@('watch','Chat do ID'),@('watch all','Todos os chats'),@('watch off','Ocultar chats'),@('say','Enviar ao ID'),@('all','Enviar a todos'),@('help','Ajuda'),@('exit','Encerrar controlador'))){
 $button=[Windows.Forms.Button]::new();$button.Text=$spec[1];$button.Tag=$spec[0];$button.AutoSize=$true;$button.Margin=[Windows.Forms.Padding]::new(4);$toolbar.Controls.Add($button);$script:buttons[$spec[0]]=$button
 $button.Add_Click({param($sender,$e) try{if($sender.Tag -eq 'start'){Queue-BotOperation @{kind='start'}}else{Send-BotLine (ConvertTo-BotCommand ([string]$sender.Tag) ([int]$botId.Value) ([int]$count.Value) $message.Text)}}catch{Add-BotOutput $_.Exception.Message}})
}
$output=[Windows.Forms.RichTextBox]::new();$output.Dock='Fill';$output.ReadOnly=$true;$output.WordWrap=$false;$output.MaxLength=[int]::MaxValue;$output.Font=[Drawing.Font]::new('Consolas',10);$output.BackColor=[Drawing.Color]::FromArgb(20,20,20);$output.ForeColor=[Drawing.Color]::Gainsboro
$entryPanel=[Windows.Forms.FlowLayoutPanel]::new();$entryPanel.Dock='Fill';$entryPanel.AutoSize=$true;$entryPanel.WrapContents=$true
$inputBox=[Windows.Forms.TextBox]::new();$inputBox.Width=450;$inputBox.MaxLength=500
$send=[Windows.Forms.Button]::new();$send.Text='Enviar direto';$send.AutoSize=$true
$receipt=[Windows.Forms.Button]::new();$receipt.Text='Consultar ultimo envio';$receipt.AutoSize=$true
$follow=[Windows.Forms.CheckBox]::new();$follow.Text='Seguir';$follow.Checked=$true;$follow.AutoSize=$true
foreach($control in @($inputBox,$send,$receipt,$follow)){$entryPanel.Controls.Add($control)}
$note=[Windows.Forms.Label]::new();$note.AutoSize=$true;$note.MaximumSize=[Drawing.Size]::new(730,0);$note.Text='Iniciar controlador pode conectar os bots iniciais configurados. Nao inicia o servidor. Fechar esta janela nao encerra os bots.'
$table.Controls.Add($status,0,0);$table.Controls.Add($toolbar,0,1);$table.Controls.Add($output,0,2);$table.Controls.Add($entryPanel,0,3);$table.Controls.Add($note,0,4);$form.Controls.Add($table)
if($SelfTest){
 $passed=0
 foreach($t in @(@('list',1,1,'','list'),@('add',1,2,'','add 2'),@('off',3,1,'','off 3'),@('back',3,1,'','back 3'),@('watch',2,1,'','watch 2'),@('watch all',1,1,'','watch all'),@('watch off',1,1,'','watch off'),@('say',2,1,'ola','say 2 ola'),@('all',1,1,'/help','all /help'),@('exit',1,1,'','exit'))){if((ConvertTo-BotCommand $t[0] $t[1] $t[2] $t[3]) -cne $t[4]){throw 'Falha de montagem de comando'};$passed++}
 foreach($t in @(@('add',1,0,''),@('say',0,1,'ola'),@('all',1,1,"a`nb"),@('say',1,1,('a'*101)),@('unknown',1,1,''))){$denied=$false;try{$null=ConvertTo-BotCommand $t[0] $t[1] $t[2] $t[3]}catch{$denied=$true};if(-not $denied){throw 'Entrada invalida aceita'};$passed++}
 foreach($w in @(800,1280,1920)){$form.ClientSize=[Drawing.Size]::new($w,720);$form.PerformLayout();$table.PerformLayout();foreach($panel in @($toolbar,$entryPanel)){$panel.PerformLayout();foreach($b in $panel.Controls){if($b.Left -lt 0 -or $b.Right -gt $panel.ClientSize.Width){throw ('Controle fora da largura: '+$b.Text)}}};$passed++}
 $form.Dispose();[pscustomobject]@{passed=$passed;scope='command validation and horizontal layout';network_used=$false;windows_shown=$false;real_commands_sent=$false}|ConvertTo-Json -Compress;return
}
$client=Join-Path $Root 'Bridge-ConsoleClient.ps1'
if((Get-FileHash -LiteralPath $client -Algorithm SHA256).Hash.ToLowerInvariant() -cne '3dada801a64dbf910b746b29a680eb6e5269cf4b537805eb2fd55a959145ae50'){throw 'Cliente local mudou: revise antes de executar'}
$script:jobs=[Collections.Generic.Queue[object]]::new();$script:pending=$null;$script:info=$null;$script:infoAt=[datetime]::MinValue;$script:session='';$script:cursor=@{segment=0;offset=0};$script:nextInfo=[datetime]::MinValue;$script:nextRead=[datetime]::MinValue;$script:lastSend=$null
$script:history=[Collections.Generic.List[string]]::new();$script:historyAt=0;$script:draft=''
function Add-BotOutput([string]$Text){$output.AppendText($Text+"`r`n");if($follow.Checked){$output.SelectionStart=$output.TextLength;$output.ScrollToCaret()}}
function Queue-BotOperation([hashtable]$Job){if($script:pending -or $script:jobs.Count){throw 'Operacao em andamento. Aguarde; nada foi enfileirado.'};$script:jobs.Enqueue($Job)}
function Send-BotLine([string]$Command){
 if([string]::IsNullOrWhiteSpace($Command) -or $Command.Length -gt 500 -or $Command -match '[\x00-\x1f\x7f]'){throw 'Use um comando em uma linha'}
 if(-not $script:info -or ([datetime]::UtcNow-$script:infoAt).TotalSeconds -gt 10){$script:nextInfo=[datetime]::MinValue;throw 'Atualizando o estado. Nenhum comando enviado; tente novamente apos atualizar.'}
 if(-not $script:info.channels.bots.active -or -not $script:session){throw 'Controlador parado: use Iniciar controlador. add nao inicia o controlador.'}
 if($script:info.channels.bots.capture_fault -or $script:info.service_fault){throw 'Falha de captura/canal; envio bloqueado'}
 $job=@{kind='send';command=$Command.Trim();session=$script:session;request=[guid]::NewGuid().ToString()};Queue-BotOperation $job;$script:lastSend=$job
 $script:history.Add($job.command);$script:historyAt=$script:history.Count;Add-BotOutput ('> '+$job.command+' | ID '+$job.request)
}
$send.Add_Click({try{Send-BotLine $inputBox.Text;$inputBox.Clear()}catch{Add-BotOutput $_.Exception.Message}})
$receipt.Add_Click({try{if(-not $script:lastSend){throw 'Nenhum envio nesta janela'};Queue-BotOperation @{kind='outcome';session=$script:lastSend.session;request=$script:lastSend.request}}catch{Add-BotOutput $_.Exception.Message}})
$inputBox.Add_KeyDown({param($sender,$e) switch([string]$e.KeyCode){
 'Enter'{$e.SuppressKeyPress=$true;try{Send-BotLine $inputBox.Text;$inputBox.Clear()}catch{Add-BotOutput $_.Exception.Message}}
 'Up'{$e.SuppressKeyPress=$true;if($script:historyAt -eq $script:history.Count){$script:draft=$inputBox.Text};if($script:historyAt -gt 0){$script:historyAt--;$inputBox.Text=$script:history[$script:historyAt]}}
 'Down'{$e.SuppressKeyPress=$true;if($script:historyAt -lt $script:history.Count){$script:historyAt++};$inputBox.Text=$(if($script:historyAt -eq $script:history.Count){$script:draft}else{$script:history[$script:historyAt]})}
}})
$worker=[runspacefactory]::CreateRunspace();$worker.Open()
$work={param($client,$root,$job)
 try{
  . $client
  switch($job.kind){
   'start'{
    $c=[IO.File]::ReadAllText('F:\srv\TheBridge-Remote-v2\connection.json')|ConvertFrom-Json
    if($c.project -ine $root -or [int]$c.port -lt 1 -or [int]$c.port -gt 65535){throw 'Configuracao local inesperada'}
    $body=@{jsonrpc='2.0';id=[guid]::NewGuid().ToString();method='tools/call';params=@{name='start_bot_controller';arguments=@{}}}|ConvertTo-Json -Depth 8 -Compress
    try{$r=Invoke-RestMethod -Uri ('http://127.0.0.1:'+([int]$c.port)+'/mcp') -Method Post -ContentType 'application/json' -Headers @{Authorization=('Bearer '+$c.key)} -Body $body -TimeoutSec 60}catch{throw 'Inicio sem resposta conclusiva; atualize o estado antes de repetir'}
    if($r.error){throw 'Falha RPC ao solicitar inicio'};if($r.result.isError){throw (([string]$r.result.content[0].text).Replace([string]$c.key,'[REDACTED]'))};$value=[string]$r.result.content[0].text|ConvertFrom-Json -AsHashtable
   }
   'info'{$value=Invoke-LocalConsole @{op='info'}}
   'read'{$value=Invoke-LocalConsole @{op='read';channel='bots';session=$job.session;cursor=$job.cursor;limit=100}}
   'send'{$fresh=Invoke-LocalConsole @{op='info'};if(-not $fresh.channels.bots.active -or $fresh.channels.bots.session -cne $job.session){throw 'Alvo mudou; comando nao enviado'};$value=Invoke-LocalConsole @{op='send';channel='bots';session=$job.session;request_id=$job.request;command=$job.command;confirmed=$true}}
   'outcome'{$value=Invoke-LocalConsole @{op='outcome';channel='bots';session=$job.session;request_id=$job.request}}
   default{throw 'Operacao invalida'}
  };return @{ok=$true;value=$value}
 }catch{return @{ok=$false;error=$_.Exception.Message}}
}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=250
$timer.Add_Tick({try{
 if($script:pending -and $script:pending.handle.IsCompleted){$p=$script:pending;try{
  $items=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors -or $items.Count -ne 1){throw 'Resposta incompleta'};$reply=$items[0];if(-not $reply.ok){throw $reply.error};$v=$reply.value
  switch($p.job.kind){
   'start'{Add-BotOutput ('Inicio: '+($v|ConvertTo-Json -Depth 5 -Compress));$script:nextInfo=[datetime]::MinValue}
   'info'{$script:info=$v;$script:infoAt=[datetime]::UtcNow;$a=$v.channels.bots;$status.Text='Controlador ativo: '+$a.active+' | PID: '+$a.pid+' | Servidor na porta: '+$v.status.server_listening;if($a.capture_fault){$status.Text+=' | Falha de captura: '+$a.capture_fault};if($v.service_fault){$status.Text+=' | Falha de canal: '+$v.service_fault};if($a.session -and $a.session -cne $script:session){$script:session=[string]$a.session;$script:cursor=@{segment=0;offset=0};Add-BotOutput ('--- Execucao '+$script:session+' ---')}}
   'read'{if($p.job.session -ceq $script:session){foreach($row in @($v.entries)){Add-BotOutput ('['+$row.at+'] ['+$row.kind+'] '+[regex]::Replace([string]$row.text,'\x1b\[[0-?]*[ -/]*[@-~]','').TrimEnd())};$script:cursor=$v.cursor}}
   'send'{Add-BotOutput ('Recibo '+$p.job.request+': '+$v.record.phase+' (transporte nao comprova conclusao).');$script:nextInfo=[datetime]::MinValue}
   'outcome'{Add-BotOutput ('Consulta '+$p.job.request+': '+$v.phase+'; sem reenvio.')}
  }
 }catch{Add-BotOutput ('Falha em '+$p.job.kind+': '+$_.Exception.Message+$(if($p.job.kind -eq 'send'){' | Resultado pode ser incerto. Consulte o recibo; nao foi reenviado.'}else{''}));if($p.job.kind -eq 'info'){$script:info=$null;$status.Text='Canal indisponivel; veja a mensagem abaixo.'};$script:nextInfo=[datetime]::MinValue}
 finally{$p.ps.Dispose();$script:pending=$null}}
 $idle=(-not $script:pending -and $script:jobs.Count -eq 0);$fresh=($script:info -and ([datetime]::UtcNow-$script:infoAt).TotalSeconds -le 10);$active=($fresh -and [bool]$script:info.channels.bots.active)
 foreach($k in $script:buttons.Keys){$script:buttons[$k].Enabled=($idle -and $fresh -and $(if($k -eq 'start'){-not $active}else{$active}))};$send.Enabled=($idle -and $active);$receipt.Enabled=($idle -and $null -ne $script:lastSend)
 if($idle){if([datetime]::UtcNow -ge $script:nextInfo){$script:jobs.Enqueue(@{kind='info'});$script:nextInfo=[datetime]::UtcNow.AddSeconds(5)}elseif($script:session -and [datetime]::UtcNow -ge $script:nextRead){$script:jobs.Enqueue(@{kind='read';session=$script:session;cursor=$script:cursor});$script:nextRead=[datetime]::UtcNow.AddSeconds(1)}}
 if(-not $script:pending -and $script:jobs.Count){$job=$script:jobs.Dequeue();$ps=[PowerShell]::Create();$ps.Runspace=$worker;[void]$ps.AddScript($work.ToString()).AddArgument($client).AddArgument($Root).AddArgument($job);$script:pending=@{ps=$ps;job=$job;handle=$ps.BeginInvoke()}}
}catch{Add-BotOutput ('Erro da interface: '+$_.Exception.Message)}})
$form.Add_FormClosing({param($sender,$e) if($script:pending -and $script:pending.job.kind -in @('start','send')){$e.Cancel=$true;Add-BotOutput 'Aguarde a operacao pendente terminar antes de fechar.'}})
try{$timer.Start();[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();if($script:pending){try{$script:pending.ps.Stop()}catch{};$script:pending.ps.Dispose()};$worker.Dispose();$form.Dispose()}