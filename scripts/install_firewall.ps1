# O'rnatuvchi: AlfaPOS uchun firewall (admin talab qilmasligi mumkin — agar xato bo'lsa qo'llanmaga qarang).
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $dir 'alfapos_app.exe'
$helper = Join-Path $dir 'allow_alfapos_firewall.ps1'

if (-not (Test-Path -LiteralPath $exe)) { exit 0 }
if (-not (Test-Path -LiteralPath $helper)) { exit 0 }

try {
    & $helper -ExePath $exe
} catch {
    # Firewall sozlanmasa ham dastur ishlaydi; foydalanuvchi qo'llanmada ko'rsatma bor.
    exit 0
}
