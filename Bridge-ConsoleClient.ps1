# Bridge-Delivery-ID: TB-20261103T152122Z-2F392312
# Bridge-Base-Commit: 366ca28c8eddc28138ccc3cea5513a67f78995a0
#requires -Version 7.2
function Get-ConsoleMac([byte[]]$Key,[string]$Text){$h=[Security.Cryptography.HMACSHA256]::new($Key);try{return [Convert]::ToHexString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}finally{$h.Dispose()}}
function New-ConsoleFrame([hashtable]$Payload,[byte[]]$Key){$nonce=[guid]::NewGuid().ToString('N');$timestamp=[datetimeoffset]::UtcNow.ToUnixTimeMilliseconds();$body=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 12 -Compress)));return @{nonce=$nonce;timestamp=$timestamp;payload=$body;signature=(Get-ConsoleMac $Key ($nonce+'|'+$timestamp+'|'+$body))}}
function Read-ConsoleFrame($Frame,[string]$Nonce,[byte[]]$Key){
 if($Frame.nonce -cne $Nonce -or [string]$Frame.signature -cnotmatch '^[0-9a-f]{64}$' -or [string]$Frame.payload -cnotmatch '^[A-Za-z0-9+/]*={0,2}$'){throw 'Resposta local nao autenticada'}
 $expected=Get-ConsoleMac $Key ($Nonce+'|response|'+[string]$Frame.payload);$difference=0;for($i=0;$i -lt 64;$i++){$difference=$difference -bor ([int][char]$expected[$i] -bxor [int][char]([string]$Frame.signature)[$i])};if($difference -ne 0){throw 'Assinatura da resposta local invalida'}
 $value=[Text.UTF8Encoding]::new($false,$true).GetString([Convert]::FromBase64String([string]$Frame.payload)) | ConvertFrom-Json -AsHashtable
 if($value.ok -ne $true){throw ([string]$value.error)};return $value.result
}
function Invoke-LocalConsole([hashtable]$Payload){
 $private='F:\srv\TheBridge-Remote-v2';$config=[IO.File]::ReadAllText((Join-Path $private 'connection.json')) | ConvertFrom-Json -AsHashtable
 if($config.project -ine 'F:\srv\vibecoding' -or [string]$config.key -cnotmatch '^[A-Za-z0-9_-]{40,}$'){throw 'Configuracao privada inesperada'}
 $endpoint=[IO.File]::ReadAllText((Join-Path $private 'console-endpoint.json')) | ConvertFrom-Json -AsHashtable
 if($endpoint.protocol -cne 'thebridge-local-console-v1' -or [string]$endpoint.pipe -cnotmatch '^TheBridgeConsole-[0-9a-f]{16}$'){throw 'Canal local ainda nao disponivel ou invalido'}
 $key=[Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$config.key));$pipe=$null;$reader=$null;$writer=$null
 try{
  $frame=New-ConsoleFrame $Payload $key;$pipe=[IO.Pipes.NamedPipeClientStream]::new('.',[string]$endpoint.pipe,[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous);$pipe.Connect(2000)
  $encoding=[Text.UTF8Encoding]::new($false,$true);$writer=[IO.StreamWriter]::new($pipe,$encoding,4096,$true);$writer.AutoFlush=$true;$reader=[IO.StreamReader]::new($pipe,$encoding,$false,4096,$true)
  $writer.WriteLine(($frame | ConvertTo-Json -Depth 5 -Compress));$clock=[Diagnostics.Stopwatch]::StartNew();$buffer=[char[]]::new(4096);$text=[Text.StringBuilder]::new()
  do{$remaining=10000-[int]$clock.ElapsedMilliseconds;if($remaining -le 0){throw 'Resposta incerta; nao reenviar automaticamente'};$read=$reader.ReadAsync($buffer,0,$buffer.Length);if(-not $read.Wait($remaining)){throw 'Resposta incerta; nao reenviar automaticamente'};$count=$read.GetAwaiter().GetResult();if($count -eq 0){throw 'Canal fechado; resultado pode ser incerto'};$chunk=[string]::new($buffer,0,$count);$end=$chunk.IndexOf([char]10);if($end -ge 0){[void]$text.Append($chunk.Substring(0,$end))}else{[void]$text.Append($chunk)};if($text.Length -gt 1048576){throw 'Resposta excedeu limite de pagina'}}while($end -lt 0)
  return Read-ConsoleFrame ($text.ToString() | ConvertFrom-Json -AsHashtable) ([string]$frame.nonce) $key
 }finally{if($reader){$reader.Dispose()};if($writer){$writer.Dispose()};if($pipe){$pipe.Dispose()};[Array]::Clear($key,0,$key.Length)}
}