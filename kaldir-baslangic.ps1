<#
    Masaüstü Saat kısayollarını kaldırır
    (Başlangıç + Başlat menüsü + varsa masaüstü).

    Çalışan saat kapatılmaz — yalnızca kısayollar silinir.
#>

$ErrorActionPreference = 'Stop'

$ad = 'Masaustu Saat.lnk'
$dizinler = @(
    [Environment]::GetFolderPath('Startup'),
    [Environment]::GetFolderPath('Programs'),
    [Environment]::GetFolderPath('Desktop')
)

$silinen = 0
foreach ($d in $dizinler) {
    $y = Join-Path $d $ad
    if (Test-Path $y) {
        Remove-Item $y -Force
        Write-Host "Kaldirildi: $y" -ForegroundColor Green
        $silinen++
    }
}

if ($silinen -eq 0) {
    Write-Host 'Kisayol bulunamadi, yapilacak bir sey kalmadi.' -ForegroundColor Yellow
} else {
    Write-Host ''
    Write-Host 'Not: calisan saat kapatilmadi. Kapatmak icin uzerine sag tik -> Kapat.'
}
