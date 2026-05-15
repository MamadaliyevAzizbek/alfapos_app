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

$ZipName = "alfapos_app-windows-x64.zip"
$ZipPath = Join-Path $ProjectRoot $ZipName
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "Tayyor!" -ForegroundColor Green
Write-Host "  EXE: $ExePath"
Write-Host "  ZIP: $ZipPath"
Write-Host ""
Write-Host "Eslatma: alfapos_app.exe ni alohida ko'chirmang — Release papkasidagi barcha fayllar kerak." -ForegroundColor Yellow
