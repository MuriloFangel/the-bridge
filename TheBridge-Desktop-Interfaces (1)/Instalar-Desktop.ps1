#requires -Version 7.2
[CmdletBinding()]
param([switch]$Apply,[switch]$NoOpen)
$ErrorActionPreference='Stop'
$root='F:\srv\vibecoding';$base=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TheBridgeDesktop';$stage=$null;$phase='preflight';$owned=$false
function Get-BridgeDesktopSha256([string]$File){(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()}
function Assert-BridgeDesktopPlainPath([string]$File){if((Test-Path -LiteralPath $File) -and ((Get-Item -LiteralPath $File -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw ('Link recusado: '+$File)}}
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeDesktopInstaller')
try{
 try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true};if(-not $owned){throw 'Outro instalador aberto'}
 if([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Use a sessao interativa do Windows'}
 $pwsh=Join-Path $PSHOME 'pwsh.exe';if(-not(Test-Path -LiteralPath $pwsh)){throw 'Execute no PowerShell 7 para Windows'}
 foreach($path in @($base,(Join-Path $base 'releases'),(Join-Path $base 'staging'))){Assert-BridgeDesktopPlainPath $path}
 $sources=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sources.json'))|ConvertFrom-Json -AsHashtable
 foreach($role in $sources.Keys){$p=Join-Path $root $sources[$role].file;Assert-BridgeDesktopPlainPath $p;if((Get-BridgeDesktopSha256 $p) -cne $sources[$role].sha256){throw ('Versao de interface diferente: '+$role+'. Originais preservados.')}}
 $windows=[Environment]::GetFolderPath('Windows');$csc=Join-Path $windows 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path -LiteralPath $csc)){$csc=Join-Path $windows 'Microsoft.NET\Framework\v4.0.30319\csc.exe'};if(-not(Test-Path -LiteralPath $csc)){throw 'Compilador C# do .NET Framework nao encontrado; nenhuma dependencia sera baixada automaticamente.'}
 $manifest=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'package-hashes.json'))|ConvertFrom-Json -AsHashtable
 foreach($name in $manifest.Keys){if((Get-BridgeDesktopSha256 (Join-Path $PSScriptRoot $name)) -cne $manifest[$name]){throw ('Arquivo do pacote alterado: '+$name)}}
 Write-Host 'Desktop The Bridge: lancador WinExe sem console, icone, atalhos e nova organizacao visual.'
 Write-Host 'Sem WebView, sem regravar scripts da ponte, bots ou banco de identidades. Nenhum servidor/controlador sera parado.'
 Write-Host 'Feche somente as janelas de interface antes de aplicar, pelo X, preservando componentes.' -ForegroundColor Yellow
 if(-not $Apply){Write-Host 'Previa concluida. Use -Apply para compilar/testar/instalar.';exit 0}
 $id=[datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8);$stage=Join-Path (Join-Path $base 'staging') $id;[void][IO.Directory]::CreateDirectory($stage)
 foreach($name in $manifest.Keys){$src=Join-Path $PSScriptRoot $name;$dst=Join-Path $stage $name;if($name.EndsWith('.ico')){[IO.File]::WriteAllBytes($dst,[IO.File]::ReadAllBytes($src))}else{[IO.File]::WriteAllText($dst,[IO.File]::ReadAllText($src),[Text.UTF8Encoding]::new($false))}}
 [IO.File]::WriteAllText((Join-Path $stage 'pwsh.path'),$pwsh,[Text.UTF8Encoding]::new($false))
 $phase='powershell-syntax'
 foreach($name in @('UiHost.ps1','Style.ps1')){$tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $stage $name),[ref]$tokens,[ref]$errors);if($errors.Count){throw ($name+': '+$errors[0].Message)}}
 $phase='compile-launcher';$exe=Join-Path $stage 'TheBridge.exe'
 $build=@(& $csc /nologo /target:winexe /platform:anycpu /optimize+ /r:System.dll /r:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $stage 'TheBridge.ico')) ('/out:'+$exe) (Join-Path $stage 'Launcher.cs') 2>&1)
 [IO.File]::WriteAllText((Join-Path $stage 'compile-launcher.log'),(($build|ForEach-Object {$_.ToString()}) -join "`r`n"),[Text.UTF8Encoding]::new($false));if($LASTEXITCODE -ne 0){throw 'Compilacao do lancador falhou; consulte compile-launcher.log'}
 $phase='compile-ui-helper';Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
 $refs=@(([AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES') -split [IO.Path]::PathSeparator)+@([Windows.Forms.Form].Assembly.Location,[Drawing.Icon].Assembly.Location)+@([AppDomain]::CurrentDomain.GetAssemblies()|Where-Object {-not $_.IsDynamic -and $_.Location}|ForEach-Object {$_.Location}))|Sort-Object -Unique
 Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $stage 'BridgeDesktopUx.cs'))) -ReferencedAssemblies $refs -OutputAssembly (Join-Path $stage 'BridgeDesktopUx.dll') -ErrorAction Stop
 $phase='ui-tests-without-showing'
 $results=@()
 foreach($role in @('Environment','Bots','Console','Names')){
  $report=Join-Path $stage ('test-'+$role+'.json');$p=Start-Process -FilePath $exe -ArgumentList ('--role '+$role+' --ui-test "'+$report+'"') -Wait -PassThru
  if($p.ExitCode -ne 0 -or -not(Test-Path -LiteralPath $report)){throw ('Teste visual/teclado falhou em '+$role+'. Se Ambiente estiver aberto, feche pelo X e consulte logs em LocalAppData\TheBridgeDesktop\logs. Nenhum componente foi parado.')}
  $r=[IO.File]::ReadAllText($report)|ConvertFrom-Json -AsHashtable;if($r.network_commands_sent -or $r.window_shown){throw 'Teste de UI inesperado'};$results+=$r;Write-Host ('Teste '+$role+': '+$r.tests+' verificacoes locais, sem mostrar janela nem enviar comandos.')
 }
 $phase='install-release';$releases=Join-Path $base 'releases';[void][IO.Directory]::CreateDirectory($releases);$release=Join-Path $releases $id;[IO.Directory]::Move($stage,$release);$stage=$release;$exe=Join-Path $release 'TheBridge.exe'
 $phase='shortcuts';$backup=Join-Path $release 'shortcut-backups';[void][IO.Directory]::CreateDirectory($backup);$shell=New-Object -ComObject WScript.Shell
 $desktop=[Environment]::GetFolderPath('DesktopDirectory');$programs=[Environment]::GetFolderPath('Programs');$menu=Join-Path $programs 'The Bridge';Assert-BridgeDesktopPlainPath $menu;[void][IO.Directory]::CreateDirectory($menu)
 $links=@(@{file=(Join-Path $desktop 'The Bridge.lnk');role='Environment'},@{file=(Join-Path $menu 'The Bridge - Ambiente.lnk');role='Environment'},@{file=(Join-Path $menu 'The Bridge - Bots.lnk');role='Bots'},@{file=(Join-Path $menu 'The Bridge - Console.lnk');role='Console'},@{file=(Join-Path $menu 'The Bridge - Nomes.lnk');role='Names'})
 $counter=0
 foreach($link in $links){Assert-BridgeDesktopPlainPath $link.file;if(Test-Path -LiteralPath $link.file){[IO.File]::Copy($link.file,(Join-Path $backup ($counter.ToString()+'-'+[IO.Path]::GetFileName($link.file))),$false)};$shortcut=$shell.CreateShortcut($link.file);$shortcut.TargetPath=$exe;$shortcut.Arguments='--role '+$link.role;$shortcut.WorkingDirectory=$release;$shortcut.IconLocation=$exe+',0';$shortcut.Description='The Bridge - interface Windows sem console';$shortcut.Save();$counter++}
 # Redirect only recognizably matching existing startup shortcuts; do not add autorun if absent.
 $updatedStartup=@();$startup=[Environment]::GetFolderPath('Startup')
 foreach($link in @(Get-ChildItem -LiteralPath $startup -Filter '*.lnk' -File)){$s=$shell.CreateShortcut($link.FullName);$startupArguments=[string]$s.Arguments;if($startupArguments.IndexOf((Join-Path $root 'painel.ps1'),[StringComparison]::OrdinalIgnoreCase) -ge 0 -and [IO.Path]::GetFileName([string]$s.TargetPath) -in @('pwsh.exe','powershell.exe')){Assert-BridgeDesktopPlainPath $link.FullName;[IO.File]::Copy($link.FullName,(Join-Path $backup ('startup-'+$link.Name)),$false);$s.TargetPath=$exe;$s.Arguments='--role Environment --autostart';$s.WorkingDirectory=$release;$s.IconLocation=$exe+',0';$s.Save();$updatedStartup+=$link.FullName}}
 $summary=@{installed=$true;release=$release;tests=$results;shortcuts=$links;startup_shortcuts_updated=$updatedStartup;backend_changed=$false;java_stop_requested=$false;native_ui_rewrite=$false;uses_webview=$false;actual_windows_visual_confirmation_pending=$true}
 [IO.File]::WriteAllText((Join-Path $release 'installation-result.json'),($summary|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
 Write-Host 'INTERFACE DESKTOP INSTALADA. Abra The Bridge na Area de Trabalho ou no menu Iniciar.' -ForegroundColor Green
 Write-Host 'Os scripts antigos foram preservados. Use os atalhos novos para evitar janelas de shell.'
 Write-Host ('Release e relatorio: '+$release)
 if(-not $NoOpen){$null=Start-Process -FilePath $exe -ArgumentList '--role Environment'}
}catch{Write-Host ('INTERROMPIDO em '+$phase+': '+$_.Exception.Message) -ForegroundColor Red;if($stage){Write-Host ('Arquivos/diagnostico: '+$stage)};Write-Host 'Nenhum servidor/controlador foi parado. Nao repita sem conferir. Falha parcial de atalhos nao tem rollback automatico.';exit 1}
finally{if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}
