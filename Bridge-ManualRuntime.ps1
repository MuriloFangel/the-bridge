#requires -Version 7.2
param([string]$Root='F:\srv\vibecoding')
# Load the installed authenticated client unchanged; do not reconstruct redacted source.
. (Join-Path $Root 'Bridge-NextRuntime.ps1') -Root $Root
Set-Item -Path Function:Invoke-BridgeManualBaseAction -Value ${function:Invoke-BridgeNextAction}
function Invoke-BridgeNextAction([string]$Action,[bool]$Desktop=$false){
 if($Action -eq 'StartBots'){$r=Invoke-BridgeManualBaseAction 'StartBots';return @{message='Controlador ativo e sem novas conexoes automaticas; use Adicionar ou Reconectar.';result=$r.result}}
 if($Action -ne 'StartEnv'){return Invoke-BridgeManualBaseAction $Action $Desktop}
 $errors=[Collections.Generic.List[string]]::new()
 try{$null=Invoke-BridgeNextAction 'StartBots';Write-Information 'Controlador iniciado sem conectar bots; use Adicionar.' -InformationAction Continue}catch{$errors.Add('Controlador: '+$_.Exception.Message)}
 try{$null=Invoke-BridgeManualBaseAction 'StartServer';Write-Information 'Inicio do servidor solicitado ou processo existente preservado. Nao aguardamos list.' -InformationAction Continue}catch{$errors.Add('Servidor: '+$_.Exception.Message)}
 if($Desktop){try{Invoke-BridgeNextDesktop 'Start'}catch{$errors.Add('Desktop: '+$_.Exception.Message)}}
 if($errors.Count){throw ($errors -join ' | ')}
 return @{message='Inicio solicitado sem aguardar prontidao. Bots entram somente por Adicionar/Reconectar. Porta aberta nao comprova carga completa.'}
}