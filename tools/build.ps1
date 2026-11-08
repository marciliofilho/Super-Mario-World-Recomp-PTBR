<#
.SYNOPSIS
    Pipeline completo: ROM traduzida -> C gerado -> executavel nativo.

.DESCRIPTION
    Encapsula as decisoes que descobrimos na pratica e que nao estao obvias
    no repositorio upstream:

      1. regen.sh precisa de PYTHON apontando para o Python real (em Git Bash
         o `python` do PATH cai no stub da Microsoft Store) e de
         ~/.cargo/bin no PATH (o analisador Python foi aposentado; so existe
         o nativo em Rust).
      2. recomp/disassembly-layout.json declara o SHA-256 da ROM. Precisa
         bater com a ROM fornecida, senao a geracao para em
         "disassembly layout ROM identity mismatch".
      3. SMW_BUNDLE_FALCON_CACHE_HELPER=ON (padrao) faz o CMake falhar no
         configure exigindo PIL + PyInstaller. Nao precisamos do helper do
         Falcon, entao desligamos.

.PARAMETER SkipRegen
    Reaproveita src/gen/ existente e vai direto para o build.

.PARAMETER Clean
    Remove build/ antes de configurar.

.PARAMETER Version
    Versao gravada no executavel (host_report). Padrao: 0.15.6-ptbr

.PARAMETER Rom
    ROM traduzida de entrada. Padrao: <projeto>\rom\smw-ptbr.sfc

.EXAMPLE
    .\tools\build.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipRegen,
    [switch]$Clean,
    [string]$Version = '0.15.6-ptbr',
    [string]$Rom
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Proj = Split-Path -Parent $PSScriptRoot
# Duas organizacoes sao aceitas:
#   1. o script vive no proprio repo do port  -> $Proj e o repo;
#   2. o script vive num diretorio de projeto -> o clone fica em
#      $Proj\SuperMarioWorldRecomp.
if (Test-Path (Join-Path $Proj 'CMakeLists.txt')) {
    $Repo = $Proj
} else {
    $Repo = Join-Path $Proj 'SuperMarioWorldRecomp'
}
if (-not $Rom) { $Rom = Join-Path $Proj 'rom\smw-ptbr.sfc' }

if (-not (Test-Path $Repo)) { throw "Repositorio nao encontrado: $Repo" }
if (-not (Test-Path $Rom)) {
    throw "ROM traduzida nao encontrada: $Rom`nRode tools\apply_ips.ps1 primeiro."
}

# --- caminho ASCII para o MSVC ---------------------------------------------
# O MSVC grava o caminho do PCH na pagina de codigo ANSI mas compila como
# UTF-8. Qualquer acento no caminho ("Projeto Padrao" tem um) gera
#   warning C4828 + error MSB8084 "Cannot transcode invalid UTF-8 JSON"
# e o build para. Compilar por uma junction ASCII resolve sem mover nada.
$AsciiProj = $Proj
if ($Proj -match '[^\x20-\x7E]') {
    $AsciiProj = 'C:\smw-ptbr'
    if (-not (Test-Path $AsciiProj)) {
        cmd /c mklink /J "$AsciiProj" "$Proj" | Out-Null
    }
    Write-Host "caminho com acento; compilando via junction $AsciiProj"
}
if ($Repo -eq $Proj) {
    $AsciiRepo = $AsciiProj
} else {
    $AsciiRepo = Join-Path $AsciiProj 'SuperMarioWorldRecomp'
}

# --- ferramentas ------------------------------------------------------------
$Py = 'C:\Users\Usuario\AppData\Local\Programs\Python\Python312\python.exe'
if (-not (Test-Path $Py)) { $Py = (Get-Command python.exe -ErrorAction Stop).Source }

$CargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (-not (Test-Path (Join-Path $CargoBin 'cargo.exe'))) {
    throw "cargo nao encontrado em $CargoBin (instale Rust: winget install Rustlang.Rustup)"
}

# Descoberta tolerante ao layout da instalacao: o VS pode estar em
# "Program Files" ou "Program Files (x86)" e o nivel de pastas depois de
# 2022\<edicao> varia entre versoes/atualizacoes. Preferimos o vswhere,
# que e a fonte oficial, e so depois caimos para glob e PATH.
function Find-CMake {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installs = & $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.CMake.Project -property installationPath 2>$null
        foreach ($install in @($installs)) {
            if (-not $install) { continue }
            $candidate = Join-Path $install 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
            if (Test-Path $candidate) { return $candidate }
        }
        # Componente CMake presente mas sem o VC.CMake.Project: aceita assim mesmo.
        $installs = & $vswhere -all -products * -property installationPath 2>$null
        foreach ($install in @($installs)) {
            if (-not $install) { continue }
            $candidate = Join-Path $install 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
            if (Test-Path $candidate) { return $candidate }
        }
    }

    foreach ($root in @(
        'C:\Program Files\Microsoft Visual Studio',
        'C:\Program Files (x86)\Microsoft Visual Studio'
    )) {
        if (-not (Test-Path $root)) { continue }
        $found = Get-ChildItem -Path $root -Recurse -Filter cmake.exe -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -match '\\CMake\\bin\\cmake\.exe$' } |
                 Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    $onPath = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    return $null
}

