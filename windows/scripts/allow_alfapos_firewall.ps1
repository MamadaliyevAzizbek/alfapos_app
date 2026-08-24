# Alfapos Windows — tarmoq firewall qoidalari.
# 1) Chiqish (outbound): API / internet
# 2) Kirish (inbound TCP 9100): telefon → Mobil relay (USB printer)
#
# PowerShell ni «Administrator» sifatida oching:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\allow_alfapos_firewall.ps1 -ExePath "C:\path\to\alfapos_app.exe"

param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,
    [int]$RelayPort = 9100
)

$ExePath = (Resolve-Path -LiteralPath $ExePath).Path
$OutboundName = "Alfapos POS (outbound)"
$InboundName = "Alfapos POS Mobile Relay (inbound TCP $RelayPort)"

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Error "Fayl topilmadi: $ExePath"
    exit 1
}

# --- Outbound: API ulanish ---
$outboundExists = Get-NetFirewallRule -DisplayName $OutboundName -ErrorAction SilentlyContinue
if ($outboundExists) {
    Write-Host "Allaqachon bor: $OutboundName"
} else {
    New-NetFirewallRule -DisplayName $OutboundName `
        -Direction Outbound `
        -Action Allow `
        -Program $ExePath `
        -Profile Any `
        -Enabled True | Out-Null
    Write-Host "Qo'shildi: $OutboundName → $ExePath"
}

# --- Inbound: telefon mobil relay (TCP 9100) ---
$inboundExists = Get-NetFirewallRule -DisplayName $InboundName -ErrorAction SilentlyContinue
if ($inboundExists) {
    Write-Host "Allaqachon bor: $InboundName"
} else {
    New-NetFirewallRule -DisplayName $InboundName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $RelayPort `
        -Program $ExePath `
        -Profile Any `
        -Enabled True | Out-Null
    Write-Host "Qo'shildi: $InboundName → TCP $RelayPort ($ExePath)"
}

Write-Host ""
Write-Host "Tayyor. AlfaPOS ni qayta oching."
Write-Host "Telefon: Menyu → Printer sozlamalari → Kompyuter relay → shu PC IP, port $RelayPort"
Write-Host "Desktopda «Mobil relay» Faol ekanini tekshiring."
