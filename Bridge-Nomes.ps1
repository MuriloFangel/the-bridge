#requires -Version 7.2
param([switch]$SelfTest,[string]$Root='F:\srv\vibecoding')
$ErrorActionPreference='Stop';Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
$form=[Windows.Forms.Form]::new();$form.Text='Bots - Nomes persistentes';$form.ClientSize=[Drawing.Size]::new(740,440);$form.MinimumSize=[Drawing.Size]::new(650,400)
$table=[Windows.Forms.TableLayoutPanel]::new();$table.Dock='Fill';$table.RowCount=3;$table.ColumnCount=1;$table.Padding=[Windows.Forms.Padding]::new(8)
[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize));[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Percent,100));[void]$table.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize));[void]$table.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
$bar=[Windows.Forms.FlowLayoutPanel]::new();$bar.Dock='Fill';$bar.AutoSize=$true;$bar.WrapContents=$true
$id=[Windows.Forms.NumericUpDown]::new();$id.Minimum=1;$id.Maximum=32;$id.Width=60
$reload=[Windows.Forms.Button]::new();$reload.Text='Consultar nomes';$reload.AutoSize=$true
$rename=[Windows.Forms.Button]::new();$rename.Text='Atualizar nome do ID';$rename.AutoSize=$true
$all=[Windows.Forms.Button]::new();$all.Text='Atualizar todos (desconectados)';$all.AutoSize=$true
foreach($c in @($id,$reload,$rename,$all)){$bar.Controls.Add($c)}
$text=[Windows.Forms.TextBox]::new();$text.Multiline=$true;$text.ReadOnly=$true;$text.ScrollBars='Both';$text.Dock='Fill'
$note=[Windows.Forms.Label]::new();$note.AutoSize=$true;$note.MaximumSize=[Drawing.Size]::new(600,0);$note.Text='Desconectar nao apaga a identidade. Adicionar usa o menor numero livre com o mesmo nome. Atualizar exige os IDs desconectados. Trocar nome muda o UUID offline e pode mudar o perfil/dados vistos pelo servidor.'
$table.Controls.Add($bar,0,0);$table.Controls.Add($text,0,1);$table.Controls.Add($note,0,2);$form.Controls.Add($table)
if($SelfTest){$form.PerformLayout();$table.PerformLayout();$bar.PerformLayout();foreach($b in $bar.Controls){if($b.Right -gt $bar.ClientSize.Width){throw 'Botao fora da largura'}};$form.Dispose();@{name_ui_tests=1;network_used=$false}|ConvertTo-Json -Compress;return}
$script:pending=$null
function Read-IdentityView {
 $file='F:\srv\The-Bridge-Bots-Locais\identidades-bots.jsonl'
 if(-not(Test-Path -LiteralPath $file)){$text.Text='Sem banco de nomes ainda. Inicie o controlador.';return}
 $bank=@{};foreach($line in [IO.File]::ReadAllLines($file)){if(-not $line){continue};$row=$line|ConvertFrom-Json;$bank[[int]$row.id]=[string]$row.name};$text.Text=(($bank.Keys|Sort-Object|ForEach-Object {'ID '+$_+'  '+$bank[$_]}) -join "`r`n")
}
function Start-IdentityRefresh([string]$Target){
 if($script:pending){return};$rs=[runspacefactory]::CreateRunspace();$rs.Open();$ps=[PowerShell]::Create();$ps.Runspace=$rs
 $work={param($root,$target) try{. (Join-Path $root 'Bridge-ConsoleClient.ps1');$i=Invoke-LocalConsole @{op='info'};if(-not $i.channels.bots.active){throw 'Controlador parado'};$r=Invoke-LocalConsole @{op='send';channel='bots';session=$i.channels.bots.session;request_id=[guid]::NewGuid().ToString();command=('refresh '+$target);confirmed=$true};Start-Sleep -Milliseconds 400;return @{ok=$true;phase=$r.record.phase}}catch{return @{ok=$false;error=$_.Exception.Message}}}
 [void]$ps.AddScript($work.ToString()).AddArgument($Root).AddArgument($Target);$script:pending=@{ps=$ps;rs=$rs;handle=$ps.BeginInvoke()}
}
$reload.Add_Click({try{Read-IdentityView}catch{$text.Text=$_.Exception.Message}})
$rename.Add_Click({try{Start-IdentityRefresh ([string][int]$id.Value)}catch{$text.AppendText("`r`n"+$_.Exception.Message)}})
$all.Add_Click({try{Start-IdentityRefresh 'all'}catch{$text.AppendText("`r`n"+$_.Exception.Message)}})
$timer=[Windows.Forms.Timer]::new();$timer.Interval=250;$timer.Add_Tick({$rename.Enabled=($null -eq $script:pending);$all.Enabled=$rename.Enabled;if($script:pending -and $script:pending.handle.IsCompleted){$p=$script:pending;try{$rows=@($p.ps.EndInvoke($p.handle));if($p.ps.HadErrors -or $rows.Count -ne 1){throw 'Resposta incompleta; nao reenvie automaticamente'};$r=$rows[0];Read-IdentityView;if($r.ok){$text.AppendText("`r`nPedido enviado. Se o nome nao mudou, veja o motivo em 1-Bots: IDs conectados sao bloqueados.")}else{$text.AppendText("`r`n"+$r.error)}}catch{$text.AppendText("`r`n"+$_.Exception.Message)}finally{$p.ps.Dispose();$p.rs.Dispose();$script:pending=$null}}})
$form.Add_Shown({try{Read-IdentityView}catch{$text.Text=$_.Exception.Message}});$form.Add_FormClosing({param($s,$e) if($script:pending){$e.Cancel=$true}})
try{$timer.Start();[void]$form.ShowDialog()}finally{$timer.Dispose();$form.Dispose()}