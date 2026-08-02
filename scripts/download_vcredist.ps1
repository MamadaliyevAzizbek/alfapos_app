# Microsoft Visual C++ 2015–2022 Redistributable (x64) — Inno Setup uchun
# Manba: https://aka.ms/vs/17/release/vc_redist.x64.exe

$ErrorActionPreference = 'Stop'
$OutDir = Join-Path $PSScriptRoot 'vcredist'
$OutFile = Join-Path $OutDir 'vc_redist.x64.exe'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ((Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 1MB)) {
    Write-Host "VC++ Redistributable mavjud: $OutFile ($((Get-Item $OutFile).Length) bytes)"
    exit 0
}

$url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
Write-Host "VC++ Redistributable yuklanmoqda..."
Write-Host "  $url"
Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
if (-not (Test-Path -LiteralPath $OutFile) -or ((Get-Item -LiteralPath $OutFile).Length -lt 1MB)) {
    throw "vc_redist.x64.exe yuklab olinmadi: $OutFile"
}
Write-Host "Tayyor: $OutFile ($((Get-Item $OutFile).Length) bytes)"