$CMake = Find-CMake
if (-not $CMake) { throw "cmake nao encontrado (instale VS 2022 Build Tools com VC.CMake.Project)" }

$Bash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path $Bash)) { throw "Git Bash nao encontrado em $Bash" }

Write-Host "python : $Py"
Write-Host "cmake  : $CMake"
Write-Host "cargo  : $CargoBin"
Write-Host ""

# --- 1. ROM no lugar esperado pelo regen.sh --------------------------------
$Target = Join-Path $Repo 'smw.sfc'
$srcHash = (Get-FileHash $Rom -Algorithm SHA256).Hash
if (-not (Test-Path $Target) -or (Get-FileHash $Target -Algorithm SHA256).Hash -ne $srcHash) {
    Copy-Item $Rom $Target -Force
    Write-Host "ROM copiada para smw.sfc (sha256 $($srcHash.Substring(0,16))...)"
}

# --- 2. declarar a identidade da ROM no layout de disassembly --------------
$Layout = Join-Path $Repo 'recomp\disassembly-layout.json'
if (-not (Test-Path "$Layout.orig")) { Copy-Item $Layout "$Layout.orig" }
$sha = $srcHash.ToLower()
$txt = [System.IO.File]::ReadAllText($Layout)
$declared = [regex]::Match($txt, '"rom_sha256"\s*:\s*"([0-9a-fA-F]{64})"').Groups[1].Value
if ($declared -ne $sha) {
    $txt = [regex]::Replace($txt, '"rom_sha256"\s*:\s*"[0-9a-fA-F]{64}"', "`"rom_sha256`": `"$sha`"", 'None')
    [System.IO.File]::WriteAllText($Layout, $txt)
    Write-Host "rom_sha256 do layout atualizado para a ROM traduzida"
}

# --- 3. gerar o C ----------------------------------------------------------
if (-not $SkipRegen) {
    Write-Host ""
    Write-Host "=== regen ===" -ForegroundColor Cyan
    $env:PATH = "$CargoBin;" + $env:PATH
    # Converte C:\... para /c/... (formato que o bash do Git entende)
    $bashPy = ($Py -replace '\\', '/')
    if ($bashPy -match '^([A-Za-z]):') {
        $bashPy = '/' + $Matches[1].ToLower() + $bashPy.Substring(2)
    }
    $env:PYTHON = $bashPy

    # Caminho com acento nao sobrevive a interpolacao do PowerShell no -c do
    # bash quando ele vem de $env: (o Windows converte para a code page ANSI e
    # o bash recebe bytes invalidos -> "cd: too many arguments"). Como o build
    # ja usa a junction ASCII, o regen tambem roda por ela.
    $bashRepo = $AsciiRepo.Replace('\', '/')
    if ($bashRepo -match '^([A-Za-z]):') {
        $bashRepo = '/' + $Matches[1].ToLower() + $bashRepo.Substring(2)
    }
    $env:SMW_REPO = $bashRepo
    & $Bash -c 'cd "$SMW_REPO" && ./tools/regen.sh --stock --no-tests'
    if ($LASTEXITCODE -ne 0) { throw "regen.sh falhou (exit $LASTEXITCODE)" }
}

$gen = Join-Path $Repo 'src\gen'
$genCount = (Get-ChildItem $gen -Filter *.c -ErrorAction SilentlyContinue | Measure-Object).Count
if ($genCount -eq 0) { throw "src\gen\ esta vazio -- a geracao nao produziu C" }

# --- 4. configure + build -------------------------------------------------
$Build = Join-Path $AsciiRepo 'build'
if ($Clean -and (Test-Path $Build)) {
    Remove-Item $Build -Recurse -Force
}

# O configure roda sempre: e idempotente e garante que opcoes e a versao
# gravada no executavel nao fiquem presas a um cache antigo de outra release.
Write-Host ""
Write-Host "=== configure ===" -ForegroundColor Cyan
& $CMake -S $AsciiRepo -B $Build -G 'Visual Studio 17 2022' -A x64 `
    "-DPython3_EXECUTABLE=$($Py.Replace('\','/'))" `
    -DSMW_BUNDLE_FALCON_CACHE_HELPER=OFF `
    "-DSNESRECOMP_BUILD_VERSION=$Version"
if ($LASTEXITCODE -ne 0) { throw "configure falhou (exit $LASTEXITCODE)" }

Write-Host ""
Write-Host "=== build ===" -ForegroundColor Cyan
& $CMake --build $Build --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw "build falhou (exit $LASTEXITCODE)" }

$exe = Get-ChildItem (Join-Path $Build 'Release') -Filter '*.exe' -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like 'SuperMarioWorld*' } | Select-Object -First 1
Write-Host ""
if ($exe) {
    Write-Host "Executavel: $($exe.FullName)" -ForegroundColor Green
    # O runtime procura smw.sfc a partir do diretorio do executavel.
    $stage = Join-Path $exe.DirectoryName 'smw.sfc'
    if (-not (Test-Path $stage)) {
        Copy-Item $Rom $stage -Force
        Write-Host "ROM copiada para o lado do executavel"
    }
} else {
    Write-Host "Build concluido, mas o .exe nao foi encontrado em build\Release." -ForegroundColor Yellow
}
