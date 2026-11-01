#requires -Version 7.2
# Bridge-Delivery-ID: TB-20261101T060313Z-3982FC66
# Bridge-Base-Commit: 2a1c8f56708d48843d6a5908550ee0b7142e33b5
[CmdletBinding()]
param([string]$ProjectPath,[switch]$Library)
Set-StrictMode -Version Latest
function Convert-BridgeMirrorText([byte[]]$Bytes) {
    $u=[Text.UTF8Encoding]::new($false,$true)
    $s=$u.GetString($Bytes)
    if($s.Length -gt 0 -and $s[0] -eq [char]0xFEFF){$s=$s.Substring(1)}
    return $s.Replace("`r`n","`n").Replace("`r","`n")
}
function Get-BridgeMirrorHash([byte[]]$Bytes) {
    $s=Convert-BridgeMirrorText $Bytes
    $u=[Text.UTF8Encoding]::new($false,$true)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($u.GetBytes($s))).ToLowerInvariant()
}
function New-BridgeMirrorReadme {
    param([string]$Readme,[string]$Prompt,[switch]$Initialize)
    $begin='<!-- BEGIN BRIDGE WORKER PROMPT -->'
    $end='<!-- END BRIDGE WORKER PROMPT -->'
    if([string]::IsNullOrWhiteSpace($Prompt) -or -not $Prompt.EndsWith("`n")){throw 'Prompt vazio ou sem newline final; corrija a fonte.'}
    if($Prompt.Contains($begin) -or $Prompt.Contains($end)){throw 'A fonte contem marcadores reservados da reproducao.'}
    $max=0
    foreach($m in [regex]::Matches($Prompt,'`+')){$max=[Math]::Max($max,$m.Length)}
    $fence='`' * [Math]::Max(4,$max+1)
    $u=[Text.UTF8Encoding]::new($false,$true)
    $h=Get-BridgeMirrorHash ($u.GetBytes($Prompt))
    $block=$begin+"`n## Prompt completo do operário — copiar para um novo chat`n`n"+
        'Fonte canônica: [PROMPT-NOVO-CHAT.md](PROMPT-NOVO-CHAT.md). Bloco gerado localmente; altere a fonte, não esta cópia.'+"`n`n"+
        '<!-- Bridge-Prompt-Source-SHA256: '+$h+' -->'+"`n"+$fence+"text`n"+$Prompt+$fence+"`n"+$end
    $bc=[regex]::Matches($Readme,[regex]::Escape($begin)).Count
    $ec=[regex]::Matches($Readme,[regex]::Escape($end)).Count
    if($Initialize){
        if($bc -ne 0 -or $ec -ne 0){throw 'README ja possui marcadores; instalacao inicial recusada.'}
        $legacy='(?ms)^## Prompt inicial para copiar em qualquer IA\n.*?(?=^## 1\. Objetivo e método\n)'
        if([regex]::Matches($Readme,$legacy).Count -ne 1){throw 'Secao de prompt antigo inesperada; nada foi removido.'}
        $Readme=[regex]::Replace($Readme,$legacy,'')
        $title=[regex]::Match($Readme,'(?m)^# [^\n]+\n')
        if(-not $title.Success){throw 'Titulo do README ausente.'}
        $position=$title.Index+$title.Length
        return $Readme.Substring(0,$position)+"`n"+$block+"`n"+$Readme.Substring($position)
    }
    if($bc -ne 1 -or $ec -ne 1){throw 'Marcadores ausentes/duplicados no README; nao regenerei o documento inteiro.'}
    $pattern='(?ms)^'+[regex]::Escape($begin)+'\n.*?^'+[regex]::Escape($end)+'(?=\n|$)'
    $match=[regex]::Match($Readme,$pattern)
    if(-not $match.Success){throw 'Bloco gerado do README esta malformado.'}
    return $Readme.Substring(0,$match.Index)+$block+$Readme.Substring($match.Index+$match.Length)
}
if($Library){return}
try {
    $ErrorActionPreference='Stop'
    $root=(Resolve-Path -LiteralPath $ProjectPath).Path
    $p=Join-Path $root 'PROMPT-NOVO-CHAT.md'
    $r=Join-Path $root 'README.md'
    foreach($path in @($p,$r)){
        $item=Get-Item -LiteralPath $path -ErrorAction Stop
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Documentos via link/junction nao sao suportados.'}
    }
    $promptBytes=[IO.File]::ReadAllBytes($p)
    $old=[IO.File]::ReadAllBytes($r)
    $prompt=Convert-BridgeMirrorText $promptBytes
    $readme=Convert-BridgeMirrorText $old
    $next=New-BridgeMirrorReadme -Readme $readme -Prompt $prompt
    if($next -ceq $readme){exit 0}
    if((Get-BridgeMirrorHash ([IO.File]::ReadAllBytes($r))) -cne (Get-BridgeMirrorHash $old)){throw 'README mudou durante a geracao; tente novamente.'}
    if((Get-BridgeMirrorHash ([IO.File]::ReadAllBytes($p))) -cne (Get-BridgeMirrorHash $promptBytes)){throw 'Prompt mudou durante a geracao; tente novamente.'}
    $cache=Join-Path $root '.git/bridge-readme'
    [void][IO.Directory]::CreateDirectory($cache)
    $tmp=Join-Path $cache ([guid]::NewGuid().ToString('N')+'.tmp')
    try {
        [IO.File]::WriteAllText($tmp,$next,[Text.UTF8Encoding]::new($false,$true))
        [IO.File]::Replace($tmp,$r,(Join-Path $cache ([guid]::NewGuid().ToString('N')+'.bak')))
    } finally {if(Test-Path -LiteralPath $tmp){[IO.File]::Delete($tmp)}}
    Write-Output 'README: reproducao completa do prompt atualizada; nao e teste ou reload.'
} catch {Write-Output ('STOP: reproducao do prompt: '+$_.Exception.Message);exit 1}
