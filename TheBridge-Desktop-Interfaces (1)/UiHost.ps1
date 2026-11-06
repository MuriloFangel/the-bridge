#requires -Version 7.2
[CmdletBinding()]
param([ValidateSet('Environment','Bots','Console','Names')][string]$Role='Environment',[switch]$AutoStart,[switch]$UiTest,[string]$TestReport)
$ErrorActionPreference='Stop'
$assets=$PSScriptRoot;$root='F:\srv\vibecoding';$script:BridgeDesktopAssets=$assets;$script:BridgeDesktopRole=$Role;$script:BridgeDesktopUiTest=[bool]$UiTest;$script:BridgeDesktopReport=$TestReport
try{
 $map=[IO.File]::ReadAllText((Join-Path $assets 'sources.json'))|ConvertFrom-Json -AsHashtable;$spec=$map[$Role];$path=Join-Path $root $spec.file
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $spec.sha256){throw 'A interface instalada mudou. Atualize a camada visual antes de abrir; o arquivo original nao foi sobrescrito.'}
 Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing;Add-Type -Path (Join-Path $assets 'BridgeDesktopUx.dll')
 $source=[IO.File]::ReadAllText($path);$needle='[void]$form.ShowDialog()'
 if($source.Split([string[]]@($needle),[StringSplitOptions]::None).Count -ne 2){throw 'Ponto de apresentacao da janela inesperado'}
 $injection=@'
 & (Join-Path $script:BridgeDesktopAssets 'Style.ps1') -Form $form -Role $script:BridgeDesktopRole -Assets $script:BridgeDesktopAssets -HistoryRoot $(if($script:BridgeDesktopUiTest){Join-Path ([IO.Path]::GetDirectoryName($script:BridgeDesktopReport)) 'test-history'}else{Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TheBridgeDesktop\history'})
 function Open-BridgeNextWindow([string]$File){$roles=@{'Bridge-Bots.ps1'='Bots';'Bridge-Console2.ps1'='Console';'Bridge-Nomes.ps1'='Names'};if(-not $roles.ContainsKey($File)){throw 'Janela nao reconhecida'};$null=Start-Process -FilePath (Join-Path $script:BridgeDesktopAssets 'TheBridge.exe') -ArgumentList ('--role '+$roles[$File])}
 function Get-BridgeDesktopUiDescendants([Windows.Forms.Control]$parent){foreach($control in $parent.Controls){$control;Get-BridgeDesktopUiDescendants $control}}
 if($script:BridgeDesktopUiTest){
  $timer.Stop();$tests=[BridgeDesktopUx.Toolkit]::SelfTest();$sizes=@(900,1280,1920)
  foreach($width in $sizes){$form.ClientSize=[Drawing.Size]::new($width,800);$form.PerformLayout();$table.PerformLayout();foreach($p in @(Get-BridgeDesktopUiDescendants $form|Where-Object {$_ -is [Windows.Forms.FlowLayoutPanel]})){$p.PerformLayout();if($p.ClientSize.Width -gt 0){foreach($child in $p.Controls){if($child.Left -lt 0 -or $child.Right -gt $p.ClientSize.Width+2){throw ('Controle fora da largura: '+$child.Text)}}}};$tests++}
  [IO.File]::WriteAllText($script:BridgeDesktopReport,(@{role=$script:BridgeDesktopRole;tests=$tests;network_commands_sent=$false;window_shown=$false}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 }else{[void]$form.ShowDialog()}
 [BridgeDesktopUx.Toolkit]::Remove()
'@
 $source=$source.Replace($needle,$injection)
 $tokens=$null;$errors=$null;$block=[scriptblock]::Create($source)
 $parameters=@{};if($Role -eq 'Environment'){$parameters.ProjectPath=$root;$parameters.AutoStart=[bool]$AutoStart}else{$parameters.Root=$root}
 . $block @parameters
 exit 0
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
