<#
    Masaüstü Saat'i Windows açılışından çıkarır.
#>

$ErrorActionPreference = 'Stop'

$kisayol = Join-Path ([Environment]::GetFolderPath('Startup')) 'Masaustu Saat.lnk'

if (Test-Path $kisayol) {
    Remove-Item $kisayol -Force
    Write-Host "Baslangictan kaldirildi: $kisayol" -ForegroundColor Green
} else {
    Write-Host "Baslangicta kayit yok, yapilacak bir sey kalmadi." -ForegroundColor Yellow
}
