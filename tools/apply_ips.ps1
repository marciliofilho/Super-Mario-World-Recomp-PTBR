<#
.SYNOPSIS
    Aplica um patch IPS a uma ROM SNES.

.DESCRIPTION
    O patch de tradução PT-BR do Super Mario World foi gerado contra uma ROM
    COM header de copiadora de 512 bytes (.smc). Aplicá-lo sobre a ROM
    "limpa" (.sfc) desloca tudo em 0x200 e produz uma imagem inválida
    (o header LoROM vai parar em 0x81C0 em vez de 0x7FC0).

    Este script reproduz o procedimento correto:
      1. prefixa HeaderBytes (padrão 512) de header na ROM stock
      2. aplica o IPS
      3. remove o header do resultado

.PARAMETER Ips
    Caminho do arquivo .ips

.PARAMETER Rom
    Caminho da ROM de entrada (.sfc, sem header)

.PARAMETER Out
    Caminho da ROM de saída

.PARAMETER HeaderBytes
    Bytes de header de copiadora a simular. Padrão: 512.

.PARAMETER Inspect
    Não gera saída; apenas relata os registros do IPS.

.EXAMPLE
    .\apply_ips.ps1 -Ips ..\rom\smw-ptbr.ips -Rom ..\rom\smw-usa-stock.sfc `
                    -Out ..\rom\smw-ptbr.sfc
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ips,
    [string]$Rom,
    [string]$Out,
    [int]$HeaderBytes = 512,
    [switch]$Inspect
)

$ErrorActionPreference = 'Stop'

$ipsBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Ips))
if ([System.Text.Encoding]::ASCII.GetString($ipsBytes, 0, 5) -ne 'PATCH') {
    throw "Arquivo nao comeca com 'PATCH' -- nao e um IPS."
}

# --- primeira passada: medir ---
$count = 0; $total = 0; $minOff = [int]::MaxValue; $maxEnd = 0
$i = 5
while ($i -lt $ipsBytes.Length) {
    if ([System.Text.Encoding]::ASCII.GetString($ipsBytes, $i, 3) -eq 'EOF') { break }
    # ATENCAO: o cast [int] e obrigatorio. PowerShell preserva o tipo do
    # operando esquerdo em -shl, e um [byte] deslocado 16 bits vira 0.
    $off = ([int]$ipsBytes[$i] -shl 16) -bor ([int]$ipsBytes[$i + 1] -shl 8) -bor [int]$ipsBytes[$i + 2]
    $i += 3
    $sz = ([int]$ipsBytes[$i] -shl 8) -bor [int]$ipsBytes[$i + 1]
    $i += 2
    if ($sz -eq 0) { $sz = ([int]$ipsBytes[$i] -shl 8) -bor [int]$ipsBytes[$i + 1]; $i += 3 }
    else { $i += $sz }
    $count++
    $total += $sz
    if ($off -lt $minOff) { $minOff = $off }
    if (($off + $sz) -gt $maxEnd) { $maxEnd = $off + $sz }
}

Write-Host "IPS      : $(Split-Path $Ips -Leaf)"
Write-Host "Registros: $count"
Write-Host "Bytes    : $total"
Write-Host ("Alcance  : 0x{0:X6} .. 0x{1:X6}" -f $minOff, $maxEnd)

if ($Inspect) { return }
if (-not $Rom) { throw "-Rom e obrigatorio (ou use -Inspect)." }
if (-not $Out) { throw "-Out e obrigatorio (ou use -Inspect)." }

# --- buffer final: header simulado + espaco para a ROM expandida ---
$romBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Rom))
# Buffer = arquivo COM header de copiadora. Os offsets do IPS sao relativos a
# esse arquivo, portanto sao aplicados sem somar $HeaderBytes.
$buffer = [byte[]]::new([Math]::Max($HeaderBytes + $romBytes.Length, $maxEnd))
[Array]::Copy($romBytes, 0, $buffer, $HeaderBytes, $romBytes.Length)

# --- segunda passada: aplicar ---
$i = 5
while ($i -lt $ipsBytes.Length) {
    if ([System.Text.Encoding]::ASCII.GetString($ipsBytes, $i, 3) -eq 'EOF') { break }
    $off = ([int]$ipsBytes[$i] -shl 16) -bor ([int]$ipsBytes[$i + 1] -shl 8) -bor [int]$ipsBytes[$i + 2]
    $i += 3
    $sz = ([int]$ipsBytes[$i] -shl 8) -bor [int]$ipsBytes[$i + 1]
    $i += 2

    $dst = $off
    if ($sz -eq 0) {
        $n = ([int]$ipsBytes[$i] -shl 8) -bor [int]$ipsBytes[$i + 1]
        $v = $ipsBytes[$i + 2]
        $i += 3
        for ($k = 0; $k -lt $n; $k++) { $buffer[$dst + $k] = $v }
    } else {
        [Array]::Copy($ipsBytes, $i, $buffer, $dst, $sz)
        $i += $sz
    }
}

$clean = [byte[]]::new($buffer.Length - $HeaderBytes)
[Array]::Copy($buffer, $HeaderBytes, $clean, 0, $clean.Length)
[System.IO.File]::WriteAllBytes($Out, $clean)

Write-Host ""
Write-Host "Gerado   : $Out"
Write-Host "Tamanho  : $($clean.Length) bytes (0x$($clean.Length.ToString('X')))"
