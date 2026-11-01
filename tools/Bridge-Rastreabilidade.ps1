#requires -Version 7.2
# Bridge-Delivery-ID: TB-20261101T051722Z-E97261CF
# Bridge-Base-Commit: c8c885abe4700d57c6dbd846699eb59b6f078840
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectPath,[ValidateSet('BeforeCommit','AfterPush')][string]$Mode='BeforeCommit')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $ProjectPath).Path
$Git=(Get-Command git -ErrorAction Stop).Source
$Utf8=[Text.UTF8Encoding]::new($false)
$StrictUtf8=[Text.UTF8Encoding]::new($false,$true)
$Cache=Join-Path $Root '.git/bridge-trace'
[void](New-Item -ItemType Directory -Force -Path $Cache)
function G {
 param([string[]]$A,[int[]]$Ok=@(0))
 $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=$Git;$si.WorkingDirectory=$Root
 $si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
 foreach($x in (@('-C',$Root,'-c','core.quotepath=false')+$A)){[void]$si.ArgumentList.Add($x)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$si;$mem=[IO.MemoryStream]::new()
 try{
  [void]$p.Start();$copy=$p.StandardOutput.BaseStream.CopyToAsync($mem);$err=$p.StandardError.ReadToEndAsync()
  if(-not $p.WaitForExit(120000)){$p.Kill($true);throw "Git excedeu prazo: $($A -join ' ')"}
  $null=$copy.GetAwaiter().GetResult();$e=$err.GetAwaiter().GetResult()
  if($p.ExitCode -notin $Ok){throw "Git falhou ($($p.ExitCode)): $($A -join ' ') $e"}
  $bytes=$mem.ToArray()
  [pscustomobject]@{Code=$p.ExitCode;Bytes=$bytes;Text=$Utf8.GetString($bytes).TrimEnd([char[]]"`r`n")}
 }finally{$mem.Dispose();$p.Dispose()}
}
function Raw-Hash([AllowEmptyCollection()][byte[]]$Bytes){return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Canonical-Hash([AllowEmptyCollection()][byte[]]$Bytes){
 try{
  $t=$StrictUtf8.GetString($Bytes)
  if($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF){$t=$t.Substring(1)}
  $t=$t.Replace("`r`n","`n").Replace("`r","`n")
  return Raw-Hash ($Utf8.GetBytes($t))
 }catch [Text.DecoderFallbackException]{return $null}
}
function Write-Json([string]$Path,$Value){
 $parent=Split-Path $Path;[void](New-Item -ItemType Directory -Path $parent -Force)
 $json=$Value|ConvertTo-Json -Depth 30
 $tmp=$Path+'.tmp-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($tmp,$json+"`n",$Utf8)
 Move-Item -LiteralPath $tmp -Destination $Path -Force
}
function Validate-Manifest($m,[string]$Origin){
 foreach($key in @('schema_version','delivery_id','status','created_at','base_commit','objective','hash_algorithm','files')){
  if(-not $m.PSObject.Properties[$key]){throw "Manifesto sem $key em $Origin"}
 }
 if($m.schema_version -ne 1 -or $m.status -ne 'GERADA' -or $m.hash_algorithm -ne 'utf8-lf-no-bom-v1'){throw "Esquema/status/algoritmo invalido em $Origin"}
 if($m.delivery_id -cnotmatch '^TB-\d{8}T\d{6}Z-[0-9A-F]{8}$' -or $m.base_commit -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$'){throw "ID/SHA invalido em $Origin"}
 $null=[DateTimeOffset]::Parse([string]$m.created_at)
 if(@($m.files).Count -lt 1 -or @($m.files).Count -gt 128){throw "Quantidade de arquivos invalida em $Origin"}
 $seen=@{}
 foreach($f in $m.files){
  if(-not $f.PSObject.Properties['path'] -or -not $f.PSObject.Properties['sha256_normalized_utf8_lf']){throw "Arquivo incompleto em $Origin"}
  $path=[string]$f.path
  if([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith('/') -or $path.Contains('\') -or $path.Contains(':') -or ($path -split '/') -contains '..' -or ($path -split '/') -contains '.' -or ($path -split '/') -contains '.git'){throw "Caminho invalido em $Origin"}
  if($f.sha256_normalized_utf8_lf -notmatch '^[0-9a-fA-F]{64}$' -or $seen.ContainsKey($path)){throw "Hash/caminho duplicado invalido em $Origin"}
  $seen[$path]=$true
 }
}
try{
 if((G -A @('branch','--show-current')).Text -ne 'main'){throw 'Verificador exige main; nao trocou branch.'}
 $statePath=Join-Path $Cache 'snapshot.json'
 if($Mode -eq 'AfterPush'){
  $sha=(G -A @('rev-parse','HEAD')).Text
  $state=$null;if(Test-Path -LiteralPath $statePath){$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}
  $eventPath=$null;if($null -ne $state){$eventPath=$state.event_path}
  Write-Json (Join-Path $Cache 'ultimo-envio.json') ([ordered]@{schema_version=1;commit_sha=$sha;observation_path=$eventPath;pushed_at=[DateTimeOffset]::UtcNow.ToString('o');meaning='Recibo local de push; nao e teste ou reload.'})
  Write-Output "Rastreio: recibo local associado a $($sha.Substring(0,12))."
  exit 0
 }
 $ref='refs/remotes/origin/ai-deliveries'
 $attempt=Join-Path $Cache 'ultimo-fetch.txt';$fetchFailed=$false
 if(-not(Test-Path -LiteralPath $attempt) -or ([datetime]::UtcNow-(Get-Item -LiteralPath $attempt).LastWriteTimeUtc).TotalSeconds -ge 60){
  try{$null=G -A @('fetch','origin','refs/heads/ai-deliveries:refs/remotes/origin/ai-deliveries')}
  catch{$fetchFailed=$true;Write-Output 'Rastreio: nao foi possivel atualizar ledger; consulte o campo de disponibilidade, nao presuma consulta ao vivo.'}
  [IO.File]::WriteAllText($attempt,[DateTimeOffset]::UtcNow.ToString('o'),$Utf8)
 }
 $ledgerResult=G -A @('rev-parse','--verify',$ref) -Ok @(0,128)
 $ledgerSha=if($ledgerResult.Code -eq 0){$ledgerResult.Text}else{'AUSENTE'}
 $index=(G -A @('ls-files','--stage','-z')).Text.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)
 $entries=@();$allPaths=@{}
 foreach($line in $index){
  if($line -notmatch '^(\d{6}) ([0-9a-f]{40,64}) (\d)\t(.+)$'){throw 'Formato de indice nao reconhecido.'}
  $modeValue=$Matches[1];$blob=$Matches[2];$stage=$Matches[3];$path=$Matches[4]
  if($stage -ne '0'){throw 'Indice com conflito. Nao declarei correspondencia.'}
  $allPaths[$path]=$blob
  if(-not $path.StartsWith('RASTREABILIDADE/observacoes/')){$entries+=,[pscustomobject]@{path=$path;blob=$blob;mode=$modeValue}}
 }
 $identity=($entries|Sort-Object path|ForEach-Object{"$($_.mode) $($_.blob) $($_.path)"}) -join "`n"
 $snapshotKey=Raw-Hash ($Utf8.GetBytes($identity+"`nledger="+$ledgerSha))
 if(Test-Path -LiteralPath $statePath){
  $old=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
  if($old.snapshot_key -eq $snapshotKey -and $allPaths.ContainsKey([string]$old.event_path)){
   $existing=G -A @('show',(':'+[string]$old.event_path))
   if((Raw-Hash $existing.Bytes) -ne $old.event_raw_sha256){throw 'Ultima observacao foi alterada; revise em vez de sobrescrever o historico.'}
   exit 0
  }
 }
 $manifests=@{};$origins=@{}
 $localManifestPaths=@($entries|Where-Object{$_.path -match '^RASTREABILIDADE/recebidas/[^/]+\.json$'}|ForEach-Object{$_.path})
 $sources=@()
 if($ledgerSha -ne 'AUSENTE'){
  $remoteNames=(G -A @('ls-tree','-r','--name-only',$ref,'--','entregas/')).Text
  foreach($name in ($remoteNames -split "`n")){
   if($name -match '^entregas/[^/]+\.json$'){$sources+=,[pscustomobject]@{spec=($ref+':'+$name);origin=('ai-deliveries/'+$name);filename=$name}}
  }
 }
 foreach($name in $localManifestPaths){$sources+=,[pscustomobject]@{spec=(':'+$name);origin=$name;filename=$name}}
 foreach($source in $sources){
  $data=G -A @('show',$source.spec)
  if($data.Bytes.Length -gt 1048576){throw "Manifesto maior que 1MiB: $($source.origin)"}
  $m=$data.Text.TrimStart([char]0xFEFF)|ConvertFrom-Json -Depth 40;Validate-Manifest $m $source.origin
  if([IO.Path]::GetFileNameWithoutExtension($source.filename) -cne $m.delivery_id){throw "ID nao corresponde ao nome: $($source.origin)"}
  if($manifests.ContainsKey($m.delivery_id)){
   if(($manifests[$m.delivery_id]|ConvertTo-Json -Depth 40 -Compress) -cne ($m|ConvertTo-Json -Depth 40 -Compress)){throw "Manifestos conflitantes com ID $($m.delivery_id)."}
   $origins[$m.delivery_id]+=@($source.origin)
  }else{$manifests[$m.delivery_id]=$m;$origins[$m.delivery_id]=@($source.origin)}
 }
 $fileMap=@{};$fileResults=@()
 foreach($entry in $entries){
  $data=G -A @('show',(':'+$entry.path))
  $canonical=Canonical-Hash $data.Bytes
  $headerId=$null
  try{
   $text=$StrictUtf8.GetString($data.Bytes);$begin=($text -split "`n"|Select-Object -First 25) -join "`n"
   if($begin -match '(?m)^(?:#|//|;|<!--)[ \t]*Bridge-Delivery-ID:[ \t]*(TB-\d{8}T\d{6}Z-[0-9A-F]{8})(?:[ \t]*-->)?[ \t]*\r?$'){$headerId=$Matches[1]}
  }catch [Text.DecoderFallbackException]{}
  $f=[pscustomobject][ordered]@{path=$entry.path;git_blob=$entry.blob;sha256_raw=(Raw-Hash $data.Bytes);sha256_normalized_utf8_lf=$canonical;header_delivery_id=$headerId;matching_manifest_ids=@()}
  $fileMap[$entry.path]=$f;$fileResults+=,$f
 }
 $deliveryResults=@()
 foreach($id in ($manifests.Keys|Sort-Object)){
  $m=$manifests[$id];$ok=0;$tagged=$false;$details=@()
  foreach($expected in @($m.files)){
   $found=$fileMap.ContainsKey([string]$expected.path);$matchesHash=$false
   if($found){
    $actual=$fileMap[[string]$expected.path]
    $matchesHash=$null -ne $actual.sha256_normalized_utf8_lf -and $actual.sha256_normalized_utf8_lf -eq $expected.sha256_normalized_utf8_lf
    if($actual.header_delivery_id -eq $id){$tagged=$true}
    if($matchesHash){$ok++;$actual.matching_manifest_ids+=@($id)}
   }
   $details+=,[ordered]@{path=$expected.path;present=$found;hash_matches=$matchesHash}
  }
  $status=if($ok -eq @($m.files).Count){'CORRESPONDENCIA_INTEGRAL'}elseif($tagged){'ID_COM_CONTEUDO_DIVERGENTE'}elseif($ok -gt 0){'CORRESPONDENCIA_PARCIAL'}else{'SEM_CORRESPONDENCIA'}
  $deliveryResults+=,[ordered]@{delivery_id=$id;status=$status;matched_files=$ok;expected_files=@($m.files).Count;record_origins=$origins[$id];base_commit_claimed=$m.base_commit;files=$details}
 }
 $occurrence=[DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
 $event='RASTREABILIDADE/observacoes/'+$snapshotKey+'-'+$occurrence+'.json'
 $body=[ordered]@{schema_version=1;observed_at=[DateTimeOffset]::UtcNow.ToString('o');base_commit_at_observation=(G -A @('rev-parse','HEAD')).Text;meaning='Observacao do indice, nao teste, instalacao ou aprovacao.';hash_algorithm='utf8-lf-no-bom-v1';snapshot_key=$snapshotKey;ledger_commit=$ledgerSha;ledger_fetch_failed_this_run=$fetchFailed;deliveries=@($deliveryResults);files=@($fileResults)}
 $destination=Join-Path $Root $event
 if(Test-Path -LiteralPath $destination){throw "Observacao ja existe fora do cache esperado: $event. Revise antes de reutilizar."}
 Write-Json $destination $body
 $null=G -A @('add','--',$event)
 $eventBytes=(G -A @('show',(':'+$event))).Bytes
 Write-Json $statePath ([ordered]@{snapshot_key=$snapshotKey;event_path=$event;event_raw_sha256=(Raw-Hash $eventBytes)})
 $full=@($deliveryResults|Where-Object{$_.status -eq 'CORRESPONDENCIA_INTEGRAL'}).Count
 $partial=@($deliveryResults|Where-Object{$_.status -in @('CORRESPONDENCIA_PARCIAL','ID_COM_CONTEUDO_DIVERGENTE')}).Count
 Write-Output "Rastreio: observacao criada; correspondencias integrais=$full; parciais/divergentes=$partial. Nao e teste."
}catch{
 Write-Output "STOP: Rastreabilidade: $($_.Exception.Message)"
 exit 1
}
