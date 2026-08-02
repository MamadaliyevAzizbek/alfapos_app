# Alfapos — Windows release build (PowerShell)
# Talab: Windows 10/11, Flutter SDK, Visual Studio 2022 (Desktop development with C++)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

Write-Host ">> Flutter tekshiruvi..." -ForegroundColor Cyan
flutter doctor

Write-Host ">> Paketlar o'rnatilmoqda..." -ForegroundColor Cyan
flutter pub get

Write-Host ">> Windows release build..." -ForegroundColor Cyan
flutter build windows --release

$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$ExePath = Join-Path $ReleaseDir "alfapos_app.exe"
if (-not (Test-Path $ExePath)) {
    throw "Build muvaffaqiyatsiz: $ExePath topilmadi"
}

$readme = Join-Path $ProjectRoot "release\WINDOWS_OCHISH.txt"
if (Test-Path $readme) {
    Copy-Item $readme (Join-Path $ReleaseDir "WINDOWS_OCHISH.txt") -Force
}
$rawPs = Join-Path $ProjectRoot "scripts\windows_raw_print.ps1"
if (Test-Path $rawPs) {
    Copy-Item $rawPs (Join-Path $ReleaseDir "windows_raw_print.ps1") -Force
}

$OutDir = Join-Path $ProjectRoot "release\alfapos-windows-release"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$ZipName = "alfapos_app-windows-x64.zip"
$ZipPath = Join-Path $OutDir $ZipName
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath -Force

$Iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $Iscc)) { $Iscc = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe" }
if (Test-Path $Iscc) {
    Write-Host ">> VC++ Redistributable..." -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "scripts\download_vcredist.ps1")
    Write-Host ">> Inno Setup o'rnatuvchi..." -ForegroundColor Cyan
    $ver = ((Get-Content (Join-Path $ProjectRoot "pubspec.yaml") | Select-String '^version:').Line -replace 'version:\s*','' -replace '\+.*','').Trim()
    & $Iscc "/DMyAppVersion=$ver" (Join-Path $ProjectRoot "scripts\alfapos_installer.iss")
}

Write-Host ""
Write-Host "Tayyor!" -ForegroundColor Green
Write-Host "  EXE: $ExePath"
Write-Host "  ZIP: $ZipPath"
if (Test-Path (Join-Path $OutDir "alfapos_app-windows-x64-setup.exe")) {
    Write-Host "  SETUP: $(Join-Path $OutDir 'alfapos_app-windows-x64-setup.exe')"
}
Write-Host ""
Write-Host "Eslatma: ZIP/setup ichida barcha fayllar bor — exe ni yolg'iz ko'chirmang." -ForegroundColor Yellow
