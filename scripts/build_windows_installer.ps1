# AlfaPOS — Windows release + Inno Setup o'rnatuvchi (.exe setup)
# Talab: Windows 10/11, Flutter SDK, VS 2022, Inno Setup 6
#   https://jrsoftware.org/isdl.php  yoki: choco install innosetup -y

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

function Get-AppVersion {
    $line = (Get-Content (Join-Path $ProjectRoot 'pubspec.yaml') -Raw) -split "`n" |
        Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
    if (-not $line) { return '1.0.0' }
    ($line -replace 'version:\s*', '').Trim() -replace '\+.*', ''
}

Write-Host '>> Flutter pub get...' -ForegroundColor Cyan
flutter pub get

Write-Host '>> Windows release build...' -ForegroundColor Cyan
flutter build windows --release

$ReleaseDir = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$ExePath = Join-Path $ReleaseDir 'alfapos_app.exe'
if (-not (Test-Path $ExePath)) {
    throw "Build muvaffaqiyatsiz: $ExePath topilmadi"
}

$readme = Join-Path $ProjectRoot 'release\WINDOWS_OCHISH.txt'
if (Test-Path $readme) {
    Copy-Item $readme (Join-Path $ReleaseDir 'WINDOWS_OCHISH.txt') -Force
}

$OutDir = Join-Path $ProjectRoot 'release\alfapos-windows-release'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$fullVer = ((Get-Content (Join-Path $ProjectRoot 'pubspec.yaml') | Select-String '^version:').Line -replace 'version:\s*','').Trim()
$verSlug = $fullVer -replace '\+','+'

# ZIP (portativ)
$ZipPath = Join-Path $OutDir 'alfapos_app-windows-x64.zip'
$ZipVersioned = Join-Path $ProjectRoot "release\alfapos_app-$verSlug-windows-x64.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath $ZipPath -Force
Copy-Item $ZipPath $ZipVersioned -Force
Write-Host "ZIP: $ZipPath" -ForegroundColor Green
Write-Host "ZIP (versiya): $ZipVersioned" -ForegroundColor Green

# Inno Setup
$Iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Iscc) {
    Write-Host ''
    Write-Host 'Inno Setup topilmadi — faqat ZIP yaratildi.' -ForegroundColor Yellow
    Write-Host 'O''rnatuvchi uchun: choco install innosetup -y  yoki https://jrsoftware.org/isdl.php' -ForegroundColor Yellow
    Write-Host 'Keyin: .\scripts\build_windows_installer.ps1' -ForegroundColor Yellow
    exit 0
}

$ver = Get-AppVersion
$Iss = Join-Path $ProjectRoot 'scripts\alfapos_installer.iss'
Write-Host ">> Inno Setup (versiya $ver)..." -ForegroundColor Cyan
& $Iscc "/DMyAppVersion=$ver" $Iss
if ($LASTEXITCODE -ne 0) { throw "ISCC xato kodi: $LASTEXITCODE" }

$SetupPath = Join-Path $OutDir 'alfapos_app-windows-x64-setup.exe'
$SetupVersioned = Join-Path $ProjectRoot "release\alfapos_app-$verSlug-windows-x64-setup.exe"
Copy-Item $SetupPath $SetupVersioned -Force
Write-Host ''
Write-Host 'Tayyor!' -ForegroundColor Green
Write-Host "  Setup: $SetupPath"
Write-Host "  Setup (versiya): $SetupVersioned"
Write-Host "  ZIP:   $ZipPath"
Write-Host "  ZIP (versiya):   $ZipVersioned"
Write-Host ''
Write-Host 'Windowsda setup.exe ni ishga tushiring — barcha fayllar Program Files\AlfaPOS ga o''rnatiladi.' -ForegroundColor Cyan
