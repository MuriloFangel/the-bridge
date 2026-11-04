#requires -Version 7.2
[CmdletBinding()]
param([switch]$SelfTest,[string]$InspectionReceipt='')
$pwsh=Join-Path $PSHOME 'pwsh.exe'
if($SelfTest){& $pwsh -NoProfile -NonInteractive -STA -File (Join-Path $PSScriptRoot 'Bridge-Console2.ps1') -SelfTest;exit $LASTEXITCODE}
foreach($name in @('Bridge-Console2.ps1','Bridge-Bots.ps1')){$null=Start-Process -FilePath $pwsh -ArgumentList ('-NoLogo -NoProfile -STA -File "'+(Join-Path $PSScriptRoot $name)+'"') -WorkingDirectory $PSScriptRoot}