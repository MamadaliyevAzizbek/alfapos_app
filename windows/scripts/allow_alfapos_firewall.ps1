# Alfapos Windows — tarmoq (chiqish) uchun firewall qoidasi.
# PowerShell ni «Administrator» sifatida oching va ishga tushiring:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\allow_alfapos_firewall.ps1 -ExePath "C:\path\to\alfapos_app.exe"

param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath
)

$ExePath = (Resolve-Path -LiteralPath $ExePath).Path
$RuleName = "Alfapos POS (outbound)"

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Error "Fayl topilmadi: $ExePath"
    exit 1
}

$existing = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.Program -eq $ExePath }

if ($existing) {
    Write-Host "Firewall qoidasi allaqachon mavjud: $ExePath"
} else {
    New-NetFirewallRule -DisplayName $RuleName `
        -Direction Outbound `
        -Action Allow `
        -Program $ExePath `
        -Profile Any `
        -Enabled True | Out-Null
    Write-Host "Qo'shildi: $RuleName → $ExePath"
}

Write-Host "Tayyor. Alfaposni qayta ishga tushiring."
