# Bridge-Delivery-ID: TB-20261109T141700Z-A157BD10
# Bridge-Base-Commit: d42eff5140f8ed21565e15662fa4ac17c25f9760
#requires -Version 7.2
param([string]$ProjectRoot='F:\srv\vibecoding',[string]$RemoteDir='F:\srv\TheBridge-Remote-v2',[int]$HttpPort=18977)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$mutex=[Threading.Mutex]::new($false,'Local\TheBridgeAIStudioWatcherV2')
if(-not $mutex.WaitOne(0)){Write-Host "Watcher v2 ja ativo." -ForegroundColor Yellow;exit 0}
$Utf8=[Text.UTF8Encoding]::new($false);$StrictUtf8=[Text.UTF8Encoding]::new($false,$true)
. (Join-Path $ProjectRoot 'Bridge-ConsoleClient.ps1')

function RawHash([byte[]]$b){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($b)).ToLowerInvariant()}
function NormHash([byte[]]$b){$t=$StrictUtf8.GetString($b);if($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF){$t=$t.Substring(1)};RawHash ($Utf8.GetBytes($t.Replace("`r`n","`n").Replace("`r","`n")))}
function CallMcp([string]$Tool,[hashtable]$ArgsHash=@{}){
 $c=[IO.File]::ReadAllText((Join-Path $RemoteDir 'connection.json'))|ConvertFrom-Json
 $body=@{jsonrpc='2.0';id=[guid]::NewGuid().ToString();method='tools/call';params=@{name=$Tool;arguments=$ArgsHash}}|ConvertTo-Json -Depth 15 -Compress
 $r=Invoke-RestMethod -Uri "http://127.0.0.1:$($c.port)/mcp" -Method Post -Headers @{Authorization="Bearer $($c.key)"} -ContentType 'application/json' -Body $body -NoProxy -TimeoutSec 60
 if($r.error){throw "MCP Error: $($r.error|ConvertTo-Json -Compress)"}
 $txt=[string]$r.result.content[0].text;if($c.key){$txt=$txt.Replace([string]$c.key,'[REDACTED]')};if($r.result.isError){throw "MCP Tool Error: $txt"}
 try{return ($txt|ConvertFrom-Json)}catch{return $txt}
}
function PushLedger([string]$CommitMsg,[hashtable]$FilesMap){
 $tmp=Join-Path $env:TEMP ("bridge-ledger-"+[guid]::NewGuid().ToString('N'))
 try{
  [void](New-Item -ItemType Directory -Path $tmp -Force);$url=(git -C $ProjectRoot remote get-url origin).Trim()
  git -C $tmp init -q;git -C $tmp remote add origin $url
  git -C $tmp config user.name ((git -C $ProjectRoot config --get user.name).Trim())
  git -C $tmp config user.email ((git -C $ProjectRoot config --get user.email).Trim())
  git -C $tmp fetch origin refs/heads/ai-deliveries:refs/remotes/origin/ai-deliveries -q
  git -C $tmp checkout -b ai-deliveries refs/remotes/origin/ai-deliveries -q
  foreach($k in $FilesMap.Keys){
   $dst=Join-Path $tmp ($k -replace '/','\');if(Test-Path -LiteralPath $dst){throw "Registro imutavel ja existe: $k"}
   [void](New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force);[IO.File]::WriteAllText($dst,$FilesMap[$k],$Utf8);git -C $tmp add -- $k
  }
  git -C $tmp commit -m $CommitMsg -q;git -C $tmp push origin HEAD:refs/heads/ai-deliveries -q
  $sha=(git -C $tmp rev-parse HEAD).Trim();git -C $ProjectRoot fetch origin refs/heads/ai-deliveries:refs/remotes/origin/ai-deliveries -q;return $sha
 }finally{if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}}
}
function RunTrigger($cmd){
 $sb=[System.Text.StringBuilder]::new()
 [void]$sb.AppendLine("=== BRIDGE-RESPONSE-V1 (Req: $($cmd.request_id)) ===")
 [void]$sb.AppendLine("UTC: $([DateTimeOffset]::UtcNow.ToString('o'))")
 if($cmd.fetch_git){git -C $ProjectRoot fetch --all --prune -q 2>$null}
 [void]$sb.AppendLine("Main HEAD: $((git -C $ProjectRoot rev-parse HEAD).Trim())")
 [void]$sb.AppendLine("Ledger HEAD: $((git -C $ProjectRoot rev-parse refs/remotes/origin/ai-deliveries).Trim())`n")
 if($cmd.action -eq 'READ'){
  if($cmd.mcp_status){[void]$sb.AppendLine("--- MCP STATUS ---`n"+((CallMcp 'get_status')|ConvertTo-Json -Depth 6 -Compress))}
  if($cmd.console_info){try{[void]$sb.AppendLine("--- CONSOLE PIPE INFO ---`n"+((Invoke-LocalConsole @{op='info'})|ConvertTo-Json -Depth 6 -Compress))}catch{[void]$sb.AppendLine("Pipe Err: $($_.Exception.Message)")}}
  if($cmd.git_cmds){foreach($g in $cmd.git_cmds){[void]$sb.AppendLine("--- git $g ---`n"+((Invoke-Expression "git -C `"$ProjectRoot`" $g"|Out-String).Trim()))}}
  if($cmd.files){foreach($f in $cmd.files){
   $p=Join-Path $ProjectRoot ($f -replace '/','\');[void]$sb.AppendLine("==================================================================")
   if(Test-Path -LiteralPath $p -PathType Leaf){$b=[IO.File]::ReadAllBytes($p);[void]$sb.AppendLine("### FILE: $f | Bytes: $($b.Length) | RawSHA256: $(RawHash $b) | NormSHA256: $(NormHash $b)`n==================================================================`n"+$Utf8.GetString($b))}
   else{[void]$sb.AppendLine("### FILE: $f [MISSING]")}
  }}
 }elseif($cmd.action -eq 'DELIVERY'){
  $fList=($cmd.files|ForEach-Object{$_.path}) -join "`n - "
  if([System.Windows.Forms.MessageBox]::Show("Confirmar Entrega $($cmd.delivery_id)?`nObjetivo: $($cmd.objective)`nArquivos:`n - $fList","The Bridge - Entrega",'YesNo','Question','Button1','ServiceNotification') -ne 'Yes'){return $sb.AppendLine("STATUS: CANCELADO").ToString()}
  if($cmd.publish_ledger){
   $map=@{};if($cmd.manifest_json){$map["entregas/$($cmd.delivery_id).json"]=($cmd.manifest_json|ConvertTo-Json -Depth 20 -Compress)+"`n"}
   if($cmd.docs_json){$map["documentacao/$($cmd.delivery_id).json"]=($cmd.docs_json|ConvertTo-Json -Depth 20 -Compress)+"`n"}
   [void]$sb.AppendLine("LEDGER PUBLICADO: origin/ai-deliveries @ "+(PushLedger -CommitMsg $cmd.ledger_commit_msg -FilesMap $map))
  }
  $bakDir=Join-Path $ProjectRoot ".git\bridge-worker-backups\$($cmd.delivery_id)";[void](New-Item -ItemType Directory -Path $bakDir -Force)
  foreach($fo in $cmd.files){
   $rel=[string]$fo.path;$full=Join-Path $ProjectRoot ($rel -replace '/','\')
   $txt=if($fo.content_b64){$Utf8.GetString([Convert]::FromBase64String([string]$fo.content_b64))}else{[string]$fo.content}
   $newBytes=$Utf8.GetBytes($txt.Replace("`r`n","`n").Replace("`r","`n"));$newNorm=NormHash $newBytes
   if($fo.expected_new_norm -and $newNorm -ne $fo.expected_new_norm){throw "STOP: Hash novo ($newNorm) != declarado ($($fo.expected_new_norm)) em $rel"}
   if(Test-Path -LiteralPath $full -PathType Leaf){
    $curBytes=[IO.File]::ReadAllBytes($full);$curNorm=NormHash $curBytes
    if($fo.expected_base_norm -and $curNorm -ne $fo.expected_base_norm){throw "STOP: Base local ($curNorm) != esperada ($($fo.expected_base_norm)) em $rel"}
    [IO.File]::WriteAllBytes((Join-Path $bakDir ($rel -replace '[/\\]','__')),$curBytes)
   }
   [IO.File]::WriteAllBytes($full,$newBytes);$ver=[IO.File]::ReadAllBytes($full)
   [void]$sb.AppendLine("SALVO: $rel | NormSHA256: $(NormHash $ver) | RawSHA256: $(RawHash $ver)")
  }
 }elseif($cmd.action -eq 'MCP'){
  if([System.Windows.Forms.MessageBox]::Show("Executar MCP '$($cmd.tool)'?`nArgs: $($cmd.args|ConvertTo-Json -Compress)","The Bridge - MCP",'YesNo','Question','Button1','ServiceNotification') -ne 'Yes'){return $sb.AppendLine("STATUS: CANCELADO").ToString()}
  $ah=@{};if($cmd.args){foreach($p in $cmd.args.PSObject.Properties){$ah[$p.Name]=$p.Value}};[void]$sb.AppendLine(((CallMcp $cmd.tool $ah)|ConvertTo-Json -Depth 10))
 }elseif($cmd.action -eq 'POWERSHELL'){
  if([System.Windows.Forms.MessageBox]::Show("Executar Script PowerShell ($($cmd.description))?",'The Bridge - PowerShell','YesNo','Question','Button1','ServiceNotification') -ne 'Yes'){return $sb.AppendLine('STATUS: CANCELADO').ToString()}
  $out = (Invoke-Expression $cmd.script | Out-String).Trim()
  [void]$sb.AppendLine($out)
 }elseif($cmd.action -eq 'CONSOLE_PIPE'){
  if([System.Windows.Forms.MessageBox]::Show("Executar Console Pipe?`nPayload: $($cmd.payload|ConvertTo-Json -Compress)","The Bridge - Pipe",'YesNo','Question','Button1','ServiceNotification') -ne 'Yes'){return $sb.AppendLine("STATUS: CANCELADO").ToString()}
  $ph=@{};foreach($p in $cmd.payload.PSObject.Properties){$ph[$p.Name]=$p.Value};[void]$sb.AppendLine(((Invoke-LocalConsole $ph)|ConvertTo-Json -Depth 10))
 }
 return $sb.ToString()
}

$shared=[hashtable]::Synchronized(@{seq=0;response="";req_id=""})
$listener=[System.Net.HttpListener]::new();$listener.Prefixes.Add("http://127.0.0.1:$HttpPort/");$listener.Start()
$httpRs=[runspacefactory]::CreateRunspace();$httpRs.Open();$httpPs=[PowerShell]::Create();$httpPs.Runspace=$httpRs
[void]$httpPs.AddScript({param($l,$s,$u) while($l.IsListening){try{$c=$l.GetContext();$r=$c.Response;$r.Headers.Add("Access-Control-Allow-Origin","*");$r.ContentType="application/json; charset=utf-8";$b=$u.GetBytes((@{seq=$s.seq;req_id=$s.req_id;response=$s.response}|ConvertTo-Json -Compress));$r.ContentLength64=$b.Length;$r.OutputStream.Write($b,0,$b.Length);$r.OutputStream.Close()}catch{}}}).AddArgument($listener).AddArgument($shared).AddArgument($Utf8)
$null=$httpPs.BeginInvoke()

Write-Host "=== THE BRIDGE WATCHER v2 ATIVO (Clipboard + HTTP :$HttpPort) ===" -ForegroundColor Green
$lastId=""
try{
 while($true){
  Start-Sleep -Milliseconds 300
  $clip=Get-Clipboard -Raw -ErrorAction SilentlyContinue
  if($clip -and $clip.Contains('###<<<BRIDGE-TRIGGER-V1>>>###') -and $clip.Contains('###<<<END-BRIDGE-TRIGGER>>>###')){
   $m=[regex]::Match($clip,'(?s)###<<<BRIDGE-TRIGGER-V1>>>###\s*(\{.*?\})\s*###<<<END-BRIDGE-TRIGGER>>>###')
   if($m.Success){
    $parsed=$m.Groups[1].Value|ConvertFrom-Json
    if($parsed.request_id -and $parsed.request_id -ne $lastId){
     $lastId=$parsed.request_id;[console]::Beep(880,100)
     Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Trigger: $($parsed.request_id) ($($parsed.action))" -ForegroundColor Yellow
     try{$res=RunTrigger $parsed}catch{$res="=== BRIDGE-RESPONSE-ERROR (Req: $($parsed.request_id)) ===`nERRO: $($_.Exception.Message)";[console]::Beep(300,300)}
     Set-Clipboard -Value $res;$shared.req_id=$parsed.request_id;$shared.response=$res;$shared.seq++
     [console]::Beep(1200,150);Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Pronto! Seq=$($shared.seq) ($($res.Length) chars)" -ForegroundColor Green
    }
   }
  }
 }
}finally{$listener.Stop();$httpPs.Dispose();$httpRs.Dispose();$mutex.ReleaseMutex()}