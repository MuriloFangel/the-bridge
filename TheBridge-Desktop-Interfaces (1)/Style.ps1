#requires -Version 7.2
param([Windows.Forms.Form]$Form,[string]$Role,[string]$Assets,[string]$HistoryRoot)
$ErrorActionPreference='Stop'
function Get-BridgeUxDescendants([Windows.Forms.Control]$Parent){foreach($c in $Parent.Controls){$c;Get-BridgeUxDescendants $c}}
function New-BridgeUxStack {
 $p=[Windows.Forms.TableLayoutPanel]::new();$p.AutoSize=$true;$p.Dock='Fill';$p.ColumnCount=1;$p.Margin=[Windows.Forms.Padding]::new(0);[void]$p.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100));return $p
}
function Add-BridgeUxGroup($Stack,[string]$Caption,[object[]]$Controls){
 $g=[Windows.Forms.GroupBox]::new();$g.Text=$Caption;$g.AutoSize=$true;$g.Dock='Fill';$g.Padding=[Windows.Forms.Padding]::new(8,18,8,6);$g.Margin=[Windows.Forms.Padding]::new(0,0,0,6)
 $flow=[Windows.Forms.FlowLayoutPanel]::new();$flow.AutoSize=$true;$flow.Dock='Fill';$flow.WrapContents=$true;$flow.Margin=[Windows.Forms.Padding]::new(0)
 foreach($c in $Controls){if($null -ne $c){$flow.Controls.Add($c)}};$g.Controls.Add($flow)
 $row=$Stack.RowCount;$Stack.RowCount++;[void]$Stack.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize));$Stack.Controls.Add($g,0,$row)
}
function New-BridgeUxLabel([string]$Text){$l=[Windows.Forms.Label]::new();$l.AutoSize=$true;$l.Text=$Text;$l.Margin=[Windows.Forms.Padding]::new(4,8,3,2);return $l}
$all=@(Get-BridgeUxDescendants $Form);$Form.SuspendLayout();$Form.ShowInTaskbar=$true;$Form.StartPosition='CenterScreen';$Form.Font=[Drawing.Font]::new('Segoe UI',9.5);$Form.BackColor=[Drawing.Color]::FromArgb(245,247,250);$Form.AutoScroll=$true
$Form.Icon=[Drawing.Icon]::new((Join-Path $Assets 'TheBridge.ico'))
$rootTable=@($Form.Controls|Where-Object {$_ -is [Windows.Forms.TableLayoutPanel]})[0];$rootTable.Padding=[Windows.Forms.Padding]::new(12);$rootTable.AutoScroll=$true
foreach($c in $all){if($c -is [Windows.Forms.Button]){$c.AutoSize=$true;$c.Padding=[Windows.Forms.Padding]::new(6,4,6,4);$c.Margin=[Windows.Forms.Padding]::new(4);$c.FlatStyle='System'};if($c -is [Windows.Forms.RichTextBox]){$c.Font=[Drawing.Font]::new('Consolas',10)}}
$buttons=@{};foreach($b in $all|Where-Object {$_ -is [Windows.Forms.Button] -and $_.Tag}){$buttons[[string]$b.Tag]=$b}
if($Role -eq 'Environment'){
 $old=$rootTable.GetControlFromPosition(0,1);$stack=New-BridgeUxStack
 $desktopBox=@($all|Where-Object {$_ -is [Windows.Forms.CheckBox]})[0]
 Add-BridgeUxGroup $stack 'Ambiente completo' @($buttons.StartEnv,$buttons.StopEnv,$buttons.Cancel,$desktopBox)
 Add-BridgeUxGroup $stack 'Servidor Java' @($buttons.StartServer,$buttons.StopServer,$buttons.Status)
 Add-BridgeUxGroup $stack 'Controlador e ferramentas' @($buttons.StartBots,$buttons.StopBots,$buttons.Bots,$buttons.Console,$buttons.Names)
 $rootTable.Controls.Remove($old);$old.Hide();$rootTable.Controls.Add($stack,0,1);$Form.ClientSize=[Drawing.Size]::new(960,680);$Form.MinimumSize=[Drawing.Size]::new(820,580)
 $footer=$rootTable.GetControlFromPosition(0,3);$footer.Text='Fechar esta janela preserva os componentes. Iniciar controlador nao conecta bots: use Adicionar em 1 - Bots. Porta aberta nao certifica prontidao.';$footer.MaximumSize=[Drawing.Size]::new(900,0)
}elseif($Role -eq 'Bots'){
 $old=$rootTable.GetControlFromPosition(0,1);$stack=New-BridgeUxStack
 $numbers=@($all|Where-Object {$_ -is [Windows.Forms.NumericUpDown]});$id=@($numbers|Where-Object {$_.Maximum -gt 32})[0];$quantity=@($numbers|Where-Object {$_.Maximum -le 32})[0]
 $message=@($all|Where-Object {$_ -is [Windows.Forms.TextBox] -and -not $_.Multiline -and $_.MaxLength -eq 100})[0]
 $names=[Windows.Forms.Button]::new();$names.Text='Nomes persistentes';$names.AutoSize=$true;$names.Padding=[Windows.Forms.Padding]::new(6,4,6,4)
 $launcherPath=Join-Path $Assets 'TheBridge.exe';$names.Add_Click({$null=Start-Process -FilePath $launcherPath -ArgumentList '--role Names'}.GetNewClosure())
 Add-BridgeUxGroup $stack 'Controlador e conexoes manuais' @($buttons.start,$buttons.exit,(New-BridgeUxLabel 'Quantidade:'),$quantity,$buttons.add,$buttons.list,$names)
 Add-BridgeUxGroup $stack 'Bot selecionado' @((New-BridgeUxLabel 'ID:'),$id,$buttons.off,$buttons.back,$buttons.watch,$buttons.'watch all',$buttons.'watch off')
 $message.Width=340
 Add-BridgeUxGroup $stack 'Mensagem ou comando do Minecraft' @($message,$buttons.say,$buttons.all,$buttons.help)
 $sayButton=$buttons.say;$message.Add_KeyDown({param($sender,$e) if($e.KeyCode -eq 'Enter'){$e.SuppressKeyPress=$true;if($sayButton.Enabled){$sayButton.PerformClick()}}}.GetNewClosure())
 $rootTable.Controls.Remove($old);$old.Hide();$rootTable.Controls.Add($stack,0,1);$Form.ClientSize=[Drawing.Size]::new(1080,760);$Form.MinimumSize=[Drawing.Size]::new(850,650)
 $footer=$rootTable.GetControlFromPosition(0,4);$footer.Text='Adicionar conecta os menores IDs livres com nomes salvos. Fechar esta janela nao encerra o controlador. Prompt inferior: comandos do controlador; campo acima: chat/comando do bot.';$footer.MaximumSize=[Drawing.Size]::new(1000,0)
}elseif($Role -eq 'Console'){
 $Form.ClientSize=[Drawing.Size]::new(1120,760);$Form.MinimumSize=[Drawing.Size]::new(850,600)
 $send=@($all|Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Enviar'})[0];$send.Text='Enviar ao servidor'
 $entry=@($all|Where-Object {$_ -is [Windows.Forms.TextBox] -and -not $_.Multiline})[0];$entry.Width=540
}elseif($Role -eq 'Names'){$Form.ClientSize=[Drawing.Size]::new(850,500);$Form.MinimumSize=[Drawing.Size]::new(730,440)}
[BridgeDesktopUx.Toolkit]::Initialize($Role,$HistoryRoot)
$index=0;foreach($c in @(Get-BridgeUxDescendants $Form)){if($c -is [Windows.Forms.TextBoxBase]){[BridgeDesktopUx.Toolkit]::Attach($c,($Role+'-'+$c.MaxLength+'-'+$index));$index++}}
$Form.ResumeLayout($true);$Form.PerformLayout();$rootTable.PerformLayout()
