# Bridge-Delivery-ID: TB-20261103T152122Z-2F392312
# Bridge-Base-Commit: 366ca28c8eddc28138ccc3cea5513a67f78995a0
#requires -Version 7.2
[CmdletBinding()]
param([switch]$SelfTest,[string]$InspectionReceipt='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if(-not $SelfTest -and [Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Consoles requerem sessao interativa'}
. (Join-Path $PSScriptRoot 'Bridge-ConsoleClient.ps1')
[Windows.Forms.Application]::EnableVisualStyles()
$script:views=@{};$script:requests=[Collections.Generic.Queue[object]]::new();$script:pending=$null;$script:override=$null;$script:lastInfo=$null;$script:infoAt=[DateTime]::MinValue;$script:nextInfo=[DateTime]::MinValue;$script:nextCall=[DateTime]::MinValue;$script:closing=$false;$script:context=[Windows.Forms.ApplicationContext]::new()
function Add-ConsoleHistory($u,[string]$Text){if(-not $u.history.Count -or $u.history[$u.history.Count-1] -cne $Text){$u.history.Add($Text)};while($u.history.Count -gt 200){$u.history.RemoveAt(0)};$u.historyIndex=$u.history.Count}
function Move-ConsoleHistory([string]$Role,[int]$Direction){$u=$script:views[$Role];if(-not $u.history.Count){return};if($u.historyIndex -eq $u.history.Count -and $Direction -lt 0){$u.draft=$u.input.Text};$u.historyIndex=[math]::Max(0,[math]::Min($u.history.Count,$u.historyIndex+$Direction));$u.input.Text=$(if($u.historyIndex -eq $u.history.Count){$u.draft}else{$u.history[$u.historyIndex]});$u.input.SelectionStart=$u.input.TextLength}
function Queue-ConsoleCall([string]$Role,[hashtable]$Payload){
 if($Payload.op -notin @('info','sessions','read','send','outcome')){throw 'Operacao fora do escopo'}
 if($Payload.op -ne 'info' -and ($Role -notin @('server','bots') -or $Payload.channel -cne $Role)){throw 'Canal divergente'}
 if($Payload.op -eq 'send' -and ($Payload.confirmed -ne $true -or [string]::IsNullOrWhiteSpace([string]$Payload.command) -or [string]$Payload.command -match '[\x00-\x1f\x7f]')){throw 'Envio nao confirmado ou invalido'}
 if($script:requests.Count -ge 30){throw 'Fila cheia; aguarde'}
 $generation=0;if($Role){$generation=$script:views[$Role].generation}
 $script:requests.Enqueue(@{role=$Role;payload=$Payload;generation=$generation})
}
function Load-ConsolePage([string]$Role){$u=$script:views[$Role];if(-not $u.session -or $u.readQueued){return};$u.readQueued=$true;Queue-ConsoleCall $Role @{op='read';channel=$Role;session=$u.session;cursor=$u.starts[$u.page];limit=100}}
function Select-ConsoleRun([string]$Role,[string]$Session,[bool]$Follow){$u=$script:views[$Role];$u.generation++;$u.session=$Session;$u.starts=[Collections.Generic.List[object]]::new();$u.starts.Add(@{segment=0;offset=0});$u.page=0;$u.nextCursor=$null;$u.more=$false;$u.readQueued=$false;$u.follow.Checked=$Follow;$u.box.Clear();$u.history.Clear();$u.historyIndex=0;Load-ConsolePage $Role}
function Navigate-ConsolePage([string]$Role,[string]$Mode){$u=$script:views[$Role];$u.follow.Checked=$false;switch($Mode){'first'{$u.page=0};'previous'{if($u.page -le 0){return};$u.page--};'next'{if(-not $u.more -or -not $u.nextCursor){return};if($u.page+1 -eq $u.starts.Count){$u.starts.Add($u.nextCursor)}else{$u.starts[$u.page+1]=$u.nextCursor};$u.page++};'reload'{};default{throw 'Navegacao invalida'}};Load-ConsolePage $Role}
function Submit-ConsoleCommand([string]$Role){
 $u=$script:views[$Role];if($u.sendPending){$u.result.Text='Envio em andamento; nao repetido.';return}
 if(-not $script:lastInfo -or ([DateTime]::UtcNow-$script:infoAt).TotalSeconds -gt 10){Queue-ConsoleCall '' @{op='info'};$u.result.Text='Atualizando alvo; nenhum envio. Confira e tente novamente.';return}
 $target=$script:lastInfo.channels[$Role];if(-not $target.active -or -not $u.session -or $u.session -cne $target.session -or $target.capture_fault){$u.result.Text='Alvo atual nao confirmado ou execucao arquivada; comando nao enviado.';return}
 $command=$u.input.Text.Trim();$max=500;if($Role -eq 'server'){$max=300};if(-not $command -or $command.Length -gt $max -or $command -match '[\x00-\x1f\x7f]'){$u.result.Text='Use um comando valido em uma unica linha.';return}
 $message='Enviar para '+$Role+' | PID '+$target.pid+' | execucao '+$u.session+"?`r`n`r`n"+$command+"`r`n`r`nComandos podem alterar ou interromper o componente. Nao ha reenvio automatico."
 if($u.lastRequest -and -not $u.lastRequest.complete){$message+="`r`nExiste envio anterior sem resultado conclusivo. Um novo envio pode duplicar efeitos."}
 $approved=$false;if($SelfTest){$approved=$script:testApproval}else{$approved=([Windows.Forms.MessageBox]::Show($u.form,$message,'Confirmar comando','YesNo','Warning','Button2') -eq 'Yes')}
 if(-not $approved){$u.result.Text='Envio cancelado.';return}
 $id=[guid]::NewGuid().ToString();$payload=@{op='send';channel=$Role;session=$u.session;request_id=$id;command=$command;confirmed=$true}
 $u.lastRequest=@{id=$id;session=$u.session;command=$command;complete=$false};$u.sendPending=$true;Add-ConsoleHistory $u $command;$u.input.Clear();$u.result.Text='Enviando uma vez. ID '+$id;Queue-ConsoleCall $Role $payload
}
function Query-ConsoleOutcome([string]$Role){$u=$script:views[$Role];if($u.lastRequest){Queue-ConsoleCall $Role @{op='outcome';channel=$Role;session=$u.lastRequest.session;request_id=$u.lastRequest.id}}}
function Complete-ConsoleCall($Request,$Reply){
 $role=$Request.role;$op=$Request.payload.op;$u=$null;if($role){$u=$script:views[$role]}
 if(-not $Reply.ok){if($u){if($op -eq 'send'){$u.sendPending=$false;$u.result.Text='Falha ou resultado incerto. Consulte o ID; nao foi reenviado: '+$Reply.error}else{$u.status.Text='Leitura indisponivel: '+$Reply.error};if($op -eq 'read' -and $Request.generation -eq $u.generation){$u.readQueued=$false}}else{foreach($v in $script:views.Values){$v.status.Text='Canal local indisponivel: '+$Reply.error}};return}
 $data=$Reply.value
 switch($op){
  'info'{$script:lastInfo=$data;$script:infoAt=[DateTime]::UtcNow;foreach($c in @('server','bots')){$v=$script:views[$c];$a=$data.channels[$c];$v.status.Text=$c+' | Ativo: '+$a.active+' | PID: '+$a.pid+' | '+$(if($a.capture_fault){'FALHA DE CAPTURA: '+$a.capture_fault}else{'Historico persistente paginado'});if(-not $v.session){Queue-ConsoleCall $c @{op='sessions';channel=$c;offset=0;limit=50}}elseif($v.follow.Checked){if($a.session -and $a.session -cne $v.session){Select-ConsoleRun $c ([string]$a.session) $true}else{Load-ConsolePage $c}}}}
  'sessions'{$old=$u.session;$u.loading=$true;try{if($Request.payload.offset -eq 0){$u.sessions.Items.Clear()};foreach($entry in @($data.entries)){if(-not @($u.sessions.Items | Where-Object {$_.Session -ceq $entry.session}).Count){[void]$u.sessions.Items.Add([pscustomobject]@{Display=([string]$entry.started_at+' | PID '+$entry.pid+' | '+$entry.session);Session=[string]$entry.session})}};$u.sessionOffset=[int]$data.next_offset;$u.moreSessions.Enabled=[bool]$data.more;$pick=$old;if(-not $pick -and $script:lastInfo){$pick=[string]$script:lastInfo.channels[$role].session};$index=-1;for($i=0;$i -lt $u.sessions.Items.Count;$i++){if($u.sessions.Items[$i].Session -ceq $pick){$index=$i;break}};if($index -lt 0 -and $u.sessions.Items.Count){$index=0};$u.sessions.SelectedIndex=$index}finally{$u.loading=$false};if(-not $old -and $u.sessions.SelectedItem){$selected=[string]$u.sessions.SelectedItem.Session;Select-ConsoleRun $role $selected ($script:lastInfo -and $selected -ceq $script:lastInfo.channels[$role].session)}}
  'read'{if($Request.generation -ne $u.generation -or $Request.payload.session -cne $u.session){return};$u.readQueued=$false;$u.nextCursor=$data.cursor;$u.more=[bool]$data.more;$lines=@(foreach($row in @($data.entries)){if($row.kind -eq 'command'){Add-ConsoleHistory $u ([string]$row.text).TrimEnd()};'['+[string]$row.at+'] ['+[string]$row.kind+'] '+[regex]::Replace([string]$row.text,'\x1b\[[0-?]*[ -/]*[@-~]','').TrimEnd()});$u.box.Text=$lines -join "`r`n";$u.previous.Enabled=($u.page -gt 0);$u.next.Enabled=$u.more;if($u.follow.Checked){$u.box.SelectionStart=$u.box.TextLength;$u.box.ScrollToCaret();if($u.more){if($u.page+1 -eq $u.starts.Count){$u.starts.Add($u.nextCursor)}else{$u.starts[$u.page+1]=$u.nextCursor};$u.page++;Load-ConsolePage $role}}}
  'send'{$u.sendPending=$false;$record=$data.record;$u.lastRequest.complete=($record.phase -eq 'delivered');$u.result.Text='ID '+$u.lastRequest.id+' | '+$record.phase+' | Envio ao transporte nao comprova execucao.'}
  'outcome'{$u.lastRequest.complete=($data.phase -eq 'delivered');$u.result.Text='ID '+$u.lastRequest.id+' | '+$data.phase+' | Consulta sem reenvio.'}
 }
}
function Pump-ConsoleQueue {
 if($script:pending -or -not $script:requests.Count){return};$request=$script:requests.Dequeue()
 if($script:override){try{$reply=@{ok=$true;value=(& $script:override $request.payload)}}catch{$reply=@{ok=$false;error=$_.Exception.Message}};Complete-ConsoleCall $request $reply;return}
 $ps=[PowerShell]::Create();$ps.Runspace=$script:worker
 $work={param($client,$payload) . $client;try{return @{ok=$true;value=(Invoke-LocalConsole $payload)}}catch{return @{ok=$false;error=$_.Exception.Message}}}
 [void]$ps.AddScript($work.ToString()).AddArgument((Join-Path $PSScriptRoot 'Bridge-ConsoleClient.ps1')).AddArgument($request.payload);$script:pending=@{ps=$ps;request=$request;handle=$ps.BeginInvoke()}
}
$area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea;$width=[math]::Max(420,[int](($area.Width-30)/2));$height=[math]::Max(420,[math]::Min(760,$area.Height-70))
foreach($role in @('server','bots')){
 $form=[Windows.Forms.Form]::new();$form.Text='The Bridge - Console '+$role;$form.StartPosition='Manual';$x=$area.Left+10;if($role -eq 'bots'){$x+=$width+10};$form.SetBounds($x,($area.Top+25),$width,$height)
 $top=[Windows.Forms.Panel]::new();$top.Dock='Top';$top.Height=135;$bottom=[Windows.Forms.Panel]::new();$bottom.Dock='Bottom';$bottom.Height=115
 $status=[Windows.Forms.Label]::new();$status.SetBounds(8,3,($width-35),32);$status.Anchor='Top,Left,Right';$status.Text='Aguardando canal local; nenhum comando sera enviado automaticamente.';$top.Controls.Add($status)
 $sessions=[Windows.Forms.ComboBox]::new();$sessions.DropDownStyle='DropDownList';$sessions.DisplayMember='Display';$sessions.Tag=$role;$sessions.SetBounds(8,38,($width-230),25);$sessions.Anchor='Top,Left,Right';$top.Controls.Add($sessions)
 $refresh=[Windows.Forms.Button]::new();$refresh.Text='Execucoes';$refresh.Tag=$role;$refresh.SetBounds(($width-215),37,90,27);$refresh.Anchor='Top,Right';$top.Controls.Add($refresh)
 $moreSessions=[Windows.Forms.Button]::new();$moreSessions.Text='Mais';$moreSessions.Tag=$role;$moreSessions.SetBounds(($width-120),37,80,27);$moreSessions.Anchor='Top,Right';$moreSessions.Enabled=$false;$top.Controls.Add($moreSessions)
 $buttons=@{};$pos=8;foreach($pair in @(@('first','Inicio'),@('previous','Anterior'),@('next','Proxima'),@('reload','Recarregar'))){$b=[Windows.Forms.Button]::new();$b.Text=$pair[1];$b.Tag=@{role=$role;mode=$pair[0]};$b.SetBounds($pos,70,82,26);$top.Controls.Add($b);$buttons[$pair[0]]=$b;$pos+=86;$b.Add_Click({param($sender,$event) Navigate-ConsolePage ([string]$sender.Tag.role) ([string]$sender.Tag.mode)})}
 $follow=[Windows.Forms.CheckBox]::new();$follow.Text='Seguir';$follow.Checked=$true;$follow.SetBounds(355,72,85,22);$top.Controls.Add($follow)
 $search=[Windows.Forms.TextBox]::new();$search.SetBounds(8,103,($width-140),24);$search.Anchor='Top,Left,Right';$top.Controls.Add($search)
 $find=[Windows.Forms.Button]::new();$find.Text='Buscar pagina';$find.Tag=$role;$find.SetBounds(($width-125),102,95,26);$find.Anchor='Top,Right';$top.Controls.Add($find)
 $box=[Windows.Forms.TextBox]::new();$box.Multiline=$true;$box.ReadOnly=$true;$box.WordWrap=$false;$box.ScrollBars='Both';$box.Dock='Fill';$box.MaxLength=1048576;$box.Font=[Drawing.Font]::new('Consolas',10);$box.BackColor=[Drawing.Color]::FromArgb(20,20,20);$box.ForeColor=[Drawing.Color]::Gainsboro
 $input=[Windows.Forms.TextBox]::new();$input.Tag=$role;$input.SetBounds(8,7,($width-130),26);$input.Anchor='Top,Left,Right';$bottom.Controls.Add($input)
 $send=[Windows.Forms.Button]::new();$send.Text='Enviar';$send.Tag=$role;$send.SetBounds(($width-115),6,85,28);$send.Anchor='Top,Right';$bottom.Controls.Add($send)
 $result=[Windows.Forms.Label]::new();$result.SetBounds(8,40,($width-35),38);$result.Anchor='Top,Left,Right';$result.Text='Cada envio exige confirmacao. Nenhum shell do Windows.';$bottom.Controls.Add($result)
 $outcome=[Windows.Forms.Button]::new();$outcome.Text='Consultar ultimo resultado';$outcome.Tag=$role;$outcome.SetBounds(8,82,220,26);$bottom.Controls.Add($outcome)
 $form.Controls.Add($box);$form.Controls.Add($bottom);$form.Controls.Add($top)
 $script:views[$role]=@{form=$form;status=$status;sessions=$sessions;moreSessions=$moreSessions;sessionOffset=0;loading=$false;follow=$follow;box=$box;input=$input;send=$send;result=$result;previous=$buttons.previous;next=$buttons.next;search=$search;generation=0;session='';starts=[Collections.Generic.List[object]]::new();page=0;nextCursor=$null;more=$false;readQueued=$false;sendPending=$false;lastRequest=$null;history=[Collections.Generic.List[string]]::new();historyIndex=0;draft=''}
 $sessions.Add_SelectedIndexChanged({param($sender,$event) $u=$script:views[[string]$sender.Tag];if(-not $u.loading -and $sender.SelectedItem){Select-ConsoleRun ([string]$sender.Tag) ([string]$sender.SelectedItem.Session) $false}})
 $refresh.Add_Click({param($sender,$event) Queue-ConsoleCall ([string]$sender.Tag) @{op='sessions';channel=[string]$sender.Tag;offset=0;limit=50}})
 $moreSessions.Add_Click({param($sender,$event) $c=[string]$sender.Tag;Queue-ConsoleCall $c @{op='sessions';channel=$c;offset=$script:views[$c].sessionOffset;limit=50}})
 $send.Add_Click({param($sender,$event) Submit-ConsoleCommand ([string]$sender.Tag)})
 $outcome.Add_Click({param($sender,$event) Query-ConsoleOutcome ([string]$sender.Tag)})
 $input.Add_KeyDown({param($sender,$event) switch([string]$event.KeyCode){'Enter'{$event.SuppressKeyPress=$true;Submit-ConsoleCommand ([string]$sender.Tag)};'Up'{$event.SuppressKeyPress=$true;Move-ConsoleHistory ([string]$sender.Tag) -1};'Down'{$event.SuppressKeyPress=$true;Move-ConsoleHistory ([string]$sender.Tag) 1}}})
 $find.Add_Click({param($sender,$event) $u=$script:views[[string]$sender.Tag];$q=$u.search.Text;if($q){$start=[math]::Min($u.box.TextLength,$u.box.SelectionStart+$u.box.SelectionLength);$at=$u.box.Text.IndexOf($q,$start,[StringComparison]::OrdinalIgnoreCase);if($at -lt 0){$at=$u.box.Text.IndexOf($q,[StringComparison]::OrdinalIgnoreCase)};if($at -ge 0){$u.follow.Checked=$false;$u.box.Select($at,$q.Length);$u.box.ScrollToCaret();$u.box.Focus()}}})
 $form.Add_FormClosing({param($sender,$event) if(-not $script:closing){$event.Cancel=$true;$sender.Hide();if(@($script:views.Values | Where-Object {$_.form.Visible}).Count -eq 0){$script:closing=$true;$script:context.ExitThread()}}})
}
$timer=[Windows.Forms.Timer]::new();$timer.Interval=250
if($SelfTest){
 $script:testApproval=$false;$script:fakeCalls=0;$script:fakeUnknown=$false;$script:fakeReceipts=@{};$script:fakeSession='11111111-1111-4111-8111-111111111111';$script:oldSession='22222222-2222-4222-8222-222222222222'
 $script:override={param($p) switch($p.op){'info'{return @{channels=@{server=@{active=$true;pid=101;session=$script:fakeSession;capture_fault=$null};bots=@{active=$false;pid=$null;session=$null;capture_fault=$null}}}};'sessions'{return @{entries=$(if($p.channel -eq 'server'){@(@{session=$script:fakeSession;started_at='TEST';pid=101},@{session=$script:oldSession;started_at='ARCHIVE';pid=100})}else{@()});next_offset=50;more=$false}};'read'{if($p.session -eq $script:oldSession){return @{entries=@(@{at='TEST';kind='stdout';text='ARCHIVE'});cursor=@{segment=0;offset=1};more=$false}};if($p.cursor.offset -eq 0){return @{entries=@(@{at='TEST';kind='stdout';text='FIRST'});cursor=@{segment=0;offset=1};more=$true}};return @{entries=@(@{at='TEST';kind='stdout';text='TAIL'});cursor=@{segment=0;offset=2};more=$false}};'send'{$script:fakeCalls++;$record=@{phase=$(if($script:fakeUnknown){'outcome_unknown'}else{'delivered'})};$script:fakeReceipts[$p.request_id]=$record;if($script:fakeUnknown){throw 'Timeout simulado'};return @{record=$record}};'outcome'{return $script:fakeReceipts[$p.request_id]};default{throw 'Chamada inesperada'}}}
 function Drain-ConsoleTests {$i=0;while($script:requests.Count){if(++$i -gt 100){throw 'Fila de teste nao terminou'};Pump-ConsoleQueue}}
 $checks=[Collections.Generic.List[string]]::new();function Assert-ConsoleTest([bool]$Ok,[string]$Name){if(-not $Ok){throw ('Teste falhou: '+$Name)};$checks.Add($Name)}
 Assert-ConsoleTest ($script:views.Count -eq 2 -and $script:views.server.box.ReadOnly -and -not $script:views.server.input.ReadOnly) 'Duas janelas com saida protegida e entrada editavel'
 Queue-ConsoleCall '' @{op='info'};Drain-ConsoleTests;Assert-ConsoleTest ($script:views.server.box.Text.Contains('TAIL')) 'Seguir avanca paginas sem carregar historico inteiro'
 Navigate-ConsolePage 'server' 'previous';Drain-ConsoleTests;Assert-ConsoleTest ($script:views.server.box.Text.Contains('FIRST') -and -not $script:views.server.follow.Checked) 'Pagina anterior preserva consulta manual'
 Navigate-ConsolePage 'server' 'next';Drain-ConsoleTests;Assert-ConsoleTest ($script:views.server.box.Text.Contains('TAIL')) 'Proxima pagina usa cursor recebido'
 $script:views.server.input.Text='list';Submit-ConsoleCommand 'server';Drain-ConsoleTests;Assert-ConsoleTest ($script:fakeCalls -eq 0) 'Cancelar confirmacao nao envia'
 $script:testApproval=$true;Submit-ConsoleCommand 'server';Drain-ConsoleTests;Assert-ConsoleTest ($script:fakeCalls -eq 1 -and $script:views.server.lastRequest.complete) 'Comando confirmado enviado uma vez por transporte substituto'
 $script:views.server.input.Text='draft';Move-ConsoleHistory 'server' -1;Assert-ConsoleTest ($script:views.server.input.Text -ceq 'list') 'Seta para cima recupera comando';Move-ConsoleHistory 'server' 1;Assert-ConsoleTest ($script:views.server.input.Text -ceq 'draft') 'Seta para baixo restaura rascunho'
 $script:views.server.input.Text="list`nstop";Submit-ConsoleCommand 'server';Drain-ConsoleTests;Assert-ConsoleTest ($script:fakeCalls -eq 1) 'Multiplas linhas nao chegam ao transporte'
 Select-ConsoleRun 'server' $script:oldSession $false;Drain-ConsoleTests;$script:views.server.input.Text='list';Submit-ConsoleCommand 'server';Assert-ConsoleTest ($script:fakeCalls -eq 1 -and $script:views.server.box.Text.Contains('ARCHIVE')) 'Execucao arquivada permite leitura mas nao recebe comando'
 Select-ConsoleRun 'server' $script:fakeSession $false;Drain-ConsoleTests;$script:fakeUnknown=$true;$script:views.server.input.Text='help';Submit-ConsoleCommand 'server';Drain-ConsoleTests;$before=$script:fakeCalls;Query-ConsoleOutcome 'server';Drain-ConsoleTests;Assert-ConsoleTest ($before -eq 2 -and $script:fakeCalls -eq 2 -and $script:views.server.result.Text.Contains('outcome_unknown')) 'Resultado incerto consultado sem reenvio'
 $text=$script:views.server.box.Text;Complete-ConsoleCall @{role='server';payload=@{op='read';session=$script:fakeSession};generation=($script:views.server.generation-1)} @{ok=$true;value=@{entries=@(@{at='TEST';kind='stdout';text='STALE'});cursor=@{segment=0;offset=99};more=$false}};Assert-ConsoleTest ($script:views.server.box.Text -ceq $text) 'Resposta atrasada de outra geracao descartada'
 $timer.Dispose();foreach($u in $script:views.Values){$u.form.Dispose()};$script:context.Dispose();[pscustomobject]@{passed=$checks.Count;tests=@($checks);windows_shown=$false;network_used=$false;real_commands_sent=$false;components_started=$false} | ConvertTo-Json -Depth 5 -Compress;return
}
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeConsoleViews');$owned=$false;try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
if(-not $owned){try{$s=[Threading.EventWaitHandle]::OpenExisting('Local\TheBridgeConsoleViews-Show');[void]$s.Set();$s.Dispose()}catch{};$mutex.Dispose();$timer.Dispose();foreach($u in $script:views.Values){$u.form.Dispose()};$script:context.Dispose();return}
$signal=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\TheBridgeConsoleViews-Show');$script:worker=[runspacefactory]::CreateRunspace();$script:worker.Open()
$timer.Add_Tick({
 if($signal.WaitOne(0)){foreach($u in $script:views.Values){$u.form.Show();if($u.form.WindowState -eq 'Minimized'){$u.form.WindowState='Normal'};$u.form.BringToFront()}}
 if($script:pending -and $script:pending.handle.IsCompleted){$p=$script:pending;try{$r=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors -or $r.Count -ne 1){throw 'Resposta de operacao incompleta'};Complete-ConsoleCall $p.request $r[0]}catch{Complete-ConsoleCall $p.request @{ok=$false;error=$_.Exception.Message}}finally{$p.ps.Dispose();$script:pending=$null;$script:nextCall=[DateTime]::UtcNow.AddMilliseconds(250)}}
 if([DateTime]::UtcNow -ge $script:nextInfo -and $script:requests.Count -lt 20 -and -not @($script:requests.ToArray() | Where-Object {$_.payload.op -eq 'info'}).Count){Queue-ConsoleCall '' @{op='info'};$script:nextInfo=[DateTime]::UtcNow.AddSeconds(5)}
 if([DateTime]::UtcNow -ge $script:nextCall){Pump-ConsoleQueue}
})
try{foreach($u in $script:views.Values){$u.form.Show()};$timer.Start();[Windows.Forms.Application]::Run($script:context)}finally{$timer.Stop();$timer.Dispose();if($script:pending){try{$script:pending.ps.Stop()}catch{};$script:pending.ps.Dispose()};$script:worker.Dispose();foreach($u in $script:views.Values){$u.form.Dispose()};$script:context.Dispose();$signal.Dispose();if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}